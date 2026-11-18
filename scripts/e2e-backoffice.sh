#!/usr/bin/env bash
# Flujo de extremo a extremo del back office contra una API real, con un solo comando:
#   pnpm e2e:backoffice
# Crea (o vacía) una base propia, la siembra, arranca la API en un puerto propio,
# ejecuta el guion de autoría → revisión → publicación → reversión → retirada y el
# recorrido de humo de todas las pantallas por rol, y para la API al terminar.
# Requiere el Postgres de desarrollo (puerto 54329; en CI, el servicio postgres).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PG_HOST="${E2E_PG_HOST:-localhost}"
PG_PORT="${E2E_PG_PORT:-54329}"
DB="${E2E_DB:-volutrainmed_e2e}"
PORT="${E2E_API_PORT:-8799}"
export DATABASE_ADMIN_URL="postgres://volutrain:volutrain@${PG_HOST}:${PG_PORT}/${DB}"
export DATABASE_URL="postgres://vtm_app:vtm_app_dev@${PG_HOST}:${PG_PORT}/${DB}"
export PORT
BASE="http://localhost:${PORT}"
STATE="$(mktemp -t vtm-bo-e2e.XXXXXX)"
LOG="$(mktemp -t vtm-bo-api.XXXXXX)"
rm -f "$STATE"

cd "$ROOT"
echo "→ Base de datos ${DB}"
pnpm --filter @vtm/api db:ensure
echo "→ Semilla"
pnpm --filter @vtm/api seed -- --reset > /dev/null

echo "→ API en ${BASE}"
pnpm --filter @vtm/api start > "$LOG" 2>&1 &
API_PID=$!
cleanup() {
  kill "$API_PID" 2>/dev/null || true
  pkill -P "$API_PID" 2>/dev/null || true
  rm -f "$STATE"
}
trap cleanup EXIT
for i in $(seq 1 60); do
  if curl -sf "${BASE}/v1/health" > /dev/null; then break; fi
  if [ "$i" = 60 ]; then echo "La API no arranca:"; cat "$LOG"; exit 1; fi
  sleep 1
done

echo "→ Flujo de extremo a extremo"
E2E_API_BASE="$BASE" E2E_TOTP_STATE="$STATE" pnpm --filter backoffice e2e

echo "→ Recorrido de humo de todas las pantallas por rol"
BO_SMOKE_API="$BASE" BO_SMOKE_STATE="$STATE" pnpm --filter backoffice exec vitest run src/realapi.smoke.test.tsx

if [ "${E2E_BROWSER:-0}" = "1" ]; then
  echo "→ Navegador real (Playwright)"
  BO_E2E_API="$BASE" BO_E2E_STATE="$STATE" pnpm --filter backoffice e2e:browser
fi
echo "✓ Back office: extremo a extremo completado"
