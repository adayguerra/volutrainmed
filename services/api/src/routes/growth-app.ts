/** Organizaciones y ligas, lado app (add-growth-features). */
import type { FastifyInstance } from 'fastify';
import { withTx, SYSTEM, type Tx } from '../db/pool.js';
import { bad, conflict, notFound } from '../lib/errors.js';
import { requireUser } from '../server.js';
import { computeEntitlements } from '../services/entitlements.js';
import { ensureMembership, standings, weekEnd, weekStart } from '../services/leagues.js';

export const NOMINAL_DATA = ['Tu alias y tu correo', 'Lecciones completadas', 'Precisión por habilidad', 'Habilidades dominadas', 'Minutos de práctica'];
export const AGGREGATE_DATA = ['Solo datos agregados del grupo: finalización, precisión media y habilidades dominadas, sin nombres'];

async function orgByCode(tx: Tx, code: string) {
  const c = code.trim().toUpperCase();
  const g = (await tx.query('SELECT g.*, o.id AS org_id FROM org_groups g JOIN organizations o ON o.id = g.org_id WHERE g.invite_code = $1', [c])).rows[0];
  const org = (await tx.query('SELECT * FROM organizations WHERE invite_code = $1 OR id = $2', [c, g?.org_id ?? null])).rows[0];
  if (!org) throw notFound('El código no corresponde a ninguna organización');
  return { org, group: g ?? null };
}

export async function seatsUsed(tx: Tx, orgId: string): Promise<number> {
  return Number((await tx.query('SELECT count(*) AS c FROM org_memberships WHERE org_id = $1 AND left_at IS NULL', [orgId])).rows[0].c);
}

export async function growthAppRoutes(app: FastifyInstance) {
  app.post<{ Body: { code: string } }>('/v1/orgs/preview', async (req) => {
    requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const { org, group } = await orgByCode(tx, String(req.body?.code ?? ''));
      return { organization: { id: org.id, name: org.name, nominal: org.nominal, visibleData: org.nominal ? NOMINAL_DATA : AGGREGATE_DATA }, group: group ? { id: group.id, name: group.name } : null };
    });
  });

  app.post<{ Body: { code: string; acceptNominal?: boolean } }>('/v1/orgs/join', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const { org, group } = await orgByCode(tx, String(req.body?.code ?? ''));
      const today = new Date().toISOString().slice(0, 10);
      if (String(org.valid_to instanceof Date ? org.valid_to.toISOString().slice(0, 10) : org.valid_to) < today) throw conflict('org_expired', 'La licencia de la organización ha terminado');
      if (org.nominal && !req.body?.acceptNominal) throw bad('nominal_not_accepted', 'Debes aceptar qué datos verá la organización antes de unirte');
      const other = (await tx.query('SELECT org_id FROM org_memberships WHERE user_id = $1 AND left_at IS NULL AND org_id <> $2', [u.userId, org.id])).rows[0];
      if (other) throw conflict('already_member', 'Ya perteneces a otra organización. Sal de ella antes de unirte');
      const mine = (await tx.query('SELECT 1 FROM org_memberships WHERE user_id = $1 AND org_id = $2 AND left_at IS NULL', [u.userId, org.id])).rowCount;
      if (!mine && (await seatsUsed(tx, org.id)) >= org.seats) {
        await tx.query('UPDATE organizations SET seats_alert_sent_at = now() WHERE id = $1', [org.id]);
        await tx.query("INSERT INTO audit_log(actor_role, action, entity, entity_id, reason) VALUES ('system','org.seats_exhausted','organization',$1,'Intento de unión sin plazas libres')", [org.id]);
        throw conflict('seats_exhausted', 'La organización no tiene plazas libres. Ya le hemos avisado');
      }
      await tx.query(
        `INSERT INTO org_memberships(user_id, org_id, group_id, accepted_nominal) VALUES ($1,$2,$3,$4)
         ON CONFLICT (user_id, org_id) DO UPDATE SET group_id = EXCLUDED.group_id, accepted_nominal = EXCLUDED.accepted_nominal, left_at = NULL, joined_at = now()`,
        [u.userId, org.id, group?.id ?? null, Boolean(req.body?.acceptNominal)],
      );
      await tx.query("UPDATE org_invites SET status = 'accepted' WHERE org_id = $1 AND email = (SELECT email FROM users WHERE id = $2)", [org.id, u.userId]);
      return { membership: { orgId: org.id, name: org.name, groupId: group?.id ?? null, nominal: org.nominal }, entitlements: await computeEntitlements(tx, u.userId) };
    });
  });

  app.get('/v1/orgs/domain-offer', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const email = (await tx.query('SELECT email FROM users WHERE id = $1', [u.userId])).rows[0]?.email as string | undefined;
      if (!email) return { organization: null };
      const domain = email.split('@')[1] ?? '';
      const org = (await tx.query('SELECT * FROM organizations WHERE $1 = ANY(domains) AND valid_to >= current_date', [domain])).rows[0];
      if (!org) return { organization: null };
      const free = org.seats - (await seatsUsed(tx, org.id));
      const member = (await tx.query('SELECT 1 FROM org_memberships WHERE user_id = $1 AND org_id = $2 AND left_at IS NULL', [u.userId, org.id])).rowCount;
      if (free <= 0 || member) return { organization: null };
      return { organization: { id: org.id, name: org.name, nominal: org.nominal, code: org.invite_code, visibleData: org.nominal ? NOMINAL_DATA : AGGREGATE_DATA } };
    });
  });

  app.get('/v1/orgs/mine', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const r = (await tx.query(
        `SELECT o.id, o.name, o.nominal, g.id AS group_id, g.name AS group_name, g.itineraries, m.accepted_nominal FROM org_memberships m
         JOIN organizations o ON o.id = m.org_id LEFT JOIN org_groups g ON g.id = m.group_id WHERE m.user_id = $1 AND m.left_at IS NULL LIMIT 1`, [u.userId],
      )).rows[0];
      if (!r) return { organization: null };
      return { organization: { id: r.id, name: r.name, nominal: r.nominal }, group: r.group_id ? { id: r.group_id, name: r.group_name } : null, visibleData: r.nominal ? NOMINAL_DATA : AGGREGATE_DATA, assignedItineraries: r.itineraries ?? [] };
    });
  });

  app.post('/v1/orgs/leave', async (req, reply) => {
    const u = requireUser(req);
    await withTx(SYSTEM, (tx) => tx.query('UPDATE org_memberships SET left_at = now() WHERE user_id = $1 AND left_at IS NULL', [u.userId]));
    return reply.status(204).send();
  });

  app.get('/v1/leagues/current', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const user = (await tx.query('SELECT leagues_opt_in FROM users WHERE id = $1', [u.userId])).rows[0];
      const ws = weekStart();
      if (!user?.leagues_opt_in) return { participating: false, week: ws };
      const groupId = await ensureMembership(tx, u.userId, ws);
      if (!groupId) return { participating: false, week: ws };
      const st = await standings(tx, groupId, u.userId);
      const cfg = st.config;
      const suspended = Number((await tx.query("SELECT count(*) AS c FROM attempts WHERE user_id = $1 AND league_status = 'suspended' AND device_time >= $2", [u.userId, ws])).rows[0].c);
      return {
        participating: true, week: ws, endsAt: weekEnd(ws).toISOString(), division: cfg.divisions[Number(st.group.division)] ?? cfg.divisions[0],
        divisionIndex: Number(st.group.division), standings: st.standings.map(({ userId: _u, ...s }) => s),
        zones: { promote: cfg.promote, relegate: cfg.relegate }, dailyCap: cfg.dailyCap, computedAt: new Date().toISOString(), suspendedAttempts: suspended,
      };
    });
  });

  app.post<{ Body: { participate: boolean; alias?: string } }>('/v1/leagues/participation', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      await tx.query('UPDATE users SET leagues_opt_in = $2, alias = coalesce($3, alias) WHERE id = $1', [u.userId, Boolean(req.body?.participate), req.body?.alias?.trim() || null]);
      if (req.body?.alias?.trim()) await tx.query('UPDATE league_members SET alias = $2 WHERE user_id = $1', [u.userId, req.body.alias.trim()]);
      return { participating: Boolean(req.body?.participate) };
    });
  });

  app.get('/v1/leagues/private', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const leagues = (await tx.query(
        `SELECT pl.id, pl.name, pl.group_id FROM private_leagues pl JOIN org_memberships m ON m.org_id = pl.org_id AND m.left_at IS NULL
         WHERE m.user_id = $1 AND (pl.group_id IS NULL OR pl.group_id = m.group_id)`, [u.userId],
      )).rows;
      const out = [];
      for (const l of leagues) {
        const ws = weekStart();
        let g = (await tx.query('SELECT id FROM league_groups WHERE private_league_id = $1 AND week_start = $2', [l.id, ws])).rows[0];
        const user = (await tx.query('SELECT alias, leagues_opt_in FROM users WHERE id = $1', [u.userId])).rows[0];
        if (!g) g = (await tx.query("INSERT INTO league_groups(week_start, division, private_league_id, config) VALUES ($1, 0, $2, (SELECT value FROM settings WHERE key = 'league_config')) RETURNING id", [ws, l.id])).rows[0];
        if (user?.leagues_opt_in) await tx.query('INSERT INTO league_members(group_id, user_id, alias) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING', [g.id, u.userId, user.alias]);
        const st = await standings(tx, g.id, u.userId);
        out.push({ id: l.id, name: l.name, standings: st.standings.map(({ userId: _u, ...s }) => s) });
      }
      return { leagues: out };
    });
  });
}
