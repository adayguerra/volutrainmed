# Spec Delta

## Purpose

Define el repaso espaciado de los errores: qué se repasa, cómo se califica cada respuesta sin preguntar al usuario, cómo se programa el siguiente repaso, la cuarentena de los errores críticos y la cola diaria.

## ADDED Requirements

### Requirement: Ficha de repaso

La app MUST programar para repaso cada plantilla fallada en su nivel de dificultad, y presentar en cada repaso una variante numérica distinta de las ya vistas.

#### Scenario: Variante nueva en el repaso

- **GIVEN** una ficha creada al fallar un ejercicio con un perro de 24 kg
- **WHEN** la ficha vuelve en el repaso
- **THEN** el ejercicio usa otros números de la misma plantilla y nivel

### Requirement: Calificación automática

La app MUST calificar cada repaso a partir de la respuesta, sin preguntar al usuario: «otra vez» si falla o responde «No lo sé»; «difícil» si acierta con pista o en más del doble del tiempo objetivo; «bien» si acierta al primer intento; y «fácil» si acierta al primer intento en menos del 60 % del tiempo objetivo.

#### Scenario: Acierto rápido

- **GIVEN** un tiempo objetivo de 30 segundos
- **WHEN** el usuario acierta al primer intento en 15 segundos
- **THEN** la ficha se califica como «fácil»

#### Scenario: Acierto con pista

- **WHEN** el usuario acierta tras pedir una pista
- **THEN** la ficha se califica como «difícil»

#### Scenario: No lo sé

- **WHEN** el usuario responde «No lo sé»
- **THEN** la ficha se califica como «otra vez»

### Requirement: Programación del siguiente repaso

La app MUST calcular en el dispositivo la fecha del siguiente repaso de cada ficha según su historial, con una retención objetivo del 90 %.

#### Scenario: Programación sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario completa un repaso
- **THEN** cada ficha queda con su nueva fecha de repaso

#### Scenario: Intervalo creciente

- **WHEN** el usuario acierta una ficha en tres repasos consecutivos
- **THEN** el intervalo hasta el siguiente repaso es mayor que el anterior

### Requirement: Cuarentena de errores críticos

Tras un error crítico, la app MUST programar la ficha para el día siguiente y no alargar su intervalo hasta que acumule dos aciertos en días distintos.

#### Scenario: Error crítico

- **WHEN** el usuario comete un error de factor diez en una plantilla
- **THEN** su ficha vence al día siguiente

#### Scenario: Salida de la cuarentena

- **GIVEN** una ficha en cuarentena acertada ayer
- **WHEN** el usuario la acierta hoy
- **THEN** la ficha sale de la cuarentena y su intervalo empieza a crecer

### Requirement: Cola diaria de repaso

La app MUST limitar la cola diaria a un tope configurable entre 10 y 40 fichas, de 20 por defecto, ordenada con las fichas de error crítico primero y después las más vencidas.

#### Scenario: Tope por defecto

- **GIVEN** un usuario con 35 fichas vencidas y el tope por defecto
- **WHEN** abre el repaso
- **THEN** la cola de hoy tiene 20 fichas

#### Scenario: Orden de la cola

- **WHEN** la cola contiene fichas de error crítico y fichas ordinarias
- **THEN** las de error crítico se presentan primero

### Requirement: Sesión de repaso

En una sesión de repaso, una ficha acertada MUST salir de la cola del día y una ficha fallada MUST mostrar su explicación y volver al final de la sesión, dos veces como máximo.

#### Scenario: Ficha fallada en el repaso

- **WHEN** el usuario falla una ficha durante el repaso
- **THEN** ve la explicación paso a paso y la ficha reaparece al final de la sesión

#### Scenario: Motivo de la ficha

- **WHEN** se presenta una ficha de repaso
- **THEN** la pantalla indica cuándo se falló y con qué tipo de error

### Requirement: Repaso sin fichas pendientes

Cuando no hay fichas vencidas, la app MUST mostrar la fecha del próximo repaso y ofrecer práctica libre.

#### Scenario: Cola vacía

- **WHEN** el usuario abre el repaso sin fichas vencidas
- **THEN** ve «No tienes fichas para hoy» con la fecha del próximo repaso y la opción de práctica libre
