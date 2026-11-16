/**
 * Preguntas fijas, sin variantes (editor de preguntas, sección 8.6).
 * Habituales en T2, T3, T6 y T7; también admiten T1 con números cerrados.
 */
import type { AnswerSpec, ChoiceOption, ExplanationStep, OrderItem, PredictedError, SkillCode, StatementSegment, Variant, ConversionItem } from '@vtm/contracts';
import { canon } from './decimal.js';
import { speakText } from './speech.js';
import { findClinicalUseText, findQuantitiesWithoutUnit } from './textcheck.js';
import { segmentsToSpeech } from './template.js';

export interface QuestionDefinition {
  id: string;
  version: number;
  name: string;
  exerciseTypeId: 'T1' | 'T2' | 'T3' | 'T6' | 'T7' | string;
  exerciseTypeVersion?: number;
  sectorId: string;
  skillId: SkillCode;
  level: 1 | 2 | 3 | 4 | 5;
  targetTimeS: number;
  statement: string;
  question: string;
  tts?: string | null;
  answer?: AnswerSpec;
  options?: Omit<ChoiceOption, 'id'>[];
  orderItems?: OrderItem[];
  validOrders?: string[][];
  series?: { prompt: string; value: string; unit: string; tts?: string }[];
  predictedErrors?: PredictedError[];
  steps: ExplanationStep[];
  plausibility: string;
  hint?: string;
  approach?: string;
  demo?: boolean;
}

/** Convierte el texto con cantidades escritas en segmentos («0,2 mg/kg» queda resaltado). */
export function textToSegments(text: string): StatementSegment[] {
  const re = /(\d{1,3}(?:[  ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?)\s?(µg\/kg\/min|mg\/kg\/día|mg\/kg|µg\/kg|UI\/kg|mg\/ml|µg\/ml|UI\/ml|ml\/h|ml\/kg\/día|gotas\/min|gotas\/ml|µg|mg|kg|g|ml|UI|%|h|min)(?![\p{L}\/])/gu;
  const segs: StatementSegment[] = [];
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    if (m.index > last) segs.push({ t: 'text', v: text.slice(last, m.index) });
    segs.push({ t: 'qty', value: canon(m[1]!.replace(/[  ]/g, '').replace(',', '.')), unit: m[2]! });
    last = re.lastIndex;
  }
  if (last < text.length) segs.push({ t: 'text', v: text.slice(last) });
  return segs;
}

export function resolveQuestion(q: QuestionDefinition): Variant {
  const statement = textToSegments(q.statement);
  const options: ChoiceOption[] | undefined = q.options?.map((o, i) => ({ ...o, id: String.fromCharCode(97 + i) }));
  const series: ConversionItem[] | undefined = q.series?.map((s) => ({
    prompt: s.prompt,
    tts: s.tts ?? speakText(s.prompt),
    answer: { value: canon(s.value), unit: s.unit, unitFixed: true, unitChoices: [s.unit], equivalents: [], rounding: { mode: 'none' }, tolerance: { kind: 'exact' } },
  }));
  return {
    id: `${q.id}.v${q.version}`,
    templateId: null,
    questionId: q.id,
    templateVersion: q.version,
    level: q.level,
    exerciseTypeId: q.exerciseTypeId,
    exerciseTypeVersion: q.exerciseTypeVersion ?? 1,
    skillId: q.skillId,
    sectorId: q.sectorId,
    statement,
    question: q.question,
    tts: q.tts ? speakText(q.tts) : `${segmentsToSpeech(statement)} ${speakText(q.question)}`.trim(),
    approach: q.approach,
    hint: q.hint,
    targetTimeS: q.targetTimeS,
    answer: q.answer,
    predictedErrors: q.predictedErrors ?? [],
    steps: q.steps,
    plausibility: q.plausibility,
    options,
    orderItems: q.orderItems,
    validOrders: q.validOrders,
    series,
    demo: q.demo ?? true,
  };
}

export interface QuestionIssue { field: string; message: string; blocking: boolean }

/** Comprobaciones automáticas al enviar una pregunta a revisión. */
export function validateQuestion(q: QuestionDefinition, existingStatements: string[] = []): QuestionIssue[] {
  const issues: QuestionIssue[] = [];
  if (!q.statement.trim()) issues.push({ field: 'statement', message: 'Falta el enunciado', blocking: true });
  if (!q.steps.length) issues.push({ field: 'steps', message: 'Falta la explicación paso a paso', blocking: true });
  const tts = q.tts ?? '';
  if (q.tts === '') issues.push({ field: 'tts', message: 'Falta el texto para voz', blocking: true });
  void tts;
  const missing = findQuantitiesWithoutUnit(q.statement);
  if (missing.length) issues.push({ field: 'statement', message: `Cantidad sin unidad: ${missing.join(', ')}`, blocking: true });
  for (const t of [q.statement, q.question, q.plausibility]) {
    const c = findClinicalUseText(t);
    if (c) issues.push({ field: 'statement', message: `Texto con sugerencia de uso clínico: «${c}»`, blocking: true });
  }
  if (['T2', 'T6'].includes(q.exerciseTypeId)) {
    const opts = q.options ?? [];
    if (opts.length < 3 || opts.length > 4) issues.push({ field: 'options', message: 'Entre 3 y 4 opciones', blocking: true });
    if (opts.filter((o) => o.correct).length !== 1) issues.push({ field: 'options', message: 'Debe haber exactamente una opción correcta', blocking: true });
    if (q.exerciseTypeId === 'T2') for (const o of opts) if (!o.correct && !o.errorCode) issues.push({ field: 'options', message: `Falta el tipo de error de la opción «${o.label}»`, blocking: true });
  }
  if (q.exerciseTypeId === 'T3') {
    if (!q.orderItems?.length || !q.validOrders?.length) issues.push({ field: 'orderItems', message: 'Faltan los pasos o los órdenes válidos', blocking: true });
  }
  if (q.exerciseTypeId === 'T7' && (q.series?.length ?? 0) !== 10) issues.push({ field: 'series', message: 'La conversión relámpago tiene diez conversiones', blocking: true });
  if (q.exerciseTypeId === 'T1' && !q.answer) issues.push({ field: 'answer', message: 'Falta la respuesta correcta', blocking: true });
  if (existingStatements.some((s) => s.trim().toLowerCase() === q.statement.trim().toLowerCase())) {
    issues.push({ field: 'statement', message: 'Posible duplicado de otra pregunta', blocking: false });
  }
  return issues;
}
