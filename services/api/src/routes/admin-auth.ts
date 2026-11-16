/** Acceso al back office con doble factor obligatorio y cuentas (backoffice-administration). */
import type { FastifyInstance } from 'fastify';
import { randomBytes } from 'node:crypto';
import { withTx, SYSTEM } from '../db/pool.js';
import { ApiError, bad, conflict, unauthorized } from '../lib/errors.js';
import { hashPassword, newTotpSecret, otpauthUrl, sha256, signJwt, verifyPassword, verifyTotp } from '../lib/crypto.js';
import { audit } from '../lib/audit.js';
import { requireBo, boActor, type BoRole } from '../server.js';

const ROLE_LABELS: Record<BoRole, string> = {
  superadmin: 'Superadministración', content_admin: 'Administración de contenido', author: 'Autoría', reviewer: 'Revisión experta',
  org_admin: 'Administración de organización', analyst: 'Análisis', support: 'Soporte',
};

function publicAccount(a: Record<string, unknown>) {
  return { id: a.id, email: a.email, name: a.name, role: a.role, roleLabel: ROLE_LABELS[a.role as BoRole], sectors: a.sectors, accreditation: a.accreditation, orgId: a.org_id, active: a.active, mfaEnabled: a.totp_enabled };
}

export async function adminAuthRoutes(app: FastifyInstance) {
  app.post<{ Body: { email: string; password: string } }>('/v1/admin/auth/login', async (req) => {
    const email = String(req.body?.email ?? '').trim().toLowerCase();
    return withTx(SYSTEM, async (tx) => {
      const acc = (await tx.query('SELECT * FROM bo_accounts WHERE email = $1 AND active', [email])).rows[0];
      if (!acc || !verifyPassword(String(req.body?.password ?? ''), acc.password_hash)) throw unauthorized('Correo o contraseña incorrectos');
      const pending = acc.totp_enabled ? null : newTotpSecret();
      const ch = (await tx.query("INSERT INTO bo_challenges(account_id, pending_secret, expires_at) VALUES ($1, $2, now() + interval '10 minutes') RETURNING id", [acc.id, pending])).rows[0];
      return { challenge: ch.id, mfaSetupRequired: !acc.totp_enabled, otpauthUrl: pending ? otpauthUrl(pending, acc.email) : undefined, secret: pending ?? undefined };
    });
  });

  app.post<{ Body: { challenge: string; code?: string; recoveryCode?: string } }>('/v1/admin/auth/mfa', async (req) => {
    return withTx(SYSTEM, async (tx) => {
      const ch = (await tx.query('SELECT * FROM bo_challenges WHERE id = $1 AND NOT used AND expires_at > now()', [req.body?.challenge])).rows[0];
      if (!ch) throw unauthorized('La sesión de acceso ha caducado. Vuelve a entrar');
      const acc = (await tx.query('SELECT * FROM bo_accounts WHERE id = $1', [ch.account_id])).rows[0];
      let recoveryCodes: string[] | undefined;
      if (req.body.recoveryCode) {
        const h = sha256(req.body.recoveryCode.trim().toUpperCase());
        if (!acc.recovery_codes.includes(h)) throw new ApiError(400, 'invalid_code', 'El código de recuperación no es válido');
        await tx.query('UPDATE bo_accounts SET recovery_codes = array_remove(recovery_codes, $2) WHERE id = $1', [acc.id, h]);
      } else {
        const secret = ch.pending_secret ?? acc.totp_secret;
        if (!secret || !verifyTotp(secret, String(req.body.code ?? ''))) throw new ApiError(400, 'invalid_code', 'El código no es correcto');
        if (ch.pending_secret) {
          recoveryCodes = Array.from({ length: 8 }, () => randomBytes(4).toString('hex').toUpperCase());
          await tx.query('UPDATE bo_accounts SET totp_secret = $2, totp_enabled = true, recovery_codes = $3 WHERE id = $1', [acc.id, ch.pending_secret, recoveryCodes.map((c) => sha256(c))]);
        }
      }
      await tx.query('UPDATE bo_challenges SET used = true WHERE id = $1', [ch.id]);
      await audit(tx, { actorId: acc.id, actorRole: acc.role, action: 'bo.login', entity: 'bo_account', entityId: acc.id });
      const token = signJwt({ kind: 'bo', sub: acc.id, role: acc.role, sectors: acc.sectors, orgId: acc.org_id, name: acc.name, email: acc.email, mfa: true }, 12 * 3600);
      return { token, account: publicAccount({ ...acc, totp_enabled: true }), recoveryCodes };
    });
  });

  app.get('/v1/admin/me', async (req) => {
    const bo = requireBo(req);
    return withTx(boActor(bo), async (tx) => ({ account: publicAccount((await tx.query('SELECT * FROM bo_accounts WHERE id = $1', [bo.accountId])).rows[0]) }));
  });

  app.get('/v1/admin/accounts', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    return withTx(boActor(bo), async (tx) => ({ items: (await tx.query('SELECT * FROM bo_accounts ORDER BY created_at')).rows.map(publicAccount) }));
  });

  app.post<{ Body: { email: string; name: string; role: BoRole; sectors?: string[]; accreditation?: string; orgId?: string; password: string } }>('/v1/admin/accounts', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    const b = req.body;
    if (!b?.email || !b.name || !b.role || !b.password || b.password.length < 10) throw bad('invalid', 'Correo, nombre, rol y contraseña de 10 caracteres como mínimo');
    return withTx(boActor(bo), async (tx) => {
      const exists = (await tx.query('SELECT 1 FROM bo_accounts WHERE email = $1', [b.email.toLowerCase()])).rowCount;
      if (exists) throw conflict('duplicate', 'Ya existe una cuenta con ese correo');
      const r = (await tx.query(
        'INSERT INTO bo_accounts(email, name, role, sectors, accreditation, org_id, password_hash) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
        [b.email.toLowerCase(), b.name, b.role, b.sectors ?? [], b.accreditation ?? null, b.orgId ?? null, hashPassword(b.password)],
      )).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'account.create', entity: 'bo_account', entityId: r.id, after: publicAccount(r) });
      return { account: publicAccount(r) };
    });
  });

  app.patch<{ Params: { id: string }; Body: { role?: BoRole; sectors?: string[]; accreditation?: string; active?: boolean } }>('/v1/admin/accounts/:id', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    return withTx(boActor(bo), async (tx) => {
      const before = (await tx.query('SELECT * FROM bo_accounts WHERE id = $1', [req.params.id])).rows[0];
      const r = (await tx.query(
        'UPDATE bo_accounts SET role = coalesce($2, role), sectors = coalesce($3, sectors), accreditation = coalesce($4, accreditation), active = coalesce($5, active) WHERE id = $1 RETURNING *',
        [req.params.id, req.body.role ?? null, req.body.sectors ?? null, req.body.accreditation ?? null, req.body.active ?? null],
      )).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'account.update', entity: 'bo_account', entityId: req.params.id, before: publicAccount(before), after: publicAccount(r) });
      return { account: publicAccount(r) };
    });
  });
}
