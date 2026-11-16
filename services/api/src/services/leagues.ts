/**
 * Ligas semanales (leagues): grupos de 30 por sector y división, puntuación por
 * precisión con tope diario, bonificación solo con marca válida de contrarreloj,
 * detección de patrones imposibles y ascensos/descensos al cierre de semana.
 */
import type { LeagueConfig } from '@vtm/contracts';
import type { Tx } from '../db/pool.js';
import { leagueConfigFor } from '../publish/service.js';

export function weekStart(d = new Date()): string {
  const x = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dow = (x.getUTCDay() + 6) % 7; // lunes = 0
  x.setUTCDate(x.getUTCDate() - dow);
  return x.toISOString().slice(0, 10);
}

export function weekEnd(ws: string): Date {
  const d = new Date(`${ws}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 7);
  return d;
}

/** Marca para revisión las series de aciertos con tiempos imposibles y deja sus puntos en suspenso. */
export async function detectAnomalies(tx: Tx, userId: string, ws: string, minHumanMs: number): Promise<number> {
  const rows = (await tx.query(
    `SELECT id, response_ms, verdict FROM attempts WHERE user_id = $1 AND device_time >= $2 AND device_time < $3 AND attempt_number = 1 ORDER BY device_time, seq`,
    [userId, ws, weekEnd(ws)],
  )).rows;
  let run: string[] = [];
  let flagged = 0;
  const flush = async () => {
    if (run.length >= 5) {
      const exists = (await tx.query('SELECT 1 FROM league_flags WHERE user_id = $1 AND attempt_ids && $2::uuid[]', [userId, run])).rowCount;
      if (!exists) {
        await tx.query('INSERT INTO league_flags(user_id, week_start, reason, attempt_ids) VALUES ($1,$2,$3,$4)', [userId, ws, `Serie de ${run.length} aciertos con tiempos inferiores a ${minHumanMs} ms`, run]);
        flagged++;
      }
      await tx.query("UPDATE attempts SET league_status = 'suspended' WHERE id = ANY($1::uuid[]) AND league_status = 'counted'", [run]);
    }
    run = [];
  };
  for (const r of rows) {
    if (['correct', 'correct_note'].includes(r.verdict) && Number(r.response_ms) < minHumanMs) run.push(r.id);
    else await flush();
  }
  await flush();
  return flagged;
}

export async function pointsFor(tx: Tx, userId: string, ws: string, cfg: LeagueConfig): Promise<number> {
  const perDay = (await tx.query(
    `SELECT date_trunc('day', device_time) AS d, count(*)::int AS n FROM attempts
     WHERE user_id = $1 AND device_time >= $2 AND device_time < $3 AND attempt_number = 1 AND verdict IN ('correct','correct_note') AND league_status = 'counted'
     GROUP BY 1`, [userId, ws, weekEnd(ws)],
  )).rows;
  const bonuses = (await tx.query(
    `SELECT date_trunc('day', started_at) AS d, count(*)::int AS n FROM learning_sessions
     WHERE user_id = $1 AND started_at >= $2 AND started_at < $3 AND mode = 'timetrial' AND (record->'summary'->>'valid')::boolean IS TRUE
     GROUP BY 1`, [userId, ws, weekEnd(ws)],
  )).rows;
  const days = new Map<string, number>();
  for (const r of perDay) days.set(new Date(r.d).toISOString(), (days.get(new Date(r.d).toISOString()) ?? 0) + r.n * cfg.pointsPerCorrect);
  for (const r of bonuses) days.set(new Date(r.d).toISOString(), (days.get(new Date(r.d).toISOString()) ?? 0) + r.n * cfg.timetrialBonus);
  let total = 0;
  for (const v of days.values()) total += Math.min(v, cfg.dailyCap);
  return total;
}

export async function ensureMembership(tx: Tx, userId: string, ws = weekStart()): Promise<string | null> {
  const user = (await tx.query('SELECT alias, sector_id, leagues_opt_in, status FROM users WHERE id = $1', [userId])).rows[0];
  if (!user || !user.leagues_opt_in || user.status !== 'active') return null;
  const existing = (await tx.query('SELECT g.id FROM league_members m JOIN league_groups g ON g.id = m.group_id WHERE m.user_id = $1 AND g.week_start = $2 AND g.private_league_id IS NULL', [userId, ws])).rows[0];
  if (existing) return existing.id as string;
  const division = Number((await tx.query('SELECT division FROM league_divisions WHERE user_id = $1', [userId])).rows[0]?.division ?? 0);
  const cfg = await leagueConfigFor(tx, new Date(`${ws}T00:00:00Z`));
  const sector = cfg.groupBySector ? user.sector_id : null;
  let group = (await tx.query(
    `SELECT g.id FROM league_groups g LEFT JOIN league_members m ON m.group_id = g.id
     WHERE g.week_start = $1 AND g.division = $2 AND coalesce(g.sector_id,'') = coalesce($3,'') AND g.private_league_id IS NULL AND NOT g.closed
     GROUP BY g.id HAVING count(m.user_id) < $4 LIMIT 1`, [ws, division, sector, cfg.groupSize],
  )).rows[0];
  if (!group) group = (await tx.query('INSERT INTO league_groups(week_start, division, sector_id, config) VALUES ($1,$2,$3,$4) RETURNING id', [ws, division, sector, JSON.stringify(cfg)])).rows[0];
  await tx.query('INSERT INTO league_members(group_id, user_id, alias) VALUES ($1,$2,$3) ON CONFLICT DO NOTHING', [group.id, userId, user.alias]);
  await tx.query('INSERT INTO league_divisions(user_id, division) VALUES ($1,$2) ON CONFLICT DO NOTHING', [userId, division]);
  return group.id as string;
}

export async function standings(tx: Tx, groupId: string, meId?: string) {
  const g = (await tx.query('SELECT * FROM league_groups WHERE id = $1', [groupId])).rows[0];
  const cfg = g.config as LeagueConfig;
  const members = (await tx.query(
    `SELECT m.user_id, m.alias FROM league_members m JOIN users u ON u.id = m.user_id WHERE m.group_id = $1 AND u.leagues_opt_in AND u.status = 'active'`, [groupId],
  )).rows;
  const rows: { userId: string; alias: string; points: number }[] = [];
  for (const m of members) {
    await detectAnomalies(tx, m.user_id, g.week_start instanceof Date ? g.week_start.toISOString().slice(0, 10) : String(g.week_start), cfg.minHumanMs);
    const p = await pointsFor(tx, m.user_id, g.week_start instanceof Date ? g.week_start.toISOString().slice(0, 10) : String(g.week_start), cfg);
    await tx.query('UPDATE league_members SET points = $3 WHERE group_id = $1 AND user_id = $2', [groupId, m.user_id, p]);
    rows.push({ userId: m.user_id, alias: m.alias, points: p });
  }
  rows.sort((a, b) => b.points - a.points || a.alias.localeCompare(b.alias));
  return {
    group: g, config: cfg,
    standings: rows.map((r, i) => ({ position: i + 1, alias: r.alias, points: r.points, me: r.userId === meId, userId: r.userId })),
  };
}

/** Cierre de semana: suben los 7 primeros y bajan los 5 últimos de cada grupo. */
export async function closeWeek(tx: Tx, ws: string) {
  const groups = (await tx.query('SELECT id, division, config FROM league_groups WHERE week_start = $1 AND NOT closed AND private_league_id IS NULL', [ws])).rows;
  const results: { groupId: string; promoted: number; relegated: number }[] = [];
  for (const g of groups) {
    const cfg = g.config as LeagueConfig;
    const st = (await standings(tx, g.id)).standings;
    let promoted = 0; let relegated = 0;
    for (const s of st) {
      let result = 'stay';
      let division = Number(g.division);
      if (s.position <= cfg.promote && division < cfg.divisions.length - 1) { division++; result = 'promoted'; promoted++; }
      else if (s.position > st.length - cfg.relegate && st.length > cfg.promote + cfg.relegate && division > 0) { division--; result = 'relegated'; relegated++; }
      await tx.query('UPDATE league_members SET result = $3 WHERE group_id = $1 AND user_id = $2', [g.id, s.userId, result]);
      await tx.query('INSERT INTO league_divisions(user_id, division) VALUES ($1,$2) ON CONFLICT (user_id) DO UPDATE SET division = EXCLUDED.division', [s.userId, division]);
    }
    await tx.query('UPDATE league_groups SET closed = true WHERE id = $1', [g.id]);
    results.push({ groupId: g.id, promoted, relegated });
  }
  return results;
}
