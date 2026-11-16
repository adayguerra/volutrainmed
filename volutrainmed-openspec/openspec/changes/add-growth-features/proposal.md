# Proposal

## Why

Una vez comprobado que el usuario vuelve y que la voz funciona, el producto necesita tres palancas de crecimiento que no tenían sentido en el lanzamiento:

- **Ligas.** Un grupo semanal de 30 personas del mismo sector exige una base de usuarios que el producto mínimo viable no tiene. Una liga medio vacía desmotiva.
- **Organizaciones.** Universidades, hospitales y clínicas compran licencias, pero su ciclo de venta es largo.
- **Creador de tipos de ejercicio.** Aporta valor cuando el catálogo fijo de cinco tipos se queda corto.

Fase 2. Depende de `add-training-app-mvp`, `add-house-ads-and-premium` (las plazas de organización eliminan los anuncios) y `add-content-backoffice`. Criterio de entrada: retención en objetivo y contenido sin errores críticos notificados.

## What Changes

- Ligas semanales por sector con cinco divisiones, puntuación por precisión, alias y salida voluntaria.
- Logros configurables desde el back office.
- Organizaciones con plazas, grupos, acceso por código o por dominio de correo, informes agregados y ligas privadas.
- Creador de tipos de ejercicio por combinación de bloques, sin código ni versión de la app.
- Tipos nuevos definidos con el creador: completar el planteamiento (T4), detectar el error (T5), caso encadenado (T8) y emparejar (T10).

## Capabilities

### New Capabilities

- `leagues`: ligas semanales, puntuación, divisiones, privacidad de los participantes y logros configurables.
- `organizations`: organizaciones cliente, plazas, grupos, visibilidad de los datos e informes.
- `exercise-type-builder`: definición de tipos de ejercicio por bloques y su interpretación en la app.

### Modified Capabilities

Ninguna en este paquete, porque los cambios anteriores aún no están archivados. Al implementarlo habrá que añadir deltas sobre `gamification-progress` (los logros fijos pasan a ser configurables) y sobre `exercise-session` (tipos T4, T5, T8 y T10).

## Impact

- **App**: pestaña de ligas, unión a una organización, intérprete de tipos ampliado.
- **Back office**: gestión de ligas y logros, organizaciones y creador de tipos.
- **Servidor**: cálculo semanal de ligas y detección de patrones anómalos.
- **Privacidad**: el rendimiento de un profesional ante su empleador es delicado. Por defecto, la organización solo ve datos agregados.
- **Control de cambios regulatorio**: ninguna de las tres capacidades introduce cálculo libre ni datos de pacientes. Los informes de organización describen formación, no competencia clínica.
