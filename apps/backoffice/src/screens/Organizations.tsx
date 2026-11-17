/**
 * B20 · Organizaciones: plazas y vigencia, código de invitación y dominios,
 * grupos con itinerarios asignados, invitación masiva por archivo, informe
 * agregado de grupo (sin datos si hay menos de 5 miembros activos), modo
 * nominal informado y ligas privadas.
 */
import { useState } from 'react';
import { useSession } from '../auth/session';
import { can } from '../auth/permissions';
import { parseFile } from '../content/csv';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, useAction, useAsync } from '../ui/kit';
import { date } from '../ui/format';
import type { TreeNode } from '../api/types';

interface Org { id: string; name: string; type: string; seats: number; seatsUsed: number; valid_from: string; valid_to: string; nominal: boolean; removes_ads: boolean; invite_code: string; domains: string[]; invitesPending?: number }
interface Group { id: string; name: string; invite_code: string; itineraries: string[]; members: number }
interface OrgDetail { organization: Org; groups: Group[]; admins: { id: string; name: string; email: string }[]; invites: { id: string; email: string; status: string; created_at: string }[]; privateLeagues: { id: string; name: string; group_id: string | null }[] }
interface Report { insufficient: boolean; activeMembers: number; message?: string; members?: number; completionLessons?: number; accuracy?: number | null; skillsMastered?: string[]; individuals?: { alias: string; email: string; accuracy: number | null }[] }

function readText(f: File): Promise<string> {
  if (typeof f.text === 'function') return f.text();
  return new Promise((resolve, reject) => { const r = new FileReader(); r.onload = () => resolve(String(r.result ?? '')); r.onerror = () => reject(r.error); r.readAsText(f); });
}

/** Correos de un archivo: una columna «correo»/«email» o un correo por línea. */
export async function emailsFromFile(f: File): Promise<string[]> {
  const text = await readText(f);
  if (/[;,\t]/.test(text.split(/\r?\n/)[0] ?? '') || /\.json$/i.test(f.name)) {
    const { columns, rows } = parseFile(f.name, text);
    const col = columns.find((c) => /^(correo|email|e-mail|mail)$/i.test(c.trim())) ?? columns[0]!;
    return rows.map((r) => r[col] ?? '').filter((x) => x.trim());
  }
  const lines = text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  return /^(correo|email)$/i.test(lines[0] ?? '') ? lines.slice(1) : lines;
}

function GroupReport({ orgId, group }: { orgId: string; group: Group }) {
  const { api } = useSession();
  const st = useAsync(() => api.get<Report>(`/v1/admin/orgs/${orgId}/report`, { groupId: group.id }), [api, orgId, group.id]);
  return (
    <section className="card col g8" aria-label={`Informe del grupo ${group.name}`}>
      <strong className="ui">Informe agregado · {group.name}</strong>
      <Async state={st}>
        {(r) => r.insufficient ? <Notice kind="info" icon="shield_person">{r.message ?? 'El grupo tiene menos de 5 miembros activos: no se muestran datos agregados.'}</Notice> : (
          <>
            <div className="grid3">
              <div className="col g4"><span className="t-label muted">Lecciones completadas</span><span className="kpi" data-testid="finalizacion">{r.completionLessons}</span></div>
              <div className="col g4"><span className="t-label muted">Precisión media</span><span className="kpi" data-testid="precision">{r.accuracy === null || r.accuracy === undefined ? '—' : `${String(r.accuracy).replace('.', ',')} %`}</span></div>
              <div className="col g4"><span className="t-label muted">Miembros activos</span><span className="kpi">{r.activeMembers} de {r.members}</span></div>
            </div>
            <p className="t-small" data-testid="habilidades">Habilidades dominadas por el grupo: {r.skillsMastered?.length ? r.skillsMastered.join(', ') : 'ninguna todavía'}</p>
            {r.individuals ? (
              <div className="tblwrap"><table className="tbl" aria-label="Datos individuales (modo nominal)"><thead><tr><th>Alias</th><th>Correo</th><th>Precisión</th></tr></thead>
                <tbody>{r.individuals.map((i) => <tr key={i.alias}><td>{i.alias}</td><td className="mono t-small">{i.email}</td><td>{i.accuracy ?? '—'} %</td></tr>)}</tbody></table></div>
            ) : <p className="t-small muted">Solo datos agregados del grupo, sin nombres.</p>}
          </>
        )}
      </Async>
    </section>
  );
}

function OrgDetailView({ id, onBack }: { id: string; onBack: () => void }) {
  const { api, account } = useSession();
  const { run, busy } = useAction();
  const st = useAsync(() => api.get<OrgDetail>(`/v1/admin/orgs/${id}`), [api, id]);
  const its = useAsync(() => api.get<{ tree: TreeNode[] }>('/v1/admin/structure').then((t) => t.tree.flatMap((s) => s.children.map((c) => ({ id: c.id, name: c.title })))).catch(() => [] as { id: string; name: string }[]), [api]);
  const [report, setReport] = useState<string | null>(null);
  const [groupName, setGroupName] = useState('');
  const [inviteGroup, setInviteGroup] = useState('');
  const [inviteResult, setInviteResult] = useState<{ sent: number; invalid: { row: number; value: string }[] } | null>(null);
  const [leagueName, setLeagueName] = useState('');
  const [leagueGroup, setLeagueGroup] = useState('');
  const manage = can(account?.role, 'manageGroups');
  const editOrg = can(account?.role, 'editOrg');

  async function invite(file: File) {
    const emails = await emailsFromFile(file);
    const r = await run(() => api.post<{ sent: number; invalid: { row: number; value: string }[] }>(`/v1/admin/orgs/${id}/invites`, { emails, groupId: inviteGroup || undefined }), (x) => `Se han enviado ${x.sent} invitaciones`);
    if (r) { setInviteResult(r); st.reload(); }
  }

  return (
    <Async state={st}>
      {(d) => {
        const o = d.organization;
        return (
          <div className="col g16">
            <button type="button" className="btn btn-tertiary btn-xs" style={{ alignSelf: 'flex-start' }} onClick={onBack}><Icon name="arrow_back" />Todas las organizaciones</button>
            <div className="split">
              <div className="col g16" style={{ minWidth: 0 }}>
                <Panel title={`${o.name} · datos y plan`} icon="apartment">
                  <dl className="grid2 t-small">
                    <div><dt className="t-label muted">Tipo</dt><dd style={{ margin: 0 }}>{o.type}</dd></div>
                    <div><dt className="t-label muted">Plazas</dt><dd style={{ margin: 0 }} className="mono" data-testid="plazas">{o.seatsUsed} / {o.seats}</dd></div>
                    <div><dt className="t-label muted">Vigencia</dt><dd style={{ margin: 0 }}>{date(o.valid_from)} – {date(o.valid_to)}</dd></div>
                    <div><dt className="t-label muted">Código de invitación</dt><dd style={{ margin: 0 }} className="mono b">{o.invite_code}</dd></div>
                    <div><dt className="t-label muted">Dominios de correo</dt><dd style={{ margin: 0 }}>{o.domains.length ? o.domains.map((x) => `@${x}`).join(', ') : '—'}</dd></div>
                    <div><dt className="t-label muted">Sin anuncios</dt><dd style={{ margin: 0 }}>{o.removes_ads ? 'Sí: las plazas tienen los derechos de Premium' : 'No'}</dd></div>
                  </dl>
                  {editOrg && (
                    <div className="row g8 wrap" style={{ marginTop: 12 }}>
                      <button type="button" className="btn btn-secondary btn-xs" onClick={async () => { const n = window.prompt('Número de plazas', String(o.seats)); if (n && Number(n) > 0) { const r = await run(() => api.patch(`/v1/admin/orgs/${id}`, { seats: Number(n) }), 'Plazas actualizadas'); if (r) st.reload(); } }}>Cambiar plazas</button>
                    </div>
                  )}
                </Panel>
                <Panel title="Grupos e informe agregado" icon="groups" bodyClass="tblwrap">
                  {d.groups.length === 0 ? <Empty icon="groups" title="Sin grupos" /> : (
                    <table className="tbl" aria-label="Grupos">
                      <thead><tr><th>Grupo</th><th className="num">Miembros</th><th>Itinerarios asignados</th><th>Código</th><th><span className="sr-only">Acciones</span></th></tr></thead>
                      <tbody>{d.groups.map((g) => (
                        <tr key={g.id}>
                          <td>{g.name}</td><td className="num">{g.members}</td>
                          <td>
                            {manage ? (
                              <select aria-label={`Itinerarios del grupo ${g.name}`} className="input input-sm" multiple size={Math.min(3, Math.max(2, (its.data ?? []).length))} value={g.itineraries}
                                onChange={async (e) => { const v = [...e.target.selectedOptions].map((x) => x.value); const r = await run(() => api.patch(`/v1/admin/orgs/${id}/groups/${g.id}`, { itineraries: v }), 'Itinerarios asignados al grupo'); if (r) st.reload(); }}>
                                {(its.data ?? []).map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
                              </select>
                            ) : g.itineraries.join(', ') || '—'}
                          </td>
                          <td className="mono">{g.invite_code}</td>
                          <td className="actions"><button type="button" className="btn btn-secondary btn-xs" onClick={() => setReport(report === g.id ? null : g.id)}>{report === g.id ? 'Ocultar informe' : 'Ver informe'}</button></td>
                        </tr>
                      ))}</tbody>
                    </table>
                  )}
                  <div style={{ padding: 16 }} className="col g12">
                    {report && <GroupReport orgId={id} group={d.groups.find((g) => g.id === report)!} />}
                    {manage && (
                      <div className="row g8 wrap ai-end">
                        <Field label="Nuevo grupo" id="g-name"><input id="g-name" className="input input-sm" value={groupName} onChange={(e) => setGroupName(e.target.value)} /></Field>
                        <button type="button" className="btn btn-secondary btn-sm" disabled={!groupName.trim() || busy} onClick={async () => { const r = await run(() => api.post(`/v1/admin/orgs/${id}/groups`, { name: groupName.trim() }), 'Grupo creado'); if (r) { setGroupName(''); st.reload(); } }}><Icon name="add" />Crear grupo</button>
                      </div>
                    )}
                  </div>
                </Panel>
                {manage && (
                  <Panel title="Invitar por archivo" icon="forward_to_inbox">
                    <div className="col g10">
                      <div className="row g8 wrap ai-end">
                        <Field label="Grupo de destino" id="inv-group"><select id="inv-group" className="input input-sm" value={inviteGroup} onChange={(e) => setInviteGroup(e.target.value)}><option value="">Sin grupo</option>{d.groups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}</select></Field>
                        <Field label="Archivo de correos (CSV o un correo por línea)" id="inv-file"><input id="inv-file" type="file" accept=".csv,.txt,.json,text/csv,text/plain" className="input" style={{ paddingTop: 12 }} onChange={(e) => { const f = e.target.files?.[0]; if (f) void invite(f); }} /></Field>
                      </div>
                      {inviteResult && (
                        <div className="col g6" role="status">
                          <Notice kind="ok">Se han enviado {inviteResult.sent} invitaciones.</Notice>
                          {inviteResult.invalid.length > 0 && (
                            <>
                              <Notice kind="warn">{inviteResult.invalid.length} filas con error no se han enviado:</Notice>
                              <ul className="col g4" aria-label="Filas con error">{inviteResult.invalid.map((r) => <li key={r.row} className="t-small mono">Fila {r.row}: {r.value}</li>)}</ul>
                            </>
                          )}
                        </div>
                      )}
                    </div>
                  </Panel>
                )}
              </div>
              <div className="col g16">
                <Panel title="Qué ve la organización" icon="visibility">
                  <div className="col g8 t-small">
                    <label className="check-row"><input type="radio" name="vis" checked={!o.nominal} disabled={!editOrg} onChange={async () => { const r = await run(() => api.patch(`/v1/admin/orgs/${id}`, { nominal: false }), 'Solo datos agregados'); if (r) st.reload(); }} />Solo datos agregados del grupo. Es la opción por defecto.</label>
                    <label className="check-row"><input type="radio" name="vis" checked={o.nominal} disabled={!editOrg} onChange={async () => { const r = await run(() => api.patch(`/v1/admin/orgs/${id}`, { nominal: true }), 'Modo nominal activado: se informa a cada usuario antes de unirse'); if (r) st.reload(); }} />Modo nominal: datos individuales. Se informa a cada usuario antes de unirse y solo se ven los de quien lo acepta.</label>
                  </div>
                </Panel>
                <Panel title="Administradores" icon="admin_panel_settings">
                  {d.admins.length ? <ul className="col g4">{d.admins.map((a) => <li key={a.id} className="t-small">{a.name} · <span className="mono">{a.email}</span></li>)}</ul> : <p className="t-small muted">Sin administradores.</p>}
                </Panel>
                <Panel title="Ligas privadas" icon="emoji_events">
                  <div className="col g8">
                    {d.privateLeagues.length ? <ul className="col g4" aria-label="Ligas privadas">{d.privateLeagues.map((l) => <li key={l.id} className="t-small">{l.name}{l.group_id ? ` · ${d.groups.find((g) => g.id === l.group_id)?.name ?? ''}` : ''}</li>)}</ul> : <p className="t-small muted">Ninguna liga privada.</p>}
                    {manage && (
                      <>
                        <Field label="Nombre de la liga" id="lg-name"><input id="lg-name" className="input input-sm" value={leagueName} onChange={(e) => setLeagueName(e.target.value)} /></Field>
                        <Field label="Grupo" id="lg-group"><select id="lg-group" className="input input-sm" value={leagueGroup} onChange={(e) => setLeagueGroup(e.target.value)}><option value="">Toda la organización</option>{d.groups.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}</select></Field>
                        <button type="button" className="btn btn-secondary btn-sm" disabled={!leagueName.trim()} onClick={async () => { const r = await run(() => api.post(`/v1/admin/orgs/${id}/private-leagues`, { name: leagueName.trim(), groupId: leagueGroup || undefined }), 'Liga privada creada: participan con alias y de forma voluntaria'); if (r) { setLeagueName(''); st.reload(); } }}>Crear liga privada</button>
                      </>
                    )}
                  </div>
                </Panel>
              </div>
            </div>
          </div>
        );
      }}
    </Async>
  );
}

export function Organizations() {
  const { api, account } = useSession();
  const { run } = useAction();
  const st = useAsync(() => api.get<{ items: Org[] }>('/v1/admin/orgs'), [api]);
  const [selected, setSelected] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [form, setForm] = useState({ name: '', type: 'universidad', seats: 50, validFrom: new Date().toISOString().slice(0, 10), validTo: `${new Date().getFullYear() + 1}-08-31`, domains: '', nominal: false });
  const only = account?.role === 'org_admin' && st.data?.items.length === 1 ? st.data.items[0]!.id : null;
  const current = selected ?? only;
  return (
    <Page title="Organizaciones" crumbs={[{ label: 'Personas' }, { label: 'Organizaciones' }]}
      actions={can(account?.role, 'createOrg') ? <button type="button" className="btn btn-primary btn-sm" onClick={() => setCreating(true)}><Icon name="add" />Nueva organización</button> : undefined}>
      {current ? <OrgDetailView id={current} onBack={() => setSelected(null)} /> : (
        <Panel bodyClass="tblwrap">
          <Async state={st}>
            {(d) => d.items.length === 0 ? <Empty icon="apartment" title="Sin organizaciones" /> : (
              <table className="tbl" aria-label="Organizaciones">
                <thead><tr><th>Nombre</th><th>Tipo</th><th>Plazas</th><th>Vigencia</th><th>Modo</th><th className="num">Invitaciones pendientes</th></tr></thead>
                <tbody>{d.items.map((o) => (
                  <tr key={o.id} className="clickable" onClick={() => setSelected(o.id)}>
                    <td><button type="button" className="link" style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer' }} onClick={() => setSelected(o.id)}>{o.name}</button></td>
                    <td>{o.type}</td><td className="mono">{o.seatsUsed} / {o.seats}</td><td>{date(o.valid_from)} – {date(o.valid_to)}</td>
                    <td>{o.nominal ? 'Nominal' : 'Agregado'}</td><td className="num">{o.invitesPending ?? 0}</td>
                  </tr>
                ))}</tbody>
              </table>
            )}
          </Async>
        </Panel>
      )}
      {creating && (
        <Modal title="Nueva organización" onClose={() => setCreating(false)}>
          <Field label="Nombre" id="o-name"><input id="o-name" className="input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></Field>
          <div className="grid2">
            <Field label="Tipo" id="o-type"><select id="o-type" className="input" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}><option value="universidad">Universidad</option><option value="hospital">Hospital</option><option value="academia">Academia</option><option value="clinica">Clínica veterinaria</option></select></Field>
            <Field label="Plazas" id="o-seats"><input id="o-seats" className="input mono" type="number" min={1} value={form.seats} onChange={(e) => setForm({ ...form, seats: Number(e.target.value) })} /></Field>
            <Field label="Desde" id="o-from"><input id="o-from" className="input" type="date" value={form.validFrom} onChange={(e) => setForm({ ...form, validFrom: e.target.value })} /></Field>
            <Field label="Hasta" id="o-to"><input id="o-to" className="input" type="date" value={form.validTo} onChange={(e) => setForm({ ...form, validTo: e.target.value })} /></Field>
          </div>
          <Field label="Dominios de correo autorizados (separados por comas)" id="o-dom"><input id="o-dom" className="input" value={form.domains} onChange={(e) => setForm({ ...form, domains: e.target.value })} /></Field>
          <label className="check-row t-small"><input type="checkbox" checked={form.nominal} onChange={(e) => setForm({ ...form, nominal: e.target.checked })} />Modo nominal (se informa a cada usuario antes de unirse)</label>
          <div className="row g8 end">
            <button type="button" className="btn btn-tertiary btn-sm" onClick={() => setCreating(false)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={!form.name.trim() || form.seats < 1} onClick={async () => {
              const r = await run(() => api.post<{ organization: Org }>('/v1/admin/orgs', { ...form, domains: form.domains.split(',').map((x) => x.trim()).filter(Boolean) }), 'Organización creada');
              if (r) { setCreating(false); st.reload(); setSelected(r.organization.id); }
            }}>Crear</button>
          </div>
        </Modal>
      )}
    </Page>
  );
}
