/**
 * Pruebas de integración de la API contra Postgres (base volutrainmed_test).
 * Cada «it» nombra el requisito o escenario del OpenSpec que comprueba.
 */
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createHash, createPublicKey, verify as edVerify } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import pg from 'pg';
import { randomUUID } from 'node:crypto';
import { buildApp } from '../src/server.js';
import { closePool } from '../src/db/pool.js';
import { totp } from '../src/lib/crypto.js';
import { DEV_PASSWORD } from '../src/seed/run.js';
import { signaturePayload, type Attempt, type ItineraryPackage, type ContentManifest } from '@vtm/contracts';

let app: FastifyInstance;
const secrets = new Map<string, string>();
const tokens = new Map<string, string>();

async function call(method: string, url: string, body?: unknown, token?: string, headers: Record<string, string> = {}) {
  const res = await app.inject({ method: method as never, url, payload: body as never, headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), ...headers } });
  let json: any = null;
  try { json = res.json(); } catch { json = null; }
  return { status: res.statusCode, json, raw: res.rawPayload, headers: res.headers };
}

async function bo(email: string): Promise<string> {
  if (tokens.has(email)) return tokens.get(email)!;
  const login = await call('POST', '/v1/admin/auth/login', { email, password: DEV_PASSWORD });
  expect(login.status).toBe(200);
  if (login.json.secret) secrets.set(email, login.json.secret);
  const code = totp(secrets.get(email)!);
  const mfa = await call('POST', '/v1/admin/auth/mfa', { challenge: login.json.challenge, code });
  expect(mfa.status).toBe(200);
  tokens.set(email, mfa.json.token);
  return mfa.json.token;
}

async function appUser(email: string, deviceId = `dev-${randomUUID()}`, localProfile?: Record<string, unknown>) {
  await call('POST', '/v1/auth/otp/request', { email });
  const mail = await call('GET', `/v1/dev/mailbox?email=${encodeURIComponent(email)}`);
  const code = mail.json.items[0].body;
  const r = await call('POST', '/v1/auth/otp/verify', { email, code, deviceId, localProfile });
  expect(r.status).toBe(200);
  return { token: r.json.token as string, user: r.json.user, deviceId, isNew: r.json.isNew, merged: r.json.merged };
}

function attempt(over: Partial<Attempt> = {}): Attempt {
  return {
    id: randomUUID(), sessionId: randomUUID(), deviceId: 'd', mode: 'lesson', lessonId: 'u-f-1-l1', templateId: 'tpl-f-mg-ug', questionId: null,
    variantId: 'tpl-f-mg-ug.v1.L1.x', skillId: 'H1', exerciseTypeId: 'T1', level: 1, attemptNumber: 1, answerValue: '250', answerUnit: 'µg',
    verdict: 'correct', errorCode: null, critical: false, hintsUsed: 0, responseMs: 8000, targetMs: 15000, inputMode: 'touch', points: 10,
    contentVersion: '2026.11.1', deviceTime: new Date().toISOString(), ...over,
  };
}

const adminDb = () => new pg.Client({ connectionString: process.env.DATABASE_ADMIN_URL });
const appDb = () => new pg.Client({ connectionString: process.env.DATABASE_URL });

beforeAll(async () => { app = await buildApp(); });
afterAll(async () => { await app.close(); await closePool(); });

describe('onboarding-account', () => {
  it('CORS: el navegador puede usar PATCH y DELETE (edición del perfil y eliminación de la cuenta desde la app web)', async () => {
    const res = await app.inject({ method: 'OPTIONS', url: '/v1/me', headers: { origin: 'http://localhost:8090', 'access-control-request-method': 'PATCH' } });
    expect(res.statusCode).toBe(204);
    const allowed = String(res.headers['access-control-allow-methods']);
    for (const m of ['PATCH', 'DELETE', 'PUT']) expect(allowed).toContain(m);
  });
  it('Código correcto: la sesión se inicia con el código de seis cifras', async () => {
    const u = await appUser('lucia@correo.test');
    expect(u.token).toBeTruthy();
    expect(u.isNew).toBe(true);
  });
  it('Código incorrecto: lo indica y permite pedir otro', async () => {
    await call('POST', '/v1/auth/otp/request', { email: 'mal@correo.test' });
    const r = await call('POST', '/v1/auth/otp/verify', { email: 'mal@correo.test', code: '000000' });
    expect(r.status).toBe(400);
    expect(r.json.error.message).toBe('El código no es correcto');
    const again = await call('POST', '/v1/auth/otp/request', { email: 'mal@correo.test' });
    expect(again.status).toBe(204);
  });
  it('Fusión al registrarse: el perfil local se conserva en la cuenta y en otro dispositivo', async () => {
    const local = { alias: 'MeniscoLocal', sectorId: 'veterinaria', itineraryId: 'it-vet-pequenos', declaredLevel: 'afianzar', goal: { kind: 'daily', minutes: 10 }, disclaimerAcceptedAt: new Date().toISOString() };
    const a = await appUser('fusion@correo.test', 'movil-1', local);
    expect(a.merged).toBe(true);
    expect(a.user.sectorId).toBe('veterinaria');
    const atts = [1, 2, 3].map((i) => attempt({ lessonId: `u-v-1-l${i}`, deviceId: 'movil-1' }));
    const push = await call('POST', '/v1/sync/push', { deviceId: 'movil-1', appVersion: '1.0.0', attempts: atts, sessions: [], events: [] }, a.token);
    expect(push.json.accepted.attempts).toBe(3);
    const b = await appUser('fusion@correo.test', 'tablet-1');
    const pull = await call('GET', '/v1/sync/pull', undefined, b.token);
    expect(pull.json.attempts.map((x: Attempt) => x.lessonId).sort()).toEqual(['u-v-1-l1', 'u-v-1-l2', 'u-v-1-l3']);
  });
  it('Apple y Google (desarrollo): acceso con token de prueba', async () => {
    const r = await call('POST', '/v1/auth/apple', { idToken: 'dev:apple@correo.test', deviceId: 'x' });
    expect(r.status).toBe(200);
    const g = await call('POST', '/v1/auth/google', { idToken: 'dev:google@correo.test', deviceId: 'y' });
    expect(g.status).toBe(200);
  });
  it('Exportación de datos: confirmación y archivo con perfil e historial', async () => {
    const u = await appUser('exporta@correo.test');
    await call('POST', '/v1/sync/push', { deviceId: u.deviceId, appVersion: '1.0.0', attempts: [attempt()], sessions: [], events: [] }, u.token);
    const req = await call('POST', '/v1/me/export', undefined, u.token);
    expect(req.status).toBe(202);
    await new Promise((r) => setTimeout(r, 400));
    const file = await call('GET', `/v1/me/export/${req.json.requestId}`, undefined, u.token);
    expect(file.json.status).toBe('ready');
    expect(file.json.file.attempts).toHaveLength(1);
    expect(file.json.file.profile.email).toBe('exporta@correo.test');
  });
  it('Eliminación de la cuenta: con confirmación escrita se suprimen o anonimizan los datos', async () => {
    const u = await appUser('borra@correo.test');
    const no = await call('DELETE', '/v1/me', { confirmation: 'si' }, u.token);
    expect(no.status).toBe(400);
    const ok = await call('DELETE', '/v1/me', { confirmation: 'ELIMINAR' }, u.token);
    expect(ok.status).toBe(204);
    const db = adminDb(); await db.connect();
    const r = (await db.query('SELECT email, alias, status FROM users WHERE id = $1', [u.user.id])).rows[0];
    await db.end();
    expect(r).toEqual({ email: null, alias: 'Usuario eliminado', status: 'deleted' });
  });
  it('Formulario de consulta: aviso de error con variante y respuesta adjuntas, idempotente (envío diferido)', async () => {
    const u = await appUser('consulta@correo.test');
    const inq = { id: randomUUID(), type: 'exercise_error', message: 'Creo que el redondeo está mal', replyEmail: 'consulta@correo.test', exercise: { variantId: 'tpl-v-meloxicam.v1.L3.abc', templateId: 'tpl-v-meloxicam', questionId: null, answerValue: '0.96', answerUnit: 'ml' }, createdAt: new Date().toISOString() };
    const r1 = await call('POST', '/v1/inquiries', inq, u.token);
    const r2 = await call('POST', '/v1/inquiries', inq, u.token);
    expect(r1.json.reference).toBe(r2.json.reference);
    expect(r1.json.notice).toBe('No respondemos consultas sobre pacientes ni tratamientos');
    const mine = await call('GET', '/v1/inquiries', undefined, u.token);
    expect(mine.json.items).toHaveLength(1);
  });
});

describe('offline-sync', () => {
  it('Envío repetido: el servidor conserva cada intento una sola vez', async () => {
    const u = await appUser('sync@correo.test');
    const batch = Array.from({ length: 120 }, () => attempt());
    const a = await call('POST', '/v1/sync/push', { deviceId: u.deviceId, appVersion: '1.0.0', attempts: batch, sessions: [], events: [] }, u.token);
    const b = await call('POST', '/v1/sync/push', { deviceId: u.deviceId, appVersion: '1.0.0', attempts: batch, sessions: [], events: [] }, u.token);
    expect(a.json.accepted.attempts).toBe(120);
    expect(b.json.accepted.attempts).toBe(0);
    expect(b.json.duplicates.attempts).toBe(120);
  });
  it('Dos dispositivos sin conexión: ambos ven la unión de intentos', async () => {
    const m = await appUser('dos@correo.test', 'movil-2');
    const t = await appUser('dos@correo.test', 'tablet-2');
    await call('POST', '/v1/sync/push', { deviceId: 'movil-2', appVersion: '1.0.0', attempts: [attempt({ lessonId: 'L-movil' })], sessions: [], events: [] }, m.token);
    await call('POST', '/v1/sync/push', { deviceId: 'tablet-2', appVersion: '1.0.0', attempts: [attempt({ lessonId: 'L-tablet' })], sessions: [], events: [] }, t.token);
    const pm = await call('GET', '/v1/sync/pull', undefined, m.token);
    const pt = await call('GET', '/v1/sync/pull', undefined, t.token);
    expect(pm.json.attempts.map((x: Attempt) => x.lessonId).sort()).toEqual(['L-movil', 'L-tablet']);
    expect(pt.json.attempts.map((x: Attempt) => x.id).sort()).toEqual(pm.json.attempts.map((x: Attempt) => x.id).sort());
  });
  it('Paquete válido: firma Ed25519 y SHA-256 verificables con la clave pública', async () => {
    const m = await call('GET', '/v1/content/manifest?deviceId=verifica&appVersion=1.0.0');
    const manifest = m.json as ContentManifest;
    const key = await call('GET', '/v1/content/public-key');
    const spki = Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), Buffer.from(key.json.publicKey, 'base64')]);
    const pub = createPublicKey({ key: spki, format: 'der', type: 'spki' });
    for (const f of [manifest.global, ...manifest.packages]) {
      const bytes = (await call('GET', f.url)).raw;
      expect(createHash('sha256').update(bytes).digest('hex')).toBe(f.sha256);
      expect(edVerify(null, Buffer.from(signaturePayload(f)), pub, Buffer.from(f.signature, 'base64'))).toBe(true);
    }
    const fund = (await call('GET', manifest.packages.find((p) => p.itineraryId === 'it-fundamentos')!.url)).raw;
    const pkg = JSON.parse(gunzipSync(fund).toString('utf8')) as ItineraryPackage;
    expect(pkg.units).toHaveLength(5);
    expect(pkg.lessons.filter((l) => l.kind === 'challenge').every((l) => l.slots.length === 10)).toBe(true);
  });
  it('Paquete no válido: una firma alterada no verifica', async () => {
    const m = (await call('GET', '/v1/content/manifest?deviceId=altera&appVersion=1.0.0')).json as ContentManifest;
    const key = await call('GET', '/v1/content/public-key');
    const pub = createPublicKey({ key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), Buffer.from(key.json.publicKey, 'base64')]), format: 'der', type: 'spki' });
    const tampered = { ...m.global, sha256: m.global.sha256.replace(/^./, (c) => (c === 'a' ? 'b' : 'a')) };
    expect(edVerify(null, Buffer.from(signaturePayload(tampered)), pub, Buffer.from(m.global.signature, 'base64'))).toBe(false);
  });
  it('Descarga interrumpida: se reanuda desde el punto alcanzado (Range)', async () => {
    const m = (await call('GET', '/v1/content/manifest?deviceId=rango&appVersion=1.0.0')).json as ContentManifest;
    const url = m.packages[0]!.url;
    const full = (await call('GET', url)).raw;
    const part1 = await call('GET', url, undefined, undefined, { range: 'bytes=0-999' });
    const part2 = await call('GET', url, undefined, undefined, { range: 'bytes=1000-' });
    expect(part1.status).toBe(206);
    expect(Buffer.concat([part1.raw, part2.raw]).equals(full)).toBe(true);
  });
});

describe('backoffice-administration', () => {
  it('Doble factor obligatorio: el primer acceso exige configurar el segundo factor', async () => {
    const login = await call('POST', '/v1/admin/auth/login', { email: 'soporte@volutrainmed.test', password: DEV_PASSWORD });
    expect(login.json.mfaSetupRequired).toBe(true);
    expect(login.json.otpauthUrl).toContain('otpauth://totp/');
    const noMfa = await call('GET', '/v1/admin/dashboard');
    expect(noMfa.status).toBe(401);
    secrets.set('soporte@volutrainmed.test', login.json.secret);
    const wrong = await call('POST', '/v1/admin/auth/mfa', { challenge: login.json.challenge, code: '000000' });
    expect(wrong.status).toBe(400);
  });
  it('Soporte: no tiene acceso a la publicación (ni en la API ni en la base de datos)', async () => {
    const t = await bo('soporte@volutrainmed.test');
    expect((await call('GET', '/v1/admin/releases', undefined, t)).status).toBe(403);
    const db = appDb(); await db.connect();
    await db.query('BEGIN'); await db.query("SELECT set_config('app.actor_role', 'support', true)");
    const rows = (await db.query('SELECT count(*)::int AS n FROM releases')).rows[0].n;
    await db.query('ROLLBACK'); await db.end();
    expect(rows).toBe(0);
  });
  it('Analista: consulta la analítica de una plantilla y no puede editarla', async () => {
    const t = await bo('analista@volutrainmed.test');
    expect((await call('GET', '/v1/admin/analytics/items', undefined, t)).status).toBe(200);
    const edit = await call('PUT', '/v1/admin/items/tpl-f-mg-ug', { data: { name: 'x' } }, t);
    expect(edit.status).toBe(403);
  });
  it('Autor: ve una plantilla de otro autor y no puede modificarla', async () => {
    const t = await bo('autor2@volutrainmed.test');
    expect((await call('GET', '/v1/admin/items/tpl-f-mg-ug', undefined, t)).json.canEdit).toBe(false);
    expect((await call('PUT', '/v1/admin/items/tpl-f-mg-ug', { data: { name: 'x' } }, t)).status).toBe(403);
  });
  it('Registro de auditoría: inalterable incluso para el superadministrador y para el propietario de la base', async () => {
    const db = appDb(); await db.connect();
    await expect(db.query("UPDATE audit_log SET action = 'x' WHERE id = 1")).rejects.toThrow();
    await db.end();
    const owner = adminDb(); await owner.connect();
    await expect(owner.query('DELETE FROM audit_log WHERE id = 1')).rejects.toThrow(/inalterable/);
    await owner.end();
  });
  it('Cambio de una fórmula: la auditoría guarda autor, fecha, fórmula anterior y nueva', async () => {
    const t = await bo('autora@volutrainmed.test');
    const cur = (await call('GET', '/v1/admin/items/tpl-f-pct-vol', undefined, t)).json.item;
    const data = { ...cur.data, formula: 'mg ÷ p × 1' };
    const r = await call('PUT', '/v1/admin/items/tpl-f-pct-vol', { data }, t);
    expect(r.status).toBe(200);
    expect(r.json.item.version).toBe(cur.version + 1);
    const admin = await bo('superadmin@volutrainmed.test');
    const log = await call('GET', '/v1/admin/audit?action=item.update', undefined, admin);
    const entry = log.json.items.find((e: any) => e.entity_id === 'tpl-f-pct-vol');
    expect(entry.before.formula).toBe('mg ÷ p');
    expect(entry.after.formula).toBe('mg ÷ p × 1');
  });
  it('Nada se borra: un DELETE sobre contenido falla', async () => {
    const owner = adminDb(); await owner.connect();
    await expect(owner.query("DELETE FROM content_items WHERE id = 'tpl-f-mg-ug'")).rejects.toThrow(/Nada se borra/);
    await owner.end();
  });
  it('Conceder días de Premium con motivo queda en auditoría', async () => {
    const u = await appUser('regalo@correo.test');
    const t = await bo('soporte@volutrainmed.test');
    const noReason = await call('POST', `/v1/admin/users/${u.user.id}/actions`, { action: 'grant_premium', days: 7 }, t);
    expect(noReason.status).toBe(400);
    const r = await call('POST', `/v1/admin/users/${u.user.id}/actions`, { action: 'grant_premium', days: 7, reason: 'Incidencia con la descarga' }, t);
    expect(r.json.entitlements.premium).toBe(true);
    expect(r.json.entitlements.source).toBe('support_grant');
  });
  it('Panel de control: el revisor ve primero las revisiones pendientes de sus sectores', async () => {
    const author = await bo('autora@volutrainmed.test');
    const created = await call('POST', '/v1/admin/items', { kind: 'question', data: { name: 'Prueba panel', exerciseTypeId: 'T2', sectorId: 'veterinaria', skillId: 'H2', level: 2, targetTimeS: 20, statement: 'Una solución al 1 %.', question: '¿Concentración?', options: [{ label: '10 mg/ml', correct: true }, { label: '1 mg/ml', correct: false, errorCode: 'E2' }, { label: '100 mg/ml', correct: false, errorCode: 'E2' }], steps: [{ n: 1, text: '1 % = 10 mg/ml', operation: '1 g en 100 ml', result: { value: '10', unit: 'mg/ml' }, cancelled: [] }], plausibility: 'Tiene sentido.' } }, author);
    expect(created.status).toBe(200);
    expect((await call('POST', `/v1/admin/items/${created.json.item.id}/submit`, undefined, author)).status).toBe(200);
    const vet = await bo('revisor.vet@volutrainmed.test');
    const dash = await call('GET', '/v1/admin/dashboard', undefined, vet);
    expect(dash.json.myWork.pendingReviews.some((p: any) => p.id === created.json.item.id)).toBe(true);
    const clin = await bo('revisor.clinico@volutrainmed.test');
    const dash2 = await call('GET', '/v1/admin/dashboard', undefined, clin);
    expect(dash2.json.myWork.pendingReviews.some((p: any) => p.id === created.json.item.id)).toBe(false);
  });
});

describe('content-authoring', () => {
  it('Unidades incoherentes: «El resultado sale en mg, no en ml» y no se puede guardar', async () => {
    const t = await bo('autora@volutrainmed.test');
    const r = await call('POST', '/v1/admin/engine/check-dimensions', { formula: 'dosis × peso', units: { dosis: 'mg/kg', peso: 'kg' }, answerUnit: 'ml' }, t);
    expect(r.json.message).toBe('El resultado sale en mg, no en ml');
    const cur = (await call('GET', '/v1/admin/items/tpl-v-meloxicam', undefined, t)).json.item;
    const save = await call('PUT', '/v1/admin/items/tpl-v-meloxicam', { data: { ...cur.data, formula: 'caso.dosis × peso' } }, t);
    expect(save.status).toBe(422);
    expect(save.json.error.message).toBe('El resultado sale en mg, no en ml');
  });
  it('Nueva unidad: aparece en el árbol en estado borrador; reordenar sin arrastrar', async () => {
    const t = await bo('contenido@volutrainmed.test');
    const u = await call('POST', '/v1/admin/structure/unit', { name: 'Unidad nueva', itineraryId: 'it-fundamentos', skills: ['H1', 'H12'], description: 'Prueba', templateIds: [], questionIds: [] }, t);
    expect(u.json.item.state).toBe('draft');
    const tree = await call('GET', '/v1/admin/structure', undefined, t);
    const fund = tree.json.tree.find((s: any) => s.id === 'comun').children.find((i: any) => i.id === 'it-fundamentos');
    const ids = fund.children.map((c: any) => c.id);
    expect(ids[ids.length - 1]).toBe(u.json.item.id);
    await call('POST', `/v1/admin/structure/unit/${u.json.item.id}/move`, { direction: 'up' }, t);
    const tree2 = await call('GET', '/v1/admin/structure', undefined, t);
    const ids2 = tree2.json.tree.find((s: any) => s.id === 'comun').children.find((i: any) => i.id === 'it-fundamentos').children.map((c: any) => c.id);
    expect(ids2.indexOf(u.json.item.id)).toBe(ids.length - 2);
  });
  it('Lección sin ejercicios: el back office impide enviarla a revisión e indica qué falta', async () => {
    const t = await bo('contenido@volutrainmed.test');
    const l = await call('POST', '/v1/admin/structure/lesson', { unitId: 'u-f-1', kind: 'free', title: 'Sin huecos', rule: 'slots', slots: [] }, t);
    const s = await call('POST', `/v1/admin/items/${l.json.item.id}/submit`, undefined, t);
    expect(s.status).toBe(422);
    expect(s.json.error.message).toContain('no tiene ejercicios asignados');
  });
  it('Plantilla de dosis por peso: 20 variantes de muestra con enunciado, respuesta en ml y pasos', async () => {
    const t = await bo('autora@volutrainmed.test');
    const cur = (await call('GET', '/v1/admin/items/tpl-v-meloxicam', undefined, t)).json.item;
    const r = await call('POST', '/v1/admin/engine/sample', { definition: cur.data, n: 20, level: 3 }, t);
    expect(r.json.variants).toHaveLength(20);
    expect(r.json.variants.every((v: any) => v.answer.unit === 'ml' && v.steps.length === 2 && v.doubleCheck.ok)).toBe(true);
  });
  it('Importación parcial: 180 válidas y 20 con error → 180 borradores e informe de 20', async () => {
    const t = await bo('autora@volutrainmed.test');
    const rows = Array.from({ length: 200 }, (_, i) => ({ enunciado: `Necesitas ${i + 10} mg de un fármaco con presentación de 10 mg/ml.`, pregunta: '¿Qué volumen cargas?', respuesta: String((i + 10) / 10).replace('.', ','), unidad: i < 20 ? '' : 'ml', decimales: '1', habilidad: 'H4', sector: 'comun', nivel: '2', explicacion: 'Volumen = dosis ÷ concentración' }));
    const v = await call('POST', '/v1/admin/import/validate', { type: 'T1', rows }, t);
    expect(v.json.ok).toBe(180);
    expect(v.json.rows[13].errors).toContain('Fila 14: falta la unidad de la respuesta');
    const c = await call('POST', '/v1/admin/import/commit', { type: 'T1', rows }, t);
    expect(c.json.created).toBe(180);
    expect(c.json.rejected).toHaveLength(20);
  });
  it('Escuchar y simular una respuesta: «cero coma noventa y seis» se interpreta como 0,96', async () => {
    const t = await bo('autora@volutrainmed.test');
    const s = await call('POST', '/v1/admin/engine/parse-spoken', { text: 'cero coma noventa y seis' }, t);
    expect(s.json).toMatchObject({ kind: 'number', value: '0.96' });
    const g = await call('POST', '/v1/admin/engine/grade', { answer: { value: '0.96', unit: 'ml', unitFixed: true, unitChoices: ['ml'], equivalents: [], rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' } }, input: { raw: '0.96' } }, t);
    expect(g.json.verdict).toBe('correct');
    const gammas = await call('POST', '/v1/admin/engine/parse-spoken', { text: 'doscientas gammas', options: { synonyms: { gammas: 'µg' } } }, t);
    expect(gammas.json).toMatchObject({ value: '200', unit: 'µg' });
  });
});

describe('content-review-publishing', () => {
  let qid = '';
  it('Autor que intenta validar lo suyo: la acción no está disponible', async () => {
    const t = await bo('autora@volutrainmed.test');
    const created = await call('POST', '/v1/admin/items', { kind: 'question', data: { name: 'Cuatro ojos', exerciseTypeId: 'T2', sectorId: 'anestesia', skillId: 'H2', level: 2, targetTimeS: 20, statement: 'Lidocaína al 2 %.', question: '¿Cuántos mg/ml?', options: [{ label: '20 mg/ml', correct: true }, { label: '2 mg/ml', correct: false, errorCode: 'E2' }, { label: '200 mg/ml', correct: false, errorCode: 'E2' }], steps: [{ n: 1, text: '2 % = 20 mg/ml', operation: '2 g en 100 ml', result: { value: '20', unit: 'mg/ml' }, cancelled: [] }], plausibility: 'Tiene sentido.' } }, t);
    qid = created.json.item.id;
    await call('POST', `/v1/admin/items/${qid}/submit`, undefined, t);
    const view = await call('GET', `/v1/admin/reviews/${qid}`, undefined, t);
    expect(view.json.canValidate).toBe(false);
    const db = appDb(); await db.connect();
    const author = (await db.query("SELECT id FROM bo_accounts WHERE email = 'autora@volutrainmed.test'")).rows[0].id;
    await db.query('BEGIN'); await db.query("SELECT set_config('app.actor_role', 'system', true)");
    await expect(db.query("INSERT INTO reviews(item_id, item_version, reviewer_id, decision, fingerprint) VALUES ($1, 1, $2, 'validate', 'x')", [qid, author])).rejects.toThrow(/contenido propio|revisor experto/);
    await db.query('ROLLBACK'); await db.end();
  });
  it('Revisor sin acreditación en el sector: puede comentar y no validar', async () => {
    const t = await bo('revisor.enfermeria@volutrainmed.test');
    const view = await call('GET', `/v1/admin/reviews/${qid}`, undefined, t);
    expect(view.json.canValidate).toBe(false);
    expect(view.json.canComment).toBe(true);
    expect((await call('POST', `/v1/admin/reviews/${qid}/comments`, { body: 'Revisa la explicación' }, t)).status).toBe(200);
    const fullChecklist = Object.fromEntries(view.json.checklist.map((c: any) => [c.key, true]));
    expect((await call('POST', `/v1/admin/reviews/${qid}/decision`, { decision: 'validate', checklist: fullChecklist }, t)).status).toBe(403);
  });
  it('Lista incompleta: la validación no se registra', async () => {
    const t = await bo('revisor.clinico@volutrainmed.test');
    const r = await call('POST', `/v1/admin/reviews/${qid}/decision`, { decision: 'validate', checklist: { pauta_plausible: true } }, t);
    expect(r.status).toBe(422);
    expect(r.json.error.message).toContain('Falta marcar');
  });
  it('Muestra de variantes: 20 al azar, extremos y recálculo independiente', async () => {
    const t = await bo('revisor.clinico@volutrainmed.test');
    // Una plantilla validada vuelve a revisión al marcar un cambio en la información del fármaco.
    const admin = await bo('contenido@volutrainmed.test');
    await call('POST', '/v1/admin/items/tpl-a-fentanilo/drug-info-changed', undefined, admin);
    const v = await call('GET', '/v1/admin/reviews/tpl-a-fentanilo', undefined, t);
    expect(v.json.sample).toHaveLength(20);
    expect(v.json.extremes).toHaveLength(2);
    expect(v.json.sample.every((s: any) => s.matches && s.recalculated === s.answer.value)).toBe(true);
  });
  it('Contenido modificado durante la revisión: el revisor ve las diferencias y la lista se reinicia', async () => {
    const author = await bo('autora@volutrainmed.test');
    const cur = (await call('GET', `/v1/admin/items/${qid}`, undefined, author)).json.item;
    await call('PUT', `/v1/admin/items/${qid}`, { data: { ...cur.data, question: '¿Cuántos mg por ml?' } }, author);
    const rev = await bo('revisor.clinico@volutrainmed.test');
    const v = await call('GET', `/v1/admin/reviews/${qid}`, undefined, rev);
    expect(v.json.changesDuringReview.some((c: any) => c.path === 'question')).toBe(true);
    const full = Object.fromEntries(v.json.checklist.map((c: any) => [c.key, true]));
    const stale = await call('POST', `/v1/admin/reviews/${qid}/decision`, { decision: 'validate', checklist: full, fingerprint: cur.fingerprint }, rev);
    expect(stale.status).toBe(409);
    const ok = await call('POST', `/v1/admin/reviews/${qid}/decision`, { decision: 'validate', checklist: full, fingerprint: v.json.item.fingerprint }, rev);
    expect(ok.json.state).toBe('validated');
  });
  it('Cambios solicitados: vuelve al autor con el comentario visible', async () => {
    const author = await bo('autora@volutrainmed.test');
    const c = await call('POST', '/v1/admin/items', { kind: 'question', data: { name: 'Cambios', exerciseTypeId: 'T2', sectorId: 'comun', skillId: 'H2', level: 2, targetTimeS: 20, statement: 'Solución al 5 %.', question: '¿mg/ml?', options: [{ label: '50 mg/ml', correct: true }, { label: '5 mg/ml', correct: false, errorCode: 'E2' }, { label: '500 mg/ml', correct: false, errorCode: 'E2' }], steps: [{ n: 1, text: '5 % = 50 mg/ml', operation: '5 g en 100 ml', result: { value: '50', unit: 'mg/ml' }, cancelled: [] }], plausibility: 'Bien.' } }, author);
    await call('POST', `/v1/admin/items/${c.json.item.id}/submit`, undefined, author);
    const rev = await bo('revisor.clinico@volutrainmed.test');
    const noComment = await call('POST', `/v1/admin/reviews/${c.json.item.id}/decision`, { decision: 'request_changes' }, rev);
    expect(noComment.status).toBe(400);
    const r = await call('POST', `/v1/admin/reviews/${c.json.item.id}/decision`, { decision: 'request_changes', comment: 'Añade la explicación del redondeo' }, rev);
    expect(r.json.state).toBe('changes_requested');
    const item = await call('GET', `/v1/admin/items/${c.json.item.id}`, undefined, author);
    expect(item.json.reviews[0].comment).toBe('Añade la explicación del redondeo');
  });
  it('Sector con doble revisión: con una sola validación sigue en revisión', async () => {
    const author = await bo('autora@volutrainmed.test');
    const c = await call('POST', '/v1/admin/items', { kind: 'question', data: { name: 'Pediatría', exerciseTypeId: 'T2', sectorId: 'pediatria', skillId: 'H3', level: 2, targetTimeS: 20, statement: 'Niño simulado de 12 kg. Pauta: 0,01 mg/kg.', question: '¿Dosis?', options: [{ label: '0,12 mg', correct: true }, { label: '1,2 mg', correct: false, errorCode: 'E2' }, { label: '0,012 mg', correct: false, errorCode: 'E2' }], steps: [{ n: 1, text: 'Dosis', operation: '0,01 mg/kg × 12 kg', result: { value: '0.12', unit: 'mg' }, cancelled: ['kg'] }], plausibility: 'Bien.' } }, author);
    await call('POST', `/v1/admin/items/${c.json.item.id}/submit`, undefined, author);
    const p1 = await bo('revisor.ped1@volutrainmed.test');
    const view = await call('GET', `/v1/admin/reviews/${c.json.item.id}`, undefined, p1);
    const full = Object.fromEntries(view.json.checklist.map((x: any) => [x.key, true]));
    const r1 = await call('POST', `/v1/admin/reviews/${c.json.item.id}/decision`, { decision: 'validate', checklist: full }, p1);
    expect(r1.json.state).toBe('in_review');
    const p2 = await bo('revisor.ped2@volutrainmed.test');
    const r2 = await call('POST', `/v1/admin/reviews/${c.json.item.id}/decision`, { decision: 'validate', checklist: full }, p2);
    expect(r2.json.state).toBe('validated');
  });
  it('Publicación: elementos no validados atenuados, comprobaciones, despliegue al 5 % y reversión', async () => {
    const t = await bo('contenido@volutrainmed.test');
    // La plantilla que volvió a revisión por un cambio en la información del fármaco se revalida antes de publicar.
    const rev = await bo('revisor.clinico@volutrainmed.test');
    const view = await call('GET', '/v1/admin/reviews/tpl-a-fentanilo', undefined, rev);
    const full = Object.fromEntries(view.json.checklist.map((c: any) => [c.key, true]));
    expect((await call('POST', '/v1/admin/reviews/tpl-a-fentanilo/decision', { decision: 'validate', checklist: full }, rev)).json.state).toBe('validated');
    const rel = await call('POST', '/v1/admin/releases', { notes: 'Prueba' }, t);
    expect(rel.status).toBe(200);
    expect(rel.json.release.diff.excluded.some((e: any) => e.reason.includes('Pendiente') || e.reason.includes('borrador'))).toBe(true);
    const checks = await call('POST', `/v1/admin/releases/${rel.json.release.id}/checks`, undefined, t);
    expect(checks.json.summary.passed).toBe(true);
    expect(checks.json.checks.find((c: any) => c.id === 'compat').detail).toContain('%');
    const test = await call('POST', `/v1/admin/releases/${rel.json.release.id}/test-package`, undefined, t);
    expect(test.json.qrPayload).toContain(test.json.testCode);
    const viaQr = await call('GET', `/v1/content/manifest?deviceId=qa&appVersion=1.0.0&testCode=${test.json.testCode}`);
    expect(viaQr.json.testPackage).toBe(true);
    const normal = await call('GET', '/v1/content/manifest?deviceId=usuario&appVersion=1.0.0');
    expect(normal.json.contentVersion).toBe('2026.11.1');
    const badName = await call('POST', `/v1/admin/releases/${rel.json.release.id}/publish`, { confirmName: 'otra', rolloutPct: 5 }, t);
    expect(badName.status).toBe(400);
    const pub = await call('POST', `/v1/admin/releases/${rel.json.release.id}/publish`, { confirmName: rel.json.release.number, rolloutPct: 5 }, t);
    expect(pub.status).toBe(200);
    let gotNew = 0;
    for (let i = 0; i < 400; i++) {
      const m = await call('GET', `/v1/content/manifest?deviceId=disp-${i}&appVersion=1.0.0`);
      if (m.json.contentVersion === rel.json.release.number) gotNew++;
    }
    expect(gotNew).toBeGreaterThan(5);
    expect(gotNew).toBeLessThan(45);
    const roll = await call('POST', '/v1/admin/releases/rollback', { reason: 'Prueba de reversión' }, t);
    expect(roll.json.active).toBe('2026.11.1');
    const after = await call('GET', '/v1/content/manifest?deviceId=disp-1&appVersion=1.0.0');
    expect(after.json.contentVersion).toBe('2026.11.1');
  });
  it('Compatibilidad con la app: una versión que exige una app más reciente se omite y se avisa', async () => {
    const owner = adminDb(); await owner.connect();
    await owner.query("UPDATE releases SET min_app_version = '9.0.0', state = 'published', rollout_pct = 100, published_at = now() WHERE state = 'rolled_back'");
    await owner.end();
    const m = await call('GET', '/v1/content/manifest?deviceId=viejo&appVersion=1.0.0');
    expect(m.json.contentVersion).toBe('2026.11.1');
    expect(m.json.newerRequiresAppVersion).toBe('9.0.0');
    const owner2 = adminDb(); await owner2.connect();
    await owner2.query("UPDATE releases SET state = 'rolled_back' WHERE min_app_version = '9.0.0'");
    await owner2.end();
  });
  it('Retirada inmediata de una plantilla desde una consulta: llega en la lista de retirada', async () => {
    const t = await bo('contenido@volutrainmed.test');
    const inq = await call('GET', '/v1/admin/inquiries', undefined, t);
    const one = inq.json.items.find((i: any) => i.exercise?.templateId === 'tpl-v-meloxicam');
    const r = await call('POST', `/v1/admin/inquiries/${one.id}/withdraw-exercise`, { reason: 'Error detectado' }, t);
    expect(r.status).toBe(200);
    const rev = await call('GET', '/v1/content/revocations');
    expect(rev.json.templateIds).toContain('tpl-v-meloxicam');
    const conv = await call('POST', `/v1/admin/inquiries/${one.id}/convert`, undefined, t);
    expect(conv.json.itemId).toBe('tpl-v-meloxicam');
    const item = await call('GET', '/v1/admin/items/tpl-v-meloxicam', undefined, t);
    expect(item.json.item.state).toBe('draft');
    expect(item.json.item.linkedInquiry).toBe(one.id);
  });
  it('Consulta sobre un paciente: se responde con la respuesta modelo que la declina', async () => {
    const u = await appUser('paciente@correo.test');
    await call('POST', '/v1/inquiries', { id: randomUUID(), type: 'other', message: 'Tengo un paciente real de 70 kg, ¿cuánto le pongo?', replyEmail: null, createdAt: new Date().toISOString() }, u.token);
    const t = await bo('soporte@volutrainmed.test');
    const list = await call('GET', '/v1/admin/inquiries', undefined, t);
    const q = list.json.items.find((i: any) => i.message.includes('paciente real'));
    const detail = await call('GET', `/v1/admin/inquiries/${q.id}`, undefined, t);
    expect(detail.json.suggestedModel).toBe('patient');
    expect((await call('POST', `/v1/admin/inquiries/${q.id}/reply`, { template: 'patient' }, t)).status).toBe(200);
    const mine = await call('GET', '/v1/inquiries', undefined, u.token);
    expect(mine.json.items[0].reply).toContain('no respondemos consultas sobre pacientes');
  });
});

describe('premium-subscription', () => {
  it('Prueba gratuita una sola vez, cancelación, compra cancelada y fallida, restauración en otro dispositivo', async () => {
    const u = await appUser('premium@correo.test', 'p-movil');
    const prods = await call('GET', '/v1/store/products');
    expect(prods.json.products.map((p: any) => p.price)).toEqual(['6.99', '39.99']);
    const cancel = await call('POST', '/v1/store/purchase', { productId: 'vtm_premium_annual', withTrial: true, simulate: 'cancel' }, u.token);
    expect(cancel.status).toBe(409);
    const fail = await call('POST', '/v1/store/purchase', { productId: 'vtm_premium_annual', withTrial: true, simulate: 'fail' }, u.token);
    expect(fail.status).toBe(402);
    const ok = await call('POST', '/v1/store/purchase', { productId: 'vtm_premium_annual', withTrial: true, attributedAdId: 'PA-03' }, u.token);
    expect(ok.json.entitlements).toMatchObject({ premium: true, noAds: true, plan: 'trial', trialUsed: true });
    const other = await appUser('premium@correo.test', 'p-tablet');
    const restored = await call('POST', '/v1/store/restore', undefined, other.token);
    expect(restored.json.entitlements.premium).toBe(true);
    const c = await call('POST', '/v1/store/cancel', undefined, u.token);
    expect(c.json.entitlements).toMatchObject({ premium: true, status: 'cancelled', renewsAt: null });
    const exp = await call('POST', '/v1/dev/subscription/expire', { daysAgo: 1 }, u.token);
    expect(exp.json.entitlements.premium).toBe(false);
    const me = await call('GET', '/v1/me', undefined, u.token);
    expect(me.json.notices).toEqual(['premium_ended']);
    const me2 = await call('GET', '/v1/me', undefined, u.token);
    expect(me2.json.notices).toEqual([]);
    const again = await call('POST', '/v1/store/purchase', { productId: 'vtm_premium_monthly', withTrial: true }, u.token);
    expect(again.json.entitlements.plan).toBe('monthly');
  });
});

describe('organizations', () => {
  it('Unión con código, modo nominal informado, plazas agotadas y derecho sin anuncios', async () => {
    const admin = await bo('superadmin@volutrainmed.test');
    const org = await call('POST', '/v1/admin/orgs', { name: 'Hospital de prueba', seats: 1, validFrom: '2026-01-01', validTo: '2027-12-31', nominal: true }, admin);
    const code = org.json.organization.invite_code;
    const a = await appUser('miembro1@correo.test');
    const preview = await call('POST', '/v1/orgs/preview', { code }, a.token);
    expect(preview.json.organization.visibleData.length).toBeGreaterThan(1);
    expect((await call('POST', '/v1/orgs/join', { code }, a.token)).status).toBe(400);
    const joined = await call('POST', '/v1/orgs/join', { code, acceptNominal: true }, a.token);
    expect(joined.json.entitlements).toMatchObject({ premium: true, noAds: true, source: 'organization' });
    const b = await appUser('miembro2@correo.test');
    const full = await call('POST', '/v1/orgs/join', { code, acceptNominal: true }, b.token);
    expect(full.status).toBe(409);
    expect(full.json.error.code).toBe('seats_exhausted');
  });
  it('Invitación masiva: 117 enviadas y 3 filas con error', async () => {
    const admin = await bo('superadmin@volutrainmed.test');
    const orgs = await call('GET', '/v1/admin/orgs', undefined, admin);
    const org = orgs.json.items[0];
    const emails = [...Array.from({ length: 117 }, (_, i) => `alumno${i}@facultad-demo.test`), 'malo@', 'sinarroba.test', 'otro@@x'];
    const r = await call('POST', `/v1/admin/orgs/${org.id}/invites`, { emails }, admin);
    expect(r.json.sent).toBe(117);
    expect(r.json.invalid).toHaveLength(3);
  });
  it('Grupo pequeño: con menos de 5 miembros activos el informe no muestra datos agregados', async () => {
    const orgAdmin = await bo('organizacion@volutrainmed.test');
    const orgs = await call('GET', '/v1/admin/orgs', undefined, orgAdmin);
    expect(orgs.json.items).toHaveLength(1);
    const report = await call('GET', `/v1/admin/orgs/${orgs.json.items[0].id}/report`, undefined, orgAdmin);
    expect(report.json.insufficient).toBe(true);
    const other = await call('GET', '/v1/admin/orgs/00000000-0000-0000-0000-000000000000/report', undefined, orgAdmin);
    expect(other.status).toBe(403);
  });
  it('Dominio autorizado: la app ofrece unirse', async () => {
    const u = await appUser('estudiante@facultad-demo.test');
    const offer = await call('GET', '/v1/orgs/domain-offer', undefined, u.token);
    expect(offer.json.organization.name).toBe('Facultad de demostración');
  });
});

describe('leagues', () => {
  it('Tope diario de 300 puntos, alias y detección de tiempos imposibles', async () => {
    const u = await appUser('liga@correo.test');
    const atts = Array.from({ length: 40 }, () => attempt({ responseMs: 9000 }));
    await call('POST', '/v1/sync/push', { deviceId: u.deviceId, appVersion: '1.0.0', attempts: atts, sessions: [], events: [] }, u.token);
    const l = await call('GET', '/v1/leagues/current', undefined, u.token);
    expect(l.json.participating).toBe(true);
    const me = l.json.standings.find((s: any) => s.me);
    expect(me.points).toBe(300);
    expect(me.alias).not.toContain('@');
    const cheat = await appUser('rapido@correo.test');
    const fast = Array.from({ length: 6 }, () => attempt({ responseMs: 200 }));
    await call('POST', '/v1/sync/push', { deviceId: cheat.deviceId, appVersion: '1.0.0', attempts: fast, sessions: [], events: [] }, cheat.token);
    const lc = await call('GET', '/v1/leagues/current', undefined, cheat.token);
    expect(lc.json.standings.find((s: any) => s.me).points).toBe(0);
    expect(lc.json.suspendedAttempts).toBe(6);
    const admin = await bo('contenido@volutrainmed.test');
    const flags = await call('GET', '/v1/admin/leagues/flagged', undefined, admin);
    expect(flags.json.items.length).toBeGreaterThan(0);
  });
  it('Salida de las ligas: deja de aparecer y puede volver', async () => {
    const u = await appUser('fuera@correo.test');
    await call('POST', '/v1/leagues/participation', { participate: false }, u.token);
    expect((await call('GET', '/v1/leagues/current', undefined, u.token)).json.participating).toBe(false);
    await call('POST', '/v1/leagues/participation', { participate: true }, u.token);
    expect((await call('GET', '/v1/leagues/current', undefined, u.token)).json.participating).toBe(true);
  });
  it('Cambio del tope diario: entra en vigor el lunes siguiente', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    const cfg = (await call('GET', '/v1/admin/leagues/config', undefined, admin)).json.current;
    const r = await call('PUT', '/v1/admin/leagues/config', { ...cfg, dailyCap: 250 }, admin);
    const from = new Date(r.json.scheduledFrom);
    expect(from.getUTCDay()).toBe(1);
    expect(from.getTime()).toBeGreaterThan(Date.now());
    const now = (await call('GET', '/v1/admin/leagues/config', undefined, admin)).json;
    expect(now.current.dailyCap).toBe(300);
    expect(now.scheduled.value.dailyCap).toBe(250);
  });
  it('Logro de racha: prueba de la condición con un usuario de ejemplo de 12 días', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    const r = await call('POST', '/v1/admin/achievements/test', { condition: { metric: 'streak_days', op: '>=', value: 30 }, sample: { streak_days: 12 } }, admin);
    expect(r.json.obtains).toBe(false);
  });
});

describe('leagues (cierre semanal)', () => {
  async function sectorUser(email: string, sectorId: string) {
    const u = await appUser(email);
    await call('PATCH', '/v1/me', { sectorId }, u.token);
    return u;
  }
  it('Inicio de semana: cada participante queda asignado a un grupo de su división con usuarios de su sector', async () => {
    const a = await sectorUser('semana-a@correo.test', 'emergencias');
    const b = await sectorUser('semana-b@correo.test', 'emergencias');
    const c = await sectorUser('semana-c@correo.test', 'pediatria');
    const la = (await call('GET', '/v1/leagues/current', undefined, a.token)).json;
    const lb = (await call('GET', '/v1/leagues/current', undefined, b.token)).json;
    const lc = (await call('GET', '/v1/leagues/current', undefined, c.token)).json;
    expect(la.division).toBe('Bronce');
    const aliasesA = la.standings.map((s: any) => s.alias);
    expect(aliasesA).toContain(a.user.alias);
    expect(lb.standings.map((s: any) => s.alias).sort()).toEqual([...aliasesA, ...(aliasesA.includes(b.user.alias) ? [] : [b.user.alias])].sort());
    expect(lc.standings.map((s: any) => s.alias)).not.toContain(a.user.alias);
    const db = adminDb(); await db.connect();
    try {
      const rows = (await db.query(
        `SELECT u.email, g.id, g.division, g.sector_id FROM league_members m JOIN league_groups g ON g.id = m.group_id JOIN users u ON u.id = m.user_id
         WHERE u.email = ANY($1) AND g.private_league_id IS NULL`, [['semana-a@correo.test', 'semana-b@correo.test', 'semana-c@correo.test']])).rows;
      const by = Object.fromEntries(rows.map((r) => [r.email, r]));
      expect(by['semana-a@correo.test'].id).toBe(by['semana-b@correo.test'].id);
      expect(by['semana-a@correo.test'].sector_id).toBe('emergencias');
      expect(by['semana-a@correo.test'].division).toBe(0);
      expect(by['semana-c@correo.test'].sector_id).toBe('pediatria');
      expect(by['semana-c@correo.test'].id).not.toBe(by['semana-a@correo.test'].id);
    } finally { await db.end(); }
  });
  it('Ascenso y descenso: al terminar la semana los 7 primeros de cada grupo suben de división y los 5 últimos bajan', async () => {
    const db = adminDb(); await db.connect();
    try {
      const users = [];
      for (let i = 0; i < 14; i++) {
        const u = await sectorUser(`ascenso-${i}@correo.test`, 'farmacia');
        // Todos empiezan en Plata para que el descenso sea posible.
        await db.query('INSERT INTO league_divisions(user_id, division) VALUES ($1, 1) ON CONFLICT (user_id) DO UPDATE SET division = 1', [u.user.id]);
        const atts = Array.from({ length: 14 - i }, () => attempt({ responseMs: 9000 }));
        await call('POST', '/v1/sync/push', { deviceId: u.deviceId, appVersion: '1.0.0', attempts: atts, sessions: [], events: [] }, u.token);
        users.push(u);
      }
      let week = '';
      for (const u of users) {
        const l = (await call('GET', '/v1/leagues/current', undefined, u.token)).json;
        expect(l.division).toBe('Plata');
        week = l.week;
      }
      const last = (await call('GET', '/v1/leagues/current', undefined, users[0]!.token)).json;
      expect(last.standings).toHaveLength(14);
      expect(last.standings[0].me).toBe(true);
      const sa = await bo('superadmin@volutrainmed.test');
      const closed = await call('POST', '/v1/admin/leagues/close-week', { weekStart: week }, sa);
      expect(closed.status).toBe(200);
      const mine = closed.json.groups.filter((g: any) => g.promoted === 7 && g.relegated === 5);
      expect(mine).toHaveLength(1);
      const div = (await db.query('SELECT u.email, d.division FROM league_divisions d JOIN users u ON u.id = d.user_id WHERE u.email LIKE $1', ['ascenso-%'])).rows;
      const of = (i: number) => div.find((r) => r.email === `ascenso-${i}@correo.test`).division;
      for (let i = 0; i < 7; i++) expect(of(i)).toBe(2);
      for (let i = 7; i < 9; i++) expect(of(i)).toBe(1);
      for (let i = 9; i < 14; i++) expect(of(i)).toBe(0);
      // El cierre semanal es exclusivo de la superadministración y queda en auditoría.
      const ca = await bo('contenido@volutrainmed.test');
      expect((await call('POST', '/v1/admin/leagues/close-week', { weekStart: week }, ca)).status).toBe(403);
      const audit = await call('GET', '/v1/admin/audit?action=league.close_week', undefined, ca);
      expect(audit.json.items.length).toBeGreaterThan(0);
    } finally { await db.end(); }
  });
});

describe('catálogos de habilidades y especies (back office)', () => {
  it('las habilidades y las especies son catálogos con el mismo ciclo de revisión y llegan al paquete publicado', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    const skills = await call('GET', '/v1/admin/items?kind=catalog_skill', undefined, admin);
    expect(skills.json.items).toHaveLength(12);
    expect(skills.json.items.every((i: any) => i.state === 'published' || i.state === 'validated')).toBe(true);
    const species = await call('GET', '/v1/admin/items?kind=catalog_species', undefined, admin);
    expect(species.json.items.map((i: any) => i.data.name).sort()).toEqual(['Caballo', 'Conejo', 'Gato', 'Hurón', 'Perro']);
    // El paquete global lleva las habilidades del catálogo.
    const m = (await call('GET', '/v1/content/manifest?deviceId=cat-1&appVersion=1.0.0')).json as ContentManifest;
    const g = JSON.parse(gunzipSync((await call('GET', m.global.url)).raw).toString('utf8'));
    expect(g.skills.map((k: any) => k.id)).toEqual(['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'H7', 'H8', 'H9', 'H10', 'H11', 'H12']);
    // Alta sin código válido o sin nombre: no se guarda.
    expect((await call('POST', '/v1/admin/items', { kind: 'catalog_skill', data: { code: 'X1', name: 'Mala' } }, admin)).status).toBe(422);
    expect((await call('POST', '/v1/admin/items', { kind: 'catalog_species', data: { name: ' ' } }, admin)).status).toBe(422);
    // Una especie nueva queda en borrador; la autoría no gestiona catálogos.
    const sp = await call('POST', '/v1/admin/items', { kind: 'catalog_species', data: { name: 'Cobaya', sectorId: 'veterinaria' } }, admin);
    expect(sp.json.item.state).toBe('draft');
    const author = await bo('autora@volutrainmed.test');
    expect((await call('POST', '/v1/admin/items', { kind: 'catalog_species', data: { name: 'Loro' } }, author)).status).toBe(403);
    // Cambiar una habilidad publicada crea una versión nueva en borrador.
    const h1 = skills.json.items.find((i: any) => i.data.code === 'H1');
    const upd = await call('PUT', `/v1/admin/items/${h1.id}`, { data: { ...h1.data, name: 'Conversión de unidades (masa, volumen y tiempo)' } }, admin);
    expect(upd.json.item.version).toBe(h1.version + 1);
    expect(upd.json.item.state).toBe('draft');
  });
});

describe('house-ads (back office)', () => {
  it('Espera configurable de 0 a 5 s, auditada', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    expect((await call('PUT', '/v1/admin/ads/params', { waitS: 6, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 }, admin)).status).toBe(400);
    const ok = await call('PUT', '/v1/admin/ads/params', { waitS: 2, frequencyTouch: 1, frequencyVoice: 2, defaultDailyCap: 6 }, admin);
    expect(ok.json.params.waitS).toBe(2);
  });
  it('Texto con alusión clínica: la revisión lo rechaza y no puede publicarse', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    const c = await call('POST', '/v1/admin/items', { kind: 'ad_creative', data: { name: 'Mal anuncio', campaignId: 'camp-lanzamiento', kind: 'generic', context: 'always', weight: 1, dailyCap: 2, headline: 'Úsalo con tu paciente', body: 'En tu guardia, sin pausas.', cta: 'Ver Premium', ctaAction: 'paywall', voiceSpot: null, illustration: 'x' } }, admin);
    const s = await call('POST', `/v1/admin/items/${c.json.item.id}/submit`, undefined, admin);
    expect(s.status).toBe(422);
    expect(s.json.error.message).toMatch(/Término vetado|uso clínico/);
  });
});

describe('exercise-type-builder', () => {
  it('Paso sin bloque de respuesta: no se guarda; con bloque de ordenar no es compatible con voz', async () => {
    const admin = await bo('contenido@volutrainmed.test');
    const bad = await call('POST', '/v1/admin/exercise-types', { id: 'type-x', name: 'Incompleto', description: '', steps: [{ presentation: ['statement'] }], behaviour: [], minAppVersion: '1.0.0' }, admin);
    expect(bad.status).toBe(422);
    const order = await call('POST', '/v1/admin/exercise-types', { id: 'type-orden', name: 'Ordenar y responder', description: '', steps: [{ presentation: ['statement'], response: 'ordering', grading: 'order_equivalences' }, { presentation: ['statement'], response: 'numeric_unit', grading: 'numeric_tolerance' }], behaviour: [], minAppVersion: '1.1.0' }, admin);
    expect(order.json.item.data.voiceCompatible).toBe(false);
    const two = await call('POST', '/v1/admin/exercise-types', { id: 'type-dos', name: 'Selección y número', description: '', steps: [{ presentation: ['statement'], response: 'single_choice', grading: 'exact_match' }, { presentation: ['statement'], response: 'numeric_unit', grading: 'numeric_tolerance' }], behaviour: [], minAppVersion: '1.0.0' }, admin);
    expect(two.json.item.data.voiceCompatible).toBe(true);
    expect(two.json.compatibility.pct).toBeGreaterThanOrEqual(0);
  });
});
