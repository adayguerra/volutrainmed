/**
 * Servicio de publicación (content-review-publishing).
 * Una versión es una foto del contenido validado y vigente. Al publicar se
 * generan las variantes, se recalculan con el motor independiente, se firman los
 * paquetes por itinerario y se despliegan de forma gradual (5 %, 50 %, 100 %).
 */
import type { AdCampaign, AdCreative, AdParams, ContentManifest, ExerciseType, FreePlanRules, Instrument, ItinerarySummary, LeagueConfig, MeasureUnit, Revocations, Sector, Skill, VoiceLexicon, Achievement } from '@vtm/contracts';
import type { QuestionDefinition, TemplateDefinition } from '@vtm/engine';
import type { Tx } from '../db/pool.js';
import { buildContent, signPackage, type BuildOutput, type CheckResult, type LessonSeed, type UnitInput } from './build.js';
import { loadOrCreateKeys } from '../lib/keys.js';
import { rolloutBucket } from '../lib/crypto.js';
import { SKILLS } from '../seed/content.js';
import type { ItemRow } from '../services/items.js';

export interface Snapshot {
  included: { id: string; version: number; kind: string; title: string; fingerprint: string }[];
  excluded: { id: string; version: number; kind: string; title: string; reason: string }[];
  rows: ItemRow[];
}

const STATE_REASON: Record<string, string> = {
  draft: 'En borrador: no se ha enviado a revisión',
  in_review: 'Pendiente de validación por un revisor experto',
  changes_requested: 'Con cambios solicitados por el revisor',
};

/** Última versión validada y vigente de cada elemento no retirado. */
export async function snapshot(tx: Tx): Promise<Snapshot> {
  const all = (await tx.query('SELECT * FROM content_items ORDER BY id, version DESC')).rows as ItemRow[];
  const byId = new Map<string, ItemRow[]>();
  for (const r of all) (byId.get(r.id) ?? byId.set(r.id, []).get(r.id)!).push(r);
  const included: Snapshot['included'] = [];
  const excluded: Snapshot['excluded'] = [];
  const rows: ItemRow[] = [];
  const now = Date.now();
  for (const [id, vs] of byId) {
    const newest = vs[0]!;
    if (newest.state === 'retired') continue;
    const ok = vs.find((v) => ['validated', 'published'].includes(v.state) && (!v.validated_until || new Date(v.validated_until).getTime() > now));
    if (ok) {
      included.push({ id, version: ok.version, kind: ok.kind, title: ok.title, fingerprint: ok.fingerprint });
      rows.push(ok);
    }
    if (!ok || newest.version !== ok.version) {
      excluded.push({ id, version: newest.version, kind: newest.kind, title: newest.title, reason: STATE_REASON[newest.state] ?? `Estado: ${newest.state}` });
    }
  }
  return { included, excluded, rows };
}

export async function getSetting<T>(tx: Tx, key: string, fallback: T): Promise<T> {
  const r = (await tx.query('SELECT value, effective_from FROM settings WHERE key = $1', [key])).rows[0];
  return (r?.value as T) ?? fallback;
}

/** Configuración de liga vigente: los cambios entran en vigor el lunes siguiente. */
export async function leagueConfigFor(tx: Tx, at = new Date()): Promise<LeagueConfig> {
  const next = (await tx.query("SELECT value, effective_from FROM settings WHERE key = 'league_config_next'")).rows[0];
  if (next?.effective_from && new Date(next.effective_from) <= at) return next.value as LeagueConfig;
  return (await tx.query("SELECT value FROM settings WHERE key = 'league_config'")).rows[0]?.value as LeagueConfig;
}

export async function buildFromSnapshot(tx: Tx, snap: Snapshot, contentVersion: string, minAppVersion: string): Promise<BuildOutput> {
  const of = (k: string) => snap.rows.filter((r) => r.kind === k).sort((a, b) => a.ord - b.ord);
  const sectors = of('sector').map((r) => r.data as unknown as Sector);
  const itineraries = of('itinerary').map((r) => r.data as unknown as ItinerarySummary);
  const units: UnitInput[] = of('unit').map((r) => {
    const d = r.data as Record<string, unknown>;
    return {
      id: r.id, itineraryId: String(d.itineraryId), order: r.ord, name: String(d.name), description: String(d.description ?? ''), skills: (d.skills as never) ?? [],
      prerequisiteUnitId: (d.prerequisiteUnitId as string | null) ?? null, guide: (d.guide as never) ?? { equivalences: [], example: { statement: '', steps: [], answer: '' } },
      templateIds: ((d.templateIds as string[]) ?? []).filter((t) => snap.included.some((i) => i.id === t)),
      questionIds: ((d.questionIds as string[]) ?? []).filter((q) => snap.included.some((i) => i.id === q)),
    };
  });
  // Requisito previo: la unidad anterior del mismo itinerario.
  for (const it of itineraries) {
    const us = units.filter((u) => u.itineraryId === it.id).sort((a, b) => a.order - b.order);
    us.forEach((u, i) => { u.order = i + 1; u.prerequisiteUnitId = i === 0 ? null : us[i - 1]!.id; });
  }
  const lessons: LessonSeed[] = of('lesson').map((r) => {
    const d = r.data as Record<string, unknown>;
    return { id: r.id, unitId: String(d.unitId), order: r.ord, kind: d.kind as never, title: String(d.title ?? ''), estimatedMinutes: Number(d.estimatedMinutes ?? 4), slots: (d.slots as never) ?? [], rule: d.rule === 'auto' ? 'auto' : undefined };
  });
  const campaigns: AdCampaign[] = of('ad_campaign').map((r) => ({ ...(r.data as unknown as AdCampaign), creatives: of('ad_creative').filter((c) => (c.data as Record<string, unknown>).campaignId === r.id).map((c) => c.data as unknown as AdCreative) }));
  const lexicon = of('voice_lexicon')[0]?.data as unknown as VoiceLexicon | undefined;
  return buildContent({
    contentVersion, minAppVersion, sectors, itineraries,
    // Las habilidades salen del catálogo validado; sin catálogo (bases antiguas) se usa la lista de serie.
    skills: of('catalog_skill').length
      ? of('catalog_skill').map((r) => ({ id: String((r.data as Record<string, unknown>).code) as Skill['id'], name: String((r.data as Record<string, unknown>).name), description: ((r.data as Record<string, unknown>).description as string | undefined) || undefined }))
          .sort((a, b) => Number(a.id.slice(1)) - Number(b.id.slice(1)))
      : SKILLS,
    // Tipos en uso versionados: viajan todas sus versiones vigentes y cada ejercicio usa la suya.
    exerciseTypes: (await tx.query("SELECT data, version FROM content_items WHERE kind = 'exercise_type' AND state IN ('validated','published') ORDER BY id, version")).rows
      .map((r) => ({ ...(r.data as ExerciseType), version: Number(r.version) })),
    units, lessons,
    templates: of('template').map((r) => ({ ...(r.data as unknown as TemplateDefinition), version: r.version })),
    questions: of('question').map((r) => ({ ...(r.data as unknown as QuestionDefinition), version: r.version })),
    measureUnits: of('catalog_unit').map((r) => r.data as unknown as MeasureUnit),
    instruments: of('catalog_instrument').map((r) => r.data as unknown as Instrument),
    voiceLexicon: lexicon ?? { confusions: [], commands: [], sectorSynonyms: [] },
    achievements: of('achievement').map((r) => r.data as unknown as Achievement),
    league: await leagueConfigFor(tx),
    adParams: await getSetting<AdParams>(tx, 'ad_params', { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 }),
    campaigns,
    freePlan: await getSetting<FreePlanRules>(tx, 'free_plan', { handsfreeDailyMinutes: 5, freeUnitsPerItinerary: 99 }),
    orgsEnabled: await getSetting<boolean>(tx, 'orgs_enabled', false),
  });
}

export function cmpVersion(a: string, b: string): number {
  const pa = a.split('.').map(Number); const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) { const d = (pa[i] ?? 0) - (pb[i] ?? 0); if (d) return d; }
  return 0;
}

/** Porcentaje de dispositivos activos (últimos 30 días) que admiten una versión mínima. */
export async function compatibility(tx: Tx, minAppVersion: string) {
  const rows = (await tx.query("SELECT app_version FROM devices WHERE last_sync_at > now() - interval '30 days' OR created_at > now() - interval '30 days'")).rows;
  const total = rows.length;
  const ok = rows.filter((r) => r.app_version && cmpVersion(r.app_version, minAppVersion) >= 0).length;
  return { total, compatible: ok, pct: total ? Math.round((ok / total) * 100) : 100 };
}

export async function storePackages(tx: Tx, releaseId: string, number: string, build: BuildOutput): Promise<void> {
  const keys = loadOrCreateKeys();
  const url = (id: string) => `/v1/content/files/${encodeURIComponent(id)}`;
  const blobs = [
    { it: '__global__', blob: signPackage(`${number}:global`, number, build.global.minAppVersion, build.global, keys.privateKey, url) },
    ...build.itineraries.map((p) => ({ it: p.itinerary.id, blob: signPackage(`${number}:${p.itinerary.id}`, number, p.minAppVersion, p, keys.privateKey, url) })),
  ];
  for (const { it, blob } of blobs) {
    await tx.query(
      `INSERT INTO packages(id, release_id, itinerary_id, version, sha256, signature, size, min_app_version, bytes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) ON CONFLICT (id) DO UPDATE SET sha256 = EXCLUDED.sha256, signature = EXCLUDED.signature, size = EXCLUDED.size, bytes = EXCLUDED.bytes`,
      [blob.file.id, releaseId, it, number, blob.file.sha256, blob.file.signature, blob.file.size, blob.file.minAppVersion, blob.bytes],
    );
  }
}

export async function revocations(tx: Tx): Promise<Revocations> {
  const rows = (await tx.query('SELECT id, kind, item_id FROM revocations WHERE active ORDER BY id')).rows;
  const maxId = Number((await tx.query('SELECT coalesce(max(id), 0) AS m FROM revocations')).rows[0].m);
  return {
    version: maxId,
    templateIds: rows.filter((r) => r.kind === 'template').map((r) => r.item_id),
    questionIds: rows.filter((r) => r.kind === 'question').map((r) => r.item_id),
    variantIds: rows.filter((r) => r.kind === 'variant').map((r) => r.item_id),
  };
}

export async function manifest(tx: Tx, deviceId: string, appVersion: string, testCode?: string): Promise<ContentManifest | null> {
  const keys = loadOrCreateKeys();
  const bucket = rolloutBucket(deviceId || 'anon');
  let release: Record<string, unknown> | undefined;
  let newer: string | null = null;
  if (testCode) {
    release = (await tx.query("SELECT * FROM releases WHERE test_code = $1 AND state IN ('testing','published')", [testCode])).rows[0];
  }
  if (!release) {
    const published = (await tx.query("SELECT * FROM releases WHERE state = 'published' ORDER BY published_at DESC")).rows;
    for (const r of published) {
      if (bucket >= Number(r.rollout_pct)) continue;
      if (cmpVersion(appVersion, String(r.min_app_version)) < 0) { newer ??= String(r.min_app_version); continue; }
      release = r;
      break;
    }
    // Sin ninguna versión aplicable por despliegue, la última al 100 % anterior.
    if (!release) release = published.find((r) => Number(r.rollout_pct) >= 100 && cmpVersion(appVersion, String(r.min_app_version)) >= 0) ?? (await tx.query("SELECT * FROM releases WHERE state = 'superseded' ORDER BY published_at DESC LIMIT 1")).rows[0];
  }
  if (!release) return null;
  const pkgs = (await tx.query('SELECT id, itinerary_id, version, sha256, signature, size, min_app_version FROM packages WHERE release_id = $1', [release.id])).rows;
  const toFile = (p: Record<string, unknown>) => ({ id: String(p.id), version: String(p.version), url: `/v1/content/files/${encodeURIComponent(String(p.id))}`, sha256: String(p.sha256), signature: String(p.signature), size: Number(p.size), minAppVersion: String(p.min_app_version) });
  const g = pkgs.find((p) => p.itinerary_id === '__global__');
  if (!g) return null;
  return {
    contentVersion: String(release.number), releaseId: String(release.id), rolloutBucket: bucket, publicKeyId: keys.keyId,
    global: toFile(g), packages: pkgs.filter((p) => p.itinerary_id !== '__global__').map((p) => ({ ...toFile(p), itineraryId: String(p.itinerary_id) })),
    revocations: await revocations(tx), newerRequiresAppVersion: newer, testPackage: Boolean(testCode && release.test_code === testCode && release.state === 'testing'),
  };
}

export function summarizeChecks(checks: CheckResult[]) {
  const failed = checks.filter((c) => !c.ok);
  return { passed: failed.length === 0, failed: failed.length, total: checks.length };
}

export async function nextReleaseNumber(tx: Tx): Promise<string> {
  const d = new Date();
  const prefix = `${d.getUTCFullYear()}.${d.getUTCMonth() + 1}.`;
  const n = Number((await tx.query("SELECT count(*) AS c FROM releases WHERE number LIKE $1 || '%'", [prefix])).rows[0].c) + 1;
  return `${prefix}${n}`;
}
