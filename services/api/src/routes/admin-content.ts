/** Back office de contenido: estructura, elementos, motor, importación y revisión. */
import type { FastifyInstance } from 'fastify';
import {
  checkDimensions, generateVariants, massTest, validateTemplate, resolveQuestion, validateQuestion, speakText, parseSpoken, grade, readQuantity,
  segmentsToText, type TemplateDefinition, type QuestionDefinition, type SpokenOptions,
} from '@vtm/engine';
import { evalInB } from '@vtm/engine';
import type { AnswerSpec, PredictedError } from '@vtm/contracts';
import { withTx } from '../db/pool.js';
import { ApiError, bad, forbidden, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { requireBo, boActor } from '../server.js';
import {
  CHECKLIST_KEYS, CHECKLIST_LABELS, KINDS, STRUCTURE_KINDS, createItem, decide, diffData, latest, moveItem, retireItem, submitItem, updateItem, versions,
  type ItemRow, type Kind,
} from '../services/items.js';

const ALL_BO = ['superadmin', 'content_admin', 'author', 'reviewer', 'analyst', 'support', 'org_admin'] as const;

function itemView(r: ItemRow) {
  return {
    id: r.id, version: r.version, kind: r.kind, state: r.state, sectorId: r.sector_id, parentId: r.parent_id, order: r.ord, title: r.title, data: r.data,
    authorId: r.author_id, fingerprint: r.fingerprint, validations: r.validations, validatedUntil: r.validated_until, updatedAt: r.updated_at, createdAt: r.created_at,
    linkedInquiry: r.linked_inquiry,
  };
}

export const IMPORT_COLUMNS: Record<string, { key: string; label: string; required: boolean }[]> = {
  T1: [
    { key: 'enunciado', label: 'Enunciado', required: true }, { key: 'pregunta', label: 'Pregunta', required: true }, { key: 'respuesta', label: 'Respuesta', required: true },
    { key: 'unidad', label: 'Unidad de la respuesta', required: true }, { key: 'decimales', label: 'Decimales', required: false }, { key: 'habilidad', label: 'Habilidad (H1–H12)', required: true },
    { key: 'sector', label: 'Sector', required: true }, { key: 'nivel', label: 'Nivel (1–5)', required: true }, { key: 'explicacion', label: 'Explicación (pasos separados por |)', required: true },
    { key: 'tiempo_objetivo', label: 'Tiempo objetivo (s)', required: false },
  ],
  T2: [
    { key: 'enunciado', label: 'Enunciado', required: true }, { key: 'pregunta', label: 'Pregunta', required: true }, { key: 'correcta', label: 'Opción correcta', required: true },
    { key: 'falsa1', label: 'Opción falsa 1', required: true }, { key: 'error1', label: 'Tipo de error 1 (E0–E7)', required: true }, { key: 'falsa2', label: 'Opción falsa 2', required: true },
    { key: 'error2', label: 'Tipo de error 2', required: true }, { key: 'falsa3', label: 'Opción falsa 3', required: false }, { key: 'error3', label: 'Tipo de error 3', required: false },
    { key: 'habilidad', label: 'Habilidad', required: true }, { key: 'sector', label: 'Sector', required: true }, { key: 'nivel', label: 'Nivel', required: true },
    { key: 'explicacion', label: 'Explicación', required: true },
  ],
  case_rows: [{ key: 'farmaco', label: 'Fármaco (principio activo)', required: true }, { key: 'dosis', label: 'Pauta', required: true }, { key: 'conc', label: 'Presentación', required: true }, { key: 'especie', label: 'Especie', required: false }],
};

function rowToQuestion(type: string, row: Record<string, string>, i: number): { q?: QuestionDefinition; errors: string[] } {
  const errors: string[] = [];
  const cols = IMPORT_COLUMNS[type] ?? [];
  for (const c of cols) if (c.required && !String(row[c.key] ?? '').trim()) errors.push(`Fila ${i + 1}: falta ${c.key === 'unidad' ? 'la unidad de la respuesta' : c.label.toLowerCase()}`);
  if (errors.length) return { errors };
  const level = Number(row.nivel);
  if (!(level >= 1 && level <= 5)) errors.push(`Fila ${i + 1}: el nivel debe estar entre 1 y 5`);
  if (!/^H(1[0-2]|[1-9])$/.test(row.habilidad ?? '')) errors.push(`Fila ${i + 1}: habilidad no válida`);
  const steps = String(row.explicacion ?? '').split('|').map((s, n) => ({ n: n + 1, text: s.trim(), operation: s.trim(), result: { value: '0', unit: '' }, cancelled: [] }));
  const base = {
    id: `q-imp-${Date.now().toString(36)}-${i}`, version: 1, name: String(row.pregunta).slice(0, 60), sectorId: row.sector!, skillId: row.habilidad as never, level: level as 1,
    targetTimeS: Number(row.tiempo_objetivo ?? 30) || 30, statement: row.enunciado!, question: row.pregunta!, steps, plausibility: '', demo: true,
  };
  let q: QuestionDefinition;
  if (type === 'T1') {
    const value = String(row.respuesta).replace(',', '.').trim();
    if (!/^-?\d+(\.\d+)?$/.test(value)) errors.push(`Fila ${i + 1}: la respuesta no es una cifra`);
    const places = row.decimales ? Number(row.decimales) : null;
    const answer: AnswerSpec = { value, unit: row.unidad!, unitFixed: level <= 3, unitChoices: [row.unidad!], equivalents: [], rounding: places === null ? { mode: 'none' } : { mode: 'decimals', places }, tolerance: { kind: 'exact' } };
    q = { ...base, exerciseTypeId: 'T1', answer };
  } else {
    const opts = [{ label: row.correcta!, correct: true }];
    for (const k of [1, 2, 3]) if (row[`falsa${k}`]?.trim()) opts.push({ label: row[`falsa${k}`]!, correct: false, errorCode: (row[`error${k}`] ?? 'E0') as never } as never);
    q = { ...base, exerciseTypeId: 'T2', options: opts };
  }
  errors.push(...validateQuestion(q).filter((x) => x.blocking).map((x) => `Fila ${i + 1}: ${x.message}`));
  return { q, errors };
}

export async function adminContentRoutes(app: FastifyInstance) {
  // ------------------------------------------------------------------ Estructura
  app.get('/v1/admin/structure', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query(`SELECT DISTINCT ON (id) * FROM content_items WHERE kind = ANY($1) ORDER BY id, version DESC`, [STRUCTURE_KINDS])).rows as ItemRow[];
      const items = rows.map(itemView).sort((a, b) => a.order - b.order);
      const counts = (await tx.query(`SELECT data->>'unitId' AS unit, count(*)::int AS n FROM content_items WHERE kind = 'lesson' GROUP BY 1`)).rows;
      const validatedTemplates = new Set((await tx.query("SELECT DISTINCT id FROM content_items WHERE kind IN ('template','question') AND state IN ('validated','published')")).rows.map((r) => r.id));
      const build = (kind: Kind, parent: string | null): unknown[] => items.filter((i) => i.kind === kind && (kind === 'sector' || i.parentId === parent)).map((i) => {
        const childKind = ({ sector: 'itinerary', itinerary: 'unit', unit: 'lesson' } as Record<string, Kind>)[kind];
        const node: Record<string, unknown> = { ...i, children: childKind ? build(childKind, i.id) : [] };
        if (kind === 'unit') {
          const tids = [...(((i.data.templateIds as string[]) ?? [])), ...(((i.data.questionIds as string[]) ?? []))];
          node.coverage = { lessons: counts.find((c) => c.unit === i.id)?.n ?? 0, templates: tids.length, validatedTemplates: tids.filter((t) => validatedTemplates.has(t)).length };
        }
        return node;
      });
      return { tree: build('sector', null), itinerariesWithoutSector: items.filter((i) => i.kind === 'itinerary' && !items.some((s) => s.kind === 'sector' && s.id === i.parentId)).map((i) => ({ ...i, children: build('unit', i.id) })) };
    });
  });

  app.post<{ Params: { kind: string }; Body: Record<string, unknown> }>('/v1/admin/structure/:kind', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    const kind = req.params.kind as Kind;
    if (!STRUCTURE_KINDS.includes(kind)) throw bad('invalid_kind', 'Tipo de nodo no válido');
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await createItem(tx, bo, kind, req.body ?? {})) }));
  });

  app.patch<{ Params: { kind: string; id: string }; Body: Record<string, unknown> }>('/v1/admin/structure/:kind/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.id);
      return { item: itemView(await updateItem(tx, bo, req.params.id, { ...cur.data, ...(req.body ?? {}) })) };
    });
  });

  app.post<{ Params: { kind: string; id: string }; Body: { direction: 'up' | 'down' } }>('/v1/admin/structure/:kind/:id/move', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    await withTx(boActor(bo), (tx) => moveItem(tx, bo, req.params.id, req.body?.direction === 'up' ? 'up' : 'down'));
    return { ok: true };
  });

  app.post<{ Params: { kind: string; id: string }; Body: { reason: string } }>('/v1/admin/structure/:kind/:id/retire', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await retireItem(tx, bo, req.params.id, req.body?.reason ?? '')) }));
  });

  app.put<{ Params: { id: string }; Body: { rule: 'auto' | 'slots'; slots?: unknown[] } }>('/v1/admin/structure/lesson/:id/slots', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.id);
      const item = await updateItem(tx, bo, req.params.id, { ...cur.data, rule: req.body?.rule ?? 'slots', slots: req.body?.slots ?? [] });
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'lesson.compose', entity: 'lesson', entityId: req.params.id, after: { rule: req.body?.rule, slots: (req.body?.slots ?? []).length } });
      return { item: itemView(item) };
    });
  });

  // ------------------------------------------------------------------ Elementos
  app.get<{ Querystring: { kind?: string; state?: string; sector?: string; q?: string; mine?: string; includeRetired?: string } }>('/v1/admin/items', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query('SELECT DISTINCT ON (id) * FROM content_items ORDER BY id, version DESC')).rows as ItemRow[];
      const q = (req.query.q ?? '').toLowerCase();
      const items = rows.filter((r) =>
        (!req.query.kind || req.query.kind.split(',').includes(r.kind))
        && (!req.query.state || req.query.state.split(',').includes(r.state))
        && (req.query.includeRetired === '1' || req.query.state?.includes('retired') || r.state !== 'retired')
        && (!req.query.sector || r.sector_id === req.query.sector)
        && (!q || r.title.toLowerCase().includes(q) || r.id.includes(q))
        && (req.query.mine !== '1' || r.author_id === bo.accountId));
      const authors = new Map((await tx.query('SELECT id, name FROM bo_accounts')).rows.map((a) => [a.id, a.name]));
      return { items: items.sort((a, b) => (a.updated_at < b.updated_at ? 1 : -1)).map((r) => ({ ...itemView(r), authorName: authors.get(r.author_id) ?? null, canEdit: bo.role === 'superadmin' || bo.role === 'content_admin' || (bo.role === 'author' && r.author_id === bo.accountId) })) };
    });
  });

  app.get<{ Params: { id: string } }>('/v1/admin/items/:id', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    return withTx(boActor(bo), async (tx) => {
      const vs = await versions(tx, req.params.id);
      if (!vs.length) throw notFound();
      const reviews = (await tx.query('SELECT r.*, a.name AS reviewer_name FROM reviews r JOIN bo_accounts a ON a.id = r.reviewer_id WHERE item_id = $1 ORDER BY created_at DESC', [req.params.id])).rows;
      const comments = (await tx.query('SELECT c.*, a.name AS author_name FROM review_comments c JOIN bo_accounts a ON a.id = c.author_id WHERE item_id = $1 ORDER BY created_at', [req.params.id])).rows;
      const cur = vs[0]!;
      return {
        item: itemView(cur), versions: vs.map(itemView), reviews, comments,
        canEdit: bo.role === 'superadmin' || bo.role === 'content_admin' || (bo.role === 'author' && cur.author_id === bo.accountId),
        canValidate: bo.role === 'reviewer' && cur.author_id !== bo.accountId && (!cur.sector_id || cur.sector_id === 'comun' || bo.sectors.includes(cur.sector_id)),
      };
    });
  });

  app.post<{ Body: { kind: Kind; data: Record<string, unknown> } }>('/v1/admin/items', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'author']);
    if (!KINDS.includes(req.body?.kind)) throw bad('invalid_kind', 'Tipo de elemento desconocido');
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await createItem(tx, bo, req.body.kind, req.body.data ?? {})) }));
  });

  app.put<{ Params: { id: string }; Body: { data: Record<string, unknown> } }>('/v1/admin/items/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'author']);
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await updateItem(tx, bo, req.params.id, req.body?.data ?? {})) }));
  });

  app.post<{ Params: { id: string } }>('/v1/admin/items/:id/submit', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'author']);
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await submitItem(tx, bo, req.params.id)) }));
  });

  app.post<{ Params: { id: string }; Body: { reason: string } }>('/v1/admin/items/:id/retire', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => ({ item: itemView(await retireItem(tx, bo, req.params.id, req.body?.reason ?? '')) }));
  });

  app.post<{ Params: { id: string } }>('/v1/admin/items/:id/drug-info-changed', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.id);
      await tx.query("UPDATE content_items SET drug_info_changed = true, state = 'in_review', validations = 0, submitted_data = data, submitted_at = now() WHERE id = $1 AND version = $2", [cur.id, cur.version]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'item.drug_info_changed', entity: cur.kind, entityId: cur.id });
      return { ok: true };
    });
  });

  app.get<{ Params: { id: string }; Querystring: { from?: string; to?: string } }>('/v1/admin/items/:id/diff', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    return withTx(boActor(bo), async (tx) => {
      const vs = await versions(tx, req.params.id);
      const cur = vs[0]!;
      if (!req.query.from && cur.submitted_data) return { from: 'enviado a revisión', to: 'actual', changes: diffData(cur.submitted_data, cur.data) };
      const a = vs.find((v) => v.version === Number(req.query.from)) ?? vs[1] ?? cur;
      const b = vs.find((v) => v.version === Number(req.query.to)) ?? cur;
      return { from: a.version, to: b.version, changes: diffData(a.data, b.data) };
    });
  });

  // ------------------------------------------------------------------ Motor (vista previa y pruebas)
  app.post<{ Body: { formula: string; units: Record<string, string>; answerUnit: string } }>('/v1/admin/engine/check-dimensions', async (req) => {
    requireBo(req, [...ALL_BO]);
    return checkDimensions(req.body.formula ?? '', req.body.units ?? {}, req.body.answerUnit ?? '');
  });

  app.post<{ Body: { definition: TemplateDefinition; n?: number; level?: number } }>('/v1/admin/engine/sample', async (req) => {
    requireBo(req, [...ALL_BO]);
    const def = req.body.definition;
    const levels = req.body.level ? [req.body.level] : def.levels.map((l) => l.level);
    const n = Math.min(req.body.n ?? 20, 100);
    const perLevel = Math.max(1, Math.ceil(n / levels.length));
    try {
      const res = generateVariants(def, { perLevel, levels, seed: Date.now() % 100000 });
      return { variants: res.variants.slice(0, n).map((r) => ({ ...r.variant, statementText: segmentsToText(r.variant.statement), assignment: r.assignment, unrounded: r.unrounded, doubleCheck: r.doubleCheck, collision: r.collision })), reports: res.reports };
    } catch (e) {
      throw new ApiError(422, 'generation_failed', (e as Error).message);
    }
  });

  app.post<{ Body: { definition: TemplateDefinition; draws?: number } }>('/v1/admin/engine/mass-test', async (req) => {
    requireBo(req, [...ALL_BO]);
    try { return massTest(req.body.definition, Math.min(req.body.draws ?? 1000, 5000)); } catch (e) { throw new ApiError(422, 'generation_failed', (e as Error).message); }
  });

  app.post<{ Body: { definition: TemplateDefinition } }>('/v1/admin/engine/validate', async (req) => {
    requireBo(req, [...ALL_BO]);
    return { issues: validateTemplate(req.body.definition) };
  });

  app.post<{ Body: { question: QuestionDefinition } }>('/v1/admin/engine/question-preview', async (req) => {
    requireBo(req, [...ALL_BO]);
    const v = resolveQuestion(req.body.question);
    return { variant: { ...v, statementText: segmentsToText(v.statement) }, issues: validateQuestion(req.body.question) };
  });

  app.post<{ Body: { text: string } }>('/v1/admin/engine/speak', async (req) => {
    requireBo(req, [...ALL_BO]);
    return { spoken: speakText(req.body.text ?? '') };
  });

  app.post<{ Body: { value: string; unit: string } }>('/v1/admin/engine/read-quantity', async (req) => {
    requireBo(req, [...ALL_BO]);
    return { spoken: readQuantity(req.body.value, req.body.unit) };
  });

  app.post<{ Body: { text: string; options?: SpokenOptions } }>('/v1/admin/engine/parse-spoken', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    const res = parseSpoken(req.body.text ?? '', req.body.options ?? {});
    await withTx(boActor(bo), (tx) => tx.query("INSERT INTO events(id, name, at, props) VALUES (gen_random_uuid(), 'bo_voice_lexicon_tested', now(), $1)", [JSON.stringify({ parsed_ok: res.kind === 'number' })]));
    return res;
  });

  app.post<{ Body: { answer: AnswerSpec; predicted?: PredictedError[]; input: { raw: string; unit?: string } } }>('/v1/admin/engine/grade', async (req) => {
    requireBo(req, [...ALL_BO]);
    return grade(req.body.answer, req.body.predicted ?? [], req.body.input);
  });

  app.post<{ Body: { formula: string; scope: Record<string, { value: string; unit: string }>; unit: string } }>('/v1/admin/engine/recalculate', async (req) => {
    requireBo(req, [...ALL_BO]);
    return { value: evalInB(req.body.formula, req.body.scope, req.body.unit).toDecimalString(12) };
  });

  // ------------------------------------------------------------------ Importación masiva
  app.get<{ Querystring: { type?: string } }>('/v1/admin/import/template', async (req, reply) => {
    requireBo(req, ['superadmin', 'content_admin', 'author']);
    const cols = IMPORT_COLUMNS[req.query.type ?? 'T1'] ?? IMPORT_COLUMNS.T1!;
    const example = req.query.type === 'T2'
      ? 'Una solución al 2 %. ¿Cuántos mg/ml contiene?;Elige la concentración;20 mg/ml;2 mg/ml;E2;200 mg/ml;E2;0,2 mg/ml;E2;H2;comun;2;2 % = 2 g en 100 ml|2000 mg ÷ 100 ml = 20 mg/ml'
      : 'Necesitas 60 mg de lidocaína al 2 %.;¿Qué volumen cargas?;3;ml;1;H4;comun;2;2 % = 20 mg/ml|60 mg ÷ 20 mg/ml = 3 ml;30';
    reply.header('Content-Type', 'text/csv; charset=utf-8').header('Content-Disposition', `attachment; filename="modelo-${req.query.type ?? 'T1'}.csv"`);
    return `${cols.map((c) => c.key).join(';')}\n${example}\n`;
  });

  app.post<{ Body: { type: string; rows: Record<string, string>[]; mapping?: Record<string, string> } }>('/v1/admin/import/validate', async (req) => {
    requireBo(req, ['superadmin', 'content_admin', 'author']);
    const rows = (req.body.rows ?? []).slice(0, 2001);
    if (rows.length > 2000) throw bad('too_many_rows', 'Se admiten 2000 filas por archivo');
    const mapped = rows.map((r) => (req.body.mapping ? Object.fromEntries(Object.entries(req.body.mapping).map(([col, key]) => [key, r[col] ?? ''])) : r));
    const result = mapped.map((r, i) => {
      if (req.body.type === 'case_rows') {
        const errors = IMPORT_COLUMNS.case_rows!.filter((c) => c.required && !String(r[c.key] ?? '').trim()).map((c) => `Fila ${i + 1}: falta ${c.label.toLowerCase()}`);
        return { row: i + 1, ok: !errors.length, errors, data: r };
      }
      const { errors } = rowToQuestion(req.body.type, r, i);
      return { row: i + 1, ok: !errors.length, errors, data: r };
    });
    return { total: result.length, ok: result.filter((r) => r.ok).length, errors: result.filter((r) => !r.ok).length, rows: result, columns: IMPORT_COLUMNS[req.body.type] ?? [] };
  });

  app.post<{ Body: { type: string; rows: Record<string, string>[]; mapping?: Record<string, string>; targetTemplateId?: string } }>('/v1/admin/import/commit', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'author']);
    const rows = (req.body.rows ?? []).slice(0, 2000);
    const mapped = rows.map((r) => (req.body.mapping ? Object.fromEntries(Object.entries(req.body.mapping).map(([col, key]) => [key, r[col] ?? ''])) : r));
    return withTx(boActor(bo), async (tx) => {
      const created: string[] = [];
      const rejected: { row: number; errors: string[] }[] = [];
      if (req.body.type === 'case_rows') {
        if (!req.body.targetTemplateId) throw bad('template_required', 'Elige la plantilla cuya tabla de casos se completa');
        const cur = await latest(tx, req.body.targetTemplateId);
        const def = cur.data as unknown as TemplateDefinition;
        const table = def.variables.find((v) => v.kind === 'case_table');
        if (!table) throw bad('no_case_table', 'La plantilla no tiene tabla de casos');
        const ok = mapped.filter((r, i) => {
          const errs = IMPORT_COLUMNS.case_rows!.filter((c) => c.required && !String(r[c.key] ?? '').trim()).map((c) => `Fila ${i + 1}: falta ${c.label.toLowerCase()}`);
          if (errs.length) rejected.push({ row: i + 1, errors: errs });
          return !errs.length;
        });
        table.rows = [...(table.rows ?? []), ...ok.map((r) => ({ farmaco: r.farmaco!, dosis: String(r.dosis).replace(',', '.'), conc: String(r.conc).replace(',', '.') }))];
        await updateItem(tx, bo, cur.id, def as never);
        created.push(cur.id);
      } else {
        for (let i = 0; i < mapped.length; i++) {
          const { q, errors } = rowToQuestion(req.body.type, mapped[i]!, i);
          if (errors.length || !q) { rejected.push({ row: i + 1, errors }); continue; }
          const item = await createItem(tx, bo, 'question', q as never, { state: 'draft' });
          created.push(item.id);
        }
      }
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'import.commit', entity: 'import', after: { type: req.body.type, created: created.length, rejected: rejected.length } });
      return { created: created.length, ids: created, rejected, report: rejected.map((r) => r.errors.join('; ')).join('\n') };
    });
  });

  // ------------------------------------------------------------------ Revisión
  app.get<{ Querystring: { sector?: string; kind?: string } }>('/v1/admin/reviews/inbox', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'reviewer', 'author']);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query("SELECT DISTINCT ON (id) * FROM content_items ORDER BY id, version DESC")).rows as ItemRow[];
      const authors = new Map((await tx.query('SELECT id, name FROM bo_accounts')).rows.map((a) => [a.id, a.name]));
      const items = rows.filter((r) => r.state === 'in_review'
        && (!req.query.sector || r.sector_id === req.query.sector) && (!req.query.kind || r.kind === req.query.kind)
        && (bo.role !== 'author' || r.author_id === bo.accountId))
        .map((r) => ({
          ...itemView(r), authorName: authors.get(r.author_id) ?? null,
          mySector: bo.role === 'reviewer' && (!r.sector_id || r.sector_id === 'comun' || bo.sectors.includes(r.sector_id)),
          ownContent: r.author_id === bo.accountId, daysInReview: r.updated_at ? Math.floor((Date.now() - new Date((r as unknown as { submitted_at: string }).submitted_at ?? r.updated_at).getTime()) / 86400000) : 0,
          modifiedDuringReview: Boolean(r.submitted_data && JSON.stringify(r.submitted_data) !== JSON.stringify(r.data)),
        }))
        .sort((a, b) => Number(b.mySector) - Number(a.mySector) || b.daysInReview - a.daysInReview);
      return { items, checklist: CHECKLIST_KEYS.map((k) => ({ key: k, label: CHECKLIST_LABELS[k] })) };
    });
  });

  app.get<{ Params: { itemId: string } }>('/v1/admin/reviews/:itemId', async (req) => {
    const bo = requireBo(req, [...ALL_BO]);
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.itemId);
      let sample: unknown[] = []; let extremes: unknown[] = [];
      if (cur.kind === 'template') {
        const def = { ...(cur.data as unknown as TemplateDefinition), version: cur.version };
        const res = generateVariants(def, { perLevel: Math.max(8, Math.ceil(60 / def.levels.length)), seed: 99 });
        const all = res.variants.map((r) => ({ id: r.variant.id, level: r.variant.level, statement: segmentsToText(r.variant.statement), question: r.variant.question, tts: r.variant.tts, answer: r.variant.answer, recalculated: r.doubleCheck.b, matches: r.doubleCheck.ok, assignment: r.assignment, predictedErrors: r.variant.predictedErrors, steps: r.variant.steps }));
        const shuffled = [...all].sort(() => Math.random() - 0.5);
        sample = shuffled.slice(0, 20);
        const sorted = [...all].sort((a, b) => Number(a.answer!.value) - Number(b.answer!.value));
        extremes = [sorted[0], sorted[sorted.length - 1]].filter(Boolean);
      } else if (cur.kind === 'question') {
        const v = resolveQuestion(cur.data as unknown as QuestionDefinition);
        sample = [{ id: v.id, level: v.level, statement: segmentsToText(v.statement), question: v.question, tts: v.tts, answer: v.answer, options: v.options, orderItems: v.orderItems, series: v.series, matches: true }];
      }
      const author = (await tx.query('SELECT name FROM bo_accounts WHERE id = $1', [cur.author_id])).rows[0]?.name ?? null;
      const comments = (await tx.query('SELECT c.*, a.name AS author_name FROM review_comments c JOIN bo_accounts a ON a.id = c.author_id WHERE item_id = $1 ORDER BY created_at', [cur.id])).rows;
      const reviews = (await tx.query('SELECT r.*, a.name AS reviewer_name FROM reviews r JOIN bo_accounts a ON a.id = r.reviewer_id WHERE item_id = $1 ORDER BY created_at DESC', [cur.id])).rows;
      const changes = cur.submitted_data ? diffData(cur.submitted_data, cur.data) : [];
      const sector = cur.sector_id ? (await tx.query("SELECT data FROM content_items WHERE kind = 'sector' AND id = $1 ORDER BY version DESC LIMIT 1", [cur.sector_id])).rows[0]?.data : null;
      return {
        item: itemView(cur), authorName: author, sample, extremes, comments, reviews, changesDuringReview: changes,
        checklist: CHECKLIST_KEYS.map((k) => ({ key: k, label: CHECKLIST_LABELS[k] })),
        requiredValidations: sector?.doubleReview ? 2 : 1,
        canValidate: bo.role === 'reviewer' && cur.author_id !== bo.accountId && (!cur.sector_id || cur.sector_id === 'comun' || bo.sectors.includes(cur.sector_id)),
        canComment: ['reviewer', 'superadmin', 'content_admin', 'author'].includes(bo.role),
        reasonCannotValidate: bo.role !== 'reviewer' ? 'Validar es exclusivo del revisor experto' : cur.author_id === bo.accountId ? 'Nadie valida contenido propio' : (cur.sector_id && cur.sector_id !== 'comun' && !bo.sectors.includes(cur.sector_id)) ? 'No estás acreditado en este sector: puedes comentar, no validar' : null,
      };
    });
  });

  app.post<{ Params: { itemId: string }; Body: { decision: 'validate' | 'request_changes' | 'reject'; checklist?: Record<string, boolean>; comment?: string; fingerprint?: string } }>('/v1/admin/reviews/:itemId/decision', async (req) => {
    const bo = requireBo(req, ['reviewer', 'superadmin', 'content_admin']);
    if (bo.role !== 'reviewer') throw forbidden('Solo un revisor experto decide sobre una revisión');
    return withTx(boActor(bo), (tx) => decide(tx, bo, req.params.itemId, req.body));
  });

  app.post<{ Params: { itemId: string }; Body: { body: string; anchor?: string } }>('/v1/admin/reviews/:itemId/comments', async (req) => {
    const bo = requireBo(req, ['reviewer', 'superadmin', 'content_admin', 'author']);
    if (!req.body?.body?.trim()) throw bad('empty', 'Escribe el comentario');
    return withTx(boActor(bo), async (tx) => {
      const cur = await latest(tx, req.params.itemId);
      const r = (await tx.query('INSERT INTO review_comments(item_id, item_version, author_id, anchor, body) VALUES ($1,$2,$3,$4,$5) RETURNING *', [cur.id, cur.version, bo.accountId, req.body.anchor ?? null, req.body.body])).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'review.comment', entity: cur.kind, entityId: cur.id, after: { anchor: req.body.anchor ?? null } });
      return { comment: r };
    });
  });
}
