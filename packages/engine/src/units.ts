/**
 * Unidades de medida y análisis dimensional.
 *
 * Magnitudes base: masa (g), volumen (ml), tiempo (s), gotas, unidades
 * internacionales (UI) y recuento (tomas, dosis). Una unidad compuesta como
 * «µg/kg/min» se interpreta como µg · kg⁻¹ · min⁻¹.
 */
import { D, type Dec, dec } from './decimal.js';

export type Dim = 'M' | 'V' | 'T' | 'G' | 'IU' | 'N';
export const DIMS: Dim[] = ['M', 'V', 'T', 'G', 'IU', 'N'];
export type DimVec = Record<Dim, number>;

export interface AtomicUnit {
  symbol: string;
  aliases: string[];
  dims: Partial<DimVec>;
  /** Factor a la unidad base de su magnitud. */
  factor: string;
}

export const ATOMIC_UNITS: AtomicUnit[] = [
  { symbol: 'g', aliases: ['gr', 'gramo', 'gramos'], dims: { M: 1 }, factor: '1' },
  { symbol: 'mg', aliases: ['miligramo', 'miligramos'], dims: { M: 1 }, factor: '0.001' },
  { symbol: 'µg', aliases: ['mcg', 'ug', 'μg', 'microgramo', 'microgramos', 'gamma', 'gammas'], dims: { M: 1 }, factor: '0.000001' },
  { symbol: 'ng', aliases: [], dims: { M: 1 }, factor: '0.000000001' },
  { symbol: 'kg', aliases: ['kilo', 'kilos'], dims: { M: 1 }, factor: '1000' },
  { symbol: 'ml', aliases: ['mL', 'cc', 'cm3', 'mililitro', 'mililitros'], dims: { V: 1 }, factor: '1' },
  { symbol: 'l', aliases: ['L', 'litro', 'litros'], dims: { V: 1 }, factor: '1000' },
  { symbol: 'µl', aliases: ['ul', 'μl', 'microlitro', 'microlitros'], dims: { V: 1 }, factor: '0.001' },
  { symbol: 's', aliases: ['seg', 'segundo', 'segundos'], dims: { T: 1 }, factor: '1' },
  { symbol: 'min', aliases: ['minuto', 'minutos'], dims: { T: 1 }, factor: '60' },
  { symbol: 'h', aliases: ['hora', 'horas'], dims: { T: 1 }, factor: '3600' },
  { symbol: 'día', aliases: ['dia', 'días', 'dias', 'd'], dims: { T: 1 }, factor: '86400' },
  { symbol: 'gotas', aliases: ['gota', 'gt', 'gtt'], dims: { G: 1 }, factor: '1' },
  { symbol: 'UI', aliases: ['U', 'unidades', 'unidad'], dims: { IU: 1 }, factor: '1' },
  { symbol: 'tomas', aliases: ['toma', 'dosis'], dims: { N: 1 }, factor: '1' },
  // Porcentaje masa/volumen: 1 % = 1 g en 100 ml = 0,01 g/ml.
  { symbol: '%', aliases: ['por ciento'], dims: { M: 1, V: -1 }, factor: '0.01' },
];

const BY_SYMBOL = new Map<string, AtomicUnit>();
for (const u of ATOMIC_UNITS) {
  BY_SYMBOL.set(u.symbol, u);
  for (const a of u.aliases) BY_SYMBOL.set(a, u);
}

export function emptyDims(): DimVec {
  return { M: 0, V: 0, T: 0, G: 0, IU: 0, N: 0 };
}

export interface UnitExpr {
  /** Texto original normalizado («µg/kg/min»). */
  text: string;
  dims: DimVec;
  /** Factor a unidades base. */
  factor: Dec;
}

export class UnitError extends Error {}

/** Interpreta «µg/kg/min», «mg/ml», «gotas/min», «ml/h», «UI/kg», «min/h», «1». */
export function parseUnit(text: string): UnitExpr {
  const t = text.trim();
  if (t === '' || t === '1') return { text: '', dims: emptyDims(), factor: dec(1) };
  const dims = emptyDims();
  let factor = dec(1);
  // Separadores: «/» divide todo lo que sigue a su derecha inmediata; «·», «*», «×» multiplican.
  const parts = t.split('/');
  parts.forEach((part, idx) => {
    const sign = idx === 0 ? 1 : -1;
    for (const raw of part.split(/[·*×]/)) {
      const sym = raw.trim();
      if (!sym) continue;
      const m = sym.match(/^(.+?)(\^(-?\d+))?$/);
      const base = m?.[1] ?? sym;
      const exp = m?.[3] ? Number(m[3]) : 1;
      const u = BY_SYMBOL.get(base);
      if (!u) throw new UnitError(`Unidad desconocida: «${base}»`);
      for (const [k, v] of Object.entries(u.dims) as [Dim, number][]) dims[k] += v * exp * sign;
      factor = factor.mul(dec(u.factor).pow(exp * sign));
    }
  });
  return { text: t, dims, factor };
}

export function sameDims(a: DimVec, b: DimVec): boolean {
  return DIMS.every((k) => a[k] === b[k]);
}

export function mulDims(a: DimVec, b: DimVec, sign = 1): DimVec {
  const r = emptyDims();
  for (const k of DIMS) r[k] = a[k] + sign * b[k];
  return r;
}

export function isDimensionless(a: DimVec): boolean {
  return DIMS.every((k) => a[k] === 0);
}

const DIM_SYMBOL: Record<Dim, string> = { M: 'mg', V: 'ml', T: 'min', G: 'gotas', IU: 'UI', N: 'tomas' };

/** Describe una dimensión de forma legible: M·V⁻¹ → «mg/ml». */
export function describeDims(d: DimVec): string {
  const num: string[] = [];
  const den: string[] = [];
  for (const k of DIMS) {
    const e = d[k];
    if (e === 0) continue;
    const s = DIM_SYMBOL[k] + (Math.abs(e) > 1 ? `^${Math.abs(e)}` : '');
    (e > 0 ? num : den).push(s);
  }
  if (!num.length && !den.length) return 'sin unidad';
  return (num.length ? num.join('·') : '1') + (den.length ? '/' + den.join('/') : '');
}

/** Convierte un valor de una unidad a otra de la misma magnitud. */
export function convert(value: Dec, from: string, to: string): Dec {
  const a = parseUnit(from);
  const b = parseUnit(to);
  if (!sameDims(a.dims, b.dims)) throw new UnitError(`No se puede convertir ${from} en ${to}`);
  return value.mul(a.factor).div(b.factor);
}

export function unitsEquivalent(a: string, b: string): boolean {
  try {
    const x = parseUnit(a);
    const y = parseUnit(b);
    return sameDims(x.dims, y.dims) && x.factor.eq(y.factor);
  } catch {
    return a === b;
  }
}

export { D };
