# Spec Delta

## Purpose

Define cómo se organiza y se recorre el contenido: la jerarquía de sector a ejercicio, la ruta visual, la secuencia de lecciones de cada unidad, el reto de unidad, la dificultad adaptativa y los estados de dominio por habilidad.

## ADDED Requirements

### Requirement: Jerarquía del contenido

La app MUST organizar el contenido en sector, itinerario, unidad, lección y ejercicio, y mostrar el itinerario activo como una ruta de unidades con su estado.

#### Scenario: Ruta con estados

- **WHEN** el usuario abre Inicio
- **THEN** ve las unidades del itinerario en orden, cada una con su estado en icono y texto: bloqueada, disponible, en curso, superada, dominada o por refrescar

#### Scenario: Ruta sin conexión

- **GIVEN** el dispositivo sin conexión y el itinerario descargado
- **WHEN** el usuario abre Inicio
- **THEN** la ruta se muestra completa y las lecciones descargadas pueden iniciarse

### Requirement: Acción principal única

La pantalla de Inicio MUST ofrecer una única acción principal, «Continuar», que lleva a la siguiente lección pendiente.

#### Scenario: Continuar

- **GIVEN** un usuario que ha completado dos lecciones de la unidad 4
- **WHEN** toca «Continuar»
- **THEN** empieza la lección 3 de la unidad 4

### Requirement: Secuencia de lecciones de una unidad

Cada unidad MUST presentar sus lecciones en este orden: concepto guiado, práctica con apoyos, práctica libre, mixta y reto de unidad; y cada lección MUST abrirse al completar la anterior.

#### Scenario: Lección bloqueada

- **WHEN** el usuario toca la lección 3 sin haber completado la 2
- **THEN** la app indica «Completa antes la lección 2» y no la inicia

#### Scenario: Lección mixta

- **WHEN** el usuario hace la lección mixta de una unidad
- **THEN** la lección alterna ejercicios de la habilidad nueva con ejercicios de habilidades de unidades anteriores

### Requirement: Reto de unidad

El reto de unidad MUST constar de 10 ejercicios sin pistas y superarse con 9 aciertos o más y ningún error crítico; al superarlo, la app MUST abrir la unidad siguiente.

#### Scenario: Reto superado

- **WHEN** el usuario acierta 9 de 10 sin errores críticos
- **THEN** la unidad pasa a «superada» y se abre la siguiente

#### Scenario: Reto no superado por un error crítico

- **WHEN** el usuario acierta 9 de 10 y su único fallo es un error de factor diez
- **THEN** el reto no se supera y el fallo pasa al repaso

#### Scenario: Saltar una unidad con el reto

- **WHEN** un usuario hace el reto de una unidad sin haber completado sus lecciones y lo supera
- **THEN** la unidad queda superada y sus lecciones, convalidadas

### Requirement: Dificultad adaptativa dentro de la lección

Dentro de una lección, la app MUST subir un nivel de dificultad tras tres aciertos seguidos dentro del tiempo objetivo y bajarlo tras dos fallos seguidos, mostrando entonces el planteamiento.

#### Scenario: Subida de nivel

- **WHEN** el usuario acierta tres ejercicios seguidos dentro del tiempo objetivo
- **THEN** el siguiente ejercicio de esa plantilla se presenta un nivel por encima

#### Scenario: Bajada de nivel con apoyo

- **WHEN** el usuario falla dos ejercicios seguidos
- **THEN** el siguiente se presenta un nivel por debajo y con el planteamiento visible

### Requirement: Estados de dominio por habilidad

La app MUST calcular para cada habilidad uno de estos estados con los ejercicios respondidos al primer intento: nueva, en aprendizaje, consolidada, dominada o por refrescar.

#### Scenario: Habilidad consolidada

- **WHEN** el usuario alcanza un 85 % de acierto en sus últimos 20 ejercicios de una habilidad, hechos en al menos 2 días distintos
- **THEN** la habilidad pasa a «consolidada»

#### Scenario: Habilidad dominada

- **WHEN** el usuario alcanza un 95 % en los últimos 20, en al menos 3 días repartidos en 7 o más, sin errores críticos y con mediana de tiempo dentro del objetivo
- **THEN** la habilidad pasa a «dominada»

#### Scenario: Habilidad por refrescar

- **WHEN** una habilidad dominada acumula fichas vencidas más de 14 días o un fallo en repaso
- **THEN** pasa a «por refrescar» y vuelve a «dominada» tras tres repasos correctos seguidos

### Requirement: Calentamiento de repaso

Cuando hay fichas de repaso vencidas, la sesión diaria MUST empezar con un calentamiento de hasta 5 de ellas antes de la lección nueva.

#### Scenario: Sesión con repaso pendiente

- **GIVEN** un usuario con 12 fichas vencidas
- **WHEN** toca «Continuar»
- **THEN** responde primero 5 fichas de repaso y después empieza la lección

#### Scenario: Sesión sin repaso pendiente

- **GIVEN** un usuario sin fichas vencidas
- **WHEN** toca «Continuar»
- **THEN** la lección empieza directamente
