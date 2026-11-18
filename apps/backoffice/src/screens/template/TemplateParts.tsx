/** Pasos del asistente de plantillas (B06–B08) y panel de pruebas (B09). */
import { useState } from 'react';
import type { TemplateDefinition, VariableDef } from '@vtm/engine';
import { ERROR_LABELS, type ErrorCode } from '@vtm/contracts';
import { commonError, formulaCheck, runMassTest, sample, type MassReport, type SampleRow } from '../../content/template';
import { ERROR_CODES, SKILLS } from '../../content/common';

type Named = { id: string; name: string };
import { Field, Icon, Notice, Panel } from '../../ui/kit';
import { num, qty } from '../../ui/format';

type Def = TemplateDefinition;
type Set = (fn: (d: Def) => Def) => void;

const KIND_OPTS: { id: VariableDef['kind']; label: string }[] = [
  { id: 'int', label: 'Entero' }, { id: 'decimal', label: 'Decimal' }, { id: 'list', label: 'Lista' }, { id: 'case_table', label: 'Tabla de casos' }, { id: 'computed', label: 'Calculada' },
];

function move<T>(arr: T[], i: number, d: -1 | 1): T[] {
  const j = i + d;
  if (j < 0 || j >= arr.length) return arr;
  const next = [...arr];
  [next[i], next[j]] = [next[j]!, next[i]!];
  return next;
}

// ------------------------------------------------------------------ 1 · Datos generales
export function GeneralStep({ def, set, sectors, types, skills = SKILLS, species = [] }: { def: Def; set: Set; sectors: Named[]; types: Named[]; skills?: Named[]; species?: string[] }) {
  return (
    <div className="grid2">
      <Field label="Nombre de la plantilla" id="t-name"><input id="t-name" className="input" value={def.name} onChange={(e) => set((d) => ({ ...d, name: e.target.value }))} /></Field>
      <Field label="Sector" id="t-sector"><select id="t-sector" className="input" value={def.sectorId} onChange={(e) => set((d) => ({ ...d, sectorId: e.target.value }))}>{sectors.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
      <Field label="Habilidad" id="t-skill"><select id="t-skill" className="input" value={def.skillId} onChange={(e) => set((d) => ({ ...d, skillId: e.target.value as Def['skillId'] }))}>{skills.map((s) => <option key={s.id} value={s.id}>{s.id} · {s.name}</option>)}</select></Field>
      <Field label="Tipo de ejercicio" id="t-type"><select id="t-type" className="input" value={def.exerciseTypeId} onChange={(e) => set((d) => ({ ...d, exerciseTypeId: e.target.value }))}>{types.map((t) => <option key={t.id} value={t.id}>{t.id} · {t.name}</option>)}</select></Field>
      {def.sectorId === 'veterinaria' && (
        <Field label="Especie" id="t-species" help="Del catálogo de especies.">
          <select id="t-species" className="input" value={def.species ?? ''} onChange={(e) => set((d) => ({ ...d, species: e.target.value || null }))}>
            <option value="">Sin especie</option>
            {[...new Set([...species.map((x) => x.toLowerCase()), ...(def.species ? [def.species] : [])])].map((x) => <option key={x} value={x}>{x.charAt(0).toUpperCase() + x.slice(1)}</option>)}
          </select>
        </Field>
      )}
      <Field label="Variantes que se publicarán por nivel" id="t-vpl" help="300 por defecto. Un número menor reduce el tamaño del paquete.">
        <input id="t-vpl" className="input mono" type="number" min={1} max={1000} value={def.variantsPerLevel} onChange={(e) => set((d) => ({ ...d, variantsPerLevel: Math.max(1, Number(e.target.value) || 1) }))} />
      </Field>
    </div>
  );
}

// ------------------------------------------------------------------ 2 · Variables
function CaseTable({ v, update }: { v: VariableDef; update: (p: Partial<VariableDef>) => void }) {
  const cols = v.columns ?? [];
  const rows = v.rows ?? [];
  return (
    <div className="col g8 card" style={{ background: 'var(--surface-2)' }}>
      <strong className="ui t-small">Tabla de casos · {v.name}</strong>
      <div className="col g6">
        <span className="t-label muted">Columnas (nombre y unidad)</span>
        {cols.map((c, i) => (
          <div key={i} className="row g6">
            <input aria-label={`Nombre de la columna ${i + 1} de ${v.name}`} className="input input-sm mono" value={c.name} onChange={(e) => update({ columns: cols.map((x, j) => (j === i ? { ...x, name: e.target.value } : x)) })} />
            <input aria-label={`Unidad de la columna ${i + 1} de ${v.name}`} className="input input-sm mono" style={{ width: 120 }} value={c.unit} onChange={(e) => update({ columns: cols.map((x, j) => (j === i ? { ...x, unit: e.target.value } : x)) })} />
            <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar la columna ${c.name}`} onClick={() => update({ columns: cols.filter((_, j) => j !== i) })}><Icon name="close" /></button>
          </div>
        ))}
        <button type="button" className="btn btn-tertiary btn-xs" onClick={() => update({ columns: [...cols, { name: `col${cols.length + 1}`, unit: '' }] })}><Icon name="add" />Añadir columna</button>
      </div>
      <div className="tblwrap">
        <table className="tbl" aria-label={`Filas de la tabla de casos ${v.name}`}>
          <thead><tr>{cols.map((c) => <th key={c.name}>{c.name}{c.unit ? ` (${c.unit})` : ''}</th>)}<th><span className="sr-only">Acciones</span></th></tr></thead>
          <tbody>{rows.map((r, i) => (
            <tr key={i}>
              {cols.map((c) => <td key={c.name}><input aria-label={`Fila ${i + 1} · ${c.name}`} className="input input-sm mono" value={r[c.name] ?? ''} onChange={(e) => update({ rows: rows.map((x, j) => (j === i ? { ...x, [c.name]: e.target.value } : x)) })} /></td>)}
              <td className="actions"><button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar la fila ${i + 1}`} onClick={() => update({ rows: rows.filter((_, j) => j !== i) })}><Icon name="delete" /></button></td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      <button type="button" className="btn btn-secondary btn-xs" onClick={() => update({ rows: [...rows, Object.fromEntries(cols.map((c) => [c.name, '']))] })}><Icon name="add" />Añadir fila</button>
      <p className="t-small muted">El generador elige una fila entera: evita combinaciones farmacológicamente absurdas.</p>
    </div>
  );
}

export function VariablesStep({ def, set }: { def: Def; set: Set }) {
  const update = (i: number, p: Partial<VariableDef>) => set((d) => ({ ...d, variables: d.variables.map((v, j) => (j === i ? { ...v, ...p } : v)) }));
  return (
    <div className="col g12">
      <div className="tblwrap">
        <table className="tbl" aria-label="Variables">
          <thead><tr><th>Nombre</th><th>Etiqueta</th><th>Tipo</th><th>Rango, valores o fórmula</th><th>Paso</th><th>Unidad</th><th>En el enunciado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
          <tbody>{def.variables.map((v, i) => (
            <tr key={i}>
              <td><input aria-label={`Nombre de la variable ${i + 1}`} className="input input-sm mono" value={v.name} onChange={(e) => update(i, { name: e.target.value.replace(/[^a-zA-Z0-9_áéíóúñ]/g, '') })} /></td>
              <td><input aria-label={`Etiqueta de la variable ${i + 1}`} className="input input-sm" value={v.label} onChange={(e) => update(i, { label: e.target.value })} /></td>
              <td><select aria-label={`Tipo de la variable ${i + 1}`} className="input input-sm" value={v.kind} onChange={(e) => update(i, { kind: e.target.value as VariableDef['kind'], ...(e.target.value === 'case_table' ? { columns: v.columns ?? [{ name: 'farmaco', unit: '' }], rows: v.rows ?? [] } : {}) })}>{KIND_OPTS.map((k) => <option key={k.id} value={k.id}>{k.label}</option>)}</select></td>
              <td>
                {(v.kind === 'int' || v.kind === 'decimal') && (
                  <div className="row g4">
                    <input aria-label={`Mínimo de ${v.name}`} className="input input-sm mono" style={{ width: 80 }} value={v.min ?? ''} onChange={(e) => update(i, { min: e.target.value.replace(',', '.') })} />
                    <span className="muted">a</span>
                    <input aria-label={`Máximo de ${v.name}`} className="input input-sm mono" style={{ width: 80 }} value={v.max ?? ''} onChange={(e) => update(i, { max: e.target.value.replace(',', '.') })} />
                  </div>
                )}
                {v.kind === 'list' && <input aria-label={`Valores de ${v.name}`} className="input input-sm mono" value={(v.values ?? []).join('; ')} onChange={(e) => update(i, { values: e.target.value.split(';').map((x) => x.trim().replace(',', '.')).filter(Boolean) })} />}
                {v.kind === 'computed' && <input aria-label={`Fórmula de ${v.name}`} className="input input-sm mono" value={v.formula ?? ''} onChange={(e) => update(i, { formula: e.target.value })} />}
                {v.kind === 'case_table' && <span className="t-small muted">{(v.rows ?? []).length} filas</span>}
              </td>
              <td>{(v.kind === 'int' || v.kind === 'decimal') ? <input aria-label={`Paso de ${v.name}`} className="input input-sm mono" style={{ width: 70 }} value={v.step ?? ''} onChange={(e) => update(i, { step: e.target.value.replace(',', '.') })} /> : '—'}</td>
              <td>{v.kind !== 'case_table' ? <input aria-label={`Unidad de ${v.name}`} className="input input-sm mono" style={{ width: 100 }} value={v.unit} onChange={(e) => update(i, { unit: e.target.value })} /> : '—'}</td>
              <td><input aria-label={`${v.name} aparece en el enunciado`} type="checkbox" checked={v.show} onChange={(e) => update(i, { show: e.target.checked })} /></td>
              <td className="actions">
                <button type="button" className="iconbtn iconbtn-sm" aria-label={`Subir la variable ${v.name}`} onClick={() => set((d) => ({ ...d, variables: move(d.variables, i, -1) }))}><Icon name="arrow_upward" /></button>
                <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar la variable ${v.name}`} onClick={() => set((d) => ({ ...d, variables: d.variables.filter((_, j) => j !== i) }))}><Icon name="delete" /></button>
              </td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      {def.variables.map((v, i) => v.kind === 'case_table' ? <CaseTable key={`ct-${i}`} v={v} update={(p) => update(i, p)} /> : null)}
      <div className="row g8 wrap">
        {KIND_OPTS.map((k) => (
          <button key={k.id} type="button" className="btn btn-secondary btn-xs" onClick={() => set((d) => ({
            ...d,
            variables: [...d.variables, k.id === 'case_table'
              ? { name: `caso${d.variables.length ? d.variables.length + 1 : ''}`, label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [{ name: 'farmaco', unit: '' }, { name: 'dosis', unit: 'mg/kg' }, { name: 'conc', unit: 'mg/ml' }], rows: [] }
              : { name: `v${d.variables.length + 1}`, label: '', kind: k.id, unit: '', show: k.id !== 'computed', ...(k.id === 'int' || k.id === 'decimal' ? { min: '1', max: '10', step: k.id === 'int' ? '1' : '0.1' } : {}), ...(k.id === 'list' ? { values: [] } : {}) }],
          }))}><Icon name="add" />{k.label}</button>
        ))}
      </div>
    </div>
  );
}

// ------------------------------------------------------------------ 3 · Enunciado
export function StatementStep({ def, set, preview }: { def: Def; set: Set; preview: SampleRow | null }) {
  const vars = def.variables.flatMap((v) => (v.kind === 'case_table' ? (v.columns ?? []).map((c) => `${v.name}.${c.name}`) : [v.name]));
  return (
    <div className="col g16">
      <Field label="Enunciado" id="t-statement" help="Escribe las variables entre llaves, por ejemplo {peso}. Las cantidades se resaltan en la app.">
        <textarea id="t-statement" className="input" value={def.statement} onChange={(e) => set((d) => ({ ...d, statement: e.target.value }))} />
      </Field>
      <div className="row g6 wrap" aria-label="Insertar variable">
        {vars.map((v) => <button key={v} type="button" className="tag-var" style={{ cursor: 'pointer' }} onClick={() => set((d) => ({ ...d, statement: `${d.statement}{${v}}` }))}>{`{${v}}`}</button>)}
      </div>
      <Field label="Pregunta" id="t-question"><input id="t-question" className="input" value={def.question} onChange={(e) => set((d) => ({ ...d, question: e.target.value }))} /></Field>
      <Field label="Texto para voz (opcional)" id="t-tts" help="Si lo dejas vacío, se genera con el normalizador de lectura de la app.">
        <textarea id="t-tts" className="input" value={def.tts ?? ''} onChange={(e) => set((d) => ({ ...d, tts: e.target.value || null }))} />
      </Field>
      <div className="grid2">
        <Field label="Planteamiento (niveles con apoyos)" id="t-approach"><input id="t-approach" className="input" value={def.approach ?? ''} onChange={(e) => set((d) => ({ ...d, approach: e.target.value }))} /></Field>
        <Field label="Pista" id="t-hint"><input id="t-hint" className="input" value={def.hint ?? ''} onChange={(e) => set((d) => ({ ...d, hint: e.target.value }))} /></Field>
      </div>
      <Field label="Comprobación de plausibilidad" id="t-plaus" help="Usa {respuesta} para citar el resultado."><input id="t-plaus" className="input" value={def.plausibility} onChange={(e) => set((d) => ({ ...d, plausibility: e.target.value }))} /></Field>
      {preview && <Notice kind="info">Ejemplo: {preview.statement} {preview.question}</Notice>}
    </div>
  );
}

// ------------------------------------------------------------------ 4 · Fórmula y respuesta
const OPS = [['+', ' + '], ['−', ' − '], ['×', ' × '], ['÷', ' ÷ '], ['( )', '()'], ['redondear', 'redondear(, 1)'], ['mínimo', 'mínimo(, )'], ['máximo', 'máximo(, )'], ['si', 'si(, , )']] as const;

export function FormulaStep({ def, set, preview }: { def: Def; set: Set; preview: SampleRow | null }) {
  const dc = formulaCheck(def);
  const rounding = def.rounding;
  return (
    <div className="col g16">
      <Field label="Fórmula" id="t-formula">
        <input id="t-formula" className="input mono" style={{ fontSize: 18 }} value={def.formula} onChange={(e) => set((d) => ({ ...d, formula: e.target.value }))} aria-describedby="t-formula-check" />
      </Field>
      <div className="row g6 wrap" aria-label="Operadores">
        {OPS.map(([l, ins]) => <button key={l} type="button" className="btn btn-secondary btn-xs mono" onClick={() => set((d) => ({ ...d, formula: `${d.formula}${ins}` }))}>{l}</button>)}
      </div>
      <div id="t-formula-check" aria-live="polite">
        {dc && (dc.ok
          ? <Notice kind="ok" icon="check_circle"><strong>Las unidades cuadran.</strong> {dc.message}. Coincide con la unidad de respuesta.</Notice>
          : <Notice kind="err"><strong>{dc.message}</strong>. Una fórmula que no cuadra en unidades no se puede guardar.</Notice>)}
      </div>
      <div className="grid2">
        <Field label="Unidad de respuesta" id="t-unit"><input id="t-unit" className="input mono" value={def.answerUnit} onChange={(e) => set((d) => ({ ...d, answerUnit: e.target.value, unitChoices: d.unitChoices.includes(e.target.value) ? d.unitChoices : [e.target.value, ...d.unitChoices.slice(1)] }))} /></Field>
        <Field label="Unidades a elegir en niveles 4 y 5" id="t-choices" help="Separadas por punto y coma."><input id="t-choices" className="input mono" value={def.unitChoices.join('; ')} onChange={(e) => set((d) => ({ ...d, unitChoices: e.target.value.split(';').map((x) => x.trim()).filter(Boolean) }))} /></Field>
        <Field label="Redondeo" id="t-round">
          <select id="t-round" className="input" value={rounding.mode === 'decimals' ? `d${rounding.places}` : rounding.mode} onChange={(e) => {
            const v = e.target.value;
            set((d) => ({ ...d, rounding: v.startsWith('d') ? { mode: 'decimals', places: Number(v.slice(1)) } : v === 'syringe_auto' ? { mode: 'syringe_auto' } : v === 'integer' ? { mode: 'integer' } : v === 'instrument' ? { mode: 'instrument', step: '0.1', instrument: 'jeringa' } : { mode: 'none' } }));
          }}>
            <option value="none">Sin redondeo</option><option value="d0">Entero (0 decimales)</option><option value="d1">1 decimal</option><option value="d2">2 decimales</option><option value="d3">3 decimales</option>
            <option value="integer">Entero (gotas, comprimidos)</option><option value="syringe_auto">Según el instrumento · jeringa por volumen</option><option value="instrument">Paso fijo del instrumento</option>
          </select>
        </Field>
        {rounding.mode === 'instrument' && (
          <Field label="Paso del instrumento" id="t-step"><input id="t-step" className="input mono" value={rounding.step} onChange={(e) => set((d) => ({ ...d, rounding: { mode: 'instrument', step: e.target.value.replace(',', '.'), instrument: (d.rounding as { instrument: string }).instrument } }))} /></Field>
        )}
        <Field label="Tolerancia" id="t-tol">
          <select id="t-tol" className="input" value={def.tolerance.kind} onChange={(e) => set((d) => ({ ...d, tolerance: e.target.value === 'abs' ? { kind: 'abs', value: '0.01' } : e.target.value === 'rel' ? { kind: 'rel', percent: '1' } : { kind: 'exact' } }))}>
            <option value="exact">Exacta sobre el valor redondeado</option><option value="abs">Absoluta</option><option value="rel">Relativa (%)</option>
          </select>
        </Field>
        {def.tolerance.kind !== 'exact' && (
          <Field label={def.tolerance.kind === 'abs' ? 'Margen absoluto' : 'Margen en %'} id="t-tolv">
            <input id="t-tolv" className="input mono" value={def.tolerance.kind === 'abs' ? def.tolerance.value : def.tolerance.percent} onChange={(e) => set((d) => ({ ...d, tolerance: d.tolerance.kind === 'abs' ? { kind: 'abs', value: e.target.value.replace(',', '.') } : { kind: 'rel', percent: e.target.value.replace(',', '.') } }))} />
          </Field>
        )}
        <Field label="Unidades equivalentes aceptadas" id="t-eq" help="Unidad=factor, separadas por punto y coma. Por ejemplo: µg/ml=1000.">
          <input id="t-eq" className="input mono" value={def.equivalents.map((e) => `${e.unit}=${e.factor}`).join('; ')} onChange={(e) => set((d) => ({ ...d, equivalents: e.target.value.split(';').map((x) => x.trim()).filter(Boolean).map((x) => { const [unit, factor] = x.split('='); return { unit: (unit ?? '').trim(), factor: (factor ?? '1').trim().replace(',', '.') }; }) }))} />
        </Field>
      </div>
      {preview && (
        <div className="card col g6">
          <span className="t-label muted">Respuesta de una variante de ejemplo</span>
          <span className="kv">{qty(preview.answer, preview.unit)}</span>
          <ol className="col g4">{preview.steps.map((s) => <li key={s.n} className="op">{s.n}. {s.operation} = {qty(s.result.value, s.result.unit)}</li>)}</ol>
        </div>
      )}
    </div>
  );
}

// ------------------------------------------------------------------ 5 · Restricciones y errores previsibles
export function ErrorsStep({ def, set, preview }: { def: Def; set: Set; preview: SampleRow | null }) {
  const c = def.constraints;
  const upd = (i: number, p: Partial<Def['predictedErrors'][number]>) => set((d) => ({ ...d, predictedErrors: d.predictedErrors.map((e, j) => (j === i ? { ...e, ...p } : e)) }));
  return (
    <div className="col g16">
      <h3 className="t-sub" style={{ fontSize: 16 }}>Restricciones</h3>
      <div className="grid2">
        <Field label={`Resultado mínimo (${def.answerUnit})`} id="t-rmin"><input id="t-rmin" className="input mono" value={c.resultMin ?? ''} onChange={(e) => set((d) => ({ ...d, constraints: { ...d.constraints, resultMin: e.target.value.replace(',', '.') || undefined } }))} /></Field>
        <Field label={`Resultado máximo (${def.answerUnit})`} id="t-rmax"><input id="t-rmax" className="input mono" value={c.resultMax ?? ''} onChange={(e) => set((d) => ({ ...d, constraints: { ...d.constraints, resultMax: e.target.value.replace(',', '.') || undefined } }))} /></Field>
      </div>
      <Field label="Condiciones entre variables" id="t-cond" help="Una por línea, por ejemplo: peso ≤ 8[kg]">
        <textarea id="t-cond" className="input mono" value={c.conditions.join('\n')} onChange={(e) => set((d) => ({ ...d, constraints: { ...d.constraints, conditions: e.target.value.split('\n').map((x) => x.trim()).filter(Boolean) } }))} />
      </Field>
      <h3 className="t-sub" style={{ fontSize: 16 }}>Respuestas erróneas previsibles</h3>
      <div className="tblwrap">
        <table className="tbl" aria-label="Errores previsibles">
          <thead><tr><th>Fórmula errónea</th><th>Unidad</th><th>Ejemplo</th><th>Código</th><th>Diagnóstico en una frase</th><th><span className="sr-only">Acciones</span></th></tr></thead>
          <tbody>{def.predictedErrors.map((p, i) => (
            <tr key={i}>
              <td><input aria-label={`Fórmula del error ${i + 1}`} className="input input-sm mono" value={p.formula} onChange={(e) => upd(i, { formula: e.target.value })} /></td>
              <td><input aria-label={`Unidad del error ${i + 1}`} className="input input-sm mono" style={{ width: 90 }} value={p.unit} onChange={(e) => upd(i, { unit: e.target.value })} /></td>
              <td className="num">{preview?.predicted[i] ? qty(preview.predicted[i]!.value, preview.predicted[i]!.unit) : '—'}</td>
              <td><select aria-label={`Código del error ${i + 1}`} className="input input-sm" value={p.code} onChange={(e) => upd(i, { code: e.target.value as ErrorCode })}>{ERROR_CODES.map((k) => <option key={k} value={k}>{k} · {ERROR_LABELS[k]}</option>)}</select></td>
              <td><input aria-label={`Diagnóstico del error ${i + 1}`} className="input input-sm" value={p.message} onChange={(e) => upd(i, { message: e.target.value })} /></td>
              <td className="actions"><button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar el error ${i + 1}`} onClick={() => set((d) => ({ ...d, predictedErrors: d.predictedErrors.filter((_, j) => j !== i) }))}><Icon name="delete" /></button></td>
            </tr>
          ))}</tbody>
        </table>
      </div>
      <div className="row g8 wrap">
        <span className="t-small muted">Añadir error habitual:</span>
        {([['E1', 'E1 · Unidad'], ['E2', 'E2 · ×10'], ['E4', 'E4 · Intermedio'], ['E6', 'E6 · Límite']] as const).map(([k, l]) => (
          <button key={k} type="button" className="btn btn-secondary btn-xs" onClick={() => set((d) => ({ ...d, predictedErrors: [...d.predictedErrors, commonError(k, d)] }))}>{l}</button>
        ))}
        <button type="button" className="btn btn-tertiary btn-xs" onClick={() => set((d) => ({ ...d, predictedErrors: [...d.predictedErrors, { formula: '', unit: d.answerUnit, code: 'E0', message: '' }] }))}><Icon name="add" />Otro</button>
      </div>
    </div>
  );
}

// ------------------------------------------------------------------ 6 · Explicación y niveles
export function StepsLevelsStep({ def, set }: { def: Def; set: Set }) {
  const upd = (i: number, p: Partial<Def['steps'][number]>) => set((d) => ({ ...d, steps: d.steps.map((s, j) => (j === i ? { ...s, ...p } : s)) }));
  const ranged = def.variables.filter((v) => v.kind === 'int' || v.kind === 'decimal');
  const lists = def.variables.filter((v) => v.kind === 'list');
  const updLevel = (l: number, p: Partial<Def['levels'][number]>) => set((d) => ({ ...d, levels: d.levels.map((x) => (x.level === l ? { ...x, ...p } : x)) }));
  const updOv = (l: number, name: string, key: 'min' | 'max' | 'multipleOf' | 'values', value: string) => set((d) => ({
    ...d,
    levels: d.levels.map((x) => {
      if (x.level !== l) return x;
      const ov = { ...(x.overrides ?? {}) };
      const cur = { ...(ov[name] ?? {}) } as Record<string, unknown>;
      if (key === 'values') cur.values = value.split(';').map((s) => s.trim().replace(',', '.')).filter(Boolean);
      else cur[key] = value.replace(',', '.') || undefined;
      Object.keys(cur).forEach((k) => { if (cur[k] === undefined || (Array.isArray(cur[k]) && !(cur[k] as unknown[]).length)) delete cur[k]; });
      if (Object.keys(cur).length) ov[name] = cur; else delete ov[name];
      return { ...x, overrides: Object.keys(ov).length ? ov : undefined };
    }),
  }));
  return (
    <div className="col g16">
      <h3 className="t-sub" style={{ fontSize: 16 }}>Pasos de la explicación</h3>
      <p className="t-small muted">Cada paso calcula un valor intermedio con su unidad. Los pasos siguientes pueden usar paso1, paso2… y el resultado, respuesta.</p>
      <ol className="col g8" aria-label="Pasos de la explicación">
        {def.steps.map((s, i) => (
          <li key={i} className="step" style={{ flexWrap: 'wrap' }}>
            <span className="n">{i + 1}</span>
            <div className="col g6 grow">
              <input aria-label={`Texto del paso ${i + 1}`} className="input input-sm" value={s.text} onChange={(e) => upd(i, { text: e.target.value })} placeholder="Qué se hace" />
              <div className="row g6 wrap">
                <input aria-label={`Fórmula del paso ${i + 1}`} className="input input-sm mono" style={{ flex: '2 1 200px' }} value={s.formula} onChange={(e) => upd(i, { formula: e.target.value })} placeholder="Fórmula" />
                <input aria-label={`Unidad del paso ${i + 1}`} className="input input-sm mono" style={{ flex: '0 1 100px' }} value={s.unit} onChange={(e) => upd(i, { unit: e.target.value })} placeholder="Unidad" />
                <input aria-label={`Operación mostrada en el paso ${i + 1}`} className="input input-sm mono" style={{ flex: '2 1 200px' }} value={s.operation} onChange={(e) => upd(i, { operation: e.target.value })} placeholder="{peso} × {caso.dosis}" />
                <input aria-label={`Unidades canceladas en el paso ${i + 1}`} className="input input-sm mono" style={{ flex: '1 1 120px' }} value={s.cancelled.join('; ')} onChange={(e) => upd(i, { cancelled: e.target.value.split(';').map((x) => x.trim()).filter(Boolean) })} placeholder="Canceladas" />
              </div>
            </div>
            <div className="row g4">
              <button type="button" className="iconbtn iconbtn-sm" aria-label={`Subir el paso ${i + 1}`} onClick={() => set((d) => ({ ...d, steps: move(d.steps, i, -1) }))}><Icon name="arrow_upward" /></button>
              <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar el paso ${i + 1}`} onClick={() => set((d) => ({ ...d, steps: d.steps.filter((_, j) => j !== i) }))}><Icon name="delete" /></button>
            </div>
          </li>
        ))}
      </ol>
      <button type="button" className="btn btn-secondary btn-sm" onClick={() => set((d) => ({ ...d, steps: [...d.steps, { text: '', formula: d.formula, unit: d.answerUnit, operation: '', cancelled: [] }] }))}><Icon name="add" />Añadir paso</button>

      <h3 className="t-sub" style={{ fontSize: 16 }}>Niveles de dificultad</h3>
      <div className="tblwrap">
        <table className="tbl" aria-label="Niveles de dificultad">
          <thead><tr><th>Nivel</th><th>Tiempo objetivo (s)</th><th>Unidad fija</th>{ranged.map((v) => <th key={v.name}>{v.name}: mínimo · máximo · múltiplo de</th>)}{lists.map((v) => <th key={v.name}>{v.name}: valores</th>)}</tr></thead>
          <tbody>{def.levels.map((l) => (
            <tr key={l.level}>
              <td className="mono b">{l.level}</td>
              <td><input aria-label={`Tiempo objetivo del nivel ${l.level}`} className="input input-sm mono" style={{ width: 70 }} type="number" value={l.targetTimeS} onChange={(e) => updLevel(l.level, { targetTimeS: Number(e.target.value) })} /></td>
              <td><input aria-label={`Unidad fija en el nivel ${l.level}`} type="checkbox" checked={l.unitFixed} onChange={(e) => updLevel(l.level, { unitFixed: e.target.checked })} /></td>
              {ranged.map((v) => {
                const ov = l.overrides?.[v.name] ?? {};
                return (
                  <td key={v.name}><div className="row g4">
                    <input aria-label={`Nivel ${l.level} · mínimo de ${v.name}`} className="input input-sm mono" style={{ width: 64 }} value={ov.min ?? ''} placeholder={v.min} onChange={(e) => updOv(l.level, v.name, 'min', e.target.value)} />
                    <input aria-label={`Nivel ${l.level} · máximo de ${v.name}`} className="input input-sm mono" style={{ width: 64 }} value={ov.max ?? ''} placeholder={v.max} onChange={(e) => updOv(l.level, v.name, 'max', e.target.value)} />
                    <input aria-label={`Nivel ${l.level} · múltiplo de para ${v.name}`} className="input input-sm mono" style={{ width: 64 }} value={ov.multipleOf ?? ''} onChange={(e) => updOv(l.level, v.name, 'multipleOf', e.target.value)} />
                  </div></td>
                );
              })}
              {lists.map((v) => <td key={v.name}><input aria-label={`Nivel ${l.level} · valores de ${v.name}`} className="input input-sm mono" value={(l.overrides?.[v.name]?.values ?? []).join('; ')} placeholder={(v.values ?? []).join('; ')} onChange={(e) => updOv(l.level, v.name, 'values', e.target.value)} /></td>)}
            </tr>
          ))}</tbody>
        </table>
      </div>
    </div>
  );
}

// ------------------------------------------------------------------ Panel de pruebas (B09)
export function TestPanel({ def, mass, setMass }: { def: Def; mass: MassReport | null; setMass: (m: MassReport | null) => void }) {
  const [rows, setRows] = useState<SampleRow[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [level, setLevel] = useState<number | ''>('');
  const [running, setRunning] = useState(false);
  const cols = def.variables.filter((v) => v.show).flatMap((v) => (v.kind === 'case_table' ? (v.columns ?? []).map((c) => `${v.name}.${c.name}`) : [v.name]));
  const maxCount = Math.max(1, ...(mass?.distribution.map((d) => d.count) ?? [1]));
  return (
    <Panel title="Panel de pruebas" icon="science" id="test-panel">
      <div className="col g12">
        <div className="row g8 wrap">
          <select aria-label="Nivel de la muestra" className="input input-sm" style={{ width: 'auto' }} value={level} onChange={(e) => setLevel(e.target.value ? Number(e.target.value) : '')}>
            <option value="">Todos los niveles</option>{[1, 2, 3, 4, 5].map((l) => <option key={l} value={l}>Nivel {l}</option>)}
          </select>
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => { const r = sample(def, 20, level || undefined); setRows(r.rows); setErr(r.error ?? null); }}><Icon name="casino" />Generar 20 variantes de muestra</button>
          <button type="button" className="btn btn-secondary btn-sm" disabled={running} onClick={() => { setRunning(true); setTimeout(() => { setMass(runMassTest(def)); setRunning(false); }, 0); }}><Icon name="analytics" />Prueba masiva (1000)</button>
        </div>
        {err && <Notice kind="err">{err}</Notice>}
        {mass && (
          <section className="col g12" aria-label="Informe de la prueba masiva">
            {mass.error ? <Notice kind="err">{mass.error}</Notice> : (
              <>
                <div className="grid4">
                  <div className="col g4"><span className="t-label muted">Válidas</span><span className="kpi" data-testid="mass-valid">{mass.valid} de {mass.draws}</span></div>
                  <div className="col g4"><span className="t-label muted">Descartadas por restricciones</span><span className="kpi">{num(mass.discardedPct, 1)} %</span></div>
                  <div className="col g4"><span className="t-label muted">Repeticiones</span><span className="kpi">{mass.repetitions}</span></div>
                  <div className="col g4"><span className="t-label muted">Extremos</span><span className="kpi" style={{ fontSize: 20 }}>{mass.extremes.min ? `${num(mass.extremes.min)} y ${num(mass.extremes.max)} ${def.answerUnit}` : '—'}</span></div>
                </div>
                {mass.collisions > 0 ? (
                  <Notice kind="err"><strong>{mass.collisions} colisiones entre la respuesta correcta y una errónea previsible.</strong> {mass.collisionExamples.map((c) => `${c.variantId}: ${num(c.value)} (${c.code})`).join(' · ')}. Resuélvelas antes de enviar a revisión: ajusta los rangos, las restricciones o el error previsible.</Notice>
                ) : <Notice kind="ok">Sin colisiones entre la respuesta correcta y los errores previsibles.</Notice>}
                {mass.doubleCheckFailures > 0 && <Notice kind="err">El doble cálculo no coincide en {mass.doubleCheckFailures} variantes.</Notice>}
                {mass.shortfall.length > 0 && (
                  <Notice kind="warn">
                    <strong>Variantes insuficientes.</strong>{' '}
                    {mass.shortfall.map((s) => `Nivel ${s.level}: ${s.generated} de ${s.requested} cumplen las restricciones`).join(' · ')}. Amplía los rangos de las variables o relaja las restricciones.
                  </Notice>
                )}
                {mass.distribution.length > 0 && (
                  <div className="col g6">
                    <span className="t-label muted">Distribución de las respuestas ({def.answerUnit})</span>
                    <div className="bars" role="img" aria-label="Distribución de las respuestas">
                      {mass.distribution.map((d, i) => <div key={i} style={{ height: `${(d.count / maxCount) * 100}%` }} title={`${num(d.from)}–${num(d.to)}: ${d.count}`} />)}
                    </div>
                    <div className="row between t-label muted"><span>{num(mass.extremes.min)}</span><span>{num(mass.extremes.max)}</span></div>
                  </div>
                )}
              </>
            )}
          </section>
        )}
        {rows && rows.length > 0 && (
          <div className="tblwrap">
            <table className="tbl" aria-label="Muestra de variantes">
              <thead><tr><th>Nivel</th>{cols.map((c) => <th key={c}>{c}</th>)}<th>Respuesta</th><th>Doble cálculo</th><th>Errores previsibles</th><th>Enunciado y pasos</th></tr></thead>
              <tbody>{rows.map((r) => (
                <tr key={r.id} data-testid="variant-row">
                  <td className="mono">{r.level}</td>
                  {cols.map((c) => { const a = r.assignment[c]; return <td key={c} className="mono" data-col={c}>{a ? (a.text ?? qty(a.value, a.unit)) : '—'}</td>; })}
                  <td className="num b" data-col="respuesta">{qty(r.answer, r.unit)}</td>
                  <td>{r.doubleCheck.ok ? <span className="chip chip-success">Coincide</span> : <span className="chip chip-error">No coincide</span>}{r.collision && <span className="chip chip-error">Colisión</span>}</td>
                  <td className="t-small" data-col="errores">{r.predicted.map((p, i) => <div key={i}>{qty(p.value, p.unit)} · {p.code} · {p.message}</div>)}</td>
                  <td className="t-small"><details><summary>{r.statement.slice(0, 60)}…</summary><p>{r.statement} {r.question}</p><ol>{r.steps.map((s) => <li key={s.n}>{s.text}: {s.operation} = {qty(s.result.value, s.result.unit)}</li>)}</ol></details></td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </div>
    </Panel>
  );
}
