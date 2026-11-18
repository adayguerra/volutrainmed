# VolutrainMed

Entrenador formativo de cálculo de dosis y volúmenes para estudiantes y profesionales sanitarios y veterinarios: sesiones de 3 a 5 minutos con casos simulados, corrección paso a paso, repaso espaciado, contrarreloj, modo manos libres con la voz procesada en el dispositivo y funcionamiento sin conexión.

> **VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.** Todo el contenido incluido es de demostración y está pendiente de validación por un profesional.

| Pieza | Carpeta | Tecnología |
| --- | --- | --- |
| App de entrenamiento (móvil, tablet y web) | `apps/mobile` | Flutter 3.47 · iOS, Android y web |
| Back office | `apps/backoffice` | React + TypeScript + Vite |
| API y servicio de publicación | `services/api` | Node 22 · Fastify · Postgres 16 |
| Motor de plantillas | `packages/engine` | TypeScript (decimal exacto, doble cálculo, voz) |
| Contratos | `packages/contracts`, `contracts/` | Tipos, REST, fixtures y paquetes de ejemplo |
| Especificación | `volutrainmed-openspec/` | OpenSpec 2.0 (cuatro cambios) |
| Diseño | `design/` | Lienzo de Claude y Stitch |
| Documentación | `docs/` | Definición funcional, arquitectura, voz, tiendas, regulatorio e informe |

## Puesta en marcha

Requisitos: Docker, Node 22 con pnpm 10, Flutter 3.47 y Xcode (para iOS).

```bash
# 1. Base de datos
docker run -d --name volutrainmed-pg -e POSTGRES_USER=volutrain -e POSTGRES_PASSWORD=volutrain \
  -e POSTGRES_DB=volutrainmed -p 54329:5432 postgres:16-alpine

# 2. Dependencias, esquema, semilla y primera publicación
pnpm install
pnpm --filter @vtm/api seed -- --reset

# 3. API (http://localhost:8787)
pnpm --filter @vtm/api start

# 4. Back office (http://localhost:5173)
pnpm --filter backoffice dev

# 5. App (simulador iOS, Android o web)
cd apps/mobile && flutter run --dart-define=API_BASE=http://localhost:8787
```

### Cuentas del back office (desarrollo)

Contraseña común: `VolutrainMed-2026!`. El primer acceso de cada cuenta configura el segundo factor (aplicación de autenticación) y entrega códigos de recuperación.

| Rol | Correo |
| --- | --- |
| Superadministración | `superadmin@volutrainmed.test` |
| Administración de contenido | `contenido@volutrainmed.test` |
| Autoría | `autora@volutrainmed.test`, `autor2@volutrainmed.test` |
| Revisión experta | `revisor.clinico@…` (común, anestesia, enfermería, medicina, emergencias, farmacia), `revisor.vet@…` (común, veterinaria), `revisor.enfermeria@…`, `revisor.ped1@…`, `revisor.ped2@…` |
| Organización | `organizacion@volutrainmed.test` (Facultad de demostración, código `FACDEMO1`) |
| Análisis | `analista@volutrainmed.test` |
| Soporte | `soporte@volutrainmed.test` |

En la app, el acceso por correo usa un código de seis cifras; en desarrollo el código se consulta en `GET /v1/dev/mailbox?email=…`.

## Pruebas

```bash
pnpm --filter @vtm/engine test   # motor: fixtures compartidas y 500 locuciones
pnpm --filter @vtm/api test      # API: integración contra Postgres (base volutrainmed_test)
pnpm --filter backoffice test    # back office
pnpm e2e:backoffice              # back office de extremo a extremo contra una API real (base volutrainmed_e2e, puerto 8799)
cd apps/mobile && flutter analyze && flutter test
cd volutrainmed-openspec && npx -y @fission-ai/openspec@latest validate --all --strict
```

`pnpm e2e:backoffice` crea y siembra la base `volutrainmed_e2e`, arranca una API propia en el puerto 8799, ejecuta el flujo completo (la autora crea una plantilla, un revisor distinto la valida, se publica al 5 % y al 100 %, se revierte y se retira un ejercicio desde una consulta) con doble factor real, recorre todas las pantallas con cada rol y para la API. Con `E2E_BROWSER=1` añade el recorrido en un navegador real (Playwright). Variables: `E2E_DB`, `E2E_API_PORT`, `E2E_PG_PORT`.

## Documentación

- [Arquitectura y decisiones](docs/arquitectura.md)
- [Contrato de la API](contracts/api.md)
- [Definición funcional](docs/definicion-funcional.md)
- [Fuentes de diseño](design/README.md)
- [Prueba técnica de voz](docs/voz/prueba-tecnica.md)
- [Fichas de las tiendas](docs/tiendas/fichas.md) y [calificación regulatoria](docs/regulatorio/calificacion.md)
- [Informe de implementación y trazabilidad](docs/informe-implementacion.md)
