/** Crea la base de datos de DATABASE_ADMIN_URL si no existe (pruebas de extremo a extremo y CI). */
import pg from 'pg';
import { ADMIN_URL } from './pool.js';

async function main() {
  const url = new URL(ADMIN_URL);
  const name = url.pathname.replace(/^\//, '');
  if (!/^[a-z0-9_]+$/.test(name)) throw new Error('Nombre de base no válido');
  url.pathname = '/postgres';
  const c = new pg.Client({ connectionString: url.toString() });
  await c.connect();
  try {
    const r = await c.query('SELECT 1 FROM pg_database WHERE datname = $1', [name]);
    if (!r.rowCount) await c.query(`CREATE DATABASE ${name}`);
    console.log(r.rowCount ? `La base ${name} ya existe` : `Base ${name} creada`);
  } finally {
    await c.end();
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
