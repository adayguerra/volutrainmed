/**
 * Tienda de pruebas (premium-subscription). Simula la tienda y la validación de
 * recibos del proveedor de suscripciones; en producción se sustituye por la
 * integración con RevenueCat y las tiendas.
 */
import type { FastifyInstance } from 'fastify';
import { withTx, SYSTEM } from '../db/pool.js';
import { ApiError, bad, notFound } from '../lib/errors.js';
import { requireUser } from '../server.js';
import { PRODUCTS, addPeriod, computeEntitlements } from '../services/entitlements.js';

const DEV = process.env.NODE_ENV !== 'production';

export async function storeRoutes(app: FastifyInstance) {
  app.get('/v1/store/products', async () => ({ products: PRODUCTS, fetchedAt: new Date().toISOString() }));

  app.post<{ Body: { productId: string; withTrial?: boolean; receipt?: string; simulate?: 'ok' | 'cancel' | 'fail'; attributedAdId?: string } }>('/v1/store/purchase', async (req) => {
    const u = requireUser(req);
    const b = req.body ?? ({} as never);
    const product = PRODUCTS.find((p) => p.id === b.productId);
    if (!product) throw bad('unknown_product', 'Producto desconocido');
    return withTx(SYSTEM, async (tx) => {
      if (b.simulate === 'cancel') {
        await tx.query("INSERT INTO store_transactions(user_id, product_id, kind, result, attributed_ad_id) VALUES ($1,$2,'purchase','cancelled',$3)", [u.userId, product.id, b.attributedAdId ?? null]);
        throw new ApiError(409, 'purchase_cancelled', 'Compra cancelada');
      }
      if (b.simulate === 'fail') {
        await tx.query("INSERT INTO store_transactions(user_id, product_id, kind, result, attributed_ad_id) VALUES ($1,$2,'purchase','failed',$3)", [u.userId, product.id, b.attributedAdId ?? null]);
        throw new ApiError(402, 'payment_failed', 'La tienda no ha podido completar el pago');
      }
      const sub = (await tx.query('SELECT * FROM subscriptions WHERE user_id = $1', [u.userId])).rows[0];
      const now = new Date();
      const trial = Boolean(b.withTrial) && !sub?.trial_used;
      const trialEnds = new Date(now.getTime() + product.trialDays * 86400_000);
      const expires = trial ? trialEnds : addPeriod(now, product.period);
      await tx.query(
        `INSERT INTO subscriptions(user_id, plan, source, status, started_at, renews_at, expires_at, trial_used, trial_ends_at, cancelled_at, auto_renew, external_id, expiry_notice_pending, updated_at)
         VALUES ($1,$2,'store','active',$3,$4,$4,$5,$6,NULL,true,$7,false, now())
         ON CONFLICT (user_id) DO UPDATE SET plan = EXCLUDED.plan, source = 'store', status = 'active', started_at = EXCLUDED.started_at, renews_at = EXCLUDED.renews_at,
           expires_at = EXCLUDED.expires_at, trial_used = subscriptions.trial_used OR EXCLUDED.trial_used, trial_ends_at = coalesce(EXCLUDED.trial_ends_at, subscriptions.trial_ends_at),
           cancelled_at = NULL, auto_renew = true, external_id = EXCLUDED.external_id, expiry_notice_pending = false, updated_at = now()`,
        [u.userId, product.plan, now, expires, trial, trial ? trialEnds : null, `sandbox-${Date.now()}`],
      );
      await tx.query(
        "INSERT INTO store_transactions(user_id, product_id, kind, result, attributed_ad_id, amount, currency) VALUES ($1,$2,$3,'ok',$4,$5,'EUR')",
        [u.userId, product.id, trial ? 'trial_start' : 'purchase', b.attributedAdId ?? null, trial ? '0' : product.price],
      );
      return { entitlements: await computeEntitlements(tx, u.userId), firstChargeAt: trial ? trialEnds.toISOString() : now.toISOString(), firstChargeAmount: product.price };
    });
  });

  app.post('/v1/store/restore', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      await tx.query("INSERT INTO store_transactions(user_id, kind, result) VALUES ($1, 'restore', 'ok')", [u.userId]);
      return { entitlements: await computeEntitlements(tx, u.userId) };
    });
  });

  app.post('/v1/store/cancel', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      await tx.query('UPDATE subscriptions SET cancelled_at = now(), auto_renew = false, updated_at = now() WHERE user_id = $1', [u.userId]);
      await tx.query("INSERT INTO store_transactions(user_id, kind, result) VALUES ($1, 'cancel', 'ok')", [u.userId]);
      return { entitlements: await computeEntitlements(tx, u.userId) };
    });
  });

  app.get('/v1/entitlements', async (req) => {
    const u = requireUser(req);
    return withTx(SYSTEM, (tx) => computeEntitlements(tx, u.userId));
  });

  /** Solo desarrollo: adelanta el vencimiento para probar la caducidad. */
  app.post<{ Body: { daysAgo?: number } }>('/v1/dev/subscription/expire', async (req) => {
    if (!DEV) throw notFound();
    const u = requireUser(req);
    return withTx(SYSTEM, async (tx) => {
      const d = new Date(Date.now() - (req.body?.daysAgo ?? 1) * 86400_000);
      await tx.query('UPDATE subscriptions SET expires_at = $2::timestamptz, renews_at = $2::timestamptz, trial_ends_at = CASE WHEN trial_ends_at IS NOT NULL THEN $2::timestamptz ELSE NULL END WHERE user_id = $1', [u.userId, d]);
      return { entitlements: await computeEntitlements(tx, u.userId) };
    });
  });
}
