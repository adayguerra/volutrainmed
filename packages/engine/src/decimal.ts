/**
 * Aritmética decimal exacta y formato de cifras en español de España.
 *
 * - Nunca se usa coma flotante binaria: 0,1 + 0,2 = 0,3.
 * - Redondeo aritmético: el 5 sube (ROUND_HALF_UP).
 * - Formato: coma decimal, cero inicial obligatorio, ningún cero final y
 *   espacio fino a partir de cinco cifras enteras (12 500).
 */
import Decimal from 'decimal.js';

export const D = Decimal.clone({ precision: 60, rounding: Decimal.ROUND_HALF_UP, toExpNeg: -30, toExpPos: 40 });
export type Dec = InstanceType<typeof D>;

export function dec(v: string | number | Dec): Dec {
  if (typeof v === 'number') return new D(String(v));
  return new D(v);
}

/** Cadena canónica con punto, sin ceros finales y con cero inicial. */
export function canon(v: Dec | string | number): string {
  const d = dec(v as never);
  if (d.isZero()) return '0';
  let s = d.toFixed();
  if (s.includes('.')) s = s.replace(/0+$/, '').replace(/\.$/, '');
  return s;
}

export function roundPlaces(v: Dec, places: number): Dec {
  return v.toDecimalPlaces(places, D.ROUND_HALF_UP);
}

/** Redondea al múltiplo más cercano de step (redondeo aritmético). */
export function roundStep(v: Dec, step: Dec): Dec {
  if (step.isZero()) return v;
  return v.div(step).toDecimalPlaces(0, D.ROUND_HALF_UP).mul(step);
}

export function decimalsOf(s: string): number {
  const i = s.indexOf('.');
  return i < 0 ? 0 : s.length - i - 1;
}

const THIN = ' ';

/** Presentación en pantalla: «0,96», «12 500», «1500». */
export function formatEs(v: Dec | string | number): string {
  const s = canon(v as never);
  const neg = s.startsWith('-');
  const abs = neg ? s.slice(1) : s;
  const [int, frac] = abs.split('.') as [string, string | undefined];
  let intOut = int;
  if (int.length >= 5) intOut = int.replace(/\B(?=(\d{3})+(?!\d))/g, THIN);
  return (neg ? '-' : '') + intOut + (frac ? ',' + frac : '');
}

export interface ParsedUserNumber {
  ok: boolean;
  /** Valor canónico con punto. */
  value?: string;
  /** Lo que el usuario escribió, normalizado a coma, para mostrar. */
  normalizedDisplay?: string;
  /** Formato inseguro corregido: «,5» → «0,5»; «5,0» → «5». */
  unsafeFormat?: 'missing_leading_zero' | 'trailing_zero' | null;
  error?: 'empty' | 'invalid' | 'two_separators';
}

/**
 * Interpreta una cifra tecleada: acepta coma o punto (el punto se convierte),
 * detecta el formato inseguro y nunca acepta separador de miles.
 */
export function parseUserNumber(raw: string): ParsedUserNumber {
  const s = raw.trim().replace(/\s| /g, '');
  if (!s) return { ok: false, error: 'empty' };
  const norm = s.replace('.', ',');
  if ((norm.match(/,/g) ?? []).length > 1 || (s.match(/[.,]/g) ?? []).length > 1) {
    return { ok: false, error: 'two_separators' };
  }
  if (!/^-?(\d+)?(,\d*)?$/.test(norm) || norm === ',' || norm === '-') return { ok: false, error: 'invalid' };
  let unsafe: ParsedUserNumber['unsafeFormat'] = null;
  if (/^-?,/.test(norm)) unsafe = 'missing_leading_zero';
  const [, frac] = norm.split(',');
  if (frac !== undefined && frac.length > 0 && /0$/.test(frac)) unsafe = unsafe ?? 'trailing_zero';
  if (frac !== undefined && frac.length === 0) unsafe = unsafe ?? 'trailing_zero';
  const dotted = norm.replace(',', '.').replace(/^(-?)\./, '$10.').replace(/\.$/, '');
  const value = canon(dotted);
  return { ok: true, value, normalizedDisplay: formatEs(value), unsafeFormat: unsafe };
}
