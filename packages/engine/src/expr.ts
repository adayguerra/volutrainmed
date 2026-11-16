/**
 * Motor de fórmulas principal (motor A).
 *
 * Fórmulas en lenguaje llano, sin código:
 *   dosis × peso ÷ concentración
 *   mínimo(dosis × peso; maximo_dosis) ÷ concentración
 *   dosis × peso × 60[min/h] ÷ concentración
 *   si(peso > 40; 40; peso)
 *   redondear(volumen; 2)
 *
 * Cada operando lleva su unidad. El evaluador calcula a la vez la cifra
 * (aritmética decimal exacta) y la unidad resultante, de modo que una fórmula
 * cuya unidad no coincide con la de la respuesta se detecta antes de guardarla.
 */
import { type Dec, dec, D, roundPlaces } from './decimal.js';
import { type DimVec, emptyDims, mulDims, parseUnit, sameDims, describeDims, isDimensionless, UnitError } from './units.js';

export type Node =
  | { k: 'num'; v: string; unit: string }
  | { k: 'var'; name: string }
  | { k: 'neg'; a: Node }
  | { k: 'bin'; op: '+' | '-' | '*' | '/'; a: Node; b: Node }
  | { k: 'cmp'; op: '<' | '>' | '<=' | '>=' | '==' | '!='; a: Node; b: Node }
  | { k: 'call'; fn: 'redondear' | 'min' | 'max' | 'si'; args: Node[] };

export class FormulaError extends Error {
  constructor(message: string, public pos?: number) {
    super(message);
  }
}

type Tok = { t: 'num'; v: string; p: number } | { t: 'id'; v: string; p: number } | { t: 'op'; v: string; p: number } | { t: 'unit'; v: string; p: number };

const FN_ALIASES: Record<string, 'redondear' | 'min' | 'max' | 'si'> = {
  redondear: 'redondear', round: 'redondear',
  minimo: 'min', 'mínimo': 'min', min: 'min',
  maximo: 'max', 'máximo': 'max', max: 'max',
  si: 'si', if: 'si',
};

function tokenize(src: string): Tok[] {
  const out: Tok[] = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i]!;
    if (/\s/.test(c)) { i++; continue; }
    if (/[0-9]/.test(c)) {
      let j = i;
      while (j < src.length && /[0-9]/.test(src[j]!)) j++;
      if ((src[j] === '.' || src[j] === ',') && /[0-9]/.test(src[j + 1] ?? '')) {
        j++;
        while (j < src.length && /[0-9]/.test(src[j]!)) j++;
      }
      out.push({ t: 'num', v: src.slice(i, j).replace(',', '.'), p: i });
      i = j;
      continue;
    }
    if (c === '[') {
      const j = src.indexOf(']', i);
      if (j < 0) throw new FormulaError('Falta cerrar el corchete de la unidad', i);
      out.push({ t: 'unit', v: src.slice(i + 1, j), p: i });
      i = j + 1;
      continue;
    }
    if (/[\p{L}_]/u.test(c)) {
      let j = i;
      while (j < src.length && /[\p{L}\p{N}_.]/u.test(src[j]!)) j++;
      out.push({ t: 'id', v: src.slice(i, j), p: i });
      i = j;
      continue;
    }
    const two = src.slice(i, i + 2);
    if (['<=', '>=', '==', '!='].includes(two)) { out.push({ t: 'op', v: two, p: i }); i += 2; continue; }
    const map: Record<string, string> = { '×': '*', '·': '*', '÷': '/', ':': '/', '−': '-' };
    if ('+-*/()<>;,×·÷−'.includes(c)) {
      out.push({ t: 'op', v: map[c] ?? c, p: i });
      i++;
      continue;
    }
    throw new FormulaError(`Carácter no válido «${c}»`, i);
  }
  return out;
}

export function parseFormula(src: string): Node {
  const toks = tokenize(src);
  let pos = 0;
  const peek = () => toks[pos];
  const eat = (v?: string): Tok => {
    const t = toks[pos];
    if (!t) throw new FormulaError('La fórmula termina antes de tiempo');
    if (v !== undefined && t.v !== v) throw new FormulaError(`Se esperaba «${v}»`, t.p);
    pos++;
    return t;
  };
  function expr(): Node { return cmp(); }
  function cmp(): Node {
    const a = add();
    const t = peek();
    if (t && t.t === 'op' && ['<', '>', '<=', '>=', '==', '!='].includes(t.v)) {
      pos++;
      return { k: 'cmp', op: t.v as never, a, b: add() };
    }
    return a;
  }
  function add(): Node {
    let a = mul();
    for (;;) {
      const t = peek();
      if (t && t.t === 'op' && (t.v === '+' || t.v === '-')) { pos++; a = { k: 'bin', op: t.v, a, b: mul() }; } else return a;
    }
  }
  function mul(): Node {
    let a = unary();
    for (;;) {
      const t = peek();
      if (t && t.t === 'op' && (t.v === '*' || t.v === '/')) { pos++; a = { k: 'bin', op: t.v, a, b: unary() }; } else return a;
    }
  }
  function unary(): Node {
    const t = peek();
    if (t && t.t === 'op' && t.v === '-') { pos++; return { k: 'neg', a: unary() }; }
    return primary();
  }
  function primary(): Node {
    const t = eat();
    if (t.t === 'num') {
      const u = peek();
      if (u && u.t === 'unit') { pos++; return { k: 'num', v: t.v, unit: u.v }; }
      return { k: 'num', v: t.v, unit: '' };
    }
    if (t.t === 'id') {
      const n = peek();
      const fn = FN_ALIASES[t.v.toLowerCase()];
      if (n && n.t === 'op' && n.v === '(' && fn) {
        pos++;
        const args: Node[] = [];
        if (!(peek()?.t === 'op' && peek()?.v === ')')) {
          args.push(expr());
          while (peek()?.t === 'op' && (peek()?.v === ';' || peek()?.v === ',')) { pos++; args.push(expr()); }
        }
        eat(')');
        return { k: 'call', fn, args };
      }
      return { k: 'var', name: t.v };
    }
    if (t.t === 'op' && t.v === '(') {
      const e = expr();
      eat(')');
      return e;
    }
    throw new FormulaError(`No se esperaba «${t.v}»`, t.p);
  }
  if (!toks.length) throw new FormulaError('La fórmula está vacía');
  const node = expr();
  if (pos < toks.length) throw new FormulaError(`No se esperaba «${toks[pos]!.v}»`, toks[pos]!.p);
  return node;
}

/** Cantidad con unidad: valor expresado en su unidad compuesta. */
export interface Q {
  v: Dec;
  dims: DimVec;
  /** Factor de la unidad compuesta a unidades base. */
  f: Dec;
  /** Texto de la unidad compuesta para mensajes. */
  u: string;
  bool?: boolean;
}

export type Scope = Record<string, { value: string; unit: string }>;

function q(value: string, unit: string): Q {
  const pu = parseUnit(unit);
  return { v: dec(value), dims: pu.dims, f: pu.factor, u: pu.text };
}

function toBase(x: Q): Dec { return x.v.mul(x.f); }

function joinUnit(a: string, b: string, op: '*' | '/'): string {
  if (!a && !b) return '';
  if (op === '*') return [a, b].filter(Boolean).join('·');
  return (a || '1') + (b ? '/' + (b.includes('/') || b.includes('·') ? `(${b})` : b) : '');
}

export function evaluate(node: Node, scope: Scope): Q {
  switch (node.k) {
    case 'num': return q(node.v, node.unit);
    case 'var': {
      const s = scope[node.name];
      if (!s) throw new FormulaError(`Variable desconocida: «${node.name}»`);
      return q(s.value, s.unit);
    }
    case 'neg': { const a = evaluate(node.a, scope); return { ...a, v: a.v.neg() }; }
    case 'bin': {
      const a = evaluate(node.a, scope);
      const b = evaluate(node.b, scope);
      if (node.op === '*') return { v: a.v.mul(b.v), dims: mulDims(a.dims, b.dims), f: a.f.mul(b.f), u: joinUnit(a.u, b.u, '*') };
      if (node.op === '/') {
        if (b.v.isZero()) throw new FormulaError('División entre cero');
        return { v: a.v.div(b.v), dims: mulDims(a.dims, b.dims, -1), f: a.f.div(b.f), u: joinUnit(a.u, b.u, '/') };
      }
      if (!sameDims(a.dims, b.dims)) throw new FormulaError(`No se pueden sumar ni restar ${describeDims(a.dims)} y ${describeDims(b.dims)}`);
      const bv = toBase(b).div(a.f);
      return { ...a, v: node.op === '+' ? a.v.add(bv) : a.v.sub(bv) };
    }
    case 'cmp': {
      const a = evaluate(node.a, scope);
      const b = evaluate(node.b, scope);
      if (!sameDims(a.dims, b.dims)) throw new FormulaError('Comparación entre magnitudes distintas');
      const x = toBase(a); const y = toBase(b);
      const r = { '<': x.lt(y), '>': x.gt(y), '<=': x.lte(y), '>=': x.gte(y), '==': x.eq(y), '!=': !x.eq(y) }[node.op];
      return { v: dec(r ? 1 : 0), dims: emptyDims(), f: dec(1), u: '', bool: r };
    }
    case 'call': {
      const args = node.args.map((n) => n);
      if (node.fn === 'si') {
        if (args.length !== 3) throw new FormulaError('si(condición; valor si se cumple; valor si no) necesita tres datos');
        const c = evaluate(args[0]!, scope);
        const yes = evaluate(args[1]!, scope);
        const no = evaluate(args[2]!, scope);
        if (!sameDims(yes.dims, no.dims)) throw new FormulaError('Las dos ramas de «si» deben tener la misma unidad');
        return c.v.isZero() ? no : yes;
      }
      if (node.fn === 'redondear') {
        if (args.length !== 2) throw new FormulaError('redondear(valor; decimales) necesita dos datos');
        const a = evaluate(args[0]!, scope);
        const n = evaluate(args[1]!, scope);
        return { ...a, v: roundPlaces(a.v, n.v.toNumber()) };
      }
      if (args.length < 2) throw new FormulaError(`${node.fn === 'min' ? 'mínimo' : 'máximo'} necesita al menos dos datos`);
      const vals = args.map((n) => evaluate(n, scope));
      const first = vals[0]!;
      for (const v of vals) if (!sameDims(v.dims, first.dims)) throw new FormulaError('mínimo y máximo comparan cantidades de la misma magnitud');
      let best = first;
      for (const v of vals.slice(1)) {
        const better = node.fn === 'min' ? toBase(v).lt(toBase(best)) : toBase(v).gt(toBase(best));
        if (better) best = v;
      }
      return best;
    }
  }
}

/** Unidad resultante sin cifras: sirve para la comprobación dimensional en vivo. */
export function inferDims(node: Node, units: Record<string, string>): DimVec {
  const scope: Scope = {};
  for (const [k, u] of Object.entries(units)) scope[k] = { value: '1', unit: u };
  // Para «si» y comparaciones basta con un valor no nulo.
  return evaluate(node, scope).dims;
}

export interface DimCheck {
  ok: boolean;
  resultDims?: DimVec;
  message: string;
}

/**
 * Comprobación dimensional: «mg/kg × kg ÷ mg/ml = ml», correcto;
 * o «El resultado sale en mg, no en ml».
 */
export function checkDimensions(formula: string, units: Record<string, string>, answerUnit: string): DimCheck {
  try {
    const node = parseFormula(formula);
    const dims = inferDims(node, units);
    const target = parseUnit(answerUnit).dims;
    if (sameDims(dims, target)) return { ok: true, resultDims: dims, message: `La fórmula produce ${answerUnit}` };
    const got = isDimensionless(dims) ? 'sin unidad' : describeDims(dims);
    return { ok: false, resultDims: dims, message: `El resultado sale en ${got}, no en ${answerUnit}` };
  } catch (e) {
    if (e instanceof FormulaError || e instanceof UnitError) return { ok: false, message: e.message };
    throw e;
  }
}

/** Evalúa una fórmula y expresa el resultado en la unidad pedida. */
export function evalIn(formula: string | Node, scope: Scope, unit: string): Dec {
  const node = typeof formula === 'string' ? parseFormula(formula) : formula;
  const r = evaluate(node, scope);
  const target = parseUnit(unit);
  if (!sameDims(r.dims, target.dims)) {
    throw new FormulaError(`El resultado sale en ${describeDims(r.dims)}, no en ${unit}`);
  }
  // Los factores periódicos (60 min/h → 1/60) dejan ruido más allá del decimal 40: se elimina.
  return r.v.mul(r.f).div(target.factor).toDecimalPlaces(30);
}

export function variablesIn(node: Node): string[] {
  const s = new Set<string>();
  const walk = (n: Node) => {
    if (n.k === 'var') s.add(n.name);
    else if (n.k === 'neg') walk(n.a);
    else if (n.k === 'bin' || n.k === 'cmp') { walk(n.a); walk(n.b); }
    else if (n.k === 'call') n.args.forEach(walk);
  };
  walk(node);
  return [...s];
}

export { D };
