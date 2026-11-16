# Spec Delta

## Purpose

Define la pausa promocional que los usuarios sin Premium ven tras cada ejercicio: anuncios propios de la app que promocionan la suscripción, servidos desde el dispositivo, sin redes publicitarias y sin perjudicar la corrección, la medida del aprendizaje ni la accesibilidad.

## ADDED Requirements

### Requirement: Pausa promocional tras cada ejercicio

La app MUST mostrar exactamente un anuncio propio a los usuarios sin Premium después de cada ejercicio, una vez cerrada su corrección y antes de presentar el ejercicio siguiente o la pantalla de fin de lección.

#### Scenario: Respuesta correcta en una lección

- **GIVEN** un usuario sin Premium en una lección de 10 ejercicios
- **WHEN** responde bien el ejercicio 4 y toca «Continuar» en la banda de veredicto
- **THEN** aparece una pausa promocional con un anuncio propio
- **AND** al cerrarla se presenta el ejercicio 5

#### Scenario: Último ejercicio de la lección

- **GIVEN** un usuario sin Premium en el último ejercicio de una lección
- **WHEN** cierra su corrección
- **THEN** aparece la pausa promocional y, al cerrarla, la pantalla de fin de lección

### Requirement: La corrección va siempre antes

La pausa promocional MUST aparecer solo después de que el usuario haya visto el veredicto y haya cerrado la corrección, y nunca tapar la respuesta correcta ni la explicación paso a paso.

#### Scenario: Respuesta incorrecta con explicación

- **WHEN** un usuario sin Premium responde mal un ejercicio
- **THEN** ve el veredicto, la respuesta correcta y la explicación completa sin ningún anuncio
- **AND** la pausa promocional aparece solo cuando toca «Continuar»

#### Scenario: Error crítico con segundo intento

- **GIVEN** una respuesta con error crítico, que ofrece un segundo intento con otros números
- **WHEN** el usuario empieza el segundo intento
- **THEN** no aparece ninguna pausa promocional entre la explicación y el segundo intento
- **AND** la pausa aparece al cerrar la corrección del segundo intento

### Requirement: Formato de la pausa promocional

La pausa promocional MUST presentarse como una tarjeta a pantalla completa con el rótulo «Promoción de VolutrainMed», un titular, un texto de 90 caracteres como máximo, una ilustración, la acción del anuncio y la acción «Continuar».

#### Scenario: Elementos visibles

- **WHEN** aparece una pausa promocional
- **THEN** el rótulo «Promoción de VolutrainMed» es visible en la parte superior
- **AND** la acción «Continuar» está siempre a la vista, activa o con su cuenta atrás

#### Scenario: Tablet en horizontal

- **WHEN** la pausa aparece en una tablet de 840 dp o más de ancho
- **THEN** la tarjeta ocupa 560 dp de ancho como máximo, centrada, sin estirarse

### Requirement: Espera configurable antes de continuar

La app MUST activar la acción «Continuar» tras una espera configurable de 0 a 5 segundos, de 3 segundos por defecto, y mostrar la cuenta atrás mientras dura.

#### Scenario: Espera por defecto

- **GIVEN** la espera configurada en 3 segundos
- **WHEN** aparece la pausa promocional
- **THEN** «Continuar» muestra la cuenta atrás 3, 2, 1 y se activa al terminar

#### Scenario: Espera desactivada

- **GIVEN** la espera configurada en 0 segundos
- **WHEN** aparece la pausa promocional
- **THEN** «Continuar» está activo desde el primer momento

### Requirement: Inventario propio y local

La app MUST servir los anuncios desde el contenido descargado en el dispositivo, sin integrar ninguna red publicitaria, sin peticiones de red para mostrarlos y sin usar identificadores publicitarios.

#### Scenario: Modo avión

- **GIVEN** el dispositivo en modo avión y un usuario sin Premium
- **WHEN** termina un ejercicio
- **THEN** la pausa promocional aparece con su anuncio completo, texto e ilustración

#### Scenario: Sin tráfico publicitario

- **WHEN** se inspecciona el tráfico de red de la app durante una lección con anuncios
- **THEN** no hay ninguna petición a dominios publicitarios ni envío de identificadores publicitarios

### Requirement: Rotación de anuncios

La app MUST elegir cada anuncio por peso entre los vigentes, sin repetir el mismo anuncio en dos pausas consecutivas y sin superar su tope diario de impresiones, de 6 por defecto.

#### Scenario: Sin repetición consecutiva

- **WHEN** un usuario ve dos pausas promocionales seguidas
- **THEN** los dos anuncios son distintos

#### Scenario: Tope diario alcanzado

- **GIVEN** un anuncio que ya se ha mostrado 6 veces hoy a un usuario
- **WHEN** toca elegir el siguiente anuncio
- **THEN** ese anuncio queda fuera de la elección hasta el día siguiente

### Requirement: Anuncios activados por contexto

La app MUST dar prioridad, sobre los anuncios genéricos, al anuncio cuyo contexto de activación se cumple en ese momento, y rellenar sus datos con valores reales del usuario.

#### Scenario: Racha de varios días

- **GIVEN** un usuario con una racha de 5 días
- **WHEN** aparece una pausa y el anuncio de racha está vigente y bajo su tope
- **THEN** se muestra el anuncio de racha con el texto «Llevas 5 días seguidos»

#### Scenario: Límite diario de manos libres agotado

- **GIVEN** un usuario sin Premium que ha agotado hoy su tiempo de manos libres
- **WHEN** aparece la siguiente pausa promocional
- **THEN** se muestra el anuncio de manos libres sin límite

### Requirement: Exclusiones de la pausa promocional

La app MUST omitir la pausa promocional para usuarios con Premium activo o en prueba, durante la prueba de nivel, durante la primera lección tras el alta y entre los ejercicios de un contrarreloj.

#### Scenario: Usuario con Premium

- **WHEN** un usuario con Premium activo completa una lección
- **THEN** no ve ninguna pausa promocional

#### Scenario: Primera lección

- **WHEN** un usuario recién dado de alta hace su primera lección
- **THEN** pasa de un ejercicio al siguiente sin pausas promocionales

#### Scenario: Contrarreloj

- **GIVEN** un usuario sin Premium en un esprint de 60 segundos
- **WHEN** responde un ejercicio
- **THEN** el siguiente aparece de inmediato, sin pausa
- **AND** se muestra una única pausa promocional al terminar el esprint, antes del resumen

#### Scenario: Prueba de nivel

- **WHEN** un usuario sin Premium hace la prueba de nivel
- **THEN** no aparece ninguna pausa promocional entre sus preguntas

### Requirement: Cuña hablada en el modo manos libres

En el modo manos libres, la app MUST sustituir la tarjeta por una cuña hablada de 4 segundos como máximo tras cada ejercicio, con una frecuencia configurable aparte y la posibilidad de saltarla con «siguiente».

#### Scenario: Cuña tras el veredicto

- **GIVEN** un usuario sin Premium en una sesión de manos libres con frecuencia 1
- **WHEN** la app termina de decir el veredicto de un ejercicio
- **THEN** dice una cuña de 4 segundos como máximo y pasa a leer el ejercicio siguiente

#### Scenario: Saltar la cuña

- **WHEN** el usuario dice «siguiente» mientras suena la cuña
- **THEN** la cuña se interrumpe y empieza la lectura del ejercicio siguiente

#### Scenario: Interés sin tocar la pantalla

- **WHEN** el usuario dice «más información» durante la cuña
- **THEN** la sesión continúa y la pantalla de resumen final muestra el anuncio con su acción

### Requirement: El tiempo de anuncio no cuenta como práctica

La app MUST excluir el tiempo de las pausas promocionales del tiempo de respuesta, del tiempo medio de la lección, de los minutos de práctica de la meta y de las marcas de contrarreloj.

#### Scenario: Meta diaria de cinco minutos

- **GIVEN** una meta diaria de 5 minutos
- **WHEN** un usuario practica 4 minutos y ve 1 minuto de pausas promocionales
- **THEN** la meta muestra 4 minutos cumplidos, no 5

#### Scenario: Tiempo de respuesta

- **WHEN** se registra el intento de un ejercicio
- **THEN** su tiempo de respuesta abarca desde la presentación del enunciado hasta el envío de la respuesta, sin incluir ninguna pausa

### Requirement: Acción del anuncio

La acción del anuncio MUST abrir la pantalla de suscripción y, al cerrarla sin comprar, devolver al usuario al punto exacto de la sesión en el que estaba.

#### Scenario: Toque en «Quitar anuncios» y vuelta

- **GIVEN** una pausa promocional tras el ejercicio 6
- **WHEN** el usuario toca «Quitar anuncios», ve la pantalla de suscripción y la cierra
- **THEN** la sesión continúa en el ejercicio 7 con el progreso intacto

#### Scenario: Compra desde un anuncio

- **WHEN** el usuario completa la compra tras tocar la acción de un anuncio
- **THEN** vuelve a la sesión y no ve ninguna pausa promocional más

### Requirement: Publicidad honesta

Cada anuncio MUST estar rotulado como promoción, contener solo afirmaciones ciertas y calculadas con datos reales, y no incluir urgencia falsa, botones de cierre engañosos ni alusiones al uso con pacientes reales.

#### Scenario: Cifras calculadas con la configuración vigente

- **GIVEN** una espera de 3 segundos y una lección de 10 ejercicios
- **WHEN** se muestra el anuncio que cuantifica las pausas
- **THEN** su texto indica 30 segundos por lección, el producto de ambos valores

#### Scenario: Texto con alusión clínica

- **WHEN** un autor envía a revisión un anuncio cuyo texto menciona pacientes o guardias
- **THEN** la revisión lo rechaza y no puede publicarse

### Requirement: Campañas sin publicar una versión de la app

El back office MUST permitir crear y cambiar creatividades, pesos, fechas de vigencia, segmentos por sector, espera y frecuencia, y esos cambios MUST llegar a las apps con el paquete de contenido, sin una versión nueva en las tiendas.

#### Scenario: Cambio de la espera

- **GIVEN** una espera publicada de 3 segundos
- **WHEN** un administrador la cambia a 2 segundos y publica el contenido
- **THEN** las apps aplican 2 segundos a partir de la siguiente sesión tras descargar el paquete

#### Scenario: Campaña por sector

- **GIVEN** una campaña segmentada al sector veterinaria
- **WHEN** un usuario del sector enfermería ve una pausa promocional
- **THEN** los anuncios de esa campaña no entran en su rotación

#### Scenario: Campaña caducada sin conexión

- **GIVEN** un dispositivo sin conexión con una campaña cuya vigencia ha terminado
- **WHEN** toca elegir un anuncio
- **THEN** esa campaña queda fuera y se usan los anuncios vigentes

### Requirement: Accesibilidad de la pausa promocional

La pausa promocional MUST ser plenamente utilizable con lector de pantalla, texto ampliado al 200 % y movimiento reducido, con contraste de 4,5:1 y objetivos táctiles de 48 dp.

#### Scenario: Lector de pantalla

- **WHEN** aparece la pausa con un lector de pantalla activo
- **THEN** se anuncia «Promoción de VolutrainMed», el titular y el texto
- **AND** se anuncia cuándo se activa «Continuar», que recibe el foco

#### Scenario: Movimiento reducido

- **GIVEN** la opción de reducir movimiento activada
- **WHEN** aparece la pausa promocional
- **THEN** entra con un fundido y la ilustración no se anima

### Requirement: Medición de los anuncios

La app MUST registrar cada impresión, el tiempo de permanencia, el toque en la acción del anuncio y la compra posterior, con el identificador del anuncio y su contexto, encolando los eventos cuando no hay conexión.

#### Scenario: Impresión sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** se muestra un anuncio y el usuario continúa a los 4 segundos
- **THEN** se encola un evento de impresión con el anuncio, el contexto y 4 segundos de permanencia
- **AND** el evento se envía al recuperar la conexión

#### Scenario: Conversión atribuida

- **WHEN** un usuario compra Premium en la misma sesión en la que tocó la acción de un anuncio
- **THEN** la compra queda atribuida a ese anuncio
