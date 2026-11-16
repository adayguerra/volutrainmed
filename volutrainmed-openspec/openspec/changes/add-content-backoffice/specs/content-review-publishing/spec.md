# Spec Delta

## Purpose

Define el camino de un contenido desde el borrador hasta el dispositivo del usuario: validación por un experto distinto del autor, versionado, comprobaciones automáticas, publicación en paquetes firmados, despliegue gradual, reversión y retirada inmediata.

## ADDED Requirements

### Requirement: Ciclo de estados del contenido

Todo contenido MUST pasar por los estados borrador, en revisión, cambios solicitados, validado, publicado y retirado, y cada cambio sobre un contenido publicado MUST crear una versión nueva en borrador.

#### Scenario: Edición de un contenido publicado

- **WHEN** un autor modifica una plantilla publicada
- **THEN** se crea una versión nueva en borrador y la versión publicada sigue llegando a los usuarios

#### Scenario: Cambios solicitados

- **WHEN** un revisor solicita cambios con un comentario
- **THEN** el contenido vuelve al autor en estado «cambios solicitados» con el comentario visible

### Requirement: Validación por un experto distinto del autor

Solo un revisor experto acreditado en el sector del contenido MUST poder validarlo, y nunca su propio autor.

#### Scenario: Autor que intenta validar lo suyo

- **WHEN** el autor de una plantilla, que también es revisor, abre su ficha de revisión
- **THEN** la acción «Validar» no está disponible

#### Scenario: Revisor sin acreditación en el sector

- **WHEN** un revisor acreditado solo en enfermería abre una plantilla de veterinaria
- **THEN** puede comentar y no puede validar

#### Scenario: Sector con doble revisión

- **GIVEN** el sector pediatría configurado con dos revisores
- **WHEN** un solo revisor valida una plantilla de pediatría
- **THEN** la plantilla sigue en revisión hasta la segunda validación

### Requirement: Lista de comprobación del revisor

La validación MUST exigir que el revisor complete una lista de comprobación: pauta plausible, presentación existente, unidades correctas, aritmética verificada, redondeo adecuado al instrumento, explicación clara, texto para voz correcto y errores previsibles pertinentes.

#### Scenario: Lista incompleta

- **WHEN** el revisor intenta validar con un punto de la lista sin marcar
- **THEN** la validación no se registra

#### Scenario: Muestra de variantes

- **WHEN** el revisor abre una plantilla
- **THEN** ve 20 variantes al azar, las de valores extremos y el recálculo independiente junto a cada respuesta

### Requirement: Firma y caducidad de la validación

Cada validación MUST registrar revisor, acreditación, fecha y versión validada, y caducar a los 24 meses o al marcarse un cambio en la información del fármaco.

#### Scenario: Validación caducada

- **WHEN** pasan 24 meses desde la validación de una plantilla
- **THEN** la plantilla vuelve a la bandeja de revisión y aparece en las alertas del panel

#### Scenario: Contenido modificado durante la revisión

- **WHEN** el autor modifica una plantilla mientras está en revisión
- **THEN** el revisor ve las diferencias y la lista de comprobación se reinicia

### Requirement: Publicación solo de contenido validado

Una versión de contenido MUST incluir únicamente elementos validados y vigentes.

#### Scenario: Elemento sin validar

- **WHEN** un administrador prepara una versión
- **THEN** los elementos no validados aparecen atenuados con su motivo y no pueden incluirse

### Requirement: Comprobaciones automáticas antes de publicar

Antes de publicar, el sistema MUST generar las variantes de cada plantilla, recalcularlas con un segundo cálculo independiente y bloquear la publicación ante cualquier discrepancia, colisión o elemento sin explicación o sin texto para voz.

#### Scenario: Discrepancia en el doble cálculo

- **WHEN** el segundo cálculo de una variante no coincide con el primero
- **THEN** la publicación se bloquea y se enlaza la plantilla afectada

#### Scenario: Comprobaciones superadas

- **WHEN** todas las comprobaciones se superan
- **THEN** la acción «Publicar» queda disponible

### Requirement: Paquete firmado y despliegue gradual

La publicación MUST producir un paquete firmado por itinerario y permitir desplegarlo de forma gradual al 5 %, al 50 % y al 100 % de los dispositivos.

#### Scenario: Despliegue al 5 %

- **WHEN** un administrador publica una versión al 5 %
- **THEN** uno de cada veinte dispositivos, aproximadamente, la recibe y el resto conserva la versión anterior

#### Scenario: Compatibilidad con la app

- **WHEN** una versión incluye contenido que exige una versión mínima de la app
- **THEN** el back office muestra el porcentaje de dispositivos activos que la admite antes de publicar

### Requirement: Reversión

El back office MUST permitir volver a la versión de contenido anterior con una sola acción.

#### Scenario: Reversión de una versión

- **WHEN** un administrador revierte la versión activa
- **THEN** las apps vuelven a la versión anterior en su siguiente descarga y la reversión queda en auditoría con su motivo

### Requirement: Retirada inmediata de un ejercicio

El back office MUST permitir retirar un ejercicio concreto de forma inmediata, sin publicar una versión completa.

#### Scenario: Retirada de una plantilla con error

- **WHEN** un administrador retira una plantilla desde una consulta de usuario
- **THEN** las apps dejan de presentarla en cuanto tienen conexión

### Requirement: Paquete de prueba

El back office MUST permitir generar un paquete de prueba e instalarlo en dispositivos de prueba mediante un código QR, sin afectar a los usuarios.

#### Scenario: Prueba en un dispositivo

- **WHEN** un administrador genera un paquete de prueba y lo escanea con la app de pruebas
- **THEN** ese dispositivo muestra el contenido nuevo y ningún usuario lo recibe
