/**
 * B23 · Gestión de logros y B24 · configuración de ligas.
 * Los logros se definen sin código (métrica, operador, valor y ámbito), se
 * prueban con un usuario de ejemplo y siguen el ciclo de revisión y
 * publicación. Los cambios de reglas de las ligas entran en vigor al empezar la
 * semana siguiente, nunca a mitad de semana.
 */
import { useState } from 'react';
import type { AchievementMetric, LeagueConfig } from '@vtm/contracts';
import type { Item } from '../api/types';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, ReasonDialog, StateChip, useAction, useAsync } from '../ui/kit';
import { ago, date } from '../ui/format';

export const METRICS: Record<AchievementMetric, string> = {
  streak_days: 'Días de racha', correct_in_row: 'Aciertos seguidos', skills_mastered: 'Habilidades dominadas', handsfree_sessions: 'Sesiones manos libres',
  valid_timetrial: 'Contrarrelojes válidas', no_critical_exercises: 'Ejercicios seguidos sin error crítico', lessons_completed: 'Lecciones completadas', units_mastered: 'Unidades dominadas',
};
const CATEGORIES = [['constancia', 'Constancia'], ['precision', 'Precisión'], ['agilidad', 'Agilidad'], ['dominio', 'Dominio']] as const;
const OPS = [['>=', '≥'], ['>', '>'], ['==', '=']] as const;

interface Achievement { id?: string; name: string; description: string; category: string; icon: string; condition: { metric: AchievementMetric; op: '>=' | '>' | '=='; value: number; scope: 'global' | 'sector' }; secret: boolean; retroactive: boolean; endsAt?: string | null }

function emptyAchievement(): Achievement {
  return { name: '', description: '', category: 'constancia', icon: 'emoji_events', condition: { metric: 'streak_days', op: '>=', value: 7, scope: 'global' }, secret: false, retroactive: true, endsAt: null };
}

function AchievementEditor({ item, onSaved }: { item: Item<Achievement> | null; onSaved: (id: string) => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [a, setA] = useState<Achievement>(() => (item ? { ...emptyAchievement(), ...item.data } : emptyAchievement()));
  const [userId, setUserId] = useState('');
  const [sample, setSample] = useState('');
  const [test, setTest] = useState<{ obtains: boolean; message: string } | null>(null);
  const setC = (p: Partial<Achievement['condition']>) => setA({ ...a, condition: { ...a.condition, ...p } });
  async function save() {
    const { id: _o, ...data } = a;
    void _o;
    const r = item
      ? await run(() => api.put<{ item: Item }>(`/v1/admin/items/${item.id}`, { data: { ...data, id: item.id } }), (x) => (x.item.version > item.version ? `Creada la versión ${x.item.version} en borrador: llegará a las apps con la siguiente publicación` : 'Logro guardado en borrador'))
      : await run(() => api.post<{ item: Item }>('/v1/admin/items', { kind: 'achievement', data }), 'Logro creado en borrador: tras su revisión llega a las apps con la siguiente publicación');
    if (r) onSaved(r.item.id);
  }
  async function runTest() {
    const body = userId.trim() ? { condition: a.condition, userId: userId.trim() } : { condition: a.condition, sample: { [a.condition.metric]: Number(sample) || 0 } };
    const r = await run(() => api.post<{ obtains: boolean; value: number; message: string }>('/v1/admin/achievements/test', body));
    if (r) setTest(r);
  }
  return (
    <div className="split">
      <Panel title={item ? a.name : 'Nuevo logro'} icon="emoji_events" actions={item ? <><StateChip state={item.state} /><span className="chip chip-line mono">v{item.version}</span></> : undefined}>
        <div className="col g12">
          <div className="grid2">
            <Field label="Nombre" id="ac-name"><input id="ac-name" className="input" value={a.name} onChange={(e) => setA({ ...a, name: e.target.value })} /></Field>
            <Field label="Categoría" id="ac-cat"><select id="ac-cat" className="input" value={a.category} onChange={(e) => setA({ ...a, category: e.target.value })}>{CATEGORIES.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></Field>
          </div>
          <Field label="Descripción" id="ac-desc"><input id="ac-desc" className="input" value={a.description} onChange={(e) => setA({ ...a, description: e.target.value })} /></Field>
          <fieldset className="grid4" style={{ border: 0, padding: 0, margin: 0 }}>
            <legend className="flabel" style={{ marginBottom: 6 }}>Condición</legend>
            <Field label="Métrica" id="ac-metric"><select id="ac-metric" className="input" value={a.condition.metric} onChange={(e) => setC({ metric: e.target.value as AchievementMetric })}>{(Object.keys(METRICS) as AchievementMetric[]).map((m) => <option key={m} value={m}>{METRICS[m]}</option>)}</select></Field>
            <Field label="Operador" id="ac-op"><select id="ac-op" className="input" value={a.condition.op} onChange={(e) => setC({ op: e.target.value as Achievement['condition']['op'] })}>{OPS.map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></Field>
            <Field label="Valor" id="ac-value"><input id="ac-value" className="input mono" type="number" min={0} value={a.condition.value} onChange={(e) => setC({ value: Number(e.target.value) })} /></Field>
            <Field label="Ámbito" id="ac-scope"><select id="ac-scope" className="input" value={a.condition.scope} onChange={(e) => setC({ scope: e.target.value as 'global' | 'sector' })}><option value="global">Toda la app</option><option value="sector">Por sector</option></select></Field>
          </fieldset>
          <div className="row g16 wrap">
            <label className="check-row t-small"><input type="checkbox" checked={!a.secret} onChange={(e) => setA({ ...a, secret: !e.target.checked })} />Visible</label>
            <label className="check-row t-small"><input type="checkbox" checked={a.secret} onChange={(e) => setA({ ...a, secret: e.target.checked })} />Secreto</label>
            <label className="check-row t-small"><input type="checkbox" checked={a.retroactive} onChange={(e) => setA({ ...a, retroactive: e.target.checked })} />Con efecto retroactivo</label>
          </div>
          <Field label="Vigencia (fecha de fin opcional)" id="ac-ends"><input id="ac-ends" className="input" type="date" value={a.endsAt ?? ''} onChange={(e) => setA({ ...a, endsAt: e.target.value || null })} /></Field>
          <div className="row g8 wrap">
            <button type="button" className="btn btn-primary btn-sm" disabled={busy || !a.name.trim()} onClick={save}><Icon name="save" />Guardar</button>
            {item && ['draft', 'changes_requested'].includes(item.state) && <button type="button" className="btn btn-secondary btn-sm" disabled={busy} onClick={async () => { const r = await run(() => api.post(`/v1/admin/items/${item.id}/submit`), 'Enviado a revisión'); if (r) onSaved(item.id); }}><Icon name="send" />Enviar a revisión</button>}
          </div>
        </div>
      </Panel>
      <div className="col g16">
        <Panel title="Probar la condición" icon="science">
          <div className="col g10">
            <Field label="Usuario de ejemplo (identificador)" id="ac-user" help="Se calculan sus métricas reales."><input id="ac-user" className="input mono" value={userId} onChange={(e) => setUserId(e.target.value)} /></Field>
            <Field label={`O un valor de ejemplo de «${METRICS[a.condition.metric]}»`} id="ac-sample"><input id="ac-sample" className="input mono" type="number" value={sample} onChange={(e) => setSample(e.target.value)} disabled={Boolean(userId.trim())} /></Field>
            <button type="button" className="btn btn-secondary btn-sm" disabled={!userId.trim() && sample === ''} onClick={runTest}>Probar</button>
            {test && <Notice kind={test.obtains ? 'ok' : 'warn'}>{test.message}</Notice>}
          </div>
        </Panel>
        <Panel title="Vista previa" icon="workspace_premium">
          <div className="row g12"><span className="row center" style={{ width: 56, height: 56, borderRadius: '50%', background: 'var(--accent-tint)', color: 'var(--accent-text)' }}><Icon name={a.icon || 'emoji_events'} size={28} /></span>
            <div className="col g4"><strong className="ui">{a.secret ? 'Logro secreto' : a.name || 'Sin nombre'}</strong><span className="t-small muted">{OPS.find(([k]) => k === a.condition.op)?.[1]} {a.condition.value} · {METRICS[a.condition.metric].toLowerCase()}</span></div></div>
        </Panel>
      </div>
    </div>
  );
}

export function Achievements() {
  const { api } = useSession();
  const st = useAsync(() => api.get<{ items: Item<Achievement>[] }>('/v1/admin/items', { kind: 'achievement' }), [api]);
  const [selected, setSelected] = useState<string | 'new' | null>(null);
  const item = st.data?.items.find((i) => i.id === selected) ?? null;
  return (
    <Page title="Logros" crumbs={[{ label: 'Personas' }, { label: 'Logros y ligas' }, { label: 'Logros' }]}
      actions={<button type="button" className="btn btn-primary btn-sm" onClick={() => setSelected('new')}><Icon name="add" />Nuevo logro</button>}>
      <Async state={st}>
        {(d) => (
          <>
            <div className="row g8 wrap" role="list" aria-label="Logros">
              {d.items.length === 0 && <Empty title="Sin logros" />}
              {d.items.map((i) => (
                <button key={i.id} role="listitem" type="button" className={`card row g8${selected === i.id ? ' card-sel' : ''}`} style={{ cursor: 'pointer', minWidth: 200 }} onClick={() => setSelected(i.id)}>
                  <Icon name={i.data.icon || 'emoji_events'} className="c-accent" /><span className="col g4" style={{ alignItems: 'flex-start' }}><strong className="ui t-small">{i.data.name}</strong><span className="t-label muted">{CATEGORIES.find(([k]) => k === i.data.category)?.[1] ?? i.data.category} · <StateChip state={i.state} /></span></span>
                </button>
              ))}
            </div>
            {selected && <AchievementEditor key={selected} item={selected === 'new' ? null : item} onSaved={(id) => { st.reload(); setSelected(id); }} />}
          </>
        )}
      </Async>
    </Page>
  );
}

interface Flag { id: string; user_id: string; alias: string; week_start: string; reason: string; status: string; created_at: string }

export function Leagues() {
  const { api, account } = useSession();
  const { run, busy } = useAction();
  const editable = can(account?.role, 'leagueConfig');
  const cfg = useAsync(() => (editable ? api.get<{ current: LeagueConfig; scheduled: { value: LeagueConfig; effective_from: string } | null }>('/v1/admin/leagues/config') : Promise.resolve(null)), [api, editable]);
  const week = useAsync(() => api.get<{ week: string; groups: { id: string; division: number; sector_id: string | null; members: number; points: number }[] }>('/v1/admin/leagues/week'), [api]);
  const flags = useAsync(() => (editable ? api.get<{ items: Flag[] }>('/v1/admin/leagues/flagged').then((r) => r.items) : Promise.resolve([] as Flag[])), [api, editable]);
  const [draft, setDraft] = useState<LeagueConfig | null>(null);
  const [scheduledMsg, setScheduledMsg] = useState<string | null>(null);
  const [resolving, setResolving] = useState<{ flag: Flag; decision: 'cleared' | 'confirmed' } | null>(null);
  const [closed, setClosed] = useState<{ week: string; groups: { groupId: string; promoted: number; relegated: number }[] } | null>(null);
  const [closing, setClosing] = useState(false);
  const c = draft ?? cfg.data?.scheduled?.value ?? cfg.data?.current ?? null;
  const set = (p: Partial<LeagueConfig>) => c && setDraft({ ...c, ...p });
  const participants = (week.data?.groups ?? []).reduce((a, g) => a + g.members, 0);
  return (
    <Page title="Ligas" crumbs={[{ label: 'Personas' }, { label: 'Logros y ligas' }, { label: 'Ligas' }]}>
      {editable && (
        <Async state={cfg}>
          {() => c && (
            <Panel title="Reglas" icon="rule" actions={<button type="button" className="btn btn-primary btn-sm" disabled={!draft || busy} onClick={async () => { const r = await run(() => api.put<{ scheduledFrom: string; message: string }>('/v1/admin/leagues/config', c), (x) => x.message); if (r) { setScheduledMsg(r.message); setDraft(null); cfg.reload(); } }}><Icon name="event" />Programar cambios</button>}>
              <div className="col g12">
                <Notice icon="event_upcoming">Los cambios de reglas entran en vigor al empezar la semana siguiente{cfg.data?.scheduled ? `: lunes ${date(cfg.data.scheduled.effective_from)}` : ''}. Nunca a mitad de semana.</Notice>
                {scheduledMsg && <Notice kind="ok" icon="event_available">{scheduledMsg}. La semana en curso sigue con el tope actual de {cfg.data?.current.dailyCap} puntos.</Notice>}
                <div className="grid3">
                  <Field label="Tamaño del grupo" id="lg-size"><input id="lg-size" className="input mono" type="number" value={c.groupSize} onChange={(e) => set({ groupSize: Number(e.target.value) })} /></Field>
                  <Field label="Suben (primeros)" id="lg-up"><input id="lg-up" className="input mono" type="number" value={c.promote} onChange={(e) => set({ promote: Number(e.target.value) })} /></Field>
                  <Field label="Bajan (últimos)" id="lg-down"><input id="lg-down" className="input mono" type="number" value={c.relegate} onChange={(e) => set({ relegate: Number(e.target.value) })} /></Field>
                  <Field label="Puntos por acierto al primer intento" id="lg-pts"><input id="lg-pts" className="input mono" type="number" value={c.pointsPerCorrect} onChange={(e) => set({ pointsPerCorrect: Number(e.target.value) })} /></Field>
                  <Field label="Tope diario" id="lg-cap"><input id="lg-cap" className="input mono" type="number" value={c.dailyCap} onChange={(e) => set({ dailyCap: Number(e.target.value) })} /></Field>
                  <Field label="Bonificación por contrarreloj válida" id="lg-bonus"><input id="lg-bonus" className="input mono" type="number" value={c.timetrialBonus} onChange={(e) => set({ timetrialBonus: Number(e.target.value) })} /></Field>
                </div>
                <Field label="Divisiones (separadas por comas)" id="lg-div"><input id="lg-div" className="input" value={c.divisions.join(', ')} onChange={(e) => set({ divisions: e.target.value.split(',').map((x) => x.trim()).filter(Boolean) })} /></Field>
                <label className="check-row t-small"><input type="checkbox" checked={c.groupBySector} onChange={(e) => set({ groupBySector: e.target.checked })} />Agrupar por sector</label>
              </div>
            </Panel>
          )}
        </Async>
      )}
      <Panel title={`Semana en curso${week.data ? ` · desde el ${date(week.data.week)}` : ''}`} icon="calendar_month">
        <Async state={week}>
          {(w) => (
            <div className="grid3">
              <div className="col g4"><span className="t-label muted">Grupos</span><span className="kpi">{w.groups.length}</span></div>
              <div className="col g4"><span className="t-label muted">Participantes</span><span className="kpi">{participants}</span></div>
              <div className="col g4"><span className="t-label muted">Puntos repartidos</span><span className="kpi">{w.groups.reduce((a, g) => a + g.points, 0)}</span></div>
            </div>
          )}
        </Async>
      </Panel>
      {account?.role === 'superadmin' && (
        <Panel title="Cierre de semana" icon="event_repeat">
          <div className="col g10">
            <p className="t-small">Al cerrar una semana, los primeros de cada grupo suben de división y los últimos bajan, según las reglas con las que empezó esa semana. El cierre queda en auditoría.</p>
            <div className="row g8 wrap">
              <button type="button" className="btn btn-secondary btn-sm" disabled={busy} onClick={() => setClosing(true)}><Icon name="event_repeat" />Cerrar la semana anterior</button>
            </div>
            {closed && (
              <Notice kind="ok">Semana del {date(closed.week)} cerrada: {closed.groups.length} grupos, {closed.groups.reduce((a, g) => a + g.promoted, 0)} ascensos y {closed.groups.reduce((a, g) => a + g.relegated, 0)} descensos.</Notice>
            )}
          </div>
        </Panel>
      )}
      {closing && (
        <Modal title="Cerrar la semana anterior" onClose={() => setClosing(false)}>
          <p className="t-small">Se calculan las clasificaciones finales y se aplican los ascensos y descensos. No se puede deshacer.</p>
          <div className="row g8 end">
            <button type="button" className="btn btn-tertiary btn-sm" onClick={() => setClosing(false)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={busy} onClick={async () => { const r = await run(() => api.post<{ week: string; groups: { groupId: string; promoted: number; relegated: number }[] }>('/v1/admin/leagues/close-week', {}), 'Semana cerrada'); setClosing(false); if (r) { setClosed(r); week.reload(); } }}>Cerrar la semana</button>
          </div>
        </Modal>
      )}
      {editable && (
        <Panel title="Usuarios marcados por patrones anómalos" icon="flag" bodyClass="tblwrap">
          <Async state={flags}>
            {(f) => f.length === 0 ? <Empty icon="verified" title="Nadie marcado" /> : (
              <table className="tbl" aria-label="Usuarios marcados">
                <thead><tr><th>Alias</th><th>Patrón</th><th>Semana</th><th>Detectado</th><th>Estado</th><th><span className="sr-only">Acciones</span></th></tr></thead>
                <tbody>{f.map((x) => (
                  <tr key={x.id}>
                    <td>{x.alias}</td><td className="t-small">{x.reason}</td><td>{date(x.week_start)}</td><td>{ago(x.created_at)}</td>
                    <td>{x.status === 'open' ? <span className="chip chip-warning">Puntos en suspenso</span> : x.status === 'cleared' ? <span className="chip chip-success">Descartado</span> : <span className="chip chip-error">Confirmado</span>}</td>
                    <td className="actions">{x.status === 'open' && <>
                      <button type="button" className="btn btn-tertiary btn-xs" onClick={() => setResolving({ flag: x, decision: 'cleared' })}>Descartar</button>
                      <button type="button" className="btn btn-danger btn-xs" onClick={() => setResolving({ flag: x, decision: 'confirmed' })}>Confirmar</button>
                    </>}</td>
                  </tr>
                ))}</tbody>
              </table>
            )}
          </Async>
        </Panel>
      )}
      {resolving && (
        <ReasonDialog title={resolving.decision === 'cleared' ? `Descartar la marca de ${resolving.flag.alias}` : `Confirmar la marca de ${resolving.flag.alias}`} confirmLabel={resolving.decision === 'cleared' ? 'Descartar: los puntos cuentan' : 'Confirmar: los puntos se excluyen'} danger={resolving.decision === 'confirmed'} onClose={() => setResolving(null)}
          onConfirm={async (reason) => { const r = await run(() => api.post(`/v1/admin/leagues/flagged/${resolving.flag.id}/resolve`, { decision: resolving.decision, reason }), 'Marca resuelta'); setResolving(null); if (r) flags.reload(); }} />
      )}
    </Page>
  );
}
