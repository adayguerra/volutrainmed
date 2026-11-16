/**
 * Analizador de respuestas habladas en español de España (sección 7.3).
 *
 * El reconocedor devuelve texto; este analizador lo convierte en una cifra con
 * su unidad, en un comando o en una ambigüedad que hay que preguntar.
 * Antes del análisis se aplica el léxico de confusiones editable en el back office.
 *
 * La app Dart tiene una implementación espejo que pasa los mismos casos de
 * `contracts/fixtures/spoken.json`.
 */

export type SpokenCommand =
  | 'repite' | 'repite_datos' | 'siguiente' | 'no_lo_se' | 'pausa' | 'continua'
  | 'si' | 'no' | 'explica' | 'salta' | 'mas_despacio' | 'mas_rapido'
  | 'cifra_a_cifra' | 'teclado' | 'salir' | 'mas_informacion' | 'empezar';

export const DEFAULT_COMMANDS: Record<SpokenCommand, string[]> = {
  repite: ['repite', 'otra vez', 'repítelo', 'repitelo'],
  repite_datos: ['repite los datos', 'los datos'],
  siguiente: ['siguiente', 'continuar'],
  no_lo_se: ['no lo sé', 'no lo se', 'ni idea'],
  pausa: ['pausa', 'espera', 'un momento'],
  continua: ['continúa', 'continua', 'sigue'],
  si: ['sí', 'si', 'correcto', 'eso es', 'vale', 'confirmar'],
  no: ['no', 'incorrecto', 'corrige'],
  explica: ['explica', 'cómo se hace', 'como se hace'],
  salta: ['salta'],
  mas_despacio: ['más despacio', 'mas despacio'],
  mas_rapido: ['más rápido', 'mas rapido'],
  cifra_a_cifra: ['cifra a cifra'],
  teclado: ['teclado', 'escribir'],
  salir: ['salir', 'terminar'],
  mas_informacion: ['más información', 'mas informacion', 'más info'],
  empezar: ['empezar', 'empieza'],
};

export const DEFAULT_CONFUSIONS: Record<string, string> = {
  como: 'coma', toma: 'coma', goma: 'coma', cerro: 'cero', tos: 'dos', ocio: 'ocho', sei: 'seis',
};

/** Formas habladas de las unidades (léxico de unidades). */
export const DEFAULT_UNIT_FORMS: Record<string, string[]> = {
  'ml/h': ['mililitros por hora', 'mililitros hora', 'mililitros a la hora', 'mililitro por hora'],
  'gotas/min': ['gotas por minuto', 'gotas minuto', 'gotas al minuto'],
  'mg/ml': ['miligramos por mililitro', 'miligramos mililitro'],
  'µg/ml': ['microgramos por mililitro', 'microgramos mililitro'],
  'µg/kg/min': ['microgramos por kilo y minuto', 'microgramos kilo minuto', 'microgramos por kilo por minuto'],
  'mg/kg': ['miligramos por kilo', 'miligramos kilo'],
  'µg/h': ['microgramos por hora', 'microgramos hora'],
  'µg/min': ['microgramos por minuto', 'microgramos minuto'],
  'mg/h': ['miligramos por hora', 'miligramos hora'],
  'UI/ml': ['unidades por mililitro', 'unidades internacionales por mililitro'],
  ml: ['mililitros', 'mililitro', 'eme ele', 'ce ce', 'centímetros cúbicos', 'centimetros cubicos'],
  mg: ['miligramos', 'miligramo'],
  'µg': ['microgramos', 'microgramo'],
  g: ['gramos', 'gramo'],
  UI: ['unidades internacionales', 'unidades', 'unidad'],
  '%': ['por ciento'],
  h: ['horas', 'hora'],
  min: ['minutos', 'minuto'],
  kg: ['kilos', 'kilo', 'kilogramos'],
  gotas: ['gotas', 'gota'],
};

export interface SpokenOptions {
  digitByDigit?: boolean;
  confusions?: Record<string, string>;
  commands?: Record<string, string[]>;
  unitForms?: Record<string, string[]>;
  /** Sinónimos activados: forma hablada → unidad. «gammas» → «µg». */
  synonyms?: Record<string, string>;
}

export type SpokenResult =
  | { kind: 'number'; value: string; unit: string | null; spokenUnit?: string }
  | { kind: 'command'; command: SpokenCommand }
  | { kind: 'ambiguous'; options: string[]; question: string; unit: string | null }
  | { kind: 'unparsed'; reason: 'empty' | 'no_number' };

const DIGIT: Record<string, number> = {
  cero: 0, uno: 1, un: 1, una: 1, dos: 2, tres: 3, cuatro: 4, cinco: 5, seis: 6, siete: 7, ocho: 8, nueve: 9,
};
const SMALL: Record<string, number> = {
  ...DIGIT,
  diez: 10, once: 11, doce: 12, trece: 13, catorce: 14, quince: 15, dieciseis: 16, diecisiete: 17, dieciocho: 18, diecinueve: 19,
  veinte: 20, veintiuno: 21, veintiun: 21, veintiuna: 21, veintidos: 22, veintitres: 23, veinticuatro: 24, veinticinco: 25,
  veintiseis: 26, veintisiete: 27, veintiocho: 28, veintinueve: 29,
};
const TENS: Record<string, number> = { treinta: 30, cuarenta: 40, cincuenta: 50, sesenta: 60, setenta: 70, ochenta: 80, noventa: 90 };
const HUNDREDS: Record<string, number> = {
  cien: 100, ciento: 100, doscientos: 200, doscientas: 200, trescientos: 300, trescientas: 300, cuatrocientos: 400, cuatrocientas: 400,
  quinientos: 500, quinientas: 500, seiscientos: 600, seiscientas: 600, setecientos: 700, setecientas: 700,
  ochocientos: 800, ochocientas: 800, novecientos: 900, novecientas: 900,
};

function strip(s: string): string {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').normalize('NFC');
}

function normalizeUtterance(text: string, confusions: Record<string, string>): string[] {
  const words = strip(text.toLowerCase()).replace(/[¿?¡!.,;:«»"]/g, ' ').split(/\s+/).filter(Boolean);
  return words.map((w) => confusions[w] ?? w);
}

function isNumberWord(w: string): boolean {
  return w in SMALL || w in TENS || w in HUNDREDS || w === 'mil' || w === 'y';
}

/** Cardinal de 0 a 999 999 en palabras → número, o null si no encaja. */
export function parseCardinal(words: string[]): number | null {
  if (!words.length) return null;
  let total = 0;
  let current = 0;
  let i = 0;
  let sawAny = false;
  while (i < words.length) {
    const w = words[i]!;
    if (w in HUNDREDS) { current += HUNDREDS[w]!; sawAny = true; i++; continue; }
    if (w in TENS) {
      current += TENS[w]!; sawAny = true; i++;
      if (words[i] === 'y' && words[i + 1] && words[i + 1]! in DIGIT && DIGIT[words[i + 1]!]! > 0) { current += DIGIT[words[i + 1]!]!; i += 2; }
      continue;
    }
    if (w in SMALL) { current += SMALL[w]!; sawAny = true; i++; continue; }
    if (w === 'mil') { total += (current || 1) * 1000; current = 0; sawAny = true; i++; continue; }
    return null;
  }
  return sawAny ? total + current : null;
}

/** ¿Es una secuencia de cifras sueltas («dos cinco»)? */
function allDigits(words: string[]): boolean {
  return words.length > 1 && words.every((w) => w in DIGIT);
}

/** Parte decimal: cifras sueltas («cero cinco») o cardinales («veinticinco»). */
function parseDecimalWords(words: string[]): string | null {
  let out = '';
  let i = 0;
  while (i < words.length) {
    const w = words[i]!;
    if (w in DIGIT && !(words[i + 1] === 'y')) {
      out += String(DIGIT[w]); i++; continue;
    }
    // Cardinal de varias palabras: toma el tramo máximo que encaje.
    let j = words.length;
    let found: number | null = null;
    for (; j > i; j--) {
      const v = parseCardinal(words.slice(i, j));
      if (v !== null) { found = v; break; }
    }
    if (found === null) return null;
    out += String(found);
    i = j;
  }
  return out;
}

function canonDecimal(int: string, frac: string): string {
  const f = frac.replace(/0+$/, '');
  const i = String(BigInt(int || '0'));
  return f ? `${i}.${f}` : i;
}

function matchCommand(words: string[], commands: Record<string, string[]>): SpokenCommand | null {
  const utter = words.join(' ');
  let best: { cmd: SpokenCommand; len: number } | null = null;
  for (const [cmd, syns] of Object.entries(commands)) {
    for (const s of syns) {
      const norm = strip(s.toLowerCase());
      if (utter === norm && (!best || norm.length > best.len)) best = { cmd: cmd as SpokenCommand, len: norm.length };
    }
  }
  return best?.cmd ?? null;
}

function extractUnit(words: string[], unitForms: Record<string, string[]>, synonyms: Record<string, string>): { unit: string | null; spoken?: string; rest: string[] } {
  const text = words.join(' ');
  const candidates: { unit: string; form: string }[] = [];
  for (const [unit, forms] of Object.entries(unitForms)) for (const f of forms) candidates.push({ unit, form: strip(f.toLowerCase()) });
  for (const [form, unit] of Object.entries(synonyms)) candidates.push({ unit, form: strip(form.toLowerCase()) });
  candidates.sort((a, b) => b.form.length - a.form.length);
  for (const c of candidates) {
    if (text === c.form || text.endsWith(' ' + c.form)) {
      const rest = text.slice(0, text.length - c.form.length).trim();
      return { unit: c.unit, spoken: c.form, rest: rest ? rest.split(' ') : [] };
    }
  }
  return { unit: null, rest: words };
}

const FRACTIONS: Record<string, string> = { medio: '5', media: '5', cuarto: '25' };

export function parseSpoken(text: string, opts: SpokenOptions = {}): SpokenResult {
  const confusions = { ...DEFAULT_CONFUSIONS, ...(opts.confusions ?? {}) };
  const words = normalizeUtterance(text, confusions);
  if (!words.length) return { kind: 'unparsed', reason: 'empty' };

  const cmd = matchCommand(words, opts.commands ?? DEFAULT_COMMANDS);
  if (cmd) return { kind: 'command', command: cmd };

  const { unit, spoken, rest } = extractUnit(words, opts.unitForms ?? DEFAULT_UNIT_FORMS, opts.synonyms ?? {});
  let w = rest;
  if (!w.length) return { kind: 'unparsed', reason: 'no_number' };

  // Fracciones habladas.
  if (w.length === 1 && (w[0] === 'medio' || w[0] === 'media')) return { kind: 'number', value: '0.5', unit, spokenUnit: spoken };
  if (w.join(' ') === 'un cuarto') return { kind: 'number', value: '0.25', unit, spokenUnit: spoken };
  if (w.join(' ') === 'tres cuartos') return { kind: 'number', value: '0.75', unit, spokenUnit: spoken };
  const last = w[w.length - 1]!;
  if (w.length >= 3 && w[w.length - 2] === 'y' && last in FRACTIONS) {
    const n = parseCardinal(w.slice(0, -2));
    if (n !== null) return { kind: 'number', value: canonDecimal(String(n), FRACTIONS[last]!), unit, spokenUnit: spoken };
  }

  // Separador decimal: «coma», «con», «punto».
  const sepIdx = w.findIndex((x) => x === 'coma' || x === 'con' || x === 'punto');
  if (sepIdx >= 0) {
    const intWords = w.slice(0, sepIdx);
    const fracWords = w.slice(sepIdx + 1);
    let intVal: string;
    if (!intWords.length) intVal = '0';
    else if (allDigits(intWords)) intVal = intWords.map((x) => String(DIGIT[x])).join('');
    else {
      const n = parseCardinal(intWords);
      if (n === null) return { kind: 'unparsed', reason: 'no_number' };
      intVal = String(n);
    }
    const frac = parseDecimalWords(fracWords);
    if (frac === null || frac === '') return { kind: 'unparsed', reason: 'no_number' };
    return { kind: 'number', value: canonDecimal(intVal, frac), unit, spokenUnit: spoken };
  }

  if (!w.every(isNumberWord)) return { kind: 'unparsed', reason: 'no_number' };

  if (opts.digitByDigit && w.every((x) => x in DIGIT)) {
    return { kind: 'number', value: String(BigInt(w.map((x) => String(DIGIT[x])).join(''))), unit, spokenUnit: spoken };
  }
  if (allDigits(w)) {
    if (w.length === 2) {
      const a = DIGIT[w[0]!]!; const b = DIGIT[w[1]!]!;
      const asInt = String(a * 10 + b);
      const asDec = canonDecimal(String(a), String(b));
      const readInt = parseCardinal([w[0]!, w[1]!]);
      void readInt;
      return {
        kind: 'ambiguous',
        options: [asInt, asDec],
        question: `¿${capital(intWordsFor(asInt))} o ${intWordsFor(String(a))} coma ${intWordsFor(String(b))}?`,
        unit,
      };
    }
    return { kind: 'number', value: String(BigInt(w.map((x) => String(DIGIT[x])).join(''))), unit, spokenUnit: spoken };
  }
  const n = parseCardinal(w);
  if (n === null) return { kind: 'unparsed', reason: 'no_number' };
  return { kind: 'number', value: String(n), unit, spokenUnit: spoken };
}

const SIMPLE_WORDS = ['cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
const TEEN_WORDS: Record<number, string> = { 10: 'diez', 11: 'once', 12: 'doce', 13: 'trece', 14: 'catorce', 15: 'quince', 16: 'dieciséis', 17: 'diecisiete', 18: 'dieciocho', 19: 'diecinueve', 20: 'veinte', 21: 'veintiuno', 22: 'veintidós', 23: 'veintitrés', 24: 'veinticuatro', 25: 'veinticinco', 26: 'veintiséis', 27: 'veintisiete', 28: 'veintiocho', 29: 'veintinueve' };
const TENS_WORDS = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];

function intWordsFor(s: string): string {
  const n = Number(s);
  if (n < 10) return SIMPLE_WORDS[n]!;
  if (n < 30) return TEEN_WORDS[n]!;
  const t = Math.floor(n / 10); const u = n % 10;
  return TENS_WORDS[t]! + (u ? ' y ' + SIMPLE_WORDS[u] : '');
}

function capital(s: string): string { return s.charAt(0).toUpperCase() + s.slice(1); }

/** Pares de unidades que suenan parecido y obligan a preguntar. */
export const CONFUSABLE_UNITS: [string, string, string][] = [
  ['mg', 'µg', '¿Miligramos o microgramos?'],
  ['mg', 'ml', '¿Miligramos o mililitros?'],
  ['µg', 'ml', '¿Microgramos o mililitros?'],
];

export function unitQuestion(a: string, b: string): string | null {
  for (const [x, y, q] of CONFUSABLE_UNITS) if ((x === a && y === b) || (x === b && y === a)) return q;
  return null;
}
