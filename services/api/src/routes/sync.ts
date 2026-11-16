/** Sincronización por lotes, idempotente por identificador (offline-sync, diseño D5 y D6). */
import type { FastifyInstance } from 'fastify';
import type { Attempt, SyncPushRequest, SyncPushResponse, AnalyticsEvent } from '@vtm/contracts';
import { withTx, SYSTEM } from '../db/pool.js';
import { bad } from '../lib/errors.js';
import { appActor, requireUser } from '../server.js';
import { rolloutBucket } from '../lib/crypto.js';

const MAX_BATCH = 500;

export async function syncRoutes(app: FastifyInstance) {
  app.post<{ Body: SyncPushRequest }>('/v1/sync/push', async (req): Promise<SyncPushResponse> => {
    const u = requireUser(req);
    const b = req.body;
    if (!b?.deviceId) throw bad('device_required', 'Falta el identificador del dispositivo');
    const attempts = b.attempts ?? [];
    const sessions = b.sessions ?? [];
    const events = b.events ?? [];
    if (attempts.length > MAX_BATCH) throw bad('batch_too_large', `Lotes de ${MAX_BATCH} intentos como máximo`);
    return withTx(appActor(req), async (tx) => {
      let accA = 0; let accS = 0; let accE = 0;
      for (const a of attempts) {
        const r = await tx.query(
          `INSERT INTO attempts(id, user_id, device_id, session_id, mode, lesson_id, template_id, question_id, variant_id, skill_id, exercise_type_id, level, attempt_number,
             answer_value, answer_unit, answer_payload, verdict, error_code, critical, hints_used, response_ms, target_ms, input_mode, voice_metrics, points, content_version, device_time)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27) ON CONFLICT (id) DO NOTHING`,
          [a.id, u.userId, b.deviceId, a.sessionId, a.mode, a.lessonId, a.templateId, a.questionId, a.variantId, a.skillId, a.exerciseTypeId, a.level, a.attemptNumber,
            a.answerValue, a.answerUnit, a.answerPayload === undefined ? null : JSON.stringify(a.answerPayload), a.verdict, a.errorCode, a.critical, a.hintsUsed, Math.round(a.responseMs), Math.round(a.targetMs), a.inputMode,
            a.voiceMetrics ? JSON.stringify(a.voiceMetrics) : null, a.points, a.contentVersion, a.deviceTime],
        );
        accA += r.rowCount ?? 0;
      }
      for (const s of sessions) {
        const r = await tx.query(
          'INSERT INTO learning_sessions(id, user_id, device_id, record, mode, started_at, ended_at) VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (id) DO NOTHING',
          [s.id, u.userId, b.deviceId, JSON.stringify(s), s.mode, s.startedAt, s.endedAt],
        );
        accS += r.rowCount ?? 0;
      }
      for (const e of events) {
        const r = await tx.query('INSERT INTO events(id, user_id, device_id, name, at, props) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (id) DO NOTHING', [e.id, u.userId, b.deviceId, e.name, e.at, JSON.stringify(e.props ?? {})]);
        accE += r.rowCount ?? 0;
      }
      await tx.query(
        `INSERT INTO devices(id, user_id, app_version, rollout_bucket, last_sync_at) VALUES ($1,$2,$3,$4, now())
         ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, app_version = coalesce(EXCLUDED.app_version, devices.app_version), last_sync_at = now()`,
        [b.deviceId, u.userId, b.appVersion ?? null, rolloutBucket(b.deviceId)],
      );
      return {
        accepted: { attempts: accA, sessions: accS, events: accE },
        duplicates: { attempts: attempts.length - accA, sessions: sessions.length - accS, events: events.length - accE },
        serverTime: new Date().toISOString(),
      };
    });
  });

  app.get<{ Querystring: { cursor?: string; limit?: string } }>('/v1/sync/pull', async (req) => {
    const u = requireUser(req);
    const [aCur, sCur] = String(req.query.cursor ?? '0:0').split(':').map((x) => Number(x) || 0);
    const limit = Math.min(Number(req.query.limit ?? 2000), 5000);
    return withTx(appActor(req), async (tx) => {
      const ar = (await tx.query('SELECT * FROM attempts WHERE user_id = $1 AND seq > $2 ORDER BY seq LIMIT $3', [u.userId, aCur, limit])).rows;
      const sr = (await tx.query('SELECT seq, record FROM learning_sessions WHERE user_id = $1 AND seq > $2 ORDER BY seq LIMIT $3', [u.userId, sCur, limit])).rows;
      const attempts: Attempt[] = ar.map((r) => ({
        id: r.id, sessionId: r.session_id, deviceId: r.device_id, mode: r.mode, lessonId: r.lesson_id, templateId: r.template_id, questionId: r.question_id,
        variantId: r.variant_id, skillId: r.skill_id, exerciseTypeId: r.exercise_type_id, level: r.level, attemptNumber: r.attempt_number,
        answerValue: r.answer_value, answerUnit: r.answer_unit, answerPayload: r.answer_payload ?? undefined, verdict: r.verdict, errorCode: r.error_code,
        critical: r.critical, hintsUsed: r.hints_used, responseMs: r.response_ms, targetMs: r.target_ms, inputMode: r.input_mode, voiceMetrics: r.voice_metrics,
        points: r.points, contentVersion: r.content_version, deviceTime: new Date(r.device_time).toISOString(),
      }));
      const nextA = ar.length ? Number(ar[ar.length - 1].seq) : aCur;
      const nextS = sr.length ? Number(sr[sr.length - 1].seq) : sCur;
      return { attempts, sessions: sr.map((r) => r.record), cursor: `${nextA}:${nextS}`, hasMore: ar.length === limit || sr.length === limit };
    });
  });

  app.post<{ Body: { deviceId: string; events: AnalyticsEvent[] } }>('/v1/events', async (req) => {
    const b = req.body;
    if (!b?.deviceId) throw bad('device_required', 'Falta el identificador del dispositivo');
    return withTx(SYSTEM, async (tx) => {
      let accepted = 0;
      for (const e of (b.events ?? []).slice(0, 1000)) {
        const r = await tx.query('INSERT INTO events(id, user_id, device_id, name, at, props) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (id) DO NOTHING', [e.id, req.appUser?.userId ?? null, b.deviceId, e.name, e.at, JSON.stringify(e.props ?? {})]);
        accepted += r.rowCount ?? 0;
      }
      return { accepted };
    });
  });
}
