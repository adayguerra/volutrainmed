/**
 * B02 · Panel de control por rol y B03 · panel en una instalación nueva.
 * Cada rol ve primero su trabajo pendiente: el revisor, las revisiones de sus
 * sectores; el autor, sus borradores y los cambios solicitados.
 */
import { Link } from 'react-router-dom';
import type { Role } from '../api/types';
import { useSession } from '../auth/session';
import { canAccess } from '../auth/permissions';
import { Async, Empty, Icon, Page, Panel, useAsync } from '../ui/kit';
import { ago, num, pct } from '../ui/format';

export interface DashboardData {
  role: Role; empty: boolean;
  onboarding: { step: number; title: string; done: boolean }[] | null;
  myWork: {
    drafts: { id: string; title: string; state: string; kind: string; updatedAt: string }[];
    pendingReviews: { id: string; title: string; kind: string; sectorId: string | null; exerciseTypeId: string | null; since: string }[];
    changesRequested: { id: string; title: string }[];
  };
  alerts: { severity: 'alta' | 'media' | 'baja'; itemId: string; title: string; reason: string; sectorId?: string | null; exerciseTypeId?: string | null }[];
  expiredNow: number;
  catalog: { sector_id: string | null; published: number; total: number }[];
  activity: { users: number; sessions: number; accuracy: number | null } | null;
  lastRelease: { number: string; published_at: string; rollout_pct: number } | null;
  inquiriesOpen: number; updatedAt: string;
}

const ONBOARDING_HELP: Record<number, { text: string; to: string }> = {
  1: { text: 'Vocabulario, notación de unidades, especies e instrumentos.', to: '/estructura' },
  2: { text: 'Recorrido con objetivo formativo y sus unidades.', to: '/estructura' },
  3: { text: 'Variables, fórmula con comprobación dimensional y explicación.', to: '/plantillas/nueva' },
  4: { text: 'Un experto distinto del autor la valida.', to: '/biblioteca' },
  5: { text: 'Se generan las variantes y el paquete firmado.', to: '/publicacion' },
};

function itemLink(kind: string, id: string) {
  return kind === 'question' ? `/preguntas/${id}` : kind === 'template' ? `/plantillas/${id}` : `/biblioteca?q=${encodeURIComponent(id)}`;
}

function Onboarding({ steps }: { steps: NonNullable<DashboardData['onboarding']> }) {
  const done = steps.filter((s) => s.done).length;
  const next = steps.find((s) => !s.done)?.step;
  return (
    <Panel title={`Primeros pasos · ${done} de ${steps.length}`} icon="flag" id="onboarding">
      <ol className="col g12" aria-label="Guía de cinco pasos">
        {steps.map((s) => (
          <li key={s.step} className="row g12 card" style={s.step === next ? { borderColor: 'var(--primary)', borderWidth: 2 } : undefined}>
            <span className="row center ui b" style={{ width: 32, height: 32, borderRadius: '50%', flex: 'none', background: s.done ? 'var(--success-tint)' : 'var(--surface-2)', color: s.done ? 'var(--success)' : 'var(--fg)' }}>
              {s.done ? <Icon name="check" /> : s.step}
            </span>
            <span className="col g4 grow"><strong className="ui">{s.title}</strong><span className="t-small muted">{ONBOARDING_HELP[s.step]?.text}</span></span>
            {s.done ? <span className="chip chip-success">Hecho</span> : s.step === next ? <Link className="btn btn-primary btn-sm" to={ONBOARDING_HELP[s.step]?.to ?? '/'}>Empezar</Link> : null}
          </li>
        ))}
      </ol>
      <p className="t-small muted" style={{ marginTop: 16 }}>Nada llega a los usuarios sin la validación de un revisor experto distinto del autor. Puedes volver a esta guía desde el panel.</p>
    </Panel>
  );
}

function WorkList<T extends { id: string; title: string }>({ title, icon, items, to, right, empty, testId }: { title: string; icon: string; items: T[]; to: (i: T) => string; right?: (i: T) => string; empty: string; testId: string }) {
  return (
    <section className="panel col" data-testid={testId} aria-label={title}>
      <div className="panel-h"><Icon name={icon} className="c-primary" /><h2 className="grow" style={{ font: 'inherit', margin: 0 }}>{title}</h2><span className="kpi" style={{ fontSize: 22 }}>{items.length}</span></div>
      <ul className="panel-b col">
        {items.length === 0 && <li className="t-small muted">{empty}</li>}
        {items.slice(0, 6).map((i) => (
          <li key={i.id} className="row g8 t-small" style={{ minHeight: 34 }}>
            <Link to={to(i)} className="grow" style={{ color: 'var(--fg)' }}>{i.title}</Link>
            {right && <span className="muted t-label">{right(i)}</span>}
          </li>
        ))}
      </ul>
    </section>
  );
}

const SEV: Record<string, string> = { alta: 'chip chip-error', media: 'chip chip-warning', baja: 'chip' };

export function Dashboard() {
  const { api, account } = useSession();
  const state = useAsync(() => api.get<DashboardData>('/v1/admin/dashboard'), [api]);
  const role = account?.role;
  return (
    <Page title={state.data?.empty ? 'Te damos la bienvenida' : 'Panel de control'} crumbs={[{ label: 'Inicio' }]}>
      <Async state={state}>
        {(d) => {
          const drafts = <WorkList key="drafts" testId="panel-borradores" title="Mis borradores" icon="edit" items={d.myWork.drafts} to={(i) => itemLink(i.kind, i.id)} right={(i) => ago(i.updatedAt)} empty="No tienes borradores." />;
          const reviews = <WorkList key="reviews" testId="panel-revisiones" title={role === 'reviewer' ? 'Revisiones pendientes de tus sectores' : 'Revisiones pendientes'} icon="visibility" items={d.myWork.pendingReviews} to={(i) => `/revision/${i.id}`} right={(i) => `${i.exerciseTypeId ? `${i.exerciseTypeId} · ` : ''}${ago(i.since)}`} empty="No hay revisiones pendientes." />;
          const changes = <WorkList key="changes" testId="panel-cambios" title="Cambios solicitados" icon="undo" items={d.myWork.changesRequested} to={(i) => `/biblioteca?q=${encodeURIComponent(i.id)}`} empty="Ningún contenido con cambios solicitados." />;
          const order = role === 'reviewer' ? [reviews, changes] : role === 'author' ? [drafts, changes, reviews] : canAccess(role, 'biblioteca') ? [drafts, reviews, changes] : [];
          return (
            <>
              {d.empty && d.onboarding && <Onboarding steps={d.onboarding} />}
              {order.length > 0 && <div className="grid3">{order}</div>}
              {canAccess(role, 'analitica') && (
                <Panel title="Alertas de calidad" icon="warning" id="alertas" bodyClass="tblwrap" actions={<span className="t-label muted">Actualizado {ago(d.updatedAt)}</span>}>
                  {d.alerts.length === 0 ? <Empty icon="task_alt" title="Sin alertas de calidad" /> : (
                    <table className="tbl">
                      <thead><tr><th>Gravedad</th><th>Elemento</th><th>Motivo</th><th>Tipo y sector</th></tr></thead>
                      <tbody>
                        {d.alerts.map((a, i) => (
                          <tr key={`${a.itemId}-${i}`}>
                            <td><span className={SEV[a.severity] ?? 'chip'}>{a.severity[0]!.toUpperCase() + a.severity.slice(1)}</span></td>
                            <td><Link to={`/analitica/${a.itemId}`}>{a.title}</Link></td>
                            <td>{a.reason}</td>
                            <td className="muted">{[a.exerciseTypeId, a.sectorId].filter(Boolean).join(' · ') || '—'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </Panel>
              )}
              <div className="grid2">
                {canAccess(role, 'biblioteca') && (
                  <Panel title="Estado del catálogo" icon="inventory_2" bodyClass="tblwrap">
                    <table className="tbl">
                      <thead><tr><th>Sector</th><th className="num">Publicados</th><th className="num">Total</th></tr></thead>
                      <tbody>{d.catalog.map((c) => <tr key={c.sector_id ?? 'x'}><td>{c.sector_id ?? 'Sin sector'}</td><td className="num">{c.published}</td><td className="num">{c.total}</td></tr>)}</tbody>
                    </table>
                  </Panel>
                )}
                <Panel title="Actividad · 7 días" icon="monitoring">
                  <div className="grid3">
                    <div className="col g4"><span className="t-label muted">Usuarios activos</span><span className="kpi">{num(d.activity?.users ?? 0, 0)}</span></div>
                    <div className="col g4"><span className="t-label muted">Sesiones</span><span className="kpi">{num(d.activity?.sessions ?? 0, 0)}</span></div>
                    <div className="col g4"><span className="t-label muted">Precisión media</span><span className="kpi">{pct(d.activity?.accuracy ?? null)}</span></div>
                  </div>
                  {canAccess(role, 'consultas') && <p className="t-small" style={{ marginTop: 12 }}><Link to="/consultas">{d.inquiriesOpen} consultas abiertas</Link></p>}
                </Panel>
              </div>
              {d.lastRelease && (
                <div className="card row g12 wrap">
                  <Icon name="deployed_code" className="c-primary" />
                  <span className="grow">Última publicación: <strong className="mono">{d.lastRelease.number}</strong> · {ago(d.lastRelease.published_at)} · al {d.lastRelease.rollout_pct} %</span>
                  <Link className="btn btn-secondary btn-sm" to="/publicacion">Preparar publicación</Link>
                </div>
              )}
            </>
          );
        }}
      </Async>
    </Page>
  );
}
