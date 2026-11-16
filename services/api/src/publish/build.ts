/**
 * Construcción de paquetes de contenido (diseño D2 y D8 del MVP, D2 y D7 del back office).
 *
 * Una publicación es una foto del contenido validado. Este módulo:
 *  1. Genera las variantes de cada plantilla y las recalcula con el motor B.
 *  2. Compone las lecciones (por huecos o por regla automática por habilidad).
 *  3. Arma un paquete por itinerario y un paquete global (catálogos, tipos,
 *     anuncios, logros, liga), los comprime y los firma con Ed25519.
 */
import { createHash, sign as edSign, type KeyObject } from 'node:crypto';
import { gzipSync } from 'node:zlib';
import type {
  Achievement, AdCampaign, AdParams, ExerciseType, FreePlanRules, GlobalPackage, ItineraryPackage, ItinerarySummary,
  LeagueConfig, Lesson, LessonKind, LessonSlot, MeasureUnit, Instrument, PlacementItem, Sector, Skill, SkillCode, TemplateSummary,
  Unit, Variant, VoiceLexicon, SignedFile,
} from '@vtm/contracts';
import { LESSON_KIND_ORDER, PACKAGE_FORMAT, signaturePayload } from '@vtm/contracts';
import { generateVariants, resolveQuestion, type QuestionDefinition, type TemplateDefinition, type GenerationReport } from '@vtm/engine';

export interface LessonSeed {
  id: string;
  unitId: string;
  order: number;
  kind: LessonKind;
  title: string;
  estimatedMinutes: number;
  /** Huecos explícitos; si faltan, se aplica la regla automática por habilidad. */
  slots?: LessonSlot[];
  rule?: 'auto';
}

export interface UnitInput extends Unit {
  templateIds: string[];
  questionIds: string[];
}

export interface BuildInput {
  contentVersion: string;
  minAppVersion: string;
  sectors: Sector[];
  itineraries: ItinerarySummary[];
  skills: Skill[];
  exerciseTypes: ExerciseType[];
  units: UnitInput[];
  lessons: LessonSeed[];
  templates: TemplateDefinition[];
  questions: QuestionDefinition[];
  measureUnits: MeasureUnit[];
  instruments: Instrument[];
  voiceLexicon: VoiceLexicon;
  achievements: Achievement[];
  league: LeagueConfig;
  adParams: AdParams;
  campaigns: AdCampaign[];
  freePlan: FreePlanRules;
  orgsEnabled: boolean;
  variantsPerLevel?: number;
  /** Tipos de ejercicio que la app instalada de referencia admite (para avisos). */
}

export interface CheckResult {
  id: string;
  label: string;
  ok: boolean;
  severity?: 'error' | 'warning';
  detail: string;
  itemId?: string;
}

export interface BuildOutput {
  global: GlobalPackage;
  itineraries: ItineraryPackage[];
  reports: Record<string, GenerationReport[]>;
  checks: CheckResult[];
}

const LEVELS_BY_KIND: Record<LessonKind, (1 | 2 | 3 | 4 | 5)[]> = {
  guided: [1, 1, 2, 2], supported: [2, 2, 3], free: [3, 3, 3, 4], mixed: [3, 4], challenge: [3, 4, 4],
};
const SIZE_BY_KIND: Record<LessonKind, number> = { guided: 8, supported: 8, free: 10, mixed: 10, challenge: 10 };

/** Regla automática por habilidad: reparte los huecos entre las plantillas de la unidad. */
export function autoSlots(kind: LessonKind, unit: UnitInput, previousUnits: UnitInput[], skillOf: (id: string) => SkillCode, typeOf: (id: string) => string): LessonSlot[] {
  const size = SIZE_BY_KIND[kind];
  const levels = LEVELS_BY_KIND[kind];
  const own = [...unit.templateIds.map((id) => ({ id, q: false })), ...unit.questionIds.map((id) => ({ id, q: true }))]
    // El reto de unidad usa ejercicios de respuesta individual (sin series ni ordenación).
    .filter((x) => kind !== 'challenge' || ['T1', 'T2', 'T6'].includes(typeOf(x.id)));
  const prev = previousUnits.flatMap((u) => u.templateIds.map((id) => ({ id, q: false })));
  const slots: LessonSlot[] = [];
  // Sin ejercicios validados en la unidad no se compone nada: la comprobación de lecciones bloquea la publicación.
  if (!own.length) return slots;
  for (let i = 0; i < size; i++) {
    let pick = own[i % Math.max(own.length, 1)]!;
    // Mixta: alterna la habilidad nueva con habilidades de unidades anteriores.
    if (kind === 'mixed' && prev.length && i % 2 === 1) pick = prev[Math.floor(i / 2) % prev.length]!;
    const difficulty = levels[Math.min(levels.length - 1, Math.floor((i / size) * levels.length))]!;
    slots.push(pick.q
      ? { position: i + 1, questionId: pick.id, difficulty, skillId: skillOf(pick.id) }
      : { position: i + 1, templateId: pick.id, difficulty, skillId: skillOf(pick.id) });
  }
  return slots;
}

export function buildContent(input: BuildInput): BuildOutput {
  const checks: CheckResult[] = [];
  const reports: Record<string, GenerationReport[]> = {};
  const variantsByTemplate = new Map<string, Variant[]>();
  const summaries = new Map<string, TemplateSummary>();
  let doubleFailures = 0;
  let collisions = 0;

  for (const t of input.templates) {
    const res = generateVariants(t, { perLevel: input.variantsPerLevel ?? t.variantsPerLevel });
    reports[t.id] = res.reports;
    const vs = res.variants.map((r) => r.variant);
    variantsByTemplate.set(t.id, vs);
    for (const r of res.variants) {
      if (!r.doubleCheck.ok || !r.doubleCheck.predictedOk) {
        doubleFailures++;
        checks.push({ id: 'double', label: 'Doble cálculo coincidente', ok: false, detail: `Discrepancia en ${r.variant.id}: ${r.doubleCheck.a} frente a ${r.doubleCheck.b}`, itemId: t.id });
      }
      if (r.collision) {
        collisions++;
        if (collisions <= 20) checks.push({ id: 'collision', label: 'Sin colisiones', ok: false, detail: `Colisión en ${r.variant.id}`, itemId: t.id });
      }
    }
    const short = res.reports.filter((x) => x.generated < x.requested);
    for (const s of short) {
      if (s.exhausted) checks.push({ id: 'count', label: 'Variantes en la cantidad pedida', ok: true, severity: 'warning', detail: `Nivel ${s.level} de «${t.name}»: el espacio de combinaciones solo admite ${s.generated} variantes distintas`, itemId: t.id });
      else checks.push({ id: 'count', label: 'Variantes en la cantidad pedida', ok: false, severity: 'error', detail: `Solo ${s.generated} variantes cumplen las restricciones en el nivel ${s.level} de «${t.name}». Amplía los rangos`, itemId: t.id });
    }
    const byLevel: Record<string, string[]> = {};
    for (const v of vs) (byLevel[String(v.level)] ??= []).push(v.id);
    summaries.set(t.id, {
      id: t.id, version: t.version, name: t.name, skillId: t.skillId, sectorId: t.sectorId, exerciseTypeId: t.exerciseTypeId,
      species: t.species ?? undefined, targetTimeS: Object.fromEntries(t.levels.map((l) => [String(l.level), l.targetTimeS])), variantsByLevel: byLevel,
    });
  }
  const questionVariants = new Map<string, Variant>();
  for (const q of input.questions) questionVariants.set(q.id, resolveQuestion(q));

  // Todos los ejercicios con explicación y texto para voz.
  const all = [...[...variantsByTemplate.values()].flat(), ...questionVariants.values()];
  const noSteps = all.filter((v) => !v.steps.length);
  const noTts = all.filter((v) => !v.tts.trim());
  checks.push({ id: 'explanations', label: 'Todos los ejercicios con explicación y texto para voz', ok: !noSteps.length && !noTts.length, detail: noSteps.length || noTts.length ? `${noSteps.length} sin explicación, ${noTts.length} sin texto para voz` : `${all.length} ejercicios comprobados` });
  checks.push({ id: 'double', label: 'Doble cálculo coincidente', ok: doubleFailures === 0, detail: doubleFailures ? `${doubleFailures} discrepancias` : `${all.length} variantes recalculadas con el motor independiente` });
  checks.push({ id: 'collision', label: 'Sin colisiones entre respuesta correcta y errónea previsible', ok: collisions === 0, detail: collisions ? `${collisions} colisiones` : 'Ninguna' });

  const skillOf = (id: string): SkillCode => (input.templates.find((t) => t.id === id)?.skillId ?? input.questions.find((q) => q.id === id)?.skillId ?? 'H1') as SkillCode;
  const typeOf = (id: string): string => input.templates.find((t) => t.id === id)?.exerciseTypeId ?? input.questions.find((q) => q.id === id)?.exerciseTypeId ?? 'T1';

  const itineraries: ItineraryPackage[] = [];
  for (const it of input.itineraries) {
    const units = input.units.filter((u) => u.itineraryId === it.id).sort((a, b) => a.order - b.order);
    const lessons: Lesson[] = [];
    units.forEach((u, idx) => {
      const seeds = input.lessons.filter((l) => l.unitId === u.id).sort((a, b) => a.order - b.order);
      const effective: LessonSeed[] = seeds.length ? seeds : LESSON_KIND_ORDER.map((kind, i) => ({ id: `${u.id}-l${i + 1}`, unitId: u.id, order: i + 1, kind, title: '', estimatedMinutes: kind === 'challenge' ? 5 : 4, rule: 'auto' as const }));
      for (const l of effective) {
        const slots = l.slots && l.slots.length && l.rule !== 'auto' ? l.slots : autoSlots(l.kind, u, units.slice(0, idx), skillOf, typeOf);
        lessons.push({ id: l.id, unitId: u.id, order: l.order, kind: l.kind, title: l.title || defaultTitle(l.kind), estimatedMinutes: l.estimatedMinutes, slots });
      }
    });
    const usedTemplates = new Set<string>();
    const usedQuestions = new Set<string>();
    for (const l of lessons) for (const s of l.slots) { if (s.templateId) usedTemplates.add(s.templateId); if (s.questionId) usedQuestions.add(s.questionId); }
    for (const u of units) { u.templateIds.forEach((t) => usedTemplates.add(t)); u.questionIds.forEach((q) => usedQuestions.add(q)); }
    const variants: Variant[] = [];
    for (const t of usedTemplates) variants.push(...(variantsByTemplate.get(t) ?? []));
    for (const q of usedQuestions) { const v = questionVariants.get(q); if (v) variants.push(v); }
    const placement: PlacementItem[] = units.map((u) => ({
      unitId: u.id,
      variantIds: u.templateIds
        .filter((t) => ['T1', 'T2', 'T6'].includes(typeOf(t)))
        .flatMap((t) => (variantsByTemplate.get(t) ?? []).filter((v) => v.level === 2 || v.level === 3).slice(0, 3).map((v) => v.id)),
    }));
    const pkg: ItineraryPackage = {
      format: PACKAGE_FORMAT, contentVersion: input.contentVersion, minAppVersion: input.minAppVersion, itinerary: it,
      units: units.map(({ templateIds: _t, questionIds: _q, ...u }) => u), lessons,
      templates: [...usedTemplates].map((t) => summaries.get(t)!).filter(Boolean), variants, placement,
    };
    const emptyLessons = lessons.filter((l) => !l.slots.length);
    if (emptyLessons.length) checks.push({ id: 'lessons', label: 'Lecciones con ejercicios', ok: false, detail: `${emptyLessons.length} lecciones sin ejercicios validados en ${it.name} (${[...new Set(emptyLessons.map((l) => l.unitId))].join(', ')})` });
    itineraries.push(pkg);
  }

  const global: GlobalPackage = {
    format: PACKAGE_FORMAT, contentVersion: input.contentVersion, minAppVersion: input.minAppVersion,
    sectors: input.sectors, itineraries: input.itineraries, skills: input.skills, exerciseTypes: input.exerciseTypes,
    units: input.measureUnits, instruments: input.instruments, voiceLexicon: input.voiceLexicon, achievements: input.achievements,
    league: input.league, ads: { params: input.adParams, campaigns: input.campaigns }, freePlan: input.freePlan, orgsEnabled: input.orgsEnabled,
  };
  return { global, itineraries, reports, checks };
}

function defaultTitle(kind: LessonKind): string {
  return { guided: 'Concepto guiado', supported: 'Práctica con apoyos', free: 'Práctica libre', mixed: 'Mixta', challenge: 'Reto de unidad' }[kind];
}

export interface SignedBlob {
  file: SignedFile;
  bytes: Buffer;
}

/** Comprime y firma un paquete: Ed25519 sobre `${id}|${version}|${sha256}`. */
export function signPackage(id: string, version: string, minAppVersion: string, payload: unknown, privateKey: KeyObject, urlFor: (id: string) => string): SignedBlob {
  const bytes = gzipSync(Buffer.from(JSON.stringify(payload), 'utf8'), { level: 9 });
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  const signature = edSign(null, Buffer.from(signaturePayload({ id, version, sha256 }), 'utf8'), privateKey).toString('base64');
  return { file: { id, version, url: urlFor(id), sha256, signature, size: bytes.length, minAppVersion }, bytes };
}
