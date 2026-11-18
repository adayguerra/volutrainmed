/**
 * B04 · Estructura: sectores, itinerarios, unidades y lecciones.
 * Árbol con reordenación por botones «Subir» y «Bajar» (sin arrastrar), alta de
 * nodos hijos, ficha de cada nodo, composición de lecciones por huecos o por
 * regla automática y retirada con motivo (nada se borra).
 */
import { useEffect, useMemo, useRef, useState, type MutableRefObject } from 'react';
import type { Item, Kind, TreeNode } from '../api/types';
import { KIND_LABELS } from '../api/types';
import { can } from '../auth/permissions';
import { useSession } from '../auth/session';
import { SKILLS } from '../content/common';
import { Async, Empty, Field, Icon, Modal, Notice, Page, Panel, ReasonDialog, StateChip, useAction, useAsync } from '../ui/kit';

const CHILD: Partial<Record<Kind, Kind>> = { sector: 'itinerary', itinerary: 'unit', unit: 'lesson' };
const PARENT_FIELD: Partial<Record<Kind, string>> = { itinerary: 'sectorId', unit: 'itineraryId', lesson: 'unitId' };
const LESSON_KINDS = [
  { id: 'guided', label: '1 · Concepto guiado' }, { id: 'supported', label: '2 · Práctica con apoyos' }, { id: 'free', label: '3 · Práctica libre (sin planteamiento ni pistas)' },
  { id: 'mixed', label: '4 · Mixta' }, { id: 'challenge', label: '5 · Reto de unidad' },
];

interface Slot { position: number; templateId?: string; questionId?: string; difficulty: number; skillId: string; auto?: boolean }

function find(nodes: TreeNode[], id: string): TreeNode | null {
  for (const n of nodes) {
    if (n.id === id) return n;
    const c = find(n.children, id);
    if (c) return c;
  }
  return null;
}

type DragRef = MutableRefObject<{ id: string; kind: string; parentId: string | null; index: number } | null>;

function TreeItem({ node, depth, selected, onSelect, onMove, onReorder, drag, editable, index, count }: {
  node: TreeNode; depth: number; selected: string | null; onSelect: (id: string) => void; onMove: (n: TreeNode, dir: 'up' | 'down') => void;
  onReorder: (n: { id: string; kind: string; title?: string }, delta: number) => void; drag: DragRef; editable: boolean; index: number; count: number;
}) {
  const [over, setOver] = useState(false);
  const movable = editable && node.state !== 'retired';
  const accepts = () => Boolean(drag.current && drag.current.id !== node.id && drag.current.kind === node.kind && drag.current.parentId === node.parentId);
  const [open, setOpen] = useState(depth < 2 || node.children.some((c) => c.id === selected));
  const label = node.kind === 'unit' ? `Unidad ${index + 1} · ${node.title}` : node.kind === 'lesson' ? `L${index + 1} · ${node.title}` : node.title;
  const active = node.children.filter((c) => c.state !== 'retired');
  return (
    <li>
      <div className={`tree-node${selected === node.id ? ' sel' : ''}${over ? ' drop' : ''}`} style={{ paddingLeft: 6 + depth * 16 }} data-testid={`nodo-${node.id}`}
        draggable={movable}
        onDragStart={(e) => { drag.current = { id: node.id, kind: node.kind, parentId: node.parentId, index }; e.dataTransfer?.setData('text/plain', node.id); if (e.dataTransfer) e.dataTransfer.effectAllowed = 'move'; e.stopPropagation(); }}
        onDragEnd={() => { drag.current = null; setOver(false); }}
        onDragOver={(e) => { if (movable && accepts()) { e.preventDefault(); setOver(true); } }}
        onDragLeave={() => setOver(false)}
        onDrop={(e) => {
          setOver(false);
          const d = drag.current;
          if (!movable || !d || !accepts()) return;
          e.preventDefault(); e.stopPropagation();
          drag.current = null;
          onReorder({ id: d.id, kind: d.kind }, index - d.index);
        }}>
        {movable && <Icon name="drag_indicator" className="muted grip" />}
        {node.children.length ? (
          <button type="button" className="iconbtn iconbtn-sm" aria-label={open ? `Contraer ${node.title}` : `Desplegar ${node.title}`} aria-expanded={open} onClick={() => setOpen(!open)}>
            <Icon name={open ? 'expand_more' : 'chevron_right'} />
          </button>
        ) : <span style={{ width: 36 }} />}
        <button type="button" className="name" onClick={() => onSelect(node.id)} aria-current={selected === node.id ? 'true' : undefined}
          aria-keyshortcuts={movable ? 'Alt+ArrowUp Alt+ArrowDown' : undefined}
          onKeyDown={(e) => {
            if (!movable || !e.altKey) return;
            if (e.key === 'ArrowUp' && index > 0) { e.preventDefault(); onMove(node, 'up'); }
            if (e.key === 'ArrowDown' && index < count - 1) { e.preventDefault(); onMove(node, 'down'); }
          }}>
          {label}{node.state === 'draft' ? <span className="chip" style={{ marginLeft: 6, height: 22 }}>Borrador</span> : node.state === 'retired' ? <span className="chip chip-line" style={{ marginLeft: 6, height: 22 }}>Retirado</span> : null}
        </button>
        {editable && node.state !== 'retired' && (
          <>
            <button type="button" className="iconbtn iconbtn-sm" aria-label={`Subir ${node.title}`} disabled={index === 0} onClick={() => onMove(node, 'up')}><Icon name="arrow_upward" /></button>
            <button type="button" className="iconbtn iconbtn-sm" aria-label={`Bajar ${node.title}`} disabled={index >= count - 1} onClick={() => onMove(node, 'down')}><Icon name="arrow_downward" /></button>
          </>
        )}
      </div>
      {open && node.children.length > 0 && (
        <ul className="tree-list">
          {node.children.map((c) => (
            <TreeItem key={c.id} node={c} depth={depth + 1} selected={selected} onSelect={onSelect} onMove={onMove} onReorder={onReorder} drag={drag} editable={editable}
              index={active.findIndex((x) => x.id === c.id)} count={active.length} />
          ))}
        </ul>
      )}
    </li>
  );
}

function SkillPicker({ value, onChange, disabled, idPrefix }: { value: string[]; onChange: (v: string[]) => void; disabled?: boolean; idPrefix: string }) {
  return (
    <fieldset className="col g4" style={{ border: 0, padding: 0, margin: 0 }} disabled={disabled}>
      <legend className="flabel" style={{ marginBottom: 6 }}>Habilidades</legend>
      <div className="grid2" style={{ gap: 4 }}>
        {SKILLS.map((s) => (
          <label key={s.id} className="check-row t-small" htmlFor={`${idPrefix}-${s.id}`}>
            <input id={`${idPrefix}-${s.id}`} type="checkbox" checked={value.includes(s.id)} onChange={(e) => onChange(e.target.checked ? [...value, s.id] : value.filter((x) => x !== s.id))} />
            {s.id} · {s.name}
          </label>
        ))}
      </div>
    </fieldset>
  );
}

function NewNodeDialog({ kind, parent, onClose, onCreated }: { kind: Kind; parent: TreeNode | null; onClose: () => void; onCreated: (it: Item) => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [skills, setSkills] = useState<string[]>([]);
  const [code, setCode] = useState('');
  async function create() {
    const data: Record<string, unknown> = kind === 'lesson'
      ? { title: name, kind: 'free', rule: 'slots', slots: [], estimatedMinutes: 5 }
      : { name, description };
    if (kind === 'sector') Object.assign(data, { id: code || undefined, code: code.toUpperCase().slice(0, 3), itineraryIds: [], order: 99 });
    if (kind === 'unit') Object.assign(data, { skills, templateIds: [], questionIds: [] });
    if (kind === 'itinerary') Object.assign(data, { recommendedLevel: 'afianzar', isFoundations: false });
    const pf = PARENT_FIELD[kind];
    if (pf && parent) data[pf] = parent.id;
    const r = await run(() => api.post<{ item: Item }>(`/v1/admin/structure/${kind}`, data), `${KIND_LABELS[kind]} creada en borrador`);
    if (r) onCreated(r.item);
  }
  const title = `Nueva ${KIND_LABELS[kind].toLowerCase()}${parent ? ` en ${parent.title}` : ''}`;
  return (
    <Modal title={title} onClose={onClose}>
      <Field label={kind === 'lesson' ? 'Título' : 'Nombre'} id="nn-name"><input id="nn-name" className="input" value={name} onChange={(e) => setName(e.target.value)} /></Field>
      {kind === 'sector' && <Field label="Identificador" id="nn-code" help="En minúsculas y sin espacios, por ejemplo «odontologia»."><input id="nn-code" className="input mono" value={code} onChange={(e) => setCode(e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, ''))} /></Field>}
      {kind !== 'lesson' && <Field label="Descripción" id="nn-desc"><input id="nn-desc" className="input" value={description} onChange={(e) => setDescription(e.target.value)} /></Field>}
      {kind === 'unit' && <SkillPicker value={skills} onChange={setSkills} idPrefix="nn-skill" />}
      <div className="row g8 end">
        <button type="button" className="btn btn-tertiary btn-sm" onClick={onClose}>Cancelar</button>
        <button type="button" className="btn btn-primary btn-sm" disabled={busy || !name.trim()} onClick={create}>Crear</button>
      </div>
    </Modal>
  );
}

function NodeDetail({ node, editable, content, onChanged }: { node: TreeNode; editable: boolean; content: Item[]; onChanged: (select?: string) => void }) {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [data, setData] = useState<Record<string, unknown>>(node.data);
  const [retiring, setRetiring] = useState(false);
  const [submitIssue, setSubmitIssue] = useState<string | null>(null);
  useEffect(() => { setData(node.data); setSubmitIssue(null); }, [node.id, node.version, node.data]);
  const set = (k: string, v: unknown) => setData((d) => ({ ...d, [k]: v }));
  const slots = (data.slots as Slot[] | undefined) ?? [];
  const rule = (data.rule as string | undefined) ?? 'slots';
  const ro = !editable || node.state === 'retired';
  const templates = content.filter((c) => c.kind === 'template');
  const questions = content.filter((c) => c.kind === 'question');

  async function save() {
    if (node.kind === 'lesson') {
      const { rule: r, slots: s, ...rest } = data;
      await run(async () => {
        await api.patch(`/v1/admin/structure/lesson/${node.id}`, rest);
        await api.put(`/v1/admin/structure/lesson/${node.id}/slots`, { rule: r ?? 'slots', slots: s ?? [] });
      }, 'Lección guardada');
    } else {
      await run(() => api.patch(`/v1/admin/structure/${node.kind}/${node.id}`, data), 'Cambios guardados');
    }
    onChanged(node.id);
  }

  /** Comprobación previa al envío: indica qué falta antes de llamar a la API. */
  function missing(): string | null {
    if (node.kind === 'lesson' && rule !== 'auto' && !slots.length) return 'La lección no tiene ejercicios asignados: añade huecos o usa la regla automática por habilidad';
    if (node.kind === 'unit' && !((data.skills as string[] | undefined) ?? []).length) return 'Asigna al menos una habilidad a la unidad';
    return null;
  }

  async function submit() {
    const m = missing();
    if (m) { setSubmitIssue(m); return; }
    setSubmitIssue(null);
    await run(() => api.post(`/v1/admin/items/${node.id}/submit`), 'Enviado a revisión');
    onChanged(node.id);
  }

  const setSlot = (i: number, patch: Partial<Slot>) => set('slots', slots.map((s, j) => (j === i ? { ...s, ...patch } : s)));
  const moveSlot = (i: number, d: -1 | 1) => {
    const next = [...slots]; const j = i + d;
    if (j < 0 || j >= next.length) return;
    [next[i], next[j]] = [next[j]!, next[i]!];
    set('slots', next.map((s, k) => ({ ...s, position: k + 1 })));
  };

  return (
    <Panel title={<>{KIND_LABELS[node.kind]} · {node.title}</>} icon="edit_note" actions={<StateChip state={node.state} />} id="node-detail">
      <fieldset className="col g16" disabled={ro} style={{ border: 0, padding: 0, margin: 0 }}>
        {node.kind === 'lesson' ? (
          <>
            <Field label="Nombre" id="n-title"><input id="n-title" className="input" value={String(data.title ?? '')} onChange={(e) => set('title', e.target.value)} /></Field>
            <div className="grid2">
              <Field label="Tipo de lección" id="n-kind"><select id="n-kind" className="input" value={String(data.kind ?? 'free')} onChange={(e) => set('kind', e.target.value)}>{LESSON_KINDS.map((k) => <option key={k.id} value={k.id}>{k.label}</option>)}</select></Field>
              <Field label="Duración estimada (min)" id="n-min"><input id="n-min" className="input mono" type="number" min={1} value={Number(data.estimatedMinutes ?? 5)} onChange={(e) => set('estimatedMinutes', Number(e.target.value))} /></Field>
            </div>
            <Field label="Composición" id="n-rule">
              <select id="n-rule" className="input" value={rule} onChange={(e) => set('rule', e.target.value)}>
                <option value="slots">Huecos de ejercicio</option>
                <option value="auto">Regla automática por habilidad</option>
              </select>
            </Field>
            {rule === 'slots' && (
              <div className="col g8">
                <span className="flabel">Huecos de ejercicio</span>
                {slots.length === 0 ? <p className="t-small muted">Sin huecos todavía.</p> : (
                  <div className="tblwrap"><table className="tbl">
                    <thead><tr><th>Hueco</th><th>Plantilla o pregunta</th><th>Nivel</th><th>Habilidad</th><th><span className="sr-only">Acciones</span></th></tr></thead>
                    <tbody>{slots.map((s, i) => (
                      <tr key={i}>
                        <td className="num">{i + 1}</td>
                        <td>
                          <select aria-label={`Ejercicio del hueco ${i + 1}`} className="input input-sm" value={s.templateId ? `t:${s.templateId}` : s.questionId ? `q:${s.questionId}` : 'auto'}
                            onChange={(e) => { const v = e.target.value; setSlot(i, v === 'auto' ? { templateId: undefined, questionId: undefined, auto: true } : v.startsWith('t:') ? { templateId: v.slice(2), questionId: undefined, auto: false } : { questionId: v.slice(2), templateId: undefined, auto: false }); }}>
                            <option value="auto">Automática por habilidad</option>
                            <optgroup label="Plantillas">{templates.map((t) => <option key={t.id} value={`t:${t.id}`}>{t.title}</option>)}</optgroup>
                            <optgroup label="Preguntas">{questions.map((q) => <option key={q.id} value={`q:${q.id}`}>{q.title}</option>)}</optgroup>
                          </select>
                        </td>
                        <td><select aria-label={`Nivel del hueco ${i + 1}`} className="input input-sm" value={s.difficulty} onChange={(e) => setSlot(i, { difficulty: Number(e.target.value) })}>{[1, 2, 3, 4, 5].map((l) => <option key={l}>{l}</option>)}</select></td>
                        <td><select aria-label={`Habilidad del hueco ${i + 1}`} className="input input-sm" value={s.skillId} onChange={(e) => setSlot(i, { skillId: e.target.value })}>{SKILLS.map((k) => <option key={k.id} value={k.id}>{k.id}</option>)}</select></td>
                        <td className="actions">
                          <button type="button" className="iconbtn iconbtn-sm" aria-label={`Subir hueco ${i + 1}`} onClick={() => moveSlot(i, -1)}><Icon name="arrow_upward" /></button>
                          <button type="button" className="iconbtn iconbtn-sm" aria-label={`Bajar hueco ${i + 1}`} onClick={() => moveSlot(i, 1)}><Icon name="arrow_downward" /></button>
                          <button type="button" className="iconbtn iconbtn-sm" aria-label={`Quitar hueco ${i + 1}`} onClick={() => set('slots', slots.filter((_, j) => j !== i).map((x, k) => ({ ...x, position: k + 1 })))}><Icon name="delete" /></button>
                        </td>
                      </tr>
                    ))}</tbody>
                  </table></div>
                )}
                <button type="button" className="btn btn-secondary btn-sm" onClick={() => set('slots', [...slots, { position: slots.length + 1, difficulty: 2, skillId: 'H4', auto: true }])}><Icon name="add" />Añadir hueco</button>
              </div>
            )}
          </>
        ) : (
          <>
            <Field label="Nombre" id="n-name"><input id="n-name" className="input" value={String(data.name ?? '')} onChange={(e) => set('name', e.target.value)} /></Field>
            <Field label="Descripción" id="n-desc"><input id="n-desc" className="input" value={String(data.description ?? '')} onChange={(e) => set('description', e.target.value)} /></Field>
            {node.kind === 'sector' && (
              <label className="check-row" htmlFor="n-double"><input id="n-double" type="checkbox" checked={Boolean(data.doubleReview)} onChange={(e) => set('doubleReview', e.target.checked)} />Exige dos revisores para validar</label>
            )}
            {node.kind === 'unit' && (
              <>
                <SkillPicker value={(data.skills as string[] | undefined) ?? []} onChange={(v) => set('skills', v)} idPrefix="n-skill" />
                <Field label="Plantillas de la unidad" id="n-tpls" help="Mantén pulsada la tecla Ctrl o Cmd para elegir varias.">
                  <select id="n-tpls" className="input" multiple size={5} value={(data.templateIds as string[] | undefined) ?? []} onChange={(e) => set('templateIds', [...e.target.selectedOptions].map((o) => o.value))}>
                    {templates.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}
                  </select>
                </Field>
                <Field label="Preguntas fijas de la unidad" id="n-qs">
                  <select id="n-qs" className="input" multiple size={4} value={(data.questionIds as string[] | undefined) ?? []} onChange={(e) => set('questionIds', [...e.target.selectedOptions].map((o) => o.value))}>
                    {questions.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}
                  </select>
                </Field>
                {node.coverage && (
                  <p className="t-small muted">Cobertura: {node.coverage.lessons} lecciones · {node.coverage.validatedTemplates} de {node.coverage.templates} plantillas validadas</p>
                )}
              </>
            )}
          </>
        )}
      </fieldset>
      {submitIssue && <div style={{ marginTop: 12 }}><Notice kind="err">{submitIssue}</Notice></div>}
      {editable && node.state !== 'retired' && (
        <div className="row g8 wrap" style={{ marginTop: 16 }}>
          <button type="button" className="btn btn-primary btn-sm" disabled={busy} onClick={save}><Icon name="save" />Guardar</button>
          {['draft', 'changes_requested'].includes(node.state) && <button type="button" className="btn btn-secondary btn-sm" disabled={busy} onClick={submit}><Icon name="send" />Enviar a revisión</button>}
          <button type="button" className="btn btn-danger btn-sm" onClick={() => setRetiring(true)}><Icon name="archive" />Retirar</button>
        </div>
      )}
      {node.state === 'published' && editable && <p className="t-small muted" style={{ marginTop: 8 }}>Guardar un nodo publicado crea una versión nueva en borrador; la publicada sigue llegando a los usuarios.</p>}
      {retiring && (
        <ReasonDialog title={`Retirar ${node.title}`} description="Deja de publicarse y queda en el archivo con su historial. Nada se borra." confirmLabel="Retirar" danger onClose={() => setRetiring(false)}
          onConfirm={async (reason) => { await run(() => api.post(`/v1/admin/structure/${node.kind}/${node.id}/retire`, { reason }), 'Retirado y archivado'); setRetiring(false); onChanged(node.id); }} />
      )}
    </Panel>
  );
}

export function Structure() {
  const { api, account } = useSession();
  const editable = can(account?.role, 'editStructure');
  const state = useAsync(() => api.get<{ tree: TreeNode[]; itinerariesWithoutSector: TreeNode[] }>('/v1/admin/structure'), [api]);
  const content = useAsync(() => api.get<{ items: Item[] }>('/v1/admin/items', { kind: 'template,question' }).then((r) => r.items).catch(() => [] as Item[]), [api]);
  const [selected, setSelected] = useState<string | null>(null);
  const [creating, setCreating] = useState<{ kind: Kind; parent: TreeNode | null } | null>(null);
  const { run } = useAction();
  const tree = useMemo(() => [...(state.data?.tree ?? []), ...(state.data?.itinerariesWithoutSector ?? [])], [state.data]);
  const node = selected ? find(tree, selected) : null;

  async function move(n: TreeNode, dir: 'up' | 'down') {
    await run(() => api.post(`/v1/admin/structure/${n.kind}/${n.id}/move`, { direction: dir }), dir === 'up' ? `${n.title} sube una posición` : `${n.title} baja una posición`);
    state.reload();
  }

  /** Soltar un nodo sobre un hermano: lo lleva a esa posición con los mismos movimientos que los botones. */
  async function reorder(n: { id: string; kind: string }, delta: number) {
    if (!delta) return;
    const dir = delta < 0 ? 'up' : 'down';
    const title = find(tree, n.id)?.title ?? n.id;
    await run(async () => { for (let i = 0; i < Math.abs(delta); i++) await api.post(`/v1/admin/structure/${n.kind}/${n.id}/move`, { direction: dir }); },
      `${title} ${dir === 'up' ? 'sube' : 'baja'} ${Math.abs(delta)} ${Math.abs(delta) === 1 ? 'posición' : 'posiciones'}`);
    state.reload();
  }
  const drag: DragRef = useRef(null);

  const childKind = node ? CHILD[node.kind] : 'sector';
  return (
    <Page title="Sectores e itinerarios" crumbs={[{ label: 'Contenido' }, { label: 'Estructura' }]}
      actions={editable ? <button type="button" className="btn btn-secondary btn-sm" onClick={() => setCreating({ kind: 'sector', parent: null })}><Icon name="add" />Nuevo sector</button> : undefined}>
      {!editable && <Notice>Consulta de la estructura. Solo la administración de contenido crea, ordena y retira nodos.</Notice>}
      <Async state={state}>
        {() => (
          <div className="split-l">
            <Panel title="Árbol" icon="account_tree" actions={editable && node && childKind ? (
              <button type="button" className="btn btn-primary btn-xs" onClick={() => setCreating({ kind: childKind, parent: node })}><Icon name="add" />Nueva {KIND_LABELS[childKind].toLowerCase()}</button>
            ) : undefined}>
              {editable && <p className="t-small muted" style={{ marginBottom: 8 }}>Para reordenar, arrastra un nodo sobre otro del mismo nivel, usa los botones de subir y bajar o pulsa Alt + flecha arriba o abajo.</p>}
              {tree.length === 0 ? <Empty icon="account_tree" title="Todavía no hay sectores" /> : (
                <ul className="tree-list" aria-label="Árbol de contenido">
                  {tree.map((n, i) => <TreeItem key={n.id} node={n} depth={0} selected={selected} onSelect={setSelected} onMove={move} onReorder={reorder} drag={drag} editable={editable} index={i} count={tree.length} />)}
                </ul>
              )}
            </Panel>
            {node ? <NodeDetail node={node} editable={editable} content={content.data ?? []} onChanged={(id) => { state.reload(); if (id) setSelected(id); }} /> : (
              <Panel title="Detalle"><Empty icon="touch_app" title="Elige un nodo del árbol">Selecciona un sector, itinerario, unidad o lección para ver y editar su ficha.</Empty></Panel>
            )}
          </div>
        )}
      </Async>
      {creating && <NewNodeDialog kind={creating.kind} parent={creating.parent} onClose={() => setCreating(null)} onCreated={(it) => { setCreating(null); state.reload(); setSelected(it.id); }} />}
    </Page>
  );
}
