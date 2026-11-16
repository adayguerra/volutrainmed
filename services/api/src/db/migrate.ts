/** Aplica las migraciones SQL pendientes con el usuario propietario. */
import pg from 'pg';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ADMIN_URL } from './pool.js';

const dir = join(dirname(fileURLToPath(import.meta.url)), 'migrations');

/** Con `reset`, vacía el esquema (solo para desarrollo y pruebas). */
export async function migrate(reset = false): Promise<string[]> {
  const client = new pg.Client({ connectionString: ADMIN_URL });
  await client.connect();
  try {
    if (reset) {
      await client.query('DROP SCHEMA IF EXISTS public CASCADE');
      await client.query('CREATE SCHEMA public');
      await client.query('GRANT ALL ON SCHEMA public TO public');
    }
    await client.query('CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
    const done = new Set((await client.query('SELECT name FROM schema_migrations')).rows.map((r) => r.name as string));
    const applied: string[] = [];
    for (const f of readdirSync(dir).filter((x) => x.endsWith('.sql')).sort()) {
      if (done.has(f)) continue;
      await client.query('BEGIN');
      await client.query(readFileSync(join(dir, f), 'utf8'));
      await client.query('INSERT INTO schema_migrations(name) VALUES ($1)', [f]);
      await client.query('COMMIT');
      applied.push(f);
    }
    return applied;
  } finally {
    await client.end();
  }
}

if (process.argv[1]?.endsWith('migrate.ts')) {
  migrate(process.argv.includes('--reset')).then((a) => console.log(a.length ? `Aplicadas: ${a.join(', ')}` : 'Sin migraciones pendientes'));
}
