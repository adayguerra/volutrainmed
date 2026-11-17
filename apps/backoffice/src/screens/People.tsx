/**
 * B18 · Usuarios, B19 · ficha de usuario y cuentas del back office con su rol.
 * Las acciones de soporte exigen un motivo y quedan en el registro de
 * auditoría. La organización solo ve datos individuales con el modo nominal
 * aceptado por el usuario (lo aplica la API).
 */
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { Account, Role } from '../api/types';
import { ROLE_LABELS } from '../api/types';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { DEFAULT_SECTORS, sectorName } from '../content/common';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, ReasonDialog, useAction, useAsync } from '../ui/kit';
import { ago, date } from '../ui/format';

interface UserRow { id: string; email: string | null; alias: string; sectorId: string | null; status: string; plan: string; organization: string | null; lastActivity: string | null; createdAt: string }
interface UserDetailData {
  user: UserRow; entitlements: { premium: boolean; source?: string; plan?: string; expiresAt?: string | null; validatedAt?: string };
  devices: { id: string; platform: string; model: string; app_version: string; content_version: string; last_sync_at: string | null }[];
  inquiries: { id: string; reference: string; type: string; status: string; created_at: string }[];
  grants: { days: number; reason: string; starts_at: string; ends_at: string }[];
  progress: { attempts: number; accuracy: number | null; active_days: number; critical: number; lessonsCompleted: number };
  organization: { id: string; name: string; nominal: boolean } | null;
}

const STATUS: Record<string, string> = { active: 'Activa', blocked: 'Bloqueada', deleted: 'Anonimizada' };
const PLAN: Record<string, string> = { gratuito: 'Gratis', monthly: 'Mensual', annual: 'Anual', trial: 'Prueba', premium: 'Premium', organization: 'Organización' };

export function maskEmail(e: string | null): string {
  if (!e) return '—';
  const [u, d] = e.split('@');
  return `${(u ?? '').slice(0, 1)}•••••@${d ?? ''}`;
}

export function Users() {
  const { api } = useSession();
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [query, setQuery] = useState('');
  const [plan, setPlan] = useState('');
  const [sector, setSector] = useState('');
  const st = useAsync(() => api.get<{ items: UserRow[] }>('/v1/admin/users', { q: query || undefined, plan: plan || undefined, sector: sector || undefined }), [api, query, plan, sector]);
  return (
    <Page title="Usuarios" crumbs={[{ label: 'Personas' }, { label: 'Usuarios' }]}>
      <form className="row g8 wrap" role="search" onSubmit={(e) => { e.preventDefault(); setQuery(q); }}>
        <input aria-label="Alias o correo" placeholder="Alias o correo" className="input input-sm" style={{ width: 260 }} value={q} onChange={(e) => setQ(e.target.value)} />
        <select aria-label="Sector" className="input input-sm" style={{ width: 'auto' }} value={sector} onChange={(e) => setSector(e.target.value)}><option value="">Sector: todos</option>{DEFAULT_SECTORS.filter((s) => s.id !== 'comun').map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select>
        <select aria-label="Plan" className="input input-sm" style={{ width: 'auto' }} value={plan} onChange={(e) => setPlan(e.target.value)}><option value="">Plan: todos</option><option value="premium">De pago u organización</option><option value="free">Gratis</option></select>
        <button type="submit" className="btn btn-secondary btn-sm"><Icon name="search" />Buscar</button>
      </form>
      <Panel bodyClass="tblwrap">
        <Async state={st}>
          {(d) => d.items.length === 0 ? <Empty icon="person_search" title="Ningún usuario coincide" /> : (
            <table className="tbl" aria-label="Usuarios">
              <thead><tr><th>Alias</th><th>Correo</th><th>Sector</th><th>Plan</th><th>Organización</th><th>Última actividad</th><th>Estado</th></tr></thead>
              <tbody>{d.items.map((u) => (
                <tr key={u.id} className="clickable" onClick={() => navigate(`/usuarios/${u.id}`)}>
                  <td><Link to={`/usuarios/${u.id}`}>{u.alias}</Link></td>
                  <td className="mono t-small">{maskEmail(u.email)}</td>
                  <td>{sectorName(u.sectorId)}</td>
                  <td>{PLAN[u.plan] ?? u.plan}</td>
                  <td>{u.organization ?? '—'}</td>
                  <td className="muted">{ago(u.lastActivity)}</td>
                  <td><span className={`chip${u.status === 'blocked' ? ' chip-error' : u.status === 'deleted' ? ' chip-line' : ' chip-success'}`}>{STATUS[u.status] ?? u.status}</span></td>
                </tr>
              ))}</tbody>
            </table>
          )}
        </Async>
      </Panel>
    </Page>
  );
}

type ActionId = 'grant_premium' | 'reset_access' | 'block' | 'unblock' | 'export' | 'delete';
const ACTION_LABEL: Record<ActionId, string> = { grant_premium: 'Conceder días de plan de pago', reset_access: 'Restablecer el acceso', block: 'Bloquear', unblock: 'Desbloquear', export: 'Exportar los datos', delete: 'Anonimizar la cuenta' };

export function UserDetail() {
  const { id } = useParams();
  const { api, account } = useSession();
  const { run } = useAction();
  const st = useAsync(() => api.get<UserDetailData>(`/v1/admin/users/${id}`), [api, id]);
  const [days, setDays] = useState(7);
  const [reason, setReason] = useState('');
  const [confirm, setConfirm] = useState<ActionId | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const supportOk = can(account?.role, 'supportActions');

  async function act(action: ActionId, why: string) {
    const r = await run(() => api.post<{ entitlements?: unknown; exportId?: string }>(`/v1/admin/users/${id}/actions`, { action, reason: why, days: action === 'grant_premium' ? days : undefined }));
    if (!r) return;
    setDone(action === 'grant_premium' ? `Concedidos ${days} días de Premium. La acción queda en el registro de auditoría con su motivo.`
      : action === 'delete' ? 'Datos personales suprimidos o anonimizados. La acción queda registrada en la auditoría.'
        : action === 'export' ? `Exportación preparada (${r.exportId ?? ''}). La acción queda en el registro de auditoría.`
          : `${ACTION_LABEL[action]}: hecho. La acción queda en el registro de auditoría.`);
    setReason('');
    setConfirm(null);
    st.reload();
  }

  return (
    <Async state={st}>
      {(d) => (
        <Page title={d.user.alias} crumbs={[{ label: 'Personas' }, { label: 'Usuarios', to: '/usuarios' }, { label: d.user.alias }]}
          chip={<span className={`chip${d.user.status === 'blocked' ? ' chip-error' : d.user.status === 'deleted' ? ' chip-line' : ' chip-success'}`}>{STATUS[d.user.status] ?? d.user.status}</span>}>
          {done && <Notice kind="ok">{done}</Notice>}
          <div className="split">
            <div className="col g16" style={{ minWidth: 0 }}>
              <Panel title="Perfil" icon="person">
                <dl className="grid2 t-small">
                  <div><dt className="t-label muted">Correo</dt><dd style={{ margin: 0 }} className="mono">{maskEmail(d.user.email)}</dd></div>
                  <div><dt className="t-label muted">Alta</dt><dd style={{ margin: 0 }}>{date(d.user.createdAt)}</dd></div>
                  <div><dt className="t-label muted">Sector</dt><dd style={{ margin: 0 }}>{sectorName(d.user.sectorId)}</dd></div>
                  <div><dt className="t-label muted">Plan</dt><dd style={{ margin: 0 }} data-testid="plan">{d.entitlements.premium ? `Premium${d.entitlements.source ? ` · ${d.entitlements.source}` : ''}${d.entitlements.expiresAt ? ` hasta el ${date(d.entitlements.expiresAt)}` : ''}` : 'Gratis'}</dd></div>
                  <div><dt className="t-label muted">Organización</dt><dd style={{ margin: 0 }}>{d.organization ? `${d.organization.name}${d.organization.nominal ? ' (modo nominal)' : ''}` : 'Sin organización'}</dd></div>
                </dl>
              </Panel>
              <Panel title="Dispositivos" icon="devices" bodyClass="tblwrap">
                {d.devices.length === 0 ? <Empty icon="devices" title="Sin dispositivos" /> : (
                  <table className="tbl"><thead><tr><th>Dispositivo</th><th>App</th><th>Contenido</th><th>Última sincronización</th></tr></thead>
                    <tbody>{d.devices.map((x) => <tr key={x.id}><td>{x.model} · {x.platform}</td><td className="mono">{x.app_version}</td><td className="mono">{x.content_version}</td><td>{ago(x.last_sync_at)}</td></tr>)}</tbody></table>
                )}
              </Panel>
              <Panel title="Progreso (solo lectura)" icon="monitoring">
                <div className="grid4">
                  <div className="col g4"><span className="t-label muted">Intentos</span><span className="kpi">{d.progress.attempts}</span></div>
                  <div className="col g4"><span className="t-label muted">Precisión</span><span className="kpi">{d.progress.accuracy === null ? '—' : `${d.progress.accuracy} %`}</span></div>
                  <div className="col g4"><span className="t-label muted">Días activos</span><span className="kpi">{d.progress.active_days}</span></div>
                  <div className="col g4"><span className="t-label muted">Consultas</span><span className="kpi">{d.inquiries.length}</span></div>
                </div>
              </Panel>
              {d.grants.length > 0 && (
                <Panel title="Días concedidos" icon="redeem">
                  <ul className="col g4" aria-label="Días concedidos">{d.grants.map((g, i) => <li key={i} className="t-small">{g.days} días · {g.reason} · hasta el {date(g.ends_at)}</li>)}</ul>
                </Panel>
              )}
            </div>
            {supportOk && d.user.status !== 'deleted' && (
              <Panel title="Acciones de soporte" icon="support_agent">
                <div className="col g12">
                  <Field label="Conceder días de plan de pago" id="u-days"><input id="u-days" className="input mono" type="number" min={1} max={365} value={days} onChange={(e) => setDays(Number(e.target.value))} /></Field>
                  <Field label="Motivo (obligatorio)" id="u-reason"><textarea id="u-reason" className="input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Incidencia, consulta VM-…" /></Field>
                  <p className="t-small muted">Las acciones sensibles quedan en el registro de auditoría.</p>
                  <button type="button" className="btn btn-primary btn-sm" disabled={!reason.trim() || days < 1} onClick={() => act('grant_premium', reason.trim())}>Conceder {days} días</button>
                  <button type="button" className="btn btn-secondary btn-sm" disabled={!reason.trim()} onClick={() => act('reset_access', reason.trim())}>Restablecer el acceso</button>
                  <button type="button" className="btn btn-secondary btn-sm" disabled={!reason.trim()} onClick={async () => { await act('export', reason.trim()); }}>Exportar los datos</button>
                  <button type="button" className="btn btn-secondary btn-sm" disabled={!reason.trim()} onClick={() => act(d.user.status === 'blocked' ? 'unblock' : 'block', reason.trim())}>{d.user.status === 'blocked' ? 'Desbloquear' : 'Bloquear'}</button>
                  <button type="button" className="btn btn-danger btn-sm" onClick={() => setConfirm('delete')}>Anonimizar la cuenta</button>
                </div>
              </Panel>
            )}
          </div>
          {confirm === 'delete' && (
            <ReasonDialog title="Suprimir los datos de la cuenta" danger confirmLabel="Suprimir y anonimizar" initial={reason} onClose={() => setConfirm(null)}
              description="Se suprimen o anonimizan los datos personales. Los intentos quedan anonimizados para la analítica. No se puede deshacer."
              onConfirm={(why) => act('delete', why)} />
          )}
        </Page>
      )}
    </Async>
  );
}

const ROLES = Object.keys(ROLE_LABELS) as Role[];

export function Accounts() {
  const { api } = useSession();
  const { run } = useAction();
  const st = useAsync(() => api.get<{ items: Account[] }>('/v1/admin/accounts'), [api]);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ email: '', name: '', role: 'author' as Role, sectors: '', accreditation: '', password: '' });
  return (
    <Page title="Cuentas y roles" crumbs={[{ label: 'Personas' }, { label: 'Cuentas del back office' }]}
      actions={<button type="button" className="btn btn-primary btn-sm" onClick={() => setCreating(true)}><Icon name="person_add" />Nueva cuenta</button>}>
      <Notice icon="verified_user">Siete roles con permisos distintos, aplicados también en la base de datos. Toda cuenta debe configurar el doble factor en su primer acceso.</Notice>
      <Panel bodyClass="tblwrap">
        <Async state={st}>
          {(d) => (
            <table className="tbl" aria-label="Cuentas">
              <thead><tr><th>Nombre</th><th>Correo</th><th>Rol</th><th>Sectores acreditados</th><th>Doble factor</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
              <tbody>{d.items.map((a) => (
                <tr key={a.id}>
                  <td>{a.name}</td><td className="mono t-small">{a.email}</td>
                  <td>
                    <select aria-label={`Rol de ${a.name}`} className="input input-sm" style={{ width: 'auto' }} value={a.role} onChange={async (e) => { const r = await run(() => api.patch(`/v1/admin/accounts/${a.id}`, { role: e.target.value }), 'Rol actualizado'); if (r) st.reload(); }}>
                      {ROLES.map((r) => <option key={r} value={r}>{ROLE_LABELS[r]}</option>)}
                    </select>
                  </td>
                  <td className="t-small">{a.sectors.length ? a.sectors.map((s) => sectorName(s)).join(', ') : '—'}</td>
                  <td>{a.mfaEnabled ? <span className="chip chip-success">Activo</span> : <span className="chip chip-warning">Pendiente</span>}</td>
                  <td>{a.active ? 'Activa' : 'Desactivada'}</td>
                  <td className="actions"><button type="button" className="btn btn-tertiary btn-xs" onClick={async () => { const r = await run(() => api.patch(`/v1/admin/accounts/${a.id}`, { active: !a.active }), a.active ? 'Cuenta desactivada' : 'Cuenta activada'); if (r) st.reload(); }}>{a.active ? 'Desactivar' : 'Activar'}</button></td>
                </tr>
              ))}</tbody>
            </table>
          )}
        </Async>
      </Panel>
      {creating && (
        <Modal title="Nueva cuenta del back office" onClose={() => setCreating(false)}>
          <Field label="Nombre" id="ac-name"><input id="ac-name" className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
          <Field label="Correo" id="ac-email"><input id="ac-email" className="input" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
          <Field label="Rol" id="ac-role"><select id="ac-role" className="input" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value as Role })}>{ROLES.map((r) => <option key={r} value={r}>{ROLE_LABELS[r]}</option>)}</select></Field>
          {form.role === 'reviewer' && <>
            <Field label="Sectores acreditados (separados por comas)" id="ac-sectors"><input id="ac-sectors" className="input" value={form.sectors} onChange={(e) => setForm({ ...form, sectors: e.target.value })} /></Field>
            <Field label="Acreditación" id="ac-acc"><input id="ac-acc" className="input" value={form.accreditation} onChange={(e) => setForm({ ...form, accreditation: e.target.value })} /></Field>
          </>}
          <Field label="Contraseña inicial (10 caracteres como mínimo)" id="ac-pass"><input id="ac-pass" className="input" type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></Field>
          <div className="row g8 end">
            <button type="button" className="btn btn-tertiary btn-sm" onClick={() => setCreating(false)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={!form.name || !form.email || form.password.length < 10} onClick={async () => {
              const r = await run(() => api.post('/v1/admin/accounts', { ...form, sectors: form.sectors.split(',').map((s) => s.trim()).filter(Boolean), accreditation: form.accreditation || undefined }), 'Cuenta creada: configurará el doble factor en su primer acceso');
              if (r) { setCreating(false); st.reload(); }
            }}>Crear cuenta</button>
          </div>
        </Modal>
      )}
    </Page>
  );
}

