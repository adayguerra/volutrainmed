# Spec Delta

## Purpose

Define las ligas semanales y los logros configurables: una motivación social que premia la precisión y no el volumen, con alias y salida voluntaria para respetar la privacidad de un público profesional.

## ADDED Requirements

### Requirement: Ligas semanales por sector

La app MUST agrupar cada semana a los participantes en ligas de 30 usuarios, del mismo sector cuando sea posible, repartidas en cinco divisiones: Bronce, Plata, Oro, Platino y Titanio.

#### Scenario: Inicio de semana

- **WHEN** empieza una semana
- **THEN** cada participante queda asignado a un grupo de su división con usuarios de su sector

#### Scenario: Ascenso y descenso

- **WHEN** termina la semana
- **THEN** los 7 primeros de cada grupo suben de división y los 5 últimos bajan

### Requirement: Puntuación por precisión

La liga MUST puntuar solo los aciertos al primer intento, conceder bonificación por rapidez solo con una marca válida de contrarreloj y limitar los puntos a 300 por día.

#### Scenario: Tope diario

- **GIVEN** un usuario que ya ha sumado 300 puntos hoy
- **WHEN** acierta más ejercicios
- **THEN** su puntuación de liga no aumenta hasta el día siguiente

#### Scenario: Marca de contrarreloj no válida

- **WHEN** un usuario termina un contrarreloj con una precisión inferior al 90 %
- **THEN** no recibe bonificación de liga por esa marca

### Requirement: Alias y participación voluntaria

Los usuarios MUST aparecer en las ligas con un alias y poder salir de ellas y volver en cualquier momento.

#### Scenario: Clasificación con alias

- **WHEN** un usuario consulta la clasificación de su grupo
- **THEN** ve alias, nunca nombres ni correos

#### Scenario: Salida de las ligas

- **WHEN** un usuario elige no participar
- **THEN** deja de aparecer en la clasificación y la pestaña indica «No participas en ligas», con la opción de volver

### Requirement: Clasificación sin conexión

Sin conexión, la app MUST mostrar la última clasificación conocida con su hora y sumar los puntos propios al recuperar la conexión.

#### Scenario: Liga sin conexión

- **GIVEN** el dispositivo sin conexión desde hace 3 horas
- **WHEN** el usuario abre la pestaña de ligas
- **THEN** ve «Clasificación de hace 3 h» y sus puntos pendientes de sumar

### Requirement: Cambios de reglas al inicio de semana

Los cambios en la configuración de las ligas MUST entrar en vigor al comenzar la semana siguiente, nunca durante una semana en curso.

#### Scenario: Cambio del tope diario

- **WHEN** un administrador cambia el tope diario un miércoles
- **THEN** el nuevo tope se aplica desde el lunes siguiente

### Requirement: Detección de puntuaciones anómalas

El sistema MUST marcar para revisión a los participantes con patrones imposibles, como tiempos de respuesta por debajo de lo humanamente posible.

#### Scenario: Tiempos imposibles

- **WHEN** un participante registra una serie de aciertos con tiempos de respuesta inferiores a medio segundo
- **THEN** queda marcado para revisión y sus puntos de esa serie quedan en suspenso

### Requirement: Logros configurables

El back office MUST permitir crear logros con una condición formada por métrica, operador, valor y ámbito, sin código, y probar la condición con un usuario de ejemplo.

#### Scenario: Logro de racha

- **WHEN** un administrador crea el logro «30 días de racha» con la métrica días de racha, el operador mayor o igual y el valor 30
- **THEN** los usuarios que alcanzan 30 días de racha lo obtienen tras la siguiente publicación

#### Scenario: Prueba de la condición

- **WHEN** el administrador prueba la condición con un usuario de ejemplo con 12 días de racha
- **THEN** el back office indica que ese usuario no obtendría el logro
