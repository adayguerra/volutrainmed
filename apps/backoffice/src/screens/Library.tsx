/**
 * B05 · Biblioteca de plantillas y preguntas, con filtros, archivo de lo
 * retirado e historial de versiones. Nada se borra: se retira y se archiva.
 */
import { useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import type { Item, ItemDetail } from '../api/types';
import { STATE_LABELS } from '../api/types';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { DEFAULT_SECTORS, SKILLS, isExpired, sectorName } from '../content/common';
import { Async, Empty, Icon, Loading, Modal, Page, Panel, ReasonDialog, StateChip, useAction, useAsync } from '../ui/kit';
import { ago, date } from '../ui/format';

type LibItem = Item<{ exerciseTypeId?: string; skillId?: string }>;

export function itemPath(i: Pick<Item, 'kind' | 'id'>) {
  return i.kind === 'question' ? `/preguntas/${i.id}` : `/plantillas/${i.id}`;
}

function History({ id, onClose }: { id: string; onClose: () => void }) {
  const { api } = useSession();
  const st = useAsync(() => api.get<ItemDetail>(`/v1/admin/items/${id}`), [api, id]);
  return (
    <Modal title="Historial de versiones" onClose={onClose}>
      {st.loading ? <Loading /> : st.data ? (
        <div className="col g12">
          <ul className="col g8" aria-label="Versiones">
            {st.data.versions.map((v) => (
              <li key={v.version} className="row g8 card"><span className="mono b">v{v.version}</span><StateChip state={v.state} /><span className="grow t-small muted">{date(v.updatedAt, true)}</span></li>
            ))}
          </ul>
          {st.data.reviews.length > 0 && (
            <ul className="col g6" aria-label="Revisiones">
              {st.data.reviews.map((r) => <li key={r.id} className="t-small">v{r.item_version} · {r.decision === 'validate' ? 'Validado' : r.decision === 'request_changes' ? 'Cambios solicitados' : 'Rechazado'} por {r.reviewer_name} · {date(r.created_at)}{r.comment ? ` · «${r.comment}»` : ''}</li>)}
            </ul>
          )}
        </div>
      ) : null}
      <div className="row end"><button type="button" className="btn btn-secondary btn-sm" onClick={onClose}>Cerrar</button></div>
    </Modal>
  );
}

export function Library() {
  const { api, account } = useSession();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [q, setQ] = useState(params.get('q') ?? '');
  const [kind, setKind] = useState('template,question');
  const [state, setState] = useState('');
  const [sector, setSector] = useState('');
  const [skill, setSkill] = useState('');
  const [type, setType] = useState('');
  const [archive, setArchive] = useState(params.get('archivo') === '1');
  const [history, setHistory] = useState<string | null>(null);
  const [retiring, setRetiring] = useState<LibItem | null>(null);
  const { run } = useAction();
  const canCreate = can(account?.role, 'createContent');
  const canRetire = can(account?.role, 'retire');
  const list = useAsync(
    () => api.get<{ items: LibItem[] }>('/v1/admin/items', { kind, q: params.get('q') ?? undefined, state: archive ? 'retired' : state || undefined, sector: sector || undefined }),
    [api, kind, state, sector, archive, params.get('q')],
  );
  const rows = (list.data?.items ?? []).filter((i) => (!skill || i.data.skillId === skill) && (!type || i.data.exerciseTypeId === type));
  const types = [...new Set((list.data?.items ?? []).map((i) => i.data.exerciseTypeId).filter(Boolean))].sort() as string[];

  return (
    <Page title={archive ? 'Archivo' : 'Biblioteca'} crumbs={[{ label: 'Contenido' }, { label: 'Biblioteca' }]}
      actions={canCreate ? (
        <>
          <Link className="btn btn-secondary btn-sm" to="/preguntas/nueva"><Icon name="add" />Nueva pregunta</Link>
          <Link className="btn btn-primary btn-sm" to="/plantillas/nueva"><Icon name="add" />Nueva plantilla</Link>
        </>
      ) : undefined}>
      <form className="row g8 wrap" role="search" onSubmit={(e) => { e.preventDefault(); const p = new URLSearchParams(params); if (q) p.set('q', q); else p.delete('q'); setParams(p); }}>
        <input aria-label="Buscar por nombre o fármaco" placeholder="Buscar por nombre o fármaco" className="input input-sm" style={{ width: 280 }} value={q} onChange={(e) => setQ(e.target.value)} />
        <select aria-label="Clase" className="input input-sm" style={{ width: 'auto' }} value={kind} onChange={(e) => setKind(e.target.value)}>
          <option value="template,question">Clase: todas</option><option value="template">Plantillas</option><option value="question">Preguntas</option>
        </select>
        <select aria-label="Sector" className="input input-sm" style={{ width: 'auto' }} value={sector} onChange={(e) => setSector(e.target.value)}>
          <option value="">Sector: todos</option>{DEFAULT_SECTORS.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
        </select>
        <select aria-label="Habilidad" className="input input-sm" style={{ width: 'auto' }} value={skill} onChange={(e) => setSkill(e.target.value)}>
          <option value="">Habilidad: todas</option>{SKILLS.map((s) => <option key={s.id} value={s.id}>{s.id} · {s.name}</option>)}
        </select>
        <select aria-label="Tipo" className="input input-sm" style={{ width: 'auto' }} value={type} onChange={(e) => setType(e.target.value)}>
          <option value="">Tipo: todos</option>{types.map((t) => <option key={t}>{t}</option>)}
        </select>
        {!archive && (
          <select aria-label="Estado" className="input input-sm" style={{ width: 'auto' }} value={state} onChange={(e) => setState(e.target.value)}>
            <option value="">Estado: todos</option>{['draft', 'in_review', 'changes_requested', 'validated', 'published'].map((s) => <option key={s} value={s}>{STATE_LABELS[s]}</option>)}
          </select>
        )}
        <button type="submit" className="btn btn-secondary btn-sm"><Icon name="search" />Buscar</button>
        <button type="button" className="btn btn-tertiary btn-sm" aria-pressed={archive} onClick={() => setArchive(!archive)}><Icon name="inventory_2" />{archive ? 'Volver a la biblioteca' : 'Ver archivo'}</button>
      </form>
      <Panel bodyClass="tblwrap">
        <Async state={list}>
          {() => rows.length === 0 ? <Empty title={archive ? 'El archivo está vacío' : 'Sin resultados'} /> : (
            <table className="tbl">
              <thead><tr><th>Nombre</th><th>Clase</th><th>Tipo</th><th>Sector</th><th>Habilidad</th><th>Estado</th><th>Autor</th><th>Versión</th><th>Actualizado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
              <tbody>
                {rows.map((i) => (
                  <tr key={i.id} className="clickable" onClick={(e) => { if ((e.target as HTMLElement).closest('button,a')) return; navigate(itemPath(i)); }}>
                    <td><Link to={itemPath(i)}>{i.title}</Link></td>
                    <td>{i.kind === 'template' ? 'Plantilla' : 'Pregunta'}</td>
                    <td className="mono">{i.data.exerciseTypeId ?? '—'}</td>
                    <td>{sectorName(i.sectorId)}</td>
                    <td className="mono">{i.data.skillId ?? '—'}</td>
                    <td><StateChip state={i.state} expired={i.state !== 'retired' && isExpired(i)} /></td>
                    <td>{i.authorName ?? '—'}</td>
                    <td className="mono">v{i.version}</td>
                    <td className="muted">{ago(i.updatedAt)}</td>
                    <td className="actions">
                      <button type="button" className="btn btn-tertiary btn-xs" onClick={() => setHistory(i.id)}>Historial</button>
                      {canRetire && i.state !== 'retired' && <button type="button" className="btn btn-danger btn-xs" onClick={() => setRetiring(i)}>Retirar</button>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Async>
      </Panel>
      <p className="t-small muted">Nada se borra: el contenido se retira y se archiva. Los cambios sobre contenido publicado crean una versión nueva en borrador.</p>
      {history && <History id={history} onClose={() => setHistory(null)} />}
      {retiring && (
        <ReasonDialog title={`Retirar «${retiring.title}»`} description="Deja de publicarse en la siguiente versión y queda consultable en el archivo con su historial." confirmLabel="Retirar" danger
          onClose={() => setRetiring(null)}
          onConfirm={async (reason) => { const r = await run(() => api.post(`/v1/admin/items/${retiring.id}/retire`, { reason }), 'Retirado y archivado'); setRetiring(null); if (r) list.reload(); }} />
      )}
    </Page>
  );
}
