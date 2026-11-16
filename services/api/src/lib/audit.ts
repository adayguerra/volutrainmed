import type { Tx } from '../db/pool.js';

/** Añade una entrada al registro de auditoría (inalterable por disparador). */
export async function audit(tx: Tx, a: { actorId?: string | null; actorRole: string; action: string; entity: string; entityId?: string | null; before?: unknown; after?: unknown; reason?: string | null }) {
  await tx.query(
    'INSERT INTO audit_log(actor_id, actor_role, action, entity, entity_id, before, after, reason) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)',
    [a.actorId ?? null, a.actorRole, a.action, a.entity, a.entityId ?? null, a.before === undefined ? null : JSON.stringify(a.before), a.after === undefined ? null : JSON.stringify(a.after), a.reason ?? null],
  );
}
