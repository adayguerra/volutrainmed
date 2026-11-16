# Spec Delta

## Purpose

Garantiza que el producto se comporta como un entrenador formativo y nunca como una calculadora clínica ni como apoyo a decisiones sobre pacientes reales. De este límite depende su encaje fuera de la normativa de producto sanitario y su admisión en las tiendas.

## ADDED Requirements

### Requirement: Solo casos simulados

La app MUST presentar únicamente ejercicios procedentes de contenido publicado y validado, sin ofrecer ninguna función que calcule un resultado a partir de datos libres introducidos por el usuario.

#### Scenario: No existe entrada libre de datos

- **WHEN** se recorren todas las pantallas de la app
- **THEN** ninguna acepta un peso, un fármaco o una dosis libres para devolver un volumen, una dosis o un ritmo

#### Scenario: La respuesta del usuario solo se corrige

- **WHEN** el usuario introduce una cifra en un ejercicio
- **THEN** la app la compara con la respuesta del caso simulado y muestra un veredicto
- **AND** no calcula nada a partir de esa cifra

### Requirement: La pauta viene dada en el enunciado

Cada ejercicio MUST incluir la pauta que hay que aplicar como dato del enunciado, y la app MUST NOT recomendar ni proponer pautas.

#### Scenario: Enunciado con pauta

- **WHEN** se presenta un ejercicio de dosis por peso
- **THEN** el enunciado indica la pauta, por ejemplo «0,2 mg/kg», junto al resto de datos

#### Scenario: Límite de dosis como dato

- **WHEN** un ejercicio trabaja la dosis máxima
- **THEN** el límite aparece en el enunciado como dato del caso, no como recomendación de la app

### Requirement: Aviso formativo

La app MUST mostrar el aviso «VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales», exigir su aceptación expresa durante el alta y mantenerlo accesible en los ajustes.

#### Scenario: Aceptación obligatoria en el alta

- **WHEN** un usuario nuevo llega al paso del aviso formativo
- **THEN** no puede continuar hasta marcar «Lo entiendo»

#### Scenario: Aviso disponible en ajustes

- **WHEN** un usuario abre el apartado legal del perfil
- **THEN** puede leer de nuevo el aviso formativo completo

#### Scenario: Aviso sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** un usuario abre el aviso formativo
- **THEN** el texto se muestra completo, porque va incluido en la app

### Requirement: Casos rotulados como simulados

Los enunciados MUST identificar a personas y animales como casos simulados y nombrar los fármacos por su principio activo.

#### Scenario: Paciente simulado

- **WHEN** un enunciado menciona a una persona
- **THEN** la presenta como «paciente simulado» y sin ningún dato identificativo

#### Scenario: Principio activo

- **WHEN** un enunciado nombra un fármaco
- **THEN** usa su principio activo, no una marca comercial

### Requirement: Comunicación sin uso clínico

Los textos de la app, de las notificaciones, de los anuncios propios y de las fichas de las tiendas MUST describir el producto como entrenamiento y MUST NOT sugerir su uso durante la atención a pacientes.

#### Scenario: Ficha de la tienda

- **WHEN** se revisa la descripción publicada en las tiendas
- **THEN** habla de entrenar, aprender y ganar agilidad, e incluye el aviso formativo

#### Scenario: Texto con sugerencia de uso clínico

- **WHEN** un texto propuesto contiene una frase como «úsalo en tu guardia»
- **THEN** la revisión de contenido lo rechaza antes de publicarse
