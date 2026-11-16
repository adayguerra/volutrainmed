/**
 * Normalizador de lectura: de cifra escrita a texto hablado en español de España.
 *
 * Es el mismo en la app (voz y lector de pantalla) y en la vista previa del
 * back office (diseño D8). La app Dart tiene una implementación espejo que pasa
 * los mismos casos de `contracts/fixtures/tts.json`.
 *
 *   0,25 mg      → «cero coma veinticinco miligramos»
 *   0,05 mg      → «cero coma cero cinco miligramos»
 *   1 mg, 1 UI   → «un miligramo», «una unidad»
 *   21 mg        → «veintiún miligramos»
 *   2 %          → «dos por ciento»
 *   1:10 000     → «uno en diez mil»
 *   250 mg/5 ml  → «doscientos cincuenta miligramos en cinco mililitros»
 *   µg/kg/min    → «microgramos por kilo y minuto»
 */

type Gender = 'm' | 'f';

const UNITS_0_29 = [
  'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve',
  'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
  'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete', 'veintiocho', 'veintinueve',
];
const TENS = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];
const HUNDREDS_M = ['', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'];
const HUNDREDS_F = ['', 'ciento', 'doscientas', 'trescientas', 'cuatrocientas', 'quinientas', 'seiscientas', 'setecientas', 'ochocientas', 'novecientas'];

/** «uno» final según lo que sigue: apocopado (un/veintiún) o femenino (una/veintiuna). */
function fixOne(words: string, mode: 'plain' | 'apocope' | 'fem'): string {
  if (mode === 'plain') return words;
  if (mode === 'apocope') return words.replace(/veintiuno$/, 'veintiún').replace(/(^|\s)uno$/, '$1un');
  return words.replace(/veintiuno$/, 'veintiuna').replace(/(^|\s)uno$/, '$1una');
}

function below1000(n: number, g: Gender): string {
  if (n === 100) return 'cien';
  const h = Math.floor(n / 100);
  const r = n % 100;
  const parts: string[] = [];
  if (h) parts.push((g === 'f' ? HUNDREDS_F : HUNDREDS_M)[h]!);
  if (r) {
    if (r < 30) parts.push(UNITS_0_29[r]!);
    else {
      const t = Math.floor(r / 10);
      const u = r % 10;
      parts.push(TENS[t]! + (u ? ' y ' + UNITS_0_29[u] : ''));
    }
  }
  return parts.join(' ');
}

/**
 * Cardinal en palabras. `oneMode` decide cómo termina «uno»:
 * «plain» (uno), «apocope» (un, delante de sustantivo masculino), «fem» (una).
 */
export function intToWords(n: bigint | number, g: Gender = 'm', oneMode: 'plain' | 'apocope' | 'fem' = 'plain'): string {
  let v = typeof n === 'bigint' ? n : BigInt(Math.trunc(n));
  if (v === 0n) return 'cero';
  const neg = v < 0n;
  if (neg) v = -v;
  const millions = Number(v / 1000000n);
  const thousands = Number((v / 1000n) % 1000n);
  const rest = Number(v % 1000n);
  const parts: string[] = [];
  if (millions) parts.push(millions === 1 ? 'un millón' : fixOne(intToWords(millions, 'm'), 'apocope') + ' millones');
  if (thousands) parts.push(thousands === 1 ? 'mil' : fixOne(below1000(thousands, g), g === 'f' ? 'fem' : 'apocope') + ' mil');
  if (rest) parts.push(fixOne(below1000(rest, g), oneMode));
  const s = parts.join(' ');
  return (neg ? 'menos ' : '') + s;
}

/** Parte decimal: ceros iniciales cifra a cifra y el resto como cardinal (hasta 3 cifras). */
function fracToWords(frac: string): string {
  const lead = frac.match(/^0*/)![0];
  const rest = frac.slice(lead.length);
  const words: string[] = lead.split('').map(() => 'cero');
  if (rest) {
    if (rest.length <= 3) words.push(intToWords(BigInt(rest)));
    else words.push(...rest.split('').map((d) => UNITS_0_29[Number(d)]!));
  }
  return words.join(' ');
}

export interface UnitReading { singular: string; plural: string; gender: Gender }

/** Lecturas de las unidades atómicas. Editables desde el catálogo del back office. */
export const UNIT_READINGS: Record<string, UnitReading> = {
  g: { singular: 'gramo', plural: 'gramos', gender: 'm' },
  mg: { singular: 'miligramo', plural: 'miligramos', gender: 'm' },
  'µg': { singular: 'microgramo', plural: 'microgramos', gender: 'm' },
  mcg: { singular: 'microgramo', plural: 'microgramos', gender: 'm' },
  ng: { singular: 'nanogramo', plural: 'nanogramos', gender: 'm' },
  kg: { singular: 'kilo', plural: 'kilos', gender: 'm' },
  ml: { singular: 'mililitro', plural: 'mililitros', gender: 'm' },
  l: { singular: 'litro', plural: 'litros', gender: 'm' },
  'µl': { singular: 'microlitro', plural: 'microlitros', gender: 'm' },
  s: { singular: 'segundo', plural: 'segundos', gender: 'm' },
  min: { singular: 'minuto', plural: 'minutos', gender: 'm' },
  h: { singular: 'hora', plural: 'horas', gender: 'f' },
  'día': { singular: 'día', plural: 'días', gender: 'm' },
  gotas: { singular: 'gota', plural: 'gotas', gender: 'f' },
  UI: { singular: 'unidad', plural: 'unidades internacionales', gender: 'f' },
  tomas: { singular: 'toma', plural: 'tomas', gender: 'f' },
  '%': { singular: 'por ciento', plural: 'por ciento', gender: 'm' },
};

/** Lectura de una unidad compuesta. «µg/kg/min» → «microgramos por kilo y minuto». */
export function readUnit(unit: string, plural = true): { text: string; gender: Gender } {
  const parts = unit.split('/').map((p) => p.trim()).filter(Boolean);
  if (!parts.length) return { text: '', gender: 'm' };
  const head = UNIT_READINGS[parts[0]!];
  const headText = head ? (plural ? head.plural : head.singular) : parts[0]!;
  const dens = parts.slice(1).map((p) => UNIT_READINGS[p]?.singular ?? p);
  let text = headText;
  if (dens.length === 1) text += ' por ' + dens[0];
  else if (dens.length > 1) text += ' por ' + dens.slice(0, -1).join(', ') + ' y ' + dens[dens.length - 1];
  return { text, gender: head?.gender ?? 'm' };
}

/** Cifra canónica («0.25», «1500») a palabras, concordando con la unidad. */
export function numberToWords(value: string, gender: Gender = 'm', beforeNoun = false): string {
  const neg = value.startsWith('-');
  const v = neg ? value.slice(1) : value;
  const [int, frac] = v.split('.') as [string, string | undefined];
  const oneMode = frac ? 'plain' : beforeNoun ? (gender === 'f' ? 'fem' : 'apocope') : 'plain';
  let words = intToWords(BigInt(int || '0'), beforeNoun ? gender : 'm', oneMode);
  if (frac) words += ' coma ' + fracToWords(frac);
  return (neg ? 'menos ' : '') + words;
}

/** Cantidad con unidad. «0.2», «mg/kg» → «cero coma dos miligramos por kilo». */
export function readQuantity(value: string, unit: string): string {
  if (!unit) return numberToWords(value);
  if (unit === '%') return numberToWords(value) + ' por ciento';
  const isOne = value === '1';
  const u = readUnit(unit, !isOne);
  return numberToWords(value, u.gender, true) + ' ' + u.text;
}

const NUM_RE = String.raw`\d{1,3}(?:[  ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?`;
const UNIT_TOKEN = String.raw`(?:µg|mcg|mg|ng|kg|g|ml|µl|l|UI|gotas|gota|min|h|s|día|días|tomas|toma|%)`;
const UNIT_RE = String.raw`${UNIT_TOKEN}(?:\/${UNIT_TOKEN})*`;

function toCanon(num: string): string {
  return num.replace(/[  ]/g, '').replace(',', '.');
}

/**
 * Normaliza un texto completo para la voz: sustituye razones, presentaciones
 * «250 mg/5 ml» y cantidades con unidad por su lectura.
 */
export function speakText(text: string): string {
  let out = text;
  // Razones 1:10 000 → «uno en diez mil».
  out = out.replace(new RegExp(String.raw`\b(${NUM_RE}):(${NUM_RE})\b`, 'g'), (_m, a: string, b: string) => `${numberToWords(toCanon(a))} en ${numberToWords(toCanon(b))}`);
  // Presentación «250 mg/5 ml» → «doscientos cincuenta miligramos en cinco mililitros».
  out = out.replace(new RegExp(String.raw`(${NUM_RE})\s?(${UNIT_TOKEN})\/(${NUM_RE})\s?(${UNIT_TOKEN})(?![\p{L}\/])`, 'gu'), (_m, a: string, ua: string, b: string, ub: string) => `${readQuantity(toCanon(a), ua)} en ${readQuantity(toCanon(b), ub)}`);
  // Cantidad con unidad (compuesta o no).
  out = out.replace(new RegExp(String.raw`(${NUM_RE})\s?(${UNIT_RE})(?![\p{L}])`, 'gu'), (_m, n: string, u: string) => readQuantity(toCanon(n), u));
  // Números sueltos.
  out = out.replace(new RegExp(String.raw`(?<![\p{L}\d])(${NUM_RE})(?![\d])`, 'gu'), (_m, n: string) => numberToWords(toCanon(n)));
  return out.replace(/\s+/g, ' ').trim();
}

/** Lectura para la confirmación hablada: «Cuatro coma ocho mililitros por hora». */
export function confirmationText(value: string, unit: string): string {
  const s = readQuantity(value, unit);
  return s.charAt(0).toUpperCase() + s.slice(1);
}

const CONFUSABLE = /\b(sesenta|setenta|dos|doce|tres|trece|seis|dieciséis|siete|diecisiete|cuatro|catorce|cinco|quince)\b/;

/** Si la cifra contiene palabras que se confunden, se deletrea: «Sesenta: seis, cero». */
export function spellingFor(value: string): string | null {
  const words = numberToWords(value);
  if (!CONFUSABLE.test(words)) return null;
  const [int] = value.split('.');
  if (!int || int.length < 2) return null;
  const digits = value.replace('-', '').split('').map((c) => (c === '.' ? 'coma' : UNITS_0_29[Number(c)]!));
  return digits.join(', ');
}
