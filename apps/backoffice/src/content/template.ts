/** Ayudas del editor de plantillas: definición vacía, unidades y comprobaciones con el motor compartido. */
import { checkDimensions, generateVariants, massTest, validateTemplate, type LevelDef, type TemplateDefinition, type TemplateIssue } from '@vtm/engine';
import type { ErrorCode } from '@vtm/contracts';

export function defaultLevels(): LevelDef[] {
  return ([1, 2, 3, 4, 5] as const).map((l) => ({ level: l, unitFixed: l <= 3, targetTimeS: 20 + (l - 1) * 5 }));
}

export function newTemplate(): TemplateDefinition {
  return {
    id: '', version: 1, name: '', sectorId: 'comun', skillId: 'H4', exerciseTypeId: 'T1', species: null,
    variables: [], statement: '', question: '', tts: null, formula: '', answerUnit: 'ml', unitChoices: ['ml'], equivalents: [],
    rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' }, constraints: { conditions: [] },
    predictedErrors: [], steps: [], plausibility: '', levels: defaultLevels(), variantsPerLevel: 300,
  };
}

/** Normaliza una definición recibida de la API (campos opcionales que el editor necesita). */
export function normalizeTemplate(d: Partial<TemplateDefinition>): TemplateDefinition {
  const base = newTemplate();
  return {
    ...base, ...d,
    variables: d.variables ?? [], constraints: { conditions: [], ...(d.constraints ?? {}) }, predictedErrors: d.predictedErrors ?? [],
    steps: d.steps ?? [], levels: d.levels?.length ? d.levels : base.levels, equivalents: d.equivalents ?? [], unitChoices: d.unitChoices ?? [d.answerUnit ?? 'ml'],
  } as TemplateDefinition;
}

export function unitsOf(def: TemplateDefinition): Record<string, string> {
  const units: Record<string, string> = {};
  for (const v of def.variables) {
    if (v.kind === 'case_table') for (const c of v.columns ?? []) units[`${v.name}.${c.name}`] = c.unit;
    else units[v.name] = v.unit;
  }
  return units;
}

export function formulaCheck(def: TemplateDefinition): { ok: boolean; message: string } | null {
  if (!def.formula.trim()) return null;
  const r = checkDimensions(def.formula, unitsOf(def), def.answerUnit);
  return { ok: r.ok, message: r.message };
}

export function issuesOf(def: TemplateDefinition): TemplateIssue[] {
  try { return validateTemplate(def); } catch (e) { return [{ field: 'formula', message: (e as Error).message, blocking: true }]; }
}

export interface SampleRow {
  id: string; level: number; statement: string; question: string; answer: string; unit: string; unrounded: string;
  assignment: Record<string, { value: string; unit: string; text?: string }>; doubleCheck: { a: string; b: string; ok: boolean }; collision: boolean;
  predicted: { value: string; unit: string; code: ErrorCode; message: string }[]; steps: { n: number; text: string; operation: string; result: { value: string; unit: string } }[];
}

export function sample(def: TemplateDefinition, n = 20, level?: number, seed = Date.now() % 100000): { rows: SampleRow[]; error?: string } {
  try {
    const levels = level ? [level] : def.levels.map((l) => l.level);
    const perLevel = Math.max(1, Math.ceil(n / levels.length));
    const res = generateVariants(def, { perLevel, levels, seed });
    const rows = res.variants.slice(0, n).map((r) => ({
      id: r.variant.id, level: r.variant.level,
      statement: r.variant.statement.map((s) => (s.t === 'text' ? s.v : `${s.value.replace('.', ',')} ${s.unit}`)).join(''),
      question: r.variant.question, answer: r.variant.answer!.value, unit: r.variant.answer!.unit, unrounded: r.unrounded,
      assignment: r.assignment, doubleCheck: r.doubleCheck, collision: r.collision,
      predicted: r.variant.predictedErrors.map((p) => ({ value: p.value, unit: p.unit, code: p.code, message: p.message })),
      steps: r.variant.steps,
    }));
    return { rows };
  } catch (e) {
    return { rows: [], error: (e as Error).message };
  }
}

export interface MassReport {
  draws: number; valid: number; discardedPct: number; repetitions: number; uniqueAnswers: number; collisions: number;
  collisionExamples: { variantId: string; value: string; code: string }[]; doubleCheckFailures: number;
  extremes: { min: string | null; max: string | null }; distribution: { from: string; to: string; count: number }[];
  shortfall: { level: number; generated: number; requested: number }[];
  error?: string;
}

/** Prueba masiva de 1000 extracciones y recuento de variantes publicables por nivel. */
export function runMassTest(def: TemplateDefinition, draws = 1000): MassReport {
  try {
    const mt = massTest(def, draws);
    const gen = generateVariants(def, { perLevel: def.variantsPerLevel, seed: 1 });
    const shortfall = gen.reports.filter((r) => r.generated < r.requested).map((r) => ({ level: r.level, generated: r.generated, requested: r.requested }));
    return { ...mt, shortfall };
  } catch (e) {
    return { draws, valid: 0, discardedPct: 100, repetitions: 0, uniqueAnswers: 0, collisions: 0, collisionExamples: [], doubleCheckFailures: 0, extremes: { min: null, max: null }, distribution: [], shortfall: [], error: (e as Error).message };
  }
}

/** Errores habituales que el autor añade con un botón (B08). */
export function commonError(code: 'E1' | 'E2' | 'E4' | 'E6', def: TemplateDefinition): TemplateDefinition['predictedErrors'][number] {
  const u = def.answerUnit;
  switch (code) {
    case 'E1': return { formula: 'respuesta × 1000', unit: u, code: 'E1', message: 'Revisa la conversión de unidades: te sobra un factor 1000', deviationStep: 1 };
    case 'E2': return { formula: 'respuesta × 10', unit: u, code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: def.steps.length || 1 };
    case 'E4': return { formula: 'paso1', unit: def.steps[0]?.unit ?? u, code: 'E4', message: 'Te has quedado en un paso intermedio', deviationStep: 2 };
    default: return { formula: '', unit: u, code: 'E6', message: 'No has aplicado el límite de dosis', deviationStep: def.steps.length || 1 };
  }
}
