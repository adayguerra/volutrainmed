/**
 * Genera paquetes de ejemplo en contracts/sample/ para el desarrollo de la app
 * (y el paquete de Fundamentos que va incluido dentro de la app).
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildContent, signPackage } from '../publish/build.js';
import { loadOrCreateKeys } from '../lib/keys.js';
import { seedBuildInput } from './input.js';
import { validateTemplate } from '@vtm/engine';
import { TEMPLATES } from './content.js';

const here = dirname(fileURLToPath(import.meta.url));
const out = join(here, '../../../../contracts/sample');
mkdirSync(out, { recursive: true });

let blocking = 0;
for (const t of TEMPLATES) {
  const issues = validateTemplate(t).filter((i) => i.blocking);
  if (issues.length) { blocking++; console.error(`✗ ${t.id}:`, issues.map((i) => i.message).join(' | ')); }
}
if (blocking) process.exit(1);

const res = buildContent(seedBuildInput(process.env.CONTENT_VERSION ?? '2026.11.0', Number(process.env.VARIANTS ?? 12)));
const failed = res.checks.filter((c) => !c.ok);
for (const c of res.checks) console.log(`${c.ok ? '✓' : '✗'} ${c.label}: ${c.detail}`);
const keys = loadOrCreateKeys();
writeFileSync(join(out, 'global.json'), JSON.stringify(res.global, null, 1));
const manifest: Record<string, unknown> = { publicKey: keys.publicKeyB64, keyId: keys.keyId, packages: [] as unknown[] };
for (const p of res.itineraries) {
  writeFileSync(join(out, `${p.itinerary.id}.json`), JSON.stringify(p, null, 1));
  const signed = signPackage(p.itinerary.id, p.contentVersion, p.minAppVersion, p, keys.privateKey, (id) => `${id}.json.gz`);
  writeFileSync(join(out, `${p.itinerary.id}.json.gz`), signed.bytes);
  (manifest.packages as unknown[]).push(signed.file);
  console.log(`${p.itinerary.id}: ${p.units.length} unidades, ${p.lessons.length} lecciones, ${p.variants.length} variantes, ${signed.bytes.length} bytes`);
}
const g = signPackage('global', res.global.contentVersion, res.global.minAppVersion, res.global, keys.privateKey, (id) => `${id}.json.gz`);
writeFileSync(join(out, 'global.json.gz'), g.bytes);
manifest.global = g.file;
writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 1));
if (failed.length) process.exit(2);
