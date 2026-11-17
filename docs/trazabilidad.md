# Trazabilidad de escenarios del OpenSpec

Generado con `python3 -I scripts/trazabilidad.py`. Una prueba cubre un escenario cuando su nombre contiene el nombre del escenario; el resto se anota a mano en `scripts/trazabilidad-manual.json`.

| Estado | Escenarios |
| --- | --- |
| Sin evidencia automática | 278 |
| Prueba automatizada | 54 |
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
| Analítica de contenido | Datos insuficientes | Sin evidencia automática |  |
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
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Completar el planteamiento | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Emparejar | Sin evidencia automática |  |
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
| Tipos de la fase 2 | Detectar el error | Sin evidencia automática |  |

## add-growth-features · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Logros fijos | Primera sesión manos libres | Sin evidencia automática |  |
| Logros fijos | Logro configurado en el back office | Sin evidencia automática |  |
| Logros fijos | Logro obtenido sin conexión | Sin evidencia automática |  |

## add-growth-features · leagues

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Ligas semanales por sector | Inicio de semana | Sin evidencia automática |  |
| Ligas semanales por sector | Ascenso y descenso | Sin evidencia automática |  |
| Puntuación por precisión | Tope diario | Prueba automatizada | services/api/test/api.test.ts |
| Puntuación por precisión | Marca de contrarreloj no válida | Sin evidencia automática |  |
| Alias y participación voluntaria | Clasificación con alias | Sin evidencia automática |  |
| Alias y participación voluntaria | Salida de las ligas | Prueba automatizada | services/api/test/api.test.ts |
| Clasificación sin conexión | Liga sin conexión | Sin evidencia automática |  |
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
| Las plazas de organización eliminan los anuncios | Miembro sin conexión | Sin evidencia automática |  |

## add-house-ads-and-premium · house-ads

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Pausa promocional tras cada ejercicio | Respuesta correcta en una lección | Sin evidencia automática |  |
| Pausa promocional tras cada ejercicio | Último ejercicio de la lección | Sin evidencia automática |  |
| La corrección va siempre antes | Respuesta incorrecta con explicación | Sin evidencia automática |  |
| La corrección va siempre antes | Error crítico con segundo intento | Sin evidencia automática |  |
| Formato de la pausa promocional | Elementos visibles | Sin evidencia automática |  |
| Formato de la pausa promocional | Tablet en horizontal | Sin evidencia automática |  |
| Espera configurable antes de continuar | Espera por defecto | Sin evidencia automática |  |
| Espera configurable antes de continuar | Espera desactivada | Sin evidencia automática |  |
| Inventario propio y local | Modo avión | Sin evidencia automática |  |
| Inventario propio y local | Sin tráfico publicitario | Sin evidencia automática |  |
| Rotación de anuncios | Sin repetición consecutiva | Sin evidencia automática |  |
| Rotación de anuncios | Tope diario alcanzado | Sin evidencia automática |  |
| Anuncios activados por contexto | Racha de varios días | Sin evidencia automática |  |
| Anuncios activados por contexto | Límite diario de manos libres agotado | Sin evidencia automática |  |
| Exclusiones de la pausa promocional | Usuario con Premium | Sin evidencia automática |  |
| Exclusiones de la pausa promocional | Primera lección | Sin evidencia automática |  |
| Exclusiones de la pausa promocional | Contrarreloj | Sin evidencia automática |  |
| Exclusiones de la pausa promocional | Prueba de nivel | Sin evidencia automática |  |
| Cuña hablada en el modo manos libres | Cuña tras el veredicto | Sin evidencia automática |  |
| Cuña hablada en el modo manos libres | Saltar la cuña | Sin evidencia automática |  |
| Cuña hablada en el modo manos libres | Interés sin tocar la pantalla | Sin evidencia automática |  |
| El tiempo de anuncio no cuenta como práctica | Meta diaria de cinco minutos | Sin evidencia automática |  |
| El tiempo de anuncio no cuenta como práctica | Tiempo de respuesta | Sin evidencia automática |  |
| Acción del anuncio | Toque en «Quitar anuncios» y vuelta | Sin evidencia automática |  |
| Acción del anuncio | Compra desde un anuncio | Sin evidencia automática |  |
| Publicidad honesta | Cifras calculadas con la configuración vigente | Sin evidencia automática |  |
| Publicidad honesta | Texto con alusión clínica | Prueba automatizada | services/api/test/api.test.ts |
| Campañas sin publicar una versión de la app | Cambio de la espera | Sin evidencia automática |  |
| Campañas sin publicar una versión de la app | Campaña por sector | Sin evidencia automática |  |
| Campañas sin publicar una versión de la app | Campaña caducada sin conexión | Sin evidencia automática |  |
| Accesibilidad de la pausa promocional | Lector de pantalla | Prueba automatizada | packages/engine/test/engine.test.ts |
| Accesibilidad de la pausa promocional | Movimiento reducido | Sin evidencia automática |  |
| Medición de los anuncios | Impresión sin conexión | Sin evidencia automática |  |
| Medición de los anuncios | Conversión atribuida | Sin evidencia automática |  |

## add-house-ads-and-premium · premium-subscription

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Planes y prueba gratuita | Inicio de la prueba | Sin evidencia automática |  |
| Planes y prueba gratuita | Prueba ya consumida | Sin evidencia automática |  |
| Premium elimina los anuncios | Compra a mitad de lección | Sin evidencia automática |  |
| Premium elimina los anuncios | Lección completa con Premium | Sin evidencia automática |  |
| Beneficios adicionales de Premium | Límite de manos libres en el plan gratuito | Sin evidencia automática |  |
| Beneficios adicionales de Premium | Manos libres con Premium | Sin evidencia automática |  |
| Compra en la tienda y restauración | Restauración en un dispositivo nuevo | Sin evidencia automática |  |
| Compra en la tienda y restauración | Compra cancelada | Prueba automatizada | services/api/test/api.test.ts |
| Compra en la tienda y restauración | Compra fallida | Sin evidencia automática |  |
| Validez sin conexión | Dos semanas sin conexión | Sin evidencia automática |  |
| Validez sin conexión | Más de treinta días sin conexión | Sin evidencia automática |  |
| Caducidad y cancelación | Cancelación a mitad de periodo | Sin evidencia automática |  |
| Caducidad y cancelación | Suscripción caducada | Sin evidencia automática |  |
| Transparencia de la oferta | Información antes de comprar | Sin evidencia automática |  |
| Transparencia de la oferta | Precios no disponibles | Sin evidencia automática |  |
| Recordatorio antes del fin de la prueba | Aviso previo al cobro | Sin evidencia automática |  |
| Estado de la suscripción en Perfil | Usuario con plan anual | Sin evidencia automática |  |

## add-training-app-mvp · adaptive-accessible-ui

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Disposición por clase de tamaño | Móvil | Prueba automatizada | services/api/test/api.test.ts |
| Disposición por clase de tamaño | Tablet en horizontal | Sin evidencia automática |  |
| Disposición por clase de tamaño | Giro del dispositivo | Sin evidencia automática |  |
| Disposición por clase de tamaño | Disposición sin conexión | Sin evidencia automática |  |
| La tablet no estira el móvil | Sesión en tablet horizontal | Sin evidencia automática |  |
| La tablet no estira el móvil | Inicio en tablet horizontal | Sin evidencia automática |  |
| Hoja de borrador no persistente | Cambio de ejercicio | Sin evidencia automática |  |
| Contraste y color no exclusivo | Veredicto | Sin evidencia automática |  |
| Contraste y color no exclusivo | Tema oscuro | Sin evidencia automática |  |
| Texto ampliable | Texto al 200 % | Sin evidencia automática |  |
| Objetivos táctiles | Icono pequeño | Sin evidencia automática |  |
| Compatibilidad con lector de pantalla | Lectura de una cantidad | Sin evidencia automática |  |
| Compatibilidad con lector de pantalla | Anuncio del veredicto | Sin evidencia automática |  |
| Movimiento reducido | Fin de lección con movimiento reducido | Sin evidencia automática |  |
| Alternativa a los gestos | Ordenar pasos sin arrastrar | Sin evidencia automática |  |
| Alternativa a los gestos | Cerrar una hoja | Sin evidencia automática |  |
| Respuesta háptica y sonora configurable | Modo silencio | Sin evidencia automática |  |
| Respuesta háptica y sonora configurable | Háptica desactivada | Sin evidencia automática |  |

## add-training-app-mvp · answer-grading

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Aritmética decimal exacta | Suma de decimales | Sin evidencia automática |  |
| Tres veredictos | Más decimales de los pedidos | Sin evidencia automática |  |
| Tres veredictos | Formato inseguro | Sin evidencia automática |  |
| Tres veredictos | Respuesta incorrecta | Sin evidencia automática |  |
| Redondeo indicado | Gota entera | Sin evidencia automática |  |
| Redondeo indicado | Jeringa de 1 ml | Prueba automatizada | packages/engine/test/engine.test.ts |
| Unidades de la respuesta | Unidad equivalente | Sin evidencia automática |  |
| Unidades de la respuesta | Unidad equivocada | Sin evidencia automática |  |
| Diagnóstico del tipo de error | Factor diez | Sin evidencia automática |  |
| Diagnóstico del tipo de error | Paso omitido | Sin evidencia automática |  |
| Diagnóstico del tipo de error | Error sin clasificar | Sin evidencia automática |  |
| Errores críticos | Desviación de factor cinco | Sin evidencia automática |  |
| Errores críticos | Dosis máxima no aplicada | Sin evidencia automática |  |
| Explicación paso a paso | Explicación de una perfusión | Sin evidencia automática |  |
| Explicación paso a paso | Explicación a demanda tras un acierto | Sin evidencia automática |  |
| Segundo intento con otros números | Segundo intento acertado | Sin evidencia automática |  |
| Corrección con valores verificados | Corrección en modo avión | Sin evidencia automática |  |

## add-training-app-mvp · exercise-session

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Tipos de ejercicio del producto mínimo viable | Respuesta numérica | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Selección única con opciones diagnósticas | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Ordenar pasos con equivalencias | Sin evidencia automática |  |
| Tipos de ejercicio del producto mínimo viable | Conversión relámpago | Sin evidencia automática |  |
| Teclado numérico propio | Segunda coma | Sin evidencia automática |  |
| Teclado numérico propio | Teclado físico en tablet | Sin evidencia automática |  |
| Unidad de respuesta | Unidad fija | Sin evidencia automática |  |
| Unidad de respuesta | Unidad a elegir | Sin evidencia automática |  |
| Respuesta «No lo sé» | No lo sé | Sin evidencia automática |  |
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
| Casos rotulados como simulados | Paciente simulado | Sin evidencia automática |  |
| Casos rotulados como simulados | Principio activo | Sin evidencia automática |  |
| Comunicación sin uso clínico | Ficha de la tienda | Sin evidencia automática |  |
| Comunicación sin uso clínico | Texto con sugerencia de uso clínico | Sin evidencia automática |  |

## add-training-app-mvp · gamification-progress

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Meta de práctica diaria o semanal | Meta diaria cumplida | Sin evidencia automática |  |
| Meta de práctica diaria o semanal | Meta semanal | Sin evidencia automática |  |
| Racha | Racha extendida | Sin evidencia automática |  |
| Racha | Racha interrumpida | Sin evidencia automática |  |
| Racha | Racha sin conexión | Sin evidencia automática |  |
| Puntos por aciertos al primer intento | Segundo intento | Sin evidencia automática |  |
| Puntos por aciertos al primer intento | Acierto al primer intento | Sin evidencia automática |  |
| Niveles | Subida de nivel | Sin evidencia automática |  |
| Logros fijos | Primera sesión manos libres | Sin evidencia automática |  |
| Fin de lección | Lección con fallos | Sin evidencia automática |  |
| Fin de lección | Cambio de estado de una habilidad | Sin evidencia automática |  |
| Estadísticas por habilidad | Evolución de la precisión | Sin evidencia automática |  |
| Estadísticas por habilidad | Datos insuficientes | Sin evidencia automática |  |
| Estadísticas por habilidad | Estadísticas sin conexión | Sin evidencia automática |  |
| Fallar no bloquea la práctica | Lección con muchos fallos | Sin evidencia automática |  |

## add-training-app-mvp · hands-free-voice

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Procesamiento íntegro en el dispositivo | Sesión en modo avión | Sin evidencia automática |  |
| Procesamiento íntegro en el dispositivo | Sin tráfico de voz | Sin evidencia automática |  |
| Sin almacenamiento de audio ni de transcripciones | Datos guardados de un intento por voz | Sin evidencia automática |  |
| Turno conversacional | Turno completo | Sin evidencia automática |  |
| Turno conversacional | La pregunta va al final | Sin evidencia automática |  |
| Confirmación antes de corregir | Rechazo de lo entendido | Sin evidencia automática |  |
| Confirmación antes de corregir | Cifras que se confunden | Prueba automatizada | packages/engine/test/engine.test.ts |
| Confirmación antes de corregir | Confirmación abreviada | Sin evidencia automática |  |
| Gramática de respuestas numéricas | Variantes de un mismo decimal | Sin evidencia automática |  |
| Gramática de respuestas numéricas | Cero tras la coma | Sin evidencia automática |  |
| Gramática de respuestas numéricas | Entero y medio | Sin evidencia automática |  |
| Gramática de respuestas numéricas | Respuesta ambigua | Sin evidencia automática |  |
| Unidades habladas | Unidad fija | Sin evidencia automática |  |
| Unidades habladas | Miligramos o microgramos | Sin evidencia automática |  |
| Unidades habladas | Sinónimo de sector | Sin evidencia automática |  |
| Comandos de voz | Repite | Sin evidencia automática |  |
| Comandos de voz | Pausa y continúa | Sin evidencia automática |  |
| Comandos de voz | No lo sé | Sin evidencia automática |  |
| Comandos de voz | Salir | Sin evidencia automática |  |
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
| Jerarquía del contenido | Ruta con estados | Sin evidencia automática |  |
| Jerarquía del contenido | Ruta sin conexión | Sin evidencia automática |  |
| Acción principal única | Continuar | Sin evidencia automática |  |
| Secuencia de lecciones de una unidad | Lección bloqueada | Sin evidencia automática |  |
| Secuencia de lecciones de una unidad | Lección mixta | Sin evidencia automática |  |
| Reto de unidad | Reto superado | Sin evidencia automática |  |
| Reto de unidad | Reto no superado por un error crítico | Sin evidencia automática |  |
| Reto de unidad | Saltar una unidad con el reto | Sin evidencia automática |  |
| Dificultad adaptativa dentro de la lección | Subida de nivel | Sin evidencia automática |  |
| Dificultad adaptativa dentro de la lección | Bajada de nivel con apoyo | Sin evidencia automática |  |
| Estados de dominio por habilidad | Habilidad consolidada | Sin evidencia automática |  |
| Estados de dominio por habilidad | Habilidad dominada | Sin evidencia automática |  |
| Estados de dominio por habilidad | Habilidad por refrescar | Sin evidencia automática |  |
| Calentamiento de repaso | Sesión con repaso pendiente | Sin evidencia automática |  |
| Calentamiento de repaso | Sesión sin repaso pendiente | Sin evidencia automática |  |

## add-training-app-mvp · offline-sync

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Entrenamiento completo sin conexión | Semana sin conexión | Sin evidencia automática |  |
| Sincronización posterior del progreso | Recuperación de la conexión | Sin evidencia automática |  |
| Sincronización posterior del progreso | Envío repetido | Prueba automatizada | services/api/test/api.test.ts |
| Sincronización posterior del progreso | Error de sincronización | Sin evidencia automática |  |
| Fusión del progreso entre dispositivos | Dos dispositivos sin conexión | Prueba automatizada | services/api/test/api.test.ts |
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
| Prueba de nivel opcional | Unidades convalidadas | Sin evidencia automática |  |
| Prueba de nivel opcional | Omitir la prueba | Sin evidencia automática |  |
| Prueba de nivel opcional | Prueba interrumpida | Sin evidencia automática |  |
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
| Ficha de repaso | Variante nueva en el repaso | Sin evidencia automática |  |
| Calificación automática | Acierto rápido | Sin evidencia automática |  |
| Calificación automática | Acierto con pista | Sin evidencia automática |  |
| Calificación automática | No lo sé | Sin evidencia automática |  |
| Programación del siguiente repaso | Programación sin conexión | Sin evidencia automática |  |
| Programación del siguiente repaso | Intervalo creciente | Sin evidencia automática |  |
| Cuarentena de errores críticos | Error crítico | Sin evidencia automática |  |
| Cuarentena de errores críticos | Salida de la cuarentena | Sin evidencia automática |  |
| Cola diaria de repaso | Tope por defecto | Sin evidencia automática |  |
| Cola diaria de repaso | Orden de la cola | Sin evidencia automática |  |
| Sesión de repaso | Ficha fallada en el repaso | Sin evidencia automática |  |
| Sesión de repaso | Motivo de la ficha | Sin evidencia automática |  |
| Repaso sin fichas pendientes | Cola vacía | Sin evidencia automática |  |

## add-training-app-mvp · time-trial

| Requisito | Escenario | Estado | Evidencia |
| --- | --- | --- | --- |
| Contrarreloj por habilidad consolidada | Habilidad sin consolidar | Sin evidencia automática |  |
| Contrarreloj por habilidad consolidada | Sin ninguna habilidad consolidada | Sin evidencia automática |  |
| Esprint de sesenta segundos | Acierto en el esprint | Sin evidencia automática |  |
| Esprint de sesenta segundos | Esprint sin conexión | Sin evidencia automática |  |
| Penalización por fallo | Fallo con 20 segundos restantes | Sin evidencia automática |  |
| Marca válida con precisión mínima | Marca no válida | Sin evidencia automática |  |
| Marca válida con precisión mínima | Récord | Prueba automatizada | services/api/test/api.test.ts |
| La interrupción anula el esprint | Interrupción | Sin evidencia automática |  |
| Variante sin cuenta atrás | Ejercicios sin límite de tiempo | Sin evidencia automática |  |
| Los fallos pasan al repaso | Fallo en el esprint | Sin evidencia automática |  |
