import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  canon, dec, formatEs, parseUserNumber, checkDimensions, evalIn, evalInB, grade, readQuantity, speakText,
  parseSpoken, generateVariants, massTest, validateTemplate, checkAdCreative, findClinicalUseText,
  findQuantitiesWithoutUnit, spellingFor, confirmationText, resolveVariant, type TemplateDefinition,
} from '../src/index.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '../../../contracts/fixtures');
const load = (f: string) => JSON.parse(readFileSync(join(root, f), 'utf8'));

describe('aritmética decimal y formato', () => {
  it('0,1 + 0,2 = 0,3 exacto', () => {
    expect(canon(dec('0.1').add(dec('0.2')))).toBe('0.3');
  });
  it('formato español: coma, cero inicial, sin ceros finales, espacio fino desde cinco cifras', () => {
    expect(formatEs('0.96')).toBe('0,96');
    expect(formatEs('5.0')).toBe('5');
    expect(formatEs('12500')).toBe('12 500');
    expect(formatEs('1500')).toBe('1500');
  });
  it('interpreta la entrada del teclado', () => {
    expect(parseUserNumber('4.8').value).toBe('4.8');
    expect(parseUserNumber(',5').unsafeFormat).toBe('missing_leading_zero');
    expect(parseUserNumber('5,0').unsafeFormat).toBe('trailing_zero');
    expect(parseUserNumber('1,2,3').ok).toBe(false);
  });
});

describe('fixtures de corrección compartidas', () => {
  const { cases } = load('grading.json');
  for (const c of cases) {
    it(c.name, () => {
      const r = grade(c.spec, c.predicted, c.input);
      expect(r.verdict).toBe(c.expect.verdict);
      if ('errorCode' in c.expect) expect(r.errorCode).toBe(c.expect.errorCode);
      if ('critical' in c.expect) expect(r.critical).toBe(c.expect.critical);
      if ('note' in c.expect) expect(r.note).toBe(c.expect.note);
      if ('value' in c.expect) expect(r.value).toBe(c.expect.value);
      if ('deviationStep' in c.expect) expect(r.deviationStep).toBe(c.expect.deviationStep);
    });
  }
});

describe('normalizador de lectura (fixtures compartidas)', () => {
  const f = load('tts.json');
  for (const q of f.quantities) it(`${q.value} ${q.unit}`, () => expect(readQuantity(q.value, q.unit)).toBe(q.spoken));
  for (const t of f.texts) it(t.text, () => expect(speakText(t.text)).toBe(t.spoken));
  it('lectura completa de «0,2 mg/kg» para el lector de pantalla', () => {
    expect(speakText('0,2 mg/kg')).toBe('cero coma dos miligramos por kilo');
  });
  it('confirmación hablada con unidad', () => {
    expect(confirmationText('4.8', 'ml/h')).toBe('Cuatro coma ocho mililitros por hora');
  });
  it('deletrea cifras que se confunden: «Sesenta: seis, cero»', () => {
    expect(spellingFor('60')).toBe('seis, cero');
    expect(spellingFor('4.8')).toBeNull();
  });
});

describe('gramática de cifras habladas (fixtures compartidas)', () => {
  const { cases } = load('spoken.json');
  for (const c of cases) {
    it(c.said, () => {
      const r = parseSpoken(c.said, { digitByDigit: c.digitByDigit, synonyms: c.synonyms });
      if (c.command) { expect(r).toEqual({ kind: 'command', command: c.command }); return; }
      if (c.ambiguous) { expect(r.kind).toBe('ambiguous'); if (r.kind === 'ambiguous') { expect(r.options).toEqual(c.ambiguous); expect(r.question).toBe(c.question); } return; }
      if (c.unparsed) { expect(r.kind).toBe('unparsed'); return; }
      expect(r.kind).toBe('number');
      if (r.kind === 'number') { expect(r.value).toBe(c.value); if (c.unit) expect(r.unit).toBe(c.unit); }
    });
  }
});

describe('comprobación dimensional', () => {
  const units = { dosis: 'mg/kg', peso: 'kg', concentracion: 'mg/ml' };
  it('mg/kg × kg ÷ mg/ml produce ml', () => {
    const r = checkDimensions('dosis × peso ÷ concentracion', units, 'ml');
    expect(r.ok).toBe(true);
    expect(r.message).toBe('La fórmula produce ml');
  });
  it('mg/kg × kg no produce ml', () => {
    const r = checkDimensions('dosis × peso', units, 'ml');
    expect(r.ok).toBe(false);
    expect(r.message).toBe('El resultado sale en mg, no en ml');
  });
  it('perfusión con constante con unidad: µg/kg/min × kg × 60[min/h] ÷ µg/ml = ml/h', () => {
    const scope = { dosis: { value: '0.1', unit: 'µg/kg/min' }, peso: { value: '80', unit: 'kg' }, conc: { value: '100', unit: 'µg/ml' } };
    expect(canon(evalIn('dosis × peso × 60[min/h] ÷ conc', scope, 'ml/h'))).toBe('4.8');
    expect(evalInB('dosis × peso × 60[min/h] ÷ conc', scope, 'ml/h').toDecimalString()).toBe('4.8');
  });
  it('mínimo() expresa la dosis máxima (paracetamol 15 mg/kg, máx. 1 g)', () => {
    const scope = { dosis: { value: '15', unit: 'mg/kg' }, peso: { value: '70', unit: 'kg' }, maximo: { value: '1', unit: 'g' }, conc: { value: '10', unit: 'mg/ml' } };
    expect(canon(evalIn('mínimo(dosis × peso; maximo) ÷ conc', scope, 'ml'))).toBe('100');
    expect(evalInB('mínimo(dosis × peso; maximo) ÷ conc', scope, 'ml').toDecimalString()).toBe('100');
  });
  it('conversión de µg a mg y porcentajes', () => {
    expect(canon(evalIn('x', { x: { value: '2', unit: '%' } }, 'mg/ml'))).toBe('20');
    expect(canon(evalIn('x', { x: { value: '500', unit: 'µg' } }, 'mg'))).toBe('0.5');
  });
});

const meloxicam: TemplateDefinition = {
  id: 'tpl-vet-meloxicam', version: 1, name: 'Meloxicam SC en perro', sectorId: 'veterinaria', skillId: 'H4', exerciseTypeId: 'T1', species: 'perro',
  variables: [
    { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
    { name: 'caso', label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [
      { name: 'farmaco', unit: '' }, { name: 'dosis', unit: 'mg/kg' }, { name: 'conc', unit: 'mg/ml' },
    ], rows: [{ farmaco: 'meloxicam', dosis: '0.2', conc: '5' }] },
  ],
  statement: 'Perro de {peso}. Pauta: {caso.farmaco} {caso.dosis} por vía subcutánea. Presentación: {caso.conc}.',
  question: '¿Qué volumen cargas?',
  formula: 'caso.dosis × peso ÷ caso.conc',
  answerUnit: 'ml', unitChoices: ['ml', 'mg', 'µg'], equivalents: [],
  rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' },
  constraints: { resultMin: '0.1', resultMax: '3', conditions: [] },
  predictedErrors: [
    { formula: 'respuesta × 10', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: 2 },
    { formula: 'caso.dosis × peso', unit: 'mg', code: 'E4', message: 'Has dado la dosis en mg: falta calcular el volumen', deviationStep: 2 },
    { formula: 'caso.dosis × peso × caso.conc ÷ 1[mg/ml] ÷ 1[mg] × 1[ml]', unit: 'ml', code: 'E3', message: 'Has multiplicado por la concentración en lugar de dividir', deviationStep: 2 },
  ],
  steps: [
    { text: 'Dosis', formula: 'caso.dosis × peso', unit: 'mg', operation: '{caso.dosis} × {peso}', cancelled: ['kg'] },
    { text: 'Volumen', formula: 'paso1 ÷ caso.conc', unit: 'ml', operation: '{paso1} ÷ {caso.conc}', cancelled: ['mg'] },
  ],
  plausibility: '{respuesta} en una jeringa de 1 ml. Tiene sentido.',
  levels: [1, 2, 3, 4, 5].map((l) => ({ level: l as 1, unitFixed: l <= 3, targetTimeS: 25 + l * 5, overrides: l === 1 ? { peso: { multipleOf: '10' } } : undefined })),
  variantsPerLevel: 30,
};

describe('generador de variantes', () => {
  it('la plantilla es válida', () => {
    expect(validateTemplate(meloxicam).filter((i) => i.blocking)).toEqual([]);
  });
  it('genera 20 variantes de muestra con enunciado, respuesta en ml y pasos', () => {
    const { variants } = generateVariants(meloxicam, { perLevel: 20, levels: [3] });
    expect(variants).toHaveLength(20);
    for (const rv of variants) {
      expect(rv.variant.answer!.unit).toBe('ml');
      expect(rv.variant.steps).toHaveLength(2);
      expect(rv.doubleCheck.ok).toBe(true);
      const v = dec(rv.variant.answer!.value);
      expect(v.gte('0.1') && v.lte('3')).toBe(true);
    }
  });
  it('perro de 24 kg: 0,96 ml con los errores previsibles 9,6 / 4,8 / 24', () => {
    const a = { peso: { value: '24', unit: 'kg' }, 'caso.farmaco': { value: '0', unit: '', text: 'meloxicam' }, 'caso.dosis': { value: '0.2', unit: 'mg/kg' }, 'caso.conc': { value: '5', unit: 'mg/ml' } };
    const rv = resolveVariant(meloxicam, meloxicam.levels[2]!, a, 0, 1);
    expect(rv.variant.answer!.value).toBe('0.96');
    expect(rv.variant.predictedErrors.map((p) => `${p.value} ${p.unit} ${p.code}`)).toEqual(['9.6 ml E2', '4.8 mg E4', '24 ml E3']);
    expect(rv.variant.steps.map((s) => s.operation)).toEqual(['0,2 mg/kg × 24 kg', '4,8 mg ÷ 5 mg/ml']);
    expect(rv.variant.statement.some((s) => s.t === 'text' && s.v.includes('meloxicam'))).toBe(true);
    expect(rv.doubleCheck).toEqual({ a: '0.96', b: '0.96', ok: true, predictedOk: true });
    expect(rv.variant.plausibility).toBe('0,96 ml en una jeringa de 1 ml. Tiene sentido.');
  });
  it('nivel 1 con pesos múltiplos de 10', () => {
    const { variants } = generateVariants(meloxicam, { perLevel: 3, levels: [1] });
    for (const rv of variants) expect(Number(rv.assignment.peso!.value) % 10).toBe(0);
  });
  it('tabla de casos: cada variante usa una fila completa', () => {
    const def: TemplateDefinition = { ...meloxicam, variables: [meloxicam.variables[0]!, { ...meloxicam.variables[1]!, rows: [
      { farmaco: 'meloxicam', dosis: '0.2', conc: '5' }, { farmaco: 'meloxicam', dosis: '0.1', conc: '1.5' },
    ] }] };
    const { variants } = generateVariants(def, { perLevel: 30, levels: [3] });
    for (const rv of variants) {
      const pair = `${rv.assignment['caso.dosis']!.value}|${rv.assignment['caso.conc']!.value}`;
      expect(['0.2|5', '0.1|1.5']).toContain(pair);
    }
  });
  it('enunciado rotulado, texto para voz con datos primero y pregunta al final', () => {
    const { variants } = generateVariants(meloxicam, { perLevel: 1, levels: [2] });
    const v = variants[0]!.variant;
    expect(v.tts.endsWith('Redondea a la centésima.')).toBe(true);
    expect(v.tts).toContain('miligramos por kilo');
    expect(v.question.startsWith('¿Qué volumen cargas?')).toBe(true);
  });
  it('prueba masiva de 1000 informa descartes, distribución y extremos', () => {
    const r = massTest(meloxicam, 1000);
    expect(r.draws).toBe(1000);
    expect(r.valid).toBeGreaterThan(500);
    expect(r.distribution.length).toBe(8);
    expect(r.doubleCheckFailures).toBe(0);
  });
  it('detecta colisiones entre la respuesta correcta y una errónea previsible', () => {
    const def: TemplateDefinition = { ...meloxicam, predictedErrors: [{ formula: 'respuesta', unit: 'ml', code: 'E3', message: 'colisión forzada' }] };
    const r = massTest(def, 100);
    expect(r.collisions).toBeGreaterThan(0);
  });
  it('impide guardar una fórmula con unidades incoherentes', () => {
    const issues = validateTemplate({ ...meloxicam, formula: 'caso.dosis × peso' });
    expect(issues.some((i) => i.message === 'El resultado sale en mg, no en ml')).toBe(true);
  });
  it('impide enviar a revisión una plantilla sin pasos', () => {
    expect(validateTemplate({ ...meloxicam, steps: [] }).some((i) => i.field === 'steps')).toBe(true);
  });
});

describe('límite formativo y anuncios', () => {
  it('rechaza textos con sugerencia de uso clínico', () => {
    expect(findClinicalUseText('Practica y úsalo en tu guardia')).toBeTruthy();
    expect(findClinicalUseText('VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.')).toBeNull();
  });
  it('detecta cantidades sin unidad', () => {
    expect(findQuantitiesWithoutUnit('Pauta: 0,2 por vía oral')).toEqual(['0,2']);
    expect(findQuantitiesWithoutUnit('Perro de 24 kg. Adrenalina 1:10 000')).toEqual([]);
  });
  it('rechaza creatividades con términos vetados o demasiado largas', () => {
    expect(checkAdCreative({ headline: 'Úsalo con tu paciente', body: 'Texto', cta: 'Ver', voiceSpot: null }).length).toBeGreaterThan(0);
    expect(checkAdCreative({ headline: 'Entrena sin pausas', body: 'Con Premium pasas de un ejercicio al siguiente sin anuncios.', cta: 'Quitar anuncios', voiceSpot: 'Con Premium, entrenas sin estas pausas.' })).toEqual([]);
    expect(checkAdCreative({ headline: '{espera_s} s × {ejercicios} ejercicios = {total_s} s', body: 'Es lo que duran las pausas de esta lección. Con Premium son tiempo de práctica.', cta: 'Quitar anuncios', voiceSpot: 'Estas pausas suman {total_s} segundos por lección. Premium las quita.' })).toEqual([]);
  });
});
