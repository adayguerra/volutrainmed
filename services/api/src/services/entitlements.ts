/**
 * Derechos de acceso (premium-subscription y organizations).
 * Fuentes: suscripción de la tienda, días concedidos por soporte y plaza activa
 * en una organización. La app los guarda con validatedAt y valen 30 días sin conexión.
 */
import type { Entitlements, StoreProduct } from '@vtm/contracts';
import type { Tx } from '../db/pool.js';

export const PRODUCTS: StoreProduct[] = [
  { id: 'vtm_premium_monthly', plan: 'monthly', price: '6.99', currency: 'EUR', period: 'P1M', trialDays: 7 },
  { id: 'vtm_premium_annual', plan: 'annual', price: '39.99', currency: 'EUR', period: 'P1Y', trialDays: 7 },
];

export function addPeriod(d: Date, period: 'P1M' | 'P1Y'): Date {
  const r = new Date(d);
  if (period === 'P1M') r.setUTCMonth(r.getUTCMonth() + 1); else r.setUTCFullYear(r.getUTCFullYear() + 1);
  return r;
}

/** Renovación perezosa de la tienda de pruebas: si no está cancelada, renueva al vencer. */
async function renewIfDue(tx: Tx, userId: string) {
  const { rows } = await tx.query('SELECT * FROM subscriptions WHERE user_id = $1', [userId]);
  const s = rows[0];
  if (!s || !s.expires_at || new Date(s.expires_at) > new Date()) return;
  if (s.status === 'active' && s.auto_renew && !s.cancelled_at) {
    const product = PRODUCTS.find((p) => p.plan === s.plan) ?? PRODUCTS[0]!;
    let exp = new Date(s.expires_at);
    while (exp <= new Date()) exp = addPeriod(exp, product.period);
    await tx.query('UPDATE subscriptions SET expires_at = $2, renews_at = $2, updated_at = now() WHERE user_id = $1', [userId, exp]);
    await tx.query("INSERT INTO store_transactions(user_id, product_id, kind, result, amount, currency) VALUES ($1,$2,'renewal','ok',$3,'EUR')", [userId, product.id, product.price]);
  } else if (s.status !== 'expired' && s.status !== 'none') {
    await tx.query("UPDATE subscriptions SET status = 'expired', expiry_notice_pending = true, updated_at = now() WHERE user_id = $1", [userId]);
  }
}

export async function computeEntitlements(tx: Tx, userId: string): Promise<Entitlements> {
  await renewIfDue(tx, userId);
  const now = new Date();
  const sub = (await tx.query('SELECT * FROM subscriptions WHERE user_id = $1', [userId])).rows[0];
  const grant = (await tx.query('SELECT * FROM premium_grants WHERE user_id = $1 AND ends_at > now() ORDER BY ends_at DESC LIMIT 1', [userId])).rows[0];
  const org = (await tx.query(
    `SELECT o.id, o.name, o.nominal, o.removes_ads, o.valid_to FROM org_memberships m JOIN organizations o ON o.id = m.org_id
     WHERE m.user_id = $1 AND m.left_at IS NULL AND o.valid_to >= current_date AND o.valid_from <= current_date LIMIT 1`, [userId])).rows[0];
  const base = { trialUsed: Boolean(sub?.trial_used), trialEndsAt: sub?.trial_ends_at ? new Date(sub.trial_ends_at).toISOString() : null, validatedAt: now.toISOString() };
  const storeActive = sub && sub.expires_at && new Date(sub.expires_at) > now && ['active', 'cancelled'].includes(sub.status);
  if (storeActive) {
    const inTrial = sub.trial_ends_at && new Date(sub.trial_ends_at) > now;
    return {
      ...base, premium: true, noAds: true, source: 'store', plan: inTrial ? 'trial' : sub.plan,
      status: sub.cancelled_at ? 'cancelled' : 'active', expiresAt: new Date(sub.expires_at).toISOString(),
      renewsAt: sub.cancelled_at ? null : new Date(sub.renews_at ?? sub.expires_at).toISOString(), organization: org ? { id: org.id, name: org.name, nominal: org.nominal } : null,
    };
  }
  if (org && org.removes_ads) {
    return { ...base, premium: true, noAds: true, source: 'organization', plan: 'organization', status: 'active', expiresAt: new Date(org.valid_to).toISOString(), renewsAt: null, organization: { id: org.id, name: org.name, nominal: org.nominal } };
  }
  if (grant) {
    return { ...base, premium: true, noAds: true, source: 'support_grant', plan: 'grant', status: 'active', expiresAt: new Date(grant.ends_at).toISOString(), renewsAt: null, organization: null };
  }
  return { ...base, premium: false, noAds: false, source: 'none', plan: null, status: sub?.status === 'expired' ? 'expired' : 'none', expiresAt: sub?.expires_at ? new Date(sub.expires_at).toISOString() : null, renewsAt: null, organization: org ? { id: org.id, name: org.name, nominal: org.nominal } : null };
}
