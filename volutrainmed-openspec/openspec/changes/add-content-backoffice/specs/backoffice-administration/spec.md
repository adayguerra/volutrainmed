# Spec Delta

## Purpose

Define la administración del back office: roles y permisos, seguridad de acceso, auditoría, panel de control, gestión de usuarios, consultas recibidas, catálogos compartidos y analítica de contenido.

## ADDED Requirements

### Requirement: Roles y permisos

El back office MUST aplicar siete roles con permisos distintos: superadministrador, administrador de contenido, autor, revisor experto, administrador de organización, analista y soporte.

#### Scenario: Analista

- **WHEN** un analista abre una plantilla
- **THEN** puede consultar su analítica y no puede editarla

#### Scenario: Autor

- **WHEN** un autor abre una plantilla creada por otro autor
- **THEN** puede verla y no puede modificarla

#### Scenario: Soporte

- **WHEN** un usuario de soporte abre la sección de publicación
- **THEN** no tiene acceso

### Requirement: Doble factor obligatorio

El back office MUST exigir un segundo factor de autenticación a todos sus usuarios.

#### Scenario: Primer acceso

- **WHEN** un usuario nuevo del back office inicia sesión por primera vez
- **THEN** debe configurar el segundo factor antes de acceder a ninguna sección

### Requirement: Registro de auditoría

El back office MUST registrar de forma inalterable quién hizo cada acción, cuándo y con qué valores anterior y posterior.

#### Scenario: Cambio de una fórmula

- **WHEN** un autor cambia la fórmula de una plantilla
- **THEN** el registro guarda el autor, la fecha, la fórmula anterior y la nueva

#### Scenario: Intento de alteración

- **WHEN** cualquier usuario, incluido un superadministrador, intenta modificar o borrar una entrada del registro
- **THEN** la operación no está disponible

### Requirement: Nada se borra

El back office MUST retirar y archivar el contenido en lugar de borrarlo.

#### Scenario: Retirar una pregunta

- **WHEN** un administrador retira una pregunta
- **THEN** deja de publicarse y permanece consultable en el archivo con su historial

### Requirement: Panel de control por rol

El panel de control MUST mostrar a cada usuario su trabajo pendiente y las alertas de calidad que le corresponden.

#### Scenario: Revisor

- **WHEN** un revisor abre el panel
- **THEN** ve primero las revisiones pendientes de sus sectores

#### Scenario: Instalación nueva

- **WHEN** el back office no tiene contenido
- **THEN** el panel muestra una guía de cinco pasos: sector, itinerario, plantilla, revisión y publicación

### Requirement: Gestión de usuarios

El back office MUST permitir buscar usuarios, consultar su plan y su progreso, y ejecutar acciones de soporte que exigen un motivo y quedan en auditoría.

#### Scenario: Conceder días de Premium

- **WHEN** un usuario de soporte concede 7 días de Premium a un usuario e indica el motivo
- **THEN** el usuario recibe el acceso y la acción queda en el registro de auditoría

#### Scenario: Supresión de datos

- **WHEN** se tramita la solicitud de eliminación de una cuenta
- **THEN** sus datos personales se suprimen o se anonimizan y la acción queda registrada

### Requirement: Consultas de usuarios

El back office MUST presentar las consultas recibidas con el ejercicio y la respuesta implicados, y permitir responderlas, convertirlas en una corrección de contenido o retirar el ejercicio.

#### Scenario: Aviso de error en un ejercicio

- **WHEN** llega una consulta de tipo «error en un ejercicio»
- **THEN** su ficha muestra la variante exacta y la respuesta que dio el usuario

#### Scenario: Conversión en corrección

- **WHEN** un administrador convierte una consulta en corrección de contenido
- **THEN** se crea un borrador de la plantilla enlazado con la consulta

#### Scenario: Consulta sobre un paciente

- **WHEN** llega una consulta sobre un paciente real
- **THEN** se responde con la respuesta modelo que la declina

### Requirement: Catálogos compartidos

El back office MUST mantener los catálogos de unidades, instrumentos y voz, y someter sus cambios al mismo ciclo de revisión y publicación que el contenido.

#### Scenario: Nueva forma hablada

- **WHEN** un administrador añade «gammas» como forma hablada de microgramos para el sector anestesia
- **THEN** el cambio queda en borrador hasta su revisión y llega a las apps con la siguiente publicación

#### Scenario: Prueba de interpretación

- **WHEN** un administrador escribe «doscientas gammas» en el cuadro de prueba del catálogo
- **THEN** ve la interpretación resultante, 200 µg

### Requirement: Analítica de contenido

El back office MUST mostrar por plantilla y por pregunta el número de respuestas, el acierto al primer intento, el tiempo mediano frente al objetivo, el porcentaje de «No lo sé», los errores críticos y el error más frecuente.

#### Scenario: Preguntas con más fallos

- **WHEN** un administrador ordena la tabla por acierto ascendente
- **THEN** ve primero las plantillas con más fallos

#### Scenario: Datos insuficientes

- **WHEN** una plantilla tiene menos de 50 respuestas
- **THEN** su analítica indica «Datos insuficientes»

### Requirement: Alertas de calidad

El back office MUST alertar cuando una plantilla tiene un acierto inferior al 40 % o superior al 98 %, más de un 25 % de «No lo sé», más de un 30 % de errores sin clasificar o un tiempo mediano superior al doble del objetivo.

#### Scenario: Plantilla demasiado difícil

- **WHEN** una plantilla con 200 respuestas tiene un 35 % de acierto
- **THEN** aparece en las alertas del panel de control

#### Scenario: Error frecuente sin clasificar

- **WHEN** una misma respuesta errónea sin clasificar se repite en una plantilla
- **THEN** el administrador puede añadirla como error previsible desde la ficha de analítica
