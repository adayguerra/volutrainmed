/**
 * Plantillas parametrizadas y generación de variantes (diseño D2, D4 y D5).
 *
 * Una plantilla validada produce cientos de variantes correctas: variables con
 * rangos o tabla de casos coherente, fórmula con comprobación dimensional,
 * redondeo, tolerancia, restricciones, errores previsibles y pasos de la
 * explicación. Las variantes salen resueltas y viajan al dispositivo, que no
 * calcula fórmulas.
 */
import type { AnswerSpec, ChoiceOption, ErrorCode, ExplanationStep, PredictedError, Rounding, SkillCode, StatementSegment, Tolerance, Variant } from '@vtm/contracts';
import { type Dec, D, dec, canon, formatEs, roundPlaces, roundStep } from './decimal.js';
import { checkDimensions, evalIn, FormulaError, parseFormula, type Scope } from './expr.js';
import { evalInB, Rational } from './doublecheck.js';
import { parseUnit, sameDims } from './units.js';
import { speakText, speakFragment, readQuantity, readUnit } from './speech.js';
import { findClinicalUseText, findQuantitiesWithoutUnit } from './textcheck.js';

export interface VariableDef {
  name: string;
  label: string;
  kind: 'int' | 'decimal' | 'list' | 'case_table' | 'computed';
  unit: string;
  min?: string;
  max?: string;
  step?: string;
  values?: string[];
  formula?: string;
  columns?: { name: string; unit: string; label?: string }[];
  rows?: Record<string, string>[];
  show: boolean;
}

export interface LevelDef {
  level: 1 | 2 | 3 | 4 | 5;
  overrides?: Record<string, { min?: string; max?: string; step?: string; values?: string[]; multipleOf?: string }>;
  unitFixed: boolean;
  targetTimeS: number;
}

export type TemplateRounding = Rounding | { mode: 'syringe_auto' };

export interface TemplateDefinition {
  id: string;
  version: number;
  name: string;
  sectorId: string;
  skillId: SkillCode;
  exerciseTypeId: string;
  species?: string | null;
  variables: VariableDef[];
  statement: string;
  question: string;
  tts?: string | null;
  formula: string;
  answerUnit: string;
  unitChoices: string[];
  equivalents: { unit: string; factor: string }[];
  rounding: TemplateRounding;
  tolerance: Tolerance;
  constraints: { resultMin?: string; resultMax?: string; conditions: string[] };
  predictedErrors: { formula: string; unit: string; code: ErrorCode; message: string; deviationStep?: number }[];
  steps: { text: string; formula: string; unit: string; operation: string; cancelled: string[] }[];
  plausibility: string;
  approach?: string;
  hint?: string;
  bands?: { label: string; min?: string; max?: string }[];
  levels: LevelDef[];
  variantsPerLevel: number;
  demo?: boolean;
}

// ---------------------------------------------------------------------------
// Generador pseudoaleatorio reproducible
// ---------------------------------------------------------------------------

function hashString(s: string): number {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

export function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------------------------------------------------------------------------
// Muestreo de variables
// ---------------------------------------------------------------------------

function sampleRange(r: () => number, min: Dec, max: Dec, step: Dec): Dec {
  const n = max.sub(min).div(step).floor().toNumber();
  const k = Math.floor(r() * (n + 1));
  return min.add(step.mul(k));
}

export type Assignment = Record<string, { value: string; unit: string; text?: string }>;

function sampleAssignment(def: TemplateDefinition, level: LevelDef, r: () => number): Assignment {
  const out: Assignment = {};
  for (const v of def.variables) {
    const ov = level.overrides?.[v.name];
    if (v.kind === 'case_table') {
      const rows = v.rows ?? [];
      if (!rows.length) throw new FormulaError(`La tabla de casos «${v.label}» no tiene filas`);
      const row = rows[Math.floor(r() * rows.length)]!;
      for (const col of v.columns ?? []) {
        const raw = row[col.name] ?? '';
        const numeric = /^-?\d+(?:[.,]\d+)?$/.test(raw.trim());
        out[`${v.name}.${col.name}`] = numeric ? { value: canon(raw.replace(',', '.')), unit: col.unit } : { value: '0', unit: '', text: raw };
      }
      continue;
    }
    if (v.kind === 'computed') continue;
    if (v.kind === 'list') {
      const values = ov?.values ?? v.values ?? [];
      const pick = values[Math.floor(r() * values.length)]!;
      out[v.name] = { value: canon(pick.replace(',', '.')), unit: v.unit };
      continue;
    }
    const min = dec(ov?.min ?? v.min ?? '0');
    const max = dec(ov?.max ?? v.max ?? '0');
    let step = dec(ov?.step ?? v.step ?? (v.kind === 'int' ? '1' : '0.1'));
    if (ov?.multipleOf) step = dec(ov.multipleOf);
    let val = sampleRange(r, min, max, step);
    if (ov?.multipleOf) {
      const m = dec(ov.multipleOf);
      val = val.div(m).ceil().mul(m);
      if (val.gt(max)) val = val.sub(m);
    }
    out[v.name] = { value: canon(val), unit: v.unit };
  }
  // Variables calculadas, en orden de declaración.
  for (const v of def.variables) {
    if (v.kind !== 'computed' || !v.formula) continue;
    const val = evalIn(v.formula, toScope(out), v.unit);
    out[v.name] = { value: canon(val.toDecimalPlaces(12)), unit: v.unit };
  }
  return out;
}

function toScope(a: Assignment): Scope {
  const s: Scope = {};
  for (const [k, v] of Object.entries(a)) if (v.text === undefined) s[k] = { value: v.value, unit: v.unit };
  return s;
}

// ---------------------------------------------------------------------------
// Redondeo
// ---------------------------------------------------------------------------

export const SYRINGES = [
  { maxMl: '1', step: '0.01', name: 'jeringa de 1 ml' },
  { maxMl: '3', step: '0.1', name: 'jeringa de 3 ml' },
  { maxMl: '10', step: '0.2', name: 'jeringa de 10 ml' },
  { maxMl: '50', step: '1', name: 'jeringa de 50 ml' },
];

export function resolveRounding(r: TemplateRounding, value: Dec, unit: string): Rounding {
  if (r.mode !== 'syringe_auto') return r;
  let ml = value;
  try { const u = parseUnit(unit); const mlU = parseUnit('ml'); if (sameDims(u.dims, mlU.dims)) ml = value.mul(u.factor); } catch { /* sin conversión */ }
  const s = SYRINGES.find((x) => ml.lte(dec(x.maxMl))) ?? SYRINGES[SYRINGES.length - 1]!;
  return { mode: 'instrument', step: s.step, instrument: s.name };
}

export function applyRounding(v: Dec, r: Rounding): Dec {
  if (r.mode === 'decimals') return roundPlaces(v, r.places);
  if (r.mode === 'instrument') return roundStep(v, dec(r.step));
  if (r.mode === 'integer') return roundPlaces(v, 0);
  return v;
}

export function roundingInstruction(r: Rounding): string {
  if (r.mode === 'decimals') return r.places === 0 ? 'Redondea a un número entero.' : r.places === 1 ? 'Redondea a la décima.' : r.places === 2 ? 'Redondea a la centésima.' : `Redondea a ${r.places} decimales.`;
  if (r.mode === 'instrument') return `Se mide con ${r.instrument} (divisiones de ${formatEs(r.step)} ml): redondea a esa división.`;
  if (r.mode === 'integer') return r.label ? `Redondea a ${r.label}.` : 'Redondea a un número entero.';
  return '';
}

function roundingWithRational(v: Rational, r: Rounding): Rational {
  if (r.mode === 'decimals') return v.roundPlaces(r.places);
  if (r.mode === 'instrument') return v.roundStep(Rational.parse(r.step));
  if (r.mode === 'integer') return v.roundPlaces(0);
  return v;
}

// ---------------------------------------------------------------------------
// Texto del enunciado
// ---------------------------------------------------------------------------

function renderSegments(template: string, a: Assignment): StatementSegment[] {
  const segs: StatementSegment[] = [];
  const re = /\{([\p{L}\p{N}_.]+)\}/gu;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(template))) {
    if (m.index > last) segs.push({ t: 'text', v: template.slice(last, m.index) });
    const key = m[1]!;
    const val = a[key];
    if (!val) segs.push({ t: 'text', v: m[0] });
    else if (val.text !== undefined) segs.push({ t: 'text', v: val.text });
    else if (!val.unit) segs.push({ t: 'text', v: formatEs(val.value) });
    else segs.push({ t: 'qty', value: val.value, unit: val.unit, key });
    last = re.lastIndex;
  }
  if (last < template.length) segs.push({ t: 'text', v: template.slice(last) });
  return segs;
}

export function segmentsToText(segs: StatementSegment[]): string {
  return segs.map((s) => (s.t === 'text' ? s.v : `${formatEs(s.value)}${s.unit === '%' ? ' %' : ' ' + s.unit}`)).join('');
}

export function segmentsToSpeech(segs: StatementSegment[]): string {
  return segs.map((s) => (s.t === 'text' ? speakFragment(s.v) : readQuantity(s.value, s.unit))).join('').replace(/\s+/g, ' ').trim();
}

function renderInline(template: string, a: Assignment): string {
  return segmentsToText(renderSegments(template, a));
}

// ---------------------------------------------------------------------------
// Resolución de una variante
// ---------------------------------------------------------------------------

export interface ResolvedVariant {
  variant: Variant;
  assignment: Assignment;
  unrounded: string;
  /** Resultado del motor B ya redondeado. */
  doubleCheck: { a: string; b: string; ok: boolean; predictedOk: boolean };
  collision: boolean;
}

function signature(a: Assignment): string {
  return Object.keys(a).sort().map((k) => `${k}=${a[k]!.text ?? a[k]!.value}`).join('&');
}

export function resolveVariant(def: TemplateDefinition, level: LevelDef, a: Assignment, index: number, seed: number): ResolvedVariant {
  const scope = toScope(a);
  const raw = evalIn(def.formula, scope, def.answerUnit);
  const rounding = resolveRounding(def.rounding, raw, def.answerUnit);
  const rounded = applyRounding(raw, rounding);
  const value = canon(rounded);

  // Pasos de la explicación: cada paso puede usar los anteriores como paso1, paso2…
  const stepScope: Scope = { ...scope, respuesta: { value: canon(raw), unit: def.answerUnit } };
  const steps: ExplanationStep[] = def.steps.map((s, i) => {
    const r = evalIn(s.formula, stepScope, s.unit);
    const isLast = i === def.steps.length - 1;
    const shown = isLast ? rounded : r;
    stepScope[`paso${i + 1}`] = { value: canon(r), unit: s.unit };
    const opAssign: Assignment = { ...a };
    for (const [k, v] of Object.entries(stepScope)) if (!opAssign[k]) opAssign[k] = { value: canon(dec(v.value).toDecimalPlaces(4)), unit: v.unit };
    return {
      n: i + 1,
      text: s.text,
      operation: renderInline(s.operation, opAssign),
      result: { value: canon(isLast ? shown : shown.toDecimalPlaces(4)), unit: s.unit },
      cancelled: s.cancelled,
      cancelledSpoken: s.cancelled.length ? s.cancelled.map((u) => `${readUnit(u).text} se cancelan`).join('; ') : undefined,
    };
  });

  // Errores previsibles.
  const predicted: PredictedError[] = [];
  let collision = false;
  for (const p of def.predictedErrors) {
    let pv: Dec;
    try { pv = evalIn(p.formula, stepScope, p.unit); } catch { continue; }
    const sameAsAnswer = (() => { try { return sameDims(parseUnit(p.unit).dims, parseUnit(def.answerUnit).dims); } catch { return false; } })();
    const pr = p.unit === def.answerUnit ? applyRounding(pv, rounding) : pv.toDecimalPlaces(4);
    const pvCanon = canon(pr);
    if (sameAsAnswer && p.unit === def.answerUnit && pvCanon === value) collision = true;
    if (!sameAsAnswer && pvCanon === value && def.unitChoices.length <= 1) collision = true;
    predicted.push({ value: pvCanon, unit: p.unit, code: p.code, message: p.message, deviationStep: p.deviationStep });
  }

  const unitFixed = level.unitFixed;
  const answer: AnswerSpec = {
    value,
    unit: def.answerUnit,
    unitFixed,
    unitChoices: unitFixed ? [def.answerUnit] : def.unitChoices.length ? def.unitChoices : [def.answerUnit],
    equivalents: def.equivalents,
    rounding,
    tolerance: def.tolerance,
    unrounded: canon(raw.toDecimalPlaces(8)),
  };

  const statement = renderSegments(def.statement, a);
  const instr = roundingInstruction(rounding);
  const question = renderInline(def.question, a) + (instr ? ` ${instr}` : '');
  const tts = def.tts ? speakText(renderInline(def.tts, a)) : `${segmentsToSpeech(statement)} ${speakText(question)}`.trim();

  // Opciones para T2 (selección única) y T6 (estimación por franjas).
  let options: ChoiceOption[] | undefined;
  const r = rng(seed ^ hashString(`${index}`));
  if (def.exerciseTypeId === 'T2') {
    const seen = new Set<string>([value]);
    const opts: ChoiceOption[] = [{ id: 'ok', label: formatQty(value, def.answerUnit), value, unit: def.answerUnit, correct: true }];
    for (const p of predicted) {
      const key = `${p.value}|${p.unit}`;
      if (seen.has(key) || seen.has(p.value) && p.unit === def.answerUnit) continue;
      seen.add(key);
      opts.push({ id: `e${opts.length}`, label: formatQty(p.value, p.unit), value: p.value, unit: p.unit, correct: false, errorCode: p.code, message: p.message });
      if (opts.length === 4) break;
    }
    for (const k of ['10', '0.1', '100']) {
      if (opts.length >= 4) break;
      const fv = canon(rounded.mul(dec(k)));
      if (seen.has(fv)) continue;
      seen.add(fv);
      opts.push({ id: `e${opts.length}`, label: formatQty(fv, def.answerUnit), value: fv, unit: def.answerUnit, correct: false, errorCode: 'E2', message: k === '0.1' ? 'Tu respuesta es diez veces menor' : `Tu respuesta es ${k === '10' ? 'diez' : 'cien'} veces mayor` });
    }
    options = shuffle(opts, r).map((o, i) => ({ ...o, id: String.fromCharCode(97 + i) }));
  } else if (def.exerciseTypeId === 'T6' && def.bands) {
    options = def.bands.map((b, i) => {
      const inBand = (b.min === undefined || rounded.gte(dec(b.min))) && (b.max === undefined || rounded.lt(dec(b.max)));
      return { id: String.fromCharCode(97 + i), label: b.label, correct: inBand, errorCode: inBand ? undefined : 'E2', message: inBand ? undefined : 'La franja no corresponde al orden de magnitud del resultado' };
    });
  }

  const variant: Variant = {
    id: `${def.id}.v${def.version}.L${level.level}.${hashString(signature(a)).toString(36)}`,
    templateId: def.id,
    questionId: null,
    templateVersion: def.version,
    level: level.level,
    exerciseTypeId: def.exerciseTypeId,
    exerciseTypeVersion: 1,
    skillId: def.skillId,
    sectorId: def.sectorId,
    species: def.species ?? undefined,
    statement,
    question,
    tts,
    approach: def.approach,
    hint: def.hint,
    targetTimeS: level.targetTimeS,
    answer,
    predictedErrors: predicted,
    steps,
    plausibility: renderInline(def.plausibility.replace('{respuesta}', formatQty(value, def.answerUnit)), a),
    options,
    demo: def.demo ?? true,
  };

  // Doble cálculo con el motor B.
  const bRaw = evalInB(def.formula, scope, def.answerUnit);
  const bRounded = roundingWithRational(bRaw, rounding).toDecimalString();
  const aStr = value;
  const bStr = canon(bRounded);
  let predictedOk = true;
  for (const p of def.predictedErrors) {
    try {
      const pa = evalIn(p.formula, stepScope, p.unit);
      const pb = evalInB(p.formula, Object.fromEntries(Object.entries(stepScope).map(([k, v]) => [k, v])), p.unit);
      if (canon(pa.toDecimalPlaces(10)) !== canon(dec(pb.toDecimalString(30)).toDecimalPlaces(10))) predictedOk = false;
    } catch { /* fórmulas con «paso» que el motor B resuelve con el mismo ámbito */ }
  }
  return { variant, assignment: a, unrounded: canon(raw.toDecimalPlaces(8)), doubleCheck: { a: aStr, b: bStr, ok: aStr === bStr, predictedOk }, collision };
}

function formatQty(v: string, u: string): string {
  return u === '%' ? `${formatEs(v)} %` : `${formatEs(v)} ${u}`;
}

function shuffle<T>(arr: T[], r: () => number): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j]!, a[i]!]; }
  return a;
}

function passesConstraints(def: TemplateDefinition, a: Assignment, rounded: Dec): boolean {
  if (def.constraints.resultMin !== undefined && rounded.lt(dec(def.constraints.resultMin))) return false;
  if (def.constraints.resultMax !== undefined && rounded.gt(dec(def.constraints.resultMax))) return false;
  if (rounded.lte(0)) return false;
  const scope = toScope(a);
  for (const c of def.constraints.conditions) {
    if (!c.trim()) continue;
    const node = parseFormula(c);
    const scopeQ = scope;
    // Una condición es una comparación: vale 1 si se cumple.
    const v = evalIn(node, scopeQ, '');
    if (v.isZero()) return false;
  }
  return true;
}

export interface GenerationReport {
  level: number;
  requested: number;
  generated: number;
  attempts: number;
  discarded: number;
  discardedPct: number;
  duplicates: number;
  collisions: number;
  doubleCheckFailures: number;
  /** Se han encontrado todas las combinaciones posibles: no caben más variantes distintas. */
  exhausted: boolean;
  min: string | null;
  max: string | null;
}

export interface GenerationResult {
  variants: ResolvedVariant[];
  reports: GenerationReport[];
}

/** Genera las variantes de todos los niveles (300 por nivel por defecto). */
export function generateVariants(def: TemplateDefinition, opts: { perLevel?: number; seed?: number; levels?: number[] } = {}): GenerationResult {
  const perLevel = opts.perLevel ?? def.variantsPerLevel;
  const out: ResolvedVariant[] = [];
  const reports: GenerationReport[] = [];
  for (const level of def.levels) {
    if (opts.levels && !opts.levels.includes(level.level)) continue;
    const seed = (opts.seed ?? 0) ^ hashString(`${def.id}:${def.version}:${level.level}`);
    const r = rng(seed);
    const seen = new Set<string>();
    let attempts = 0; let discarded = 0; let duplicates = 0; let collisions = 0; let dcFail = 0;
    let min: Dec | null = null; let max: Dec | null = null;
    const maxAttempts = perLevel * 40;
    const levelOut: ResolvedVariant[] = [];
    while (levelOut.length < perLevel && attempts < maxAttempts) {
      attempts++;
      let a: Assignment;
      try { a = sampleAssignment(def, level, r); } catch (e) { if (e instanceof FormulaError) { discarded++; continue; } throw e; }
      const sig = signature(a);
      if (seen.has(sig)) { duplicates++; continue; }
      let rv: ResolvedVariant;
      try {
        const raw = evalIn(def.formula, toScope(a), def.answerUnit);
        const rounded = applyRounding(raw, resolveRounding(def.rounding, raw, def.answerUnit));
        if (!passesConstraints(def, a, rounded)) { discarded++; continue; }
        rv = resolveVariant(def, level, a, levelOut.length, seed);
      } catch (e) {
        if (e instanceof FormulaError) { discarded++; continue; }
        throw e;
      }
      seen.add(sig);
      if (rv.collision) collisions++;
      if (!rv.doubleCheck.ok || !rv.doubleCheck.predictedOk) dcFail++;
      const v = dec(rv.variant.answer!.value);
      if (!min || v.lt(min)) min = v;
      if (!max || v.gt(max)) max = v;
      levelOut.push(rv);
    }
    out.push(...levelOut);
    const totalDraws = attempts;
    reports.push({
      level: level.level, requested: perLevel, generated: levelOut.length, attempts,
      discarded, discardedPct: totalDraws ? Math.round((discarded / totalDraws) * 1000) / 10 : 0,
      duplicates, collisions, doubleCheckFailures: dcFail,
      exhausted: levelOut.length < perLevel && duplicates >= 5 * Math.max(1, levelOut.length),
      min: min ? canon(min) : null, max: max ? canon(max) : null,
    });
  }
  return { variants: out, reports };
}

export interface MassTestReport {
  draws: number;
  valid: number;
  discardedPct: number;
  repetitions: number;
  uniqueAnswers: number;
  collisions: number;
  collisionExamples: { variantId: string; value: string; code: ErrorCode }[];
  doubleCheckFailures: number;
  extremes: { min: string | null; max: string | null };
  distribution: { from: string; to: string; count: number }[];
}

/** Prueba masiva: 1000 extracciones repartidas entre los niveles. */
export function massTest(def: TemplateDefinition, draws = 1000, seed = 7): MassTestReport {
  const r = rng(seed ^ hashString(def.id));
  let valid = 0; let discarded = 0; let repetitions = 0; let collisions = 0; let dcFail = 0;
  const sigs = new Set<string>();
  const answers: Dec[] = [];
  const examples: MassTestReport['collisionExamples'] = [];
  for (let i = 0; i < draws; i++) {
    const level = def.levels[i % def.levels.length]!;
    let a: Assignment;
    try { a = sampleAssignment(def, level, r); } catch { discarded++; continue; }
    const sig = `${level.level}|${signature(a)}`;
    if (sigs.has(sig)) repetitions++;
    sigs.add(sig);
    try {
      const raw = evalIn(def.formula, toScope(a), def.answerUnit);
      const rounded = applyRounding(raw, resolveRounding(def.rounding, raw, def.answerUnit));
      if (!passesConstraints(def, a, rounded)) { discarded++; continue; }
      const rv = resolveVariant(def, level, a, i, seed);
      valid++;
      answers.push(dec(rv.variant.answer!.value));
      if (rv.collision) {
        collisions++;
        const p = rv.variant.predictedErrors.find((x) => x.value === rv.variant.answer!.value);
        if (examples.length < 5 && p) examples.push({ variantId: rv.variant.id, value: p.value, code: p.code });
      }
      if (!rv.doubleCheck.ok) dcFail++;
    } catch { discarded++; }
  }
  const sorted = answers.sort((x, y) => x.cmp(y));
  const min = sorted[0] ?? null; const max = sorted[sorted.length - 1] ?? null;
  const distribution: MassTestReport['distribution'] = [];
  if (min && max) {
    const bins = 8;
    const width = max.sub(min).div(bins);
    for (let b = 0; b < bins; b++) {
      const from = min.add(width.mul(b)); const to = b === bins - 1 ? max : min.add(width.mul(b + 1));
      const count = sorted.filter((v) => v.gte(from) && (b === bins - 1 ? v.lte(to) : v.lt(to))).length;
      distribution.push({ from: canon(from.toDecimalPlaces(3)), to: canon(to.toDecimalPlaces(3)), count });
    }
  }
  return {
    draws, valid, discardedPct: Math.round((discarded / draws) * 1000) / 10, repetitions,
    uniqueAnswers: new Set(sorted.map((v) => canon(v))).size, collisions, collisionExamples: examples,
    doubleCheckFailures: dcFail, extremes: { min: min ? canon(min) : null, max: max ? canon(max) : null }, distribution,
  };
}

export interface TemplateIssue {
  field: string;
  message: string;
  blocking: boolean;
}

/** Comprobaciones del editor y del envío a revisión. */
export function validateTemplate(def: TemplateDefinition): TemplateIssue[] {
  const issues: TemplateIssue[] = [];
  const units: Record<string, string> = {};
  for (const v of def.variables) {
    if (v.kind === 'case_table') for (const c of v.columns ?? []) units[`${v.name}.${c.name}`] = c.unit;
    else units[v.name] = v.unit;
  }
  if (!def.name.trim()) issues.push({ field: 'name', message: 'Falta el nombre de la plantilla', blocking: true });
  if (!def.formula.trim()) issues.push({ field: 'formula', message: 'Falta la fórmula', blocking: true });
  else {
    const dc = checkDimensions(def.formula, units, def.answerUnit);
    if (!dc.ok) issues.push({ field: 'formula', message: dc.message, blocking: true });
  }
  const stepUnits: Record<string, string> = { ...units, respuesta: def.answerUnit };
  def.steps.forEach((s, i) => {
    const dc = checkDimensions(s.formula, stepUnits, s.unit);
    if (!dc.ok) issues.push({ field: `steps.${i}`, message: `Paso ${i + 1}: ${dc.message}`, blocking: true });
    stepUnits[`paso${i + 1}`] = s.unit;
  });
  if (!def.steps.length) issues.push({ field: 'steps', message: 'La plantilla necesita los pasos de su explicación', blocking: true });
  def.predictedErrors.forEach((p, i) => {
    const dc = checkDimensions(p.formula, stepUnits, p.unit);
    if (!dc.ok) issues.push({ field: `predictedErrors.${i}`, message: `Error previsible ${i + 1}: ${dc.message}`, blocking: true });
  });
  if (def.levels.length !== 5) issues.push({ field: 'levels', message: 'Define los cinco niveles de dificultad', blocking: true });
  if (def.species && def.sectorId !== 'veterinaria') issues.push({ field: 'species', message: 'La especie solo se indica en veterinaria', blocking: true });
  for (const t of [def.statement, def.question, def.tts ?? '', def.plausibility]) {
    const clin = findClinicalUseText(t);
    if (clin) issues.push({ field: 'statement', message: `Texto con sugerencia de uso clínico: «${clin}»`, blocking: true });
  }
  const missing = findQuantitiesWithoutUnit(def.statement.replace(/\{[^}]+\}/g, 'X'));
  if (missing.length) issues.push({ field: 'statement', message: `Cantidad sin unidad en el enunciado: ${missing.join(', ')}`, blocking: true });
  if (!/simulad|perro|gato|niñ|caballo|conejo|hurón/i.test(def.statement) && /paciente/i.test(def.statement)) {
    issues.push({ field: 'statement', message: 'Las personas se presentan como «paciente simulado»', blocking: true });
  }
  return issues;
}

export { D };
