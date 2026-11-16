# API de VolutrainMed (v1)

Servidor: `services/api` (Node 22 + Fastify + Postgres). Base local: `http://localhost:8787`.
Tipos de los cuerpos: `packages/contracts/src/index.ts`. Todas las cifras viajan como cadenas decimales con punto.

## Convenciones

- JSON UTF-8. Fechas en ISO 8601 UTC.
- Errores: `{ "error": { "code": "snake_case", "message": "Texto para personas en español" } }` con el código HTTP adecuado (400, 401, 403, 404, 409, 422, 429).
- Autenticación de la app: `Authorization: Bearer <token>` (JWT HS256, 30 días). Sin token, la app funciona con perfil local y no llama a la API salvo contenido público.
- Autenticación del back office: `Authorization: Bearer <token>` obtenido tras contraseña + segundo factor (TOTP). Token de 12 h. Todo endpoint `/v1/admin/*` exige token con `mfa: true`.
- Cada acción de escritura del back office queda en el registro de auditoría (`audit_log`, inalterable por disparador en Postgres).
- Paginación: `?limit=50&cursor=<opaco>` → `{ items, nextCursor }`.
- Modo desarrollo (`NODE_ENV!=production`): `GET /v1/dev/mailbox?email=` devuelve los códigos de un solo uso enviados (no hay servidor de correo en local).

## App (usuarios finales)

| Método y ruta | Cuerpo / consulta | Respuesta |
| --- | --- | --- |
| `GET /v1/health` | — | `{ ok, time }` |
| `POST /v1/auth/otp/request` | `{ email }` | `204`. Envía un código de 6 cifras (10 min, 5 intentos) |
| `POST /v1/auth/otp/verify` | `{ email, code, deviceId, localProfile?: UserProfile }` | `{ token, user: UserProfile, isNew, merged }`. Si hay perfil local, lo fusiona (diseño D5: los intentos se suben después por sincronización) |
| `POST /v1/auth/apple` / `POST /v1/auth/google` | `{ idToken, deviceId, localProfile? }` | Igual que `otp/verify`. En desarrollo acepta `idToken = "dev:<email>"`; en producción valida con el proveedor (pendiente de credenciales) |
| `GET /v1/me` | — | `{ user: UserProfile, entitlements: Entitlements, organization }` |
| `PATCH /v1/me` | campos de `UserProfile` (alias, sectorId, itineraryId, declaredLevel, goal, leaguesOptIn, disclaimerAcceptedAt) | `{ user }` (gana la última escritura) |
| `POST /v1/me/export` | — | `202 { requestId, status: "pending" }` |
| `GET /v1/me/export/:id` | — | `{ status: "pending" \| "ready", file?: { profile, attempts, sessions, inquiries } }` |
| `DELETE /v1/me` | `{ confirmation: "ELIMINAR" }` | `204`. Suprime o anonimiza los datos personales; los intentos quedan anonimizados |
| `POST /v1/devices` | `{ deviceId, platform, model, appVersion, contentVersion }` | `{ rolloutBucket }` |

### Sincronización (offline-sync)

| Método y ruta | Cuerpo / consulta | Respuesta |
| --- | --- | --- |
| `POST /v1/sync/push` | `SyncPushRequest` (lotes de hasta 500 intentos) | `SyncPushResponse`. Idempotente por `id`: repetir un lote no duplica nada |
| `GET /v1/sync/pull?cursor=` | — | `SyncPullResponse` con todos los intentos y sesiones del usuario posteriores al cursor (dispositivo nuevo o fusión entre dispositivos) |
| `POST /v1/events` | `{ deviceId, events: AnalyticsEvent[] }` | `{ accepted }`. Sin cuenta se admite con `deviceId` seudónimo |

### Contenido (offline-sync, content-review-publishing)

| Método y ruta | Cuerpo / consulta | Respuesta |
| --- | --- | --- |
| `GET /v1/content/manifest?deviceId=&appVersion=&testCode=` | — | `ContentManifest`. El despliegue gradual usa `bucket = hash(deviceId) % 100 < rolloutPct`. `testCode` sirve el paquete de prueba del QR |
| `GET /v1/content/files/:packageId` | cabecera `Range` opcional | Bytes del paquete (gzip de JSON). Admite descarga reanudable (`206`) |
| `GET /v1/content/revocations` | — | `Revocations` (lista de retirada, independiente de las versiones) |
| `GET /v1/content/public-key` | — | `{ keyId, publicKey }` (Ed25519, base64 SPKI DER). La app lleva la clave fijada |
| `GET /v1/voice/pack` | — | `{ version, size, sha256, signature, url, files }` del paquete de voz (bajo demanda) |
| `GET /v1/voice/pack/file` | `Range` | Bytes del paquete de voz |

### Consultas (onboarding-account)

| Método y ruta | Cuerpo | Respuesta |
| --- | --- | --- |
| `POST /v1/inquiries` | `InquiryInput` (id creado en el dispositivo; idempotente) | `{ id, reference, status: "received" }` |
| `GET /v1/inquiries` | — | `{ items: [{ id, reference, type, message, status, reply, createdAt }] }` |

### Suscripción (premium-subscription)

La compra real pasa por la tienda y un proveedor de suscripciones (RevenueCat). En desarrollo, `services/api` incluye una **tienda de pruebas** que simula la tienda y la validación de recibos.

| Método y ruta | Cuerpo | Respuesta |
| --- | --- | --- |
| `GET /v1/store/products` | — | `{ products: StoreProduct[], fetchedAt }` (6,99 € al mes y 39,99 € al año, prueba de 7 días) |
| `POST /v1/store/purchase` | `{ productId, withTrial, receipt, simulate?: "ok" \| "cancel" \| "fail", attributedAdId? }` | `{ entitlements }` o `409 purchase_cancelled` / `402 payment_failed` |
| `POST /v1/store/restore` | — | `{ entitlements }` |
| `POST /v1/store/cancel` | — | `{ entitlements }` (se conserva hasta el fin del periodo) |
| `GET /v1/entitlements` | — | `Entitlements` (la app los guarda con `validatedAt`; valen 30 días sin conexión) |

### Organizaciones y ligas (add-growth-features)

| Método y ruta | Cuerpo | Respuesta |
| --- | --- | --- |
| `POST /v1/orgs/preview` | `{ code }` | `{ organization: { id, name, nominal, visibleData[] }, group }` para informar antes de unirse |
| `POST /v1/orgs/join` | `{ code, acceptNominal }` | `{ membership, entitlements }` o `409 seats_exhausted` |
| `GET /v1/orgs/domain-offer` | — | `{ organization? }` si el correo pertenece a un dominio autorizado con plazas |
| `GET /v1/orgs/mine` | — | `{ organization, group, visibleData[], assignedItineraries[] }` |
| `POST /v1/orgs/leave` | — | `204` |
| `GET /v1/leagues/current` | — | `{ participating, week, division, endsAt, standings: [{ position, alias, points, me }], zones: { promote, relegate }, computedAt, pendingPoints }` |
| `POST /v1/leagues/participation` | `{ participate, alias? }` | `{ participating }` |
| `GET /v1/leagues/private` | — | Ligas privadas de la organización a las que pertenece |

## Back office (`/v1/admin`, roles y permisos)

Roles: `superadmin`, `content_admin`, `author`, `reviewer`, `org_admin`, `analyst`, `support`.

| Área | Rutas principales |
| --- | --- |
| Acceso | `POST /v1/admin/auth/login {email,password}` → `{ challenge, mfaSetupRequired, otpauthUrl? }` · `POST /v1/admin/auth/mfa {challenge, code}` → `{ token, account }` · `POST /v1/admin/auth/recovery {challenge, recoveryCode}` · `GET /v1/admin/me` |
| Panel | `GET /v1/admin/dashboard` (trabajo pendiente por rol, alertas de calidad, estado del catálogo, actividad, última publicación; guía de cinco pasos si no hay contenido) |
| Estructura | `GET /v1/admin/structure` (árbol) · `POST /v1/admin/structure/:kind` (`sector`, `itinerary`, `unit`, `lesson`) · `PATCH /v1/admin/structure/:kind/:id` · `POST /v1/admin/structure/:kind/:id/move {direction: "up"\|"down"}` · `POST /v1/admin/structure/:kind/:id/retire` · `PUT /v1/admin/structure/lesson/:id/slots` |
| Contenido | `GET /v1/admin/items?kind=&state=&sector=&q=` · `GET /v1/admin/items/:id` (con versiones) · `POST /v1/admin/items {kind, data}` · `PUT /v1/admin/items/:id {data}` (sobre publicado crea versión nueva en borrador) · `POST /v1/admin/items/:id/submit` · `POST /v1/admin/items/:id/retire {reason}` · `GET /v1/admin/items/:id/diff?from=&to=` |
| Motor | `POST /v1/admin/engine/check-dimensions` · `POST /v1/admin/engine/sample {definition, n, level}` · `POST /v1/admin/engine/mass-test {definition}` · `POST /v1/admin/engine/validate {definition}` · `POST /v1/admin/engine/speak {text}` · `POST /v1/admin/engine/parse-spoken {text, options}` · `POST /v1/admin/engine/grade {answer, predicted, input}` |
| Importación | `GET /v1/admin/import/template?type=` (CSV modelo) · `POST /v1/admin/import/validate {type, rows, mapping}` · `POST /v1/admin/import/commit {type, rows, mapping}` |
| Revisión | `GET /v1/admin/reviews/inbox` · `GET /v1/admin/reviews/:itemId` (variantes de muestra, extremos y recálculo independiente) · `POST /v1/admin/reviews/:itemId/decision {decision, checklist, comment}` · `POST /v1/admin/reviews/:itemId/comments` |
| Publicación | `GET /v1/admin/releases` · `POST /v1/admin/releases` (prepara versión: diferencias frente a la activa) · `POST /v1/admin/releases/:id/checks` · `POST /v1/admin/releases/:id/test-package` (→ `testCode` y QR) · `POST /v1/admin/releases/:id/publish {confirmName, rolloutPct}` · `POST /v1/admin/releases/:id/rollout {rolloutPct}` · `POST /v1/admin/releases/rollback {reason}` · `POST /v1/admin/revocations {kind, itemId, reason}` · `GET /v1/admin/releases/compat?minAppVersion=` |
| Tipos de ejercicio | `GET/POST/PUT /v1/admin/exercise-types` (versión nueva si está en uso; compatibilidad con voz calculada) |
| Usuarios | `GET /v1/admin/users?q=&plan=&sector=` · `GET /v1/admin/users/:id` · `POST /v1/admin/users/:id/actions {action: "grant_premium"\|"reset_access"\|"block"\|"unblock"\|"export"\|"delete", days?, reason}` |
| Consultas | `GET /v1/admin/inquiries` · `GET /v1/admin/inquiries/:id` · `POST /v1/admin/inquiries/:id/reply {text, template?}` · `POST /v1/admin/inquiries/:id/convert` (borrador enlazado) · `POST /v1/admin/inquiries/:id/withdraw-exercise` |
| Catálogos | Los catálogos son elementos de contenido (`kind`: `catalog_unit`, `catalog_instrument`, `voice_lexicon`) y siguen el mismo ciclo. `POST /v1/admin/engine/parse-spoken` sirve el cuadro de prueba |
| Analítica | `GET /v1/admin/analytics/items?sort=&sector=` · `GET /v1/admin/analytics/items/:id` · `POST /v1/admin/analytics/items/:id/promote-error {value, unit, code, message}` · `GET /v1/admin/analytics/alerts` |
| Campañas | Creatividades y campañas son elementos (`kind`: `ad_creative`, `ad_campaign`) con el mismo ciclo · `GET/PUT /v1/admin/ads/params` (espera y frecuencias, auditadas) · `GET /v1/admin/ads/performance` |
| Logros y ligas | Logros como elementos (`kind`: `achievement`) · `POST /v1/admin/achievements/test {condition, userId}` · `GET/PUT /v1/admin/leagues/config` (en vigor la semana siguiente) · `GET /v1/admin/leagues/week` · `GET /v1/admin/leagues/flagged` · `POST /v1/admin/leagues/flagged/:id/resolve` |
| Organizaciones | `GET/POST /v1/admin/orgs` · `GET/PATCH /v1/admin/orgs/:id` · `POST /v1/admin/orgs/:id/groups` · `POST /v1/admin/orgs/:id/invites {emails[], groupId}` · `GET /v1/admin/orgs/:id/report?groupId=` · `POST /v1/admin/orgs/:id/private-leagues` |
| Auditoría | `GET /v1/admin/audit?actor=&action=&entity=&from=&to=` · `GET /v1/admin/audit/export` (CSV) |
| Cuentas | `GET/POST /v1/admin/accounts` (superadministrador): rol, sectores acreditados y acreditación |
