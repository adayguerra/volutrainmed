/**
 * Claves Ed25519 de firma de paquetes. La privada se genera una vez en
 * services/api/keys/ (no se versiona); la pública se fija en la app.
 */
import { createPrivateKey, createPublicKey, generateKeyPairSync, type KeyObject } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const KEYS_DIR = process.env.VTM_KEYS_DIR ?? join(here, '../../keys');
export const KEY_ID = 'vtm-content-2026-1';

export interface ContentKeys { privateKey: KeyObject; publicKey: KeyObject; publicKeyB64: string; keyId: string }

export function loadOrCreateKeys(): ContentKeys {
  const privPath = join(KEYS_DIR, 'content-signing.pem');
  if (!existsSync(privPath)) {
    mkdirSync(KEYS_DIR, { recursive: true });
    const { privateKey } = generateKeyPairSync('ed25519');
    writeFileSync(privPath, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
  }
  const privateKey = createPrivateKey(readFileSync(privPath));
  const publicKey = createPublicKey(privateKey);
  const raw = publicKey.export({ type: 'spki', format: 'der' });
  // Los 32 últimos bytes del SPKI de Ed25519 son la clave pública en bruto.
  const publicKeyB64 = Buffer.from(raw.subarray(raw.length - 32)).toString('base64');
  const pubFile = join(KEYS_DIR, 'content-signing.pub.b64');
  writeFileSync(pubFile, publicKeyB64 + '\n');
  return { privateKey, publicKey, publicKeyB64, keyId: KEY_ID };
}

export function ensureDir(p: string) { mkdirSync(dirname(p), { recursive: true }); }
