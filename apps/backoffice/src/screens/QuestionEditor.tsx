/**
 * B10 · Editor de preguntas fijas (sin variantes) para cualquier tipo de
 * ejercicio: respuesta, opciones con el tipo de error de cada opción falsa,
 * pasos que ordenar, conversiones, explicación paso a paso, texto para voz,
 * insertador de cantidades y comprobaciones automáticas antes de enviar.
 */
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { resolveQuestion, validateQuestion, type QuestionDefinition } from '@vtm/engine';
import { ERROR_LABELS, type ErrorCode } from '@vtm/contracts';
import type { Item, ItemDetail } from '../api/types';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { BUILTIN_TYPES, DEFAULT_SECTORS, ERROR_CODES, SKILLS, loadSectors, loadSkills, loadTypes } from '../content/common';
import { ExercisePreview, type Device } from '../content/ExercisePreview';
import { ErrorBox, Field, Icon, Loading, Notice, Page, Panel, StateChip, useAction, useAsync } from '../ui/kit';

type Q = QuestionDefinition;
type Opt = NonNullable<Q['options']>[number];

export function newQuestion(type = 'T2'): Q {
  return {
    id: '', version: 1, name: '', exerciseTypeId: type, sectorId: 'comun', skillId: 'H2', level: 2, targetTimeS: 20, statement: '', question: '', tts: null,
    options: type === 'T2' || type === 'T6' ? [{ label: '', correct: true }, { label: '', correct: false, errorCode: 'E2' }, { label: '', correct: false, errorCode: 'E2' }] as Opt[] : undefined,
    answer: type === 'T1' ? { value: '', unit: 'ml', unitFixed: true, unitChoices: ['ml'], equivalents: [], rounding: { mode: 'none' }, tolerance: { kind: 'exact' } } : undefined,
    steps: [], plausibility: '',
  };
}

const UNITS = ['mg', 'µg', 'g', 'kg', 'ml', 'l', 'UI', '%', 'mg/kg', 'µg/kg', 'mg/ml', 'µg/ml', 'UI/ml', 'ml/h', 'gotas/min', 'µg/kg/min', 'h', 'min'];

function OptionsEditor({ q, set }: { q: Q; set: (fn: (q: Q) => Q) => void }) {
  const opts = q.options ?? [];
  const upd = (i: number, p: Partial<Opt>) => set((x) => ({ ...x, options: (x.options ?? []).map((o, j) => (j === i ? { ...o, ...p } : o)) }));
  return (
    <fieldset className="col g8" style={{ border: 0, padding: 0, margin: 0 }}>
      <legend className="flabel" style={{ marginBottom: 6 }}>Opciones y código de error de cada opción falsa</legend>
      {opts.map((o, i) => (
        <div key={i} className="row g8 wrap card" style={{ padding: 10 }}>
          <span className="ui b" style={{ width: 20 }}>{String.fromCharCode(65 + i)}</span>
          <input aria-label={`Opción ${String.fromCharCode(65 + i)}`} className="input input-sm mono" style={{ flex: '1 1 140px' }} value={o.label} onChange={(e) => upd(i, { label: e.target.value })} />
          <label className="check-row t-small"><input type="radio" name="correct" aria-label={`La opción ${String.fromCharCode(65 + i)} es la correcta`} checked={o.correct} onChange={() => set((x) => ({ ...x, options: (x.options ?? []).map((y, j) => ({ ...y, correct: j === i, errorCode: j === i ? undefined : (y.errorCode ?? 'E0') })) }))} />Correcta</label>
          {!o.correct && (
            <select aria-label={`Tipo de error de la opción ${String.fromCharCode(65 + i)}`} className="input input-sm" style={{ width: 'auto' }} value={o.errorCode ?? ''} onChange={(e) => upd(i, { errorCode: (e.target.value || undefined) as ErrorCode | undefined })}>
              <option value="">Sin tipo de error</option>{ERROR_CODES.map((c) => <option key={c} value={c}>{c} · {ERROR_LABELS[c]}</option>)}
            </select>
          )}
          {!o.correct && <input aria-label={`Diagnóstico de la opción ${String.fromCharCode(65 + i)}`} placeholder="Diagnóstico en una frase" className="input input-sm" style={{ flex: '2 1 200px' }} value={o.message ?? ''} onChange={(e) => upd(i, { message: e.target.value })} />}
          <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar la opción ${String.fromCharCode(65 + i)}`} onClick={() => set((x) => ({ ...x, options: (x.options ?? []).filter((_, j) => j !== i) }))}><Icon name="delete" /></button>
        </div>
      ))}
      {opts.length < 4 && <button type="button" className="btn btn-secondary btn-xs" onClick={() => set((x) => ({ ...x, options: [...(x.options ?? []), { label: '', correct: false, errorCode: 'E0' } as Opt] }))}><Icon name="add" />Añadir opción</button>}
    </fieldset>
  );
}

export function QuestionEditor() {
  const { id } = useParams();
  const isNew = !id || id === 'nueva';
  const { api, account } = useSession();
  const navigate = useNavigate();
  const detail = useAsync(() => (isNew ? Promise.resolve(null) : api.get<ItemDetail<Q>>(`/v1/admin/items/${id}`)), [api, id]);
  const sectors = useAsync(() => loadSectors(api), [api]);
  const types = useAsync(() => loadTypes(api), [api]);
  const skills = useAsync(() => loadSkills(api), [api]);
  const others = useAsync(() => api.get<{ items: Item<Q>[] }>('/v1/admin/items', { kind: 'question' }).then((r) => r.items).catch(() => [] as Item<Q>[]), [api]);
  const [q, setQ] = useState<Q>(() => newQuestion());
  const [dirty, setDirty] = useState(false);
  const [loadedFrom, setLoadedFrom] = useState<unknown>(null);
  const [device, setDevice] = useState<Device>('phone');
  const [dark, setDark] = useState(false);
  const [insVal, setInsVal] = useState('');
  const [insUnit, setInsUnit] = useState('mg');
  const [serverIssue, setServerIssue] = useState<string | null>(null);
  const { run, busy } = useAction();
  if (detail.data && loadedFrom !== detail.data) {
    setLoadedFrom(detail.data);
    setQ({ ...newQuestion(detail.data.item.data.exerciseTypeId), ...detail.data.item.data });
    setDirty(false);
  }
  const set = (fn: (q: Q) => Q) => { setQ(fn); setDirty(true); setServerIssue(null); };
  const item = detail.data?.item;
  const editable = isNew ? can(account?.role, 'createContent') : Boolean(detail.data?.canEdit) && item?.state !== 'retired';
  const existing = (others.data ?? []).filter((o) => o.id !== id).map((o) => String(o.data.statement ?? ''));
  const issues = useMemo(() => validateQuestion(q, existing), [q, existing.join('|')]);
  const variant = useMemo(() => { try { return resolveQuestion({ ...q, id: q.id || 'nueva' }); } catch { return null; } }, [q]);
  const has = (field: string, re?: RegExp) => issues.some((i) => i.field === field && i.blocking && (!re || re.test(i.message)));
  const checks = [
    { label: 'Campos obligatorios', ok: !has('statement', /Falta el enunciado/) && !has('answer') && !has('options') && !has('orderItems') && !has('series') && q.question.trim() !== '' },
    { label: 'Cantidades con unidad', ok: !has('statement', /Cantidad sin unidad/), detail: issues.find((i) => /Cantidad sin unidad/.test(i.message))?.message },
    { label: 'Explicación presente', ok: !has('steps') },
    { label: 'Texto para voz presente', ok: !has('tts') },
    { label: 'Sin sugerencia de uso clínico', ok: !issues.some((i) => /uso clínico/.test(i.message)) },
  ];
  const dup = issues.find((i) => !i.blocking);
  const blocking = issues.filter((i) => i.blocking);

  function changeType(t: string) {
    set((x) => ({ ...newQuestion(t), ...x, exerciseTypeId: t, options: ['T2', 'T6'].includes(t) ? (x.options ?? newQuestion(t).options) : undefined, answer: t === 'T1' ? (x.answer ?? newQuestion('T1').answer) : x.answer, orderItems: t === 'T3' ? (x.orderItems ?? []) : undefined, series: t === 'T7' ? (x.series ?? []) : undefined }));
  }

  async function save(): Promise<boolean> {
    const { id: _o, ...data } = q;
    void _o;
    const clean = { ...data, name: data.name || data.question.slice(0, 60) || 'Pregunta', validOrders: q.exerciseTypeId === 'T3' ? [(q.orderItems ?? []).map((o) => o.id)] : q.validOrders };
    if (isNew) {
      const r = await run(() => api.post<{ item: Item }>('/v1/admin/items', { kind: 'question', data: clean }), 'Pregunta creada en borrador');
      if (r) { setDirty(false); navigate(`/preguntas/${r.item.id}`, { replace: true }); return true; }
      return false;
    }
    const r = await run(() => api.put<{ item: Item }>(`/v1/admin/items/${id}`, { data: { ...clean, id } }), (x) => (item && x.item.version > item.version ? `Creada la versión ${x.item.version} en borrador` : 'Borrador guardado'));
    if (r) { setDirty(false); detail.reload(); return true; }
    return false;
  }

  async function submit() {
    if (dirty && !(await save())) return;
    try { await api.post(`/v1/admin/items/${id}/submit`); detail.reload(); await run(async () => undefined, 'Enviada a revisión'); } catch (e) { setServerIssue((e as Error).message); }
  }

  if (!isNew && detail.loading && !detail.data) return <Page title="Pregunta"><Loading /></Page>;
  if (detail.error) return <Page title="Pregunta"><ErrorBox error={detail.error} onRetry={detail.reload} /></Page>;
  const t = q.exerciseTypeId;

  return (
    <Page title={q.name || q.question || 'Nueva pregunta'} crumbs={[{ label: 'Biblioteca', to: '/biblioteca' }, { label: 'Preguntas' }]}
      chip={item ? <><StateChip state={item.state} /><span className="chip chip-line mono">v{item.version}</span></> : <span className="chip">Borrador</span>}
      actions={editable ? (
        <>
          {!isNew && <Link className="btn btn-tertiary btn-sm" to={`/vista-previa/${id}`}><Icon name="record_voice_over" />Vista previa con voz</Link>}
          <button type="button" className="btn btn-secondary btn-sm" disabled={!dirty || busy || !q.statement.trim()} onClick={save}><Icon name="save" />Guardar borrador</button>
          {!isNew && <button type="button" className="btn btn-primary btn-sm" disabled={busy || blocking.length > 0 || !item || !['draft', 'changes_requested'].includes(item.state)} onClick={submit}><Icon name="send" />Enviar a revisión</button>}
        </>
      ) : !isNew ? <Link className="btn btn-tertiary btn-sm" to={`/vista-previa/${id}`}><Icon name="record_voice_over" />Vista previa con voz</Link> : undefined}>
      {!editable && <Notice icon="visibility">Solo lectura: puedes ver la pregunta, no modificarla.</Notice>}
      {serverIssue && <Notice kind="err"><strong>No se puede enviar a revisión:</strong> {serverIssue}</Notice>}
      <div className="split">
        <Panel title="Pregunta" icon="quiz">
          <fieldset className="col g16" disabled={!editable} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
            <div className="grid2">
              <Field label="Tipo de ejercicio" id="q-type"><select id="q-type" className="input" value={t} onChange={(e) => changeType(e.target.value)}>{(types.data ?? BUILTIN_TYPES).map((x) => <option key={x.id} value={x.id}>{x.id} · {x.name}</option>)}</select></Field>
              <Field label="Sector" id="q-sector"><select id="q-sector" className="input" value={q.sectorId} onChange={(e) => set((x) => ({ ...x, sectorId: e.target.value }))}>{(sectors.data ?? DEFAULT_SECTORS).map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
              <Field label="Habilidad" id="q-skill"><select id="q-skill" className="input" value={q.skillId} onChange={(e) => set((x) => ({ ...x, skillId: e.target.value as Q['skillId'] }))}>{(skills.data ?? SKILLS).map((s) => <option key={s.id} value={s.id}>{s.id} · {s.name}</option>)}</select></Field>
              <Field label="Nombre" id="q-name"><input id="q-name" className="input" value={q.name} onChange={(e) => set((x) => ({ ...x, name: e.target.value }))} /></Field>
            </div>
            <Field label="Enunciado" id="q-statement" help="Inserta las cantidades con su unidad: la app las resalta y la voz las lee.">
              <textarea id="q-statement" className="input" value={q.statement} onChange={(e) => set((x) => ({ ...x, statement: e.target.value }))} />
            </Field>
            <div className="row g6 wrap" aria-label="Insertar una cantidad">
              <input aria-label="Cifra de la cantidad" className="input input-sm mono" style={{ width: 100 }} value={insVal} onChange={(e) => setInsVal(e.target.value.replace('.', ','))} />
              <select aria-label="Unidad de la cantidad" className="input input-sm" style={{ width: 'auto' }} value={insUnit} onChange={(e) => setInsUnit(e.target.value)}>{UNITS.map((u) => <option key={u}>{u}</option>)}</select>
              <button type="button" className="btn btn-secondary btn-xs" disabled={!insVal} onClick={() => { set((x) => ({ ...x, statement: `${x.statement}${x.statement && !x.statement.endsWith(' ') ? ' ' : ''}${insVal}${insUnit === '%' ? ' %' : ` ${insUnit}`}` })); setInsVal(''); }}><Icon name="add" />Insertar cantidad</button>
            </div>
            <Field label="Pregunta" id="q-question"><input id="q-question" className="input" value={q.question} onChange={(e) => set((x) => ({ ...x, question: e.target.value }))} /></Field>
            {t === 'T1' && q.answer && (
              <div className="grid3">
                <Field label="Respuesta correcta" id="q-ans"><input id="q-ans" className="input mono" value={q.answer.value.replace('.', ',')} onChange={(e) => set((x) => ({ ...x, answer: { ...x.answer!, value: e.target.value.replace(',', '.') } }))} /></Field>
                <Field label="Unidad de la respuesta" id="q-ansu"><input id="q-ansu" className="input mono" value={q.answer.unit} onChange={(e) => set((x) => ({ ...x, answer: { ...x.answer!, unit: e.target.value, unitChoices: [e.target.value] } }))} /></Field>
                <Field label="Decimales" id="q-dec"><input id="q-dec" className="input mono" type="number" min={0} max={4} value={q.answer.rounding.mode === 'decimals' ? q.answer.rounding.places : ''} onChange={(e) => set((x) => ({ ...x, answer: { ...x.answer!, rounding: e.target.value === '' ? { mode: 'none' } : { mode: 'decimals', places: Number(e.target.value) } } }))} /></Field>
              </div>
            )}
            {(t === 'T2' || t === 'T6') && <OptionsEditor q={q} set={set} />}
            {t === 'T3' && (
              <fieldset className="col g8" style={{ border: 0, padding: 0, margin: 0 }}>
                <legend className="flabel">Pasos en el orden correcto</legend>
                {(q.orderItems ?? []).map((o, i) => (
                  <div key={o.id} className="row g6"><span className="mono">{i + 1}.</span>
                    <input aria-label={`Paso ${i + 1} para ordenar`} className="input input-sm" value={o.text} onChange={(e) => set((x) => ({ ...x, orderItems: (x.orderItems ?? []).map((y, j) => (j === i ? { ...y, text: e.target.value } : y)) }))} />
                    <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar el paso ${i + 1}`} onClick={() => set((x) => ({ ...x, orderItems: (x.orderItems ?? []).filter((_, j) => j !== i) }))}><Icon name="delete" /></button>
                  </div>
                ))}
                <button type="button" className="btn btn-secondary btn-xs" onClick={() => set((x) => ({ ...x, orderItems: [...(x.orderItems ?? []), { id: `s${(x.orderItems?.length ?? 0) + 1}`, text: '' }] }))}><Icon name="add" />Añadir paso</button>
              </fieldset>
            )}
            {t === 'T7' && (
              <fieldset className="col g6" style={{ border: 0, padding: 0, margin: 0 }}>
                <legend className="flabel">Diez conversiones</legend>
                {(q.series ?? []).map((s, i) => (
                  <div key={i} className="row g6">
                    <input aria-label={`Conversión ${i + 1}`} className="input input-sm" value={s.prompt} onChange={(e) => set((x) => ({ ...x, series: (x.series ?? []).map((y, j) => (j === i ? { ...y, prompt: e.target.value } : y)) }))} />
                    <input aria-label={`Resultado de la conversión ${i + 1}`} className="input input-sm mono" style={{ width: 90 }} value={s.value} onChange={(e) => set((x) => ({ ...x, series: (x.series ?? []).map((y, j) => (j === i ? { ...y, value: e.target.value.replace(',', '.') } : y)) }))} />
                    <input aria-label={`Unidad de la conversión ${i + 1}`} className="input input-sm mono" style={{ width: 80 }} value={s.unit} onChange={(e) => set((x) => ({ ...x, series: (x.series ?? []).map((y, j) => (j === i ? { ...y, unit: e.target.value } : y)) }))} />
                  </div>
                ))}
                {(q.series?.length ?? 0) < 10 && <button type="button" className="btn btn-secondary btn-xs" onClick={() => set((x) => ({ ...x, series: [...(x.series ?? []), { prompt: '', value: '', unit: 'mg' }] }))}><Icon name="add" />Añadir conversión</button>}
              </fieldset>
            )}
            <fieldset className="col g8" style={{ border: 0, padding: 0, margin: 0 }}>
              <legend className="flabel" style={{ marginBottom: 6 }}>Explicación paso a paso</legend>
              {q.steps.map((s, i) => (
                <div key={i} className="row g6 wrap">
                  <span className="mono">{i + 1}.</span>
                  <input aria-label={`Texto del paso ${i + 1}`} className="input input-sm" style={{ flex: '2 1 200px' }} value={s.text} onChange={(e) => set((x) => ({ ...x, steps: x.steps.map((y, j) => (j === i ? { ...y, text: e.target.value, operation: y.operation || e.target.value } : y)) }))} />
                  <input aria-label={`Resultado del paso ${i + 1}`} className="input input-sm mono" style={{ width: 90 }} value={s.result.value} onChange={(e) => set((x) => ({ ...x, steps: x.steps.map((y, j) => (j === i ? { ...y, result: { ...y.result, value: e.target.value.replace(',', '.') } } : y)) }))} />
                  <input aria-label={`Unidad del resultado del paso ${i + 1}`} className="input input-sm mono" style={{ width: 90 }} value={s.result.unit} onChange={(e) => set((x) => ({ ...x, steps: x.steps.map((y, j) => (j === i ? { ...y, result: { ...y.result, unit: e.target.value } } : y)) }))} />
                  <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar el paso ${i + 1} de la explicación`} onClick={() => set((x) => ({ ...x, steps: x.steps.filter((_, j) => j !== i).map((y, k) => ({ ...y, n: k + 1 })) }))}><Icon name="delete" /></button>
                </div>
              ))}
              <button type="button" className="btn btn-secondary btn-xs" onClick={() => set((x) => ({ ...x, steps: [...x.steps, { n: x.steps.length + 1, text: '', operation: '', result: { value: '0', unit: '' }, cancelled: [] }] }))}><Icon name="add" />Añadir paso de la explicación</button>
            </fieldset>
            <Field label="Texto para voz" id="q-tts" help="Si lo dejas vacío se genera con el normalizador de lectura de la app.">
              <textarea id="q-tts" className="input" value={q.tts ?? ''} onChange={(e) => set((x) => ({ ...x, tts: e.target.value || null }))} placeholder={variant?.tts} />
            </Field>
            <div className="grid2">
              <Field label="Dificultad" id="q-level"><select id="q-level" className="input" value={q.level} onChange={(e) => set((x) => ({ ...x, level: Number(e.target.value) as Q['level'] }))}>{[1, 2, 3, 4, 5].map((l) => <option key={l}>{l}</option>)}</select></Field>
              <Field label="Tiempo objetivo (s)" id="q-time"><input id="q-time" className="input mono" type="number" value={q.targetTimeS} onChange={(e) => set((x) => ({ ...x, targetTimeS: Number(e.target.value) }))} /></Field>
            </div>
            <Field label="Comprobación de plausibilidad" id="q-plaus"><input id="q-plaus" className="input" value={q.plausibility} onChange={(e) => set((x) => ({ ...x, plausibility: e.target.value }))} /></Field>
          </fieldset>
        </Panel>
        <div className="col g16">
          <Panel title="Vista previa" icon="smartphone" actions={
            <div className="row g6">
              <div className="segctl" role="group" aria-label="Dispositivo"><button type="button" className={device === 'phone' ? 'on' : ''} aria-pressed={device === 'phone'} onClick={() => setDevice('phone')}>Móvil</button><button type="button" className={device === 'tablet' ? 'on' : ''} aria-pressed={device === 'tablet'} onClick={() => setDevice('tablet')}>Tablet</button></div>
              <div className="segctl" role="group" aria-label="Tema"><button type="button" className={!dark ? 'on' : ''} aria-pressed={!dark} onClick={() => setDark(false)}>Claro</button><button type="button" className={dark ? 'on' : ''} aria-pressed={dark} onClick={() => setDark(true)}>Oscuro</button></div>
            </div>
          }>
            {variant ? <div style={{ overflowX: 'auto' }}><ExercisePreview v={variant} device={device} orientation={device === 'tablet' ? 'landscape' : 'portrait'} dark={dark} zoom={device === 'tablet' ? 60 : 85} /></div> : <p className="muted t-small">Completa el enunciado para ver la pregunta.</p>}
          </Panel>
          <Panel title="Comprobaciones al enviar" icon="checklist">
            <ul className="col g6" aria-label="Comprobaciones al enviar">
              {checks.map((c) => <li key={c.label} className={`row g6 t-small ${c.ok ? 'c-success' : 'c-error'}`}><Icon name={c.ok ? 'check_circle' : 'cancel'} size={18} />{c.label}{!c.ok && c.detail ? `: ${c.detail.replace(/^Cantidad sin unidad: /, '')}` : ''}</li>)}
              {dup && <li className="row g6 t-small c-warning"><Icon name="warning" size={18} />{dup.message}</li>}
            </ul>
            {blocking.length > 0 && (
              <ul className="col g4" style={{ marginTop: 10 }} aria-label="Motivos que impiden enviar">
                {blocking.map((b, i) => <li key={i} className="t-small c-error">{b.message}</li>)}
              </ul>
            )}
          </Panel>
        </div>
      </div>
    </Page>
  );
}
