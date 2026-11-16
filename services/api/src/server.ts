/**
 * API de VolutrainMed. Contrato: contracts/api.md.
 */
import Fastify, { type FastifyInstance, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import { ApiError, forbidden, unauthorized } from './lib/errors.js';
import { verifyJwt } from './lib/crypto.js';
import type { Actor } from './db/pool.js';
import { appRoutes } from './routes/app.js';
import { syncRoutes } from './routes/sync.js';
import { contentRoutes } from './routes/content.js';
import { storeRoutes } from './routes/store.js';
import { growthAppRoutes } from './routes/growth-app.js';
import { adminAuthRoutes } from './routes/admin-auth.js';
import { adminContentRoutes } from './routes/admin-content.js';
import { adminReleaseRoutes } from './routes/admin-releases.js';
import { adminPeopleRoutes } from './routes/admin-people.js';
import { adminInsightRoutes } from './routes/admin-insights.js';

export type BoRole = 'superadmin' | 'content_admin' | 'author' | 'reviewer' | 'org_admin' | 'analyst' | 'support';

export interface AppUserCtx { userId: string; deviceId?: string }
export interface BoCtx { accountId: string; role: BoRole; sectors: string[]; orgId: string | null; name: string; email: string }

declare module 'fastify' {
  interface FastifyRequest {
    appUser?: AppUserCtx | null;
    bo?: BoCtx | null;
  }
}

export function appActor(req: FastifyRequest): Actor {
  return req.appUser ? { role: 'user', userId: req.appUser.userId } : { role: 'anonymous' };
}

export function requireUser(req: FastifyRequest): AppUserCtx {
  if (!req.appUser) throw unauthorized();
  return req.appUser;
}

export function requireBo(req: FastifyRequest, roles?: BoRole[]): BoCtx {
  if (!req.bo) throw unauthorized('Inicia sesión en el back office con tu segundo factor');
  if (roles && !roles.includes(req.bo.role)) throw forbidden();
  return req.bo;
}

export function boActor(bo: BoCtx): Actor {
  return { role: bo.role, actorId: bo.accountId };
}

export async function buildApp(opts: { logger?: boolean } = {}): Promise<FastifyInstance> {
  const app = Fastify({ logger: opts.logger ?? false, bodyLimit: 25 * 1024 * 1024 });
  await app.register(cors, { origin: true, exposedHeaders: ['Content-Range', 'Accept-Ranges', 'Content-Length'] });

  app.addHook('onRequest', async (req) => {
    req.appUser = null;
    req.bo = null;
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) return;
    const payload = verifyJwt<Record<string, unknown>>(h.slice(7));
    if (!payload) return;
    if (payload.kind === 'app' && typeof payload.sub === 'string') req.appUser = { userId: payload.sub, deviceId: payload.deviceId as string | undefined };
    if (payload.kind === 'bo' && payload.mfa === true && typeof payload.sub === 'string') {
      req.bo = { accountId: payload.sub, role: payload.role as BoRole, sectors: (payload.sectors as string[]) ?? [], orgId: (payload.orgId as string | null) ?? null, name: String(payload.name ?? ''), email: String(payload.email ?? '') };
    }
  });

  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof ApiError) return reply.status(err.status).send({ error: { code: err.code, message: err.message } });
    const pgErr = err as { code?: string; message: string };
    if (pgErr.code === '42501') return reply.status(403).send({ error: { code: 'forbidden', message: pgErr.message } });
    if (pgErr.code === '23514') return reply.status(422).send({ error: { code: 'rule_violation', message: pgErr.message } });
    if ((err as { validation?: unknown }).validation) return reply.status(400).send({ error: { code: 'invalid', message: pgErr.message } });
    app.log.error(err);
    return reply.status(500).send({ error: { code: 'internal', message: 'Ha ocurrido un error inesperado' } });
  });

  app.get('/v1/health', async () => ({ ok: true, time: new Date().toISOString() }));

  await app.register(appRoutes);
  await app.register(syncRoutes);
  await app.register(contentRoutes);
  await app.register(storeRoutes);
  await app.register(growthAppRoutes);
  await app.register(adminAuthRoutes);
  await app.register(adminContentRoutes);
  await app.register(adminReleaseRoutes);
  await app.register(adminPeopleRoutes);
  await app.register(adminInsightRoutes);
  return app;
}

if (process.argv[1]?.endsWith('server.ts')) {
  const port = Number(process.env.PORT ?? 8787);
  buildApp({ logger: true }).then((app) => app.listen({ port, host: '0.0.0.0' }));
}
