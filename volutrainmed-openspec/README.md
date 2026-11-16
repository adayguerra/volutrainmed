# VolutrainMed · OpenSpec

Especificación del producto VolutrainMed en formato [OpenSpec](https://github.com/Fission-AI/OpenSpec) 2.0 (esquema `spec-driven`).

El producto todavía no está construido. Por eso `openspec/specs/` está vacío y todo el alcance vive en `openspec/changes/` como cambios propuestos. Al implementar y archivar cada cambio, sus requisitos pasan a `openspec/specs/`.

## Cambios

| Orden | Cambio | Fase | Contenido |
| --- | --- | --- | --- |
| 1 | `add-training-app-mvp` | 1 | La app de entrenamiento: alta, ruta, sesión, corrección, repaso espaciado, contrarreloj, manos libres, sin conexión, gamificación básica y diseño adaptativo y accesible |
| 2 | `add-house-ads-and-premium` | 1 | Pausa promocional con anuncios propios tras cada ejercicio y suscripción Premium que la elimina. Incluye el catálogo de anuncios |
| 3 | `add-content-backoffice` | 1 | Back office: creación de contenido sin código, revisión experta, publicación y administración |
| 4 | `add-growth-features` | 2 | Ligas y logros configurables, organizaciones y creador de tipos de ejercicio |

Los cambios 1, 2 y 3 forman el producto mínimo viable. El 2 depende del 1 (se engancha a la sesión de ejercicios) y del 3 (las campañas se gestionan y se publican desde el back office).

## Capacidades

| Cambio | Capacidad | Qué cubre |
| --- | --- | --- |
| 1 | `formative-boundary` | Límite entre entrenador y calculadora clínica |
| 1 | `onboarding-account` | Alta, prueba de nivel, cuenta, perfil y consulta |
| 1 | `learning-path` | Ruta, lecciones, reto de unidad y dominio por habilidad |
| 1 | `exercise-session` | Sesión táctil, tipos de ejercicio del MVP y teclado propio |
| 1 | `answer-grading` | Corrección numérica, unidades, diagnóstico del error y explicación |
| 1 | `spaced-review` | Repaso espaciado de errores |
| 1 | `time-trial` | Contrarreloj orientado a la agilidad |
| 1 | `hands-free-voice` | Modo manos libres con voz en el dispositivo |
| 1 | `offline-sync` | Funcionamiento sin conexión, sincronización y paquetes de contenido |
| 1 | `gamification-progress` | Metas, rachas, puntos, niveles, logros fijos y estadísticas |
| 1 | `adaptive-accessible-ui` | Diseño adaptativo en móvil y tablet, y accesibilidad |
| 2 | `house-ads` | Pausa promocional con anuncios propios |
| 2 | `premium-subscription` | Suscripción Premium |
| 3 | `content-authoring` | Plantillas, preguntas, importación y vista previa con voz |
| 3 | `content-review-publishing` | Revisión experta, versionado y publicación |
| 3 | `backoffice-administration` | Roles, usuarios, analítica de contenido, consultas y catálogos |
| 4 | `leagues` | Ligas semanales y logros configurables |
| 4 | `organizations` | Organizaciones, grupos e informes |
| 4 | `exercise-type-builder` | Creación de tipos de ejercicio por bloques |

## Uso

```bash
npm install -g @fission-ai/openspec
openspec list                      # cambios activos
openspec show add-house-ads-and-premium
openspec validate --all --strict   # validación del paquete
```

## Decisión que cambia respecto a la definición funcional

La definición funcional (versión 1) partía de un producto sin publicidad. Este OpenSpec incorpora el modelo indicado después: plan gratuito con una pausa promocional tras cada ejercicio y suscripción para eliminarla. Los anuncios son propios de la app, van dentro del paquete de contenido y funcionan sin conexión; no se integra ninguna red publicitaria. Las secciones 5.17, 11.1 y el supuesto S9 de la definición funcional deben actualizarse en consecuencia.

## Avisos

- Todos los ejemplos farmacológicos están pendientes de validación por un profesional antes de publicarse.
- El encaje regulatorio y de tiendas debe confirmarlo un especialista.
- Los precios y los beneficios adicionales de Premium son supuestos por validar (véase el diseño del cambio 2).
