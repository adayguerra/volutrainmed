/**
 * B06–B09 · Editor de plantillas en seis pasos con vista previa, comprobación
 * dimensional en vivo, errores previsibles, panel de pruebas (muestra de 20 y
 * prueba masiva de 1000) y envío a revisión. Usa el mismo motor que el servicio
 * de publicación (@vtm/engine).
 */
import { useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import type { TemplateDefinition } from '@vtm/engine';
import type { ItemDetail } from '../../api/types';
import { canAccess, can } from '../../auth/permissions';
import { useSession } from '../../auth/session';
import { BUILTIN_TYPES, DEFAULT_SECTORS, loadSectors, loadSkills, loadSpecies, loadTypes } from '../../content/common';
import { formulaCheck, issuesOf, newTemplate, normalizeTemplate, sample, type MassReport } from '../../content/template';
import { ErrorBox, Icon, Loading, Notice, Page, Panel, StateChip, Tabs, useAction, useAsync } from '../../ui/kit';
import { date } from '../../ui/format';
import { ErrorsStep, FormulaStep, GeneralStep, StatementStep, StepsLevelsStep, TestPanel, VariablesStep } from './TemplateParts';

type StepId = 'general' | 'variables' | 'statement' | 'formula' | 'errors' | 'steps';
const STEPS: { id: StepId; label: string }[] = [
  { id: 'general', label: 'Datos generales' }, { id: 'variables', label: 'Variables' }, { id: 'statement', label: 'Enunciado' },
  { id: 'formula', label: 'Fórmula y respuesta' }, { id: 'errors', label: 'Restricciones y errores previsibles' }, { id: 'steps', label: 'Explicación y niveles' },
];

export function TemplateEditor() {
  const { id } = useParams();
  const isNew = !id || id === 'nueva';
  const { api, account } = useSession();
  const navigate = useNavigate();
  const detail = useAsync(() => (isNew ? Promise.resolve(null) : api.get<ItemDetail<TemplateDefinition>>(`/v1/admin/items/${id}`)), [api, id]);
  const sectors = useAsync(() => loadSectors(api), [api]);
  const types = useAsync(() => loadTypes(api), [api]);
  const skills = useAsync(() => loadSkills(api), [api]);
  const species = useAsync(() => loadSpecies(api), [api]);
  const [def, setDef] = useState<TemplateDefinition>(newTemplate);
  const [dirty, setDirty] = useState(false);
  const [tab, setTab] = useState<StepId>('general');
  const [mass, setMass] = useState<MassReport | null>(null);
  const [serverIssue, setServerIssue] = useState<string | null>(null);
  const { run, busy } = useAction();

  // Estado derivado de la carga: se fija en el mismo render para no mostrar una definición vacía.
  const [loadedFrom, setLoadedFrom] = useState<unknown>(null);
  if (detail.data && loadedFrom !== detail.data) {
    setLoadedFrom(detail.data);
    setDef(normalizeTemplate(detail.data.item.data));
    setDirty(false);
    setMass(null);
  }

  const set = (fn: (d: TemplateDefinition) => TemplateDefinition) => { setDef((d) => fn(d)); setDirty(true); setMass(null); setServerIssue(null); };
  const item = detail.data?.item;
  const editable = isNew ? can(account?.role, 'createContent') : Boolean(detail.data?.canEdit) && item?.state !== 'retired';
  const dc = formulaCheck(def);
  const issues = useMemo(() => issuesOf(def), [def]);
  const blocking = issues.filter((i) => i.blocking);
  const preview = useMemo(() => { const r = sample(def, 1, 2, 17); return r.rows[0] ?? null; }, [def]);
  const canSave = editable && dirty && def.name.trim() !== '' && (!dc || dc.ok);
  const submitReasons = [
    ...blocking.map((b) => b.message),
    ...(mass && mass.collisions > 0 ? [`La prueba masiva detecta ${mass.collisions} colisiones: resuélvelas antes de enviar a revisión`] : []),
  ];
  const canSubmit = editable && !isNew && item && ['draft', 'changes_requested'].includes(item.state) && submitReasons.length === 0 && (!dc || dc.ok);

  async function save(): Promise<boolean> {
    const { id: _omit, ...data } = def;
    void _omit;
    if (isNew) {
      const r = await run(() => api.post<{ item: { id: string } }>('/v1/admin/items', { kind: 'template', data }), 'Plantilla creada en borrador');
      if (r) { setDirty(false); navigate(`/plantillas/${r.item.id}`, { replace: true }); return true; }
      return false;
    }
    const r = await run(() => api.put<{ item: { version: number; state: string } }>(`/v1/admin/items/${id}`, { data: def }), (x) => (item && x.item.version > item.version ? `Creada la versión ${x.item.version} en borrador. La versión ${item.version} publicada sigue llegando a los usuarios` : 'Cambios guardados'));
    if (r) { setDirty(false); detail.reload(); return true; }
    return false;
  }

  async function submit() {
    if (dirty && !(await save())) return;
    try {
      await api.post(`/v1/admin/items/${id}/submit`);
      setServerIssue(null);
      detail.reload();
      await run(async () => undefined, 'Enviada a revisión');
    } catch (e) {
      setServerIssue((e as Error).message);
    }
  }

  if (!isNew && detail.loading && !detail.data) return <Page title="Plantilla"><Loading /></Page>;
  if (detail.error) return <Page title="Plantilla"><ErrorBox error={detail.error} onRetry={detail.reload} /></Page>;

  const latestReview = detail.data?.reviews.find((r) => r.decision !== 'validate');
  return (
    <Page
      title={def.name || 'Nueva plantilla'}
      crumbs={[{ label: 'Biblioteca', to: '/biblioteca' }, { label: 'Plantillas' }, ...(def.name ? [{ label: def.name }] : [])]}
      chip={item ? <><StateChip state={item.state} /><span className="chip chip-line mono">v{item.version}</span></> : <span className="chip">Borrador</span>}
      actions={
        <>
          {dirty ? <span className="t-small muted">Cambios sin guardar</span> : item ? <span className="t-small muted">Guardado</span> : null}
          {!isNew && canAccess(account?.role, 'analitica') && <Link className="btn btn-tertiary btn-sm" to={`/analitica/${id}`}><Icon name="bar_chart" />Ver analítica</Link>}
          {!isNew && <Link className="btn btn-secondary btn-sm" to={`/vista-previa/${id}`}><Icon name="record_voice_over" />Vista previa con voz</Link>}
          {editable && <button type="button" className="btn btn-secondary btn-sm" disabled={!canSave || busy} onClick={save}><Icon name="save" />Guardar</button>}
          {editable && !isNew && <button type="button" className="btn btn-primary btn-sm" disabled={!canSubmit || busy} onClick={submit}><Icon name="send" />Enviar a revisión</button>}
        </>
      }>
      {!editable && (
        <Notice kind="info" icon="visibility">
          Solo lectura: {account?.role === 'author' ? 'esta plantilla es de otra persona; puedes verla, no modificarla.' : account?.role === 'analyst' ? 'puedes consultar la plantilla y su analítica, no editarla.' : item?.state === 'retired' ? 'la plantilla está retirada.' : 'tu rol no modifica contenido.'}
        </Notice>
      )}
      {editable && item?.state === 'published' && <Notice kind="warn">Esta plantilla está publicada. Al guardar se crea la versión {item.version + 1} en borrador y la versión {item.version} publicada sigue llegando a los usuarios hasta que se valide y publique la nueva.</Notice>}
      {item?.state === 'changes_requested' && latestReview?.comment && <Notice kind="warn"><strong>Cambios solicitados por {latestReview.reviewer_name}:</strong> «{latestReview.comment}»</Notice>}
      {serverIssue && <Notice kind="err"><strong>No se puede enviar a revisión:</strong> {serverIssue}</Notice>}
      <div className="split">
        <div className="col g16" style={{ minWidth: 0 }}>
          <Tabs label="Pasos del asistente" value={tab} onChange={setTab} tabs={STEPS.map((s, i) => ({ id: s.id, label: s.label, n: i + 1 }))} />
          <section className="panel panel-b" aria-label={STEPS.find((s) => s.id === tab)!.label}>
            <fieldset disabled={!editable} style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}>
              {tab === 'general' && <GeneralStep def={def} set={set} sectors={sectors.data ?? DEFAULT_SECTORS} types={types.data ?? BUILTIN_TYPES} skills={skills.data} species={species.data} />}
              {tab === 'variables' && <VariablesStep def={def} set={set} />}
              {tab === 'statement' && <StatementStep def={def} set={set} preview={preview} />}
              {tab === 'formula' && <FormulaStep def={def} set={set} preview={preview} />}
              {tab === 'errors' && <ErrorsStep def={def} set={set} preview={preview} />}
              {tab === 'steps' && <StepsLevelsStep def={def} set={set} />}
            </fieldset>
          </section>
          <TestPanel def={def} mass={mass} setMass={setMass} />
        </div>
        <div className="col g16">
          <Panel title="Vista previa" icon="smartphone">
            {preview ? (
              <div className="col g12">
                <p className="t-stmt">{preview.statement}</p>
                <p className="ui sb">{preview.question}</p>
                <div className="answer" style={{ height: 64 }}><span className="v" style={{ fontSize: 28 }}>{preview.answer.replace('.', ',')}</span><span className="u">{preview.unit}</span></div>
                <span className="t-label muted">Variante de ejemplo · nivel {preview.level}</span>
              </div>
            ) : <p className="t-small muted">Completa variables, enunciado y fórmula para ver una variante.</p>}
          </Panel>
          <Panel title="Comprobaciones" icon="checklist">
            {issues.length === 0 ? <Notice kind="ok">Sin problemas detectados.</Notice> : (
              <ul className="col g6" aria-label="Comprobaciones de la plantilla">
                {issues.map((i, k) => <li key={k} className={`t-small ${i.blocking ? 'c-error' : 'c-warning'}`}><Icon name={i.blocking ? 'error' : 'warning'} size={16} /> {i.message}</li>)}
              </ul>
            )}
            {!isNew && editable && submitReasons.length > 0 && <p className="t-small muted" style={{ marginTop: 8 }}>Resuelve lo anterior para enviar la plantilla a revisión.</p>}
          </Panel>
          {detail.data && (
            <Panel title="Versiones" icon="history">
              <ul className="col g6" aria-label="Versiones de la plantilla">
                {detail.data.versions.map((v) => <li key={v.version} className="row g8 t-small"><span className="mono b">v{v.version}</span><StateChip state={v.state} /><span className="muted">{date(v.updatedAt)}</span></li>)}
              </ul>
            </Panel>
          )}
        </div>
      </div>
    </Page>
  );
}
