# Spec Delta

## Purpose

Define la sesión de ejercicios en modo táctil: los tipos de ejercicio del producto mínimo viable, el teclado numérico propio, la unidad de respuesta, la respuesta «No lo sé», la salida de la sesión y la medida del tiempo de respuesta.

## ADDED Requirements

### Requirement: Tipos de ejercicio del producto mínimo viable

La app MUST presentar y corregir cinco tipos de ejercicio: respuesta numérica con unidad (T1), selección única (T2), ordenar pasos (T3), estimación rápida (T6) y conversión relámpago (T7).

#### Scenario: Respuesta numérica

- **WHEN** se presenta un ejercicio T1
- **THEN** el usuario ve el enunciado, un campo de respuesta con su unidad y el teclado numérico propio

#### Scenario: Selección única con opciones diagnósticas

- **WHEN** se presenta un ejercicio T2
- **THEN** las opciones falsas corresponden a errores previsibles y su orden cambia entre variantes

#### Scenario: Ordenar pasos con equivalencias

- **WHEN** el usuario ordena los pasos de un ejercicio T3 en cualquiera de los órdenes válidos declarados
- **THEN** la respuesta se da por correcta

#### Scenario: Conversión relámpago

- **WHEN** el usuario empieza un ejercicio T7
- **THEN** responde una serie de diez conversiones con 60 segundos en total

### Requirement: Teclado numérico propio

La app MUST ofrecer un teclado propio con cifras, coma decimal y borrado, con teclas de 56 dp como mínimo, sin recurrir al teclado del sistema.

#### Scenario: Segunda coma

- **WHEN** el usuario pulsa la coma por segunda vez en la misma cifra
- **THEN** la coma no se escribe y el dispositivo da una señal háptica breve

#### Scenario: Teclado físico en tablet

- **GIVEN** una tablet con teclado físico conectado
- **WHEN** el usuario teclea «4.8» y pulsa Intro
- **THEN** el campo muestra «4,8» y la respuesta se comprueba

### Requirement: Unidad de respuesta

La app MUST mostrar la unidad de respuesta como sufijo fijo del campo en los niveles de dificultad 1 a 3 y pedir al usuario que la elija en los niveles 4 y 5.

#### Scenario: Unidad fija

- **WHEN** se presenta un ejercicio de nivel 2 cuya respuesta es en ml
- **THEN** el campo muestra «ml» como sufijo y el usuario solo introduce la cifra

#### Scenario: Unidad a elegir

- **WHEN** se presenta un ejercicio de nivel 4
- **THEN** «Comprobar» no se activa hasta que el usuario ha introducido una cifra y ha elegido una unidad

### Requirement: Respuesta «No lo sé»

La app MUST ofrecer en cada ejercicio la respuesta «No lo sé», que lleva directamente a la resolución guiada y se registra como ejercicio no acertado.

#### Scenario: No lo sé

- **WHEN** el usuario toca «No lo sé»
- **THEN** ve la resolución paso a paso sin diagnóstico de error
- **AND** el ejercicio entra en la cola de repaso

### Requirement: Sesión sin navegación y con salida confirmada

Durante una sesión, la app MUST ocultar la navegación principal y pedir confirmación antes de salir, conservando lo respondido hasta ese momento.

#### Scenario: Salida a mitad de lección

- **WHEN** el usuario toca cerrar en el ejercicio 6 de 10 y confirma
- **THEN** los cinco intentos anteriores quedan guardados y la lección figura como no completada

#### Scenario: Gesto de atrás

- **WHEN** el usuario hace el gesto de atrás del sistema durante un ejercicio
- **THEN** se abre la confirmación de salida en lugar de abandonar la sesión

### Requirement: Pausa al pasar a segundo plano

La app MUST detener la medida del tiempo cuando pasa a segundo plano y reanudar la sesión en el mismo ejercicio al volver.

#### Scenario: Llamada entrante

- **WHEN** entra una llamada durante un ejercicio y el usuario vuelve dos minutos después
- **THEN** el ejercicio sigue en pantalla y esos dos minutos no cuentan en el tiempo de respuesta

### Requirement: Medida del tiempo de respuesta

La app MUST medir el tiempo de respuesta de cada ejercicio desde la presentación del enunciado hasta el envío de la respuesta, sin incluir pausas, correcciones ni nada de lo que ocurre entre ejercicios.

#### Scenario: Tiempo de un ejercicio

- **WHEN** el usuario responde un ejercicio a los 18 segundos de verlo y dedica 40 segundos a leer la explicación
- **THEN** el intento registra 18 segundos

### Requirement: Lección preparada antes de empezar

La app MUST preparar todos los ejercicios de una lección antes de iniciarla, de modo que la sesión no dependa de la red ni tenga esperas entre ejercicios.

#### Scenario: Lección en modo avión

- **GIVEN** el dispositivo en modo avión
- **WHEN** el usuario inicia una lección descargada
- **THEN** los ejercicios se suceden sin esperas de carga

#### Scenario: Variante defectuosa

- **WHEN** una variante de la lección no puede mostrarse
- **THEN** la app la salta, lo registra y la lección continúa con el ejercicio siguiente
