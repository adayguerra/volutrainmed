/**
 * Genera el conjunto de regresión de voz de 500 locuciones (tarea 10.3 del MVP),
 * en su capa de texto: lo que devolvería el reconocedor y lo que la gramática
 * debe interpretar. La parte acústica (20 hablantes, silencio y 65 dB, seis
 * dispositivos) requiere grabaciones reales: ver docs/voz/prueba-tecnica.md.
 *
 *   npx tsx packages/engine/scripts/voice-corpus.ts
 */
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { numberToWords, readUnit } from '../src/speech.js';
import { rng } from '../src/template.js';

interface Case { said: string; value: string; unit?: string; digitByDigit?: boolean; category: string }

const r = rng(2026);
const pick = <T>(xs: T[]) => xs[Math.floor(r() * xs.length)]!;
const DIGITS = ['cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
const UNITS = ['ml', 'mg', 'µg', 'ml/h', 'gotas/min', 'mg/ml', 'UI', 'µg/kg/min', 'mg/kg', 'g', 'kg', 'h', 'min'];
const cases: Case[] = [];
const seen = new Set<string>();
const add = (c: Case) => { if (!seen.has(c.said)) { seen.add(c.said); cases.push(c); } };

function decimalString(maxInt: number, places: number, leadingZeros = 0): string {
  if (leadingZeros >= places) places = leadingZeros + 1;
  const int = Math.floor(r() * maxInt);
  let frac = '0'.repeat(leadingZeros);
  for (let i = leadingZeros; i < places; i++) frac += String(i === places - 1 ? 1 + Math.floor(r() * 9) : Math.floor(r() * 10));
  return `${int}.${frac}`;
}

// 1. Enteros de 0 a 999 999 (120).
while (cases.length < 120) {
  const mag = pick([10, 100, 1000, 10000, 1000000]);
  const v = String(Math.floor(r() * mag));
  add({ said: numberToWords(v), value: v, category: 'entero' });
}
// 2. Decimales dichos como número tras «coma», «con» o «punto» (110).
while (cases.length < 230) {
  const v = decimalString(pick([1, 10, 100, 1000]), pick([1, 2, 2, 3]), r() < 0.25 ? 1 : 0);
  const sep = pick(['coma', 'coma', 'coma', 'con', 'punto']);
  const said = numberToWords(v).replace(' coma ', ` ${sep} `);
  add({ said, value: v, category: `decimal-${sep}` });
}
// 3. Decimales cifra a cifra tras la coma (60).
while (cases.length < 290) {
  const v = decimalString(pick([1, 10, 100]), pick([2, 3]));
  const [i, f] = v.split('.') as [string, string];
  add({ said: `${numberToWords(i)} coma ${f.split('').map((d) => DIGITS[Number(d)]).join(' ')}`, value: v, category: 'decimal-cifras' });
}
// 4. Coma inicial sin cero («coma cinco») (20).
while (cases.length < 310) {
  const d = 1 + Math.floor(r() * 9);
  const two = r() < 0.5;
  const f = two ? `${d}${1 + Math.floor(r() * 9)}` : String(d);
  add({ said: `coma ${numberToWords(f)}`, value: `0.${f}`, category: 'coma-inicial' });
}
// 5. Fracciones habladas (30).
const FR: [string, string][] = [['medio', '0.5'], ['un cuarto', '0.25'], ['tres cuartos', '0.75']];
for (const [s, v] of FR) add({ said: s, value: v, category: 'fraccion' });
while (cases.length < 340) {
  const n = 1 + Math.floor(r() * 99);
  const half = r() < 0.6;
  add({ said: `${numberToWords(String(n))} y ${half ? 'medio' : 'cuarto'}`, value: `${n}.${half ? '5' : '25'}`, category: 'fraccion' });
}
// 6. Con unidad hablada (100).
while (cases.length < 440) {
  const unit = pick(UNITS);
  const v = r() < 0.5 ? String(1 + Math.floor(r() * 500)) : decimalString(pick([1, 10, 100]), pick([1, 2]));
  const u = readUnit(unit, v !== '1');
  add({ said: `${numberToWords(v, u.gender, true)} ${u.text}`, value: v, unit, category: 'con-unidad' });
}
// 7. Modo cifra a cifra para enteros (25).
while (cases.length < 465) {
  const v = String(100 + Math.floor(r() * 9900));
  add({ said: v.split('').map((d) => DIGITS[Number(d)]).join(' '), value: String(BigInt(v)), digitByDigit: true, category: 'cifra-a-cifra' });
}
// 8. Confusiones del reconocedor corregidas por el léxico (35).
while (cases.length < 500) {
  const v = decimalString(pick([10, 100]), 1);
  const said = numberToWords(v).replace(' coma ', ` ${pick(['como', 'toma'])} `).replace(/^cero /, r() < 0.3 ? 'cerro ' : 'cero ');
  add({ said, value: v, category: 'confusion' });
}

const out = join(dirname(fileURLToPath(import.meta.url)), '../../../contracts/fixtures/voice-regression-500.json');
writeFileSync(out, JSON.stringify({
  description: 'Conjunto de regresión de voz (capa de texto): 500 locuciones con su interpretación esperada. La parte acústica requiere grabaciones reales.',
  total: cases.length,
  categories: Object.fromEntries([...new Set(cases.map((c) => c.category))].map((k) => [k, cases.filter((c) => c.category === k).length])),
  cases,
}, null, 1));
console.log(`${cases.length} locuciones → ${out}`);
