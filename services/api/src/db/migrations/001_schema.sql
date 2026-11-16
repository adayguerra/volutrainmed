-- VolutrainMed · esquema inicial (Postgres 16)
-- Tres ámbitos: contenido (back office, inmutable una vez publicado), usuarios y
-- organizaciones, y aprendizaje (nace en el dispositivo y se sincroniza).
-- Los permisos del back office se aplican también aquí: RLS con el rol de la
-- petición (app.actor_role), cuatro ojos por disparador y auditoría inalterable.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Rol de la aplicación: sin superusuario y sin BYPASSRLS, para que RLS se aplique.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vtm_app') THEN
    CREATE ROLE vtm_app LOGIN PASSWORD 'vtm_app_dev' NOSUPERUSER NOBYPASSRLS;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION vtm_role() RETURNS text LANGUAGE sql STABLE AS
$$ SELECT coalesce(nullif(current_setting('app.actor_role', true), ''), 'anonymous') $$;
CREATE OR REPLACE FUNCTION vtm_actor() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('app.actor_id', true), '')::uuid $$;
CREATE OR REPLACE FUNCTION vtm_user() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('app.user_id', true), '')::uuid $$;

-- ---------------------------------------------------------------------------
-- Usuarios de la app
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE,
  alias text NOT NULL,
  sector_id text,
  itinerary_id text,
  declared_level text,
  goal jsonb,
  disclaimer_accepted_at timestamptz,
  leagues_opt_in boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked','deleted')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  last_seen_at timestamptz
);

CREATE TABLE devices (
  id text PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  platform text, model text, app_version text, content_version text,
  rollout_bucket int NOT NULL,
  test_code text,
  last_sync_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE otp_codes (
  id bigserial PRIMARY KEY,
  email text NOT NULL,
  code_hash text NOT NULL,
  purpose text NOT NULL DEFAULT 'app_login',
  attempts int NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE dev_mailbox (
  id bigserial PRIMARY KEY, email text NOT NULL, subject text NOT NULL, body text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Aprendizaje: el intento es la fuente de verdad (solo se añade)
-- ---------------------------------------------------------------------------
CREATE TABLE attempts (
  id uuid PRIMARY KEY,
  seq bigserial UNIQUE,
  user_id uuid REFERENCES users(id),
  device_id text NOT NULL,
  session_id uuid NOT NULL,
  mode text NOT NULL,
  lesson_id text, template_id text, question_id text,
  variant_id text NOT NULL,
  skill_id text NOT NULL,
  exercise_type_id text NOT NULL,
  level int NOT NULL,
  attempt_number int NOT NULL,
  answer_value text, answer_unit text, answer_payload jsonb,
  verdict text NOT NULL,
  error_code text,
  critical boolean NOT NULL,
  hints_used int NOT NULL DEFAULT 0,
  response_ms int NOT NULL,
  target_ms int NOT NULL,
  input_mode text NOT NULL,
  voice_metrics jsonb,
  points int NOT NULL DEFAULT 0,
  content_version text NOT NULL,
  device_time timestamptz NOT NULL,
  server_time timestamptz NOT NULL DEFAULT now(),
  league_status text NOT NULL DEFAULT 'counted' CHECK (league_status IN ('counted','suspended','excluded'))
);
CREATE INDEX attempts_user_seq ON attempts(user_id, seq);
CREATE INDEX attempts_template ON attempts(template_id);
CREATE INDEX attempts_question ON attempts(question_id);

CREATE TABLE learning_sessions (
  id uuid PRIMARY KEY,
  seq bigserial UNIQUE,
  user_id uuid REFERENCES users(id),
  device_id text NOT NULL,
  record jsonb NOT NULL,
  mode text NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  server_time timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_user_seq ON learning_sessions(user_id, seq);

CREATE TABLE events (
  id uuid PRIMARY KEY,
  user_id uuid REFERENCES users(id),
  device_id text,
  name text NOT NULL,
  at timestamptz NOT NULL,
  props jsonb NOT NULL DEFAULT '{}',
  server_time timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX events_name ON events(name, at);

CREATE TABLE inquiries (
  id uuid PRIMARY KEY,
  reference text UNIQUE NOT NULL,
  user_id uuid REFERENCES users(id),
  device_id text,
  type text NOT NULL,
  message text NOT NULL,
  reply_email text,
  exercise jsonb,
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','in_review','answered')),
  assignee_id uuid,
  reply text,
  linked_item_id text,
  is_patient_query boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL,
  answered_at timestamptz
);

CREATE TABLE export_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  status text NOT NULL DEFAULT 'pending',
  file jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  ready_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Suscripción
-- ---------------------------------------------------------------------------
CREATE TABLE subscriptions (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  plan text, source text NOT NULL DEFAULT 'store',
  status text NOT NULL DEFAULT 'none',
  started_at timestamptz, renews_at timestamptz, expires_at timestamptz,
  trial_used boolean NOT NULL DEFAULT false, trial_ends_at timestamptz,
  cancelled_at timestamptz, external_id text,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE store_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id),
  product_id text, kind text NOT NULL, result text NOT NULL,
  attributed_ad_id text, amount text, currency text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE premium_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  days int NOT NULL, reason text NOT NULL, granted_by uuid NOT NULL,
  starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz NOT NULL
);

-- ---------------------------------------------------------------------------
-- Back office: cuentas
-- ---------------------------------------------------------------------------
CREATE TABLE bo_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  name text NOT NULL,
  role text NOT NULL CHECK (role IN ('superadmin','content_admin','author','reviewer','org_admin','analyst','support')),
  sectors text[] NOT NULL DEFAULT '{}',
  accreditation text,
  org_id uuid,
  password_hash text NOT NULL,
  totp_secret text,
  totp_enabled boolean NOT NULL DEFAULT false,
  recovery_codes text[] NOT NULL DEFAULT '{}',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE bo_challenges (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id uuid NOT NULL REFERENCES bo_accounts(id),
  pending_secret text,
  expires_at timestamptz NOT NULL,
  used boolean NOT NULL DEFAULT false
);

-- ---------------------------------------------------------------------------
-- Contenido versionado con ciclo de revisión
-- Tipos: sector, itinerary, unit, lesson, template, question, exercise_type,
-- catalog_unit, catalog_instrument, voice_lexicon, ad_creative, ad_campaign,
-- achievement.
-- ---------------------------------------------------------------------------
CREATE TABLE content_items (
  id text NOT NULL,
  version int NOT NULL,
  kind text NOT NULL,
  state text NOT NULL DEFAULT 'draft' CHECK (state IN ('draft','in_review','changes_requested','validated','published','retired','superseded')),
  sector_id text,
  parent_id text,
  ord int NOT NULL DEFAULT 0,
  title text NOT NULL,
  data jsonb NOT NULL,
  author_id uuid REFERENCES bo_accounts(id),
  fingerprint text NOT NULL,
  validations int NOT NULL DEFAULT 0,
  validated_until timestamptz,
  drug_info_changed boolean NOT NULL DEFAULT false,
  linked_inquiry uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (id, version)
);
CREATE INDEX content_items_kind ON content_items(kind, state);

CREATE TABLE reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id text NOT NULL,
  item_version int NOT NULL,
  reviewer_id uuid NOT NULL REFERENCES bo_accounts(id),
  decision text NOT NULL CHECK (decision IN ('validate','request_changes','reject')),
  checklist jsonb NOT NULL DEFAULT '{}',
  comment text,
  accreditation text,
  fingerprint text NOT NULL,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (item_id, item_version) REFERENCES content_items(id, version)
);
CREATE TABLE review_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id text NOT NULL, item_version int NOT NULL,
  author_id uuid NOT NULL REFERENCES bo_accounts(id),
  anchor text, body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE releases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  number text UNIQUE NOT NULL,
  state text NOT NULL DEFAULT 'preparing' CHECK (state IN ('preparing','testing','published','rolled_back','superseded')),
  notes text,
  rollout_pct int NOT NULL DEFAULT 0,
  min_app_version text NOT NULL DEFAULT '1.0.0',
  items jsonb NOT NULL DEFAULT '[]',
  diff jsonb,
  checks jsonb,
  test_code text,
  created_by uuid REFERENCES bo_accounts(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  rolled_back_reason text
);
CREATE TABLE packages (
  id text PRIMARY KEY,
  release_id uuid NOT NULL REFERENCES releases(id),
  itinerary_id text NOT NULL,
  version text NOT NULL,
  sha256 text NOT NULL,
  signature text NOT NULL,
  size int NOT NULL,
  min_app_version text NOT NULL,
  bytes bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE revocations (
  id bigserial PRIMARY KEY,
  kind text NOT NULL CHECK (kind IN ('template','question','variant')),
  item_id text NOT NULL,
  reason text NOT NULL,
  created_by uuid REFERENCES bo_accounts(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  effective_from timestamptz,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Organizaciones y ligas
-- ---------------------------------------------------------------------------
CREATE TABLE organizations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL, type text NOT NULL DEFAULT 'universidad',
  seats int NOT NULL, valid_from date NOT NULL, valid_to date NOT NULL,
  nominal boolean NOT NULL DEFAULT false,
  removes_ads boolean NOT NULL DEFAULT true,
  invite_code text UNIQUE NOT NULL,
  domains text[] NOT NULL DEFAULT '{}',
  seats_alert_sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE org_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES organizations(id),
  name text NOT NULL, invite_code text UNIQUE NOT NULL,
  itineraries text[] NOT NULL DEFAULT '{}'
);
CREATE TABLE org_memberships (
  user_id uuid NOT NULL REFERENCES users(id),
  org_id uuid NOT NULL REFERENCES organizations(id),
  group_id uuid REFERENCES org_groups(id),
  role text NOT NULL DEFAULT 'member',
  accepted_nominal boolean NOT NULL DEFAULT false,
  joined_at timestamptz NOT NULL DEFAULT now(),
  left_at timestamptz,
  PRIMARY KEY (user_id, org_id)
);
CREATE TABLE org_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES organizations(id),
  group_id uuid REFERENCES org_groups(id),
  email text NOT NULL, status text NOT NULL DEFAULT 'sent',
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE private_leagues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES organizations(id),
  group_id uuid REFERENCES org_groups(id),
  name text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE league_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start date NOT NULL,
  division int NOT NULL,
  sector_id text,
  private_league_id uuid REFERENCES private_leagues(id),
  config jsonb NOT NULL,
  closed boolean NOT NULL DEFAULT false
);
CREATE TABLE league_members (
  group_id uuid NOT NULL REFERENCES league_groups(id),
  user_id uuid NOT NULL REFERENCES users(id),
  alias text NOT NULL,
  points int NOT NULL DEFAULT 0,
  result text,
  PRIMARY KEY (group_id, user_id)
);
CREATE TABLE league_divisions (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  division int NOT NULL DEFAULT 0
);
CREATE TABLE league_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  week_start date NOT NULL,
  reason text NOT NULL,
  attempt_ids uuid[] NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','cleared','confirmed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_by uuid, resolved_at timestamptz
);
CREATE TABLE achievements_awarded (
  user_id uuid NOT NULL REFERENCES users(id),
  achievement_id text NOT NULL,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);

-- ---------------------------------------------------------------------------
-- Registro de auditoría inalterable
-- ---------------------------------------------------------------------------
CREATE TABLE audit_log (
  id bigserial PRIMARY KEY,
  actor_id uuid,
  actor_role text NOT NULL,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id text,
  before jsonb,
  after jsonb,
  reason text,
  at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION audit_log_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'El registro de auditoría es inalterable' USING ERRCODE = 'insufficient_privilege';
END $$;
CREATE TRIGGER audit_no_update BEFORE UPDATE OR DELETE ON audit_log FOR EACH ROW EXECUTE FUNCTION audit_log_immutable();
CREATE TRIGGER audit_no_truncate BEFORE TRUNCATE ON audit_log FOR EACH STATEMENT EXECUTE FUNCTION audit_log_immutable();

-- ---------------------------------------------------------------------------
-- Disparadores de reglas del back office
-- ---------------------------------------------------------------------------

-- Cuatro ojos: nadie valida contenido propio; solo revisores acreditados en el sector.
CREATE OR REPLACE FUNCTION reviews_four_eyes() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE item content_items; acc bo_accounts;
BEGIN
  SELECT * INTO item FROM content_items WHERE id = NEW.item_id AND version = NEW.item_version;
  SELECT * INTO acc FROM bo_accounts WHERE id = NEW.reviewer_id;
  IF NEW.decision = 'validate' THEN
    IF item.author_id = NEW.reviewer_id THEN
      RAISE EXCEPTION 'Nadie valida contenido propio' USING ERRCODE = 'check_violation';
    END IF;
    IF acc.role <> 'reviewer' THEN
      RAISE EXCEPTION 'Validar es exclusivo del revisor experto' USING ERRCODE = 'check_violation';
    END IF;
    IF item.sector_id IS NOT NULL AND item.sector_id <> 'comun' AND NOT (item.sector_id = ANY (acc.sectors)) THEN
      RAISE EXCEPTION 'El revisor no está acreditado en el sector %', item.sector_id USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER reviews_four_eyes_trg BEFORE INSERT ON reviews FOR EACH ROW EXECUTE FUNCTION reviews_four_eyes();

-- Quien no edita contenido no puede cambiar sus datos; un autor no valida ni publica.
CREATE OR REPLACE FUNCTION content_items_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r text := vtm_role();
BEGIN
  IF r IN ('reviewer','analyst','support','org_admin') AND NEW.data IS DISTINCT FROM OLD.data THEN
    RAISE EXCEPTION 'El rol % no puede modificar el contenido', r USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF r = 'author' AND NEW.state IN ('validated','published') AND NEW.state IS DISTINCT FROM OLD.state THEN
    RAISE EXCEPTION 'Un autor no valida ni publica' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.state = 'published' AND NEW.data IS DISTINCT FROM OLD.data THEN
    RAISE EXCEPTION 'El contenido publicado es inmutable: crea una versión nueva' USING ERRCODE = 'check_violation';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $$;
CREATE TRIGGER content_items_guard_trg BEFORE UPDATE ON content_items FOR EACH ROW EXECUTE FUNCTION content_items_guard();

-- Nada se borra: el contenido se retira y se archiva.
CREATE OR REPLACE FUNCTION no_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Nada se borra: se retira y se archiva' USING ERRCODE = 'insufficient_privilege'; END $$;
CREATE TRIGGER content_items_no_delete BEFORE DELETE ON content_items FOR EACH ROW EXECUTE FUNCTION no_delete();
CREATE TRIGGER reviews_no_delete BEFORE DELETE ON reviews FOR EACH ROW EXECUTE FUNCTION no_delete();
CREATE TRIGGER releases_no_delete BEFORE DELETE ON releases FOR EACH ROW EXECUTE FUNCTION no_delete();

-- ---------------------------------------------------------------------------
-- RLS: permisos por rol aplicados en la base de datos
-- ---------------------------------------------------------------------------
ALTER TABLE content_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE revocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_sessions ENABLE ROW LEVEL SECURITY;

-- Contenido: lectura para los roles de contenido y el sistema (la app lee paquetes, no esta tabla).
CREATE POLICY ci_select ON content_items FOR SELECT USING (vtm_role() IN ('system','superadmin','content_admin','author','reviewer','analyst','support'));
CREATE POLICY ci_insert ON content_items FOR INSERT WITH CHECK (vtm_role() IN ('system','superadmin','content_admin','author'));
CREATE POLICY ci_update ON content_items FOR UPDATE USING (
  vtm_role() IN ('system','superadmin','content_admin','reviewer')
  OR (vtm_role() = 'author' AND author_id = vtm_actor())
);

CREATE POLICY rv_select ON reviews FOR SELECT USING (vtm_role() IN ('system','superadmin','content_admin','author','reviewer','analyst'));
CREATE POLICY rv_insert ON reviews FOR INSERT WITH CHECK (vtm_role() IN ('system','reviewer') AND (vtm_role() = 'system' OR reviewer_id = vtm_actor()));

-- Publicación: soporte, analistas y organizaciones no tienen acceso.
CREATE POLICY rel_select ON releases FOR SELECT USING (vtm_role() IN ('system','superadmin','content_admin','public'));
CREATE POLICY rel_write ON releases FOR ALL USING (vtm_role() IN ('system','superadmin','content_admin')) WITH CHECK (vtm_role() IN ('system','superadmin','content_admin'));
CREATE POLICY pkg_select ON packages FOR SELECT USING (true);
CREATE POLICY pkg_write ON packages FOR INSERT WITH CHECK (vtm_role() IN ('system','superadmin','content_admin'));
CREATE POLICY revo_select ON revocations FOR SELECT USING (true);
CREATE POLICY revo_write ON revocations FOR ALL USING (vtm_role() IN ('system','superadmin','content_admin')) WITH CHECK (vtm_role() IN ('system','superadmin','content_admin'));

-- Auditoría: todos insertan; solo superadministración y administración de contenido consultan.
CREATE POLICY au_insert ON audit_log FOR INSERT WITH CHECK (true);
CREATE POLICY au_select ON audit_log FOR SELECT USING (vtm_role() IN ('system','superadmin','content_admin'));

-- Aprendizaje: cada usuario ve y añade lo suyo; el sistema y la analítica, todo.
CREATE POLICY at_user ON attempts FOR ALL USING (vtm_role() IN ('system','superadmin','content_admin','analyst','support','author','reviewer') OR user_id = vtm_user())
  WITH CHECK (vtm_role() = 'system' OR user_id = vtm_user());
CREATE POLICY ls_user ON learning_sessions FOR ALL USING (vtm_role() IN ('system','superadmin','analyst','support') OR user_id = vtm_user())
  WITH CHECK (vtm_role() = 'system' OR user_id = vtm_user());

GRANT USAGE ON SCHEMA public TO vtm_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO vtm_app;
GRANT DELETE ON otp_codes, bo_challenges, org_memberships TO vtm_app;
REVOKE UPDATE, DELETE, TRUNCATE ON audit_log FROM vtm_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO vtm_app;
