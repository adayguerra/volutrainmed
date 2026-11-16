# Spec Delta

## Purpose

Define cómo se corrige una respuesta: aritmética decimal exacta, veredictos, redondeo, tratamiento de unidades, diagnóstico del tipo de error, errores críticos, explicación paso a paso y segundo intento. Los ejemplos farmacológicos están pendientes de validación por un profesional.

## ADDED Requirements

### Requirement: Aritmética decimal exacta

La corrección MUST comparar cifras decimales de forma exacta, sin errores de representación.

#### Scenario: Suma de decimales

- **WHEN** la respuesta correcta de un ejercicio es 0,3 y resulta de sumar 0,1 y 0,2
- **THEN** la respuesta «0,3» se da por correcta

### Requirement: Tres veredictos

La app MUST clasificar cada respuesta como correcta, correcta con observación o incorrecta.

#### Scenario: Más decimales de los pedidos

- **GIVEN** un ejercicio cuya respuesta es 0,27 ml tras redondear a la centésima
- **WHEN** el usuario responde «0,2667»
- **THEN** el veredicto es «correcta con observación» y la nota indica «Se redondea a 0,27 ml»

#### Scenario: Formato inseguro

- **WHEN** el usuario responde «,5» o «5,0»
- **THEN** la app normaliza la cifra a «0,5» o «5» y lo indica con una nota

#### Scenario: Respuesta incorrecta

- **WHEN** el usuario responde una cifra fuera de la tolerancia
- **THEN** el veredicto es «incorrecta» y se muestra la respuesta correcta con su unidad

### Requirement: Redondeo indicado

Cuando el resultado no es exacto, el enunciado MUST indicar cómo redondear, por decimales o por instrumento de medida, y la corrección MUST aplicar redondeo aritmético.

#### Scenario: Gota entera

- **GIVEN** 1000 ml en 8 horas con un sistema de 20 gotas/ml, redondeando a gota entera
- **WHEN** el usuario responde «42»
- **THEN** la respuesta es correcta, porque 41,67 redondea a 42 gotas/min

#### Scenario: Jeringa de 1 ml

- **GIVEN** un resultado de 0,2667 ml que se mide con una jeringa de 1 ml
- **WHEN** el usuario responde «0,27»
- **THEN** la respuesta es correcta

### Requirement: Unidades de la respuesta

La corrección MUST aceptar las unidades equivalentes que declare el ejercicio y dar por incorrecta una cifra correcta expresada en una unidad equivocada.

#### Scenario: Unidad equivalente

- **GIVEN** un ejercicio cuya respuesta es 0,5 mg y que admite microgramos
- **WHEN** el usuario responde «500 µg»
- **THEN** la respuesta es correcta

#### Scenario: Unidad equivocada

- **GIVEN** un ejercicio cuya respuesta es 0,5 mg
- **WHEN** el usuario responde «0,5 µg»
- **THEN** la respuesta es incorrecta y el diagnóstico es de unidad

### Requirement: Diagnóstico del tipo de error

Cuando una respuesta incorrecta coincide con una respuesta errónea previsible del ejercicio, la app MUST indicar el tipo de error en una frase: unidad, orden de magnitud, operación invertida, paso omitido, dato equivocado, límite no aplicado o redondeo.

#### Scenario: Factor diez

- **GIVEN** un ejercicio cuya respuesta es 0,96 ml
- **WHEN** el usuario responde «9,6»
- **THEN** el diagnóstico indica que la respuesta es diez veces mayor

#### Scenario: Paso omitido

- **GIVEN** un ejercicio que pide el volumen y cuyo valor intermedio es 4,8 mg
- **WHEN** el usuario responde «4,8»
- **THEN** el diagnóstico indica que ha dado la dosis y falta calcular el volumen

#### Scenario: Error sin clasificar

- **WHEN** la respuesta incorrecta no coincide con ningún error previsible
- **THEN** la app muestra la respuesta correcta y la explicación, sin diagnóstico

### Requirement: Errores críticos

La app MUST marcar como crítico todo error de unidad, de orden de magnitud o de límite no aplicado, y toda respuesta que se desvíe del valor correcto en un factor de 5 o más.

#### Scenario: Desviación de factor cinco

- **GIVEN** un ejercicio cuya respuesta es 2 ml
- **WHEN** el usuario responde «10»
- **THEN** el intento se registra como error crítico

#### Scenario: Dosis máxima no aplicada

- **GIVEN** un ejercicio con pauta de 15 mg/kg, máximo de 1 g por dosis, paciente simulado de 70 kg y presentación de 10 mg/ml
- **WHEN** el usuario responde «105 ml» en lugar de «100 ml»
- **THEN** el intento se registra como error crítico de límite no aplicado

### Requirement: Explicación paso a paso

Tras una respuesta incorrecta, la app MUST mostrar el veredicto en menos de 300 ms y una explicación por pasos, con la operación de cada paso, las unidades que se cancelan, el paso en el que se desvió el usuario y una comprobación de plausibilidad.

#### Scenario: Explicación de una perfusión

- **GIVEN** un ejercicio de noradrenalina a 0,1 µg/kg/min, paciente simulado de 80 kg y dilución de 100 µg/ml
- **WHEN** el usuario responde «0,08 ml/h»
- **THEN** la explicación muestra los pasos hasta 4,8 ml/h y marca el paso de minutos a horas como el del desvío

#### Scenario: Explicación a demanda tras un acierto

- **WHEN** el usuario acierta y toca «Ver cómo se hace»
- **THEN** se muestra la misma explicación por pasos

### Requirement: Segundo intento con otros números

Tras un fallo, la app MUST ofrecer un segundo intento inmediato con otra variante de la misma plantilla, que no otorga puntos.

#### Scenario: Segundo intento acertado

- **WHEN** el usuario acierta el segundo intento
- **THEN** la lección continúa, no se suman puntos y el primer fallo permanece en la cola de repaso

### Requirement: Corrección con valores verificados

La app MUST corregir comparando la respuesta con los valores del contenido publicado y verificado, también sin conexión.

#### Scenario: Corrección en modo avión

- **GIVEN** el dispositivo en modo avión
- **WHEN** el usuario responde un ejercicio
- **THEN** recibe el veredicto, el diagnóstico y la explicación completos
