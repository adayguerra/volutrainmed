/**
 * Semilla de desarrollo: esquema, cuentas del back office por rol, contenido de
 * demostración pasado por el ciclo real de revisión (autora → revisor distinto)
 * y primera publicación al 100 %.
 *
 *   pnpm --filter @vtm/api seed           (añade lo que falte)
 *   pnpm --filter @vtm/api seed -- --reset (vacía la base y empieza de cero)
 */
import { migrate } from '../db/migrate.js';
import { withTx, SYSTEM, closePool, type Tx } from '../db/pool.js';
import { hashPassword } from '../lib/crypto.js';
import { createItem, decide, submitItem, CHECKLIST_KEYS, latest } from '../services/items.js';
import { buildFromSnapshot, nextReleaseNumber, snapshot, storePackages, summarizeChecks } from '../publish/service.js';
import type { BoCtx, BoRole } from '../server.js';
import {
  ACHIEVEMENTS, AD_PARAMS, EXERCISE_TYPES, INSTRUMENTS, ITINERARIES, LAUNCH_CAMPAIGN, LEAGUE_CONFIG, MEASURE_UNITS, QUESTIONS, SECTORS, SKILLS, STRUCTURE, TEMPLATES, VOICE_LEXICON, LESSON_TITLES,
} from './content.js';
import { LESSON_KIND_ORDER } from '@vtm/contracts';

export const DEV_PASSWORD = 'VolutrainMed-2026!';

export const ACCOUNTS: { email: string; name: string; role: BoRole; sectors: string[]; accreditation?: string }[] = [
  { email: 'superadmin@volutrainmed.test', name: 'Superadministración', role: 'superadmin', sectors: [] },
  { email: 'contenido@volutrainmed.test', name: 'María Ortega', role: 'content_admin', sectors: [] },
  { email: 'autora@volutrainmed.test', name: 'Lucía Martín (autora de demostración)', role: 'author', sectors: [] },
  { email: 'autor2@volutrainmed.test', name: 'Pablo Ruiz (autor de demostración)', role: 'author', sectors: [] },
  { email: 'revisor.clinico@volutrainmed.test', name: 'Revisor de demostración (clínico)', role: 'reviewer', sectors: ['comun', 'anestesia', 'enfermeria', 'medicina', 'emergencias', 'farmacia'], accreditation: 'Acreditación de demostración · pendiente de un profesional real' },
  { email: 'revisor.vet@volutrainmed.test', name: 'Revisora de demostración (veterinaria)', role: 'reviewer', sectors: ['comun', 'veterinaria'], accreditation: 'Acreditación de demostración · pendiente de un profesional real' },
  { email: 'revisor.enfermeria@volutrainmed.test', name: 'Revisor de demostración (solo enfermería)', role: 'reviewer', sectors: ['enfermeria'], accreditation: 'Acreditación de demostración' },
  { email: 'revisor.ped1@volutrainmed.test', name: 'Revisora de demostración (pediatría 1)', role: 'reviewer', sectors: ['pediatria', 'comun'], accreditation: 'Acreditación de demostración' },
  { email: 'revisor.ped2@volutrainmed.test', name: 'Revisor de demostración (pediatría 2)', role: 'reviewer', sectors: ['pediatria', 'comun'], accreditation: 'Acreditación de demostración' },
  { email: 'analista@volutrainmed.test', name: 'Analista de demostración', role: 'analyst', sectors: [] },
  { email: 'soporte@volutrainmed.test', name: 'Soporte de demostración', role: 'support', sectors: [] },
  { email: 'organizacion@volutrainmed.test', name: 'Administración de la Facultad de demostración', role: 'org_admin', sectors: [] },
];

async function ctx(tx: Tx, email: string): Promise<BoCtx> {
  const a = (await tx.query('SELECT * FROM bo_accounts WHERE email = $1', [email])).rows[0];
  return { accountId: a.id, role: a.role, sectors: a.sectors, orgId: a.org_id, name: a.name, email: a.email };
}

const FULL_CHECKLIST = Object.fromEntries(CHECKLIST_KEYS.map((k) => [k, true]));

async function seedItem(tx: Tx, author: BoCtx, reviewers: BoCtx[], kind: Parameters<typeof createItem>[2], data: Record<string, unknown>, ord?: number) {
  const id = String(data.id);
  const exists = (await tx.query('SELECT 1 FROM content_items WHERE id = $1', [id])).rowCount;
  if (exists) return;
  await createItem(tx, author, kind, data, { id, ord });
  await submitItem(tx, author, id);
  const item = await latest(tx, id);
  const sector = item.sector_id;
  const candidates = reviewers.filter((r) => r.accountId !== item.author_id && (!sector || sector === 'comun' || r.sectors.includes(sector)));
  if (!candidates.length) throw new Error(`Sin revisor acreditado para ${id} (${sector})`);
  await tx.query("SELECT set_config('app.actor_role', 'reviewer', true), set_config('app.actor_id', $1, true)", [candidates[0]!.accountId]);
  await decide(tx, candidates[0]!, id, { decision: 'validate', checklist: FULL_CHECKLIST });
  const after = await latest(tx, id);
  if (after.state !== 'validated' && candidates[1]) {
    await tx.query("SELECT set_config('app.actor_role', 'reviewer', true), set_config('app.actor_id', $1, true)", [candidates[1].accountId]);
    await decide(tx, candidates[1], id, { decision: 'validate', checklist: FULL_CHECKLIST });
  }
  await tx.query("SELECT set_config('app.actor_role', 'system', true), set_config('app.actor_id', '', true)");
}

export async function seed(opts: { reset?: boolean; publish?: boolean; log?: (s: string) => void } = {}) {
  const log = opts.log ?? ((s: string) => console.log(s));
  const applied = await migrate(Boolean(opts.reset));
  if (applied.length) log(`Migraciones: ${applied.join(', ')}`);
  await withTx(SYSTEM, async (tx) => {
    for (const a of ACCOUNTS) {
      await tx.query(
        'INSERT INTO bo_accounts(email, name, role, sectors, accreditation, password_hash) VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT (email) DO NOTHING',
        [a.email, a.name, a.role, a.sectors, a.accreditation ?? null, hashPassword(DEV_PASSWORD)],
      );
    }
    const settings: [string, unknown][] = [
      ['ad_params', AD_PARAMS], ['league_config', LEAGUE_CONFIG], ['free_plan', { handsfreeDailyMinutes: 5, freeUnitsPerItinerary: 99 }], ['orgs_enabled', true],
    ];
    for (const [k, v] of settings) await tx.query('INSERT INTO settings(key, value) VALUES ($1,$2) ON CONFLICT (key) DO NOTHING', [k, JSON.stringify(v)]);
    const org = (await tx.query("SELECT id FROM organizations WHERE name = 'Facultad de demostración'")).rows[0];
    if (!org) {
      const o = (await tx.query("INSERT INTO organizations(name, type, seats, valid_from, valid_to, nominal, invite_code, domains) VALUES ('Facultad de demostración', 'universidad', 50, current_date - 30, current_date + 335, false, 'FACDEMO1', '{facultad-demo.test}') RETURNING id")).rows[0];
      await tx.query("INSERT INTO org_groups(org_id, name, invite_code, itineraries) VALUES ($1, 'Promoción de demostración', 'GRUPO-DEMO', '{it-fundamentos}')", [o.id]);
      await tx.query("UPDATE bo_accounts SET org_id = $1 WHERE email = 'organizacion@volutrainmed.test'", [o.id]);
    }
  });

  await withTx(SYSTEM, async (tx) => {
    const admin = await ctx(tx, 'contenido@volutrainmed.test');
    const author = await ctx(tx, 'autora@volutrainmed.test');
    const reviewers = [await ctx(tx, 'revisor.clinico@volutrainmed.test'), await ctx(tx, 'revisor.vet@volutrainmed.test'), await ctx(tx, 'revisor.ped1@volutrainmed.test'), await ctx(tx, 'revisor.ped2@volutrainmed.test')];
    await tx.query("SELECT set_config('app.actor_role', 'system', true)");
    let n = 0;
    // Estructura y catálogos: los crea la administración de contenido; los valida un revisor.
    for (const s of SECTORS) { await seedItem(tx, admin, reviewers, 'sector', s as never, s.order); n++; }
    await seedItem(tx, admin, reviewers, 'sector', { id: 'comun', code: 'COM', name: 'Común a todos los sectores', description: 'Fundamentos', icon: 'school', typicalCalcs: 'Conversiones, concentraciones, volumen, redondeo y estimación', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos'], order: 99, hidden: true } as never, 99);
    for (const it of ITINERARIES) { await seedItem(tx, admin, reviewers, 'itinerary', it as never, it.order); n++; }
    for (const t of EXERCISE_TYPES) { await seedItem(tx, admin, reviewers, 'exercise_type', t as never); n++; }
    for (const u of MEASURE_UNITS) await seedItem(tx, admin, reviewers, 'catalog_unit', { ...u, id: `cu-${u.symbol.replace(/[^a-z]/gi, '') || 'pct'}` } as never);
    for (const i of INSTRUMENTS) await seedItem(tx, admin, reviewers, 'catalog_instrument', { ...i, id: `ci-${i.id}` } as never);
    await seedItem(tx, admin, reviewers, 'voice_lexicon', { ...VOICE_LEXICON, id: 'voice-lexicon-es', name: 'Léxico de voz (es-ES)' } as never);
    for (const [i, k] of SKILLS.entries()) await seedItem(tx, admin, reviewers, 'catalog_skill', { id: `cs-${k.id.toLowerCase()}`, code: k.id, name: k.name } as never, i + 1);
    for (const [i, sp] of ['Perro', 'Gato', 'Conejo', 'Hurón', 'Caballo'].entries()) await seedItem(tx, admin, reviewers, 'catalog_species', { id: `sp-${sp.toLowerCase().normalize('NFD').replace(/[^a-z]/g, '')}`, name: sp, sectorId: 'veterinaria' } as never, i + 1);
    for (const a of ACHIEVEMENTS) await seedItem(tx, admin, reviewers, 'achievement', a as never);
    await seedItem(tx, admin, reviewers, 'ad_campaign', { id: LAUNCH_CAMPAIGN.id, name: LAUNCH_CAMPAIGN.name, sectorIds: null, startsAt: null, endsAt: null } as never);
    for (const c of LAUNCH_CAMPAIGN.creatives) await seedItem(tx, admin, reviewers, 'ad_creative', { ...c, campaignId: LAUNCH_CAMPAIGN.id, name: `${c.id} · ${c.headline}` } as never);
    // Contenido: lo escribe la autora; lo valida un revisor acreditado distinto.
    for (const t of TEMPLATES) { await seedItem(tx, author, reviewers, 'template', t as never); n++; }
    for (const q of QUESTIONS) { await seedItem(tx, author, reviewers, 'question', q as never); n++; }
    for (const [itineraryId, units] of Object.entries(STRUCTURE)) {
      let order = 1;
      for (const u of units) {
        await seedItem(tx, admin, reviewers, 'unit', { ...u.unit, itineraryId, templateIds: u.templates, questionIds: u.questions ?? [] } as never, order++);
        LESSON_KIND_ORDER.forEach(() => undefined);
        let lo = 1;
        for (const kind of LESSON_KIND_ORDER) {
          await seedItem(tx, admin, reviewers, 'lesson', { id: `${u.unit.id}-l${lo}`, unitId: u.unit.id, kind, title: LESSON_TITLES[kind], estimatedMinutes: kind === 'challenge' ? 5 : 4, rule: 'auto', slots: [] } as never, lo);
          lo++;
        }
      }
    }
    log(`Contenido de demostración validado (${n} elementos principales).`);
  });

  if (opts.publish !== false) {
    await withTx(SYSTEM, async (tx) => {
      const published = (await tx.query("SELECT 1 FROM releases WHERE state = 'published'")).rowCount;
      if (published) { log('Ya hay una versión publicada.'); return; }
      const admin = await ctx(tx, 'contenido@volutrainmed.test');
      const number = await nextReleaseNumber(tx);
      const snap = await snapshot(tx);
      const build = await buildFromSnapshot(tx, snap, number, '1.0.0');
      const s = summarizeChecks(build.checks);
      if (!s.passed) throw new Error(`Comprobaciones fallidas: ${build.checks.filter((c) => !c.ok).map((c) => c.detail).join(' | ')}`);
      const r = (await tx.query("INSERT INTO releases(number, notes, state, rollout_pct, items, checks, created_by, published_at) VALUES ($1, 'Publicación inicial de demostración', 'published', 100, $2, $3, $4, now()) RETURNING id",
        [number, JSON.stringify(snap.included), JSON.stringify(build.checks), admin.accountId])).rows[0];
      await storePackages(tx, r.id, number, build);
      for (const i of snap.included) await tx.query("UPDATE content_items SET state = 'published' WHERE id = $1 AND version = $2", [i.id, i.version]);
      await tx.query("INSERT INTO audit_log(actor_id, actor_role, action, entity, entity_id, after) VALUES ($1, 'content_admin', 'release.publish', 'release', $2, $3)", [admin.accountId, r.id, JSON.stringify({ number, rolloutPct: 100, seed: true })]);
      log(`Publicada la versión ${number}: ${build.itineraries.map((p) => `${p.itinerary.name} (${p.variants.length} variantes)`).join(', ')}.`);
    });
  }
}

if (process.argv[1]?.endsWith('run.ts')) {
  seed({ reset: process.argv.includes('--reset') }).then(() => closePool()).catch(async (e) => { console.error(e); await closePool(); process.exit(1); });
}
