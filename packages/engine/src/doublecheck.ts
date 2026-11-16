/**
 * Motor B: segunda implementación independiente para el doble cálculo (diseño D3).
 *
 * No comparte código de cálculo con el motor A (expr.ts):
 *  - Tokenizador y analizador propios (algoritmo shunting-yard a notación polaca inversa).
 *  - Aritmética racional exacta con BigInt (fracciones), no decimal.js.
 *  - Resolución propia de factores de unidad a partir de los datos del catálogo.
 *
 * Solo comparte datos: la tabla de unidades atómicas.
 */
import { ATOMIC_UNITS } from './units.js';

export class Rational {
  readonly n: bigint;
  readonly d: bigint;
  constructor(n: bigint, d: bigint = 1n) {
    if (d === 0n) throw new Error('División entre cero');
    if (d < 0n) { n = -n; d = -d; }
    const g = gcd(n < 0n ? -n : n, d);
    this.n = n / g;
    this.d = d / g;
  }
  static parse(s: string): Rational {
    const t = s.trim().replace(',', '.');
    const neg = t.startsWith('-');
    const body = neg ? t.slice(1) : t;
    const [i, f = ''] = body.split('.');
    const n = BigInt((i || '0') + f) * (neg ? -1n : 1n);
    return new Rational(n, 10n ** BigInt(f.length));
  }
  add(o: Rational) { return new Rational(this.n * o.d + o.n * this.d, this.d * o.d); }
  sub(o: Rational) { return new Rational(this.n * o.d - o.n * this.d, this.d * o.d); }
  mul(o: Rational) { return new Rational(this.n * o.n, this.d * o.d); }
  div(o: Rational) { return new Rational(this.n * o.d, this.d * o.n); }
  neg() { return new Rational(-this.n, this.d); }
  cmp(o: Rational) { const x = this.n * o.d - o.n * this.d; return x < 0n ? -1 : x > 0n ? 1 : 0; }
  pow(e: number): Rational {
    let r = new Rational(1n);
    const base: Rational = e < 0 ? new Rational(this.d, this.n) : this;
    for (let i = 0; i < Math.abs(e); i++) r = r.mul(base);
    return r;
  }
  /** Redondeo aritmético (el 5 sube) a `places` decimales. */
  roundPlaces(places: number): Rational {
    const scale = 10n ** BigInt(places);
    const scaled = this.mul(new Rational(scale));
    const neg = scaled.n < 0n;
    const absN = neg ? -scaled.n : scaled.n;
    const q = absN / scaled.d;
    const rem = absN % scaled.d;
    const up = rem * 2n >= scaled.d ? 1n : 0n;
    return new Rational((q + up) * (neg ? -1n : 1n), scale);
  }
  roundStep(step: Rational): Rational {
    const k = this.div(step).roundPlaces(0);
    return k.mul(step);
  }
  /** Decimal exacto si el denominador solo tiene factores 2 y 5; si no, 40 decimales. */
  toDecimalString(maxPlaces = 40): string {
    const neg = this.n < 0n;
    const absN = neg ? -this.n : this.n;
    const intPart = absN / this.d;
    let rem = absN % this.d;
    let frac = '';
    for (let i = 0; i < maxPlaces && rem !== 0n; i++) {
      rem *= 10n;
      frac += String(rem / this.d);
      rem %= this.d;
    }
    frac = frac.replace(/0+$/, '');
    const s = intPart.toString() + (frac ? '.' + frac : '');
    return (neg && s !== '0' ? '-' : '') + s;
  }
}

function gcd(a: bigint, b: bigint): bigint {
  while (b) [a, b] = [b, a % b];
  return a === 0n ? 1n : a;
}

// ---------------------------------------------------------------------------
// Unidades del motor B: resolución propia de factores y dimensiones.
// ---------------------------------------------------------------------------

type DimKey = string;
interface BUnit { dims: Map<DimKey, number>; factor: Rational }

const B_TABLE = new Map<string, { dims: Record<string, number>; factor: string }>();
for (const u of ATOMIC_UNITS) {
  B_TABLE.set(u.symbol, { dims: u.dims as Record<string, number>, factor: u.factor });
  for (const a of u.aliases) B_TABLE.set(a, { dims: u.dims as Record<string, number>, factor: u.factor });
}

function bUnit(text: string): BUnit {
  const dims = new Map<DimKey, number>();
  let factor = new Rational(1n);
  const t = text.trim();
  if (!t || t === '1') return { dims, factor };
  const segments = t.split('/');
  for (let s = 0; s < segments.length; s++) {
    const sign = s === 0 ? 1 : -1;
    for (const piece of segments[s]!.split(/[·*×]/)) {
      const p = piece.trim();
      if (!p) continue;
      const [sym, expTxt] = p.split('^');
      const entry = B_TABLE.get(sym!);
      if (!entry) throw new Error(`Motor B: unidad desconocida ${sym}`);
      const e = (expTxt ? Number(expTxt) : 1) * sign;
      for (const [k, v] of Object.entries(entry.dims)) dims.set(k, (dims.get(k) ?? 0) + v * e);
      factor = factor.mul(Rational.parse(entry.factor).pow(e));
    }
  }
  for (const [k, v] of [...dims]) if (v === 0) dims.delete(k);
  return { dims, factor };
}

function dimsEqual(a: Map<DimKey, number>, b: Map<DimKey, number>): boolean {
  const keys = new Set([...a.keys(), ...b.keys()]);
  for (const k of keys) if ((a.get(k) ?? 0) !== (b.get(k) ?? 0)) return false;
  return true;
}

function dimsCombine(a: Map<DimKey, number>, b: Map<DimKey, number>, sign: number): Map<DimKey, number> {
  const r = new Map(a);
  for (const [k, v] of b) r.set(k, (r.get(k) ?? 0) + sign * v);
  for (const [k, v] of [...r]) if (v === 0) r.delete(k);
  return r;
}

/** Valor del motor B: siempre en unidades base. */
interface BVal { base: Rational; dims: Map<DimKey, number>; unitFactor: Rational }

// ---------------------------------------------------------------------------
// Analizador shunting-yard
// ---------------------------------------------------------------------------

type RToken =
  | { kind: 'n'; value: string; unit: string }
  | { kind: 'v'; name: string }
  | { kind: 'op'; op: string }
  | { kind: 'fn'; name: string; argc: number }
  | { kind: 'lp' } | { kind: 'rp' } | { kind: 'sep' };

const PREC: Record<string, number> = { cmp: 1, '+': 2, '-': 2, '*': 3, '/': 3, neg: 4 };
const FN_NAMES: Record<string, string> = { redondear: 'round', minimo: 'min', 'mínimo': 'min', min: 'min', maximo: 'max', 'máximo': 'max', max: 'max', si: 'if' };

function lex(src: string): RToken[] {
  const re = /\s*(?:(\d+(?:[.,]\d+)?)(\[[^\]]*\])?|([\p{L}_][\p{L}\p{N}_.]*)|(<=|>=|==|!=|[<>+\-*/×·÷−():;,]))/uy;
  const out: RToken[] = [];
  let m: RegExpExecArray | null;
  re.lastIndex = 0;
  let prev: RToken | undefined;
  while (re.lastIndex < src.length && (m = re.exec(src))) {
    if (m[1] !== undefined) {
      out.push({ kind: 'n', value: m[1].replace(',', '.'), unit: m[2] ? m[2].slice(1, -1) : '' });
    } else if (m[3] !== undefined) {
      const fn = FN_NAMES[m[3].toLowerCase()];
      const nextChar = src.slice(re.lastIndex).trimStart()[0];
      if (fn && nextChar === '(') out.push({ kind: 'fn', name: fn, argc: 1 });
      else out.push({ kind: 'v', name: m[3] });
    } else if (m[4] !== undefined) {
      const o = m[4];
      if (o === '(') out.push({ kind: 'lp' });
      else if (o === ')') out.push({ kind: 'rp' });
      else if (o === ';' || o === ',') out.push({ kind: 'sep' });
      else {
        const norm = ({ '×': '*', '·': '*', '÷': '/', ':': '/', '−': '-' } as Record<string, string>)[o] ?? o;
        const unaryContext = !prev || prev.kind === 'op' || prev.kind === 'lp' || prev.kind === 'sep' || prev.kind === 'fn';
        if (norm === '-' && unaryContext) out.push({ kind: 'op', op: 'neg' });
        else out.push({ kind: 'op', op: ['<', '>', '<=', '>=', '==', '!='].includes(norm) ? `cmp:${norm}` : norm });
      }
    }
    prev = out[out.length - 1];
  }
  if (re.lastIndex < src.trim().length && src.slice(re.lastIndex).trim()) throw new Error('Motor B: no se pudo leer la fórmula');
  return out;
}

function precOf(op: string): number { return op.startsWith('cmp:') ? PREC.cmp! : PREC[op]!; }

function toRpn(tokens: RToken[]): RToken[] {
  const out: RToken[] = [];
  const stack: RToken[] = [];
  const argCounts: number[] = [];
  for (const t of tokens) {
    if (t.kind === 'n' || t.kind === 'v') out.push(t);
    else if (t.kind === 'fn') { stack.push(t); argCounts.push(1); }
    else if (t.kind === 'sep') {
      while (stack.length && stack[stack.length - 1]!.kind !== 'lp') out.push(stack.pop()!);
      argCounts[argCounts.length - 1]!++;
    } else if (t.kind === 'op') {
      while (stack.length) {
        const top = stack[stack.length - 1]!;
        if (top.kind !== 'op') break;
        const right = t.op === 'neg';
        if (right ? precOf(top.op) > precOf(t.op) : precOf(top.op) >= precOf(t.op)) out.push(stack.pop()!);
        else break;
      }
      stack.push(t);
    } else if (t.kind === 'lp') stack.push(t);
    else if (t.kind === 'rp') {
      while (stack.length && stack[stack.length - 1]!.kind !== 'lp') out.push(stack.pop()!);
      stack.pop();
      const top = stack[stack.length - 1];
      if (top && top.kind === 'fn') {
        stack.pop();
        out.push({ ...top, argc: argCounts.pop()! });
      }
    }
  }
  while (stack.length) out.push(stack.pop()!);
  return out;
}

function bValue(value: string, unit: string): BVal {
  const u = bUnit(unit);
  return { base: Rational.parse(value).mul(u.factor), dims: u.dims, unitFactor: u.factor };
}

export type BScope = Record<string, { value: string; unit: string }>;

export function evaluateB(formula: string, scope: BScope): BVal {
  const rpn = toRpn(lex(formula));
  const st: BVal[] = [];
  for (const t of rpn) {
    if (t.kind === 'n') st.push(bValue(t.value, t.unit));
    else if (t.kind === 'v') {
      const s = scope[t.name];
      if (!s) throw new Error(`Motor B: variable desconocida ${t.name}`);
      st.push(bValue(s.value, s.unit));
    } else if (t.kind === 'op') {
      if (t.op === 'neg') { const a = st.pop()!; st.push({ ...a, base: a.base.neg() }); continue; }
      const b = st.pop()!; const a = st.pop()!;
      if (t.op === '*') st.push({ base: a.base.mul(b.base), dims: dimsCombine(a.dims, b.dims, 1), unitFactor: a.unitFactor.mul(b.unitFactor) });
      else if (t.op === '/') st.push({ base: a.base.div(b.base), dims: dimsCombine(a.dims, b.dims, -1), unitFactor: a.unitFactor.div(b.unitFactor) });
      else if (t.op === '+' || t.op === '-') {
        if (!dimsEqual(a.dims, b.dims)) throw new Error('Motor B: suma de magnitudes distintas');
        st.push({ ...a, base: t.op === '+' ? a.base.add(b.base) : a.base.sub(b.base) });
      } else if (t.op.startsWith('cmp:')) {
        const c = a.base.cmp(b.base);
        const op = t.op.slice(4);
        const r = op === '<' ? c < 0 : op === '>' ? c > 0 : op === '<=' ? c <= 0 : op === '>=' ? c >= 0 : op === '==' ? c === 0 : c !== 0;
        st.push({ base: new Rational(r ? 1n : 0n), dims: new Map(), unitFactor: new Rational(1n) });
      }
    } else if (t.kind === 'fn') {
      const args = st.splice(st.length - t.argc, t.argc);
      if (t.name === 'if') st.push(args[0]!.base.n !== 0n ? args[1]! : args[2]!);
      else if (t.name === 'min' || t.name === 'max') {
        let best = args[0]!;
        for (const a of args.slice(1)) {
          const c = a.base.cmp(best.base);
          if ((t.name === 'min' && c < 0) || (t.name === 'max' && c > 0)) best = a;
        }
        st.push(best);
      } else if (t.name === 'round') {
        const [x, n] = args as [BVal, BVal];
        // redondear trabaja en la unidad compuesta del operando, como el motor A.
        const inUnit = x.base.div(x.unitFactor).roundPlaces(Number(n.base.toDecimalString()));
        st.push({ ...x, base: inUnit.mul(x.unitFactor) });
      }
    }
  }
  if (st.length !== 1) throw new Error('Motor B: fórmula mal formada');
  return st[0]!;
}

/** Evalúa y expresa el resultado, sin redondear, en la unidad pedida. */
export function evalInB(formula: string, scope: BScope, unit: string): Rational {
  const r = evaluateB(formula, scope);
  const target = bUnit(unit);
  if (!dimsEqual(r.dims, target.dims)) throw new Error(`Motor B: el resultado no está en ${unit}`);
  return r.base.div(target.factor);
}
