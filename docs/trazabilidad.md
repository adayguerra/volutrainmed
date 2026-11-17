# Trazabilidad de escenarios del OpenSpec

Generado con `python3 -I scripts/trazabilidad.py`. Una prueba cubre un escenario cuando su nombre contiene el nombre del escenario; el resto se anota a mano en `scripts/trazabilidad-manual.json`.

| Estado | Escenarios |
| --- | --- |
| Prueba automatizada | 171 |
| Sin evidencia automática | 161 |
| **Total** | **332** |

## add-content-backoffice · backoffice-administration

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Roles y permisos | Analista | Prueba automatizada | services/api/test/api.test.ts |
| Roles y permisos | Autor | Prueba automatizada | services/api/test/api.test.ts |
| Roles y permisos | Soporte | Prueba automatizada | services/api/test/api.test.ts |
| Doble factor obligatorio | Primer acceso | Prueba automatizada | services/api/test/api.test.ts |
| Registro de auditoría | Cambio de una fórmula | Prueba automatizada | services/api/test/api.test.ts |
| Registro de auditoría | Intento de alteración | Sin evidencia automática |  |
| Nada se borra | Retirar una pregunta | Sin evidencia automática |  |
| Panel de control por rol | Revisor | Prueba automatizada | services/api/test/api.test.ts |
| Panel de control por rol | Instalación nueva | Sin evidencia automática |  |
| Gestión de usuarios | Conceder días de Premium | Prueba automatizada | services/api/test/api.test.ts |
| Gestión de usuarios | Supresión de datos | Sin evidencia automática |  |
| Consultas de usuarios | Aviso de error en un ejercicio | Sin evidencia automática |  |
| Consultas de usuarios | Conversión en corrección | Sin evidencia automática |  |
| Consultas de usuarios | Consulta sobre un paciente | Prueba automatizada | services/api/test/api.test.ts |
| Catálogos compartidos | Nueva forma hablada | Sin evidencia automática |  |
| Catálogos compartidos | Prueba de interpretación | Sin evidencia automática |  |
| Analítica de contenido | Preguntas con más fallos | Sin evidencia automática |  |
| Analítica de contenido | Datos insuficientes | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Alertas de calidad | Plantilla demasiado difícil | Sin evidencia automática |  |
| Alertas de calidad | Error frecuente sin clasificar | Sin evidencia automática |  |

## add-content-backoffice · content-authoring

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Estructura del contenido editable | Nueva unidad | Prueba automatizada | services/api/test/api.test.ts |
| Estructura del contenido editable | Lección sin ejercicios | Prueba automatizada | services/api/test/api.test.ts |
| Estructura del contenido editable | Reordenar sin arrastrar | Prueba automatizada | services/api/test/api.test.ts |
| Plantillas parametrizadas | Plantilla de dosis por peso | Prueba automatizada | services/api/test/api.test.ts |
| Plantillas parametrizadas | Tabla de casos | Prueba automatizada | packages/engine/test/engine.test.ts |
| Comprobación dimensional de la fórmula | Unidades coherentes | Sin evidencia automática |  |
| Comprobación dimensional de la fórmula | Unidades incoherentes | Prueba automatizada | packages/engine/test/engine.test.ts, services/api/test/api.test.ts |
| Restricciones y errores previsibles | Resultado fuera de rango | Sin evidencia automática |  |
| Restricciones y errores previsibles | Error previsible de factor diez | Sin evidencia automática |  |
| Prueba masiva de variantes | Colisión detectada | Sin evidencia automática |  |
| Prueba masiva de variantes | Variantes insuficientes | Sin evidencia automática |  |
| Explicación y niveles de dificultad | Plantilla sin pasos | Prueba automatizada | packages/engine/test/engine.test.ts |
| Explicación y niveles de dificultad | Nivel con números limpios | Sin evidencia automática |  |
| Preguntas fijas | Pregunta de selección única | Sin evidencia automática |  |
| Preguntas fijas | Cantidad sin unidad | Sin evidencia automática |  |
| Texto para voz y vista previa con lectura | Escuchar un ejercicio | Sin evidencia automática |  |
| Texto para voz y vista previa con lectura | Simular una respuesta | Prueba automatizada | services/api/test/api.test.ts |
| Texto para voz y vista previa con lectura | Vista previa en tablet | Sin evidencia automática |  |
| Importación masiva | Fila con error | Sin evidencia automática |  |
| Importación masiva | Importación parcial | Prueba automatizada | services/api/test/api.test.ts |
| Creación sin código ni versión de la app | De la plantilla al dispositivo | Sin evidencia automática |  |

## add-content-backoffice · content-review-publishing

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ciclo de estados del contenido | Edición de un contenido publicado | Sin evidencia automática |  |
| Ciclo de estados del contenido | Cambios solicitados | Prueba automatizada | services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Autor que intenta validar lo suyo | Prueba automatizada | services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Revisor sin acreditación en el sector | Prueba automatizada | services/api/test/api.test.ts |
| Validación por un experto distinto del autor | Sector con doble revisión | Prueba automatizada | services/api/test/api.test.ts |
| Lista de comprobación del revisor | Lista incompleta | Prueba automatizada | services/api/test/api.test.ts |
| Lista de comprobación del revisor | Muestra de variantes | Prueba automatizada | services/api/test/api.test.ts |
| Firma y caducidad de la validación | Validación caducada | Sin evidencia automática |  |
| Firma y caducidad de la validación | Contenido modificado durante la revisión | Prueba automatizada | services/api/test/api.test.ts |
| Publicación solo de contenido validado | Elemento sin validar | Sin evidencia automática |  |
| Comprobaciones automáticas antes de publicar | Discrepancia en el doble cálculo | Sin evidencia automática |  |
| Comprobaciones automáticas antes de publicar | Comprobaciones superadas | Sin evidencia automática |  |
| Paquete firmado y despliegue gradual | Despliegue al 5 % | Prueba automatizada | services/api/test/api.test.ts |
| Paquete firmado y despliegue gradual | Compatibilidad con la app | Prueba automatizada | services/api/test/api.test.ts |
| Reversión | Reversión de una versión | Sin evidencia automática |  |
| Retirada inmediata de un ejercicio | Retirada de una plantilla con error | Sin evidencia automática |  |
| Paquete de prueba | Prueba en un dispositivo | Sin evidencia automática |  |

## add-growth-features · exercise-session

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos de ejercicio del producto mínimo viable | Respuesta numérica | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Completar el planteamiento | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Emparejar | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tipos de ejercicio del producto mínimo viable | Tipo de fase 2 sin conexión | Sin evidencia automática |  |

## add-growth-features · exercise-type-builder

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos como combinación de bloques | Tipo de dos pasos | Sin evidencia automática |  |
| Tipos como combinación de bloques | Paso sin bloque de respuesta | Prueba automatizada | services/api/test/api.test.ts |
| Tipos como combinación de bloques | Bloques sin arrastrar | Sin evidencia automática |  |
| Interpretación del tipo en la app | Tipo nuevo en una app ya instalada | Sin evidencia automática |  |
| Interpretación del tipo en la app | Tipo nuevo sin conexión | Sin evidencia automática |  |
| Versión mínima de la app por tipo | App antigua | Sin evidencia automática |  |
| Versión mínima de la app por tipo | Aviso antes de publicar | Sin evidencia automática |  |
| Compatibilidad con voz calculada | Tipo con un bloque de ordenar | Sin evidencia automática |  |
| Tipos en uso versionados | Cambio en un tipo en uso | Sin evidencia automática |  |
| Tipos de la fase 2 | Caso encadenado | Sin evidencia automática |  |
| Tipos de la fase 2 | Detectar el error | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |

## add-growth-features · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Logros fijos | Primera sesión manos libres | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Logros fijos | Logro configurado en el back office | Sin evidencia automática |  |
| Logros fijos | Logro obtenido sin conexión | Sin evidencia automática |  |

## add-growth-features · leagues

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ligas semanales por sector | Inicio de semana | Sin evidencia automática |  |
| Ligas semanales por sector | Ascenso y descenso | Sin evidencia automática |  |
| Puntuación por precisión | Tope diario | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/league_test.dart, services/api/test/api.test.ts |
| Puntuación por precisión | Marca de contrarreloj no válida | Prueba automatizada | apps/mobile/test/domain/league_test.dart |
| Alias y participación voluntaria | Clasificación con alias | Prueba automatizada | apps/mobile/test/domain/league_test.dart |
| Alias y participación voluntaria | Salida de las ligas | Prueba automatizada | services/api/test/api.test.ts |
| Clasificación sin conexión | Liga sin conexión | Prueba automatizada | apps/mobile/test/domain/league_test.dart |
| Cambios de reglas al inicio de semana | Cambio del tope diario | Prueba automatizada | services/api/test/api.test.ts |
| Detección de puntuaciones anómalas | Tiempos imposibles | Prueba automatizada | services/api/test/api.test.ts |
| Logros configurables | Logro de racha | Prueba automatizada | services/api/test/api.test.ts |
| Logros configurables | Prueba de la condición | Prueba automatizada | services/api/test/api.test.ts |

## add-growth-features · organizations

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Organizaciones con plazas | Plazas agotadas | Prueba automatizada | services/api/test/api.test.ts |
| Organizaciones con plazas | Vigencia terminada | Sin evidencia automática |  |
| Acceso por código o por dominio de correo | Código de invitación | Sin evidencia automática |  |
| Acceso por código o por dominio de correo | Dominio autorizado | Prueba automatizada | services/api/test/api.test.ts |
| Datos agregados por defecto | Informe de grupo | Sin evidencia automática |  |
| Datos agregados por defecto | Grupo pequeño | Prueba automatizada | services/api/test/api.test.ts |
| Modo nominal informado | Unión a una organización en modo nominal | Sin evidencia automática |  |
| Modo nominal informado | Qué ve la organización | Sin evidencia automática |  |
| Grupos e itinerarios asignados | Invitación masiva | Prueba automatizada | services/api/test/api.test.ts |
| Grupos e itinerarios asignados | Itinerario asignado | Sin evidencia automática |  |
| Ligas privadas | Liga de una promoción | Sin evidencia automática |  |
| Las plazas de organización eliminan los anuncios | Miembro de una organización | Sin evidencia automática |  |
| Las plazas de organización eliminan los anuncios | Miembro sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |

## add-house-ads-and-premium · house-ads

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Pausa promocional tras cada ejercicio | Respuesta correcta en una lección | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Pausa promocional tras cada ejercicio | Último ejercicio de la lección | Sin evidencia automática |  |
| La corrección va siempre antes | Respuesta incorrecta con explicación | Sin evidencia automática |  |
| La corrección va siempre antes | Error crítico con segundo intento | Sin evidencia automática |  |
| Formato de la pausa promocional | Elementos visibles | Sin evidencia automática |  |
| Formato de la pausa promocional | Tablet en horizontal | Sin evidencia automática |  |
| Espera configurable antes de continuar | Espera por defecto | Sin evidencia automática |  |
| Espera configurable antes de continuar | Espera desactivada | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Inventario propio y local | Modo avión | Sin evidencia automática |  |
| Inventario propio y local | Sin tráfico publicitario | Sin evidencia automática |  |
| Rotación de anuncios | Sin repetición consecutiva | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Rotación de anuncios | Tope diario alcanzado | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Anuncios activados por contexto | Racha de varios días | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Anuncios activados por contexto | Límite diario de manos libres agotado | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Exclusiones de la pausa promocional | Usuario con Premium | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Exclusiones de la pausa promocional | Primera lección | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Exclusiones de la pausa promocional | Contrarreloj | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/league_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart |
| Exclusiones de la pausa promocional | Prueba de nivel | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart |
| Cuña hablada en el modo manos libres | Cuña tras el veredicto | Sin evidencia automática |  |
| Cuña hablada en el modo manos libres | Saltar la cuña | Sin evidencia automática |  |
| Cuña hablada en el modo manos libres | Interés sin tocar la pantalla | Sin evidencia automática |  |
| El tiempo de anuncio no cuenta como práctica | Meta diaria de cinco minutos | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| El tiempo de anuncio no cuenta como práctica | Tiempo de respuesta | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Acción del anuncio | Toque en «Quitar anuncios» y vuelta | Sin evidencia automática |  |
| Acción del anuncio | Compra desde un anuncio | Sin evidencia automática |  |
| Publicidad honesta | Cifras calculadas con la configuración vigente | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Publicidad honesta | Texto con alusión clínica | Prueba automatizada | services/api/test/api.test.ts |
| Campañas sin publicar una versión de la app | Cambio de la espera | Sin evidencia automática |  |
| Campañas sin publicar una versión de la app | Campaña por sector | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Campañas sin publicar una versión de la app | Campaña caducada sin conexión | Prueba automatizada | apps/mobile/test/domain/ads_test.dart |
| Accesibilidad de la pausa promocional | Lector de pantalla | Prueba automatizada | packages/engine/test/engine.test.ts |
| Accesibilidad de la pausa promocional | Movimiento reducido | Sin evidencia automática |  |
| Medición de los anuncios | Impresión sin conexión | Sin evidencia automática |  |
| Medición de los anuncios | Conversión atribuida | Sin evidencia automática |  |

## add-house-ads-and-premium · premium-subscription

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Planes y prueba gratuita | Inicio de la prueba | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Planes y prueba gratuita | Prueba ya consumida | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Premium elimina los anuncios | Compra a mitad de lección | Sin evidencia automática |  |
| Premium elimina los anuncios | Lección completa con Premium | Sin evidencia automática |  |
| Beneficios adicionales de Premium | Límite de manos libres en el plan gratuito | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Beneficios adicionales de Premium | Manos libres con Premium | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Compra en la tienda y restauración | Restauración en un dispositivo nuevo | Sin evidencia automática |  |
| Compra en la tienda y restauración | Compra cancelada | Prueba automatizada | services/api/test/api.test.ts |
| Compra en la tienda y restauración | Compra fallida | Sin evidencia automática |  |
| Validez sin conexión | Dos semanas sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Validez sin conexión | Más de treinta días sin conexión | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Caducidad y cancelación | Cancelación a mitad de periodo | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Caducidad y cancelación | Suscripción caducada | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Transparencia de la oferta | Información antes de comprar | Sin evidencia automática |  |
| Transparencia de la oferta | Precios no disponibles | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Recordatorio antes del fin de la prueba | Aviso previo al cobro | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |
| Estado de la suscripción en Perfil | Usuario con plan anual | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart |

## add-training-app-mvp · adaptive-accessible-ui

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Disposición por clase de tamaño | Móvil | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, services/api/test/api.test.ts |
| Disposición por clase de tamaño | Tablet en horizontal | Sin evidencia automática |  |
| Disposición por clase de tamaño | Giro del dispositivo | Sin evidencia automática |  |
| Disposición por clase de tamaño | Disposición sin conexión | Sin evidencia automática |  |
| La tablet no estira el móvil | Sesión en tablet horizontal | Sin evidencia automática |  |
| La tablet no estira el móvil | Inicio en tablet horizontal | Sin evidencia automática |  |
| Hoja de borrador no persistente | Cambio de ejercicio | Sin evidencia automática |  |
| Contraste y color no exclusivo | Veredicto | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Contraste y color no exclusivo | Tema oscuro | Sin evidencia automática |  |
| Texto ampliable | Texto al 200 % | Sin evidencia automática |  |
| Objetivos táctiles | Icono pequeño | Sin evidencia automática |  |
| Compatibilidad con lector de pantalla | Lectura de una cantidad | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart |
| Compatibilidad con lector de pantalla | Anuncio del veredicto | Sin evidencia automática |  |
| Movimiento reducido | Fin de lección con movimiento reducido | Sin evidencia automática |  |
| Alternativa a los gestos | Ordenar pasos sin arrastrar | Sin evidencia automática |  |
| Alternativa a los gestos | Cerrar una hoja | Sin evidencia automática |  |
| Respuesta háptica y sonora configurable | Modo silencio | Sin evidencia automática |  |
| Respuesta háptica y sonora configurable | Háptica desactivada | Sin evidencia automática |  |

## add-training-app-mvp · answer-grading

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Aritmética decimal exacta | Suma de decimales | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tres veredictos | Más decimales de los pedidos | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tres veredictos | Formato inseguro | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tres veredictos | Respuesta incorrecta | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Redondeo indicado | Gota entera | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Redondeo indicado | Jeringa de 1 ml | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart, packages/engine/test/engine.test.ts |
| Unidades de la respuesta | Unidad equivalente | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Unidades de la respuesta | Unidad equivocada | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Diagnóstico del tipo de error | Factor diez | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Diagnóstico del tipo de error | Paso omitido | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Diagnóstico del tipo de error | Error sin clasificar | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Errores críticos | Desviación de factor cinco | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Errores críticos | Dosis máxima no aplicada | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Explicación paso a paso | Explicación de una perfusión | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Explicación paso a paso | Explicación a demanda tras un acierto | Sin evidencia automática |  |
| Segundo intento con otros números | Segundo intento acertado | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Corrección con valores verificados | Corrección en modo avión | Sin evidencia automática |  |

## add-training-app-mvp · exercise-session

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos de ejercicio del producto mínimo viable | Respuesta numérica | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Sin evidencia automática |  |
| Teclado numérico propio | Segunda coma | Sin evidencia automática |  |
| Teclado numérico propio | Teclado físico en tablet | Prueba automatizada | apps/mobile/test/domain/grading_fixtures_test.dart |
| Unidad de respuesta | Unidad fija | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Unidad de respuesta | Unidad a elegir | Sin evidencia automática |  |
| Respuesta «No lo sé» | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart |
| Sesión sin navegación y con salida confirmada | Salida a mitad de lección | Sin evidencia automática |  |
| Sesión sin navegación y con salida confirmada | Gesto de atrás | Sin evidencia automática |  |
| Pausa al pasar a segundo plano | Llamada entrante | Sin evidencia automática |  |
| Medida del tiempo de respuesta | Tiempo de un ejercicio | Sin evidencia automática |  |
| Lección preparada antes de empezar | Lección en modo avión | Sin evidencia automática |  |
| Lección preparada antes de empezar | Variante defectuosa | Sin evidencia automática |  |

## add-training-app-mvp · formative-boundary

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Solo casos simulados | No existe entrada libre de datos | Sin evidencia automática |  |
| Solo casos simulados | La respuesta del usuario solo se corrige | Sin evidencia automática |  |
| La pauta viene dada en el enunciado | Enunciado con pauta | Sin evidencia automática |  |
| La pauta viene dada en el enunciado | Límite de dosis como dato | Sin evidencia automática |  |
| Aviso formativo | Aceptación obligatoria en el alta | Sin evidencia automática |  |
| Aviso formativo | Aviso disponible en ajustes | Sin evidencia automática |  |
| Aviso formativo | Aviso sin conexión | Sin evidencia automática |  |
| Casos rotulados como simulados | Paciente simulado | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart |
| Casos rotulados como simulados | Principio activo | Sin evidencia automática |  |
| Comunicación sin uso clínico | Ficha de la tienda | Sin evidencia automática |  |
| Comunicación sin uso clínico | Texto con sugerencia de uso clínico | Sin evidencia automática |  |

## add-training-app-mvp · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Meta de práctica diaria o semanal | Meta diaria cumplida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Meta de práctica diaria o semanal | Meta semanal | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Racha | Racha extendida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Racha | Racha interrumpida | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Racha | Racha sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Puntos por aciertos al primer intento | Segundo intento | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart |
| Puntos por aciertos al primer intento | Acierto al primer intento | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart |
| Niveles | Subida de nivel | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Logros fijos | Primera sesión manos libres | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Fin de lección | Lección con fallos | Sin evidencia automática |  |
| Fin de lección | Cambio de estado de una habilidad | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Estadísticas por habilidad | Evolución de la precisión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Estadísticas por habilidad | Datos insuficientes | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Estadísticas por habilidad | Estadísticas sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Fallar no bloquea la práctica | Lección con muchos fallos | Sin evidencia automática |  |

## add-training-app-mvp · hands-free-voice

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Procesamiento íntegro en el dispositivo | Sesión en modo avión | Sin evidencia automática |  |
| Procesamiento íntegro en el dispositivo | Sin tráfico de voz | Sin evidencia automática |  |
| Sin almacenamiento de audio ni de transcripciones | Datos guardados de un intento por voz | Sin evidencia automática |  |
| Turno conversacional | Turno completo | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart |
| Turno conversacional | La pregunta va al final | Sin evidencia automática |  |
| Confirmación antes de corregir | Rechazo de lo entendido | Sin evidencia automática |  |
| Confirmación antes de corregir | Cifras que se confunden | Prueba automatizada | apps/mobile/test/domain/tts_fixtures_test.dart, packages/engine/test/engine.test.ts |
| Confirmación antes de corregir | Confirmación abreviada | Sin evidencia automática |  |
| Gramática de respuestas numéricas | Variantes de un mismo decimal | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Cero tras la coma | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Entero y medio | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Gramática de respuestas numéricas | Respuesta ambigua | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Unidades habladas | Unidad fija | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Unidades habladas | Miligramos o microgramos | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Unidades habladas | Sinónimo de sector | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Comandos de voz | Repite | Prueba automatizada | apps/mobile/test/domain/ads_test.dart, apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart |
| Comandos de voz | Pausa y continúa | Sin evidencia automática |  |
| Comandos de voz | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart |
| Comandos de voz | Salir | Prueba automatizada | apps/mobile/test/domain/spoken_fixtures_test.dart |
| Recuperación de errores de reconocimiento | Tercer fallo | Sin evidencia automática |  |
| Recuperación de errores de reconocimiento | El fallo de reconocimiento no penaliza | Sin evidencia automática |  |
| Recuperación de errores de reconocimiento | Silencio | Sin evidencia automática |  |
| Ruido ambiente | Entorno ruidoso | Sin evidencia automática |  |
| Uso con guantes o manos ocupadas | Toque en la pantalla | Sin evidencia automática |  |
| Uso con guantes o manos ocupadas | Botón de los auriculares | Sin evidencia automática |  |
| Paquete de voz bajo demanda | Sin paquete y sin conexión | Sin evidencia automática |  |
| Paquete de voz bajo demanda | Paquete alterado | Sin evidencia automática |  |
| Latencia del reconocimiento | Respuesta corta | Sin evidencia automática |  |
| Ejercicios compatibles con voz | Lección con un tipo no compatible | Sin evidencia automática |  |
| Accesibilidad de la sesión de voz | Sin oír | Sin evidencia automática |  |
| Accesibilidad de la sesión de voz | Sin hablar | Sin evidencia automática |  |

## add-training-app-mvp · learning-path

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Jerarquía del contenido | Ruta con estados | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Jerarquía del contenido | Ruta sin conexión | Sin evidencia automática |  |
| Acción principal única | Continuar | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Secuencia de lecciones de una unidad | Lección bloqueada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Secuencia de lecciones de una unidad | Lección mixta | Sin evidencia automática |  |
| Reto de unidad | Reto superado | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Reto de unidad | Reto no superado por un error crítico | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Reto de unidad | Saltar una unidad con el reto | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Dificultad adaptativa dentro de la lección | Subida de nivel | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Dificultad adaptativa dentro de la lección | Bajada de nivel con apoyo | Sin evidencia automática |  |
| Estados de dominio por habilidad | Habilidad consolidada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart |
| Estados de dominio por habilidad | Habilidad dominada | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Estados de dominio por habilidad | Habilidad por refrescar | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Calentamiento de repaso | Sesión con repaso pendiente | Sin evidencia automática |  |
| Calentamiento de repaso | Sesión sin repaso pendiente | Sin evidencia automática |  |

## add-training-app-mvp · offline-sync

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Entrenamiento completo sin conexión | Semana sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart |
| Sincronización posterior del progreso | Recuperación de la conexión | Sin evidencia automática |  |
| Sincronización posterior del progreso | Envío repetido | Prueba automatizada | services/api/test/api.test.ts |
| Sincronización posterior del progreso | Error de sincronización | Sin evidencia automática |  |
| Fusión del progreso entre dispositivos | Dos dispositivos sin conexión | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, services/api/test/api.test.ts |
| Fusión del progreso entre dispositivos | Dispositivo nuevo | Sin evidencia automática |  |
| Paquetes de contenido verificados | Paquete válido | Prueba automatizada | services/api/test/api.test.ts |
| Paquetes de contenido verificados | Paquete no válido | Prueba automatizada | services/api/test/api.test.ts |
| Paquetes de contenido verificados | Descarga interrumpida | Prueba automatizada | services/api/test/api.test.ts |
| Actualización de contenido entre sesiones | Contenido nuevo durante una lección | Sin evidencia automática |  |
| Actualización de contenido entre sesiones | Contenido que exige una app más reciente | Sin evidencia automática |  |
| Retirada inmediata de ejercicios | Ejercicio retirado | Sin evidencia automática |  |
| Indicador de conexión no bloqueante | Pérdida de conexión | Sin evidencia automática |  |
| Acciones que requieren conexión | Compra sin conexión | Sin evidencia automática |  |
| Acciones que requieren conexión | Crear la cuenta sin conexión | Sin evidencia automática |  |

## add-training-app-mvp · onboarding-account

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Alta en cuatro pasos | Elección de sector | Sin evidencia automática |  |
| Alta en cuatro pasos | Continuar desactivado sin selección | Sin evidencia automática |  |
| Alta en cuatro pasos | Alta sin conexión | Sin evidencia automática |  |
| Prueba de nivel opcional | Unidades convalidadas | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/progress/projections_test.dart |
| Prueba de nivel opcional | Omitir la prueba | Prueba automatizada | apps/mobile/test/domain/placement_test.dart |
| Prueba de nivel opcional | Prueba interrumpida | Prueba automatizada | apps/mobile/test/domain/placement_test.dart |
| Registro después de la primera lección | Primera lección sin cuenta | Sin evidencia automática |  |
| Registro después de la primera lección | Fusión al registrarse | Prueba automatizada | services/api/test/api.test.ts |
| Registro después de la primera lección | Registro pospuesto | Sin evidencia automática |  |
| Métodos de acceso | Código correcto | Prueba automatizada | services/api/test/api.test.ts |
| Métodos de acceso | Código incorrecto | Prueba automatizada | services/api/test/api.test.ts |
| Permisos pedidos en contexto | Micrófono denegado | Sin evidencia automática |  |
| Permisos pedidos en contexto | Sin permisos al arrancar | Sin evidencia automática |  |
| Gestión de datos personales | Exportación de datos | Prueba automatizada | services/api/test/api.test.ts |
| Gestión de datos personales | Eliminación de la cuenta | Prueba automatizada | services/api/test/api.test.ts |
| Formulario de consulta | Aviso desde un ejercicio | Sin evidencia automática |  |
| Formulario de consulta | Envío sin conexión | Sin evidencia automática |  |
| Formulario de consulta | Aviso sobre consultas clínicas | Sin evidencia automática |  |

## add-training-app-mvp · spaced-review

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ficha de repaso | Variante nueva en el repaso | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Calificación automática | Acierto rápido | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Calificación automática | Acierto con pista | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Calificación automática | No lo sé | Prueba automatizada | apps/mobile/test/domain/placement_test.dart, apps/mobile/test/domain/review/review_test.dart, apps/mobile/test/domain/spoken_fixtures_test.dart |
| Programación del siguiente repaso | Programación sin conexión | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Programación del siguiente repaso | Intervalo creciente | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Cuarentena de errores críticos | Error crítico | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/review/review_test.dart |
| Cuarentena de errores críticos | Salida de la cuarentena | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Cola diaria de repaso | Tope por defecto | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Cola diaria de repaso | Orden de la cola | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Sesión de repaso | Ficha fallada en el repaso | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Sesión de repaso | Motivo de la ficha | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
| Repaso sin fichas pendientes | Cola vacía | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |

## add-training-app-mvp · time-trial

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Contrarreloj por habilidad consolidada | Habilidad sin consolidar | Prueba automatizada | apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart |
| Contrarreloj por habilidad consolidada | Sin ninguna habilidad consolidada | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Esprint de sesenta segundos | Acierto en el esprint | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Esprint de sesenta segundos | Esprint sin conexión | Sin evidencia automática |  |
| Penalización por fallo | Fallo con 20 segundos restantes | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Marca válida con precisión mínima | Marca no válida | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Marca válida con precisión mínima | Récord | Prueba automatizada | apps/mobile/test/domain/entitlements_test.dart, apps/mobile/test/domain/league_test.dart, apps/mobile/test/domain/progress/projections_test.dart, apps/mobile/test/domain/timetrial_test.dart, services/api/test/api.test.ts |
| La interrupción anula el esprint | Interrupción | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Variante sin cuenta atrás | Ejercicios sin límite de tiempo | Prueba automatizada | apps/mobile/test/domain/timetrial_test.dart |
| Los fallos pasan al repaso | Fallo en el esprint | Prueba automatizada | apps/mobile/test/domain/review/review_test.dart |
