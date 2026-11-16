/**
 * Acceso a Postgres. Cada petición se ejecuta en una transacción con el rol y
 * el actor fijados en la sesión (app.actor_role, app.actor_id, app.user_id),
 * de modo que las políticas RLS y los disparadores apliquen los permisos.
 */
import pg from 'pg';

export const ADMIN_URL = process.env.DATABASE_ADMIN_URL ?? 'postgres://volutrain:volutrain@localhost:54329/volutrainmed';
export const APP_URL = process.env.DATABASE_URL ?? 'postgres://vtm_app:vtm_app_dev@localhost:54329/volutrainmed';

let pool: pg.Pool | null = null;
export function getPool(): pg.Pool {
  pool ??= new pg.Pool({ connectionString: APP_URL, max: 10 });
  return pool;
}
export async function closePool() { await pool?.end(); pool = null; }

export interface Actor {
  role: 'system' | 'anonymous' | 'user' | 'superadmin' | 'content_admin' | 'author' | 'reviewer' | 'org_admin' | 'analyst' | 'support' | 'public';
  actorId?: string | null;
  userId?: string | null;
}

export type Tx = pg.PoolClient;

export async function withTx<T>(actor: Actor, fn: (tx: Tx) => Promise<T>): Promise<T> {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `SELECT set_config('app.actor_role', $1, true), set_config('app.actor_id', $2, true), set_config('app.user_id', $3, true)`,
      [actor.role, actor.actorId ?? '', actor.userId ?? ''],
    );
    const out = await fn(client);
    await client.query('COMMIT');
    return out;
  } catch (e) {
    await client.query('ROLLBACK').catch(() => undefined);
    throw e;
  } finally {
    client.release();
  }
}

export const SYSTEM: Actor = { role: 'system' };
