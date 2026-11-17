/**
 * B17 · Versionado y publicación: preparación de la versión con diferencias
 * frente a la activa (lo no validado aparece atenuado con su motivo),
 * comprobaciones automáticas (doble cálculo, colisiones, explicación y voz,
 * compatibilidad y tamaño), paquete de prueba con código QR, publicación
 * firmada con confirmación del nombre, despliegue gradual 5 → 50 → 100 %,
 * reversión con una acción y retirada inmediata de un ejercicio.
 */
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import QRCode from 'qrcode';
import type { Check, Item, Release, ReleaseDiff } from '../api/types';
import { useSession } from '../auth/session';
import { Async, Field, Icon, Modal, Notice, Page, Panel, ReasonDialog, useAction, useAsync } from '../ui/kit';
import { ago, date } from '../ui/format';

const RELEASE_STATE: Record<string, { label: string; cls: string }> = {
  preparing: { label: 'En preparación', cls: 'chip chip-primary' }, testing: { label: 'En prueba', cls: 'chip chip-accent' }, published: { label: 'Publicada', cls: 'chip chip-success' },
  superseded: { label: 'Archivada', cls: 'chip' }, rolled_back: { label: 'Revertida', cls: 'chip chip-warning' },
};

function cmpVersion(a: string, b: string): number {
  const pa = a.split('.').map(Number); const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) { const d = (pa[i] ?? 0) - (pb[i] ?? 0); if (d) return d; }
  return 0;
}

function itemLink(e: { id: string; kind?: string }) {
  return e.kind === 'question' ? `/preguntas/${e.id}` : e.kind === 'template' ? `/plantillas/${e.id}` : `/biblioteca?q=${encodeURIComponent(e.id)}`;
}

function DiffList({ diff }: { diff: ReleaseDiff }) {
  return (
    <div className="col g8">
      <div className="row g8 wrap">
        <span className="chip chip-success">{diff.added.length} añadidos</span>
        <span className="chip chip-primary">{diff.changed.length} modificados</span>
        <span className="chip chip-warning">{diff.retired.length} retirados</span>
        <span className="chip">{diff.excluded.length} sin validar</span>
      </div>
      <div className="tblwrap">
        <table className="tbl" aria-label="Cambios en esta versión">
          <tbody>
            {diff.added.map((e) => <tr key={`a-${e.id}`}><td className="mono c-success">+</td><td><Link to={itemLink(e)}>{e.title ?? e.id}</Link></td><td className="t-small muted">{e.kind}</td><td className="t-small">v{e.version}</td></tr>)}
            {diff.changed.map((e) => <tr key={`c-${e.id}`}><td className="mono c-primary">±</td><td><Link to={itemLink(e)}>{e.title ?? e.id}</Link></td><td className="t-small muted">{e.kind}</td><td className="t-small">→ v{e.version}</td></tr>)}
            {diff.retired.map((e) => <tr key={`r-${e.id}`}><td className="mono c-warning">−</td><td>{e.title ?? e.id}</td><td className="t-small muted">{e.kind}</td><td className="t-small">Retirada</td></tr>)}
            {diff.excluded.map((e) => (
              <tr key={`x-${e.id}`} className="dim" data-testid="excluido" aria-disabled="true">
                <td className="mono">·</td><td>{e.title ?? e.id}</td><td className="t-small muted">{e.kind}</td><td className="t-small">No se incluye: {e.reason}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function PublishDialog({ release, pct, onClose, onDone }: { release: Release; pct: number; onClose: () => void; onDone: () => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [name, setName] = useState('');
  return (
    <Modal title={`Publicar la versión ${release.number} al ${pct} %`} onClose={onClose}>
      <p className="t-small">Se firmarán los paquetes por itinerario y {pct < 100 ? `los recibirá aproximadamente el ${pct} % de los dispositivos; el resto conserva la versión anterior` : 'los recibirán todos los dispositivos en su siguiente descarga'}.</p>
      <Field label={`Escribe el nombre de la versión (${release.number}) para confirmar`} id="confirm-name"><input id="confirm-name" className="input mono" value={name} onChange={(e) => setName(e.target.value)} /></Field>
      <div className="row g8 end">
        <button type="button" className="btn btn-tertiary btn-sm" onClick={onClose}>Cancelar</button>
        <button type="button" className="btn btn-primary btn-sm" disabled={busy || name !== release.number} onClick={async () => {
          const r = await run(() => api.post(`/v1/admin/releases/${release.id}/publish`, { confirmName: name, rolloutPct: pct }), pct < 100 ? `Publicada al ${pct} %: el resto de dispositivos conserva la versión anterior` : 'Publicada al 100 %');
          if (r) onDone();
        }}>Publicar</button>
      </div>
    </Modal>
  );
}

function WithdrawDialog({ onClose, onDone }: { onClose: () => void; onDone: () => void }) {
  const { api } = useSession();
  const { run } = useAction();
  const items = useAsync(() => api.get<{ items: Item[] }>('/v1/admin/items', { kind: 'template,question', state: 'published' }).then((r) => r.items), [api]);
  const [itemId, setItemId] = useState('');
  const kind = items.data?.find((i) => i.id === itemId)?.kind === 'question' ? 'question' : 'template';
  return (
    <ReasonDialog title="Retirar un ejercicio ahora" confirmLabel="Retirar ahora" danger onClose={onClose}
      description="La retirada se aplica en cuanto las apps tienen conexión, sin publicar una versión completa."
      extra={<Field label="Ejercicio" id="wd-item"><select id="wd-item" className="input" value={itemId} onChange={(e) => setItemId(e.target.value)}><option value="">Elige un ejercicio publicado</option>{(items.data ?? []).map((i) => <option key={i.id} value={i.id}>{i.title}</option>)}</select></Field>}
      onConfirm={async (reason) => { if (!itemId) return; const r = await run(() => api.post('/v1/admin/revocations', { kind, itemId, reason }), 'Retirado: las apps dejan de presentarlo en cuanto tienen conexión'); if (r) onDone(); }} />
  );
}

/** Tipos de ejercicio con versión mínima que exige el contenido de la versión. */
function TypeRequirements({ release }: { release: Release }) {
  const { api } = useSession();
  const data = useAsync(async () => {
    const [types, items] = await Promise.all([
      api.get<{ items: { id: string; data: { name: string; minAppVersion: string } }[] }>('/v1/admin/exercise-types').then((r) => r.items).catch(() => []),
      api.get<{ items: Item<{ exerciseTypeId?: string }>[] }>('/v1/admin/items', { kind: 'template,question' }).then((r) => r.items).catch(() => []),
    ]);
    const ids = new Set(release.items.map((i) => i.id));
    const used = new Set(items.filter((i) => ids.has(i.id)).map((i) => i.data.exerciseTypeId).filter(Boolean) as string[]);
    const needs = types.filter((t) => used.has(t.id) && cmpVersion(t.data.minAppVersion || '1.0.0', release.minAppVersion) > 0);
    return Promise.all(needs.map(async (t) => ({ id: t.id, name: t.data.name, min: t.data.minAppVersion, compat: await api.get<{ pct: number; compatible: number; total: number }>('/v1/admin/releases/compat', { minAppVersion: t.data.minAppVersion }).catch(() => null) })));
  }, [api, release.id]);
  if (!data.data?.length) return null;
  return (
    <ul className="col g6" aria-label="Tipos con versión mínima">
      {data.data.map((t) => <li key={t.id}><Notice kind="warn" icon="system_update">Incluye contenido del tipo {t.id} · {t.name}, que exige la app {t.min}: lo admite el {t.compat?.pct ?? '—'} % de los dispositivos activos; las apps anteriores omiten esos ejercicios.</Notice></li>)}
    </ul>
  );
}

function ReleaseDetail({ release, previous, onChanged }: { release: Release; previous: Release | null; onChanged: () => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [checks, setChecks] = useState<Check[] | null>(release.checks);
  const [testCode, setTestCode] = useState<string | null>(release.testCode);
  const [qr, setQr] = useState<string | null>(null);
  const [publishPct, setPublishPct] = useState<number | null>(null);
  const [rollback, setRollback] = useState(false);
  const [compat, setCompat] = useState<{ pct: number; compatible: number; total: number } | null>(null);
  useEffect(() => { setChecks(release.checks); setTestCode(release.testCode); }, [release.id, release.checks, release.testCode]);
  useEffect(() => {
    if (testCode) QRCode.toDataURL(`volutrainmed://paquete-prueba?codigo=${testCode}`, { margin: 1, width: 160 }).then(setQr).catch(() => setQr(null));
  }, [testCode]);
  useEffect(() => {
    api.get<{ pct: number; compatible: number; total: number }>('/v1/admin/releases/compat', { minAppVersion: release.minAppVersion }).then(setCompat).catch(() => setCompat(null));
  }, [api, release.minAppVersion]);
  const failed = (checks ?? []).filter((c) => !c.ok);
  const passed = checks !== null && checks.length > 0 && failed.length === 0;
  const editable = ['preparing', 'testing'].includes(release.state);
  const live = release.state === 'published';

  return (
    <div className="col g16">
      <Panel title="Cambios en esta versión" icon="difference">{release.diff ? <DiffList diff={release.diff} /> : <p className="muted t-small">Sin diferencias registradas.</p>}</Panel>
      <Panel title="Comprobaciones" icon="fact_check" actions={editable ? <button type="button" className="btn btn-secondary btn-xs" disabled={busy} onClick={async () => { const r = await run(() => api.post<{ checks: Check[] }>(`/v1/admin/releases/${release.id}/checks`)); if (r) setChecks(r.checks); }}><Icon name="play_arrow" />Ejecutar comprobaciones</button> : undefined}>
        <div className="col g10">
          <p className="t-small" data-testid="compat-version">Versión mínima de la app {release.minAppVersion}{compat ? ` · la admite el ${compat.pct} % de los dispositivos activos (${compat.compatible} de ${compat.total})` : ''}.</p>
          <TypeRequirements release={release} />
          {checks === null ? <p className="t-small muted">Ejecuta las comprobaciones antes de publicar.</p> : (
            <ul className="col g6" aria-label="Resultado de las comprobaciones">
              {checks.map((c, i) => (
                <li key={`${c.id}-${i}`} className={`row g8 t-small ai-start ${c.ok ? '' : 'c-error'}`}>
                  <Icon name={c.ok ? 'check_circle' : 'cancel'} className={c.ok ? 'c-success' : 'c-error'} />
                  <span className="grow"><strong>{c.label}</strong> · {c.detail}{c.itemId && !c.ok ? <> · <Link to={`/plantillas/${c.itemId}`}>Abrir la plantilla afectada</Link></> : null}</span>
                </li>
              ))}
            </ul>
          )}
          {checks !== null && !passed && <Notice kind="err">La publicación está bloqueada: {failed.length} comprobaciones sin superar.</Notice>}
        </div>
      </Panel>
      {editable && (
        <Panel title="Prueba y publicación" icon="rocket_launch">
          <div className="col g12">
            <div className="row g12 wrap ai-start">
              <button type="button" className="btn btn-secondary btn-sm" disabled={busy} onClick={async () => { const r = await run(() => api.post<{ testCode: string; checks: Check[] }>(`/v1/admin/releases/${release.id}/test-package`), (x) => `Paquete de prueba listo: código ${x.testCode}`); if (r) { setTestCode(r.testCode); setChecks(r.checks); } }}><Icon name="qr_code_2" />Generar paquete de prueba</button>
              {testCode && (
                <div className="row g12 card">
                  {qr && <img src={qr} width={120} height={120} alt={`Código QR del paquete de prueba ${testCode}`} />}
                  <div className="col g4"><span className="t-label muted">Código del paquete de prueba</span><span className="mono b" style={{ fontSize: 20 }} data-testid="test-code">{testCode}</span><span className="t-small muted">Escanéalo con la app de pruebas: ningún usuario recibe este paquete.</span></div>
                </div>
              )}
            </div>
            <div className="row g8 wrap">
              {[5, 50, 100].map((p) => <button key={p} type="button" className={`btn btn-sm ${p === 5 ? 'btn-primary' : 'btn-secondary'}`} disabled={!passed || busy} onClick={() => setPublishPct(p)}><Icon name="publish" />Publicar al {p} %</button>)}
            </div>
            {!passed && <p className="t-small muted">«Publicar» se activa cuando todas las comprobaciones se superan.</p>}
            <p className="t-small muted">Publicar exige escribir el nombre de la versión.</p>
          </div>
        </Panel>
      )}
      {live && (
        <Panel title="Despliegue" icon="tune">
          <div className="col g12">
            <p className="t-body">Desplegada al <strong data-testid="rollout">{release.rolloutPct} %</strong> de los dispositivos.{(release.rolloutPct ?? 100) < 100 ? ' El resto conserva la versión anterior.' : ''}</p>
            <div className="row g8 wrap" role="group" aria-label="Despliegue gradual">
              {[5, 50, 100].map((p) => <button key={p} type="button" className={`btn btn-sm ${release.rolloutPct === p ? 'btn-primary' : 'btn-secondary'}`} disabled={busy || release.rolloutPct === p || (release.rolloutPct ?? 0) > p} onClick={async () => { const r = await run(() => api.post(`/v1/admin/releases/${release.id}/rollout`, { rolloutPct: p }), `Despliegue al ${p} %`); if (r) onChanged(); }}>{p} %</button>)}
            </div>
            {previous && <button type="button" className="btn btn-danger btn-sm" onClick={() => setRollback(true)}><Icon name="undo" />Revertir a {previous.number}</button>}
          </div>
        </Panel>
      )}
      {release.state === 'rolled_back' && <Notice kind="warn">Revertida{release.rolledBackReason ? `: «${release.rolledBackReason}»` : ''}.</Notice>}
      {publishPct !== null && <PublishDialog release={release} pct={publishPct} onClose={() => setPublishPct(null)} onDone={() => { setPublishPct(null); onChanged(); }} />}
      {rollback && previous && (
        <ReasonDialog title={`Revertir ${release.number} a ${previous.number}`} description="Las apps vuelven a la versión anterior en su siguiente descarga. La reversión queda en auditoría con su motivo." confirmLabel="Revertir" danger onClose={() => setRollback(false)}
          onConfirm={async (reason) => { const r = await run(() => api.post<{ rolledBack: string; active: string }>('/v1/admin/releases/rollback', { reason }), (x) => `Revertida ${x.rolledBack}: vuelve a estar activa ${x.active}`); setRollback(false); if (r) onChanged(); }} />
      )}
    </div>
  );
}

export function Publishing() {
  const { api } = useSession();
  const { run, busy } = useAction();
  const st = useAsync(() => api.get<{ items: Release[]; pending: ReleaseDiff }>('/v1/admin/releases'), [api]);
  const revocations = useAsync(() => api.get<{ items: { id: number; kind: string; item_id: string; reason: string; created_at: string }[] }>('/v1/admin/revocations').then((r) => r.items).catch(() => []), [api]);
  const [selected, setSelected] = useState<string | null>(null);
  const [preparing, setPreparing] = useState(false);
  const [minApp, setMinApp] = useState('1.0.0');
  const [notes, setNotes] = useState('');
  const [withdraw, setWithdraw] = useState(false);
  const items = st.data?.items ?? [];
  const current = useMemo(() => items.find((r) => r.id === selected) ?? items.find((r) => ['preparing', 'testing'].includes(r.state)) ?? items.find((r) => r.state === 'published') ?? items[0] ?? null, [items, selected]);
  const active = items.find((r) => r.state === 'published');
  const previous = active ? items.filter((r) => ['published', 'superseded'].includes(r.state) && r.id !== active.id && r.publishedAt && active.publishedAt && r.publishedAt < active.publishedAt).sort((a, b) => (a.publishedAt! < b.publishedAt! ? 1 : -1))[0] ?? null : null;

  return (
    <Page title={current ? `Versión ${current.number}` : 'Publicación'} crumbs={[{ label: 'Contenido' }, { label: 'Publicación' }]}
      chip={current ? <span className={RELEASE_STATE[current.state]?.cls}>{RELEASE_STATE[current.state]?.label}{current.state === 'published' ? ` · ${current.rolloutPct} %` : ''}</span> : undefined}
      actions={<>
        <button type="button" className="btn btn-danger btn-sm" onClick={() => setWithdraw(true)}><Icon name="block" />Retirar ejercicio ahora</button>
        <button type="button" className="btn btn-primary btn-sm" onClick={() => setPreparing(true)}><Icon name="add" />Preparar versión</button>
      </>}>
      <Async state={st}>
        {(d) => (
          <div className="split-l">
            <div className="col g16">
              <Panel title="Versiones" icon="layers">
                <ul className="col g4" aria-label="Versiones">
                  {d.items.map((r) => (
                    <li key={r.id}>
                      <button type="button" className={`tree-node${current?.id === r.id ? ' sel' : ''}`} style={{ width: '100%', border: 0, background: current?.id === r.id ? undefined : 'none', cursor: 'pointer' }} onClick={() => setSelected(r.id)}>
                        <span className="mono b">{r.number}</span><span className={RELEASE_STATE[r.state]?.cls} style={{ marginLeft: 'auto' }}>{RELEASE_STATE[r.state]?.label}{r.state === 'published' ? ` · ${r.rolloutPct} %` : ''}</span>
                      </button>
                    </li>
                  ))}
                </ul>
              </Panel>
              <Panel title="Pendiente de publicar" icon="pending_actions">
                <p className="t-small">{d.pending.added.length} añadidos · {d.pending.changed.length} modificados · {d.pending.retired.length} retirados · {d.pending.excluded.length} sin validar</p>
              </Panel>
              <Panel title="Lista de retirada" icon="block">
                {(revocations.data ?? []).length === 0 ? <p className="t-small muted">Ningún ejercicio retirado.</p> : (
                  <ul className="col g4" aria-label="Lista de retirada">{(revocations.data ?? []).slice(0, 10).map((r) => <li key={r.id} className="t-small"><span className="mono">{r.item_id}</span> · {r.reason} · {ago(r.created_at)}</li>)}</ul>
                )}
              </Panel>
            </div>
            {current ? <ReleaseDetail key={current.id} release={current} previous={current.id === active?.id ? previous : null} onChanged={() => { st.reload(); revocations.reload(); }} /> : <Panel title="Sin versiones"><p className="muted">Prepara la primera versión de contenido.</p></Panel>}
          </div>
        )}
      </Async>
      <p className="t-small muted">Publicar exige escribir el nombre de la versión. La retirada se aplica en cuanto las apps tienen conexión. {active ? `Activa: ${active.number}, publicada el ${date(active.publishedAt)}.` : ''}</p>
      {preparing && (
        <Modal title="Preparar una versión" onClose={() => setPreparing(false)}>
          <p className="t-small">Incluye únicamente los elementos validados y vigentes. Lo no validado aparece atenuado con su motivo.</p>
          <Field label="Versión mínima de la app" id="rel-min"><input id="rel-min" className="input mono" value={minApp} onChange={(e) => setMinApp(e.target.value)} /></Field>
          <Field label="Notas" id="rel-notes"><input id="rel-notes" className="input" value={notes} onChange={(e) => setNotes(e.target.value)} /></Field>
          <div className="row g8 end">
            <button type="button" className="btn btn-tertiary btn-sm" onClick={() => setPreparing(false)}>Cancelar</button>
            <button type="button" className="btn btn-primary btn-sm" disabled={busy} onClick={async () => { const r = await run(() => api.post<{ release: Release }>('/v1/admin/releases', { notes: notes || undefined, minAppVersion: minApp }), (x) => `Versión ${x.release.number} preparada`); setPreparing(false); if (r) { setSelected(r.release.id); st.reload(); } }}>Preparar</button>
          </div>
        </Modal>
      )}
      {withdraw && <WithdrawDialog onClose={() => setWithdraw(false)} onDone={() => { setWithdraw(false); revocations.reload(); }} />}
    </Page>
  );
}
