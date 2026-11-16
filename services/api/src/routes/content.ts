/** Contenido firmado, lista de retirada y paquete de voz (offline-sync, hands-free-voice). */
import type { FastifyInstance, FastifyReply } from 'fastify';
import { gzipSync } from 'node:zlib';
import { createHash, sign as edSign } from 'node:crypto';
import { signaturePayload } from '@vtm/contracts';
import { withTx, SYSTEM } from '../db/pool.js';
import { notFound } from '../lib/errors.js';
import { loadOrCreateKeys } from '../lib/keys.js';
import { manifest, revocations } from '../publish/service.js';

function sendRange(reply: FastifyReply, bytes: Buffer, range: string | undefined, contentType: string) {
  reply.header('Accept-Ranges', 'bytes').header('Content-Type', contentType);
  const m = range?.match(/^bytes=(\d*)-(\d*)$/);
  if (m) {
    const start = m[1] ? Number(m[1]) : 0;
    const end = m[2] ? Math.min(Number(m[2]), bytes.length - 1) : bytes.length - 1;
    if (start >= bytes.length || start > end) return reply.status(416).header('Content-Range', `bytes */${bytes.length}`).send();
    return reply.status(206).header('Content-Range', `bytes ${start}-${end}/${bytes.length}`).header('Content-Length', String(end - start + 1)).send(bytes.subarray(start, end + 1));
  }
  return reply.header('Content-Length', String(bytes.length)).send(bytes);
}

/**
 * Paquete de voz bajo demanda. El modelo de reconocimiento embebido (sherpa-onnx)
 * está pendiente de la prueba técnica (tareas 1.1 y 1.2 del MVP); hasta entonces el
 * paquete distribuye los recursos de idioma (gramática, léxicos, comandos) firmados.
 */
function voicePack() {
  const keys = loadOrCreateKeys();
  const payload = {
    format: 1, version: '2026.11.1', locale: 'es-ES', engine: 'pendiente-prueba-tecnica',
    note: 'Recursos de idioma del modo manos libres. El modelo acústico embebido se añadirá tras la prueba técnica de voz.',
    grammar: { decimalSeparators: ['coma', 'con', 'punto'], fractions: ['medio', 'y medio', 'un cuarto', 'y cuarto', 'tres cuartos'] },
  };
  const bytes = gzipSync(Buffer.from(JSON.stringify(payload)));
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  const id = 'voice-es-ES';
  const signature = edSign(null, Buffer.from(signaturePayload({ id, version: payload.version, sha256 })), keys.privateKey).toString('base64');
  return { meta: { id, version: payload.version, size: bytes.length, sha256, signature, url: '/v1/voice/pack/file', declaredDownloadMb: 0.01 }, bytes };
}

export async function contentRoutes(app: FastifyInstance) {
  app.get<{ Querystring: { deviceId?: string; appVersion?: string; testCode?: string } }>('/v1/content/manifest', async (req, reply) => {
    const m = await withTx({ role: 'public' }, (tx) => manifest(tx, String(req.query.deviceId ?? ''), String(req.query.appVersion ?? '1.0.0'), req.query.testCode || undefined));
    if (!m) return reply.status(404).send({ error: { code: 'no_content', message: 'Aún no hay contenido publicado' } });
    return m;
  });

  app.get<{ Params: { id: string } }>('/v1/content/files/:id', async (req, reply) => {
    const row = await withTx(SYSTEM, async (tx) => (await tx.query('SELECT bytes FROM packages WHERE id = $1', [req.params.id])).rows[0]);
    if (!row) throw notFound('Paquete no encontrado');
    return sendRange(reply, row.bytes as Buffer, req.headers.range, 'application/gzip');
  });

  app.get('/v1/content/revocations', async () => withTx({ role: 'public' }, (tx) => revocations(tx)));

  app.get('/v1/content/public-key', async () => {
    const k = loadOrCreateKeys();
    return { keyId: k.keyId, publicKey: k.publicKeyB64, algorithm: 'Ed25519' };
  });

  app.get('/v1/voice/pack', async () => voicePack().meta);
  app.get('/v1/voice/pack/file', async (req, reply) => sendRange(reply, voicePack().bytes, req.headers.range, 'application/gzip'));
}
