# Trazabilidad de escenarios del OpenSpec

Generado con `python3 -I scripts/trazabilidad.py`. Una prueba cubre un escenario cuando su nombre contiene el nombre del escenario; el resto se anota a mano en `scripts/trazabilidad-manual.json`.

| Estado | Escenarios |
| --- | --- |
| Prueba automatizada | 324 |
| Sin evidencia automática | 8 |
| **Total** | **332** |

## add-content-backoffice · backoffice-administration

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Roles y permisos | Analista | Prueba automatizada | apps/backoffice/src/realapi.smoke.test.tsx, apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/backoffice/src/screens/template/TemplateEditor.test.tsx, services/api/test/api.test.ts |
| Roles y permisos | Autor | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/auth/auth.test.tsx, apps/backoffice/src/realapi.smoke.test.tsx, apps/backoffice/src/screens/Dashboard.test.tsx, apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/backoffice/src/screens/Library.test.tsx, apps/backoffice/src/screens/People.test.tsx, apps/backoffice/src/screens/Review.test.tsx, apps/backoffice/src/screens/template/TemplateEditor.test.tsx, apps/mobile/test/account/cuenta_test.dart, services/api/test/api.test.ts |
| Roles y permisos | Soporte | Prueba automatizada | apps/backoffice/src/auth/auth.test.tsx, apps/backoffice/src/realapi.smoke.test.tsx, apps/backoffice/src/screens/Dashboard.test.tsx, apps/backoffice/src/screens/People.test.tsx, apps/backoffice/src/screens/Publishing.test.tsx, apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/leagues/ligas_test.dart, apps/mobile/test/subscription/suscripcion_test.dart, apps/mobile/test/timetrial/contenido_al_empezar_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart, apps/mobile/test/voice/motor_voz_sistema_test.dart, services/api/test/api.test.ts |
| Doble factor obligatorio | Primer acceso | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/auth/auth.test.tsx, services/api/test/api.test.ts |
| Registro de auditoría | Cambio de una fórmula | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx, services/api/test/api.test.ts |
| Registro de auditoría | Intento de alteración | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx |
| Nada se borra | Retirar una pregunta | Prueba automatizada | apps/backoffice/src/screens/Library.test.tsx |
| Panel de control por rol | Revisor | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/auth/auth.test.tsx, apps/backoffice/src/realapi.smoke.test.tsx, apps/backoffice/src/screens/Dashboard.test.tsx, apps/backoffice/src/screens/Publishing.test.tsx, apps/backoffice/src/screens/Review.test.tsx, apps/backoffice/src/screens/Structure.test.tsx, services/api/test/api.test.ts |
| Panel de control por rol | Instalación nueva | Prueba automatizada | apps/backoffice/src/screens/Dashboard.test.tsx |
| Gestión de usuarios | Conceder días de Premium | Prueba automatizada | apps/backoffice/src/screens/People.test.tsx, services/api/test/api.test.ts |
| Gestión de usuarios | Supresión de datos | Prueba automatizada | apps/backoffice/src/screens/People.test.tsx |
| Consultas de usuarios | Aviso de error en un ejercicio | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx |
| Consultas de usuarios | Conversión en corrección | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx |
| Consultas de usuarios | Consulta sobre un paciente | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx, services/api/test/api.test.ts |
| Catálogos compartidos | Nueva forma hablada | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx |
| Catálogos compartidos | Prueba de interpretación | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx |
| Analítica de contenido | Preguntas con más fallos | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx |
| Analítica de contenido | Datos insuficientes | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/progress/progreso_test.dart |
| Alertas de calidad | Plantilla demasiado difícil | Prueba automatizada | apps/backoffice/src/screens/Dashboard.test.tsx |
| Alertas de calidad | Error frecuente sin clasificar | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx |

## add-content-backoffice · content-authoring

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Estructura del contenido editable | Nueva unidad | Prueba automatizada | apps/backoffice/src/screens/Structure.test.tsx, services/api/test/api.test.ts |
| Estructura del contenido editable | Lección sin ejercicios | Prueba automatizada | apps/backoffice/src/screens/Structure.test.tsx, services/api/test/api.test.ts |
| Estructura del contenido editable | Reordenar sin arrastrar | Prueba automatizada | apps/backoffice/src/screens/Structure.test.tsx, services/api/test/api.test.ts |
| Plantillas parametrizadas | Plantilla de dosis por peso | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx, services/api/test/api.test.ts |
| Plantillas parametrizadas | Tabla de casos | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx, packages/engine/test/engine.test.ts |
| Comprobación dimensional de la fórmula | Unidades coherentes | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Comprobación dimensional de la fórmula | Unidades incoherentes | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx, packages/engine/test/engine.test.ts, services/api/test/api.test.ts |
| Restricciones y errores previsibles | Resultado fuera de rango | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Restricciones y errores previsibles | Error previsible de factor diez | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Prueba masiva de variantes | Colisión detectada | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Prueba masiva de variantes | Variantes insuficientes | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Explicación y niveles de dificultad | Plantilla sin pasos | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx, packages/engine/test/engine.test.ts |
| Explicación y niveles de dificultad | Nivel con números limpios | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Preguntas fijas | Pregunta de selección única | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx |
| Preguntas fijas | Cantidad sin unidad | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx |
| Texto para voz y vista previa con lectura | Escuchar un ejercicio | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx |
| Texto para voz y vista previa con lectura | Simular una respuesta | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx, services/api/test/api.test.ts |
| Texto para voz y vista previa con lectura | Vista previa en tablet | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx |
| Importación masiva | Fila con error | Prueba automatizada | apps/backoffice/src/screens/Import.test.tsx |
| Importación masiva | Importación parcial | Prueba automatizada | apps/backoffice/src/screens/Import.test.tsx, services/api/test/api.test.ts |
| Creación sin código ni versión de la app | De la plantilla al dispositivo | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts |

## add-content-backoffice · content-review-publishing

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ciclo de estados del contenido | Edición de un contenido publicado | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx |
| Ciclo de estados del contenido | Cambios solicitados | Prueba automatizada | apps/backoffice/src/screens/Publishing.test.tsx, apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Autor que intenta validar lo suyo | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Revisor sin acreditación en el sector | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Sector con doble revisión | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Lista de comprobación del revisor | Lista incompleta | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Lista de comprobación del revisor | Muestra de variantes | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Firma y caducidad de la validación | Validación caducada | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx |
| Firma y caducidad de la validación | Contenido modificado durante la revisión | Prueba automatizada | apps/backoffice/src/screens/Review.test.tsx, services/api/test/api.test.ts |
| Publicación solo de contenido validado | Elemento sin validar | Prueba automatizada | apps/backoffice/src/screens/Publishing.test.tsx |
| Comprobaciones automáticas antes de publicar | Discrepancia en el doble cálculo | Prueba automatizada | apps/backoffice/src/screens/Publishing.test.tsx |
| Comprobaciones automáticas antes de publicar | Comprobaciones superadas | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/screens/Publishing.test.tsx |
| Paquete firmado y despliegue gradual | Despliegue al 5 % | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, services/api/test/api.test.ts |
| Paquete firmado y despliegue gradual | Compatibilidad con la app | Prueba automatizada | apps/backoffice/src/screens/Publishing.test.tsx, services/api/test/api.test.ts |
| Reversión | Reversión de una versión | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts |
| Retirada inmediata de un ejercicio | Retirada de una plantilla con error | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts |
| Paquete de prueba | Prueba en un dispositivo | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts |

## add-growth-features · exercise-session

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos de ejercicio del producto mínimo viable | Respuesta numérica | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Completar el planteamiento | Prueba automatizada | apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fase2_ui_test.dart |
| Tipos de ejercicio del producto mínimo viable | Emparejar | Prueba automatizada | apps/backoffice/src/screens/Import.test.tsx, apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fase2_ui_test.dart |
| Tipos de ejercicio del producto mínimo viable | Tipo de fase 2 sin conexión | Prueba automatizada | apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fase2_ui_test.dart |

## add-growth-features · exercise-type-builder

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos como combinación de bloques | Tipo de dos pasos | Prueba automatizada | apps/backoffice/src/screens/ExerciseTypes.test.tsx |
| Tipos como combinación de bloques | Paso sin bloque de respuesta | Prueba automatizada | apps/backoffice/src/screens/ExerciseTypes.test.tsx, services/api/test/api.test.ts |
| Tipos como combinación de bloques | Bloques sin arrastrar | Prueba automatizada | apps/backoffice/src/screens/ExerciseTypes.test.tsx |
| Interpretación del tipo en la app | Tipo nuevo en una app ya instalada | Sin evidencia automática |  |
| Interpretación del tipo en la app | Tipo nuevo sin conexión | Sin evidencia automática |  |
| Versión mínima de la app por tipo | App antigua | Sin evidencia automática |  |
| Versión mínima de la app por tipo | Aviso antes de publicar | Prueba automatizada | apps/backoffice/src/screens/Publishing.test.tsx |
| Compatibilidad con voz calculada | Tipo con un bloque de ordenar | Prueba automatizada | apps/backoffice/src/screens/ExerciseTypes.test.tsx |
| Tipos en uso versionados | Cambio en un tipo en uso | Prueba automatizada | apps/backoffice/src/screens/ExerciseTypes.test.tsx |
| Tipos de la fase 2 | Caso encadenado | Prueba automatizada | apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fase2_ui_test.dart |
| Tipos de la fase 2 | Detectar el error | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fase2_ui_test.dart |

## add-growth-features · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Logros fijos | Primera sesión manos libres | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/voice/turno_test.dart |
| Logros fijos | Logro configurado en el back office | Prueba automatizada | apps/mobile/test/leagues/ligas_test.dart |
| Logros fijos | Logro obtenido sin conexión | Prueba automatizada | apps/mobile/test/leagues/ligas_test.dart |

## add-growth-features · leagues

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ligas semanales por sector | Inicio de semana | Sin evidencia automática |  |
| Ligas semanales por sector | Ascenso y descenso | Sin evidencia automática |  |
| Puntuación por precisión | Tope diario | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx, apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/league_test.dart, apps/mobile/test/leagues/ligas_test.dart, services/api/test/api.test.ts |
| Puntuación por precisión | Marca de contrarreloj no válida | Prueba automatizada | apps/mobile/test/domain/league_test.dart |
| Alias y participación voluntaria | Clasificación con alias | Prueba automatizada | apps/mobile/test/domain/league_test.dart, apps/mobile/test/leagues/ligas_test.dart |
| Alias y participación voluntaria | Salida de las ligas | Prueba automatizada | apps/mobile/test/leagues/ligas_test.dart, services/api/test/api.test.ts |
| Clasificación sin conexión | Liga sin conexión | Prueba automatizada | apps/mobile/test/domain/league_test.dart, apps/mobile/test/leagues/ligas_test.dart |
| Cambios de reglas al inicio de semana | Cambio del tope diario | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx, services/api/test/api.test.ts |
| Detección de puntuaciones anómalas | Tiempos imposibles | Prueba automatizada | services/api/test/api.test.ts |
| Logros configurables | Logro de racha | Prueba automatizada | services/api/test/api.test.ts |
| Logros configurables | Prueba de la condición | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx, services/api/test/api.test.ts |

## add-growth-features · organizations

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Organizaciones con plazas | Plazas agotadas | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart, services/api/test/api.test.ts |
| Organizaciones con plazas | Vigencia terminada | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart |
| Acceso por código o por dominio de correo | Código de invitación | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart |
| Acceso por código o por dominio de correo | Dominio autorizado | Prueba automatizada | apps/mobile/test/account/cuenta_test.dart, services/api/test/api.test.ts |
| Datos agregados por defecto | Informe de grupo | Prueba automatizada | apps/backoffice/src/screens/Organizations.test.tsx |
| Datos agregados por defecto | Grupo pequeño | Prueba automatizada | apps/backoffice/src/screens/Organizations.test.tsx, services/api/test/api.test.ts |
| Modo nominal informado | Unión a una organización en modo nominal | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart |
| Modo nominal informado | Qué ve la organización | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart |
| Grupos e itinerarios asignados | Invitación masiva | Prueba automatizada | apps/backoffice/src/screens/Organizations.test.tsx, services/api/test/api.test.ts |
| Grupos e itinerarios asignados | Itinerario asignado | Prueba automatizada | apps/mobile/test/orgs/organizacion_test.dart |
| Ligas privadas | Liga de una promoción | Prueba automatizada | apps/mobile/test/leagues/ligas_test.dart |
| Las plazas de organización eliminan los anuncios | Miembro de una organización | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| Las plazas de organización eliminan los anuncios | Miembro sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |

## add-house-ads-and-premium · house-ads

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Pausa promocional tras cada ejercicio | Respuesta correcta en una lección | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Pausa promocional tras cada ejercicio | Último ejercicio de la lección | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| La corrección va siempre antes | Respuesta incorrecta con explicación | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| La corrección va siempre antes | Error crítico con segundo intento | Prueba automatizada | apps/mobile/test/session/motor_sesion_test.dart |
| Formato de la pausa promocional | Elementos visibles | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Formato de la pausa promocional | Tablet en horizontal | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/app/armazon_test.dart, apps/mobile/test/app/barrido_pantallas_test.dart |
| Espera configurable antes de continuar | Espera por defecto | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Espera configurable antes de continuar | Espera desactivada | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Inventario propio y local | Modo avión | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/voice/turno_test.dart |
| Inventario propio y local | Sin tráfico publicitario | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Rotación de anuncios | Sin repetición consecutiva | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Rotación de anuncios | Tope diario alcanzado | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Anuncios activados por contexto | Racha de varios días | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Anuncios activados por contexto | Límite diario de manos libres agotado | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Exclusiones de la pausa promocional | Usuario con Premium | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Exclusiones de la pausa promocional | Primera lección | Prueba automatizada | apps/mobile/integration_test/recorrido_test.dart, apps/mobile/test/domain/ads_test.dart, apps/mobile/test/onboarding/alta_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Exclusiones de la pausa promocional | Contrarreloj | Prueba automatizada | apps/mobile/test/app/barrido_pantallas_test.dart, apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/league_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/orgs/organizacion_test.dart, apps/mobile/test/timetrial/contenido_al_empezar_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Exclusiones de la pausa promocional | Prueba de nivel | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/onboarding/alta_test.dart |
| Cuña hablada en el modo manos libres | Cuña tras el veredicto | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Cuña hablada en el modo manos libres | Saltar la cuña | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Cuña hablada en el modo manos libres | Interés sin tocar la pantalla | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| El tiempo de anuncio no cuenta como práctica | Meta diaria de cinco minutos | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| El tiempo de anuncio no cuenta como práctica | Tiempo de respuesta | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Acción del anuncio | Toque en «Quitar anuncios» y vuelta | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Acción del anuncio | Compra desde un anuncio | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Publicidad honesta | Cifras calculadas con la configuración vigente | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Publicidad honesta | Texto con alusión clínica | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx, services/api/test/api.test.ts |
| Campañas sin publicar una versión de la app | Cambio de la espera | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Campañas sin publicar una versión de la app | Campaña por sector | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Campañas sin publicar una versión de la app | Campaña caducada sin conexión | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/domain/ads_test.dart |
| Accesibilidad de la pausa promocional | Lector de pantalla | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, packages/engine/test/engine.test.ts |
| Accesibilidad de la pausa promocional | Movimiento reducido | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Medición de los anuncios | Impresión sin conexión | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |
| Medición de los anuncios | Conversión atribuida | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart |

## add-house-ads-and-premium · premium-subscription

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Planes y prueba gratuita | Inicio de la prueba | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Planes y prueba gratuita | Prueba ya consumida | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Premium elimina los anuncios | Compra a mitad de lección | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| Premium elimina los anuncios | Lección completa con Premium | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| Beneficios adicionales de Premium | Límite de manos libres en el plan gratuito | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Beneficios adicionales de Premium | Manos libres con Premium | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Compra en la tienda y restauración | Restauración en un dispositivo nuevo | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart |
| Compra en la tienda y restauración | Compra cancelada | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart, services/api/test/api.test.ts |
| Compra en la tienda y restauración | Compra fallida | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart |
| Validez sin conexión | Dos semanas sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Validez sin conexión | Más de treinta días sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Caducidad y cancelación | Cancelación a mitad de periodo | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Caducidad y cancelación | Suscripción caducada | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Transparencia de la oferta | Información antes de comprar | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart |
| Transparencia de la oferta | Precios no disponibles | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Recordatorio antes del fin de la prueba | Aviso previo al cobro | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/subscription/suscripcion_test.dart |
| Estado de la suscripción en Perfil | Usuario con plan anual | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/profile/perfil_test.dart |

## add-training-app-mvp · adaptive-accessible-ui

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Disposición por clase de tamaño | Móvil | Prueba automatizada | apps/mobile/test/account/fusion_cuenta_test.dart, apps/mobile/test/app/armazon_test.dart, apps/mobile/test/app/barrido_pantallas_test.dart, apps/mobile/test/contenido/solo_wifi_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/sync/sincronizador_test.dart, services/api/test/api.test.ts |
| Disposición por clase de tamaño | Tablet en horizontal | Prueba automatizada | apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/app/armazon_test.dart, apps/mobile/test/app/barrido_pantallas_test.dart |
| Disposición por clase de tamaño | Giro del dispositivo | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Disposición por clase de tamaño | Disposición sin conexión | Prueba automatizada | apps/mobile/test/home/inicio_test.dart |
| La tablet no estira el móvil | Sesión en tablet horizontal | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| La tablet no estira el móvil | Inicio en tablet horizontal | Prueba automatizada | apps/mobile/test/home/inicio_test.dart |
| Hoja de borrador no persistente | Cambio de ejercicio | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Contraste y color no exclusivo | Veredicto | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/onboarding/alta_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart, apps/mobile/test/voice/turno_test.dart |
| Contraste y color no exclusivo | Tema oscuro | Prueba automatizada | apps/mobile/test/app/armazon_test.dart, apps/mobile/test/app/barrido_pantallas_test.dart, apps/mobile/test/profile/perfil_test.dart |
| Texto ampliable | Texto al 200 % | Prueba automatizada | apps/mobile/test/app/barrido_pantallas_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/profile/perfil_test.dart, apps/mobile/test/progress/progreso_test.dart, apps/mobile/test/review/repaso_test.dart, apps/mobile/test/session/correccion_test.dart |
| Objetivos táctiles | Icono pequeño | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Compatibilidad con lector de pantalla | Lectura de una cantidad | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Compatibilidad con lector de pantalla | Anuncio del veredicto | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Movimiento reducido | Fin de lección con movimiento reducido | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| Alternativa a los gestos | Ordenar pasos sin arrastrar | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Alternativa a los gestos | Cerrar una hoja | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Respuesta háptica y sonora configurable | Modo silencio | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Respuesta háptica y sonora configurable | Háptica desactivada | Prueba automatizada | apps/mobile/test/profile/perfil_test.dart, apps/mobile/test/session/correccion_test.dart |

## add-training-app-mvp · answer-grading

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Aritmética decimal exacta | Suma de decimales | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tres veredictos | Más decimales de los pedidos | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Tres veredictos | Formato inseguro | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Tres veredictos | Respuesta incorrecta | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Redondeo indicado | Gota entera | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Redondeo indicado | Jeringa de 1 ml | Prueba automatizada | apps/backoffice/src/screens/QuestionPreview.test.tsx, apps/mobile/test/domain/grading_fixtures_test.dart, packages/engine/test/engine.test.ts |
| Unidades de la respuesta | Unidad equivalente | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Unidades de la respuesta | Unidad equivocada | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Diagnóstico del tipo de error | Factor diez | Prueba automatizada | apps/backoffice/src/screens/template/TemplateEditor.test.tsx, apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Diagnóstico del tipo de error | Paso omitido | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Diagnóstico del tipo de error | Error sin clasificar | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Errores críticos | Desviación de factor cinco | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Errores críticos | Dosis máxima no aplicada | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Explicación paso a paso | Explicación de una perfusión | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart |
| Explicación paso a paso | Explicación a demanda tras un acierto | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| Segundo intento con otros números | Segundo intento acertado | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Corrección con valores verificados | Corrección en modo avión | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |

## add-training-app-mvp · exercise-session

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos de ejercicio del producto mínimo viable | Respuesta numérica | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Teclado numérico propio | Segunda coma | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Teclado numérico propio | Teclado físico en tablet | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart |
| Unidad de respuesta | Unidad fija | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/voice/turno_test.dart |
| Unidad de respuesta | Unidad a elegir | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/voice/turno_test.dart |
| Respuesta «No lo sé» | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/voice/contenido_al_empezar_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart, apps/mobile/test/voice/turno_test.dart |
| Sesión sin navegación y con salida confirmada | Salida a mitad de lección | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Sesión sin navegación y con salida confirmada | Gesto de atrás | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Pausa al pasar a segundo plano | Llamada entrante | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Medida del tiempo de respuesta | Tiempo de un ejercicio | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Lección preparada antes de empezar | Lección en modo avión | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart |
| Lección preparada antes de empezar | Variante defectuosa | Prueba automatizada | apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart |

## add-training-app-mvp · formative-boundary

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Solo casos simulados | No existe entrada libre de datos | Prueba automatizada | apps/mobile/test/app/barrido_pantallas_test.dart, apps/mobile/test/session/correccion_test.dart |
| Solo casos simulados | La respuesta del usuario solo se corrige | Prueba automatizada | apps/mobile/test/session/correccion_test.dart |
| La pauta viene dada en el enunciado | Enunciado con pauta | Prueba automatizada | apps/mobile/test/contenido_formativo/contenido_formativo_test.dart, apps/mobile/test/session/correccion_test.dart |
| La pauta viene dada en el enunciado | Límite de dosis como dato | Prueba automatizada | apps/mobile/test/contenido_formativo/contenido_formativo_test.dart, apps/mobile/test/session/correccion_test.dart |
| Aviso formativo | Aceptación obligatoria en el alta | Prueba automatizada | apps/mobile/test/onboarding/alta_test.dart |
| Aviso formativo | Aviso disponible en ajustes | Prueba automatizada | apps/mobile/test/profile/perfil_test.dart |
| Aviso formativo | Aviso sin conexión | Prueba automatizada | apps/mobile/test/profile/perfil_test.dart |
| Casos rotulados como simulados | Paciente simulado | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/backoffice/src/screens/QuestionPreview.test.tsx, apps/mobile/test/contenido_formativo/contenido_formativo_test.dart, apps/mobile/test/domain/tts_fixtures_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/voice/turno_test.dart |
| Casos rotulados como simulados | Principio activo | Prueba automatizada | apps/mobile/test/contenido_formativo/contenido_formativo_test.dart |
| Comunicación sin uso clínico | Ficha de la tienda | Sin evidencia automática |  |
| Comunicación sin uso clínico | Texto con sugerencia de uso clínico | Sin evidencia automática |  |

## add-training-app-mvp · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Meta de práctica diaria o semanal | Meta diaria cumplida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Meta de práctica diaria o semanal | Meta semanal | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Racha | Racha extendida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Racha | Racha interrumpida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Racha | Racha sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Puntos por aciertos al primer intento | Segundo intento | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Puntos por aciertos al primer intento | Acierto al primer intento | Prueba automatizada | apps/backoffice/src/screens/Dashboard.test.tsx, apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/voice/turno_test.dart |
| Niveles | Subida de nivel | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Logros fijos | Primera sesión manos libres | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/voice/turno_test.dart |
| Fin de lección | Lección con fallos | Prueba automatizada | apps/mobile/test/session/fin_y_pausas_test.dart |
| Fin de lección | Cambio de estado de una habilidad | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Estadísticas por habilidad | Evolución de la precisión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/progress/progreso_test.dart |
| Estadísticas por habilidad | Datos insuficientes | Prueba automatizada | apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/progress/progreso_test.dart |
| Estadísticas por habilidad | Estadísticas sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/progress/progreso_test.dart |
| Fallar no bloquea la práctica | Lección con muchos fallos | Prueba automatizada | apps/mobile/test/session/motor_sesion_test.dart |

## add-training-app-mvp · hands-free-voice

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Procesamiento íntegro en el dispositivo | Sesión en modo avión | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Procesamiento íntegro en el dispositivo | Sin tráfico de voz | Prueba automatizada | apps/mobile/test/voice/motor_voz_sistema_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Sin almacenamiento de audio ni de transcripciones | Datos guardados de un intento por voz | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Turno conversacional | Turno completo | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart, apps/mobile/test/voice/turno_test.dart |
| Turno conversacional | La pregunta va al final | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Confirmación antes de corregir | Rechazo de lo entendido | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Confirmación antes de corregir | Cifras que se confunden | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart, apps/mobile/test/voice/turno_test.dart, packages/engine/test/engine.test.ts |
| Confirmación antes de corregir | Confirmación abreviada | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Gramática de respuestas numéricas | Variantes de un mismo decimal | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Cero tras la coma | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Entero y medio | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Respuesta ambigua | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Unidades habladas | Unidad fija | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/voice/turno_test.dart |
| Unidades habladas | Miligramos o microgramos | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/voice/turno_test.dart |
| Unidades habladas | Sinónimo de sector | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/voice/turno_test.dart |
| Comandos de voz | Repite | Prueba automatizada | apps/backoffice/src/screens/GamificationCatalogs.test.tsx, apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/profile/perfil_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/subscription/suscripcion_test.dart, apps/mobile/test/voice/turno_test.dart |
| Comandos de voz | Pausa y continúa | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Comandos de voz | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/voice/contenido_al_empezar_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart, apps/mobile/test/voice/turno_test.dart |
| Comandos de voz | Salir | Prueba automatizada | apps/backoffice/src/screens/Import.test.tsx, apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/orgs/organizacion_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/voice/turno_test.dart |
| Recuperación de errores de reconocimiento | Tercer fallo | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Recuperación de errores de reconocimiento | El fallo de reconocimiento no penaliza | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Recuperación de errores de reconocimiento | Silencio | Prueba automatizada | apps/mobile/test/session/correccion_test.dart, apps/mobile/test/voice/motor_voz_sistema_test.dart, apps/mobile/test/voice/turno_test.dart |
| Ruido ambiente | Entorno ruidoso | Prueba automatizada | apps/mobile/test/voice/motor_voz_sistema_test.dart, apps/mobile/test/voice/turno_test.dart |
| Uso con guantes o manos ocupadas | Toque en la pantalla | Prueba automatizada | apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Uso con guantes o manos ocupadas | Botón de los auriculares | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Paquete de voz bajo demanda | Sin paquete y sin conexión | Prueba automatizada | apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Paquete de voz bajo demanda | Paquete alterado | Prueba automatizada | apps/mobile/test/app/armazon_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Latencia del reconocimiento | Respuesta corta | Sin evidencia automática |  |
| Ejercicios compatibles con voz | Lección con un tipo no compatible | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |
| Accesibilidad de la sesión de voz | Sin oír | Prueba automatizada | apps/mobile/test/voice/pantalla_manos_libres_test.dart, apps/mobile/test/voice/turno_test.dart |
| Accesibilidad de la sesión de voz | Sin hablar | Prueba automatizada | apps/mobile/test/voice/turno_test.dart |

## add-training-app-mvp · learning-path

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Jerarquía del contenido | Ruta con estados | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Jerarquía del contenido | Ruta sin conexión | Prueba automatizada | apps/mobile/test/home/inicio_test.dart |
| Acción principal única | Continuar | Prueba automatizada | apps/backoffice/src/auth/auth.test.tsx, apps/backoffice/src/screens/GamificationCatalogs.test.tsx, apps/mobile/integration_test/recorrido_test.dart, apps/mobile/test/account/cuenta_test.dart, apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/contenido/actualizacion_entre_sesiones_test.dart, apps/mobile/test/contenido/actualizador_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/onboarding/alta_test.dart, apps/mobile/test/session/correccion_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/fase2_motor_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/subscription/suscripcion_test.dart, apps/mobile/test/sync/sincronizador_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart, apps/mobile/test/voice/contenido_al_empezar_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Secuencia de lecciones de una unidad | Lección bloqueada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Secuencia de lecciones de una unidad | Lección mixta | Prueba automatizada | apps/mobile/test/session/fase2_motor_test.dart |
| Reto de unidad | Reto superado | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Reto de unidad | Reto no superado por un error crítico | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Reto de unidad | Saltar una unidad con el reto | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart |
| Dificultad adaptativa dentro de la lección | Subida de nivel | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Dificultad adaptativa dentro de la lección | Bajada de nivel con apoyo | Prueba automatizada | apps/mobile/test/session/motor_sesion_test.dart |
| Estados de dominio por habilidad | Habilidad consolidada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Estados de dominio por habilidad | Habilidad dominada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Estados de dominio por habilidad | Habilidad por refrescar | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Calentamiento de repaso | Sesión con repaso pendiente | Prueba automatizada | apps/mobile/test/home/inicio_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Calentamiento de repaso | Sesión sin repaso pendiente | Prueba automatizada | apps/mobile/test/home/inicio_test.dart, apps/mobile/test/session/motor_sesion_test.dart |

## add-training-app-mvp · offline-sync

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Entrenamiento completo sin conexión | Semana sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/sync/sincronizador_test.dart |
| Sincronización posterior del progreso | Recuperación de la conexión | Prueba automatizada | apps/mobile/test/sync/sincronizador_test.dart |
| Sincronización posterior del progreso | Envío repetido | Prueba automatizada | apps/mobile/test/sync/sincronizador_test.dart, services/api/test/api.test.ts |
| Sincronización posterior del progreso | Error de sincronización | Prueba automatizada | apps/mobile/test/sync/sincronizador_test.dart |
| Fusión del progreso entre dispositivos | Dos dispositivos sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/sync/sincronizador_test.dart, services/api/test/api.test.ts |
| Fusión del progreso entre dispositivos | Dispositivo nuevo | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart, apps/mobile/test/sync/sincronizador_test.dart |
| Paquetes de contenido verificados | Paquete válido | Prueba automatizada | apps/mobile/test/contenido/actualizador_test.dart, services/api/test/api.test.ts |
| Paquetes de contenido verificados | Paquete no válido | Prueba automatizada | apps/mobile/test/contenido/actualizador_test.dart, services/api/test/api.test.ts |
| Paquetes de contenido verificados | Descarga interrumpida | Prueba automatizada | apps/mobile/test/contenido/actualizador_test.dart, services/api/test/api.test.ts |
| Actualización de contenido entre sesiones | Contenido nuevo durante una lección | Prueba automatizada | apps/mobile/test/contenido/actualizacion_entre_sesiones_test.dart |
| Actualización de contenido entre sesiones | Contenido que exige una app más reciente | Prueba automatizada | apps/mobile/test/contenido/actualizador_test.dart |
| Retirada inmediata de ejercicios | Ejercicio retirado | Prueba automatizada | apps/mobile/test/contenido/actualizador_test.dart |
| Indicador de conexión no bloqueante | Pérdida de conexión | Prueba automatizada | apps/mobile/test/home/inicio_test.dart, apps/mobile/test/profile/perfil_test.dart |
| Acciones que requieren conexión | Compra sin conexión | Prueba automatizada | apps/mobile/test/subscription/suscripcion_test.dart |
| Acciones que requieren conexión | Crear la cuenta sin conexión | Prueba automatizada | apps/mobile/test/account/cuenta_test.dart |

## add-training-app-mvp · onboarding-account

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Alta en cuatro pasos | Elección de sector | Prueba automatizada | apps/mobile/test/onboarding/alta_test.dart |
| Alta en cuatro pasos | Continuar desactivado sin selección | Prueba automatizada | apps/mobile/integration_test/recorrido_test.dart, apps/mobile/test/onboarding/alta_test.dart |
| Alta en cuatro pasos | Alta sin conexión | Prueba automatizada | apps/mobile/test/onboarding/alta_test.dart |
| Prueba de nivel opcional | Unidades convalidadas | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/onboarding/alta_test.dart |
| Prueba de nivel opcional | Omitir la prueba | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/onboarding/alta_test.dart |
| Prueba de nivel opcional | Prueba interrumpida | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/onboarding/alta_test.dart |
| Registro después de la primera lección | Primera lección sin cuenta | Prueba automatizada | apps/mobile/test/onboarding/alta_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Registro después de la primera lección | Fusión al registrarse | Prueba automatizada | apps/mobile/test/account/cuenta_test.dart, apps/mobile/test/account/fusion_cuenta_test.dart, services/api/test/api.test.ts |
| Registro después de la primera lección | Registro pospuesto | Prueba automatizada | apps/mobile/test/profile/perfil_test.dart |
| Métodos de acceso | Código correcto | Prueba automatizada | apps/mobile/test/account/cuenta_test.dart, services/api/test/api.test.ts |
| Métodos de acceso | Código incorrecto | Prueba automatizada | apps/mobile/test/account/cuenta_test.dart, services/api/test/api.test.ts |
| Permisos pedidos en contexto | Micrófono denegado | Prueba automatizada | apps/mobile/test/voice/pantalla_manos_libres_test.dart |
| Permisos pedidos en contexto | Sin permisos al arrancar | Prueba automatizada | apps/mobile/test/onboarding/alta_test.dart |
| Gestión de datos personales | Exportación de datos | Prueba automatizada | apps/mobile/test/profile/perfil_test.dart, services/api/test/api.test.ts |
| Gestión de datos personales | Eliminación de la cuenta | Prueba automatizada | apps/backoffice/src/screens/People.test.tsx, apps/mobile/test/profile/perfil_test.dart, services/api/test/api.test.ts |
| Formulario de consulta | Aviso desde un ejercicio | Prueba automatizada | apps/mobile/test/inquiries/consultas_test.dart |
| Formulario de consulta | Envío sin conexión | Prueba automatizada | apps/mobile/test/inquiries/consultas_test.dart |
| Formulario de consulta | Aviso sobre consultas clínicas | Prueba automatizada | apps/mobile/test/inquiries/consultas_test.dart |

## add-training-app-mvp · spaced-review

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ficha de repaso | Variante nueva en el repaso | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Calificación automática | Acierto rápido | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Calificación automática | Acierto con pista | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Calificación automática | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart, apps/mobile/test/session/ejercicios_test.dart, apps/mobile/test/session/motor_sesion_test.dart, apps/mobile/test/voice/contenido_al_empezar_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart, apps/mobile/test/voice/turno_test.dart |
| Programación del siguiente repaso | Programación sin conexión | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Programación del siguiente repaso | Intervalo creciente | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Cuarentena de errores críticos | Error crítico | Prueba automatizada | apps/mobile/integration_test/recorrido_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/review/repaso_test.dart, apps/mobile/test/session/motor_sesion_test.dart |
| Cuarentena de errores críticos | Salida de la cuarentena | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Cola diaria de repaso | Tope por defecto | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/review/repaso_test.dart |
| Cola diaria de repaso | Orden de la cola | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/review/repaso_test.dart |
| Sesión de repaso | Ficha fallada en el repaso | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Sesión de repaso | Motivo de la ficha | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/session/fin_y_pausas_test.dart |
| Repaso sin fichas pendientes | Cola vacía | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/review/repaso_test.dart |

## add-training-app-mvp · time-trial

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Contrarreloj por habilidad consolidada | Habilidad sin consolidar | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Contrarreloj por habilidad consolidada | Sin ninguna habilidad consolidada | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Esprint de sesenta segundos | Acierto en el esprint | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Esprint de sesenta segundos | Esprint sin conexión | Prueba automatizada | apps/mobile/test/timetrial/contrarreloj_test.dart |
| Penalización por fallo | Fallo con 20 segundos restantes | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Marca válida con precisión mínima | Marca no válida | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Marca válida con precisión mínima | Récord | Prueba automatizada | apps/backoffice/e2e/flujo-publicacion.e2e.ts, apps/backoffice/src/realapi.smoke.test.tsx, apps/backoffice/src/screens/Import.test.tsx, apps/backoffice/src/screens/InsightsAudit.test.tsx, apps/backoffice/src/screens/Organizations.test.tsx, apps/backoffice/src/screens/People.test.tsx, apps/backoffice/src/screens/Publishing.test.tsx, apps/backoffice/src/screens/Review.test.tsx, apps/backoffice/src/screens/Structure.test.tsx, apps/backoffice/src/screens/template/TemplateEditor.test.tsx, apps/backoffice/src/test/helpers.tsx, apps/mobile/integration_test/recorrido_test.dart, apps/mobile/test/account/cuenta_test.dart, apps/mobile/test/ads/pausa_promocional_test.dart, apps/mobile/test/data/almacenes_drift_test.dart, apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/domain/league_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/home/inicio_test.dart, apps/mobile/test/leagues/ligas_test.dart, apps/mobile/test/onboarding/alta_test.dart, apps/mobile/test/profile/perfil_test.dart, apps/mobile/test/progress/progreso_test.dart, apps/mobile/test/subscription/suscripcion_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart, apps/mobile/test/voice/pantalla_manos_libres_test.dart, services/api/test/api.test.ts |
| La interrupción anula el esprint | Interrupción | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Variante sin cuenta atrás | Ejercicios sin límite de tiempo | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
| Los fallos pasan al repaso | Fallo en el esprint | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/timetrial/contrarreloj_test.dart |
