/** Back office: panel de control, analítica de contenido, campañas, logros, ligas y auditoría. */
import type { FastifyInstance } from 'fastify';
import type { AdParams, LeagueConfig, AchievementMetric } from '@vtm/contracts';
import { withTx, type Tx } from '../db/pool.js';
import { bad, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { requireBo, boActor } from '../server.js';
import { expireValidations, latest, updateItem } from '../services/items.js';
import { closeWeek, weekStart } from '../services/leagues.js';
import { getSetting, leagueConfigFor } from '../publish/service.js';
import type { TemplateDefinition, QuestionDefinition } from '@vtm/engine';

interface ItemStats {
  itemId: string; kind: string; title: string; sectorId: string | null; exerciseTypeId: string | null; responses: number; firstAttemptAccuracy: number | null;
  medianMs: number | null; targetMs: number | null; timeRatio: number | null; dontKnowPct: number | null; critical: number; unclassifiedPct: number | null;
  topError: { value: string | null; unit: string | null; code: string | null; count: number } | null; reports: number; insufficient: boolean; alerts: string[];
}

function median(xs: number[]): number | null {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m]! : (s[m - 1]! + s[m]!) / 2;
}

/** Alertas de calidad: acierto <40 % o >98 %, «No lo sé» >25 %, sin clasificar >30 %, mediana >2× objetivo. */
export function alertsFor(s: Omit<ItemStats, 'alerts'>): string[] {
  if (s.insufficient) return [];
  const a: string[] = [];
  if (s.firstAttemptAccuracy !== null && s.firstAttemptAccuracy < 40) a.push(`Acierto al primer intento del ${Math.round(s.firstAttemptAccuracy)} %`);
  if (s.firstAttemptAccuracy !== null && s.firstAttemptAccuracy > 98) a.push(`Acierto al primer intento del ${Math.round(s.firstAttemptAccuracy)} %: demasiado fácil`);
  if (s.dontKnowPct !== null && s.dontKnowPct > 25) a.push(`«No lo sé» en el ${Math.round(s.dontKnowPct)} % de las respuestas`);
  if (s.unclassifiedPct !== null && s.unclassifiedPct > 30) a.push(`${Math.round(s.unclassifiedPct)} % de errores sin clasificar`);
  if (s.timeRatio !== null && s.timeRatio > 2) a.push(`Tiempo mediano ${s.timeRatio.toFixed(1).replace('.', ',')} veces el objetivo`);
  return a;
}

export async function itemStats(tx: Tx, filter?: { sector?: string }): Promise<ItemStats[]> {
  const items = (await tx.query("SELECT DISTINCT ON (id) id, kind, title, sector_id, data FROM content_items WHERE kind IN ('template','question') ORDER BY id, version DESC")).rows;
  const atts = (await tx.query(
    `SELECT coalesce(template_id, question_id) AS item, verdict, error_code, critical, response_ms, target_ms, answer_value, answer_unit, attempt_number
     FROM attempts WHERE coalesce(template_id, question_id) IS NOT NULL`)).rows;
  const reports = (await tx.query("SELECT coalesce(exercise->>'templateId', exercise->>'questionId') AS item, count(*)::int AS n FROM inquiries WHERE type = 'exercise_error' GROUP BY 1")).rows;
  const by = new Map<string, typeof atts>();
  for (const a of atts) (by.get(a.item) ?? by.set(a.item, []).get(a.item)!).push(a);
  const out: ItemStats[] = [];
  for (const it of items) {
    if (filter?.sector && it.sector_id !== filter.sector) continue;
    const rows = by.get(it.id) ?? [];
    const first = rows.filter((r) => r.attempt_number === 1);
    const ok = first.filter((r) => ['correct', 'correct_note'].includes(r.verdict)).length;
    const wrong = first.filter((r) => r.verdict === 'incorrect');
    const dk = first.filter((r) => r.verdict === 'dont_know').length;
    const unclassified = wrong.filter((r) => !r.error_code).length;
    const counts = new Map<string, { value: string | null; unit: string | null; code: string | null; count: number }>();
    for (const w of wrong) {
      const k = `${w.answer_value}|${w.answer_unit}|${w.error_code}`;
      const c = counts.get(k) ?? { value: w.answer_value, unit: w.answer_unit, code: w.error_code, count: 0 };
      c.count++; counts.set(k, c);
    }
    const top = [...counts.values()].sort((a, b) => b.count - a.count)[0] ?? null;
    const med = median(first.filter((r) => ['correct', 'correct_note'].includes(r.verdict)).map((r) => Number(r.response_ms)));
    const target = median(first.map((r) => Number(r.target_ms)));
    const base = {
      itemId: it.id, kind: it.kind, title: it.title, sectorId: it.sector_id, exerciseTypeId: it.data?.exerciseTypeId ?? null, responses: first.length,
      firstAttemptAccuracy: first.length ? (ok / first.length) * 100 : null, medianMs: med, targetMs: target, timeRatio: med && target ? med / target : null,
      dontKnowPct: first.length ? (dk / first.length) * 100 : null, critical: first.filter((r) => r.critical).length,
      unclassifiedPct: wrong.length ? (unclassified / wrong.length) * 100 : null, topError: top, reports: reports.find((r) => r.item === it.id)?.n ?? 0,
      insufficient: first.length < 50,
    };
    out.push({ ...base, alerts: alertsFor(base) });
  }
  return out;
}

/** Métricas de un usuario para probar logros. */
export async function userMetrics(tx: Tx, userId: string): Promise<Record<AchievementMetric, number>> {
  const days = (await tx.query("SELECT DISTINCT date_trunc('day', device_time)::date AS d FROM attempts WHERE user_id = $1 ORDER BY 1 DESC", [userId])).rows.map((r) => new Date(r.d));
  let streak = 0;
  for (let i = 0; i < days.length; i++) {
    const expected = new Date(days[0]!); expected.setUTCDate(expected.getUTCDate() - i);
    if (days[i]!.toISOString().slice(0, 10) === expected.toISOString().slice(0, 10)) streak++; else break;
  }
  const atts = (await tx.query('SELECT verdict, critical, attempt_number FROM attempts WHERE user_id = $1 ORDER BY device_time DESC', [userId])).rows;
  let inRow = 0; for (const a of atts) { if (a.attempt_number === 1 && ['correct', 'correct_note'].includes(a.verdict)) inRow++; else if (a.attempt_number === 1) break; }
  let noCrit = 0; for (const a of atts) { if (a.critical) break; noCrit++; }
  const s = (await tx.query(
    `SELECT count(*) FILTER (WHERE mode = 'lesson' AND (record->>'completed')::boolean)::int AS lessons, count(*) FILTER (WHERE mode = 'handsfree' AND (record->>'completed')::boolean)::int AS hf,
            count(*) FILTER (WHERE mode = 'timetrial' AND (record->'summary'->>'valid')::boolean)::int AS tt FROM learning_sessions WHERE user_id = $1`, [userId])).rows[0];
  const skills = (await tx.query(`SELECT skill_id FROM attempts WHERE user_id = $1 AND attempt_number = 1 GROUP BY skill_id HAVING count(*) >= 20 AND avg(CASE WHEN verdict IN ('correct','correct_note') THEN 1 ELSE 0 END) >= 0.95`, [userId])).rows;
  return { streak_days: streak, correct_in_row: inRow, skills_mastered: skills.length, handsfree_sessions: s.hf, valid_timetrial: s.tt, no_critical_exercises: noCrit, lessons_completed: s.lessons, units_mastered: 0 };
}

export function evaluateCondition(c: { metric: AchievementMetric; op: '>=' | '>' | '=='; value: number }, metrics: Partial<Record<AchievementMetric, number>>): boolean {
  const v = metrics[c.metric] ?? 0;
  return c.op === '>=' ? v >= c.value : c.op === '>' ? v > c.value : v === c.value;
}

function nextMonday(): Date {
  const d = new Date(`${weekStart()}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 7);
  return d;
}

export async function adminInsightRoutes(app: FastifyInstance) {
  app.get('/v1/admin/dashboard', async (req) => {
    const bo = requireBo(req);
    return withTx(boActor(bo), async (tx) => {
      const expired = ['superadmin', 'content_admin'].includes(bo.role) ? await expireValidations(tx) : 0;
      const latestItems = (await tx.query('SELECT DISTINCT ON (id) * FROM content_items ORDER BY id, version DESC')).rows;
      const totalContent = latestItems.filter((r) => ['template', 'question'].includes(r.kind)).length;
      const myDrafts = latestItems.filter((r) => r.author_id === bo.accountId && ['draft', 'changes_requested'].includes(r.state)).map((r) => ({ id: r.id, title: r.title, state: r.state, kind: r.kind, updatedAt: r.updated_at }));
      const pendingReviews = latestItems.filter((r) => r.state === 'in_review' && (bo.role !== 'reviewer' || ((!r.sector_id || r.sector_id === 'comun' || bo.sectors.includes(r.sector_id)) && r.author_id !== bo.accountId)))
        .map((r) => ({ id: r.id, title: r.title, kind: r.kind, sectorId: r.sector_id, exerciseTypeId: r.data?.exerciseTypeId ?? null, since: r.submitted_at ?? r.updated_at }));
      const changesRequested = latestItems.filter((r) => r.state === 'changes_requested' && (bo.role !== 'author' || r.author_id === bo.accountId)).map((r) => ({ id: r.id, title: r.title }));
      const showQuality = ['superadmin', 'content_admin', 'analyst', 'reviewer', 'author'].includes(bo.role);
      const stats = showQuality ? await itemStats(tx) : [];
      const alerts = stats.filter((s) => s.alerts.length || s.reports >= 3).flatMap((s) => [
        ...s.alerts.map((a) => ({ severity: a.includes('Acierto al primer intento del') && (s.firstAttemptAccuracy ?? 100) < 40 ? 'alta' : 'media', itemId: s.itemId, title: s.title, reason: a, sectorId: s.sectorId, exerciseTypeId: s.exerciseTypeId })),
        ...(s.reports >= 3 ? [{ severity: 'baja', itemId: s.itemId, title: s.title, reason: `${s.reports} avisos de error`, sectorId: s.sectorId, exerciseTypeId: s.exerciseTypeId }] : []),
      ]);
      const expiredItems = latestItems.filter((r) => r.state === 'in_review' && r.validated_until && new Date(r.validated_until) < new Date()).map((r) => ({ severity: 'media', itemId: r.id, title: r.title, reason: 'Validación caducada: vuelve a revisión' }));
      const catalog = (await tx.query(
        `SELECT sector_id, count(*) FILTER (WHERE state = 'published')::int AS published, count(*)::int AS total FROM (SELECT DISTINCT ON (id) * FROM content_items WHERE kind IN ('template','question') ORDER BY id, version DESC) x GROUP BY sector_id`)).rows;
      const activity = (await tx.query(
        `SELECT count(DISTINCT user_id)::int AS users, count(DISTINCT session_id)::int AS sessions,
           round(100.0 * count(*) FILTER (WHERE attempt_number = 1 AND verdict IN ('correct','correct_note')) / nullif(count(*) FILTER (WHERE attempt_number = 1), 0))::int AS accuracy
         FROM attempts WHERE server_time > now() - interval '7 days'`)).rows[0];
      const lastRelease = ['superadmin', 'content_admin'].includes(bo.role) ? (await tx.query("SELECT number, published_at, rollout_pct FROM releases WHERE state = 'published' ORDER BY published_at DESC LIMIT 1")).rows[0] ?? null : null;
      const inquiriesOpen = Number((await tx.query("SELECT count(*) AS c FROM inquiries WHERE status <> 'answered'")).rows[0].c);
      return {
        role: bo.role, empty: totalContent === 0,
        onboarding: totalContent === 0 ? [
          { step: 1, title: 'Crea el primer sector', done: latestItems.some((r) => r.kind === 'sector') },
          { step: 2, title: 'Añade un itinerario', done: latestItems.some((r) => r.kind === 'itinerary') },
          { step: 3, title: 'Escribe una plantilla', done: latestItems.some((r) => r.kind === 'template') },
          { step: 4, title: 'Envíala a revisión', done: latestItems.some((r) => r.kind === 'template' && r.state !== 'draft') },
          { step: 5, title: 'Publica la primera versión', done: Boolean(lastRelease) },
        ] : null,
        myWork: { drafts: myDrafts, pendingReviews, changesRequested },
        alerts: [...alerts, ...expiredItems].slice(0, 30), expiredNow: expired,
        catalog, activity, lastRelease, inquiriesOpen, updatedAt: new Date().toISOString(),
      };
    });
  });

  app.get<{ Querystring: { sort?: string; sector?: string; dir?: string } }>('/v1/admin/analytics/items', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst', 'author', 'reviewer']);
    return withTx(boActor(bo), async (tx) => {
      let rows = await itemStats(tx, { sector: req.query.sector });
      if (bo.role === 'author') {
        const mine = new Set((await tx.query('SELECT DISTINCT id FROM content_items WHERE author_id = $1', [bo.accountId])).rows.map((r) => r.id));
        rows = rows.filter((r) => mine.has(r.itemId));
      }
      if (bo.role === 'reviewer') rows = rows.filter((r) => !r.sectorId || r.sectorId === 'comun' || bo.sectors.includes(r.sectorId));
      const key = (req.query.sort ?? 'firstAttemptAccuracy') as keyof ItemStats;
      const dir = req.query.dir === 'desc' ? -1 : 1;
      rows.sort((a, b) => {
        const x = a[key] as number | null; const y = b[key] as number | null;
        if (x === null && y === null) return 0; if (x === null) return 1; if (y === null) return -1;
        return (x - y) * dir;
      });
      return { items: rows };
    });
  });

  app.get<{ Params: { id: string } }>('/v1/admin/analytics/items/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst', 'author', 'reviewer']);
    return withTx(boActor(bo), async (tx) => {
      const stat = (await itemStats(tx)).find((s) => s.itemId === req.params.id);
      if (!stat) throw notFound();
      const wrong = (await tx.query(
        `SELECT answer_value AS value, answer_unit AS unit, error_code AS code, count(*)::int AS n FROM attempts WHERE coalesce(template_id, question_id) = $1 AND verdict = 'incorrect' AND attempt_number = 1
         GROUP BY 1,2,3 ORDER BY n DESC LIMIT 20`, [req.params.id])).rows;
      const byLevel = (await tx.query(`SELECT level, count(*)::int AS n, round(100.0 * avg(CASE WHEN verdict IN ('correct','correct_note') THEN 1 ELSE 0 END))::int AS acc FROM attempts WHERE coalesce(template_id, question_id) = $1 AND attempt_number = 1 GROUP BY level ORDER BY level`, [req.params.id])).rows;
      const byInput = (await tx.query(`SELECT input_mode, count(*)::int AS n, round(100.0 * avg(CASE WHEN verdict IN ('correct','correct_note') THEN 1 ELSE 0 END))::int AS acc FROM attempts WHERE coalesce(template_id, question_id) = $1 AND attempt_number = 1 GROUP BY input_mode`, [req.params.id])).rows;
      const byVariant = (await tx.query(`SELECT variant_id, count(*)::int AS n, round(100.0 * avg(CASE WHEN verdict IN ('correct','correct_note') THEN 1 ELSE 0 END))::int AS acc FROM attempts WHERE coalesce(template_id, question_id) = $1 AND attempt_number = 1 GROUP BY variant_id HAVING count(*) >= 5 ORDER BY acc LIMIT 10`, [req.params.id])).rows;
      const times = (await tx.query(`SELECT width_bucket(response_ms, 0, 120000, 12) AS b, count(*)::int AS n FROM attempts WHERE coalesce(template_id, question_id) = $1 AND attempt_number = 1 GROUP BY 1 ORDER BY 1`, [req.params.id])).rows;
      const byVersion = (await tx.query(`SELECT content_version, count(*)::int AS n, round(100.0 * avg(CASE WHEN verdict IN ('correct','correct_note') THEN 1 ELSE 0 END))::int AS acc FROM attempts WHERE coalesce(template_id, question_id) = $1 AND attempt_number = 1 GROUP BY 1 ORDER BY 1`, [req.params.id])).rows;
      const lowVariant = byVariant.filter((v) => stat.firstAttemptAccuracy !== null && v.acc < stat.firstAttemptAccuracy - 30);
      return { stat, wrongAnswers: wrong, byLevel, byInput, byVariant, lowVariants: lowVariant, timeDistribution: times, byVersion, summary: stat.insufficient ? 'Datos insuficientes: menos de 50 respuestas' : `Acierto al primer intento del ${Math.round(stat.firstAttemptAccuracy ?? 0)} % en ${stat.responses} respuestas` };
    });
  });

  /** «Añadir como error previsible» desde la ficha de analítica: crea una versión nueva en borrador. */
  app.post<{ Params: { id: string }; Body: { value: string; unit: string; code: string; message: string; formula?: string } }>('/v1/admin/analytics/items/:id/promote-error', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const b = req.body;
    if (!b?.code || !b.message) throw bad('invalid', 'Indica el tipo de error y su mensaje');
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.id);
      const data = structuredClone(cur.data) as Record<string, unknown>;
      if (cur.kind === 'template') {
        const t = data as unknown as TemplateDefinition;
        if (!b.formula) throw bad('formula_required', 'En una plantilla, el error previsible se define con su fórmula');
        t.predictedErrors = [...t.predictedErrors, { formula: b.formula, unit: b.unit, code: b.code as never, message: b.message }];
      } else {
        const q = data as unknown as QuestionDefinition;
        q.predictedErrors = [...(q.predictedErrors ?? []), { value: b.value, unit: b.unit, code: b.code as never, message: b.message }];
      }
      const item = await updateItem(tx, bo, cur.id, data);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'analytics.promote_error', entity: cur.kind, entityId: cur.id, after: b });
      return { itemId: item.id, version: item.version };
    });
  });

  app.get('/v1/admin/analytics/alerts', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst']);
    return withTx(boActor(bo), async (tx) => ({ items: (await itemStats(tx)).filter((s) => s.alerts.length) }));
  });

  // ------------------------------------------------------------------ Anuncios
  app.get('/v1/admin/ads/params', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst']);
    return withTx(boActor(bo), async (tx) => ({ params: await getSetting<AdParams>(tx, 'ad_params', { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 }) }));
  });

  app.put<{ Body: AdParams }>('/v1/admin/ads/params', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const p = req.body;
    if (!(p.waitS >= 0 && p.waitS <= 5)) throw bad('invalid_wait', 'La espera va de 0 a 5 segundos');
    if (!(p.frequencyTouch >= 1) || !(p.frequencyVoice >= 1)) throw bad('invalid_frequency', 'La frecuencia es 1 (cada ejercicio) o superior');
    return withTx(boActor(bo), async (tx) => {
      const before = await getSetting<AdParams>(tx, 'ad_params', p);
      await tx.query("INSERT INTO settings(key, value, updated_by) VALUES ('ad_params', $1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()", [JSON.stringify(p), bo.accountId]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'ads.params', entity: 'settings', entityId: 'ad_params', before, after: p });
      return { params: p, note: 'Los cambios llegan a las apps con la siguiente publicación de contenido' };
    });
  });

  app.get('/v1/admin/ads/performance', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst']);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query(
        `SELECT props->>'adId' AS ad, count(*) FILTER (WHERE name = 'ad_impression')::int AS impressions, count(*) FILTER (WHERE name = 'ad_cta_tapped')::int AS taps,
           round(avg((props->>'dwellMs')::numeric) FILTER (WHERE name = 'ad_impression'))::int AS avg_dwell_ms,
           count(*) FILTER (WHERE name = 'ad_voice_skipped')::int AS voice_skipped, count(*) FILTER (WHERE name = 'ad_voice_more_info')::int AS voice_more_info
         FROM events WHERE name LIKE 'ad_%' GROUP BY 1 ORDER BY 2 DESC`)).rows;
      const conv = (await tx.query("SELECT attributed_ad_id AS ad, count(*) FILTER (WHERE kind = 'trial_start')::int AS trials, count(*) FILTER (WHERE kind = 'purchase' AND result = 'ok')::int AS purchases FROM store_transactions WHERE attributed_ad_id IS NOT NULL GROUP BY 1")).rows;
      return { items: rows.map((r) => ({ ...r, trials: conv.find((c) => c.ad === r.ad)?.trials ?? 0, purchases: conv.find((c) => c.ad === r.ad)?.purchases ?? 0 })) };
    });
  });

  // ------------------------------------------------------------------ Logros y ligas
  app.post<{ Body: { condition: { metric: AchievementMetric; op: '>=' | '>' | '=='; value: number }; userId?: string; sample?: Partial<Record<AchievementMetric, number>> } }>('/v1/admin/achievements/test', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const metrics = req.body.userId ? await userMetrics(tx, req.body.userId) : (req.body.sample ?? {});
      const obtains = evaluateCondition(req.body.condition, metrics);
      const v = metrics[req.body.condition.metric] ?? 0;
      return { obtains, value: v, message: obtains ? `Lo obtendría: ${v} ${req.body.condition.op} ${req.body.condition.value}` : `No lo obtendría: tiene ${v} y la condición pide ${req.body.condition.op} ${req.body.condition.value}` };
    });
  });

  app.get('/v1/admin/leagues/config', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const next = (await tx.query("SELECT value, effective_from FROM settings WHERE key = 'league_config_next'")).rows[0] ?? null;
      return { current: await leagueConfigFor(tx), scheduled: next && new Date(next.effective_from) > new Date() ? next : null };
    });
  });

  app.put<{ Body: LeagueConfig }>('/v1/admin/leagues/config', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const c = req.body;
    if (!(c.groupSize > 1) || !(c.dailyCap > 0) || !c.divisions?.length) throw bad('invalid', 'Configuración de liga incompleta');
    return withTx(boActor(bo), async (tx) => {
      const before = await leagueConfigFor(tx);
      const from = nextMonday();
      // Los cambios entran en vigor al comenzar la semana siguiente, nunca a mitad de semana.
      const cur = (await tx.query("SELECT value, effective_from FROM settings WHERE key = 'league_config_next'")).rows[0];
      if (cur && new Date(cur.effective_from) <= new Date()) {
        await tx.query("UPDATE settings SET value = $1, updated_at = now() WHERE key = 'league_config'", [JSON.stringify(cur.value)]);
      }
      await tx.query("INSERT INTO settings(key, value, effective_from, updated_by) VALUES ('league_config_next', $1, $2, $3) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, effective_from = EXCLUDED.effective_from, updated_by = EXCLUDED.updated_by, updated_at = now()", [JSON.stringify(c), from, bo.accountId]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'league.config_scheduled', entity: 'settings', entityId: 'league_config', before, after: { ...c, effectiveFrom: from.toISOString() } });
      return { scheduledFrom: from.toISOString(), message: `El cambio se aplica desde el lunes ${from.toISOString().slice(0, 10)}` };
    });
  });

  app.get('/v1/admin/leagues/week', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'analyst']);
    return withTx(boActor(bo), async (tx) => {
      const ws = weekStart();
      const groups = (await tx.query(
        `SELECT g.id, g.division, g.sector_id, count(m.user_id)::int AS members, coalesce(sum(m.points),0)::int AS points FROM league_groups g LEFT JOIN league_members m ON m.group_id = g.id
         WHERE g.week_start = $1 AND g.private_league_id IS NULL GROUP BY g.id ORDER BY g.division, g.sector_id`, [ws])).rows;
      return { week: ws, groups };
    });
  });

  app.get('/v1/admin/leagues/flagged', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => ({ items: (await tx.query("SELECT f.*, u.alias FROM league_flags f JOIN users u ON u.id = f.user_id ORDER BY created_at DESC")).rows }));
  });

  app.post<{ Params: { id: string }; Body: { decision: 'cleared' | 'confirmed'; reason: string } }>('/v1/admin/leagues/flagged/:id/resolve', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    if (!req.body?.reason?.trim()) throw bad('reason_required', 'Indica el motivo');
    return withTx(boActor(bo), async (tx) => {
      const f = (await tx.query('SELECT * FROM league_flags WHERE id = $1', [req.params.id])).rows[0];
      if (!f) throw notFound();
      await tx.query('UPDATE league_flags SET status = $2, resolved_by = $3, resolved_at = now() WHERE id = $1', [f.id, req.body.decision, bo.accountId]);
      await tx.query('UPDATE attempts SET league_status = $2 WHERE id = ANY($1::uuid[])', [f.attempt_ids, req.body.decision === 'cleared' ? 'counted' : 'excluded']);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: `league.flag_${req.body.decision}`, entity: 'league_flag', entityId: f.id, reason: req.body.reason });
      return { ok: true };
    });
  });

  app.post<{ Body: { weekStart?: string } }>('/v1/admin/leagues/close-week', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    return withTx(boActor(bo), async (tx) => {
      const ws = req.body?.weekStart ?? weekStart(new Date(Date.now() - 7 * 86400000));
      const res = await closeWeek(tx, ws);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'league.close_week', entity: 'league', entityId: ws, after: res });
      return { week: ws, groups: res };
    });
  });

  // ------------------------------------------------------------------ Auditoría
  app.get<{ Querystring: { actor?: string; action?: string; entity?: string; from?: string; to?: string; limit?: string } }>('/v1/admin/audit', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => ({
      items: (await tx.query(
        `SELECT l.*, a.name AS actor_name FROM audit_log l LEFT JOIN bo_accounts a ON a.id = l.actor_id
         WHERE ($1::uuid IS NULL OR l.actor_id = $1) AND ($2::text IS NULL OR l.action LIKE $2 || '%') AND ($3::text IS NULL OR l.entity = $3)
           AND ($4::timestamptz IS NULL OR l.at >= $4) AND ($5::timestamptz IS NULL OR l.at <= $5)
         ORDER BY l.id DESC LIMIT $6`,
        [req.query.actor || null, req.query.action || null, req.query.entity || null, req.query.from || null, req.query.to || null, Math.min(Number(req.query.limit ?? 200), 2000)],
      )).rows,
    }));
  });

  app.get('/v1/admin/audit/export', async (req, reply) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const rows = await withTx(boActor(bo), async (tx) => (await tx.query('SELECT l.id, l.at, a.name AS actor, l.actor_role, l.action, l.entity, l.entity_id, l.reason, l.before, l.after FROM audit_log l LEFT JOIN bo_accounts a ON a.id = l.actor_id ORDER BY l.id')).rows);
    const esc = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`;
    reply.header('Content-Type', 'text/csv; charset=utf-8').header('Content-Disposition', 'attachment; filename="auditoria.csv"');
    return ['id;fecha;autor;rol;acción;elemento;identificador;motivo;antes;después', ...rows.map((r) => [r.id, new Date(r.at).toISOString(), r.actor, r.actor_role, r.action, r.entity, r.entity_id, r.reason, JSON.stringify(r.before), JSON.stringify(r.after)].map(esc).join(';'))].join('\n');
  });
}
