# Spec Delta

## Purpose

Define el funcionamiento sin conexión como norma: entrenamiento completo con el contenido descargado, progreso guardado en el dispositivo, sincronización posterior sin conflictos y distribución del contenido en paquetes firmados que no exigen una versión nueva de la app.

## ADDED Requirements

### Requirement: Entrenamiento completo sin conexión

La app MUST permitir hacer lecciones, repaso, contrarreloj y sesiones manos libres sin conexión, con el contenido y el paquete de voz ya descargados.

#### Scenario: Semana sin conexión

- **GIVEN** un dispositivo sin conexión durante 7 días con el itinerario descargado
- **WHEN** el usuario entrena cada día
- **THEN** lecciones, repaso, rachas y estadísticas funcionan y se actualizan en el dispositivo

### Requirement: Sincronización posterior del progreso

La app MUST guardar cada intento en el dispositivo y enviarlo al servidor cuando hay conexión, sin intervención del usuario y sin duplicados.

#### Scenario: Recuperación de la conexión

- **GIVEN** 120 intentos pendientes de envío
- **WHEN** el dispositivo recupera la conexión
- **THEN** los intentos se envían en segundo plano y el centro de sincronización muestra cero pendientes

#### Scenario: Envío repetido

- **WHEN** un lote de intentos se envía dos veces por un corte de red
- **THEN** el servidor conserva cada intento una sola vez

#### Scenario: Error de sincronización

- **WHEN** el envío falla
- **THEN** la app lo reintenta más tarde y muestra «No se ha podido sincronizar. Lo reintentaremos» sin interrumpir el entrenamiento

### Requirement: Fusión del progreso entre dispositivos

El progreso de un usuario MUST ser el mismo en todos sus dispositivos una vez sincronizados, aunque hayan entrenado sin conexión a la vez.

#### Scenario: Dos dispositivos sin conexión

- **GIVEN** un usuario que hace una lección en el móvil y otra en la tablet, ambos sin conexión
- **WHEN** los dos dispositivos se sincronizan
- **THEN** ambos muestran las dos lecciones, las mismas fichas de repaso y la misma racha

#### Scenario: Dispositivo nuevo

- **WHEN** el usuario inicia sesión en un dispositivo nuevo
- **THEN** recupera su progreso, sus fichas de repaso y sus estadísticas

### Requirement: Paquetes de contenido verificados

La app MUST descargar el contenido en paquetes por itinerario, verificar su integridad y su firma, y rechazar cualquier paquete que no las supere.

#### Scenario: Paquete válido

- **WHEN** la app descarga un paquete cuya firma es correcta
- **THEN** el contenido queda disponible sin conexión

#### Scenario: Paquete no válido

- **WHEN** la verificación de un paquete falla
- **THEN** la app lo descarta, conserva la versión anterior y reintenta la descarga

#### Scenario: Descarga interrumpida

- **WHEN** la conexión se corta a mitad de una descarga
- **THEN** la descarga se reanuda desde el punto alcanzado al volver la conexión

### Requirement: Actualización de contenido entre sesiones

La app MUST aplicar una versión nueva de contenido al empezar la siguiente sesión, nunca durante una sesión en curso.

#### Scenario: Contenido nuevo durante una lección

- **GIVEN** un usuario a mitad de una lección
- **WHEN** termina de descargarse una versión nueva del contenido
- **THEN** la lección continúa con la versión con la que empezó y la nueva se aplica en la sesión siguiente

#### Scenario: Contenido que exige una app más reciente

- **WHEN** el contenido nuevo requiere una versión de la app superior a la instalada
- **THEN** la app conserva el contenido compatible y muestra «Actualiza la app para ver el contenido nuevo»

### Requirement: Retirada inmediata de ejercicios

La app MUST dejar de presentar un ejercicio retirado en cuanto recibe la lista de retirada, sin esperar a una versión completa de contenido.

#### Scenario: Ejercicio retirado

- **GIVEN** una plantilla retirada por un error detectado tras su publicación
- **WHEN** el dispositivo se conecta y recibe la lista de retirada
- **THEN** esa plantilla deja de aparecer en lecciones y en repasos

### Requirement: Indicador de conexión no bloqueante

La app MUST indicar el estado sin conexión con un distintivo discreto y un aviso único al cambiar, sin bloquear ninguna función que pueda hacerse en el dispositivo.

#### Scenario: Pérdida de conexión

- **WHEN** el dispositivo pierde la conexión
- **THEN** aparece una vez el aviso «Sin conexión. Puedes seguir entrenando» y el distintivo queda visible en Inicio y en Perfil

### Requirement: Acciones que requieren conexión

Cuando una acción requiere conexión, la app MUST explicarlo y dejar la acción desactivada o en cola, según proceda.

#### Scenario: Compra sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario intenta suscribirse
- **THEN** la app explica que la compra requiere conexión

#### Scenario: Crear la cuenta sin conexión

- **GIVEN** el dispositivo sin conexión y un perfil local
- **WHEN** el usuario intenta crear su cuenta
- **THEN** la app explica que hace falta conexión y el progreso sigue guardándose en el perfil local
