/** Back office: usuarios, consultas y organizaciones. */
import type { FastifyInstance } from 'fastify';
import { withTx } from '../db/pool.js';
import { bad, forbidden, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { shortCode } from '../lib/crypto.js';
import { requireBo, boActor, type BoCtx } from '../server.js';
import { computeEntitlements } from '../services/entitlements.js';
import { createItem, latest } from '../services/items.js';
import { deleteUserData, toProfile } from './app.js';
import { withdraw } from './admin-releases.js';
import { seatsUsed } from './growth-app.js';

export const MODEL_REPLIES: Record<string, string> = {
  patient: 'Gracias por escribirnos. VolutrainMed es un entrenador formativo con casos simulados: no respondemos consultas sobre pacientes ni tratamientos. Para un caso real, consulta a los profesionales y protocolos de tu centro.',
  fixed: 'Gracias por avisarnos. Hemos revisado el ejercicio y lo hemos corregido; la corrección llegará con la próxima actualización de contenido.',
  explanation: 'Gracias por tu pregunta. Hemos revisado la explicación y te detallamos el razonamiento paso a paso.',
  received: 'Gracias por tu mensaje. Lo estamos revisando y te responderemos lo antes posible.',
};

function canSeeOrg(bo: BoCtx, orgId: string) {
  if (bo.role === 'superadmin' || bo.role === 'support') return true;
  return bo.role === 'org_admin' && bo.orgId === orgId;
}

export async function adminPeopleRoutes(app: FastifyInstance) {
  // ------------------------------------------------------------------ Usuarios
  app.get<{ Querystring: { q?: string; plan?: string; sector?: string; org?: string } }>('/v1/admin/users', async (req) => {
    const bo = requireBo(req, ['superadmin', 'support', 'org_admin']);
    return withTx(boActor(bo), async (tx) => {
      const q = `%${(req.query.q ?? '').toLowerCase()}%`;
      const rows = (await tx.query(
        `SELECT u.*, s.plan, s.status AS sub_status, s.expires_at, m.org_id, o.name AS org_name,
           (SELECT max(server_time) FROM attempts a WHERE a.user_id = u.id) AS last_activity
         FROM users u LEFT JOIN subscriptions s ON s.user_id = u.id
         LEFT JOIN org_memberships m ON m.user_id = u.id AND m.left_at IS NULL LEFT JOIN organizations o ON o.id = m.org_id
         WHERE (lower(coalesce(u.email,'')) LIKE $1 OR lower(u.alias) LIKE $1) AND ($2::text IS NULL OR u.sector_id = $2) AND ($3::uuid IS NULL OR m.org_id = $3)
         ORDER BY u.created_at DESC LIMIT 200`,
        [q, req.query.sector || null, bo.role === 'org_admin' ? bo.orgId : (req.query.org || null)],
      )).rows;
      const items = [];
      for (const r of rows) {
        const ent = await computeEntitlements(tx, r.id);
        if (req.query.plan === 'premium' && !ent.premium) continue;
        if (req.query.plan === 'free' && ent.premium) continue;
        items.push({ ...toProfile(r), status: r.status, plan: ent.premium ? (ent.plan ?? 'premium') : 'gratuito', organization: r.org_name, lastActivity: r.last_activity });
      }
      return { items };
    });
  });

  app.get<{ Params: { id: string } }>('/v1/admin/users/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'support', 'org_admin']);
    return withTx(boActor(bo), async (tx) => {
      const u = (await tx.query('SELECT * FROM users WHERE id = $1', [req.params.id])).rows[0];
      if (!u) throw notFound();
      const membership = (await tx.query('SELECT m.*, o.name, o.nominal FROM org_memberships m JOIN organizations o ON o.id = m.org_id WHERE m.user_id = $1 AND m.left_at IS NULL', [u.id])).rows[0];
      if (bo.role === 'org_admin') {
        if (!membership || membership.org_id !== bo.orgId) throw forbidden();
        if (!membership.nominal || !membership.accepted_nominal) throw forbidden('La organización solo ve datos agregados salvo con el modo nominal aceptado por el usuario');
      }
      const devices = (await tx.query('SELECT id, platform, model, app_version, content_version, last_sync_at FROM devices WHERE user_id = $1', [u.id])).rows;
      const progress = (await tx.query(
        `SELECT count(*)::int AS attempts, count(*) FILTER (WHERE attempt_number = 1 AND verdict IN ('correct','correct_note'))::int AS first_ok,
           count(*) FILTER (WHERE attempt_number = 1)::int AS first_total, count(DISTINCT date_trunc('day', device_time))::int AS active_days,
           count(*) FILTER (WHERE critical)::int AS critical FROM attempts WHERE user_id = $1`, [u.id])).rows[0];
      const sessions = (await tx.query("SELECT count(*) FILTER (WHERE mode = 'lesson' AND (record->>'completed')::boolean)::int AS lessons FROM learning_sessions WHERE user_id = $1", [u.id])).rows[0];
      const inquiries = (await tx.query('SELECT id, reference, type, status, created_at FROM inquiries WHERE user_id = $1 ORDER BY created_at DESC', [u.id])).rows;
      const grants = (await tx.query('SELECT days, reason, starts_at, ends_at FROM premium_grants WHERE user_id = $1 ORDER BY starts_at DESC', [u.id])).rows;
      return {
        user: { ...toProfile(u), status: u.status }, entitlements: await computeEntitlements(tx, u.id), devices, inquiries, grants,
        progress: { ...progress, lessonsCompleted: sessions.lessons, accuracy: progress.first_total ? Math.round((progress.first_ok / progress.first_total) * 100) : null },
        organization: membership ? { id: membership.org_id, name: membership.name, nominal: membership.nominal } : null,
      };
    });
  });

  app.post<{ Params: { id: string }; Body: { action: 'grant_premium' | 'reset_access' | 'block' | 'unblock' | 'export' | 'delete'; days?: number; reason: string } }>('/v1/admin/users/:id/actions', async (req) => {
    const bo = requireBo(req, ['superadmin', 'support']);
    const b = req.body;
    if (!b?.reason?.trim()) throw bad('reason_required', 'Las acciones de soporte exigen un motivo');
    return withTx(boActor(bo), async (tx) => {
      const u = (await tx.query('SELECT * FROM users WHERE id = $1', [req.params.id])).rows[0];
      if (!u) throw notFound();
      let result: unknown = { ok: true };
      if (b.action === 'grant_premium') {
        const days = Math.max(1, Math.min(Number(b.days ?? 7), 365));
        await tx.query("INSERT INTO premium_grants(user_id, days, reason, granted_by, ends_at) VALUES ($1,$2,$3,$4, now() + make_interval(days => $2::int))", [u.id, days, b.reason, bo.accountId]);
        result = { entitlements: await computeEntitlements(tx, u.id) };
      } else if (b.action === 'reset_access') {
        await tx.query('UPDATE otp_codes SET used_at = now() WHERE email = $1 AND used_at IS NULL', [u.email]);
      } else if (b.action === 'block' || b.action === 'unblock') {
        await tx.query('UPDATE users SET status = $2 WHERE id = $1', [u.id, b.action === 'block' ? 'blocked' : 'active']);
      } else if (b.action === 'export') {
        const r = await tx.query("INSERT INTO export_requests(user_id, status, file, ready_at) VALUES ($1, 'ready', $2, now()) RETURNING id", [u.id, JSON.stringify({
          profile: toProfile(u), attempts: (await tx.query('SELECT * FROM attempts WHERE user_id = $1 ORDER BY seq', [u.id])).rows,
          sessions: (await tx.query('SELECT record FROM learning_sessions WHERE user_id = $1', [u.id])).rows.map((x) => x.record),
        })]);
        result = { exportId: r.rows[0].id };
      } else if (b.action === 'delete') {
        await deleteUserData(tx, u.id, bo.accountId, bo.role, b.reason);
      } else throw bad('invalid_action', 'Acción no válida');
      if (b.action !== 'delete') await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: `user.${b.action}`, entity: 'user', entityId: u.id, after: { days: b.days ?? null }, reason: b.reason });
      return result;
    });
  });

  // ------------------------------------------------------------------ Consultas
  app.get<{ Querystring: { status?: string; type?: string } }>('/v1/admin/inquiries', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'support', 'author', 'reviewer']);
    return withTx(boActor(bo), async (tx) => ({
      items: (await tx.query(
        `SELECT i.*, a.name AS assignee_name FROM inquiries i LEFT JOIN bo_accounts a ON a.id = i.assignee_id
         WHERE ($1::text IS NULL OR i.status = $1) AND ($2::text IS NULL OR i.type = $2) AND ($3::uuid IS NULL OR i.assignee_id = $3)
         ORDER BY i.created_at DESC`,
        [req.query.status || null, req.query.type || null, ['author', 'reviewer'].includes(bo.role) ? bo.accountId : null],
      )).rows,
      models: MODEL_REPLIES,
    }));
  });

  app.get<{ Params: { id: string } }>('/v1/admin/inquiries/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'support', 'author', 'reviewer']);
    return withTx(boActor(bo), async (tx) => {
      const i = (await tx.query('SELECT * FROM inquiries WHERE id = $1', [req.params.id])).rows[0];
      if (!i) throw notFound();
      let variant: unknown = null;
      const ex = i.exercise as { variantId?: string; templateId?: string; questionId?: string } | null;
      if (ex?.variantId) {
        // Variante exacta que vio el usuario, buscada en los paquetes publicados.
        const pkgs = (await tx.query("SELECT bytes FROM packages WHERE itinerary_id <> '__global__' ORDER BY created_at DESC LIMIT 10")).rows;
        const { gunzipSync } = await import('node:zlib');
        for (const p of pkgs) {
          const pkg = JSON.parse(gunzipSync(p.bytes as Buffer).toString('utf8'));
          const v = (pkg.variants as { id: string }[]).find((x) => x.id === ex.variantId);
          if (v) { variant = v; break; }
        }
      }
      if (i.status === 'received') await tx.query("UPDATE inquiries SET status = 'in_review', assignee_id = coalesce(assignee_id, $2) WHERE id = $1", [i.id, bo.accountId]);
      return { inquiry: i, variant, models: MODEL_REPLIES, suggestedModel: i.is_patient_query ? 'patient' : null };
    });
  });

  app.post<{ Params: { id: string }; Body: { text?: string; template?: string } }>('/v1/admin/inquiries/:id/reply', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin', 'support', 'author', 'reviewer']);
    const text = req.body?.text?.trim() || (req.body?.template ? MODEL_REPLIES[req.body.template] : '');
    if (!text) throw bad('empty', 'Escribe la respuesta o elige una respuesta modelo');
    return withTx(boActor(bo), async (tx) => {
      await tx.query("UPDATE inquiries SET reply = $2, status = 'answered', answered_at = now(), assignee_id = coalesce(assignee_id, $3) WHERE id = $1", [req.params.id, text, bo.accountId]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'inquiry.reply', entity: 'inquiry', entityId: req.params.id, after: { template: req.body?.template ?? null } });
      return { ok: true };
    });
  });

  app.post<{ Params: { id: string } }>('/v1/admin/inquiries/:id/convert', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const i = (await tx.query('SELECT * FROM inquiries WHERE id = $1', [req.params.id])).rows[0];
      if (!i) throw notFound();
      const ex = i.exercise as { templateId?: string; questionId?: string } | null;
      const itemId = ex?.templateId ?? ex?.questionId;
      if (!itemId) throw bad('no_exercise', 'La consulta no tiene un ejercicio asociado');
      const cur = await latest(tx, itemId);
      // Borrador de corrección enlazado con la consulta.
      const draft = (await tx.query(
        `INSERT INTO content_items(id, version, kind, state, sector_id, parent_id, ord, title, data, author_id, fingerprint, linked_inquiry)
         SELECT id, version + 1, kind, 'draft', sector_id, parent_id, ord, title, data, $2, fingerprint, $3 FROM content_items WHERE id = $1 AND version = $4 RETURNING *`,
        [cur.id, bo.accountId, i.id, cur.version],
      )).rows[0];
      await tx.query("UPDATE inquiries SET status = 'in_review', linked_item_id = $2 WHERE id = $1", [i.id, cur.id]);
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'inquiry.convert_to_fix', entity: cur.kind, entityId: cur.id, after: { inquiry: i.reference, version: draft.version } });
      return { itemId: cur.id, version: draft.version };
    });
  });

  app.post<{ Params: { id: string }; Body: { reason?: string } }>('/v1/admin/inquiries/:id/withdraw-exercise', async (req) => {
    const bo = requireBo(req, ['superadmin', 'content_admin']);
    return withTx(boActor(bo), async (tx) => {
      const i = (await tx.query('SELECT * FROM inquiries WHERE id = $1', [req.params.id])).rows[0];
      if (!i) throw notFound();
      const ex = i.exercise as { templateId?: string; questionId?: string } | null;
      const kind = ex?.templateId ? 'template' : 'question';
      const itemId = ex?.templateId ?? ex?.questionId;
      if (!itemId) throw bad('no_exercise', 'La consulta no tiene un ejercicio asociado');
      return withdraw(tx, bo, kind, itemId, req.body?.reason ?? `Retirado desde la consulta ${i.reference}`, i.id);
    });
  });

  // ------------------------------------------------------------------ Organizaciones
  app.get('/v1/admin/orgs', async (req) => {
    const bo = requireBo(req, ['superadmin', 'support', 'org_admin']);
    return withTx(boActor(bo), async (tx) => {
      const rows = (await tx.query('SELECT * FROM organizations WHERE ($1::uuid IS NULL OR id = $1) ORDER BY created_at DESC', [bo.role === 'org_admin' ? bo.orgId : null])).rows;
      const out = [];
      for (const o of rows) out.push({ ...o, seatsUsed: await seatsUsed(tx, o.id), invitesPending: Number((await tx.query("SELECT count(*) AS c FROM org_invites WHERE org_id = $1 AND status = 'sent'", [o.id])).rows[0].c) });
      return { items: out };
    });
  });

  app.post<{ Body: { name: string; type?: string; seats: number; validFrom: string; validTo: string; nominal?: boolean; domains?: string[]; removesAds?: boolean } }>('/v1/admin/orgs', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    const b = req.body;
    if (!b?.name || !(b.seats > 0) || !b.validFrom || !b.validTo) throw bad('invalid', 'Nombre, plazas y vigencia son obligatorios');
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query(
        'INSERT INTO organizations(name, type, seats, valid_from, valid_to, nominal, invite_code, domains, removes_ads) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *',
        [b.name, b.type ?? 'universidad', b.seats, b.validFrom, b.validTo, Boolean(b.nominal), shortCode(8), (b.domains ?? []).map((d) => d.toLowerCase().replace(/^@/, '')), b.removesAds ?? true],
      )).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.create', entity: 'organization', entityId: r.id, after: r });
      return { organization: r };
    });
  });

  app.get<{ Params: { id: string } }>('/v1/admin/orgs/:id', async (req) => {
    const bo = requireBo(req, ['superadmin', 'support', 'org_admin']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    return withTx(boActor(bo), async (tx) => {
      const o = (await tx.query('SELECT * FROM organizations WHERE id = $1', [req.params.id])).rows[0];
      if (!o) throw notFound();
      const groups = (await tx.query('SELECT g.*, (SELECT count(*)::int FROM org_memberships m WHERE m.group_id = g.id AND m.left_at IS NULL) AS members FROM org_groups g WHERE org_id = $1', [o.id])).rows;
      const admins = (await tx.query("SELECT id, name, email FROM bo_accounts WHERE org_id = $1 AND role = 'org_admin'", [o.id])).rows;
      const invites = (await tx.query('SELECT * FROM org_invites WHERE org_id = $1 ORDER BY created_at DESC LIMIT 200', [o.id])).rows;
      const leagues = (await tx.query('SELECT * FROM private_leagues WHERE org_id = $1', [o.id])).rows;
      return { organization: { ...o, seatsUsed: await seatsUsed(tx, o.id) }, groups, admins, invites, privateLeagues: leagues };
    });
  });

  app.patch<{ Params: { id: string }; Body: { seats?: number; validTo?: string; nominal?: boolean; domains?: string[]; removesAds?: boolean } }>('/v1/admin/orgs/:id', async (req) => {
    const bo = requireBo(req, ['superadmin']);
    return withTx(boActor(bo), async (tx) => {
      const before = (await tx.query('SELECT * FROM organizations WHERE id = $1', [req.params.id])).rows[0];
      const r = (await tx.query(
        'UPDATE organizations SET seats = coalesce($2, seats), valid_to = coalesce($3, valid_to), nominal = coalesce($4, nominal), domains = coalesce($5, domains), removes_ads = coalesce($6, removes_ads) WHERE id = $1 RETURNING *',
        [req.params.id, req.body.seats ?? null, req.body.validTo ?? null, req.body.nominal ?? null, req.body.domains ?? null, req.body.removesAds ?? null],
      )).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.update', entity: 'organization', entityId: req.params.id, before, after: r });
      return { organization: r };
    });
  });

  app.post<{ Params: { id: string }; Body: { name: string; itineraries?: string[] } }>('/v1/admin/orgs/:id/groups', async (req) => {
    const bo = requireBo(req, ['superadmin', 'org_admin']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('INSERT INTO org_groups(org_id, name, invite_code, itineraries) VALUES ($1,$2,$3,$4) RETURNING *', [req.params.id, req.body.name, shortCode(8), req.body.itineraries ?? []])).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.group_create', entity: 'org_group', entityId: r.id, after: r });
      return { group: r };
    });
  });

  app.patch<{ Params: { id: string; groupId: string }; Body: { itineraries: string[] } }>('/v1/admin/orgs/:id/groups/:groupId', async (req) => {
    const bo = requireBo(req, ['superadmin', 'org_admin']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('UPDATE org_groups SET itineraries = $3 WHERE id = $2 AND org_id = $1 RETURNING *', [req.params.id, req.params.groupId, req.body.itineraries ?? []])).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.group_itineraries', entity: 'org_group', entityId: req.params.groupId, after: req.body });
      return { group: r };
    });
  });

  app.post<{ Params: { id: string }; Body: { emails: string[]; groupId?: string } }>('/v1/admin/orgs/:id/invites', async (req) => {
    const bo = requireBo(req, ['superadmin', 'org_admin']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    const emails = (req.body?.emails ?? []).map((e) => e.trim()).filter(Boolean);
    return withTx(boActor(bo), async (tx) => {
      const sent: string[] = []; const invalid: { row: number; value: string }[] = [];
      for (let i = 0; i < emails.length; i++) {
        const e = emails[i]!.toLowerCase();
        if (!/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/.test(e)) { invalid.push({ row: i + 1, value: emails[i]! }); continue; }
        await tx.query('INSERT INTO org_invites(org_id, group_id, email) VALUES ($1,$2,$3)', [req.params.id, req.body.groupId ?? null, e]);
        await tx.query('INSERT INTO dev_mailbox(email, subject, body) VALUES ($1, $2, $3)', [e, 'Invitación a VolutrainMed', 'Tu organización te invita a entrenar con VolutrainMed']);
        sent.push(e);
      }
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.invites_sent', entity: 'organization', entityId: req.params.id, after: { sent: sent.length, invalid: invalid.length } });
      return { sent: sent.length, invalid };
    });
  });

  /** Informe de grupo: agregado por defecto; sin datos si hay menos de 5 miembros activos. */
  app.get<{ Params: { id: string }; Querystring: { groupId?: string } }>('/v1/admin/orgs/:id/report', async (req) => {
    const bo = requireBo(req, ['superadmin', 'org_admin', 'support']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    return withTx(boActor(bo), async (tx) => {
      const org = (await tx.query('SELECT * FROM organizations WHERE id = $1', [req.params.id])).rows[0];
      if (!org) throw notFound();
      const members = (await tx.query(
        `SELECT m.user_id, m.accepted_nominal, u.alias, u.email FROM org_memberships m JOIN users u ON u.id = m.user_id
         WHERE m.org_id = $1 AND m.left_at IS NULL AND ($2::uuid IS NULL OR m.group_id = $2)`, [org.id, req.query.groupId || null])).rows;
      const ids = members.map((m) => m.user_id);
      const active = ids.length ? Number((await tx.query("SELECT count(DISTINCT user_id) AS c FROM attempts WHERE user_id = ANY($1) AND device_time > now() - interval '30 days'", [ids])).rows[0].c) : 0;
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.report_viewed', entity: 'organization', entityId: org.id });
      if (active < 5) return { insufficient: true, activeMembers: active, message: 'El grupo tiene menos de 5 miembros activos: no se muestran datos agregados para que no puedan atribuirse a personas concretas' };
      const agg = (await tx.query(
        `SELECT count(*) FILTER (WHERE attempt_number = 1 AND verdict IN ('correct','correct_note'))::float / nullif(count(*) FILTER (WHERE attempt_number = 1), 0) AS accuracy
         FROM attempts WHERE user_id = ANY($1)`, [ids])).rows[0];
      const lessons = (await tx.query("SELECT count(*)::int AS n FROM learning_sessions WHERE user_id = ANY($1) AND mode = 'lesson' AND (record->>'completed')::boolean", [ids])).rows[0].n;
      const skills = (await tx.query(
        `SELECT skill_id, count(*) FILTER (WHERE verdict IN ('correct','correct_note'))::float / count(*) AS acc FROM attempts WHERE user_id = ANY($1) AND attempt_number = 1 GROUP BY skill_id HAVING count(*) >= 20`, [ids])).rows;
      const report: Record<string, unknown> = {
        insufficient: false, activeMembers: active, members: members.length, completionLessons: lessons,
        accuracy: agg.accuracy === null ? null : Math.round(Number(agg.accuracy) * 1000) / 10,
        skillsMastered: skills.filter((s) => Number(s.acc) >= 0.95).map((s) => s.skill_id),
      };
      if (org.nominal) {
        report.individuals = [];
        for (const m of members.filter((x) => x.accepted_nominal)) {
          const a = (await tx.query("SELECT count(*) FILTER (WHERE attempt_number = 1 AND verdict IN ('correct','correct_note'))::float / nullif(count(*) FILTER (WHERE attempt_number = 1),0) AS acc FROM attempts WHERE user_id = $1", [m.user_id])).rows[0];
          (report.individuals as unknown[]).push({ alias: m.alias, email: m.email, accuracy: a.acc === null ? null : Math.round(Number(a.acc) * 1000) / 10 });
        }
      }
      return report;
    });
  });

  app.post<{ Params: { id: string }; Body: { name: string; groupId?: string } }>('/v1/admin/orgs/:id/private-leagues', async (req) => {
    const bo = requireBo(req, ['superadmin', 'org_admin']);
    if (!canSeeOrg(bo, req.params.id)) throw forbidden();
    return withTx(boActor(bo), async (tx) => {
      const r = (await tx.query('INSERT INTO private_leagues(org_id, group_id, name) VALUES ($1,$2,$3) RETURNING *', [req.params.id, req.body.groupId ?? null, req.body.name])).rows[0];
      await audit(tx, { actorId: bo.accountId, actorRole: bo.role, action: 'org.private_league_create', entity: 'private_league', entityId: r.id, after: r });
      return { league: r };
    });
  });

  void createItem;
}
