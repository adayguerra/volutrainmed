# Spec Delta

## Purpose

Define cómo un administrador no técnico crea tipos de ejercicio nuevos combinando bloques ya existentes, y cómo la app los interpreta sin necesidad de publicar una versión nueva.

## ADDED Requirements

### Requirement: Tipos como combinación de bloques

El back office MUST permitir definir un tipo de ejercicio como una secuencia de pasos de interacción, cada uno con bloques de presentación, un bloque de respuesta y una regla de corrección.

#### Scenario: Tipo de dos pasos

- **WHEN** un administrador crea un tipo con un primer paso de selección única y un segundo de respuesta numérica
- **THEN** el tipo queda disponible para crear preguntas y plantillas

#### Scenario: Paso sin bloque de respuesta

- **WHEN** un paso no tiene bloque de respuesta
- **THEN** el back office no permite guardar el tipo e indica el paso incompleto

#### Scenario: Bloques sin arrastrar

- **WHEN** el administrador añade y ordena bloques con los botones del editor
- **THEN** obtiene el mismo resultado que arrastrándolos

### Requirement: Interpretación del tipo en la app

La app MUST presentar y corregir cualquier tipo formado por bloques que su versión admite, sin necesidad de una versión nueva.

#### Scenario: Tipo nuevo en una app ya instalada

- **GIVEN** un tipo creado con bloques que la app instalada admite
- **WHEN** se publica contenido de ese tipo
- **THEN** los usuarios lo reciben y lo resuelven sin actualizar la app

#### Scenario: Tipo nuevo sin conexión

- **GIVEN** contenido de un tipo nuevo ya descargado y el dispositivo sin conexión
- **WHEN** el usuario hace un ejercicio de ese tipo
- **THEN** se presenta y se corrige con normalidad

### Requirement: Versión mínima de la app por tipo

Cada tipo MUST declarar la versión mínima de la app que lo admite, y las apps anteriores MUST omitir su contenido sin errores.

#### Scenario: App antigua

- **GIVEN** un tipo que usa un bloque añadido en una versión posterior de la app
- **WHEN** una app anterior descarga el contenido
- **THEN** omite los ejercicios de ese tipo y el resto de la lección funciona

#### Scenario: Aviso antes de publicar

- **WHEN** un administrador va a publicar contenido de un tipo con versión mínima
- **THEN** el back office muestra qué porcentaje de los dispositivos activos lo admite

### Requirement: Compatibilidad con voz calculada

El back office MUST marcar un tipo como compatible con el modo manos libres solo cuando todos sus bloques de respuesta admiten voz.

#### Scenario: Tipo con un bloque de ordenar

- **WHEN** un tipo incluye un bloque de respuesta de ordenar
- **THEN** el tipo figura como no compatible con voz y sus ejercicios no entran en sesiones manos libres

### Requirement: Tipos en uso versionados

Un tipo con contenido publicado MUST conservarse, y cualquier cambio sobre él MUST crear una versión nueva que no altera el contenido ya publicado.

#### Scenario: Cambio en un tipo en uso

- **WHEN** un administrador modifica un tipo con 40 preguntas publicadas
- **THEN** se crea una versión nueva del tipo y las 40 preguntas siguen usando la anterior

### Requirement: Tipos de la fase 2

El producto MUST incorporar, definidos con el creador de tipos, completar el planteamiento (T4), detectar el error (T5), caso encadenado (T8) y emparejar (T10).

#### Scenario: Caso encadenado

- **GIVEN** un caso encadenado de tres partes
- **WHEN** el usuario falla la primera parte
- **THEN** la app muestra su valor correcto y las partes siguientes continúan con él

#### Scenario: Detectar el error

- **WHEN** se presenta un cálculo resuelto de tres pasos con el segundo equivocado y el usuario señala el paso 2
- **THEN** la respuesta es correcta y la explicación muestra el valor correcto de ese paso
