/**
 * Corrección de respuestas numéricas (capacidad answer-grading).
 *
 * El dispositivo no calcula fórmulas: compara la respuesta con los valores
 * verificados de la variante. Esta implementación la usa el back office para
 * «Simular respuesta»; la app Dart tiene un espejo que pasa los mismos casos de
 * `contracts/fixtures/grading.json`.
 */
import type { AnswerSpec, ErrorCode, PredictedError, Verdict } from '@vtm/contracts';
import { CRITICAL_CODES } from '@vtm/contracts';
import { type Dec, dec, canon, decimalsOf, formatEs, parseUserNumber, roundPlaces, roundStep } from './decimal.js';
import { parseUnit, sameDims } from './units.js';

export interface GradeInput {
  raw: string;
  /** Unidad elegida por el usuario; se ignora si la unidad es fija. */
  unit?: string | null;
}

export interface GradeResult {
  verdict: Exclude<Verdict, 'dont_know' | 'skipped'>;
  /** Cifra canónica que se registra en el intento. */
  value: string | null;
  unit: string | null;
  note: string | null;
  errorCode: ErrorCode | null;
  diagnosis: string | null;
  critical: boolean;
  deviationStep: number | null;
  correctDisplay: string;
}

function applyRounding(v: Dec, spec: AnswerSpec): Dec {
  const r = spec.rounding;
  if (r.mode === 'decimals') return roundPlaces(v, r.places);
  if (r.mode === 'instrument') return roundStep(v, dec(r.step));
  if (r.mode === 'integer') return roundPlaces(v, 0);
  return v;
}

function requiredPlaces(spec: AnswerSpec): number | null {
  const r = spec.rounding;
  if (r.mode === 'decimals') return r.places;
  if (r.mode === 'integer') return 0;
  if (r.mode === 'instrument') return decimalsOf(canon(r.step));
  return null;
}

function withinTolerance(v: Dec, correct: Dec, spec: AnswerSpec): boolean {
  const t = spec.tolerance;
  if (t.kind === 'exact') return v.eq(correct);
  if (t.kind === 'abs') return v.sub(correct).abs().lte(dec(t.value));
  return v.sub(correct).abs().lte(correct.abs().mul(dec(t.percent)).div(100));
}

export function displayQty(value: string, unit: string): string {
  return unit === '%' ? `${formatEs(value)} %` : `${formatEs(value)} ${unit}`.trim();
}

/** Valor del usuario expresado en la unidad de la respuesta, o null si la unidad no es equivalente. */
function toAnswerUnit(v: Dec, unit: string, spec: AnswerSpec): Dec | null {
  if (unit === spec.unit) return v;
  const eq = spec.equivalents.find((e) => e.unit === unit);
  if (eq) return v.div(dec(eq.factor));
  return null;
}

function isCritical(code: ErrorCode | null, v: Dec | null, correct: Dec): boolean {
  if (code && CRITICAL_CODES.includes(code)) return true;
  if (v === null) return false;
  if (correct.isZero()) return !v.isZero();
  if (v.isZero()) return true;
  const ratio = v.div(correct).abs();
  return ratio.gte(5) || ratio.lte(dec(1).div(5));
}

function matchesPredicted(v: Dec, userUnit: string, spec: AnswerSpec, p: PredictedError): boolean {
  let target = dec(p.value);
  // Si la unidad prevista es convertible a la del usuario, se compara en la unidad del usuario.
  if (p.unit && p.unit !== userUnit) {
    try {
      const a = parseUnit(p.unit); const b = parseUnit(userUnit);
      if (sameDims(a.dims, b.dims)) target = target.mul(a.factor).div(b.factor);
      else if (!spec.unitFixed) return false; // con unidad elegida, la magnitud debe coincidir
    } catch { /* unidad no catalogada: compara la cifra */ }
  }
  const places = requiredPlaces(spec);
  if (v.eq(target)) return true;
  if (places !== null) return roundPlaces(v, places).eq(roundPlaces(target, places));
  return false;
}

export function grade(spec: AnswerSpec, predicted: PredictedError[], input: GradeInput): GradeResult {
  const correct = dec(spec.value);
  const correctDisplay = displayQty(spec.value, spec.unit);
  const parsed = parseUserNumber(input.raw);
  const base: Omit<GradeResult, 'verdict'> = {
    value: parsed.value ?? null,
    unit: spec.unitFixed ? spec.unit : input.unit ?? null,
    note: null, errorCode: null, diagnosis: null, critical: false, deviationStep: null, correctDisplay,
  };
  if (!parsed.ok || parsed.value === undefined) {
    return { ...base, verdict: 'incorrect', critical: false };
  }
  const v = dec(parsed.value);
  const userUnit = spec.unitFixed ? spec.unit : (input.unit ?? '');
  const formatNote = parsed.unsafeFormat === 'missing_leading_zero'
    ? `Se escribe con cero delante: ${formatEs(parsed.value)}`
    : parsed.unsafeFormat === 'trailing_zero'
      ? `Sin ceros finales: ${formatEs(parsed.value)}`
      : null;

  const inAnswerUnit = toAnswerUnit(v, userUnit, spec);
  if (inAnswerUnit !== null) {
    if (withinTolerance(inAnswerUnit, correct, spec)) {
      return { ...base, verdict: formatNote ? 'correct_note' : 'correct', note: formatNote };
    }
    // Más decimales de los pedidos que redondean al valor correcto.
    const places = requiredPlaces(spec);
    if (places !== null && decimalsOf(canon(inAnswerUnit)) > places && withinTolerance(applyRounding(inAnswerUnit, spec), correct, spec)) {
      return { ...base, verdict: 'correct_note', note: `Se redondea a ${correctDisplay}` };
    }
  }

  // Respuesta incorrecta: diagnóstico por respuestas erróneas previsibles.
  for (const p of predicted) {
    if (matchesPredicted(v, userUnit, spec, p)) {
      if (p.code === 'E7') {
        return { ...base, verdict: 'correct_note', note: p.message, errorCode: 'E7' };
      }
      return {
        ...base, verdict: 'incorrect', errorCode: p.code, diagnosis: p.message,
        critical: isCritical(p.code, inAnswerUnit, correct), deviationStep: p.deviationStep ?? null,
      };
    }
  }

  // Cifra correcta con una unidad equivocada: E1.
  if (inAnswerUnit === null) {
    const sameNumber = v.eq(correct);
    return {
      ...base, verdict: 'incorrect', errorCode: 'E1',
      diagnosis: sameNumber ? `La cifra es correcta, pero en ${spec.unit}, no en ${userUnit}` : `La unidad no corresponde: se pedía en ${spec.unit}`,
      critical: true,
    };
  }

  // Orden de magnitud no declarado: ×/÷ 10, 100 o 1000.
  if (!correct.isZero() && !inAnswerUnit.isZero()) {
    const ratio = inAnswerUnit.div(correct);
    for (const k of [10, 100, 1000]) {
      if (ratio.eq(k) || ratio.eq(dec(1).div(k))) {
        const bigger = ratio.gt(1);
        const word = k === 10 ? 'diez' : k === 100 ? 'cien' : 'mil';
        return {
          ...base, verdict: 'incorrect', errorCode: 'E2',
          diagnosis: `Tu respuesta es ${word} veces ${bigger ? 'mayor' : 'menor'}. Revisa la coma y las conversiones`,
          critical: true,
        };
      }
    }
  }

  return { ...base, verdict: 'incorrect', critical: isCritical(null, inAnswerUnit, correct) };
}

/** Respuesta a una opción (T2, T6). */
export function gradeChoice(options: { id: string; correct: boolean; errorCode?: ErrorCode; message?: string }[], chosenId: string) {
  const o = options.find((x) => x.id === chosenId);
  if (!o) return { verdict: 'incorrect' as const, errorCode: null, diagnosis: null, critical: false };
  if (o.correct) return { verdict: 'correct' as const, errorCode: null, diagnosis: null, critical: false };
  const code = o.errorCode ?? null;
  return { verdict: 'incorrect' as const, errorCode: code, diagnosis: o.message ?? null, critical: code ? CRITICAL_CODES.includes(code) : false };
}

/** Ordenar pasos (T3): válido si coincide con cualquiera de los órdenes declarados. */
export function gradeOrder(validOrders: string[][], answer: string[]): boolean {
  return validOrders.some((o) => o.length === answer.length && o.every((x, i) => x === answer[i]));
}
