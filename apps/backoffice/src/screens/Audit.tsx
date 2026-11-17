/**
 * B27 · Registro de auditoría: quién hizo cada acción, cuándo y con qué valores
 * anterior y posterior. Es inalterable (disparador en Postgres): la interfaz no
 * ofrece ninguna forma de modificar ni borrar entradas.
 */
import { useMemo, useState } from 'react';
import { useSession } from '../auth/session';
import { download } from '../content/common';
import { Async, Empty, Icon, Notice, Page, Panel, useAction, useAsync } from '../ui/kit';
import { date } from '../ui/format';

interface AuditRow { id: number; actor_id: string | null; actor_name: string | null; actor_role: string; action: string; entity: string; entity_id: string | null; before: unknown; after: unknown; reason: string | null; at: string }

export const ACTION_LABELS: Record<string, string> = {
  'item.create': 'Creó', 'item.update': 'Editó', 'item.submit': 'Envió a revisión', 'item.retire': 'Retiró', 'item.withdraw_now': 'Retiró un ejercicio ahora', 'item.drug_info_changed': 'Marcó un cambio del fármaco',
  'review.validate': 'Validó', 'review.request_changes': 'Solicitó cambios', 'review.reject': 'Rechazó', 'review.comment': 'Comentó',
  'release.create': 'Preparó la versión', 'release.checks': 'Ejecutó las comprobaciones', 'release.test_package': 'Generó el paquete de prueba', 'release.publish': 'Publicó la versión', 'release.rollout': 'Cambió el despliegue', 'release.rollback': 'Revirtió la versión',
  'user.grant_premium': 'Concedió días de plan', 'user.reset_access': 'Restableció el acceso', 'user.block': 'Bloqueó', 'user.unblock': 'Desbloqueó', 'user.export': 'Exportó los datos', 'user.delete': 'Suprimió los datos',
  'bo.login': 'Entró en el back office', 'account.create': 'Creó la cuenta', 'account.update': 'Cambió la cuenta', 'inquiry.reply': 'Respondió la consulta', 'inquiry.convert_to_fix': 'Convirtió la consulta en corrección',
  'org.create': 'Creó la organización', 'org.update': 'Cambió la organización', 'org.invites_sent': 'Envió invitaciones', 'org.report_viewed': 'Consultó el informe', 'structure.reorder': 'Reordenó', 'lesson.compose': 'Compuso la lección',
  'ads.params': 'Cambió la espera y la frecuencia', 'league.config_scheduled': 'Programó un cambio de ligas', 'analytics.promote_error': 'Añadió un error previsible', 'import.commit': 'Importó',
};

function fmt(v: unknown): string {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'string') return v;
  if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  const s = JSON.stringify(v);
  return s.length > 120 ? `${s.slice(0, 120)}…` : s;
}

/** Campos que cambian entre el valor anterior y el posterior (primer nivel). */
export function changes(before: unknown, after: unknown): { key: string; before: unknown; after: unknown }[] {
  if (before && after && typeof before === 'object' && typeof after === 'object' && !Array.isArray(before) && !Array.isArray(after)) {
    const b = before as Record<string, unknown>; const a = after as Record<string, unknown>;
    return [...new Set([...Object.keys(b), ...Object.keys(a)])].filter((k) => JSON.stringify(b[k]) !== JSON.stringify(a[k])).map((k) => ({ key: k, before: b[k], after: a[k] }));
  }
  if (before === null || before === undefined) return after === null || after === undefined ? [] : [{ key: '', before: undefined, after }];
  return [{ key: '', before, after }];
}

export function Audit() {
  const { api } = useSession();
  const { run } = useAction();
  const [actor, setActor] = useState('');
  const [action, setAction] = useState('');
  const [entity, setEntity] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const st = useAsync(() => api.get<{ items: AuditRow[] }>('/v1/admin/audit', { actor: actor || undefined, action: action || undefined, entity: entity || undefined, from: from || undefined, to: to ? `${to}T23:59:59Z` : undefined, limit: 300 }), [api, actor, action, entity, from, to]);
  const actors = useMemo(() => [...new Map((st.data?.items ?? []).filter((r) => r.actor_id).map((r) => [r.actor_id!, r.actor_name ?? r.actor_role])).entries()], [st.data]);
  return (
    <Page title="Registro de auditoría" crumbs={[{ label: 'Sistema' }, { label: 'Auditoría' }]}
      actions={<button type="button" className="btn btn-secondary btn-sm" onClick={async () => { const csv = await run(() => api.text('/v1/admin/audit/export')); if (csv) download('auditoria.csv', csv); }}><Icon name="download" />Exportar</button>}>
      <div className="row g8 wrap">
        <select aria-label="Persona" className="input input-sm" style={{ width: 'auto' }} value={actor} onChange={(e) => setActor(e.target.value)}><option value="">Persona: todas</option>{actors.map(([id, name]) => <option key={id} value={id}>{name}</option>)}</select>
        <select aria-label="Acción" className="input input-sm" style={{ width: 'auto' }} value={action} onChange={(e) => setAction(e.target.value)}>
          <option value="">Acción: todas</option><option value="item.">Contenido</option><option value="review.">Revisión</option><option value="release.">Publicación</option><option value="user.">Soporte a usuarios</option><option value="account.">Cuentas</option><option value="org.">Organizaciones</option><option value="bo.login">Accesos</option>
        </select>
        <input aria-label="Elemento" placeholder="Elemento (template, release…)" className="input input-sm" style={{ width: 200 }} value={entity} onChange={(e) => setEntity(e.target.value)} />
        <label className="row g6 t-small">Desde <input aria-label="Desde" type="date" className="input input-sm" style={{ width: 'auto' }} value={from} onChange={(e) => setFrom(e.target.value)} /></label>
        <label className="row g6 t-small">Hasta <input aria-label="Hasta" type="date" className="input input-sm" style={{ width: 'auto' }} value={to} onChange={(e) => setTo(e.target.value)} /></label>
      </div>
      <Notice icon="lock">Registro inalterable: nadie, tampoco la superadministración, puede modificar ni borrar sus entradas.</Notice>
      <Panel title="Registro inalterable" icon="history" bodyClass="tblwrap">
        <Async state={st}>
          {(d) => d.items.length === 0 ? <Empty title="Sin entradas para estos filtros" /> : (
            <table className="tbl" aria-label="Registro de auditoría">
              <thead><tr><th>Fecha</th><th>Persona</th><th>Acción</th><th>Elemento</th><th>Valor anterior</th><th>Valor posterior</th><th>Motivo</th></tr></thead>
              <tbody>{d.items.map((r) => {
                const ch = changes(r.before, r.after).slice(0, 4);
                return (
                  <tr key={r.id} data-testid="entrada-auditoria">
                    <td className="t-small" style={{ whiteSpace: 'nowrap' }}>{date(r.at, true)}</td>
                    <td className="t-small">{r.actor_name ?? r.actor_role}<br /><span className="muted t-label">{r.actor_role}</span></td>
                    <td className="t-small">{ACTION_LABELS[r.action] ?? r.action}</td>
                    <td className="t-small"><span className="muted">{r.entity}</span> · <span className="mono">{r.entity_id ?? '—'}</span></td>
                    <td>{ch.map((c, i) => <div key={i} className="t-small"><span className="diff-del">− {c.key ? `${c.key}: ` : ''}{fmt(c.before)}</span></div>)}</td>
                    <td>{ch.map((c, i) => <div key={i} className="t-small"><span className="diff-ins">+ {c.key ? `${c.key}: ` : ''}{fmt(c.after)}</span></div>)}</td>
                    <td className="t-small">{r.reason ?? ''}</td>
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
