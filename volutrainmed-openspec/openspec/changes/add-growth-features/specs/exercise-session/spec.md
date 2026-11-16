# Spec Delta

## Purpose

La sesión de ejercicios incorpora los tipos de la fase 2, definidos con el creador de tipos de ejercicio y dibujados por el intérprete genérico de bloques.

## MODIFIED Requirements

### Requirement: Tipos de ejercicio del producto mínimo viable

La app MUST presentar y corregir los cinco tipos del producto mínimo viable, respuesta numérica con unidad (T1), selección única (T2), ordenar pasos (T3), estimación rápida (T6) y conversión relámpago (T7), y los tipos de la fase 2 definidos con el creador de tipos: completar el planteamiento (T4), detectar el error (T5), caso encadenado (T8) y emparejar (T10).

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

#### Scenario: Completar el planteamiento

- **WHEN** el usuario coloca en los huecos de la operación de un ejercicio T4 las fichas correctas, aunque sobren fichas
- **THEN** la respuesta se da por correcta y se aceptan las posiciones intercambiables declaradas

#### Scenario: Emparejar

- **WHEN** el usuario une cada expresión de un ejercicio T10 con su equivalente tocando un elemento de cada columna
- **THEN** cada par se corrige por separado y el ejercicio termina cuando todos están unidos

#### Scenario: Tipo de fase 2 sin conexión

- **GIVEN** contenido T8 ya descargado y el dispositivo sin conexión
- **WHEN** el usuario resuelve el caso encadenado
- **THEN** cada parte se corrige con normalidad y, si una falla, la siguiente continúa con el valor correcto
