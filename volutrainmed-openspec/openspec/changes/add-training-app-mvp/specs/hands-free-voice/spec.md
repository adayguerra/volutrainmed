# Spec Delta

## Purpose

Define el modo manos libres: la app lee la pregunta y capta la respuesta hablada con procesamiento íntegro en el dispositivo, sin enviar audio ni texto a la nube, y funciona en modo avión. Cubre el turno conversacional, la gramática numérica, los comandos, la confirmación, los errores de reconocimiento y la vuelta a la entrada manual.

## ADDED Requirements

### Requirement: Procesamiento íntegro en el dispositivo

La app MUST sintetizar y reconocer la voz en el dispositivo, sin enviar audio ni texto reconocido a ningún servidor.

#### Scenario: Sesión en modo avión

- **GIVEN** el dispositivo en modo avión y el paquete de voz descargado
- **WHEN** el usuario completa una sesión manos libres de 10 ejercicios
- **THEN** la lectura, el reconocimiento y la corrección funcionan de principio a fin

#### Scenario: Sin tráfico de voz

- **WHEN** se inspecciona el tráfico de red durante una sesión manos libres con conexión
- **THEN** no hay ninguna transmisión de audio ni de texto reconocido

### Requirement: Sin almacenamiento de audio ni de transcripciones

La app MUST mantener el audio solo en memoria mientras lo reconoce y guardar únicamente la respuesta interpretada, sin audio ni texto transcrito.

#### Scenario: Datos guardados de un intento por voz

- **WHEN** el usuario responde por voz «cuatro coma ocho»
- **THEN** el intento guarda el valor 4,8, su unidad y métricas técnicas, y ningún audio ni texto

### Requirement: Turno conversacional

En cada ejercicio, la app MUST leer los datos y la pregunta, escuchar la respuesta, confirmar lo entendido, decir el veredicto y pasar al ejercicio siguiente.

#### Scenario: Turno completo

- **WHEN** la app lee «Paciente simulado de 80 kilos. Noradrenalina a cero coma uno microgramos por kilo y minuto. Dilución de 100 microgramos por mililitro. ¿A cuántos mililitros por hora?» y el usuario dice «cuatro coma ocho»
- **THEN** la app dice «Cuatro coma ocho mililitros por hora. ¿Correcto?»
- **AND** tras un «sí», dice «Correcto» y pasa al ejercicio siguiente

#### Scenario: La pregunta va al final

- **WHEN** la app lee un enunciado
- **THEN** dice primero los datos y, en último lugar, lo que se pregunta

### Requirement: Confirmación antes de corregir

La app MUST repetir la cifra entendida con su unidad y obtener la confirmación del usuario antes de corregir la respuesta.

#### Scenario: Rechazo de lo entendido

- **WHEN** la app dice «Catorce coma ocho mililitros por hora. ¿Correcto?» y el usuario dice «no»
- **THEN** la app vuelve a escuchar sin corregir la respuesta

#### Scenario: Cifras que se confunden

- **WHEN** la app entiende «sesenta»
- **THEN** la confirmación deletrea «Sesenta: seis, cero. ¿Correcto?»

#### Scenario: Confirmación abreviada

- **GIVEN** el ajuste de confirmación en «solo si hay duda» y una respuesta entendida con confianza alta
- **WHEN** la app repite la cifra
- **THEN** espera 1,5 segundos un posible «no» y, si no llega, corrige

### Requirement: Gramática de respuestas numéricas

La app MUST interpretar en español de España enteros, decimales con «coma», «con» o «punto», decimales dichos cifra a cifra o como número, y las fracciones habladas «medio», «y medio», «un cuarto» y «tres cuartos».

#### Scenario: Variantes de un mismo decimal

- **WHEN** el usuario dice «cero coma cinco», «coma cinco», «cero con cinco», «cero punto cinco» o «medio»
- **THEN** la app interpreta 0,5 en los cinco casos

#### Scenario: Cero tras la coma

- **WHEN** el usuario dice «cero coma cero cinco»
- **THEN** la app interpreta 0,05

#### Scenario: Entero y medio

- **WHEN** el usuario dice «dos y medio»
- **THEN** la app interpreta 2,5

#### Scenario: Respuesta ambigua

- **WHEN** el usuario dice «dos cinco» sin separador
- **THEN** la app pregunta «¿Veinticinco o dos coma cinco?»

### Requirement: Unidades habladas

La app MUST reconocer las formas habladas de las unidades, añadir la unidad en la confirmación cuando es fija y preguntar cuando duda entre dos unidades de sonido parecido.

#### Scenario: Unidad fija

- **GIVEN** un ejercicio con la unidad de respuesta fija en ml/h
- **WHEN** el usuario dice solo «cuatro coma ocho»
- **THEN** la confirmación dice «Cuatro coma ocho mililitros por hora»

#### Scenario: Miligramos o microgramos

- **GIVEN** un ejercicio en el que el usuario elige la unidad
- **WHEN** el reconocimiento duda entre «miligramos» y «microgramos»
- **THEN** la app pregunta «¿Miligramos o microgramos?»

#### Scenario: Sinónimo de sector

- **GIVEN** el sinónimo «gammas» activado en los ajustes de voz
- **WHEN** el usuario dice «doscientas gammas»
- **THEN** la app interpreta 200 µg

### Requirement: Comandos de voz

La app MUST atender en cualquier momento de la sesión los comandos «repite», «siguiente», «no lo sé», «pausa», «continúa», «explica», «teclado» y «salir».

#### Scenario: Repite

- **WHEN** el usuario dice «repite» durante la escucha
- **THEN** la app vuelve a leer el enunciado y abre de nuevo la escucha

#### Scenario: Pausa y continúa

- **WHEN** el usuario dice «pausa» y, más tarde, «continúa»
- **THEN** la sesión se detiene y se reanuda en el mismo punto

#### Scenario: No lo sé

- **WHEN** el usuario dice «no lo sé»
- **THEN** la app dice la respuesta correcta y registra el ejercicio como no acertado

#### Scenario: Salir

- **WHEN** el usuario dice «salir»
- **THEN** la app pide confirmación antes de cerrar la sesión

### Requirement: Recuperación de errores de reconocimiento

Ante fallos de reconocimiento en un mismo ejercicio, la app MUST pedir que se repita la primera vez, pasar al dictado cifra a cifra la segunda y abrir el teclado la tercera, sin contar ningún fallo de reconocimiento como respuesta incorrecta.

#### Scenario: Tercer fallo

- **WHEN** la app no entiende la respuesta por tercera vez en un ejercicio
- **THEN** dice «Te abro el teclado» y muestra el teclado numérico

#### Scenario: El fallo de reconocimiento no penaliza

- **WHEN** la app no entiende una respuesta y el usuario la repite y acierta
- **THEN** el ejercicio se registra como acertado al primer intento

#### Scenario: Silencio

- **WHEN** pasan 6 segundos sin voz durante la escucha
- **THEN** la app dice «No te he oído. ¿Lo repito?»

### Requirement: Ruido ambiente

La app MUST avisar cuando el ruido ambiente dificulta el reconocimiento y proponer auriculares o los botones.

#### Scenario: Entorno ruidoso

- **WHEN** la app detecta un nivel de ruido alto antes de que el usuario hable
- **THEN** muestra y dice «Hay mucho ruido. Acerca el micrófono o usa los botones»

### Requirement: Uso con guantes o manos ocupadas

La pantalla de manos libres MUST permitir pausar y continuar con un toque en cualquier punto, ofrecer botones de 72 dp para repetir, «no lo sé» y siguiente, y responder al botón de los auriculares.

#### Scenario: Toque en la pantalla

- **WHEN** el usuario toca cualquier zona de la pantalla durante la lectura
- **THEN** la sesión se pausa y otro toque la reanuda

#### Scenario: Botón de los auriculares

- **WHEN** el usuario pulsa el botón de sus auriculares
- **THEN** la sesión se pausa o se reanuda

### Requirement: Paquete de voz bajo demanda

La app MUST descargar el paquete de voz solo cuando el usuario entra en el modo manos libres, indicando su tamaño, y verificar su integridad antes de usarlo.

#### Scenario: Sin paquete y sin conexión

- **GIVEN** un dispositivo sin paquete de voz y sin conexión
- **WHEN** el usuario entra en manos libres
- **THEN** la app explica que hace falta conexión para la descarga y ofrece el modo táctil

#### Scenario: Paquete alterado

- **WHEN** la verificación del paquete descargado falla
- **THEN** la app lo descarta y ofrece descargarlo de nuevo

### Requirement: Latencia del reconocimiento

En el dispositivo de referencia, la app MUST mostrar la cifra entendida en 800 ms como máximo tras el fin del silencio de corte.

#### Scenario: Respuesta corta

- **WHEN** el usuario termina de decir «cuatro coma ocho» en el dispositivo de referencia
- **THEN** la cifra «4,8» aparece en pantalla en 800 ms o menos tras el silencio de corte

### Requirement: Ejercicios compatibles con voz

Una sesión manos libres MUST incluir solo ejercicios de tipos compatibles con voz, que en el producto mínimo viable son T1, T2, T6 y T7.

#### Scenario: Lección con un tipo no compatible

- **GIVEN** una lección que incluye ejercicios de ordenar pasos
- **WHEN** el usuario la inicia en manos libres
- **THEN** la sesión presenta solo los ejercicios compatibles e indica cuántos quedan para el modo táctil

### Requirement: Accesibilidad de la sesión de voz

La sesión manos libres MUST poder completarse sin ver la pantalla, sin hablar y sin oír: todo lo dicho aparece escrito, cada estado tiene su señal háptica y cada comando tiene su botón.

#### Scenario: Sin oír

- **WHEN** un usuario con el sonido desactivado sigue una sesión manos libres
- **THEN** lee en pantalla el enunciado, la cifra entendida y el veredicto, y distingue acierto y fallo por su patrón háptico

#### Scenario: Sin hablar

- **WHEN** un usuario no puede hablar durante una sesión manos libres
- **THEN** puede responder con el teclado y avanzar con los botones
