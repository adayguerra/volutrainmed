/**
 * B12 · Creador de tipos de ejercicio por bloques (exercise-type-builder).
 * Cada paso combina bloques de presentación, un bloque de respuesta y una regla
 * de corrección. Todo se añade y se ordena con botones (sin arrastrar). La
 * compatibilidad con voz se calcula sola y se muestra qué porcentaje de los
 * dispositivos activos admite la versión mínima de la app.
 */
import { useEffect, useState } from 'react';
import { VOICE_COMPATIBLE_RESPONSES, type BehaviourBlock, type ExerciseType, type ExerciseTypeStep, type GradingRule, type PresentationBlock, type ResponseBlock } from '@vtm/contracts';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { Async, Field, Icon, Notice, Page, Panel, StateChip, useAction, useAsync } from '../ui/kit';

export const PRESENTATION: Record<PresentationBlock, string> = {
  statement: 'Enunciado', highlighted_data: 'Datos destacados', image: 'Imagen', operation_with_gaps: 'Operación con huecos', step_list: 'Lista de pasos', worked_calculation: 'Cálculo resuelto', timer: 'Temporizador',
};
export const RESPONSE: Record<ResponseBlock, string> = {
  numeric_unit: 'Numérica con unidad', single_choice: 'Selección única', multiple_choice: 'Selección múltiple', ordering: 'Ordenar', matching: 'Emparejar', fill_gaps: 'Rellenar huecos',
  yes_no: 'Sí o no', range_choice: 'Selección única · franjas', conversion_series: 'Serie de conversiones', step_pick: 'Señalar un paso',
};
export const GRADING: Record<GradingRule, string> = { numeric_tolerance: 'Numérica con tolerancia', exact_match: 'Coincidencia exacta', order_equivalences: 'Orden con equivalencias', pair_set: 'Conjunto de pares' };
export const BEHAVIOUR: Record<BehaviourBlock, string> = { hints: 'Pistas', time_limit: 'Tiempo límite', scoring: 'Puntuación', second_try: 'Segundo intento' };

const DEFAULT_GRADING: Partial<Record<ResponseBlock, GradingRule>> = { numeric_unit: 'numeric_tolerance', conversion_series: 'numeric_tolerance', ordering: 'order_equivalences', matching: 'pair_set' };

interface TypeRow { id: string; version: number; state: string; data: ExerciseType; usage: number; publishedUsage: number }
type Draft = Omit<ExerciseType, 'steps'> & { steps: (Omit<ExerciseTypeStep, 'response' | 'grading'> & { response: ResponseBlock | ''; grading: GradingRule | '' })[] };

function emptyType(): Draft {
  return { id: '', version: 1, name: '', description: '', steps: [{ presentation: ['statement'], response: '', grading: '' }], behaviour: ['scoring'], voiceCompatible: false, minAppVersion: '1.0.0' };
}

function moveIn<T>(arr: T[], i: number, d: -1 | 1): T[] {
  const j = i + d;
  if (j < 0 || j >= arr.length) return arr;
  const next = [...arr];
  [next[i], next[j]] = [next[j]!, next[i]!];
  return next;
}

export function stepProblems(t: Draft): string[] {
  const out: string[] = [];
  if (!t.steps.length) out.push('El tipo necesita al menos un paso');
  t.steps.forEach((s, i) => { if (!s.response) out.push(`Paso ${i + 1}: falta el bloque de respuesta`); });
  return out;
}

export function voiceOk(t: Draft): boolean {
  return t.steps.length > 0 && t.steps.every((s) => s.response && VOICE_COMPATIBLE_RESPONSES.includes(s.response));
}

function TypeEditor({ initial, row, editable, onSaved }: { initial: Draft; row: TypeRow | null; editable: boolean; onSaved: (id: string) => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [t, setT] = useState<Draft>(initial);
  const [sel, setSel] = useState(0);
  const [compat, setCompat] = useState<{ pct: number; compatible: number; total: number } | null>(null);
  useEffect(() => {
    let alive = true;
    api.get<{ pct: number; compatible: number; total: number }>('/v1/admin/releases/compat', { minAppVersion: t.minAppVersion }).then((c) => { if (alive) setCompat(c); }).catch(() => setCompat(null));
    return () => { alive = false; };
  }, [api, t.minAppVersion]);
  const problems = stepProblems(t);
  const voice = voiceOk(t);
  const setStep = (i: number, p: Partial<Draft['steps'][number]>) => setT((x) => ({ ...x, steps: x.steps.map((s, j) => (j === i ? { ...s, ...p } : s)) }));
  const step = t.steps[sel];

  async function save() {
    const body = { ...t, voiceCompatible: voice, id: t.id || undefined } as unknown as ExerciseType;
    const r = row
      ? await run(() => api.put<{ item: { id: string; version: number } }>(`/v1/admin/exercise-types/${row.id}`, body), (x) => (x.item.version > row.version ? `Creada la versión ${x.item.version} del tipo; el contenido publicado sigue con la versión ${row.version}` : 'Tipo guardado'))
      : await run(() => api.post<{ item: { id: string } }>('/v1/admin/exercise-types', body), 'Tipo creado: ya está disponible para crear preguntas y plantillas');
    if (r) onSaved(r.item.id);
  }

  return (
    <div className="split">
      <div className="col g16" style={{ minWidth: 0 }}>
        <Panel title={row ? `${row.id} · ${t.name}` : 'Nuevo tipo'} icon="grid_view" actions={row ? <><StateChip state={row.state} /><span className="chip chip-line mono">v{row.version}</span></> : undefined}>
          <fieldset className="col g16" disabled={!editable} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
            <div className="grid2">
              {!row && <Field label="Identificador" id="et-id" help="Por ejemplo T4 o T8. Vacío para generarlo."><input id="et-id" className="input mono" value={t.id} onChange={(e) => setT({ ...t, id: e.target.value.trim() })} /></Field>}
              <Field label="Nombre del tipo" id="et-name"><input id="et-name" className="input" value={t.name} onChange={(e) => setT({ ...t, name: e.target.value })} /></Field>
              <Field label="Descripción" id="et-desc"><input id="et-desc" className="input" value={t.description} onChange={(e) => setT({ ...t, description: e.target.value })} /></Field>
              <Field label="Versión mínima de la app" id="et-min"><input id="et-min" className="input mono" value={t.minAppVersion} onChange={(e) => setT({ ...t, minAppVersion: e.target.value })} /></Field>
            </div>
            {row && row.publishedUsage > 0 && (
              <Notice kind="warn">Este tipo está en uso: {row.publishedUsage} preguntas o plantillas publicadas. Al guardar se crea la versión {row.version + 1} y el contenido publicado sigue usando la versión {row.version}.</Notice>
            )}
            <ol className="col g12" aria-label="Pasos del tipo">
              {t.steps.map((s, i) => (
                <li key={i} className={`card col g8${sel === i ? ' card-sel' : ''}`}>
                  <div className="row g8 wrap">
                    <button type="button" className="link grow" style={{ background: 'none', border: 0, textAlign: 'left', padding: 0, cursor: 'pointer' }} onClick={() => setSel(i)} aria-pressed={sel === i}>Paso {i + 1}</button>
                    <button type="button" className="iconbtn iconbtn-sm" aria-label={`Subir el paso ${i + 1}`} disabled={i === 0} onClick={() => { setT({ ...t, steps: moveIn(t.steps, i, -1) }); setSel(Math.max(0, i - 1)); }}><Icon name="arrow_upward" /></button>
                    <button type="button" className="iconbtn iconbtn-sm" aria-label={`Bajar el paso ${i + 1}`} disabled={i === t.steps.length - 1} onClick={() => { setT({ ...t, steps: moveIn(t.steps, i, 1) }); setSel(Math.min(t.steps.length - 1, i + 1)); }}><Icon name="arrow_downward" /></button>
                    <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar el paso ${i + 1}`} onClick={() => { setT({ ...t, steps: t.steps.filter((_, j) => j !== i) }); setSel(0); }}><Icon name="delete" /></button>
                  </div>
                  <div className="col g6">
                    <span className="t-label muted">Presentación</span>
                    <ul className="row g6 wrap" aria-label={`Presentación del paso ${i + 1}`}>
                      {s.presentation.map((p, k) => (
                        <li key={`${p}-${k}`} className="chip chip-line" data-block={PRESENTATION[p]}>
                          {PRESENTATION[p]}
                          <button type="button" className="iconbtn" style={{ width: 22, height: 22 }} aria-label={`Mover antes ${PRESENTATION[p]} en el paso ${i + 1}`} disabled={k === 0} onClick={() => setStep(i, { presentation: moveIn(s.presentation, k, -1) })}><Icon name="chevron_left" size={16} /></button>
                          <button type="button" className="iconbtn" style={{ width: 22, height: 22 }} aria-label={`Mover después ${PRESENTATION[p]} en el paso ${i + 1}`} disabled={k === s.presentation.length - 1} onClick={() => setStep(i, { presentation: moveIn(s.presentation, k, 1) })}><Icon name="chevron_right" size={16} /></button>
                          <button type="button" className="iconbtn" style={{ width: 22, height: 22 }} aria-label={`Quitar ${PRESENTATION[p]} del paso ${i + 1}`} onClick={() => setStep(i, { presentation: s.presentation.filter((_, j) => j !== k) })}><Icon name="close" size={16} /></button>
                        </li>
                      ))}
                    </ul>
                  </div>
                  <div className="grid2">
                    <Field label={`Respuesta del paso ${i + 1}`} id={`et-r-${i}`}>
                      <select id={`et-r-${i}`} className="input input-sm" value={s.response} onChange={(e) => { const r = e.target.value as ResponseBlock | ''; setStep(i, { response: r, grading: s.grading || (r ? DEFAULT_GRADING[r] ?? 'exact_match' : '') }); }}>
                        <option value="">Sin bloque de respuesta</option>{(Object.keys(RESPONSE) as ResponseBlock[]).map((r) => <option key={r} value={r}>{RESPONSE[r]}</option>)}
                      </select>
                    </Field>
                    <Field label={`Corrección del paso ${i + 1}`} id={`et-g-${i}`}>
                      <select id={`et-g-${i}`} className="input input-sm" value={s.grading} onChange={(e) => setStep(i, { grading: e.target.value as GradingRule })}>
                        <option value="">—</option>{(Object.keys(GRADING) as GradingRule[]).map((g) => <option key={g} value={g}>{GRADING[g]}</option>)}
                      </select>
                    </Field>
                  </div>
                  {!s.response && <span className="err-msg" role="alert"><Icon name="error" size={16} />Paso {i + 1}: falta el bloque de respuesta</span>}
                </li>
              ))}
            </ol>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => { setT({ ...t, steps: [...t.steps, { presentation: ['highlighted_data'], response: '', grading: '' }] }); setSel(t.steps.length); }}><Icon name="add" />Añadir paso</button>
            <fieldset className="col g6" style={{ border: 0, padding: 0, margin: 0 }}>
              <legend className="flabel">Comportamiento</legend>
              <div className="row g12 wrap">
                {(Object.keys(BEHAVIOUR) as BehaviourBlock[]).map((b) => (
                  <label key={b} className="check-row t-small"><input type="checkbox" checked={t.behaviour.includes(b)} onChange={(e) => setT({ ...t, behaviour: e.target.checked ? [...t.behaviour, b] : t.behaviour.filter((x) => x !== b) })} />{BEHAVIOUR[b]}</label>
                ))}
              </div>
              {t.behaviour.includes('time_limit') && <Field label="Tiempo límite (s)" id="et-tl"><input id="et-tl" className="input input-sm mono" type="number" value={t.timeLimitS ?? 15} onChange={(e) => setT({ ...t, timeLimitS: Number(e.target.value) })} /></Field>}
            </fieldset>
          </fieldset>
          {editable && (
            <div className="row g8 wrap" style={{ marginTop: 16 }}>
              <button type="button" className="btn btn-primary btn-sm" disabled={busy || problems.length > 0 || !t.name.trim()} onClick={save}><Icon name="save" />{row ? 'Guardar tipo' : 'Crear tipo'}</button>
              {problems.length > 0 && <span className="t-small c-error">{problems.join(' · ')}</span>}
            </div>
          )}
        </Panel>
      </div>
      <div className="col g16">
        {editable && step && (
          <Panel title={`Bloques · paso ${sel + 1}`} icon="widgets">
            <div className="col g8">
              <span className="t-label muted">Presentación</span>
              <div className="row g6 wrap">
                {(Object.keys(PRESENTATION) as PresentationBlock[]).map((p) => <button key={p} type="button" className="btn btn-secondary btn-xs" onClick={() => setStep(sel, { presentation: [...step.presentation, p] })}>{PRESENTATION[p]}</button>)}
              </div>
              <span className="t-label muted">Respuesta</span>
              <div className="row g6 wrap">
                {(Object.keys(RESPONSE) as ResponseBlock[]).map((r) => <button key={r} type="button" className="btn btn-secondary btn-xs" aria-pressed={step.response === r} onClick={() => setStep(sel, { response: r, grading: DEFAULT_GRADING[r] ?? 'exact_match' })}>{RESPONSE[r]}</button>)}
              </div>
            </div>
          </Panel>
        )}
        <Panel title="Propiedades" icon="info">
          <div className="col g10">
            {voice
              ? <Notice kind="ok" icon="record_voice_over">Compatible con voz: todos los bloques de respuesta lo son.</Notice>
              : <Notice kind="warn" icon="voice_over_off">No compatible con voz: {t.steps.filter((s) => s.response && !VOICE_COMPATIBLE_RESPONSES.includes(s.response)).map((s) => RESPONSE[s.response as ResponseBlock]).join(', ') || 'falta algún bloque de respuesta'}. Sus ejercicios no entran en las sesiones manos libres.</Notice>}
            <p className="t-small" data-testid="compat">Versión mínima de la app: <strong className="mono">{t.minAppVersion}</strong>.{compat ? <> La admite el <strong>{compat.pct} %</strong> de los dispositivos activos ({compat.compatible} de {compat.total}); las versiones anteriores no muestran este contenido.</> : null}</p>
          </div>
        </Panel>
      </div>
    </div>
  );
}

export function ExerciseTypes() {
  const { api, account } = useSession();
  const editable = can(account?.role, 'editTypes');
  const list = useAsync(() => api.get<{ items: TypeRow[] }>('/v1/admin/exercise-types'), [api]);
  const [selected, setSelected] = useState<string | 'new' | null>(null);
  const row = list.data?.items.find((r) => r.id === selected) ?? null;
  const initial: Draft | null = selected === 'new' ? emptyType() : row ? (row.data as Draft) : null;
  return (
    <Page title="Tipos de ejercicio" crumbs={[{ label: 'Contenido' }, { label: 'Tipos de ejercicio' }]}
      actions={editable ? <button type="button" className="btn btn-primary btn-sm" onClick={() => setSelected('new')}><Icon name="add" />Nuevo tipo</button> : undefined}>
      <Async state={list}>
        {(d) => (
          <>
            <Panel bodyClass="tblwrap">
              <table className="tbl" aria-label="Tipos de ejercicio">
                <thead><tr><th>Tipo</th><th>Nombre</th><th>Pasos</th><th>Voz</th><th>Versión mínima</th><th className="num">En uso</th><th className="num">Publicados</th><th>Estado</th></tr></thead>
                <tbody>{d.items.map((r) => (
                  <tr key={r.id} className={`clickable${selected === r.id ? ' sel' : ''}`} onClick={() => setSelected(r.id)}>
                    <td className="mono b"><button type="button" className="link" style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer' }} onClick={() => setSelected(r.id)}>{r.id}</button></td>
                    <td>{r.data.name}</td>
                    <td className="t-small">{r.data.steps.map((s) => RESPONSE[s.response] ?? s.response).join(' → ')}</td>
                    <td>{r.data.voiceCompatible ? <span className="chip chip-success">Sí</span> : <span className="chip">No</span>}</td>
                    <td className="mono">{r.data.minAppVersion}</td>
                    <td className="num">{r.usage}</td>
                    <td className="num">{r.publishedUsage}</td>
                    <td><StateChip state={r.state} /> <span className="mono t-small">v{r.version}</span></td>
                  </tr>
                ))}</tbody>
              </table>
            </Panel>
            {initial && <TypeEditor key={selected ?? ''} initial={initial} row={selected === 'new' ? null : row} editable={editable} onSaved={(id) => { list.reload(); setSelected(id); }} />}
          </>
        )}
      </Async>
    </Page>
  );
}
