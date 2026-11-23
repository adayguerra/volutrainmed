# Tareas pendientes del OpenSpec

Auditoría de las 158 tareas de los cuatro cambios (`volutrainmed-openspec/openspec/changes/*/tasks.md`) frente al código del repositorio, a 18 de noviembre de 2026.

## Totales

| Cambio | Hechas | Abiertas | Total |
| --- | --- | --- | --- |
| `add-training-app-mvp` | 44 | 12 | 56 |
| `add-house-ads-and-premium` | 24 | 15 | 39 |
| `add-content-backoffice` | 28 | 7 | 35 |
| `add-growth-features` | 18 | 10 | 28 |
| **Total** | **114** | **44** | **158** |

## Criterio

- Una tarea se marca como hecha solo si hay código real que la implementa y una prueba que lo ejercita.
- Se acepta simular el entorno (sin conexión, reloj). No se acepta simular aquello de lo que trata la tarea: reconocedor de voz, tienda, lector de pantalla o dispositivo.
- Una tarea implementada a medias sigue abierta, y la tabla indica qué falta.
- Las tareas de las secciones de pruebas que piden dispositivos, personas o inspección real siguen abiertas aunque exista una prueba automática parecida.

Pruebas ejecutadas durante la auditoría, todas en verde: motor (100), API contra Postgres (54), back office (102 y 7 omitidas, que requieren una API en marcha) y app Flutter (640 y 2 omitidas, que requieren `VTM_API_LIVE=1`). No se ejecutaron el recorrido de extremo a extremo del back office (`pnpm e2e:backoffice`), las pruebas de integración en dispositivo ni la integración continua.

Tipos de motivo: **No implementada**, **Parcial** (se indica qué falta) y **Externa** (requiere personas, dispositivos o servicios de terceros).

## add-training-app-mvp (12 abiertas)

| Tarea | Título | Por qué sigue abierta | Qué hace falta para cerrarla |
| --- | --- | --- | --- |
| 1.1 | Prueba técnica de voz | Externa. Solo existe el protocolo (`docs/voz/prueba-tecnica.md`) y el corpus de texto; no hay grabaciones ni medidas. | Grabar a 20 hablantes en silencio y con 65 dB en seis dispositivos y medir el acierto y la latencia por motor. |
| 1.2 | Decisión del motor de voz | Externa. Depende de las medidas de la 1.1; hoy se usa el reconocedor del sistema como solución provisional. | Resultados de la 1.1 y decisión documentada entre sherpa-onnx y Vosk. |
| 1.5 | Integración continua con pruebas de imagen | Parcial. `.github/workflows/ci.yml` está escrito, pero nunca se ha ejecutado (no hay remoto) y no hay pruebas de imagen: las pruebas por clase de tamaño son de widget, sin capturas de referencia. | Publicar el repositorio en GitHub, ver el flujo en verde y añadir pruebas de imagen (`matchesGoldenFile`) por clase de tamaño. |
| 3.4 | Acceso con código por correo, Apple y Google | Parcial. El código por correo funciona, pero solo llega al buzón de desarrollo (no hay proveedor de correo); Apple y Google solo aceptan tokens `dev:`. | Proveedor de correo transaccional, Sign in with Apple y Google Sign-In reales con verificación del token en el servidor. |
| 7.1 | Interfaz `MotorDeVoz` e integración del motor elegido | Parcial. La interfaz y un motor con el reconocedor del sistema en el dispositivo (`speech_to_text`) están hechos y probados con dobles; el motor elegido en el diseño (sherpa-onnx) no está integrado y nunca se ha probado con voz real. | Decisión de la 1.2, integración del motor embebido con su modelo y prueba en dispositivo. |
| 10.1 | Batería en modo avión | Parcial. Hay pruebas automáticas sin conexión de lección, repaso, contrarreloj y manos libres, pero con conectividad simulada y, en manos libres, con reconocedor y síntesis falsos. | Ejecutar la batería en dispositivos reales en modo avión, con el reconocimiento de voz real. |
| 10.2 | Inspección de red del módulo de voz | Externa. Las pruebas comprueban que el cliente HTTP no hace peticiones y que se fuerza el reconocimiento local, pero no hay una inspección de tráfico real. | Sesión de manos libres en iOS y Android tras un proxy de inspección, con el informe de tráfico. |
| 10.3 | Regresión de voz con las 500 locuciones | Parcial. Solo la capa de texto: el analizador interpreta las 500 locuciones generadas por guion. Falta la capa acústica. | Grabaciones de referencia de la 1.1 y su reproducción automática en el dispositivo de referencia. |
| 10.4 | Pruebas en móvil pequeño, grande y tablet, vertical y horizontal | Parcial. Las pruebas de widget cubren 390 × 844, tablet en horizontal y un caso de tablet en vertical; no hay móvil pequeño ni móvil en horizontal, ni ejecución en dispositivos o en emulador de Android (el APK solo se compila). | Ampliar la matriz de tamaños y ejecutar el recorrido en dispositivos o emuladores de iOS y Android. |
| 10.5 | Pruebas con lector de pantalla | Externa. Solo hay pruebas de semántica en widget. | Pasada manual con VoiceOver y TalkBack en dispositivos, con sus incidencias resueltas. |
| 10.6 | Validación por un profesional del contenido | Externa. Todo el contenido es de demostración; las validaciones de la semilla las firman cuentas de prueba. | Revisión y firma por profesionales acreditados de cada sector. |
| 10.7 | Revisión regulatoria y fichas de las tiendas | Externa. Existen los borradores (`docs/regulatorio/calificacion.md`, `docs/tiendas/fichas.md`), sin revisión jurídica ni envío a las tiendas. | Revisión por un especialista en regulación sanitaria y alta de las fichas en App Store Connect y Google Play. |

## add-house-ads-and-premium (15 abiertas)

| Tarea | Título | Por qué sigue abierta | Qué hace falta para cerrarla |
| --- | --- | --- | --- |
| 3.4 | Duración máxima de la cuña (4 s) | Parcial. La duración se estima a 3 palabras por segundo (`estimateSpotSeconds`); no se ha medido con la voz real del dispositivo. | Medir cada cuña con la síntesis por defecto en iOS y Android y ajustar la estimación. |
| 4.1 | Alta de productos en las dos tiendas | Externa. No hay productos en App Store Connect ni en Google Play. | Cuentas de desarrollador y alta de los planes mensual y anual con la prueba de 7 días. |
| 4.2 | Integración del proveedor de suscripciones | Parcial. La compra, la restauración y la validación pasan por la tienda de pruebas de la API (`/v1/store/*`, recibo `sandbox`); no hay StoreKit, Play Billing ni RevenueCat. | Integrar el proveedor real en la app y validar los recibos en el servidor. |
| 4.9 | Beneficios adicionales de Premium | Parcial. Solo está el límite diario de manos libres. `freeUnitsPerItinerary` no se usa en la app (la semilla lo deja en 99) y no hay distinción de estadísticas avanzadas. | Limitar itinerarios y estadísticas en el plan gratuito y abrirlos con Premium, con sus pruebas. |
| 5.1 | Pantalla de campañas | Parcial. Hay lista con segmento y vigencia y alta de campañas, pero el rendimiento es por anuncio (no por campaña) y no tiene prueba. | Rendimiento por campaña en la lista y prueba de la pantalla. |
| 5.2 | Editor de creatividad con vista previa y escucha | Parcial. El editor guarda la creatividad con sus comprobaciones, pero no tiene vista previa en móvil y tablet ni escucha de la cuña. | Añadir la vista previa de la tarjeta y la reproducción de la cuña. |
| 6.1 | Eventos de anuncios | Parcial. La app solo emite `ad_impression` y `ad_cta`; no emite `ad_continue`, `ad_voice_skipped` ni `ad_voice_more_info`, y el servidor cuenta `ad_cta_tapped`, un nombre que la app no usa. | Emitir los cinco eventos con los nombres de la especificación y probarlos. |
| 6.3 | Experimento de frecuencia y de espera | No implementada. No hay asignación de variantes ni métricas de guarda. | Asignación de experimento por dispositivo, parámetros por variante y panel con las métricas de guarda. |
| 6.4 | Panel de rendimiento por anuncio | Parcial. El panel y `/v1/admin/ads/performance` existen, pero los toques salen siempre a cero por el desajuste de nombres de la 6.1, y no hay pruebas. | Corregir el nombre del evento y añadir pruebas de la API y de la pantalla. |
| 7.1 | Lección completa en modo avión con anuncios | Parcial. La prueba automática comprueba una pausa sin conexión, no una lección completa en un dispositivo. | Lección completa en un dispositivo en modo avión, con sus capturas. |
| 7.2 | Inspección de red publicitaria | Externa. La prueba comprueba que no hay peticiones del cliente HTTP y no hay ningún SDK publicitario, pero falta la inspección de tráfico real. | Inspección con proxy de una compilación de iOS y de Android y revisión del manifiesto y de las etiquetas de privacidad. |
| 7.3 | Accesibilidad de la tarjeta de pausa | Externa. Hay pruebas de semántica, foco y movimiento reducido en widget; falta el lector de pantalla real. | Pasada con VoiceOver y TalkBack y con el texto al 200 % en dispositivo. |
| 7.4 | Compra, restauración, cancelación, caducidad y 31 días sin conexión | Parcial. Todo está probado contra la tienda de pruebas y con reloj simulado, no contra las tiendas reales. | Pruebas en los entornos de pruebas de Apple y de Google tras la 4.1 y la 4.2. |
| 7.5 | Sesión de manos libres con cuñas | Parcial. La máquina de turnos está probada con un reconocedor falso; nunca con voz real. | Sesión en dispositivo con el motor de voz real: cuña, salto por voz y «más información». |
| 7.6 | Revisión de los textos | Externa. Hay comprobación automática de términos vetados y de alusiones clínicas, pero no una revisión humana con la guía de tono. | Revisión y firma de los doce textos por la persona responsable de comunicación y de regulación. |

## add-content-backoffice (7 abiertas)

| Tarea | Título | Por qué sigue abierta | Qué hace falta para cerrarla |
| --- | --- | --- | --- |
| 5.6 | Construcción, firma y publicación en la red de distribución | Parcial. Los paquetes se construyen y se firman (Ed25519 y SHA-256), pero se sirven desde la propia API y Postgres; no hay almacenamiento ni red de distribución. | Infraestructura de producción (almacenamiento y red de distribución en la UE) y publicación de los paquetes en ella. |
| 5.8 | Paquete de prueba por código QR | Parcial. El back office genera el código y el QR, y la API lo respeta, pero la app no tiene forma de leer el QR ni de introducir el código (el cliente admite `testCode`, pero nada lo usa). | Pantalla o enlace `volutrainmed://paquete-prueba` en la app que aplique el código, con su prueba. |
| 7.1 | Prueba con usuarios no técnicos | Externa. No se ha hecho. | Sesiones con autores y revisores reales que creen, validen y publiquen una plantilla sin ayuda. |
| 7.2 | Publicación de extremo a extremo y recepción en la app | Parcial. El recorrido de extremo a extremo publica contra una API real, pero el dispositivo es un cliente HTTP; la prueba de la app contra la API se omite por defecto. | Recorrido único: publicar desde el back office y recibir el contenido en la app instalada, en la integración continua o en un dispositivo. |
| 7.3 | Retirada de un ejercicio y comprobación en un dispositivo | Parcial. La retirada está probada en la API y en la app por separado; no en un dispositivo. | Retirar un ejercicio y comprobar en un dispositivo que desaparece de lecciones y repasos. |
| 7.4 | Uso completo con teclado y con lector de pantalla | Parcial. Playwright comprueba axe y parte de la navegación con teclado; falta el lector de pantalla real. | Pasada completa con teclado y con VoiceOver o NVDA por todas las pantallas. |
| 7.5 | Validación por un profesional de las plantillas iniciales | Externa. Las plantillas son de demostración y las validan cuentas de prueba. | Revisión y firma por profesionales acreditados. |

## add-growth-features (10 abiertas)

| Tarea | Título | Por qué sigue abierta | Qué hace falta para cerrarla |
| --- | --- | --- | --- |
| 1.4 | Pestaña de ligas | Parcial. Hay alias y zonas rotuladas, y la fila propia se resalta con «(tú)», pero no queda fija al desplazar la lista. | Fijar la fila propia en la pantalla y probarlo. |
| 2.3 | Grupos, itinerarios e invitación masiva | Parcial. Los grupos y la asignación funcionan; las invitaciones se registran, pero el correo solo llega al buzón de desarrollo. | Proveedor de correo transaccional para enviar las invitaciones. |
| 2.8 | Contrato de encargo y revisión de protección de datos | Externa. No hay contrato ni revisión. | Redacción y revisión jurídica del contrato de encargo y de la evaluación de protección de datos. |
| 3.2 | Editor de tipos de ejercicio | Parcial. Tiene paleta de bloques, lista de pasos y propiedades; no tiene vista previa. | Vista previa del tipo en el editor, con su prueba. |
| 3.6 | Definición de T4, T5, T8 y T10 con el creador | No implementada. Esos tipos solo existen en fixtures de prueba de la app; no están creados en el back office ni en la semilla, y no hay plantillas suyas validadas. | Crear los cuatro tipos con el creador, sus plantillas y su validación por un profesional. |
| 4.1 | Semana completa de liga | Parcial. El inicio y el cierre de semana están probados en la API, y la liga sin conexión en la app, por separado; no hay una semana completa con usuarios sin conexión que sincronizan antes del cierre. | Prueba integrada de la semana completa o ensayo con usuarios reales. |
| 4.2 | Organización piloto | Externa. Solo hay una organización de demostración. | Piloto con una organización real: invitación, grupos, informe y modo nominal. |
| 4.3 | Tipo nuevo publicado sin versión de la app | Parcial. La creación del tipo (API y back office) y su interpretación en la app están probadas por separado; no hay un recorrido que cree, publique y reciba el tipo. | Recorrido de extremo a extremo: crear el tipo, publicarlo y recibirlo en una app compatible y en una antigua. |
| 4.4 | Lector de pantalla y tablet en las pantallas nuevas | Externa. Solo hay pruebas de widget. | Pasada con VoiceOver y TalkBack y en una tablet real. |
| 4.5 | Validación por un profesional de los tipos nuevos | Externa. No hay contenido de los tipos nuevos (véase la 3.6) ni profesionales que lo validen. | Contenido de T4, T5, T8 y T10 y su revisión por profesionales acreditados. |
