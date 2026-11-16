# Spec Delta

## Purpose

Cubre la entrada al producto y la relación del usuario con su cuenta: alta, elección de sector y nivel, prueba de nivel, registro, permisos, perfil, gestión de datos personales y formulario de consulta.

## ADDED Requirements

### Requirement: Alta en cuatro pasos

La app MUST guiar al usuario nuevo por cuatro pasos, uno por pantalla: sector, nivel declarado, meta de práctica y aviso formativo.

#### Scenario: Elección de sector

- **WHEN** el usuario elige el sector «Veterinaria» y continúa
- **THEN** la app propone el itinerario más habitual de ese sector

#### Scenario: Continuar desactivado sin selección

- **WHEN** el usuario no ha elegido ninguna opción en un paso
- **THEN** la acción «Continuar» permanece desactivada

#### Scenario: Alta sin conexión

- **GIVEN** el dispositivo sin conexión en el primer arranque
- **WHEN** el usuario completa los cuatro pasos
- **THEN** puede empezar con la primera unidad de Fundamentos, incluida en la app

### Requirement: Prueba de nivel opcional

La app MUST ofrecer una prueba de nivel adaptativa de 8 a 12 ejercicios que convalida unidades, sin mostrar correcciones durante la prueba y con la opción de omitirla.

#### Scenario: Unidades convalidadas

- **WHEN** el usuario termina la prueba acertando los ejercicios de las tres primeras unidades
- **THEN** el resultado marca esas unidades como convalidadas y propone empezar en la cuarta

#### Scenario: Omitir la prueba

- **WHEN** el usuario elige empezar por el principio
- **THEN** la ruta comienza en la primera unidad sin convalidaciones

#### Scenario: Prueba interrumpida

- **WHEN** el usuario cierra la app a mitad de la prueba y vuelve
- **THEN** la prueba se reanuda en la pregunta en la que la dejó

### Requirement: Registro después de la primera lección

La app MUST permitir completar la primera lección sin cuenta, guardando el progreso en un perfil local, y fusionar ese progreso al crear la cuenta.

#### Scenario: Primera lección sin cuenta

- **WHEN** un usuario nuevo termina el alta
- **THEN** accede a la primera lección sin que se le pida correo ni contraseña

#### Scenario: Fusión al registrarse

- **GIVEN** un perfil local con tres lecciones completadas
- **WHEN** el usuario crea su cuenta
- **THEN** las tres lecciones aparecen en la cuenta y en cualquier otro dispositivo donde inicie sesión

#### Scenario: Registro pospuesto

- **WHEN** el usuario elige «Ahora no» al ofrecerle crear la cuenta
- **THEN** sigue entrenando con el perfil local y el perfil muestra un recordatorio para crearla

### Requirement: Métodos de acceso

La app MUST permitir el acceso con un código de un solo uso enviado por correo, con la cuenta de Apple y con la cuenta de Google.

#### Scenario: Código correcto

- **WHEN** el usuario introduce el código de seis cifras recibido
- **THEN** la sesión se inicia al completar la sexta cifra

#### Scenario: Código incorrecto

- **WHEN** el usuario introduce un código erróneo
- **THEN** la app lo indica junto al campo y permite pedir otro sin borrar el correo escrito

### Requirement: Permisos pedidos en contexto

La app MUST solicitar el permiso de notificaciones tras la primera lección y el de micrófono al entrar por primera vez en el modo manos libres, cada uno con su motivo, y funcionar sin ninguno de los dos.

#### Scenario: Micrófono denegado

- **WHEN** el usuario deniega el permiso de micrófono
- **THEN** la app ofrece el modo táctil y explica cómo activar el permiso más adelante

#### Scenario: Sin permisos al arrancar

- **WHEN** un usuario abre la app por primera vez
- **THEN** no se le solicita ningún permiso del sistema antes de la primera lección

### Requirement: Gestión de datos personales

La app MUST permitir al usuario exportar sus datos y eliminar su cuenta desde el perfil.

#### Scenario: Exportación de datos

- **WHEN** el usuario solicita la exportación de sus datos
- **THEN** recibe confirmación de la solicitud y, cuando está lista, un archivo con su perfil y su historial de aprendizaje

#### Scenario: Eliminación de la cuenta

- **WHEN** el usuario solicita eliminar su cuenta y lo confirma por escrito
- **THEN** la cuenta se cierra y sus datos personales se suprimen o se anonimizan

### Requirement: Formulario de consulta

La app MUST ofrecer un formulario para avisar de errores en un ejercicio, plantear dudas sobre una explicación o sobre la app y sugerir contenido, con un aviso fijo de que no se atienden consultas sobre pacientes.

#### Scenario: Aviso desde un ejercicio

- **WHEN** el usuario toca «Informar de un error en este ejercicio»
- **THEN** el formulario se abre con el ejercicio, la variante y su respuesta ya adjuntos

#### Scenario: Envío sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario envía una consulta
- **THEN** queda como pendiente de envío y se envía al recuperar la conexión

#### Scenario: Aviso sobre consultas clínicas

- **WHEN** el usuario abre el formulario
- **THEN** ve el texto «No respondemos consultas sobre pacientes ni tratamientos»
