/** JWT HS256, TOTP (RFC 6238), contraseñas con scrypt y códigos de un solo uso. */
import { createHmac, randomBytes, randomInt, scryptSync, timingSafeEqual, createHash } from 'node:crypto';

const SECRET = process.env.JWT_SECRET ?? 'vtm-dev-secret-cambiar-en-produccion';

const b64u = (b: Buffer | string) => Buffer.from(b).toString('base64url');

export function signJwt(payload: Record<string, unknown>, ttlSeconds: number): string {
  const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const body = b64u(JSON.stringify({ ...payload, iat: now, exp: now + ttlSeconds }));
  const sig = b64u(createHmac('sha256', SECRET).update(`${header}.${body}`).digest());
  return `${header}.${body}.${sig}`;
}

export function verifyJwt<T = Record<string, unknown>>(token: string): T | null {
  const [h, b, s] = token.split('.');
  if (!h || !b || !s) return null;
  const expected = b64u(createHmac('sha256', SECRET).update(`${h}.${b}`).digest());
  if (expected.length !== s.length || !timingSafeEqual(Buffer.from(expected), Buffer.from(s))) return null;
  try {
    const payload = JSON.parse(Buffer.from(b, 'base64url').toString('utf8'));
    if (typeof payload.exp === 'number' && payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload as T;
  } catch {
    return null;
  }
}

export function hashPassword(pw: string): string {
  const salt = randomBytes(16);
  const hash = scryptSync(pw, salt, 32);
  return `scrypt$${salt.toString('hex')}$${hash.toString('hex')}`;
}
export function verifyPassword(pw: string, stored: string): boolean {
  const [, saltHex, hashHex] = stored.split('$');
  if (!saltHex || !hashHex) return false;
  const hash = scryptSync(pw, Buffer.from(saltHex, 'hex'), 32);
  return timingSafeEqual(hash, Buffer.from(hashHex, 'hex'));
}

const B32 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
export function base32Encode(buf: Buffer): string {
  let bits = 0; let value = 0; let out = '';
  for (const byte of buf) { value = (value << 8) | byte; bits += 8; while (bits >= 5) { out += B32[(value >>> (bits - 5)) & 31]; bits -= 5; } }
  if (bits > 0) out += B32[(value << (5 - bits)) & 31];
  return out;
}
export function base32Decode(s: string): Buffer {
  let bits = 0; let value = 0; const out: number[] = [];
  for (const c of s.replace(/=+$/, '').toUpperCase()) { value = (value << 5) | B32.indexOf(c); bits += 5; if (bits >= 8) { out.push((value >>> (bits - 8)) & 255); bits -= 8; } }
  return Buffer.from(out);
}
export function newTotpSecret(): string { return base32Encode(randomBytes(20)); }
export function totp(secret: string, timeMs = Date.now(), step = 30): string {
  const counter = Math.floor(timeMs / 1000 / step);
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(counter));
  const h = createHmac('sha1', base32Decode(secret)).update(buf).digest();
  const off = h[h.length - 1]! & 0xf;
  return ((h.readUInt32BE(off) & 0x7fffffff) % 1_000_000).toString().padStart(6, '0');
}
export function verifyTotp(secret: string, code: string): boolean {
  const now = Date.now();
  return [-1, 0, 1].some((d) => totp(secret, now + d * 30_000) === code.trim());
}
export function otpauthUrl(secret: string, email: string): string {
  return `otpauth://totp/VolutrainMed:${encodeURIComponent(email)}?secret=${secret}&issuer=VolutrainMed`;
}

export function sixDigitCode(): string { return String(randomInt(0, 1_000_000)).padStart(6, '0'); }
export function sha256(s: string | Buffer): string { return createHash('sha256').update(s).digest('hex'); }
export function shortCode(len = 8): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < len; i++) out += alphabet[randomInt(0, alphabet.length)];
  return out;
}
/** Cubo de despliegue gradual estable por dispositivo (0–99). */
export function rolloutBucket(deviceId: string): number {
  return createHash('sha256').update(deviceId).digest().readUInt32BE(0) % 100;
}
