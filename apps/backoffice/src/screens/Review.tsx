/**
 * B15 · Bandeja de revisión y B16 · ficha de revisión.
 * Validar es exclusivo del revisor experto acreditado en el sector y nunca del
 * autor (cuatro ojos, aplicado también en la base de datos). La validación
 * exige la lista de comprobación completa y guarda revisor, acreditación, fecha
 * y huella de la versión; si el autor cambia el contenido durante la revisión,
 * se muestran las diferencias y la lista se reinicia.
 */
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { ApiError } from '../api/client';
import type { Item, Review as ReviewRow, ReviewComment } from '../api/types';
import { KIND_LABELS } from '../api/types';
import { useSession } from '../auth/session';
import { DEFAULT_SECTORS, isExpired, sectorName } from '../content/common';
import { Async, Empty, Field, Icon, Notice, Page, Panel, StateChip, useAction, useAsync, useToast } from '../ui/kit';
import { date, num, qty } from '../ui/format';
import { speak } from './Preview';

interface InboxItem extends Item<{ exerciseTypeId?: string }> { authorName: string | null; mySector: boolean; ownContent: boolean; daysInReview: number; modifiedDuringReview: boolean }

export function ReviewInbox() {
  const { api, account } = useSession();
  const navigate = useNavigate();
  const [scope, setScope] = useState<'mine' | 'all'>(account?.role === 'reviewer' ? 'mine' : 'all');
  const [kind, setKind] = useState('');
  const [order, setOrder] = useState<'old' | 'new'>('old');
  const st = useAsync(() => api.get<{ items: InboxItem[] }>('/v1/admin/reviews/inbox', { kind: kind || undefined }), [api, kind]);
  const rows = (st.data?.items ?? []).filter((i) => scope === 'all' || i.mySector).sort((a, b) => (order === 'old' ? b.daysInReview - a.daysInReview : a.daysInReview - b.daysInReview));
  const sectors = account?.sectors ?? [];
  return (
    <Page title="Revisión experta" crumbs={[{ label: 'Contenido' }, { label: 'Revisión' }]}>
      {account?.role === 'reviewer' ? (
        <Notice icon="verified">Tus sectores acreditados: <strong>{sectors.map((s) => sectorName(s)).join(', ') || 'ninguno'}</strong>. En el resto puedes comentar, no validar. Nadie valida contenido propio.</Notice>
      ) : (
        <Notice icon="info">Validar es exclusivo del revisor experto acreditado en el sector. {account?.role === 'author' ? 'Aquí ves tu contenido pendiente de revisión.' : 'Puedes seguir el estado y comentar.'}</Notice>
      )}
      <div className="row g8 wrap">
        {account?.role === 'reviewer' && (
          <select aria-label="Sector" className="input input-sm" style={{ width: 'auto' }} value={scope} onChange={(e) => setScope(e.target.value as 'mine' | 'all')}>
            <option value="mine">Sector: mis sectores</option><option value="all">Sector: todos</option>
          </select>
        )}
        <select aria-label="Tipo" className="input input-sm" style={{ width: 'auto' }} value={kind} onChange={(e) => setKind(e.target.value)}>
          <option value="">Tipo: todos</option><option value="template">Plantillas</option><option value="question">Preguntas</option><option value="catalog_unit">Catálogos</option><option value="ad_creative">Anuncios</option><option value="achievement">Logros</option>
        </select>
        <select aria-label="Antigüedad" className="input input-sm" style={{ width: 'auto' }} value={order} onChange={(e) => setOrder(e.target.value as 'old' | 'new')}>
          <option value="old">Antigüedad: más antiguos</option><option value="new">Antigüedad: más recientes</option>
        </select>
      </div>
      <Panel title={`Pendientes de revisión · ${rows.length}`} icon="inbox" bodyClass="tblwrap">
        <Async state={st}>
          {() => rows.length === 0 ? <Empty icon="task_alt" title="No hay nada pendiente de revisión" /> : (
            <table className="tbl" aria-label="Pendientes de revisión">
              <thead><tr><th>Elemento</th><th>Clase</th><th>Sector</th><th>Autor</th><th>En revisión</th><th>Aviso</th><th>Estado</th></tr></thead>
              <tbody>{rows.map((i) => {
                const expired = isExpired(i);
                return (
                  <tr key={i.id} className="clickable" onClick={(e) => { if (!(e.target as HTMLElement).closest('a')) navigate(`/revision/${i.id}`); }}>
                    <td><Link to={`/revision/${i.id}`}>{i.title}</Link></td>
                    <td>{KIND_LABELS[i.kind] ?? i.kind}{i.data.exerciseTypeId ? ` · ${i.data.exerciseTypeId}` : ''}</td>
                    <td>{sectorName(i.sectorId, DEFAULT_SECTORS)}</td>
                    <td>{i.authorName ?? '—'}</td>
                    <td className="num">{expired ? '—' : `${i.daysInReview} ${i.daysInReview === 1 ? 'día' : 'días'}`}</td>
                    <td className="t-small">
                      {expired && <span className="chip chip-warning">Validación caducada</span>}
                      {i.modifiedDuringReview && <span className="chip chip-warning">Modificado durante la revisión</span>}
                      {i.ownContent && <span className="chip">Contenido propio</span>}
                      {account?.role === 'reviewer' && !i.mySector && <span className="chip">Solo comentar</span>}
                    </td>
                    <td><StateChip state={i.state} expired={expired} /></td>
                  </tr>
                );
              })}</tbody>
            </table>
          )}
        </Async>
      </Panel>
    </Page>
  );
}

interface SampleVariant { id: string; level: number; statement: string; question: string; tts?: string; answer?: { value: string; unit: string }; recalculated?: string; matches: boolean; assignment?: Record<string, { value: string; unit: string; text?: string }>; options?: { id: string; label: string; correct: boolean }[] }
interface Sheet {
  item: Item; authorName: string | null; sample: SampleVariant[]; extremes: SampleVariant[]; comments: ReviewComment[]; reviews: ReviewRow[];
  changesDuringReview: { path: string; before: unknown; after: unknown }[]; checklist: { key: string; label: string }[]; requiredValidations: number;
  canValidate: boolean; canComment: boolean; reasonCannotValidate: string | null;
}

function short(v: unknown): string {
  if (v === undefined) return '—';
  const s = typeof v === 'string' ? v : JSON.stringify(v);
  return s.length > 80 ? `${s.slice(0, 80)}…` : s;
}

function assignmentText(a?: SampleVariant['assignment']): string {
  if (!a) return '—';
  return Object.entries(a).map(([, v]) => v.text ?? `${num(v.value)}${v.unit ? ` ${v.unit}` : ''}`).join(' · ');
}

export function ReviewSheet() {
  const { itemId } = useParams();
  const { api, account } = useSession();
  const toast = useToast();
  const { run, busy } = useAction();
  const st = useAsync(() => api.get<Sheet>(`/v1/admin/reviews/${itemId}`), [api, itemId]);
  const [checked, setChecked] = useState<Record<string, boolean>>({});
  const [comment, setComment] = useState('');
  const [note, setNote] = useState('');
  const [result, setResult] = useState<string | null>(null);
  const [resetNotice, setResetNotice] = useState(false);

  async function decide(decision: 'validate' | 'request_changes' | 'reject', s: Sheet) {
    try {
      const r = await api.post<{ state: string; validations: number }>(`/v1/admin/reviews/${itemId}/decision`, { decision, checklist: checked, comment: comment.trim() || undefined, fingerprint: s.item.fingerprint });
      if (decision === 'validate') {
        setResult(r.state === 'validated'
          ? 'Validado. La validación guarda revisor, acreditación, fecha y huella de la versión, y caduca a los 24 meses.'
          : `Validación registrada (${r.validations} de ${s.requiredValidations}). Sigue en revisión hasta la segunda validación.`);
      } else setResult(decision === 'request_changes' ? 'Cambios solicitados: el contenido vuelve al autor con tu comentario.' : 'Rechazado: el contenido vuelve a borrador con tu comentario.');
      setComment('');
      setChecked({});
      st.reload();
    } catch (e) {
      if (e instanceof ApiError && e.code === 'modified_during_review') {
        setChecked({});
        setResetNotice(true);
        st.reload();
      }
      toast((e as Error).message, true);
    }
  }

  async function addComment() {
    const r = await run(() => api.post(`/v1/admin/reviews/${itemId}/comments`, { body: note.trim() }), 'Comentario añadido');
    if (r) { setNote(''); st.reload(); }
  }

  return (
    <Async state={st}>
      {(s) => {
        const total = s.checklist.length;
        const done = s.checklist.filter((c) => checked[c.key]).length;
        const inReview = s.item.state === 'in_review';
        const isReviewer = account?.role === 'reviewer';
        const first = s.sample[0];
        const lastChange = [...s.reviews].find((r) => r.decision !== 'validate');
        const rows: (SampleVariant & { tag?: string })[] = [
          ...s.extremes.map((v, i) => ({ ...v, tag: i === 0 ? 'Extremo · mínimo' : 'Extremo · máximo' })),
          ...s.sample,
        ];
        return (
          <Page title={`${s.item.title} · v${s.item.version}`} crumbs={[{ label: 'Contenido' }, { label: 'Revisión', to: '/revision' }, { label: s.item.title }]}
            chip={<><StateChip state={s.item.state} expired={isExpired(s.item)} /><span className="t-small muted">Autor: {s.authorName ?? '—'}</span></>}
            actions={<Link className="btn btn-tertiary btn-sm" to={s.item.kind === 'question' ? `/preguntas/${s.item.id}` : `/plantillas/${s.item.id}`}><Icon name="open_in_new" />Abrir en el editor</Link>}>
            {s.requiredValidations > 1 && <Notice kind="info" icon="group">Este sector exige dos revisores: {s.item.validations} de {s.requiredValidations} validaciones registradas.</Notice>}
            {result && <Notice kind="ok">{result}</Notice>}
            {s.item.state === 'changes_requested' && lastChange?.comment && <Notice kind="warn">Cambios solicitados por {lastChange.reviewer_name}: «{lastChange.comment}»</Notice>}
            {s.changesDuringReview.length > 0 && (
              <section className="panel panel-b col g8" aria-label="Diferencias durante la revisión" style={{ borderColor: 'var(--warning)' }}>
                <strong className="ui c-warning"><Icon name="difference" /> El autor ha modificado el contenido durante la revisión</strong>
                <p className="t-small">Revisa las diferencias: la lista de comprobación se reinicia.</p>
                <ul className="col g4">{s.changesDuringReview.map((c) => <li key={c.path} className="t-small"><span className="mono b">{c.path}</span>: <span className="diff-del">{short(c.before)}</span> → <span className="diff-ins">{short(c.after)}</span></li>)}</ul>
              </section>
            )}
            {resetNotice && <Notice kind="warn">El contenido ha cambiado mientras revisabas: la lista de comprobación se ha reiniciado.</Notice>}
            <div className="split">
              <div className="col g16" style={{ minWidth: 0 }}>
                {first && (
                  <Panel title="Como lo verá el usuario" icon="smartphone" actions={<span className="t-label muted">Variante {first.id.split('.').pop()}</span>}>
                    <div className="col g12">
                      <p className="t-stmt">{first.statement}</p>
                      <p className="ui sb">{first.question}</p>
                      {first.options ? <div className="col g6">{first.options.map((o, i) => <div key={o.id} className="opt" style={{ minHeight: 44, fontSize: 16 }}><span className="lt">{String.fromCharCode(65 + i)}</span>{o.label}</div>)}</div>
                        : <div className="answer" style={{ height: 64 }}><span className="ph">0</span><span className="u">{first.answer?.unit}</span></div>}
                      {first.tts && <button type="button" className="btn btn-secondary btn-sm" onClick={() => speak(first.tts!)}><Icon name="volume_up" />Escuchar en voz alta</button>}
                    </div>
                  </Panel>
                )}
                <Panel title={s.item.kind === 'template' ? '20 variantes al azar y extremos' : 'Pregunta'} icon="table" bodyClass="tblwrap" actions={s.item.kind === 'template' ? <button type="button" className="btn btn-tertiary btn-xs" onClick={st.reload}>Otras 20</button> : undefined}>
                  <table className="tbl" aria-label="Variantes de muestra">
                    <thead><tr><th>Nivel</th><th>Datos</th><th>Respuesta</th><th>Recálculo independiente</th><th>Comprobación</th></tr></thead>
                    <tbody>{rows.map((v, i) => (
                      <tr key={`${v.id}-${i}`} data-testid="muestra">
                        <td className="mono">{v.level}</td>
                        <td className="t-small">{assignmentText(v.assignment)}</td>
                        <td className="num b">{v.answer ? qty(v.answer.value, v.answer.unit) : v.options?.find((o) => o.correct)?.label ?? '—'}</td>
                        <td className="num" data-col="recalculo">{v.recalculated ? qty(v.recalculated, v.answer?.unit) : v.answer ? qty(v.answer.value, v.answer.unit) : '—'}</td>
                        <td>{!v.matches ? <span className="chip chip-error">No coincide</span> : v.tag ? <span className="chip chip-primary">{v.tag}</span> : <span className="chip chip-success">Coincide</span>}</td>
                      </tr>
                    ))}</tbody>
                  </table>
                </Panel>
              </div>
              <div className="col g16">
                <Panel title={`Lista de comprobación · ${done} de ${total}`} icon="checklist">
                  <fieldset className="col g4" style={{ border: 0, padding: 0, margin: 0 }} disabled={!s.canValidate || !inReview}>
                    <legend className="sr-only">Lista de comprobación</legend>
                    {s.checklist.map((c) => (
                      <label key={c.key} className="check-row t-small"><input type="checkbox" checked={Boolean(checked[c.key])} onChange={(e) => setChecked({ ...checked, [c.key]: e.target.checked })} />{c.label}</label>
                    ))}
                  </fieldset>
                </Panel>
                <Panel title="Comentarios" icon="forum">
                  <div className="col g10">
                    {s.comments.length === 0 ? <p className="t-small muted">Sin comentarios.</p> : (
                      <ul className="col g8" aria-label="Comentarios">
                        {s.comments.map((c) => <li key={c.id} className="card t-small"><strong>{c.anchor ? `${c.anchor} · ` : ''}{c.author_name}</strong> · {date(c.created_at)}<p>{c.body}</p></li>)}
                      </ul>
                    )}
                    {s.canComment && (
                      <div className="col g6">
                        <Field label="Añade un comentario" id="rv-note"><textarea id="rv-note" className="input" value={note} onChange={(e) => setNote(e.target.value)} /></Field>
                        <button type="button" className="btn btn-secondary btn-sm" disabled={!note.trim() || busy} onClick={addComment}>Comentar</button>
                      </div>
                    )}
                  </div>
                </Panel>
                {isReviewer && inReview && (
                  <Panel title="Decisión" icon="gavel">
                    <div className="col g10">
                      {!s.canValidate && s.reasonCannotValidate && <Notice kind="warn" icon="block">{s.reasonCannotValidate}</Notice>}
                      {s.canValidate && (
                        <>
                          <Field label="Comentario de la decisión" id="rv-comment" help="Obligatorio para solicitar cambios o rechazar."><textarea id="rv-comment" className="input" value={comment} onChange={(e) => setComment(e.target.value)} /></Field>
                          <button type="button" className="btn btn-primary btn-sm" disabled={done < total} onClick={() => decide('validate', s)}><Icon name="verified" />Validar</button>
                          {done < total && <span className="t-small muted">Marca los {total} puntos de la lista para validar.</span>}
                          <div className="row g8">
                            <button type="button" className="btn btn-secondary btn-sm" disabled={!comment.trim()} onClick={() => decide('request_changes', s)}>Solicitar cambios</button>
                            <button type="button" className="btn btn-danger btn-sm" disabled={!comment.trim()} onClick={() => decide('reject', s)}>Rechazar</button>
                          </div>
                        </>
                      )}
                      <p className="t-small muted">La validación guarda revisor, acreditación, fecha y huella de la versión. Caduca a los 24 meses.</p>
                    </div>
                  </Panel>
                )}
                {s.reviews.length > 0 && (
                  <Panel title="Revisiones" icon="history">
                    <ul className="col g6" aria-label="Revisiones registradas">
                      {s.reviews.map((r) => <li key={r.id} className="t-small">v{r.item_version} · {r.decision === 'validate' ? 'Validado' : r.decision === 'request_changes' ? 'Cambios solicitados' : 'Rechazado'} por {r.reviewer_name}{r.accreditation ? ` (${r.accreditation})` : ''} · {date(r.created_at)}{r.expires_at ? ` · caduca el ${date(r.expires_at)}` : ''}</li>)}
                    </ul>
                  </Panel>
                )}
              </div>
            </div>
          </Page>
        );
      }}
    </Async>
  );
}
