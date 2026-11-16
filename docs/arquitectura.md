# Arquitectura de VolutrainMed

Monorepo con cuatro piezas y dos flujos entre la nube y el dispositivo: **bajan paquetes de contenido firmados y suben intentos**. La voz no tiene ninguna conexión con la nube.

```
volutrainmed/
├── volutrainmed-openspec/    Especificación OpenSpec (fuente de verdad funcional)
├── docs/                     Definición funcional, arquitectura e informes
├── design/                   Fuentes de diseño (lienzo de Claude y Stitch)
├── contracts/                Contrato REST (api.md), fixtures compartidas y paquetes de ejemplo
├── packages/contracts        Tipos TypeScript canónicos (paquete, intentos, anuncios…)
├── packages/engine           Motor de plantillas, doble cálculo, corrección, voz (TS)
├── services/api              API REST + servicio de publicación (Node 22, Fastify, Postgres)
├── apps/backoffice           Back office web (React + TypeScript + Vite)
└── apps/mobile               App de entrenamiento (Flutter: iOS, Android y web; móvil y tablet)
```

## Decisiones

| Tema | Decisión | Relación con el OpenSpec |
| --- | --- | --- |
| App | Flutter 3.47, una base para iOS, Android y web; móvil y tablet con clases de tamaño | D1 |
| Cálculo | El dispositivo no calcula fórmulas: compara con variantes resueltas y verificadas en el servidor | D2 |
| Aritmética | Decimal exacta en servidor (decimal.js y racionales BigInt) y en la app (paquete `decimal`) | answer-grading |
| Doble cálculo | Motor A (decimal.js, AST) y motor B (racionales BigInt, shunting-yard), independientes | back office D3 |
| Base local | SQLite con Drift (en web, sqlite3.wasm + worker de Drift) y bandeja de salida propia | D6 |
| Fuente de verdad | El intento, solo se añade; repaso, dominio, rachas y progreso son proyecciones | D5 |
| Repaso | FSRS en el dispositivo, retención objetivo del 90 %, cuarentena de errores críticos | D7 |
| Contenido | Paquetes gzip por itinerario + paquete global, SHA-256 y firma Ed25519 sobre «id\|versión\|sha256» | D8 |
| Tipos de ejercicio | Datos por bloques interpretados por un intérprete genérico | D9 |
| Backend | Postgres 16 (en local con Docker; en producción, Supabase en la UE) + API propia en TypeScript | D10 |
| Permisos en BD | Roles del back office aplicados también en Postgres (RLS) y auditoría inalterable por disparador | backoffice-administration |
| Voz | Interfaz `MotorDeVoz`; síntesis con la voz del sistema; reconocimiento embebido pendiente de la prueba técnica | D3, D4 |
| Anuncios | Propios, en el paquete global, sin SDK publicitario ni identificador publicitario | house-ads D1 |
| Suscripción | Interfaz de tienda; en desarrollo, tienda de pruebas del servidor; en producción, RevenueCat | premium D9 |

## Puertos locales

| Servicio | Dirección |
| --- | --- |
| Postgres (Docker `volutrainmed-pg`) | `localhost:54329` (usuario `volutrain`, base `volutrainmed`) |
| API | `http://localhost:8787` |
| Back office | `http://localhost:5173` |
| App web (Flutter) | `http://localhost:8080` |

## Identidad visual

Tokens de Stitch («VolutrainMed Pro Max», `design/stitch/DESIGN.md`): primario `#0D5C75`, secundario `#088395`, verificación `#059669`, neutro `#0F172A`, lienzo `#F4FAFB`, superficie `#FFFFFF`, borde `#C5D9E0`, error `#DC2626`, aviso `#B45309` (texto) y acento de gamificación ámbar `#D97706` (texto `#92400E`). Tipografías: Space Grotesk (títulos), Noto Sans (cuerpo) y Space Mono (cifras). Iconos Material Symbols. Tema oscuro derivado del lienzo de Claude (`design/claude-artifact/tokens-components.css`, clase `.dark`), con contraste mínimo de 4,5:1.

## Reglas de producto que atraviesan todo

- Entrenador formativo, nunca calculadora clínica: ninguna pantalla acepta datos libres de paciente; la pauta va en el enunciado; los casos se rotulan como simulados; textos sin sugerencia de uso clínico.
- Cifras: coma decimal, cero inicial y sin ceros finales; número y unidad nunca se separan.
- Sin conexión como norma: todo el entrenamiento funciona en modo avión.
- Accesibilidad: contraste 4,5:1, objetivos de 48 dp, texto al 200 %, ningún estado solo con color, alternativa a todo gesto, cantidades leídas completas con el normalizador.
- Todo el contenido de ejemplo es de demostración y queda pendiente de validación por un profesional.
