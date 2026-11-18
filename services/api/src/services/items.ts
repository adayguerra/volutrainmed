/**
 * Elementos de contenido versionados con ciclo de revisión
 * (content-authoring y content-review-publishing).
 *
 * Estados: borrador, en revisión, cambios solicitados, validado, publicado y
 * retirado. Cambiar un contenido publicado o validado crea una versión nueva en
 * borrador; la versión publicada sigue llegando a los usuarios.
 */
import { checkAdCreative, checkDimensions, massTest, validateQuestion, validateTemplate, type QuestionDefinition, type TemplateDefinition } from '@vtm/engine';
import type { Tx } from '../db/pool.js';
import { audit } from '../lib/audit.js';
import { sha256 } from '../lib/crypto.js';
import { ApiError, bad, conflict, forbidden, notFound } from '../lib/errors.js';
import type { BoCtx } from '../server.js';

export const KINDS = [
  'sector', 'itinerary', 'unit', 'lesson', 'template', 'question', 'exercise_type',
  'catalog_unit', 'catalog_instrument', 'voice_lexicon', 'ad_creative', 'ad_campaign', 'achievement',
  'catalog_skill', 'catalog_species',
] as const;
export type Kind = (typeof KINDS)[number];

export const STRUCTURE_KINDS: Kind[] = ['sector', 'itinerary', 'unit', 'lesson'];

export const CHECKLIST_KEYS = [
  'pauta_plausible', 'presentacion_existente', 'unidades_correctas', 'aritmetica_verificada',
  'redondeo_instrumento', 'explicacion_clara', 'texto_voz_correcto', 'errores_previsibles_pertinentes',
] as const;

export const CHECKLIST_LABELS: Record<(typeof CHECKLIST_KEYS)[number], string> = {
  pauta_plausible: 'Pauta plausible',
  presentacion_existente: 'Presentación existente',
  unidades_correctas: 'Unidades correctas',
  aritmetica_verificada: 'Aritmética verificada',
  redondeo_instrumento: 'Redondeo adecuado al instrumento',
  explicacion_clara: 'Explicación clara',
  texto_voz_correcto: 'Texto para voz correcto',
  errores_previsibles_pertinentes: 'Errores previsibles pertinentes',
};

export interface ItemRow {
  id: string; version: number; kind: Kind; state: string; sector_id: string | null; parent_id: string | null; ord: number;
  title: string; data: Record<string, unknown>; author_id: string | null; fingerprint: string; validations: number;
  validated_until: string | null; submitted_data: Record<string, unknown> | null; created_at: string; updated_at: string; linked_inquiry: string | null;
}

const CONTENT_EDITORS = ['superadmin', 'content_admin', 'author'];

export function fingerprintOf(data: unknown): string { return sha256(JSON.stringify(data)); }

function titleOf(kind: Kind, data: Record<string, unknown>): string {
  return String(data.name ?? data.title ?? data.headline ?? data.id ?? kind);
}

function sectorOf(kind: Kind, data: Record<string, unknown>): string | null {
  if (kind === 'sector') return String(data.id ?? '');
  return (data.sectorId as string | undefined) ?? null;
}

function parentOf(kind: Kind, data: Record<string, unknown>): string | null {
  if (kind === 'itinerary') return (data.sectorId as string) ?? null;
  if (kind === 'unit') return (data.itineraryId as string) ?? null;
  if (kind === 'lesson') return (data.unitId as string) ?? null;
  if (kind === 'ad_creative') return (data.campaignId as string) ?? null;
  return null;
}

/** Comprobaciones al guardar: lo que nunca se puede guardar (p. ej. una fórmula sin cuadrar en unidades). */
export function checkOnSave(kind: Kind, data: Record<string, unknown>): void {
  if (kind === 'template') {
    const t = data as unknown as TemplateDefinition;
    if (t.formula?.trim()) {
      const units: Record<string, string> = {};
      for (const v of t.variables ?? []) {
        if (v.kind === 'case_table') for (const c of v.columns ?? []) units[`${v.name}.${c.name}`] = c.unit;
        else units[v.name] = v.unit;
      }
      const dc = checkDimensions(t.formula, units, t.answerUnit);
      if (!dc.ok) throw new ApiError(422, 'formula_units', dc.message);
    }
  }
  // Catálogos de habilidades y especies (tareas 2.3 del back office).
  if (kind === 'catalog_skill') {
    if (!/^H\d{1,2}$/.test(String(data.code ?? ''))) throw new ApiError(422, 'skill_code', 'El código de la habilidad tiene la forma H1, H2…');
    if (!String(data.name ?? '').trim()) throw new ApiError(422, 'name_required', 'Falta el nombre de la habilidad');
  }
  if (kind === 'catalog_species' && !String(data.name ?? '').trim()) throw new ApiError(422, 'name_required', 'Falta el nombre de la especie');
}

/** Comprobaciones previas al envío a revisión. Devuelve los motivos que lo impiden. */
export async function checkBeforeSubmit(tx: Tx, item: ItemRow): Promise<string[]> {
  const d = item.data;
  const issues: string[] = [];
  if (item.kind === 'template') {
    const t = d as unknown as TemplateDefinition;
    issues.push(...validateTemplate(t).filter((i) => i.blocking).map((i) => i.message));
    if (!issues.length) {
      const mt = massTest(t, 300);
      if (mt.collisions) issues.push(`La prueba masiva detecta ${mt.collisions} colisiones entre la respuesta correcta y una errónea previsible`);
      if (mt.doubleCheckFailures) issues.push('El doble cálculo no coincide en alguna variante');
      if (mt.valid === 0) issues.push('Ninguna variante cumple las restricciones. Amplía los rangos');
    }
  } else if (item.kind === 'question') {
    const existing = (await tx.query("SELECT data->>'statement' AS s FROM content_items WHERE kind = 'question' AND id <> $1", [item.id])).rows.map((r) => String(r.s ?? ''));
    issues.push(...validateQuestion(d as unknown as QuestionDefinition, existing).filter((i) => i.blocking).map((i) => i.message));
  } else if (item.kind === 'lesson') {
    const rule = d.rule ?? 'slots';
    const slots = (d.slots as unknown[] | undefined) ?? [];
    if (rule !== 'auto' && !slots.length) issues.push('La lección no tiene ejercicios asignados: añade huecos o usa la regla automática por habilidad');
    if (rule === 'auto') {
      const unit = (await tx.query("SELECT data FROM content_items WHERE kind = 'unit' AND id = $1 ORDER BY version DESC LIMIT 1", [d.unitId])).rows[0];
      const tpls = ((unit?.data?.templateIds as unknown[]) ?? []).length + ((unit?.data?.questionIds as unknown[]) ?? []).length;
      if (!tpls) issues.push('La unidad no tiene plantillas ni preguntas: la regla automática no puede componer la lección');
    }
  } else if (item.kind === 'ad_creative') {
    issues.push(...checkAdCreative(d as never).map((i) => i.message));
  } else if (item.kind === 'unit') {
    if (!((d.skills as unknown[]) ?? []).length) issues.push('Asigna al menos una habilidad a la unidad');
  } else if (item.kind === 'exercise_type') {
    const steps = (d.steps as { response?: string }[] | undefined) ?? [];
    steps.forEach((s, i) => { if (!s.response) issues.push(`Paso ${i + 1}: falta el bloque de respuesta`); });
    if (!steps.length) issues.push('El tipo necesita al menos un paso');
  }
  return issues;
}

export async function latest(tx: Tx, id: string): Promise<ItemRow> {
  const { rows } = await tx.query('SELECT * FROM content_items WHERE id = $1 ORDER BY version DESC LIMIT 1', [id]);
  if (!rows[0]) throw notFound('El elemento no existe');
  return rows[0] as ItemRow;
}

export async function versions(tx: Tx, id: string): Promise<ItemRow[]> {
  return (await tx.query('SELECT * FROM content_items WHERE id = $1 ORDER BY version DESC', [id])).rows as ItemRow[];
}

function slug(s: string): string {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 40);
}

export async function createItem(tx: Tx, bo: BoCtx, kind: Kind, data: Record<string, unknown>, opts: { id?: string; state?: string; ord?: number } = {}): Promise<ItemRow> {
  if (!KINDS.includes(kind)) throw bad('invalid_kind', 'Tipo de elemento desconocido');
  if (STRUCTURE_KINDS.includes(kind) || kind === 'exercise_type') {
    if (!['superadmin', 'content_admin'].includes(bo.role)) throw forbidden('Solo la administración de contenido gestiona la estructura y los tipos');
  } else if (['ad_creative', 'ad_campaign', 'achievement', 'catalog_unit', 'catalog_instrument', 'voice_lexicon', 'catalog_skill', 'catalog_species'].includes(kind)) {
    if (!['superadmin', 'content_admin'].includes(bo.role)) throw forbidden();
  } else if (!CONTENT_EDITORS.includes(bo.role)) throw forbidden('Tu rol no crea contenido');
  checkOnSave(kind, data);
  const prefix = { template: 'tpl', question: 'q', sector: 'sec', itinerary: 'it', unit: 'u', lesson: 'l', exercise_type: 'type', catalog_unit: 'cu', catalog_instrument: 'ci', voice_lexicon: 'vl', ad_creative: 'ad', ad_campaign: 'camp', achievement: 'ach', catalog_skill: 'cs', catalog_species: 'sp' }[kind];
  const id = opts.id ?? (data.id as string | undefined) ?? `${prefix}-${slug(titleOf(kind, data))}-${Math.random().toString(36).slice(2, 6)}`;
  const exists = (await tx.query('SELECT 1 FROM content_items WHERE id = $1', [id])).rowCount;
  if (exists) throw conflict('duplicate_id', 'Ya existe un elemento con ese identificador');
  const full = { ...data, id };
  let ord = opts.ord;
  if (ord === undefined) {
    const parent = parentOf(kind, full);
    ord = Number((await tx.query('SELECT coalesce(max(ord), 0) + 1 AS n FROM content_items WHERE kind = $1 AND coalesce(parent_id, \'\') = coalesce($2, \'\')', [kind, parent])).rows[0].n);
  }
  const { rows } = await tx.query(
    `INSERT INTO content_items(id, version, kind, state, sector_id, parent_id, ord, title, data, author_id, fingerprint)
     VALUES ($1, 1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
    [id, kind, opts.state ?? 'draft', sectorOf(kind, full), parentOf(kind, full), ord, titleOf(kind, full), JSON.stringify(full), bo.accountId, fingerprintOf(full)],
  );
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.create', entity: kind, entityId: id, after: full });
  return rows[0] as ItemRow;
}

export async function updateItem(tx: Tx, bo: BoCtx, id: string, data: Record<string, unknown>): Promise<ItemRow> {
  const cur = await latest(tx, id);
  if (cur.state === 'retired') throw conflict('retired', 'El elemento está retirado');
  if (bo.role === 'author' && cur.author_id !== bo.accountId) throw forbidden('Solo puedes modificar tu propio contenido');
  if (['reviewer', 'analyst', 'support', 'org_admin'].includes(bo.role)) throw forbidden('Tu rol no modifica contenido');
  checkOnSave(cur.kind, data);
  const full = { ...data, id };
  let row: ItemRow;
  if (['published', 'validated'].includes(cur.state)) {
    const { rows } = await tx.query(
      `INSERT INTO content_items(id, version, kind, state, sector_id, parent_id, ord, title, data, author_id, fingerprint, linked_inquiry)
       VALUES ($1, $2, $3, 'draft', $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *`,
      [id, cur.version + 1, cur.kind, sectorOf(cur.kind, full), parentOf(cur.kind, full), cur.ord, titleOf(cur.kind, full), JSON.stringify(full), cur.author_id ?? bo.accountId, fingerprintOf(full), cur.linked_inquiry],
    );
    row = rows[0] as ItemRow;
  } else {
    const nextState = cur.state === 'changes_requested' ? 'changes_requested' : cur.state;
    const { rows } = await tx.query(
      'UPDATE content_items SET data = $3, title = $4, sector_id = $5, parent_id = $6, fingerprint = $7, state = $8 WHERE id = $1 AND version = $2 RETURNING *',
      [id, cur.version, JSON.stringify(full), titleOf(cur.kind, full), sectorOf(cur.kind, full), parentOf(cur.kind, full), fingerprintOf(full), nextState],
    );
    row = rows[0] as ItemRow;
  }
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.update', entity: cur.kind, entityId: id, before: cur.data, after: full });
  return row;
}

export async function submitItem(tx: Tx, bo: BoCtx, id: string): Promise<ItemRow> {
  const cur = await latest(tx, id);
  if (!['draft', 'changes_requested'].includes(cur.state)) throw conflict('invalid_state', 'Solo se envían a revisión borradores o contenidos con cambios solicitados');
  if (bo.role === 'author' && cur.author_id !== bo.accountId) throw forbidden('Solo puedes enviar tu propio contenido');
  const issues = await checkBeforeSubmit(tx, cur);
  if (issues.length) throw new ApiError(422, 'submit_blocked', issues.join(' · '));
  const { rows } = await tx.query(
    "UPDATE content_items SET state = 'in_review', submitted_data = data, submitted_at = now(), validations = 0 WHERE id = $1 AND version = $2 RETURNING *",
    [id, cur.version],
  );
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.submit', entity: cur.kind, entityId: id });
  return rows[0] as ItemRow;
}

export async function retireItem(tx: Tx, bo: BoCtx, id: string, reason: string): Promise<ItemRow> {
  if (!['superadmin', 'content_admin'].includes(bo.role)) throw forbidden('Solo la administración de contenido retira contenido');
  if (!reason?.trim()) throw bad('reason_required', 'Indica el motivo');
  const cur = await latest(tx, id);
  const { rows } = await tx.query("UPDATE content_items SET state = 'retired' WHERE id = $1 AND version = $2 RETURNING *", [id, cur.version]);
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.retire', entity: cur.kind, entityId: id, before: { state: cur.state }, after: { state: 'retired' }, reason });
  return rows[0] as ItemRow;
}

export async function moveItem(tx: Tx, bo: BoCtx, id: string, direction: 'up' | 'down'): Promise<void> {
  if (!['superadmin', 'content_admin'].includes(bo.role)) throw forbidden();
  const cur = await latest(tx, id);
  const siblings = (await tx.query(
    `SELECT DISTINCT ON (id) id, version, ord FROM content_items WHERE kind = $1 AND coalesce(parent_id,'') = coalesce($2,'') AND state <> 'retired' ORDER BY id, version DESC`,
    [cur.kind, cur.parent_id],
  )).rows.sort((a, b) => a.ord - b.ord);
  const i = siblings.findIndex((s) => s.id === id);
  const j = direction === 'up' ? i - 1 : i + 1;
  if (i < 0 || j < 0 || j >= siblings.length) return;
  const a = siblings[i]; const b = siblings[j];
  await tx.query('UPDATE content_items SET ord = $2 WHERE id = $1', [a.id, b.ord]);
  await tx.query('UPDATE content_items SET ord = $2 WHERE id = $1', [b.id, a.ord]);
  // Si las órdenes coinciden, se fuerza un orden estricto.
  if (a.ord === b.ord) await tx.query('UPDATE content_items SET ord = $2 WHERE id = $1', [a.id, direction === 'up' ? b.ord - 1 : b.ord + 1]);
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'structure.reorder', entity: cur.kind, entityId: id, after: { direction } });
}

/** Revisión por un experto distinto del autor, con lista de comprobación, firma y caducidad. */
export async function decide(tx: Tx, bo: BoCtx, id: string, body: { decision: 'validate' | 'request_changes' | 'reject'; checklist?: Record<string, boolean>; comment?: string; fingerprint?: string }) {
  const cur = await latest(tx, id);
  if (cur.state !== 'in_review') throw conflict('invalid_state', 'El elemento no está en revisión');
  if (body.fingerprint && body.fingerprint !== cur.fingerprint) {
    throw conflict('modified_during_review', 'El autor ha modificado el contenido durante la revisión: revisa las diferencias; la lista de comprobación se reinicia');
  }
  if (bo.role !== 'reviewer') throw forbidden('Solo un revisor experto decide sobre una revisión');
  if (body.decision === 'validate') {
    if (cur.author_id === bo.accountId) throw forbidden('Nadie valida contenido propio');
    const sector = cur.sector_id;
    if (sector && sector !== 'comun' && !bo.sectors.includes(sector)) throw forbidden('No estás acreditado en este sector: puedes comentar, no validar');
    const missing = CHECKLIST_KEYS.filter((k) => !body.checklist?.[k]);
    if (missing.length) throw new ApiError(422, 'checklist_incomplete', `Falta marcar: ${missing.map((k) => CHECKLIST_LABELS[k]).join(', ')}`);
    // Solo cuentan las validaciones de este ciclo de revisión (tras el último envío o la caducidad).
    const already = (await tx.query(
      "SELECT 1 FROM reviews WHERE item_id = $1 AND item_version = $2 AND reviewer_id = $3 AND decision = 'validate' AND created_at >= coalesce((SELECT submitted_at FROM content_items WHERE id = $1 AND version = $2), '-infinity')",
      [id, cur.version, bo.accountId])).rowCount;
    if (already) throw conflict('already_validated', 'Ya has validado esta versión');
  } else if (!body.comment?.trim()) {
    throw bad('comment_required', 'El comentario es obligatorio para solicitar cambios o rechazar');
  }
  const acc = (await tx.query('SELECT accreditation FROM bo_accounts WHERE id = $1', [bo.accountId])).rows[0];
  const expires = new Date(); expires.setMonth(expires.getMonth() + 24);
  await tx.query(
    'INSERT INTO reviews(item_id, item_version, reviewer_id, decision, checklist, comment, accreditation, fingerprint, expires_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)',
    [id, cur.version, bo.accountId, body.decision, JSON.stringify(body.checklist ?? {}), body.comment ?? null, acc?.accreditation ?? null, cur.fingerprint, body.decision === 'validate' ? expires : null],
  );
  let state = cur.state;
  let validations = cur.validations;
  if (body.decision === 'validate') {
    validations += 1;
    const doubleReview = cur.sector_id ? Boolean((await tx.query("SELECT data->>'doubleReview' AS d FROM content_items WHERE kind = 'sector' AND id = $1 ORDER BY version DESC LIMIT 1", [cur.sector_id])).rows[0]?.d === 'true') : false;
    const required = doubleReview ? 2 : 1;
    if (validations >= required) state = 'validated';
  } else if (body.decision === 'request_changes') state = 'changes_requested';
  else state = 'draft';
  await tx.query('UPDATE content_items SET state = $3, validations = $4, validated_until = $5 WHERE id = $1 AND version = $2', [id, cur.version, state, validations, state === 'validated' ? expires : null]);
  await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: `review.${body.decision}`, entity: cur.kind, entityId: id, after: { state, validations, comment: body.comment ?? null } });
  return { state, validations };
}

/** Caducidad de la validación: a los 24 meses o al marcar un cambio en la información del fármaco. */
export async function expireValidations(tx: Tx): Promise<number> {
  const { rowCount } = await tx.query(
    "UPDATE content_items SET state = 'in_review', validations = 0, submitted_data = data, submitted_at = now() WHERE state IN ('validated','published') AND (validated_until < now() OR drug_info_changed) AND kind IN ('template','question')",
  );
  return rowCount ?? 0;
}

export function diffData(a: unknown, b: unknown, path = ''): { path: string; before: unknown; after: unknown }[] {
  if (JSON.stringify(a) === JSON.stringify(b)) return [];
  if (a && b && typeof a === 'object' && typeof b === 'object' && !Array.isArray(a) && !Array.isArray(b)) {
    const keys = new Set([...Object.keys(a as object), ...Object.keys(b as object)]);
    return [...keys].flatMap((k) => diffData((a as Record<string, unknown>)[k], (b as Record<string, unknown>)[k], path ? `${path}.${k}` : k));
  }
  return [{ path, before: a, after: b }];
}
