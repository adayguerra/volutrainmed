/** Publicación versionada, despliegue gradual, reversión, retirada y tipos de ejercicio. */
import type { FastifyInstance } from 'fastify';
import { VOICE_COMPATIBLE_RESPONSES, type ExerciseType } from '@vtm/contracts';
import { withTx, type Tx } from '../db/pool.js';
import { ApiError, bad, conflict, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { shortCode } from '../lib/crypto.js';
import { requireBo, boActor, type BoCtx } from '../server.js';
import { buildFromSnapshot, cmpVersion, compatibility, nextReleaseNumber, snapshot, storePackages, summarizeChecks, type Snapshot } from '../publish/service.js';
import { createItem, latest, updateItem } from '../services/items.js';
import type { CheckResult } from '../publish/build.js';

const PUBLISHERS = ['superadmin', 'content_admin'] as const;

function releaseView(r: Record<string, unknown>) {
  return {
    id: r.id, number: r.number, state: r.state, notes: r.notes, rolloutPct: r.rollout_pct, minAppVersion: r.min_app_version, items: r.items, diff: r.diff,
    checks: r.checks, testCode: r.test_code, createdAt: r.created_at, publishedAt: r.published_at, rolledBackReason: r.rolled_back_reason,
  };
}

async function activeRelease(tx: Tx) {
  return (await tx.query("SELECT * FROM releases WHERE state = 'published' ORDER BY published_at DESC LIMIT 1")).rows[0] ?? null;
}

function computeDiff(snap: Snapshot, activeItems: { id: string; version: number; title?: string; kind?: string }[]) {
  const act = new Map(activeItems.map((i) => [i.id, i]));
  const now = new Map(snap.included.map((i) => [i.id, i]));
  return {
    added: snap.included.filter((i) => !act.has(i.id)),
    changed: snap.included.filter((i) => act.has(i.id) && act.get(i.id)!.version !== i.version),
    retired: activeItems.filter((i) => !now.has(i.id)),
    excluded: snap.excluded,
  };
}

/** Comprobaciones automáticas: variantes, doble cálculo, colisiones, explicación, voz, compatibilidad y tamaño. */
async function runChecks(tx: Tx, release: Record<string, unknown>) {
  const snap = await snapshot(tx);
  const build = await buildFromSnapshot(tx, snap, String(release.number), String(release.min_app_version));
  const compat = await compatibility(tx, String(release.min_app_version));
  const sizes = build.itineraries.map((p) => ({ id: p.itinerary.id, bytes: Buffer.byteLength(JSON.stringify(p)) }));
  const checks: CheckResult[] = [
    ...build.checks,
    { id: 'compat', label: 'Versión mínima de la app y dispositivos compatibles', ok: true, detail: `${compat.pct} % de los dispositivos activos admite la versión ${release.min_app_version} (${compat.compatible} de ${compat.total})` },
    { id: 'size', label: 'Tamaño del paquete', ok: sizes.every((s) => s.bytes < 60 * 1024 * 1024), detail: sizes.map((s) => `${s.id}: ${(s.bytes / 1024).toFixed(0)} KB sin comprimir`).join(' · ') },
    { id: 'nothing', label: 'Hay cambios que publicar', ok: true, detail: `${snap.included.length} elementos validados` },
  ];
  return { snap, build, checks, compat };
}

export async function adminReleaseRoutes(app: FastifyInstance) {
  app.get('/v1/admin/releases', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query('SELECT * FROM releases ORDER BY created_at DESC')).rows;
      const snap = await snapshot(tx);
      const active = await activeRelease(tx);
      return { items: rows.map(releaseView), pending: computeDiff(snap, (active?.items as never) ?? []) };
    });
  });

  app.post<{ Body: { notes?: string; minAppVersion?: string } }>('/v1/admin/releases', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => {
      const snap = await snapshot(tx);
      const active = await activeRelease(tx);
      const diff = computeDiff(snap, (active?.items as never) ?? []);
      if (!diff.added.length && !diff.changed.length && !diff.retired.length && active) throw conflict('no_changes', 'Sin cambios que publicar');
      const number = await nextReleaseNumber(tx);
      const r = (await tx.query('INSERT INTO releases(number, notes, min_app_version, items, diff, created_by) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
        [number, req.body?.notes ?? null, req.body?.minAppVersion ?? '1.0.0', JSON.stringify(snap.included), JSON.stringify(diff), bo.accountId])).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.create', entity: 'release', entityId: r.id, after: { number, added: diff.added.length, changed: diff.changed.length, retired: diff.retired.length } });
      return { release: releaseView(r) };
    });
  });

  app.post<{ Params: { id: string } }>('/v1/admin/releases/:id/checks', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('SELECT * FROM releases WHERE id = $1', [req.params.id])).rows[0];
      if (!r) throw notFound();
      const { checks, compat } = await runChecks(tx, r);
      await tx.query('UPDATE releases SET checks = $2 WHERE id = $1', [r.id, JSON.stringify(checks)]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.checks', entity: 'release', entityId: r.id, after: summarizeChecks(checks) });
      return { checks, summary: summarizeChecks(checks), compatibility: compat };
    });
  });

  app.post<{ Params: { id: string } }>('/v1/admin/releases/:id/test-package', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('SELECT * FROM releases WHERE id = $1', [req.params.id])).rows[0];
      if (!r) throw notFound();
      const { build, checks } = await runChecks(tx, r);
      const code = r.test_code ?? shortCode(8);
      await storePackages(tx, r.id, r.number, build);
      await tx.query("UPDATE releases SET test_code = $2, state = CASE WHEN state = 'preparing' THEN 'testing' ELSE state END, checks = $3 WHERE id = $1", [r.id, code, JSON.stringify(checks)]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.test_package', entity: 'release', entityId: r.id, after: { code } });
      return { testCode: code, qrPayload: `volutrainmed://paquete-prueba?codigo=${code}`, checks };
    });
  });

  app.post<{ Params: { id: string }; Body: { confirmName: string; rolloutPct?: number } }>('/v1/admin/releases/:id/publish', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('SELECT * FROM releases WHERE id = $1', [req.params.id])).rows[0];
      if (!r) throw notFound();
      if (!['preparing', 'testing'].includes(r.state)) throw conflict('invalid_state', 'Esta versión ya se ha publicado o revertido');
      if (req.body?.confirmName !== r.number) throw bad('confirm_name', `Escribe el nombre de la versión (${r.number}) para publicar`);
      const pct = Number(req.body?.rolloutPct ?? 100);
      if (![5, 50, 100].includes(pct)) throw bad('invalid_rollout', 'El despliegue gradual es del 5 %, del 50 % o del 100 %');
      const { snap, build, checks } = await runChecks(tx, r);
      const s = summarizeChecks(checks);
      if (!s.passed) throw new ApiError(422, 'checks_failed', `La publicación está bloqueada: ${checks.filter((c) => !c.ok).map((c) => c.detail).slice(0, 5).join(' · ')}`);
      await storePackages(tx, r.id, r.number, build);
      // Con despliegue parcial, la versión anterior sigue sirviendo al resto de dispositivos.
      if (pct >= 100) await tx.query("UPDATE releases SET state = 'superseded' WHERE state = 'published' AND id <> $1", [r.id]);
      await tx.query("UPDATE releases SET state = 'published', rollout_pct = $2, published_at = now(), checks = $3, items = $4 WHERE id = $1", [r.id, pct, JSON.stringify(checks), JSON.stringify(snap.included)]);
      for (const i of snap.included) await tx.query("UPDATE content_items SET state = 'published' WHERE id = $1 AND version = $2 AND state = 'validated'", [i.id, i.version]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.publish', entity: 'release', entityId: r.id, after: { number: r.number, rolloutPct: pct, items: snap.included.length } });
      return { release: releaseView((await tx.query('SELECT * FROM releases WHERE id = $1', [r.id])).rows[0]), checks };
    });
  });

  app.post<{ Params: { id: string }; Body: { rolloutPct: number } }>('/v1/admin/releases/:id/rollout', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    const pct = Number(req.body?.rolloutPct);
    if (![5, 50, 100].includes(pct)) throw bad('invalid_rollout', 'El despliegue gradual es del 5 %, del 50 % o del 100 %');
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query("SELECT * FROM releases WHERE id = $1 AND state = 'published'", [req.params.id])).rows[0];
      if (!r) throw notFound('La versión no está publicada');
      await tx.query('UPDATE releases SET rollout_pct = $2 WHERE id = $1', [r.id, pct]);
      if (pct >= 100) await tx.query("UPDATE releases SET state = 'superseded' WHERE state = 'published' AND id <> $1", [r.id]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.rollout', entity: 'release', entityId: r.id, before: { rolloutPct: r.rollout_pct }, after: { rolloutPct: pct } });
      return { ok: true, rolloutPct: pct };
    });
  });

  app.post<{ Body: { reason: string } }>('/v1/admin/releases/rollback', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    if (!req.body?.reason?.trim()) throw bad('reason_required', 'Indica el motivo de la reversión');
    return withTx(boActor(bo), async (tx) => {
      const cur = await activeRelease(tx);
      if (!cur) throw conflict('nothing', 'No hay ninguna versión publicada');
      const prev = (await tx.query("SELECT * FROM releases WHERE state IN ('published','superseded') AND id <> $2 AND published_at < $1 ORDER BY published_at DESC LIMIT 1", [cur.published_at, cur.id])).rows[0];
      if (!prev) throw conflict('no_previous', 'No hay una versión anterior a la que volver');
      await tx.query("UPDATE releases SET state = 'rolled_back', rolled_back_reason = $2 WHERE id = $1", [cur.id, req.body.reason]);
      await tx.query("UPDATE releases SET state = 'published', rollout_pct = 100, published_at = now() WHERE id = $1", [prev.id]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'release.rollback', entity: 'release', entityId: cur.id, before: { number: cur.number }, after: { number: prev.number }, reason: req.body.reason });
      return { rolledBack: cur.number, active: prev.number };
    });
  });

  app.post<{ Body: { kind: 'template' | 'question' | 'variant'; itemId: string; reason: string; inquiryId?: string } }>('/v1/admin/revocations', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    const b = req.body;
    if (!b?.itemId || !b.reason?.trim()) throw bad('invalid', 'Indica el ejercicio y el motivo');
    return withTx(boActor(bo), async (tx) => withdraw(tx, bo, b.kind, b.itemId, b.reason, b.inquiryId));
  });

  app.get('/v1/admin/revocations', async (req) => {
    const bo = requireBo(req, [...PUBLISHERS]);
    return withTx(boActor(bo), async (tx) => ({ items: (await tx.query('SELECT * FROM revocations ORDER BY id DESC')).rows }));
  });

  app.get<{ Querystring: { minAppVersion?: string } }>('/v1/admin/releases/compat', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), (tx) => compatibility(tx, req.query.minAppVersion ?? '1.0.0'));
  });

  // ------------------------------------------------------------------ Creador de tipos de ejercicio
  app.get('/v1/admin/exercise-types', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'author', 'reviewer', 'analyst']);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query("SELECT DISTINCT ON (id) * FROM content_items WHERE kind = 'exercise_type' ORDER BY id, version DESC")).rows;
      const usage = (await tx.query("SELECT data->>'exerciseTypeId' AS t, count(*)::int AS n, count(*) FILTER (WHERE state = 'published')::int AS published FROM content_items WHERE kind IN ('template','question') GROUP BY 1")).rows;
      return { items: rows.map((r) => ({ id: r.id, version: r.version, state: r.state, data: r.data, usage: usage.find((u) => u.t === r.id)?.n ?? 0, publishedUsage: usage.find((u) => u.t === r.id)?.published ?? 0 })), voiceCompatibleResponses: VOICE_COMPATIBLE_RESPONSES };
    });
  });

  app.post<{ Body: ExerciseType }>('/v1/admin/exercise-types', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const t = normalizeType(req.body);
    return withTx(boActor(bo), async (tx) => {
      const item = await createItem(tx, bo, 'exercise_type', t as never);
      const compat = await compatibility(tx, t.minAppVersion);
      return { item, compatibility: compat };
    });
  });

  app.put<{ Params: { id: string }; Body: ExerciseType }>('/v1/admin/exercise-types/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.id);
      const t = normalizeType({ ...req.body, id: req.params.id, version: cur.state === 'published' ? cur.version + 1 : cur.version });
      // Un tipo en uso se conserva: su cambio crea una versión nueva y el contenido publicado sigue con la anterior.
      const item = await updateItem(tx, bo, req.params.id, t as never);
      return { item, compatibility: await compatibility(tx, t.minAppVersion) };
    });
  });
}

/** Compatibilidad con voz calculada: solo si todos los bloques de respuesta admiten voz. */
export function normalizeType(t: ExerciseType): ExerciseType {
  const steps = t.steps ?? [];
  const missing = steps.findIndex((s) => !s.response);
  if (!steps.length) throw new ApiError(422, 'no_steps', 'El tipo necesita al menos un paso');
  if (missing >= 0) throw new ApiError(422, 'step_without_response', `Paso ${missing + 1}: falta el bloque de respuesta`);
  return { ...t, version: t.version ?? 1, voiceCompatible: steps.every((s) => VOICE_COMPATIBLE_RESPONSES.includes(s.response)), minAppVersion: t.minAppVersion || '1.0.0', behaviour: t.behaviour ?? [] };
}

export async function withdraw(tx: Tx, bo: BoCtx, kind: 'template' | 'question' | 'variant', itemId: string, reason: string, inquiryId?: string) {
  const r = (await tx.query('INSERT INTO revocations(kind, item_id, reason, created_by) VALUES ($1,$2,$3,$4) RETURNING *', [kind, itemId, reason, bo.accountId])).rows[0];
  if (inquiryId) await tx.query("UPDATE inquiries SET status = 'in_review', linked_item_id = $2 WHERE id = $1", [inquiryId, itemId]);
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.withdraw_now', entity: kind, entityId: itemId, reason });
  return { revocation: r };
}

export { cmpVersion };
