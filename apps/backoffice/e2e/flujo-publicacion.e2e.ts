/**
 * Flujo de extremo a extremo contra una API real (sin interfaz):
 * la autora crea y edita una plantilla, la envía a revisión, un revisor distinto
 * la valida, la administración de contenido prepara la versión, genera el
 * paquete de prueba, publica al 5 %, despliega al 100 % y revierte.
 *
 * Uso: E2E_API_BASE=http://localhost:8788 pnpm --filter backoffice e2e
 * Requiere la semilla de la API (`pnpm --filter @vtm/api seed -- --reset`).
 * Los secretos TOTP del primer acceso se guardan en un archivo temporal para
 * poder repetir el flujo; si se pierden, hay que volver a sembrar con --reset.
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { authenticator } from 'otplib';
import { ApiError, createApi, type Api } from '../src/api/client';
import type { Account, Item, LoginResponse, MfaResponse, Release } from '../src/api/types';

const BASE = process.env.E2E_API_BASE ?? 'http://localhost:8788';
const PASSWORD = process.env.E2E_PASSWORD ?? 'VolutrainMed-2026!';
const STATE = process.env.E2E_TOTP_STATE ?? join(tmpdir(), `vtm-bo-e2e-${BASE.replace(/\W+/g, '_')}.json`);

const secrets: Record<string, string> = existsSync(STATE) ? JSON.parse(readFileSync(STATE, 'utf8')) : {};
let step = 0;
const log = (msg: string) => console.log(`${String(++step).padStart(2, '0')}. ${msg}`);

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new Error(`Falla la comprobación: ${msg}`);
}

async function expectError(p: Promise<unknown>, status: number, label: string): Promise<ApiError> {
  try { await p; } catch (e) {
    assert(e instanceof ApiError && e.status === status, `${label}: se esperaba ${status} y llegó ${(e as ApiError).status} ${(e as Error).message}`);
    return e as ApiError;
  }
  throw new Error(`${label}: se esperaba un error ${status}`);
}

async function signIn(email: string): Promise<{ api: Api; account: Account }> {
  const anon = createApi({ base: BASE });
  const login = await anon.post<LoginResponse>('/v1/admin/auth/login', { email, password: PASSWORD });
  let secret = secrets[email];
  if (login.mfaSetupRequired) {
    assert(login.secret && login.otpauthUrl?.startsWith('otpauth://totp/'), 'el primer acceso entrega el secreto TOTP');
    secret = login.secret;
  }
  assert(secret, `no se conoce el secreto TOTP de ${email}: vuelve a sembrar la API con --reset`);
  const r = await anon.post<MfaResponse>('/v1/admin/auth/mfa', { challenge: login.challenge, code: authenticator.generate(secret) });
  if (login.mfaSetupRequired) {
    assert(r.recoveryCodes?.length === 8, 'el alta del segundo factor entrega 8 códigos de recuperación');
    secrets[email] = secret;
    writeFileSync(STATE, JSON.stringify(secrets, null, 2));
  }
  const token = r.token;
  return { api: createApi({ base: BASE, getToken: () => token }), account: r.account };
}

function template(id: string, formula = 'dosis ÷ conc'): Record<string, unknown> {
  const lv = (l: 1 | 2 | 3 | 4 | 5) => ({ level: l, unitFixed: l <= 3, targetTimeS: 20 + (l - 1) * 5, overrides: l === 1 ? { dosis: { min: '20', max: '100', step: '20' } } : undefined });
  return {
    id, version: 1, name: `Volumen a cargar (e2e ${id.slice(-6)})`, sectorId: 'comun', skillId: 'H4', exerciseTypeId: 'T1',
    variables: [
      { name: 'dosis', label: 'Dosis', kind: 'int', unit: 'mg', min: '10', max: '200', step: '10', show: true },
      { name: 'conc', label: 'Concentración', kind: 'list', unit: 'mg/ml', values: ['5', '10', '20', '50'], show: true },
    ],
    statement: 'Necesitas {dosis} de un fármaco cuya presentación es de {conc}.', question: '¿Qué volumen cargas?', tts: null,
    formula, answerUnit: 'ml', unitChoices: ['ml'], equivalents: [], rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' },
    constraints: { resultMin: '0.1', resultMax: '20', conditions: [] },
    predictedErrors: [{ formula: 'respuesta × 10', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: 1 }],
    steps: [{ text: 'Volumen = dosis ÷ concentración', formula: 'dosis ÷ conc', unit: 'ml', operation: '{dosis} ÷ {conc}', cancelled: ['mg'] }],
    plausibility: '{respuesta}: mg divididos entre mg/ml dan ml. Tiene sentido.',
    levels: [lv(1), lv(2), lv(3), lv(4), lv(5)], variantsPerLevel: 20, demo: true,
  };
}

async function manifestVersions(n: number, testCode?: string): Promise<Map<string, number>> {
  const anon = createApi({ base: BASE });
  const counts = new Map<string, number>();
  for (let i = 0; i < n; i++) {
    const m = await anon.get<{ contentVersion: string }>('/v1/content/manifest', { deviceId: `e2e-disp-${i}-${Math.random().toString(36).slice(2)}`, appVersion: '1.0.0', testCode });
    counts.set(m.contentVersion, (counts.get(m.contentVersion) ?? 0) + 1);
  }
  return counts;
}

async function main() {
  console.log(`API: ${BASE}`);
  const tid = `tpl-e2e-${Date.now().toString(36)}`;

  // ---------------------------------------------------------------- Autoría
  const autora = await signIn('autora@volutrainmed.test');
  log(`Acceso con doble factor como ${autora.account.name} (${autora.account.roleLabel})`);
  const bad = await expectError(autora.api.post('/v1/admin/items', { kind: 'template', data: template(`${tid}-mal`, 'dosis × conc') }), 422, 'fórmula sin cuadrar');
  assert(bad.message.includes('no en ml'), `la comprobación dimensional impide guardar: «${bad.message}»`);
  log(`Fórmula incoherente rechazada al guardar: «${bad.message}»`);
  const created = await autora.api.post<{ item: Item }>('/v1/admin/items', { kind: 'template', data: { ...template(tid), formula: 'dosis ÷ conc ÷ 1' } });
  assert(created.item.state === 'draft' && created.item.id === tid, 'la plantilla nueva queda en borrador');
  log(`Plantilla creada en borrador: ${tid}`);
  const edited = await autora.api.put<{ item: Item }>(`/v1/admin/items/${tid}`, { data: template(tid) });
  assert((edited.item.data as { formula: string }).formula === 'dosis ÷ conc', 'la edición guarda la fórmula nueva');
  log('Plantilla editada (fórmula simplificada)');
  const sample = await autora.api.post<{ variants: unknown[] }>('/v1/admin/engine/sample', { definition: template(tid), n: 20 });
  assert(sample.variants.length === 20, 'la muestra devuelve 20 variantes');
  log('Muestra de 20 variantes generada');
  const submitted = await autora.api.post<{ item: Item }>(`/v1/admin/items/${tid}/submit`);
  assert(submitted.item.state === 'in_review', 'el envío deja la plantilla en revisión');
  log('Enviada a revisión');
  await expectError(autora.api.post(`/v1/admin/reviews/${tid}/decision`, { decision: 'validate', checklist: {} }), 403, 'la autora no valida');
  log('La autora no puede validar su propio contenido (403)');

  // ---------------------------------------------------------------- Revisión
  const revisor = await signIn('revisor.clinico@volutrainmed.test');
  log(`Acceso como ${revisor.account.name}`);
  const sheet = await revisor.api.get<{ canValidate: boolean; sample: { matches: boolean }[]; extremes: unknown[]; checklist: { key: string }[]; item: Item }>(`/v1/admin/reviews/${tid}`);
  assert(sheet.canValidate, 'un revisor distinto del autor y acreditado en el sector puede validar');
  assert(sheet.sample.length === 20 && sheet.sample.every((s) => s.matches) && sheet.extremes.length === 2, 'ficha con 20 variantes, extremos y recálculo coincidente');
  log('Ficha de revisión: 20 variantes al azar, 2 extremos y recálculo independiente coincidente');
  const incomplete = Object.fromEntries(sheet.checklist.map((c, i) => [c.key, i > 0]));
  await expectError(revisor.api.post(`/v1/admin/reviews/${tid}/decision`, { decision: 'validate', checklist: incomplete, fingerprint: sheet.item.fingerprint }), 422, 'lista incompleta');
  log('[Lista incompleta] Validación con un punto sin marcar rechazada (422)');
  const checklist = Object.fromEntries(sheet.checklist.map((c) => [c.key, true]));
  const dec = await revisor.api.post<{ state: string }>(`/v1/admin/reviews/${tid}/decision`, { decision: 'validate', checklist, fingerprint: sheet.item.fingerprint, comment: 'Validada en la prueba de extremo a extremo' });
  assert(dec.state === 'validated', 'la plantilla queda validada');
  log('Validada por el revisor');

  // ---------------------------------------------------------------- Publicación
  const admin = await signIn('contenido@volutrainmed.test');
  log(`Acceso como ${admin.account.name} (${admin.account.roleLabel})`);
  // La plantilla entra en una unidad de Fundamentos: la unidad cambia y también pasa por revisión.
  const tree = await admin.api.get<{ tree: { id: string; children: { id: string; children: { id: string; kind: string; data: { templateIds?: string[] } }[] }[] }[] }>('/v1/admin/structure');
  const unit = tree.tree.flatMap((s) => s.children).find((it) => it.id === 'it-fundamentos')?.children.find((u) => u.kind === 'unit');
  assert(unit, 'hay una unidad en Fundamentos');
  await admin.api.patch(`/v1/admin/structure/unit/${unit.id}`, { templateIds: [...(unit.data.templateIds ?? []), tid] });
  await admin.api.post(`/v1/admin/items/${unit.id}/submit`);
  const unitSheet = await revisor.api.get<{ checklist: { key: string }[]; item: Item }>(`/v1/admin/reviews/${unit.id}`);
  const unitDec = await revisor.api.post<{ state: string }>(`/v1/admin/reviews/${unit.id}/decision`, { decision: 'validate', checklist: Object.fromEntries(unitSheet.checklist.map((c) => [c.key, true])), fingerprint: unitSheet.item.fingerprint });
  assert(unitDec.state === 'validated', 'la unidad con la plantilla queda validada');
  log(`Plantilla añadida a la unidad ${unit.id}, enviada a revisión y validada`);
  const before = await admin.api.get<{ items: Release[] }>('/v1/admin/releases');
  const active = before.items.find((r) => r.state === 'published' && r.rolloutPct === 100);
  assert(active, 'hay una versión activa al 100 %');
  const { release } = await admin.api.post<{ release: Release }>('/v1/admin/releases', { notes: 'Prueba de extremo a extremo', minAppVersion: '1.0.0' });
  const inDiff = [...release.diff!.added, ...release.diff!.changed].some((d) => d.id === tid);
  assert(inDiff, 'la versión preparada incluye la plantilla validada');
  log(`Versión ${release.number} preparada: ${release.diff!.added.length} añadidos, ${release.diff!.changed.length} modificados, ${release.diff!.excluded.length} excluidos`);
  const checks = await admin.api.post<{ summary: { passed: boolean; failed: number; total: number }; checks: { ok: boolean; detail: string }[] }>(`/v1/admin/releases/${release.id}/checks`);
  assert(checks.summary.passed, `comprobaciones superadas: ${checks.checks.filter((c) => !c.ok).map((c) => c.detail).join(' · ')}`);
  log(`[Comprobaciones superadas] Comprobaciones automáticas superadas (${checks.summary.total})`);
  const test = await admin.api.post<{ testCode: string; qrPayload: string }>(`/v1/admin/releases/${release.id}/test-package`);
  const withCode = await manifestVersions(3, test.testCode);
  const withoutCode = await manifestVersions(30);
  assert(withCode.get(release.number) === 3, 'el dispositivo de prueba recibe la versión nueva con el código');
  assert(!withoutCode.has(release.number), 'ningún usuario recibe el paquete de prueba');
  log(`[Prueba en un dispositivo] Paquete de prueba ${test.testCode}: lo recibe el dispositivo con el código y ningún otro`);
  await expectError(admin.api.post(`/v1/admin/releases/${release.id}/publish`, { confirmName: 'otra', rolloutPct: 5 }), 400, 'nombre de confirmación');
  const pub = await admin.api.post<{ release: Release }>(`/v1/admin/releases/${release.id}/publish`, { confirmName: release.number, rolloutPct: 5 });
  assert(pub.release.state === 'published' && pub.release.rolloutPct === 5, 'publicada al 5 %');
  const at5 = await manifestVersions(400);
  const share = (at5.get(release.number) ?? 0) / 400;
  assert(share > 0.01 && share < 0.11, `al 5 % la recibe una pequeña parte de los dispositivos (${(share * 100).toFixed(1)} %)`);
  assert(at5.get(active.number), 'el resto conserva la versión anterior');
  log(`[Despliegue al 5 %] Publicada al 5 %: ${(share * 100).toFixed(1)} % de 400 dispositivos simulados la reciben; el resto sigue en ${active.number}`);
  await admin.api.post(`/v1/admin/releases/${release.id}/rollout`, { rolloutPct: 100 });
  const at100 = await manifestVersions(50);
  assert(at100.get(release.number) === 50, 'al 100 % la reciben todos');
  log('Despliegue al 100 %: la reciben todos los dispositivos');
  // Un dispositivo con la app ya instalada descarga el contenido y encuentra los ejercicios de la plantilla.
  const anon = createApi({ base: BASE });
  const man = await anon.get<{ contentVersion: string; packages: { itineraryId: string; url: string; sha256: string }[] }>('/v1/content/manifest', { deviceId: 'e2e-dispositivo-instalado', appVersion: '1.0.0' });
  const pkgRef = man.packages.find((p) => p.itineraryId === 'it-fundamentos');
  assert(man.contentVersion === release.number && pkgRef, 'el manifiesto ofrece el paquete de Fundamentos de la versión nueva');
  const bytes = Buffer.from(await (await fetch(`${BASE}${pkgRef.url}`)).arrayBuffer());
  assert(createHash('sha256').update(bytes).digest('hex') === pkgRef.sha256, 'el paquete descargado coincide con su huella firmada');
  const pkg = JSON.parse(gunzipSync(bytes).toString('utf8')) as { variants: { templateId: string | null }[] };
  const mine = pkg.variants.filter((v) => v.templateId === tid).length;
  assert(mine > 0, 'el paquete incluye variantes de la plantilla nueva');
  log(`[De la plantilla al dispositivo] El dispositivo instalado descarga ${release.number} y recibe ${mine} variantes de la plantilla, sin versión nueva de la app`);
  await expectError(admin.api.post('/v1/admin/releases/rollback', { reason: '' }), 400, 'motivo de reversión');
  const rb = await admin.api.post<{ rolledBack: string; active: string }>('/v1/admin/releases/rollback', { reason: 'Prueba de extremo a extremo: reversión' });
  assert(rb.rolledBack === release.number && rb.active === active.number, 'la reversión vuelve a la versión anterior');
  const afterRb = await manifestVersions(30);
  assert(afterRb.get(active.number) === 30, 'las apps vuelven a la versión anterior en su siguiente descarga');
  const audit = await admin.api.get<{ items: { action: string; reason: string | null; entity_id: string }[] }>('/v1/admin/audit', { action: 'release.rollback', limit: 5 });
  assert(audit.items.some((a) => a.reason === 'Prueba de extremo a extremo: reversión'), 'la reversión queda en auditoría con su motivo');
  log(`[Reversión de una versión] Revertida ${rb.rolledBack} → ${rb.active}; los dispositivos vuelven a ${rb.active} y la auditoría guarda el motivo`);
  const itemAudit = await admin.api.get<{ items: { action: string; entity_id: string }[] }>('/v1/admin/audit', { entity: 'template', limit: 200 });
  const actions = itemAudit.items.filter((a) => a.entity_id === tid).map((a) => a.action);
  for (const a of ['item.create', 'item.update', 'item.submit', 'review.validate']) assert(actions.includes(a), `auditoría de ${a}`);
  log(`Auditoría de la plantilla: ${actions.reverse().join(' → ')}`);

  // ---------------------------------------------------------------- Retirada desde una consulta
  const inquiryId = randomUUID();
  const sent = await anon.post<{ id: string; reference: string }>('/v1/inquiries', {
    id: inquiryId, type: 'exercise_error', message: 'La respuesta de este ejercicio no me cuadra (prueba de extremo a extremo).', replyEmail: null,
    exercise: { variantId: `${tid}.v1.1`, templateId: tid, questionId: null, answerValue: '1', answerUnit: 'ml' }, createdAt: new Date().toISOString(), deviceId: 'e2e-dispositivo-instalado',
  });
  const revBefore = await anon.get<{ version: number; templateIds: string[] }>('/v1/content/revocations');
  assert(!revBefore.templateIds.includes(tid), 'la plantilla no está retirada antes de la consulta');
  await admin.api.post(`/v1/admin/inquiries/${inquiryId}/withdraw-exercise`, { reason: `Retirada desde la consulta ${sent.reference} (prueba de extremo a extremo)` });
  const revAfter = await anon.get<{ version: number; templateIds: string[] }>('/v1/content/revocations');
  const manAfter = await anon.get<{ contentVersion: string; revocations: { templateIds: string[] } }>('/v1/content/manifest', { deviceId: 'e2e-dispositivo-instalado', appVersion: '1.0.0' });
  assert(revAfter.templateIds.includes(tid) && revAfter.version > revBefore.version, 'la lista de retirada pública incluye la plantilla y sube de versión');
  assert(manAfter.revocations.templateIds.includes(tid) && manAfter.contentVersion === active.number, 'el manifiesto que descargan las apps lleva la retirada sin publicar una versión nueva');
  log(`[Retirada de una plantilla con error] Desde la consulta ${sent.reference}: la plantilla entra en la lista de retirada que las apps leen al conectarse, sin publicar versión (contenido sigue en ${manAfter.contentVersion})`);

  console.log('\nFlujo de extremo a extremo completado sin errores.');
}

main().catch((e) => {
  console.error(`\nError en el paso ${step + 1}: ${e instanceof Error ? e.message : e}`);
  process.exit(1);
});
