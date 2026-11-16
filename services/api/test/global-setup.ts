/** Crea la base de pruebas, aplica el esquema desde cero y carga la semilla con su primera publicación. */
import pg from 'pg';

export default async function setup() {
  const admin = new pg.Client({ connectionString: 'postgres://volutrain:volutrain@localhost:54329/postgres' });
  await admin.connect();
  const exists = (await admin.query("SELECT 1 FROM pg_database WHERE datname = 'volutrainmed_test'")).rowCount;
  if (!exists) await admin.query('CREATE DATABASE volutrainmed_test');
  await admin.end();
  process.env.DATABASE_ADMIN_URL = 'postgres://volutrain:volutrain@localhost:54329/volutrainmed_test';
  process.env.DATABASE_URL = 'postgres://vtm_app:vtm_app_dev@localhost:54329/volutrainmed_test';
  const { seed } = await import('../src/seed/run.js');
  const { closePool } = await import('../src/db/pool.js');
  await seed({ reset: true, log: () => undefined });
  await closePool();
}
