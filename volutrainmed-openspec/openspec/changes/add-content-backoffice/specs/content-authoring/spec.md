# Spec Delta

## Purpose

Define cómo un administrador no técnico crea la estructura del contenido y los ejercicios sin tocar código: plantillas parametrizadas que generan variantes numéricas, preguntas fijas, importación masiva y vista previa con lectura en voz alta.

## ADDED Requirements

### Requirement: Estructura del contenido editable

El back office MUST permitir crear, ordenar y retirar sectores, itinerarios, unidades y lecciones, y asignar a cada lección sus ejercicios.

#### Scenario: Nueva unidad

- **WHEN** un administrador de contenido añade una unidad a un itinerario y le asigna dos habilidades
- **THEN** la unidad aparece en el árbol en estado borrador

#### Scenario: Lección sin ejercicios

- **WHEN** se intenta enviar a revisión una lección sin ejercicios asignados
- **THEN** el back office lo impide e indica qué falta

#### Scenario: Reordenar sin arrastrar

- **WHEN** un administrador usa los botones «subir» y «bajar» sobre una unidad
- **THEN** la unidad cambia de posición en el itinerario

### Requirement: Plantillas parametrizadas

El back office MUST permitir definir una plantilla de ejercicio con variables, rangos, pasos, lista de valores o tabla de casos, enunciado, fórmula, unidad de respuesta, redondeo y tolerancia, de la que se generan variantes numéricas.

#### Scenario: Plantilla de dosis por peso

- **GIVEN** una plantilla con la variable peso de 5 a 40 kg, un caso de 0,2 mg/kg con presentación de 5 mg/ml y la fórmula dosis × peso ÷ concentración
- **WHEN** el autor genera variantes de muestra
- **THEN** obtiene 20 variantes con su enunciado, su respuesta en ml y sus pasos resueltos

#### Scenario: Tabla de casos

- **WHEN** el autor define una tabla de casos con filas de fármaco, pauta, presentación y especie
- **THEN** cada variante usa una fila completa, sin mezclar valores de filas distintas

### Requirement: Comprobación dimensional de la fórmula

El back office MUST calcular la unidad que produce la fórmula e impedir guardar una fórmula cuya unidad no coincide con la unidad de respuesta declarada.

#### Scenario: Unidades coherentes

- **WHEN** el autor escribe mg/kg × kg ÷ mg/ml con unidad de respuesta ml
- **THEN** el editor indica que la fórmula produce ml

#### Scenario: Unidades incoherentes

- **WHEN** el autor escribe mg/kg × kg con unidad de respuesta ml
- **THEN** el editor indica «El resultado sale en mg, no en ml» y no permite guardar la fórmula

### Requirement: Restricciones y errores previsibles

El back office MUST permitir declarar en cada plantilla el rango admitido del resultado, condiciones entre variables y las fórmulas erróneas previsibles con su tipo de error.

#### Scenario: Resultado fuera de rango

- **GIVEN** una restricción de resultado entre 0,1 y 3 ml
- **WHEN** se generan variantes
- **THEN** ninguna variante tiene una respuesta fuera de ese rango

#### Scenario: Error previsible de factor diez

- **WHEN** el autor añade el error previsible «resultado × 10» con el tipo orden de magnitud
- **THEN** cada variante incluye ese valor erróneo asociado a su diagnóstico

### Requirement: Prueba masiva de variantes

El back office MUST ofrecer una prueba masiva que genera 1000 variantes de una plantilla e informa del porcentaje descartado, la distribución de respuestas, las repeticiones, los valores extremos y las colisiones entre la respuesta correcta y una errónea previsible.

#### Scenario: Colisión detectada

- **WHEN** en alguna variante la respuesta correcta coincide con una respuesta errónea previsible
- **THEN** el informe la señala y la plantilla no puede enviarse a revisión hasta resolverla

#### Scenario: Variantes insuficientes

- **WHEN** las restricciones dejan menos variantes de las que hay que publicar
- **THEN** el editor indica cuántas cumplen las restricciones y sugiere ampliar los rangos

### Requirement: Explicación y niveles de dificultad

Cada plantilla MUST definir los pasos de su explicación, con el valor intermedio de cada paso, y los rangos de sus cinco niveles de dificultad.

#### Scenario: Plantilla sin pasos

- **WHEN** el autor intenta enviar a revisión una plantilla sin pasos de explicación
- **THEN** el back office lo impide

#### Scenario: Nivel con números limpios

- **GIVEN** el nivel 1 definido con pesos múltiplos de 10
- **WHEN** se generan variantes de nivel 1
- **THEN** todas usan un peso múltiplo de 10

### Requirement: Preguntas fijas

El back office MUST permitir crear preguntas sin variantes para cualquier tipo de ejercicio, con su respuesta, su explicación, el tipo de error de cada opción falsa y comprobaciones automáticas antes de enviarlas a revisión.

#### Scenario: Pregunta de selección única

- **WHEN** un autor crea una pregunta de selección única con cuatro opciones y asigna un tipo de error a cada opción falsa
- **THEN** la pregunta queda en borrador y puede enviarse a revisión

#### Scenario: Cantidad sin unidad

- **WHEN** el enunciado contiene una cantidad sin unidad
- **THEN** la comprobación automática lo señala antes de enviar a revisión

### Requirement: Texto para voz y vista previa con lectura

El back office MUST generar para cada ejercicio un texto para voz editable y ofrecer una vista previa que lo lee en voz alta, lo muestra escrito y permite simular una respuesta hablada.

#### Scenario: Escuchar un ejercicio

- **WHEN** un autor abre la vista previa en modo manos libres y pulsa reproducir
- **THEN** oye el enunciado como lo oirá el usuario y ve el texto que se dice, con las cantidades resaltadas

#### Scenario: Simular una respuesta

- **WHEN** el autor escribe «cero coma noventa y seis» en la simulación de respuesta
- **THEN** la vista previa muestra que se interpreta como 0,96 y el veredicto que recibiría

#### Scenario: Vista previa en tablet

- **WHEN** el autor cambia la vista previa a tablet en horizontal
- **THEN** ve el ejercicio con la disposición de dos paneles

### Requirement: Importación masiva

El back office MUST permitir importar hasta 2000 preguntas o filas de tabla de casos desde una hoja de cálculo, validando cada fila, y crear lo importado siempre en estado borrador.

#### Scenario: Fila con error

- **WHEN** una fila del archivo no tiene unidad de respuesta
- **THEN** la validación muestra «Fila 14: falta la unidad de la respuesta» y permite corregirla en la propia tabla

#### Scenario: Importación parcial

- **WHEN** el archivo tiene 180 filas válidas y 20 con error y el autor confirma
- **THEN** se crean 180 borradores y se ofrece un informe con las 20 filas rechazadas

### Requirement: Creación sin código ni versión de la app

Un administrador sin conocimientos técnicos MUST poder crear un ejercicio, hacerlo validar y publicarlo, y los usuarios MUST recibirlo sin instalar una versión nueva de la app.

#### Scenario: De la plantilla al dispositivo

- **GIVEN** una plantilla creada en el back office y validada por un revisor
- **WHEN** un administrador publica una versión de contenido que la incluye
- **THEN** los usuarios con la app ya instalada reciben sus ejercicios al descargar el contenido
