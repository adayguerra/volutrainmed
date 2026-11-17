/**
 * B21 · Analítica de contenido y B22 · analítica de un elemento.
 * Por plantilla y por pregunta: respuestas, acierto al primer intento, tiempo
 * mediano frente al objetivo, «No lo sé», errores críticos y error más
 * frecuente; «Datos insuficientes» por debajo de 50 respuestas; alertas de
 * calidad; promoción de una respuesta errónea sin clasificar a error previsible.
 */
import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ERROR_LABELS } from '@vtm/contracts';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { DEFAULT_SECTORS, ERROR_CODES, download, errorLabel } from '../content/common';
import { toCsv } from '../content/csv';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, useAction, useAsync } from '../ui/kit';
import { num, pct, qty } from '../ui/format';

export interface ItemStats {
  itemId: string; kind: string; title: string; sectorId: string | null; exerciseTypeId: string | null; responses: number; firstAttemptAccuracy: number | null;
  medianMs: number | null; targetMs: number | null; timeRatio: number | null; dontKnowPct: number | null; critical: number; unclassifiedPct: number | null;
  topError: { value: string | null; unit: string | null; code: string | null; count: number } | null; reports: number; insufficient: boolean; alerts: string[];
}

type SortKey = 'firstAttemptAccuracy' | 'responses' | 'timeRatio' | 'dontKnowPct' | 'critical' | 'reports';
const COLS: { key: SortKey; label: string }[] = [
  { key: 'responses', label: 'Respuestas' }, { key: 'firstAttemptAccuracy', label: 'Acierto 1.er intento' }, { key: 'timeRatio', label: 'Tiempo / objetivo' },
  { key: 'dontKnowPct', label: '«No lo sé»' }, { key: 'critical', label: 'Errores críticos' }, { key: 'reports', label: 'Avisos' },
];

export function Analytics() {
  const { api } = useSession();
  const [sort, setSort] = useState<SortKey>('firstAttemptAccuracy');
  const [dir, setDir] = useState<'asc' | 'desc'>('asc');
  const [sector, setSector] = useState('');
  const [type, setType] = useState('');
  const st = useAsync(() => api.get<{ items: ItemStats[] }>('/v1/admin/analytics/items', { sort, dir, sector: sector || undefined }), [api, sort, dir, sector]);
  const rows = (st.data?.items ?? []).filter((r) => !type || r.exerciseTypeId === type);
  const byType = useMemo(() => {
    const m = new Map<string, { ok: number; n: number }>();
    for (const r of st.data?.items ?? []) {
      if (!r.exerciseTypeId || r.firstAttemptAccuracy === null || !r.responses) continue;
      const x = m.get(r.exerciseTypeId) ?? { ok: 0, n: 0 };
      x.ok += (r.firstAttemptAccuracy / 100) * r.responses; x.n += r.responses;
      m.set(r.exerciseTypeId, x);
    }
    return [...m.entries()].map(([t, x]) => ({ t, acc: (x.ok / x.n) * 100 })).sort((a, b) => a.t.localeCompare(b.t));
  }, [st.data]);
  const alerts = (st.data?.items ?? []).filter((r) => r.alerts.length);
  function toggle(k: SortKey) {
    if (k === sort) setDir(dir === 'asc' ? 'desc' : 'asc');
    else { setSort(k); setDir(k === 'firstAttemptAccuracy' ? 'asc' : 'desc'); }
  }
  return (
    <Page title="Analítica de contenido" crumbs={[{ label: 'Análisis' }, { label: 'Analítica de contenido' }]}
      actions={<button type="button" className="btn btn-secondary btn-sm" onClick={() => download('analitica.csv', toCsv(['elemento', 'tipo', 'respuestas', 'acierto', 'tiempo_objetivo', 'no_lo_se', 'criticos', 'error_frecuente', 'avisos'], rows.map((r) => [r.title, r.exerciseTypeId, r.responses, r.firstAttemptAccuracy?.toFixed(1), r.timeRatio?.toFixed(2), r.dontKnowPct?.toFixed(1), r.critical, r.topError?.code, r.reports])))}><Icon name="download" />Exportar CSV</button>}>
      <div className="row g8 wrap">
        <select aria-label="Sector" className="input input-sm" style={{ width: 'auto' }} value={sector} onChange={(e) => setSector(e.target.value)}><option value="">Sector: todos</option>{DEFAULT_SECTORS.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select>
        <select aria-label="Tipo" className="input input-sm" style={{ width: 'auto' }} value={type} onChange={(e) => setType(e.target.value)}><option value="">Tipo: todos</option>{byType.map((b) => <option key={b.t} value={b.t}>{b.t}</option>)}</select>
      </div>
      <Async state={st}>
        {() => (
          <>
            <div className="grid2">
              <Panel title="Acierto por tipo de ejercicio" icon="bar_chart">
                {byType.length === 0 ? <p className="t-small muted">Sin respuestas todavía.</p> : (
                  <div className="col g8">
                    {byType.map((b) => (
                      <button key={b.t} type="button" className="hbar" style={{ background: 'none', border: 0, cursor: 'pointer', textAlign: 'left', padding: 0 }} onClick={() => setType(type === b.t ? '' : b.t)} aria-pressed={type === b.t}>
                        <span className="mono b">{b.t}</span><span className="bar"><b style={{ width: `${b.acc}%` }} /></span><span className="mono">{pct(b.acc)}</span>
                      </button>
                    ))}
                    <p className="t-small muted">Toca una barra para filtrar la tabla.</p>
                  </div>
                )}
              </Panel>
              <Panel title="Alertas activas" icon="warning">
                {alerts.length === 0 ? <p className="t-small muted">Sin alertas.</p> : <ul className="col g6" aria-label="Alertas activas">{alerts.flatMap((a) => a.alerts.map((x, i) => <li key={`${a.itemId}-${i}`} className="t-small"><Link to={`/analitica/${a.itemId}`}>{a.title}</Link>: {x}</li>))}</ul>}
              </Panel>
            </div>
            <Panel title="Plantillas y preguntas" icon="table" bodyClass="tblwrap">
              {rows.length === 0 ? <Empty title="Sin elementos" /> : (
                <table className="tbl" aria-label="Analítica por elemento">
                  <thead><tr><th>Elemento</th><th>Tipo</th>
                    {COLS.map((c) => <th key={c.key} aria-sort={sort === c.key ? (dir === 'asc' ? 'ascending' : 'descending') : 'none'}><button type="button" className="link" style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer', font: 'inherit' }} onClick={() => toggle(c.key)}>{c.label}{sort === c.key ? (dir === 'asc' ? ' ↑' : ' ↓') : ''}</button></th>)}
                    <th>Error más frecuente</th></tr></thead>
                  <tbody>{rows.map((r) => (
                    <tr key={r.itemId} data-testid="fila-analitica">
                      <td><Link to={`/analitica/${r.itemId}`}>{r.title}</Link></td>
                      <td className="mono">{r.exerciseTypeId ?? '—'}</td>
                      <td className="num">{num(r.responses, 0)}</td>
                      <td className="num" data-col="acierto">{r.insufficient ? <span className="chip">Datos insuficientes</span> : pct(r.firstAttemptAccuracy)}</td>
                      <td className="num">{r.timeRatio === null ? '—' : `${num(r.timeRatio, 1)}×`}</td>
                      <td className="num">{pct(r.dontKnowPct)}</td>
                      <td className="num">{r.critical}</td>
                      <td className="num">{r.reports}</td>
                      <td className="t-small">{r.topError ? `${errorLabel(r.topError.code ?? 'E0')}` : '—'}</td>
                    </tr>
                  ))}</tbody>
                </table>
              )}
            </Panel>
          </>
        )}
      </Async>
    </Page>
  );
}

interface Detail {
  stat: ItemStats; wrongAnswers: { value: string | null; unit: string | null; code: string | null; n: number }[];
  byLevel: { level: number; n: number; acc: number }[]; byInput: { input_mode: string; n: number; acc: number }[];
  byVariant: { variant_id: string; n: number; acc: number }[]; lowVariants: { variant_id: string; n: number; acc: number }[];
  timeDistribution: { b: number; n: number }[]; byVersion: { content_version: string; n: number; acc: number }[]; summary: string;
}

const INPUT: Record<string, string> = { touch: 'Táctil', keyboard: 'Teclado', voice: 'Voz' };

export function AnalyticsItem() {
  const { id } = useParams();
  const { api, account } = useSession();
  const { run } = useAction();
  const st = useAsync(() => api.get<Detail>(`/v1/admin/analytics/items/${id}`), [api, id]);
  const [promote, setPromote] = useState<{ value: string | null; unit: string | null } | null>(null);
  const [code, setCode] = useState('E0');
  const [message, setMessage] = useState('');
  const [formula, setFormula] = useState('');
  const [created, setCreated] = useState<{ itemId: string; version: number } | null>(null);
  const canPromote = can(account?.role, 'promoteError');
  return (
    <Async state={st}>
      {(d) => {
        const total = d.wrongAnswers.reduce((a, w) => a + w.n, 0) || 1;
        const maxT = Math.max(1, ...d.timeDistribution.map((t) => t.n));
        const editorPath = d.stat.kind === 'question' ? `/preguntas/${d.stat.itemId}` : `/plantillas/${d.stat.itemId}`;
        return (
          <Page title={d.stat.title} crumbs={[{ label: 'Análisis' }, { label: 'Analítica de contenido', to: '/analitica' }, { label: d.stat.title }]}
            actions={<Link className="btn btn-secondary btn-sm" to={editorPath}><Icon name="open_in_new" />Abrir {d.stat.kind === 'question' ? 'pregunta' : 'plantilla'}</Link>}>
            {d.stat.insufficient ? <Notice kind="info" icon="hourglass_empty"><strong>Datos insuficientes</strong>: {d.stat.responses} respuestas de las 50 necesarias para sacar conclusiones.</Notice> : <Notice kind={d.stat.alerts.length ? 'warn' : 'info'}>{d.summary}{d.stat.alerts.length ? `. ${d.stat.alerts.join(' · ')}` : ''}</Notice>}
            {created && <Notice kind="ok">Creada la versión {created.version} en borrador con el nuevo error previsible. <Link to={editorPath}>Revisarla en el editor</Link>.</Notice>}
            <div className="grid2">
              <Panel title="Respuestas erróneas más dadas" icon="error" bodyClass="tblwrap">
                {d.wrongAnswers.length === 0 ? <Empty title="Sin respuestas erróneas" /> : (
                  <table className="tbl" aria-label="Respuestas erróneas más dadas">
                    <thead><tr><th>Respuesta</th><th>Código</th><th className="num">Frecuencia</th><th><span className="sr-only">Acciones</span></th></tr></thead>
                    <tbody>{d.wrongAnswers.map((w, i) => (
                      <tr key={i}>
                        <td className="mono">{qty(w.value, w.unit)}</td>
                        <td>{w.code ? `${w.code} · ${ERROR_LABELS[w.code as keyof typeof ERROR_LABELS] ?? ''}` : 'Sin clasificar'}</td>
                        <td className="num">{pct((w.n / total) * 100)}</td>
                        <td className="actions">{!w.code && canPromote && <button type="button" className="btn btn-secondary btn-xs" onClick={() => { setPromote({ value: w.value, unit: w.unit }); setCode('E0'); setMessage(''); setFormula(''); }}>Añadir como error previsible</button>}</td>
                      </tr>
                    ))}</tbody>
                  </table>
                )}
              </Panel>
              <Panel title="Acierto por nivel" icon="stairs">
                <div className="col g8">{d.byLevel.map((l) => <div key={l.level} className="hbar"><span>Nivel {l.level}</span><span className="bar"><b style={{ width: `${l.acc}%` }} /></span><span className="mono">{pct(l.acc)}</span></div>)}</div>
                {d.byInput.length > 0 && <div className="col g8" style={{ marginTop: 16 }}><span className="t-label muted">Por modo de entrada</span>{d.byInput.map((x) => <div key={x.input_mode} className="hbar"><span>{INPUT[x.input_mode] ?? x.input_mode}</span><span className="bar"><b style={{ width: `${x.acc}%` }} /></span><span className="mono">{pct(x.acc)}</span></div>)}</div>}
              </Panel>
              <Panel title="Distribución de tiempos" icon="timer">
                {d.timeDistribution.length === 0 ? <p className="t-small muted">Sin datos.</p> : <div className="bars" role="img" aria-label="Distribución de tiempos de respuesta">{d.timeDistribution.map((t) => <div key={t.b} style={{ height: `${(t.n / maxT) * 100}%` }} title={`${(t.b - 1) * 10}–${t.b * 10} s: ${t.n}`} />)}</div>}
                <p className="t-small muted">Tiempo mediano {d.stat.medianMs ? `${num(d.stat.medianMs / 1000, 1)} s` : '—'} · objetivo {d.stat.targetMs ? `${num(d.stat.targetMs / 1000, 0)} s` : '—'}</p>
              </Panel>
              <Panel title="Evolución entre versiones" icon="timeline" bodyClass="tblwrap">
                <table className="tbl"><thead><tr><th>Versión de contenido</th><th className="num">Respuestas</th><th className="num">Acierto</th></tr></thead>
                  <tbody>{d.byVersion.map((v) => <tr key={v.content_version}><td className="mono">{v.content_version}</td><td className="num">{v.n}</td><td className="num">{pct(v.acc)}</td></tr>)}</tbody></table>
                {d.lowVariants.length > 0 && <Notice kind="warn">Variantes con acierto anómalo: {d.lowVariants.map((v) => `${v.variant_id} (${v.acc} %)`).join(' · ')}</Notice>}
              </Panel>
            </div>
            {promote && (
              <Modal title="Añadir como error previsible" onClose={() => setPromote(null)}>
                <p className="t-small">Respuesta errónea frecuente: <strong className="mono">{qty(promote.value, promote.unit)}</strong>. Se crea una versión nueva en borrador que pasa por revisión.</p>
                <Field label="Tipo de error" id="pe-code"><select id="pe-code" className="input" value={code} onChange={(e) => setCode(e.target.value)}>{ERROR_CODES.map((c) => <option key={c} value={c}>{c} · {ERROR_LABELS[c]}</option>)}</select></Field>
                <Field label="Diagnóstico en una frase" id="pe-msg"><input id="pe-msg" className="input" value={message} onChange={(e) => setMessage(e.target.value)} /></Field>
                {d.stat.kind === 'template' && <Field label="Fórmula del error" id="pe-formula" help="En una plantilla, el error previsible se define con su fórmula, por ejemplo respuesta ÷ 60."><input id="pe-formula" className="input mono" value={formula} onChange={(e) => setFormula(e.target.value)} /></Field>}
                <div className="row g8 end">
                  <button type="button" className="btn btn-tertiary btn-sm" onClick={() => setPromote(null)}>Cancelar</button>
                  <button type="button" className="btn btn-primary btn-sm" disabled={!message.trim() || (d.stat.kind === 'template' && !formula.trim())} onClick={async () => {
                    const r = await run(() => api.post<{ itemId: string; version: number }>(`/v1/admin/analytics/items/${id}/promote-error`, { value: promote.value, unit: promote.unit, code, message: message.trim(), formula: formula.trim() || undefined }), (x) => `Creada la versión ${x.version} en borrador`);
                    if (r) { setCreated(r); setPromote(null); }
                  }}>Añadir</button>
                </div>
              </Modal>
            )}
          </Page>
        );
      }}
    </Async>
  );
}
