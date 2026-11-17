/**
 * B26 · Catálogos de unidades, instrumentos y voz, y catálogo de anuncios
 * propios. Los catálogos son elementos de contenido: un cambio queda en
 * borrador, pasa por revisión y llega a las apps con la siguiente publicación.
 * El cuadro de prueba interpreta una frase con el mismo analizador que la app.
 */
import { useMemo, useState } from 'react';
import { checkAdCreative, parseSpoken, readUnit } from '@vtm/engine';
import type { AdParams } from '@vtm/contracts';
import type { Item } from '../api/types';
import { useSession } from '../auth/session';
import { DEFAULT_SECTORS, sectorName } from '../content/common';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, StateChip, Tabs, useAction, useAsync } from '../ui/kit';
import { num } from '../ui/format';

interface UnitData { symbol: string; name: string; readingSingular?: string; readingPlural?: string; spokenForms?: string[]; magnitude?: string; factor?: string; gender?: string }
interface InstrumentData { name: string; unit: string; step: string; capacityMl?: string }
interface LexiconData { name: string; confusions: { from: string; to: string }[]; commands: { command: string; synonyms: string[] }[]; sectorSynonyms: { spoken: string; unit: string; sectorId: string; enabledByDefault?: boolean }[] }
interface Creative { name?: string; headline: string; body: string; cta: string; voiceSpot: string | null; weight: number; dailyCap: number | null; context: string; kind: string; campaignId?: string; ctaAction?: string; illustration?: string }
interface Campaign { name: string; sectorIds: string[] | null; startsAt: string | null; endsAt: string | null }

const DRAFT_NOTE = 'El cambio queda en borrador hasta su revisión y llega a las apps con la siguiente publicación.';

function useItems<T>(kind: string) {
  const { api } = useSession();
  return useAsync(() => api.get<{ items: Item<T>[] }>('/v1/admin/items', { kind }).then((r) => r.items), [api, kind]);
}

function SubmitButton({ item, onDone }: { item: Pick<Item<unknown>, 'id' | 'state'>; onDone: () => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  if (!['draft', 'changes_requested'].includes(item.state)) return null;
  return <button type="button" className="btn btn-secondary btn-xs" disabled={busy} onClick={async () => { const r = await run(() => api.post(`/v1/admin/items/${item.id}/submit`), 'Enviado a revisión'); if (r) onDone(); }}>Enviar a revisión</button>;
}

function useSaveItem(kind: string) {
  const { api } = useSession();
  const { run, busy } = useAction();
  return {
    busy,
    save: (item: Pick<Item<unknown>, 'id' | 'version'> | null, data: Record<string, unknown>) => (item
      ? run(() => api.put<{ item: Item }>(`/v1/admin/items/${item.id}`, { data: { ...data, id: item.id } }), (x) => (x.item.version > item.version ? `Creada la versión ${x.item.version} en borrador. ${DRAFT_NOTE}` : `Guardado. ${DRAFT_NOTE}`))
      : run(() => api.post<{ item: Item }>('/v1/admin/items', { kind, data }), `Creado en borrador. ${DRAFT_NOTE}`)),
  };
}

// ------------------------------------------------------------------ Unidades
function UnitsTab() {
  const st = useItems<UnitData>('catalog_unit');
  const { save, busy } = useSaveItem('catalog_unit');
  const [edit, setEdit] = useState<{ item: Item<UnitData> | null; data: UnitData } | null>(null);
  return (
    <Panel title="Unidades de medida" icon="straighten" bodyClass="tblwrap" actions={<button type="button" className="btn btn-primary btn-xs" onClick={() => setEdit({ item: null, data: { symbol: '', name: '', readingSingular: '', readingPlural: '', spokenForms: [], magnitude: '', factor: '' } })}><Icon name="add" />Nueva unidad</button>}>
      <Async state={st}>
        {(items) => (
          <table className="tbl" aria-label="Unidades de medida">
            <thead><tr><th>Símbolo</th><th>Nombre</th><th>Lectura en voz</th><th>Formas habladas aceptadas</th><th>Magnitud</th><th>Factor</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
            <tbody>{items.map((u) => (
              <tr key={u.id}>
                <td className="mono b">{u.data.symbol}</td><td>{u.data.name}</td><td>{u.data.readingPlural}</td>
                <td className="t-small">{(u.data.spokenForms ?? []).map((f) => `«${f}»`).join(', ')}</td><td>{u.data.magnitude}</td><td className="mono">{u.data.factor ? num(u.data.factor) : '—'}</td>
                <td><StateChip state={u.state} /></td>
                <td className="actions"><button type="button" className="btn btn-tertiary btn-xs" onClick={() => setEdit({ item: u, data: u.data })}>Editar</button><SubmitButton item={u} onDone={st.reload} /></td>
              </tr>
            ))}</tbody>
          </table>
        )}
      </Async>
      {edit && (
        <Modal title={edit.item ? `Unidad ${edit.item.data.symbol}` : 'Nueva unidad'} onClose={() => setEdit(null)}>
          <div className="grid2">
            {(['symbol', 'name', 'readingSingular', 'readingPlural', 'magnitude', 'factor'] as const).map((k) => (
              <Field key={k} label={{ symbol: 'Símbolo', name: 'Nombre', readingSingular: 'Lectura en singular', readingPlural: 'Lectura en plural', magnitude: 'Magnitud', factor: 'Factor' }[k]} id={`cu-${k}`}>
                <input id={`cu-${k}`} className="input" value={String(edit.data[k] ?? '')} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, [k]: e.target.value } })} />
              </Field>
            ))}
          </div>
          <Field label="Formas habladas aceptadas (separadas por comas)" id="cu-forms"><input id="cu-forms" className="input" value={(edit.data.spokenForms ?? []).join(', ')} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, spokenForms: e.target.value.split(',').map((x) => x.trim()).filter(Boolean) } })} /></Field>
          <p className="t-small muted">{DRAFT_NOTE}</p>
          <div className="row g8 end"><button type="button" className="btn btn-tertiary btn-sm" onClick={() => setEdit(null)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={busy || !edit.data.symbol} onClick={async () => { const r = await save(edit.item, edit.data as unknown as Record<string, unknown>); if (r) { setEdit(null); st.reload(); } }}>Guardar</button></div>
        </Modal>
      )}
    </Panel>
  );
}

// ------------------------------------------------------------------ Instrumentos
function InstrumentsTab() {
  const st = useItems<InstrumentData>('catalog_instrument');
  const { save, busy } = useSaveItem('catalog_instrument');
  const [edit, setEdit] = useState<{ item: Item<InstrumentData> | null; data: InstrumentData } | null>(null);
  return (
    <Panel title="Instrumentos de medida" icon="vaccines" bodyClass="tblwrap" actions={<button type="button" className="btn btn-primary btn-xs" onClick={() => setEdit({ item: null, data: { name: '', unit: 'ml', step: '0.1', capacityMl: '' } })}><Icon name="add" />Nuevo instrumento</button>}>
      <Async state={st}>
        {(items) => (
          <table className="tbl" aria-label="Instrumentos">
            <thead><tr><th>Instrumento</th><th>Unidad</th><th>División</th><th>Capacidad</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
            <tbody>{items.map((i) => (
              <tr key={i.id}><td>{i.data.name}</td><td className="mono">{i.data.unit}</td><td className="mono">{num(i.data.step)}</td><td className="mono">{i.data.capacityMl ? `${num(i.data.capacityMl)} ml` : '—'}</td><td><StateChip state={i.state} /></td>
                <td className="actions"><button type="button" className="btn btn-tertiary btn-xs" onClick={() => setEdit({ item: i, data: i.data })}>Editar</button><SubmitButton item={i} onDone={st.reload} /></td></tr>
            ))}</tbody>
          </table>
        )}
      </Async>
      {edit && (
        <Modal title={edit.item ? edit.item.data.name : 'Nuevo instrumento'} onClose={() => setEdit(null)}>
          <Field label="Nombre" id="ci-name"><input id="ci-name" className="input" value={edit.data.name} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, name: e.target.value } })} /></Field>
          <div className="grid3">
            <Field label="Unidad" id="ci-unit"><input id="ci-unit" className="input mono" value={edit.data.unit} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, unit: e.target.value } })} /></Field>
            <Field label="División" id="ci-step"><input id="ci-step" className="input mono" value={edit.data.step} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, step: e.target.value.replace(',', '.') } })} /></Field>
            <Field label="Capacidad (ml)" id="ci-cap"><input id="ci-cap" className="input mono" value={edit.data.capacityMl ?? ''} onChange={(e) => setEdit({ ...edit, data: { ...edit.data, capacityMl: e.target.value.replace(',', '.') } })} /></Field>
          </div>
          <div className="row g8 end"><button type="button" className="btn btn-tertiary btn-sm" onClick={() => setEdit(null)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={busy || !edit.data.name} onClick={async () => { const r = await save(edit.item, edit.data as unknown as Record<string, unknown>); if (r) { setEdit(null); st.reload(); } }}>Guardar</button></div>
        </Modal>
      )}
    </Panel>
  );
}

// ------------------------------------------------------------------ Voz: léxico, comandos, sinónimos y cuadro de prueba
export function normalizedPhrase(text: string, lex: LexiconData | null, synonyms: Record<string, string>): { text: string; changes: string[] } {
  const confusions = Object.fromEntries((lex?.confusions ?? []).map((c) => [c.from, c.to]));
  const changes: string[] = [];
  const words = text.toLowerCase().split(/\s+/).filter(Boolean).map((w) => {
    if (confusions[w]) { changes.push(`«${w}» → «${confusions[w]}»`); return confusions[w]!; }
    if (synonyms[w]) { const r = readUnit(synonyms[w]!).text; changes.push(`«${w}» → «${r}»`); return r; }
    return w;
  });
  return { text: words.join(' '), changes };
}

function VoiceTab() {
  const { api } = useSession();
  const st = useItems<LexiconData>('voice_lexicon');
  const units = useItems<UnitData>('catalog_unit');
  const { save, busy } = useSaveItem('voice_lexicon');
  const [sector, setSector] = useState('anestesia');
  const [phrase, setPhrase] = useState('');
  const [tested, setTested] = useState<string | null>(null);
  const [newSyn, setNewSyn] = useState({ spoken: '', unit: 'µg', sectorId: 'anestesia' });
  const [newConf, setNewConf] = useState({ from: '', to: '' });
  const lexItem = st.data?.[0] ?? null;
  const lex = lexItem?.data ?? null;
  const synonyms = useMemo(() => Object.fromEntries((lex?.sectorSynonyms ?? []).filter((s) => !sector || s.sectorId === sector).map((s) => [s.spoken, s.unit])), [lex, sector]);
  const unitForms = useMemo(() => Object.fromEntries((units.data ?? []).filter((u) => u.data.spokenForms?.length).map((u) => [u.data.symbol, u.data.spokenForms!])), [units.data]);
  const result = tested !== null ? parseSpoken(tested, { confusions: Object.fromEntries((lex?.confusions ?? []).map((c) => [c.from, c.to])), synonyms, unitForms }) : null;
  const norm = tested !== null ? normalizedPhrase(tested, lex, synonyms) : null;

  async function update(next: LexiconData) {
    if (!lexItem) return;
    const r = await save(lexItem, next as unknown as Record<string, unknown>);
    if (r) st.reload();
  }

  return (
    <div className="split">
      <div className="col g16" style={{ minWidth: 0 }}>
        <Async state={st}>
          {() => !lex || !lexItem ? <Empty title="Sin léxico de voz" /> : (
            <>
              <Panel title="Sinónimos por sector" icon="record_voice_over" actions={<StateChip state={lexItem.state} />} bodyClass="tblwrap">
                <table className="tbl" aria-label="Sinónimos por sector">
                  <thead><tr><th>Forma hablada</th><th>Unidad</th><th>Sector</th><th>Activado por defecto</th></tr></thead>
                  <tbody>{lex.sectorSynonyms.map((s, i) => <tr key={i}><td>«{s.spoken}»</td><td className="mono">{s.unit}</td><td>{sectorName(s.sectorId)}</td><td>{s.enabledByDefault ? 'Sí' : 'No'}</td></tr>)}</tbody>
                </table>
                <div className="row g8 wrap ai-end" style={{ padding: 16 }}>
                  <Field label="Nueva forma hablada" id="syn-spoken"><input id="syn-spoken" className="input input-sm" value={newSyn.spoken} onChange={(e) => setNewSyn({ ...newSyn, spoken: e.target.value.toLowerCase() })} /></Field>
                  <Field label="Unidad" id="syn-unit"><input id="syn-unit" className="input input-sm mono" style={{ width: 90 }} value={newSyn.unit} onChange={(e) => setNewSyn({ ...newSyn, unit: e.target.value })} /></Field>
                  <Field label="Sector del sinónimo" id="syn-sector"><select id="syn-sector" className="input input-sm" value={newSyn.sectorId} onChange={(e) => setNewSyn({ ...newSyn, sectorId: e.target.value })}>{DEFAULT_SECTORS.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
                  <button type="button" className="btn btn-primary btn-sm" disabled={busy || !newSyn.spoken.trim()} onClick={async () => { await update({ ...lex, sectorSynonyms: [...lex.sectorSynonyms, { ...newSyn, spoken: newSyn.spoken.trim(), enabledByDefault: false }] }); setNewSyn({ ...newSyn, spoken: '' }); }}><Icon name="add" />Añadir forma hablada</button>
                </div>
              </Panel>
              <Panel title="Léxico de confusiones" icon="swap_horiz">
                <ul className="row g6 wrap" aria-label="Léxico de confusiones">{lex.confusions.map((c, i) => <li key={i} className="chip chip-line">«{c.from}» → «{c.to}»</li>)}</ul>
                <div className="row g8 wrap ai-end" style={{ marginTop: 12 }}>
                  <Field label="Se oye" id="cf-from"><input id="cf-from" className="input input-sm" value={newConf.from} onChange={(e) => setNewConf({ ...newConf, from: e.target.value.toLowerCase() })} /></Field>
                  <Field label="Se interpreta" id="cf-to"><input id="cf-to" className="input input-sm" value={newConf.to} onChange={(e) => setNewConf({ ...newConf, to: e.target.value.toLowerCase() })} /></Field>
                  <button type="button" className="btn btn-secondary btn-sm" disabled={busy || !newConf.from || !newConf.to} onClick={async () => { await update({ ...lex, confusions: [...lex.confusions, newConf] }); setNewConf({ from: '', to: '' }); }}>Añadir confusión</button>
                </div>
              </Panel>
              <Panel title="Comandos" icon="keyboard_voice">
                <ul className="col g4" aria-label="Comandos de voz">{lex.commands.map((c) => <li key={c.command} className="t-small"><span className="mono b">{c.command}</span>: {c.synonyms.map((s) => `«${s}»`).join(', ')}</li>)}</ul>
              </Panel>
              <div className="row g8"><SubmitButton item={lexItem} onDone={st.reload} /><span className="t-small muted">{DRAFT_NOTE}</span></div>
            </>
          )}
        </Async>
      </div>
      <Panel title="Cuadro de prueba" icon="science">
        <form className="col g10" onSubmit={(e) => { e.preventDefault(); setTested(phrase); void api.post('/v1/admin/engine/parse-spoken', { text: phrase, options: { synonyms } }).catch(() => undefined); }}>
          <Field label="Sector de la prueba" id="pt-sector"><select id="pt-sector" className="input input-sm" value={sector} onChange={(e) => setSector(e.target.value)}><option value="">Todos</option>{DEFAULT_SECTORS.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></Field>
          <Field label="Escribe lo que diría el usuario" id="pt-text"><input id="pt-text" className="input" value={phrase} onChange={(e) => setPhrase(e.target.value)} /></Field>
          <button type="submit" className="btn btn-secondary btn-sm" disabled={!phrase.trim()}>Interpretar</button>
          {norm && (
            <dl className="col g8" aria-label="Resultado de la prueba">
              <div><dt className="t-label muted">Tras el léxico de confusiones</dt><dd style={{ margin: 0 }}>{norm.text}{norm.changes.length ? <span className="t-small muted"> · {norm.changes.join(' · ')}</span> : null}</dd></div>
              <div><dt className="t-label muted">Interpretación</dt><dd style={{ margin: 0 }} className="kv" data-testid="interpretacion-catalogo">{result?.kind === 'number' ? `${num(result.value)}${result.unit ? ` ${result.unit}` : ''}` : result?.kind === 'command' ? `Orden «${result.command}»` : result?.kind === 'ambiguous' ? result.question : 'Sin cifra reconocida'}</dd></div>
            </dl>
          )}
          <p className="t-small muted">Un cambio de catálogo sigue el mismo ciclo de revisión y publicación que el contenido.</p>
        </form>
      </Panel>
    </div>
  );
}

// ------------------------------------------------------------------ Anuncios propios
function CreativeEditor({ item, campaigns, onClose, onSaved }: { item: Item<Creative> | null; campaigns: Item<Campaign>[]; onClose: () => void; onSaved: () => void }) {
  const { save, busy } = useSaveItem('ad_creative');
  const [c, setC] = useState<Creative>(item?.data ?? { headline: '', body: '', cta: 'Quitar anuncios', voiceSpot: null, weight: 1, dailyCap: 3, context: 'always', kind: 'generic', campaignId: campaigns[0]?.id, ctaAction: 'paywall' });
  const issues = checkAdCreative(c);
  return (
    <Modal title={item ? `Anuncio ${item.id}` : 'Nuevo anuncio propio'} onClose={onClose}>
      <Field label="Titular" id="ad-headline"><input id="ad-headline" className="input" value={c.headline} onChange={(e) => setC({ ...c, headline: e.target.value })} /></Field>
      <Field label="Texto" id="ad-body"><textarea id="ad-body" className="input" value={c.body} onChange={(e) => setC({ ...c, body: e.target.value })} /></Field>
      <div className="grid2">
        <Field label="Botón" id="ad-cta"><input id="ad-cta" className="input" value={c.cta} onChange={(e) => setC({ ...c, cta: e.target.value })} /></Field>
        <Field label="Campaña" id="ad-camp"><select id="ad-camp" className="input" value={c.campaignId ?? ''} onChange={(e) => setC({ ...c, campaignId: e.target.value || undefined })}><option value="">Sin campaña</option>{campaigns.map((k) => <option key={k.id} value={k.id}>{k.data.name}</option>)}</select></Field>
        <Field label="Peso en la rotación" id="ad-weight"><input id="ad-weight" className="input mono" type="number" min={1} value={c.weight} onChange={(e) => setC({ ...c, weight: Number(e.target.value) })} /></Field>
        <Field label="Tope diario" id="ad-cap"><input id="ad-cap" className="input mono" type="number" min={1} value={c.dailyCap ?? ''} onChange={(e) => setC({ ...c, dailyCap: e.target.value ? Number(e.target.value) : null })} /></Field>
      </div>
      <Field label="Cuña hablada (manos libres)" id="ad-spot"><input id="ad-spot" className="input" value={c.voiceSpot ?? ''} onChange={(e) => setC({ ...c, voiceSpot: e.target.value || null })} /></Field>
      <section aria-label="Comprobaciones del anuncio">
        {issues.length === 0 ? <Notice kind="ok">Rotulado como promoción, sin términos vetados ni cifras escritas a mano.</Notice> : <ul className="col g4">{issues.map((i, k) => <li key={k} className="t-small c-error"><Icon name="error" size={16} /> {i.message}</li>)}</ul>}
      </section>
      <div className="row g8 end"><button type="button" className="btn btn-tertiary btn-sm" onClick={onClose}>Cancelar</button>
        <button type="button" className="btn btn-primary btn-sm" disabled={busy || !c.headline || issues.length > 0} onClick={async () => { const r = await save(item, { ...c, name: `${item?.id ?? 'Anuncio'} · ${c.headline}` } as unknown as Record<string, unknown>); if (r) onSaved(); }}>Guardar</button></div>
    </Modal>
  );
}

function AdsTab() {
  const { api } = useSession();
  const { run, busy } = useAction();
  const creatives = useItems<Creative>('ad_creative');
  const campaigns = useItems<Campaign>('ad_campaign');
  const params = useAsync(() => api.get<{ params: AdParams }>('/v1/admin/ads/params').then((r) => r.params), [api]);
  const perf = useAsync(() => api.get<{ items: { ad: string; impressions: number; taps: number; trials: number; purchases: number; voice_skipped: number }[] }>('/v1/admin/ads/performance').then((r) => r.items).catch(() => []), [api]);
  const [p, setP] = useState<AdParams | null>(null);
  const [edit, setEdit] = useState<Item<Creative> | null | 'new'>(null);
  const cur = p ?? params.data ?? null;
  return (
    <div className="col g16">
      <Panel title="Espera y frecuencia" icon="timer">
        {cur && (
          <div className="col g10">
            <div className="grid4">
              <Field label="Espera antes de continuar (0–5 s)" id="ap-wait"><input id="ap-wait" className="input mono" type="number" min={0} max={5} value={cur.waitS} onChange={(e) => setP({ ...cur, waitS: Number(e.target.value) })} /></Field>
              <Field label="Frecuencia táctil (cada N ejercicios)" id="ap-ft"><input id="ap-ft" className="input mono" type="number" min={1} value={cur.frequencyTouch} onChange={(e) => setP({ ...cur, frequencyTouch: Number(e.target.value) })} /></Field>
              <Field label="Frecuencia en manos libres" id="ap-fv"><input id="ap-fv" className="input mono" type="number" min={1} value={cur.frequencyVoice} onChange={(e) => setP({ ...cur, frequencyVoice: Number(e.target.value) })} /></Field>
              <Field label="Tope diario por defecto" id="ap-cap"><input id="ap-cap" className="input mono" type="number" min={1} value={cur.defaultDailyCap} onChange={(e) => setP({ ...cur, defaultDailyCap: Number(e.target.value) })} /></Field>
            </div>
            <div className="row g8"><button type="button" className="btn btn-primary btn-sm" disabled={!p || busy} onClick={async () => { const r = await run(() => api.put<{ note: string }>('/v1/admin/ads/params', cur), (x) => `Guardado. ${x.note}`); if (r) { setP(null); params.reload(); } }}>Guardar espera y frecuencia</button><span className="t-small muted">Los cambios llegan a las apps con la siguiente publicación de contenido, sin versión nueva en las tiendas.</span></div>
          </div>
        )}
      </Panel>
      <Panel title="Anuncios propios" icon="campaign" bodyClass="tblwrap" actions={<button type="button" className="btn btn-primary btn-xs" onClick={() => setEdit('new')}><Icon name="add" />Nuevo anuncio</button>}>
        <Async state={creatives}>
          {(items) => (
            <table className="tbl" aria-label="Anuncios propios">
              <thead><tr><th>Anuncio</th><th>Titular</th><th>Contexto</th><th className="num">Peso</th><th className="num">Tope diario</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
              <tbody>{items.map((a) => (
                <tr key={a.id}><td className="mono">{a.id}</td><td>{a.data.headline}</td><td className="t-small">{a.data.context}</td><td className="num">{a.data.weight}</td><td className="num">{a.data.dailyCap ?? '—'}</td><td><StateChip state={a.state} /></td>
                  <td className="actions"><button type="button" className="btn btn-tertiary btn-xs" onClick={() => setEdit(a)}>Editar</button><SubmitButton item={a} onDone={creatives.reload} /></td></tr>
              ))}</tbody>
            </table>
          )}
        </Async>
      </Panel>
      <div className="grid2">
        <Panel title="Campañas" icon="event">
          <Async state={campaigns}>
            {(items) => <ul className="col g6">{items.map((c) => <li key={c.id} className="t-small"><strong>{c.data.name}</strong> · {c.data.sectorIds?.length ? c.data.sectorIds.map((s) => sectorName(s)).join(', ') : 'todos los sectores'} · {c.data.endsAt ? `hasta el ${c.data.endsAt}` : 'sin fecha de fin'} · <StateChip state={c.state} /></li>)}</ul>}
          </Async>
        </Panel>
        <Panel title="Rendimiento" icon="insights" bodyClass="tblwrap">
          {(perf.data ?? []).length === 0 ? <p className="t-small muted" style={{ padding: 16 }}>Sin impresiones todavía.</p> : (
            <table className="tbl"><thead><tr><th>Anuncio</th><th className="num">Impresiones</th><th className="num">Toques</th><th className="num">Pruebas</th><th className="num">Compras</th></tr></thead>
              <tbody>{(perf.data ?? []).map((r) => <tr key={r.ad}><td className="mono">{r.ad}</td><td className="num">{r.impressions}</td><td className="num">{r.taps}</td><td className="num">{r.trials}</td><td className="num">{r.purchases}</td></tr>)}</tbody></table>
          )}
        </Panel>
      </div>
      {edit && <CreativeEditor item={edit === 'new' ? null : edit} campaigns={campaigns.data ?? []} onClose={() => setEdit(null)} onSaved={() => { setEdit(null); creatives.reload(); }} />}
    </div>
  );
}

type TabId = 'units' | 'instruments' | 'voice' | 'ads';

export function Catalogs() {
  const [tab, setTab] = useState<TabId>('units');
  return (
    <Page title="Catálogos de unidades y voz" crumbs={[{ label: 'Sistema' }, { label: 'Catálogos' }]}>
      <Tabs label="Catálogos" value={tab} onChange={setTab} tabs={[{ id: 'units', label: 'Unidades' }, { id: 'instruments', label: 'Instrumentos' }, { id: 'voice', label: 'Voz: confusiones, comandos y sinónimos' }, { id: 'ads', label: 'Anuncios propios' }]} />
      {tab === 'units' && <UnitsTab />}
      {tab === 'instruments' && <InstrumentsTab />}
      {tab === 'voice' && <VoiceTab />}
      {tab === 'ads' && <AdsTab />}
    </Page>
  );
}
