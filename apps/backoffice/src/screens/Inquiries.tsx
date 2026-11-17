/**
 * B25 · Consultas de usuarios: bandeja, ficha con la variante exacta y la
 * respuesta que dio el usuario, respuestas modelo (la de pacientes reales la
 * declina), conversión en corrección de contenido y retirada inmediata.
 */
import { useState } from 'react';
import { Link } from 'react-router-dom';
import type { Variant } from '@vtm/contracts';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { Statement } from '../content/ExercisePreview';
import { Async, Empty, Field, Icon, Notice, Page, Panel, ReasonDialog, useAction, useAsync } from '../ui/kit';
import { ago, date, qty } from '../ui/format';

interface Inquiry {
  id: string; reference: string; user_id: string | null; type: string; message: string; reply_email: string | null; status: string; assignee_id: string | null; assignee_name?: string | null;
  reply: string | null; linked_item_id: string | null; is_patient_query: boolean; created_at: string; answered_at: string | null;
  exercise: { variantId?: string; templateId?: string | null; questionId?: string | null; answerValue?: string | null; answerUnit?: string | null } | null;
}

const TYPE: Record<string, string> = { exercise_error: 'Error en un ejercicio', explanation_doubt: 'Duda sobre una explicación', technical: 'Problema técnico', content_suggestion: 'Sugerencia de contenido', other: 'Otra consulta' };
const STATUS: Record<string, string> = { received: 'Recibida', in_review: 'En revisión', answered: 'Respondida' };
const MODEL_LABELS: Record<string, string> = { patient: 'Consulta sobre un paciente: la declinamos', fixed: 'Ejercicio corregido', explanation: 'Explicación detallada', received: 'Gracias por avisar: lo revisamos' };

function InquiryDetail({ id, onChanged }: { id: string; onChanged: () => void }) {
  const { api, account } = useSession();
  const { run, busy } = useAction();
  const st = useAsync(() => api.get<{ inquiry: Inquiry; variant: Variant | null; models: Record<string, string>; suggestedModel: string | null }>(`/v1/admin/inquiries/${id}`), [api, id]);
  const [model, setModel] = useState<string | null>(null);
  const [text, setText] = useState<string | null>(null);
  const [converted, setConverted] = useState<{ itemId: string; version: number } | null>(null);
  const [withdrawn, setWithdrawn] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);
  const admin = can(account?.role, 'convertInquiry');
  return (
    <Async state={st}>
      {(d) => {
        const i = d.inquiry;
        const chosen = model ?? d.suggestedModel ?? (i.type === 'exercise_error' ? 'received' : 'received');
        const body = text ?? d.models[chosen] ?? '';
        const v = d.variant;
        const answerCode = v && i.exercise?.answerValue ? v.predictedErrors.find((p) => p.value === i.exercise!.answerValue)?.code : null;
        const itemPath = i.exercise?.questionId ? `/preguntas/${i.exercise.questionId}` : i.exercise?.templateId ? `/plantillas/${i.exercise.templateId}` : null;
        return (
          <div className="col g16">
            <Panel title={`${TYPE[i.type] ?? i.type} · ${i.reference}`} icon="mail" actions={<span className="chip">{STATUS[i.status] ?? i.status}</span>}>
              <div className="col g12">
                <p className="t-small muted">{date(i.created_at, true)}{i.reply_email ? ` · responder a ${i.reply_email}` : ''}</p>
                <blockquote className="card t-body" style={{ margin: 0 }}>«{i.message}»</blockquote>
                {i.is_patient_query && <Notice kind="warn" icon="health_and_safety">Consulta sobre un paciente real: se responde con la respuesta modelo que la declina.</Notice>}
                {i.exercise && (
                  <section className="card col g8" aria-label="Variante exacta" style={{ background: 'var(--surface-2)' }}>
                    <span className="t-label muted">Variante exacta · {i.exercise.variantId ?? '—'}</span>
                    {v ? (
                      <>
                        <p className="t-body"><Statement segs={v.statement} /> {v.question}</p>
                        {v.answer && <p className="t-small">Respuesta correcta: <strong className="mono">{qty(v.answer.value, v.answer.unit)}</strong></p>}
                      </>
                    ) : <p className="t-small muted">La variante no está en los paquetes publicados recientes.</p>}
                    <p className="t-small" data-testid="respuesta-dada">Respuesta dada: <strong className="mono">{qty(i.exercise.answerValue ?? null, i.exercise.answerUnit)}</strong>{answerCode ? ` · ${answerCode}` : ''}</p>
                    {itemPath && <Link to={itemPath} className="t-small">Abrir el ejercicio</Link>}
                  </section>
                )}
                {i.reply && <Notice kind="ok">Respondida {ago(i.answered_at)}: «{i.reply}»</Notice>}
              </div>
            </Panel>
            {i.status !== 'answered' && (
              <Panel title="Respuesta" icon="reply">
                <div className="col g10">
                  <Field label="Respuesta modelo" id="iq-model">
                    <select id="iq-model" className="input" value={chosen} onChange={(e) => { setModel(e.target.value); setText(null); }}>
                      {Object.keys(d.models).map((k) => <option key={k} value={k}>{MODEL_LABELS[k] ?? k}</option>)}
                    </select>
                  </Field>
                  <Field label="Texto de la respuesta" id="iq-text"><textarea id="iq-text" className="input" value={body} onChange={(e) => setText(e.target.value)} /></Field>
                  <button type="button" className="btn btn-primary btn-sm" disabled={busy || !body.trim()} onClick={async () => {
                    const r = await run(() => api.post(`/v1/admin/inquiries/${id}/reply`, text === null ? { template: chosen } : { text: body }), 'Respuesta enviada');
                    if (r) { st.reload(); onChanged(); }
                  }}><Icon name="send" />Responder</button>
                </div>
              </Panel>
            )}
            {admin && i.exercise && (
              <Panel title="Acciones sobre el ejercicio" icon="build">
                <div className="col g10">
                  {converted && <Notice kind="ok">Creado el borrador v{converted.version} de la plantilla, enlazado con la consulta {i.reference}. <Link to={`/plantillas/${converted.itemId}`}>Abrir el borrador</Link></Notice>}
                  {withdrawn && <Notice kind="ok">Retirada aplicada: las apps dejan de presentarlo en cuanto tienen conexión.</Notice>}
                  <div className="row g8 wrap">
                    <button type="button" className="btn btn-secondary btn-sm" disabled={busy} onClick={async () => { const r = await run(() => api.post<{ itemId: string; version: number }>(`/v1/admin/inquiries/${id}/convert`), 'Borrador de corrección creado'); if (r) { setConverted(r); st.reload(); } }}><Icon name="edit_document" />Convertir en corrección de contenido</button>
                    <button type="button" className="btn btn-danger btn-sm" onClick={() => setWithdrawing(true)}><Icon name="block" />Retirar el ejercicio ahora</button>
                  </div>
                </div>
              </Panel>
            )}
            {withdrawing && (
              <ReasonDialog title="Retirar el ejercicio ahora" danger confirmLabel="Retirar ahora" initial={`Retirado desde la consulta ${i.reference}`} onClose={() => setWithdrawing(false)}
                description="Entra en la lista de retirada sin publicar una versión completa: las apps dejan de presentarlo en cuanto tienen conexión."
                onConfirm={async (reason) => { const r = await run(() => api.post(`/v1/admin/inquiries/${id}/withdraw-exercise`, { reason }), 'Retirada aplicada'); setWithdrawing(false); if (r) { setWithdrawn(true); st.reload(); } }} />
            )}
          </div>
        );
      }}
    </Async>
  );
}

export function Inquiries() {
  const { api } = useSession();
  const [status, setStatus] = useState('');
  const [type, setType] = useState('');
  const [selected, setSelected] = useState<string | null>(null);
  const st = useAsync(() => api.get<{ items: Inquiry[] }>('/v1/admin/inquiries', { status: status || undefined, type: type || undefined }), [api, status, type]);
  const open = (st.data?.items ?? []).filter((i) => i.status !== 'answered').length;
  return (
    <Page title="Consultas" crumbs={[{ label: 'Personas' }, { label: 'Consultas' }]}>
      <div className="row g8 wrap">
        <select aria-label="Estado" className="input input-sm" style={{ width: 'auto' }} value={status} onChange={(e) => setStatus(e.target.value)}><option value="">Estado: todos</option>{Object.entries(STATUS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
        <select aria-label="Tipo de consulta" className="input input-sm" style={{ width: 'auto' }} value={type} onChange={(e) => setType(e.target.value)}><option value="">Tipo: todos</option>{Object.entries(TYPE).map(([k, v]) => <option key={k} value={k}>{v}</option>)}</select>
      </div>
      <div className="split-l">
        <Panel title={`Bandeja · ${open}`} icon="inbox">
          <Async state={st}>
            {(d) => d.items.length === 0 ? <Empty title="Sin consultas" /> : (
              <ul className="col g4" aria-label="Bandeja de consultas">
                {d.items.map((i) => (
                  <li key={i.id}>
                    <button type="button" className={`tree-node${selected === i.id ? ' sel' : ''}`} style={{ width: '100%', border: 0, background: selected === i.id ? undefined : 'none', cursor: 'pointer', flexDirection: 'column', alignItems: 'flex-start', padding: 10 }} onClick={() => setSelected(i.id)}>
                      <span className="ui sb">{TYPE[i.type] ?? i.type}{i.is_patient_query ? ' · paciente' : ''}</span>
                      <span className="t-label muted">{i.reference} · {ago(i.created_at)} · {i.assignee_name ?? 'Sin asignar'} · {STATUS[i.status]}</span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </Async>
        </Panel>
        {selected ? <InquiryDetail key={selected} id={selected} onChanged={st.reload} /> : <Panel title="Detalle"><Empty icon="mark_email_read" title="Elige una consulta">Las consultas sobre pacientes reciben una respuesta modelo que las declina.</Empty></Panel>}
      </div>
    </Page>
  );
}
