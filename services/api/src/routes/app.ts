/** Rutas de la app: cuenta, perfil, datos personales, dispositivos y consultas (onboarding-account). */
import type { FastifyInstance } from 'fastify';
import type { InquiryInput, UserProfile } from '@vtm/contracts';
import { NO_PATIENT_QUERIES_TEXT } from '@vtm/contracts';
import { withTx, SYSTEM, type Tx } from '../db/pool.js';
import { bad, notFound, unauthorized, ApiError } from '../lib/errors.js';
import { rolloutBucket, sha256, signJwt, sixDigitCode, shortCode } from '../lib/crypto.js';
import { computeEntitlements } from '../services/entitlements.js';
import { appActor, requireUser } from '../server.js';

const DEV = process.env.NODE_ENV !== 'production';

export function toProfile(r: Record<string, unknown>): UserProfile {
  return {
    id: String(r.id), email: (r.email as string) ?? null, alias: String(r.alias), sectorId: (r.sector_id as string) ?? null,
    itineraryId: (r.itinerary_id as string) ?? null, declaredLevel: (r.declared_level as never) ?? null, goal: (r.goal as never) ?? null,
    disclaimerAcceptedAt: r.disclaimer_accepted_at ? new Date(r.disclaimer_accepted_at as string).toISOString() : null,
    leaguesOptIn: Boolean(r.leagues_opt_in), createdAt: new Date(r.created_at as string).toISOString(),
  };
}

const ALIAS_A = ['Menisco', 'Émbolo', 'Bureta', 'Vial', 'Pipeta', 'Ampolla', 'Gotero', 'Matraz'];
const ALIAS_B = ['Ágil', 'Exacto', 'Sereno', 'Preciso', 'Constante', 'Atento', 'Claro', 'Firme'];
function randomAlias(): string {
  return `${ALIAS_A[Math.floor(Math.random() * ALIAS_A.length)]}${ALIAS_B[Math.floor(Math.random() * ALIAS_B.length)]}${Math.floor(Math.random() * 90 + 10)}`;
}

async function upsertUserByEmail(tx: Tx, email: string, local?: Partial<UserProfile>): Promise<{ user: Record<string, unknown>; isNew: boolean; merged: boolean }> {
  const found = (await tx.query("SELECT * FROM users WHERE email = $1 AND status <> 'deleted'", [email])).rows[0];
  if (found) {
    if (found.status === 'blocked') throw new ApiError(403, 'blocked', 'La cuenta está bloqueada. Escribe a soporte');
    let merged = false;
    if (local) {
      // Fusión del perfil local: se completan los campos vacíos de la cuenta (gana la última escritura en preferencias).
      const r = await tx.query(
        `UPDATE users SET sector_id = coalesce(sector_id, $2), itinerary_id = coalesce(itinerary_id, $3), declared_level = coalesce(declared_level, $4),
         goal = coalesce(goal, $5), disclaimer_accepted_at = coalesce(disclaimer_accepted_at, $6), updated_at = now() WHERE id = $1 RETURNING *`,
        [found.id, local.sectorId ?? null, local.itineraryId ?? null, local.declaredLevel ?? null, local.goal ? JSON.stringify(local.goal) : null, local.disclaimerAcceptedAt ?? null],
      );
      merged = true;
      return { user: r.rows[0], isNew: false, merged };
    }
    return { user: found, isNew: false, merged };
  }
  const r = await tx.query(
    `INSERT INTO users(email, alias, sector_id, itinerary_id, declared_level, goal, disclaimer_accepted_at, leagues_opt_in)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [email, local?.alias && local.alias.trim() ? local.alias : randomAlias(), local?.sectorId ?? null, local?.itineraryId ?? null, local?.declaredLevel ?? null, local?.goal ? JSON.stringify(local.goal) : null, local?.disclaimerAcceptedAt ?? null, local?.leaguesOptIn ?? true],
  );
  await tx.query("INSERT INTO subscriptions(user_id, status) VALUES ($1, 'none') ON CONFLICT DO NOTHING", [r.rows[0].id]);
  return { user: r.rows[0], isNew: true, merged: Boolean(local) };
}

async function session(tx: Tx, user: Record<string, unknown>, deviceId: string | undefined, isNew: boolean, merged: boolean) {
  if (deviceId) {
    await tx.query('INSERT INTO devices(id, user_id, rollout_bucket) VALUES ($1,$2,$3) ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id', [deviceId, user.id, rolloutBucket(deviceId)]);
    // Los eventos anónimos del dispositivo pasan a la cuenta (los intentos llegan por sincronización).
    await tx.query('UPDATE events SET user_id = $1 WHERE device_id = $2 AND user_id IS NULL', [user.id, deviceId]);
    await tx.query('UPDATE inquiries SET user_id = $1 WHERE device_id = $2 AND user_id IS NULL', [user.id, deviceId]);
  }
  const token = signJwt({ kind: 'app', sub: user.id, deviceId }, 30 * 24 * 3600);
  return { token, user: toProfile(user), isNew, merged, entitlements: await computeEntitlements(tx, String(user.id)) };
}

export async function appRoutes(app: FastifyInstance) {
  app.post<{ Body: { email: string } }>('/v1/auth/otp/request', async (req, reply) => {
    const email = String(req.body?.email ?? '').trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw bad('invalid_email', 'Escribe un correo electrónico válido');
    const code = sixDigitCode();
    await withTx(SYSTEM, async (tx) => {
      const recent = Number((await tx.query("SELECT count(*) AS c FROM otp_codes WHERE email = $1 AND created_at > now() - interval '10 minutes'", [email])).rows[0].c);
      if (recent >= 5) throw new ApiError(429, 'too_many', 'Has pedido demasiados códigos. Espera unos minutos');
      await tx.query("INSERT INTO otp_codes(email, code_hash, expires_at) VALUES ($1, $2, now() + interval '10 minutes')", [email, sha256(`${email}:${code}`)]);
      if (DEV) await tx.query('INSERT INTO dev_mailbox(email, subject, body) VALUES ($1, $2, $3)', [email, 'Tu código de VolutrainMed', code]);
    });
    return reply.status(204).send();
  });

  app.post<{ Body: { email: string; code: string; deviceId?: string; localProfile?: Partial<UserProfile> } }>('/v1/auth/otp/verify', async (req) => {
    const email = String(req.body?.email ?? '').trim().toLowerCase();
    const code = String(req.body?.code ?? '').trim();
    return withTx(SYSTEM, async (tx) => {
      const row = (await tx.query('SELECT * FROM otp_codes WHERE email = $1 AND used_at IS NULL AND expires_at > now() ORDER BY id DESC LIMIT 1', [email])).rows[0];
      if (!row) throw new ApiError(400, 'code_expired', 'El código ha caducado. Pide otro');
      if (row.attempts >= 5) throw new ApiError(429, 'too_many_attempts', 'Demasiados intentos. Pide otro código');
      if (row.code_hash !== sha256(`${email}:${code}`)) {
        await tx.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1', [row.id]);
        throw new ApiError(400, 'invalid_code', 'El código no es correcto');
      }
      await tx.query('UPDATE otp_codes SET used_at = now() WHERE id = $1', [row.id]);
      const { user, isNew, merged } = await upsertUserByEmail(tx, email, req.body.localProfile);
      return session(tx, user, req.body.deviceId, isNew, merged);
    });
  });

  for (const provider of ['apple', 'google'] as const) {
    app.post<{ Body: { idToken: string; deviceId?: string; localProfile?: Partial<UserProfile> } }>(`/v1/auth/${provider}`, async (req) => {
      const token = String(req.body?.idToken ?? '');
      // En desarrollo: «dev:<correo>». En producción se valida el token con el proveedor (pendiente de credenciales).
      if (!DEV || !token.startsWith('dev:')) throw new ApiError(501, 'provider_not_configured', `El acceso con ${provider === 'apple' ? 'Apple' : 'Google'} requiere configurar las credenciales del proveedor`);
      const email = token.slice(4).trim().toLowerCase();
      return withTx(SYSTEM, async (tx) => {
        const { user, isNew, merged } = await upsertUserByEmail(tx, email, req.body.localProfile);
        return session(tx, user, req.body.deviceId, isNew, merged);
      });
    });
  }

  app.get<{ Querystring: { email: string } }>('/v1/dev/mailbox', async (req) => {
    if (!DEV) throw notFound();
    return withTx(SYSTEM, async (tx) => ({ items: (await tx.query('SELECT email, subject, body, created_at FROM dev_mailbox WHERE email = $1 ORDER BY id DESC LIMIT 10', [String(req.query.email ?? '').toLowerCase()])).rows }));
  });

  app.get('/v1/me', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const user = (await tx.query("SELECT * FROM users WHERE id = $1 AND status <> 'deleted'", [u.userId])).rows[0];
      if (!user) throw unauthorized();
      await tx.query('UPDATE users SET last_seen_at = now() WHERE id = $1', [u.userId]);
      const org = (await tx.query(
        `SELECT o.id, o.name, o.nominal, g.name AS group_name, g.itineraries FROM org_memberships m JOIN organizations o ON o.id = m.org_id LEFT JOIN org_groups g ON g.id = m.group_id
         WHERE m.user_id = $1 AND m.left_at IS NULL LIMIT 1`, [u.userId])).rows[0] ?? null;
      const ent = await computeEntitlements(tx, u.userId);
      const sub = (await tx.query('SELECT expiry_notice_pending FROM subscriptions WHERE user_id = $1', [u.userId])).rows[0];
      if (sub?.expiry_notice_pending) await tx.query('UPDATE subscriptions SET expiry_notice_pending = false WHERE user_id = $1', [u.userId]);
      return { user: toProfile(user), entitlements: ent, organization: org, notices: sub?.expiry_notice_pending ? ['premium_ended'] : [] };
    });
  });

  app.patch<{ Body: Partial<UserProfile> }>('/v1/me', async (req) => {
    const u = requireUser(req);
    const b = req.body ?? {};
    return withTx(SYSTEM, async (tx) => {
      const r = await tx.query(
        `UPDATE users SET alias = coalesce($2, alias), sector_id = coalesce($3, sector_id), itinerary_id = coalesce($4, itinerary_id),
         declared_level = coalesce($5, declared_level), goal = coalesce($6, goal), leagues_opt_in = coalesce($7, leagues_opt_in),
         disclaimer_accepted_at = coalesce($8, disclaimer_accepted_at), updated_at = now() WHERE id = $1 RETURNING *`,
        [u.userId, b.alias ?? null, b.sectorId ?? null, b.itineraryId ?? null, b.declaredLevel ?? null, b.goal ? JSON.stringify(b.goal) : null, b.leaguesOptIn ?? null, b.disclaimerAcceptedAt ?? null],
      );
      return { user: toProfile(r.rows[0]) };
    });
  });

  app.post('/v1/me/export', async (req, reply) => {
    const u = requireUser(req);
    const id = await withTx(SYSTEM, async (tx) => {
      const r = await tx.query('INSERT INTO export_requests(user_id) VALUES ($1) RETURNING id', [u.userId]);
      return String(r.rows[0].id);
    });
    // Se prepara en segundo plano.
    setTimeout(() => { void prepareExport(id, u.userId); }, 50);
    return reply.status(202).send({ requestId: id, status: 'pending' });
  });

  app.get<{ Params: { id: string } }>('/v1/me/export/:id', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const r = (await tx.query('SELECT * FROM export_requests WHERE id = $1 AND user_id = $2', [req.params.id, u.userId])).rows[0];
      if (!r) throw notFound();
      return { status: r.status, file: r.file ?? undefined };
    });
  });

  app.delete<{ Body: { confirmation: string } }>('/v1/me', async (req, reply) => {
    const u = requireUser(req);
    if (String(req.body?.confirmation ?? '').trim().toUpperCase() !== 'ELIMINAR') throw bad('confirmation_required', 'Escribe ELIMINAR para confirmar');
    await withTx(SYSTEM, (tx) => deleteUserData(tx, u.userId, u.userId, 'user', 'Solicitud del usuario'));
    return reply.status(204).send();
  });

  app.post<{ Body: { deviceId: string; platform?: string; model?: string; appVersion?: string; contentVersion?: string } }>('/v1/devices', async (req) => {
    const b = req.body;
    if (!b?.deviceId) throw bad('device_required', 'Falta el identificador del dispositivo');
    return withTx(SYSTEM, async (tx) => {
      const bucket = rolloutBucket(b.deviceId);
      await tx.query(
        `INSERT INTO devices(id, user_id, platform, model, app_version, content_version, rollout_bucket, last_sync_at) VALUES ($1,$2,$3,$4,$5,$6,$7, now())
         ON CONFLICT (id) DO UPDATE SET user_id = coalesce(EXCLUDED.user_id, devices.user_id), platform = EXCLUDED.platform, model = EXCLUDED.model, app_version = EXCLUDED.app_version, content_version = EXCLUDED.content_version, last_sync_at = now()`,
        [b.deviceId, req.appUser?.userId ?? null, b.platform ?? null, b.model ?? null, b.appVersion ?? null, b.contentVersion ?? null, bucket],
      );
      return { rolloutBucket: bucket };
    });
  });

  app.post<{ Body: InquiryInput & { deviceId?: string } }>('/v1/inquiries', async (req) => {
    const b = req.body;
    if (!b?.id || !b.message?.trim()) throw bad('invalid', 'Escribe el mensaje de la consulta');
    return withTx(SYSTEM, async (tx) => {
      const existing = (await tx.query('SELECT id, reference, status FROM inquiries WHERE id = $1', [b.id])).rows[0];
      if (existing) return { id: existing.id, reference: existing.reference, status: existing.status, duplicate: true };
      const reference = `C-${shortCode(6)}`;
      const patient = /\b(mi paciente|un paciente real|paciente de \d|qué dosis le (pongo|doy)|cu[aá]nto le pongo)\b/i.test(b.message);
      await tx.query(
        'INSERT INTO inquiries(id, reference, user_id, device_id, type, message, reply_email, exercise, created_at, is_patient_query) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',
        [b.id, reference, req.appUser?.userId ?? null, b.deviceId ?? null, b.type, b.message, b.replyEmail ?? null, b.exercise ? JSON.stringify(b.exercise) : null, b.createdAt ?? new Date().toISOString(), patient],
      );
      return { id: b.id, reference, status: 'received', notice: NO_PATIENT_QUERIES_TEXT };
    });
  });

  app.get('/v1/inquiries', async (req) => {
    const u = requireUser(req);
    return withTx(appActor(req), async (tx) => ({
      items: (await tx.query('SELECT id, reference, type, message, status, reply, created_at AS "createdAt", answered_at AS "answeredAt" FROM inquiries WHERE user_id = $1 ORDER BY created_at DESC', [u.userId])).rows,
    }));
  });
}

async function prepareExport(requestId: string, userId: string) {
  await withTx(SYSTEM, async (tx) => {
    const profile = (await tx.query('SELECT * FROM users WHERE id = $1', [userId])).rows[0];
    const attempts = (await tx.query('SELECT * FROM attempts WHERE user_id = $1 ORDER BY seq', [userId])).rows;
    const sessions = (await tx.query('SELECT record FROM learning_sessions WHERE user_id = $1 ORDER BY seq', [userId])).rows.map((r) => r.record);
    const inquiries = (await tx.query('SELECT reference, type, message, status, reply, created_at FROM inquiries WHERE user_id = $1', [userId])).rows;
    const subscription = (await tx.query('SELECT plan, status, started_at, expires_at FROM subscriptions WHERE user_id = $1', [userId])).rows[0] ?? null;
    await tx.query("UPDATE export_requests SET status = 'ready', ready_at = now(), file = $2 WHERE id = $1", [requestId, JSON.stringify({ profile: profile ? toProfile(profile) : null, subscription, attempts, sessions, inquiries, generatedAt: new Date().toISOString() })]);
  });
}

/** Supresión o anonimización de los datos personales (RGPD). Los intentos se conservan anonimizados. */
export async function deleteUserData(tx: Tx, userId: string, actorId: string, actorRole: string, reason: string) {
  await tx.query(
    "UPDATE users SET email = NULL, alias = 'Usuario eliminado', sector_id = NULL, goal = NULL, status = 'deleted', deleted_at = now(), leagues_opt_in = false WHERE id = $1",
    [userId],
  );
  await tx.query('UPDATE inquiries SET reply_email = NULL WHERE user_id = $1', [userId]);
  await tx.query('UPDATE org_memberships SET left_at = now() WHERE user_id = $1 AND left_at IS NULL', [userId]);
  await tx.query("UPDATE league_members SET alias = 'Anónimo' WHERE user_id = $1", [userId]);
  await tx.query('UPDATE devices SET user_id = NULL WHERE user_id = $1', [userId]);
  await tx.query(
    'INSERT INTO audit_log(actor_id, actor_role, action, entity, entity_id, reason) VALUES ($1,$2,$3,$4,$5,$6)',
    [actorRole === 'user' ? null : actorId, actorRole, 'user.delete', 'user', userId, reason],
  );
}
