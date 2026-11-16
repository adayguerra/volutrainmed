# Spec Delta

## Purpose

Define el modo contrarreloj, que entrena la agilidad en habilidades ya consolidadas, con una regla de precisión que impide premiar las respuestas rápidas y equivocadas.

## ADDED Requirements

### Requirement: Contrarreloj por habilidad consolidada

La app MUST abrir el contrarreloj de una habilidad solo cuando esa habilidad está en estado consolidada, dominada o por refrescar.

#### Scenario: Habilidad sin consolidar

- **WHEN** el usuario intenta empezar el contrarreloj de una habilidad en aprendizaje
- **THEN** la app indica que debe consolidarla antes y cómo conseguirlo

#### Scenario: Sin ninguna habilidad consolidada

- **WHEN** un usuario sin habilidades consolidadas abre el contrarreloj
- **THEN** ve «Consolida una habilidad para abrir el contrarreloj»

### Requirement: Esprint de sesenta segundos

El esprint MUST durar 60 segundos y presentar ejercicios de una sola habilidad, pasando al siguiente de inmediato tras cada respuesta.

#### Scenario: Acierto en el esprint

- **WHEN** el usuario acierta un ejercicio del esprint
- **THEN** el siguiente aparece de inmediato, sin banda de veredicto

#### Scenario: Esprint sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario completa un esprint
- **THEN** la marca se guarda en el dispositivo y se sincroniza al recuperar la conexión

### Requirement: Penalización por fallo

Cada fallo en el esprint MUST restar 3 segundos al tiempo restante, reiniciar el multiplicador de puntos y mostrar la respuesta correcta durante 1,2 segundos.

#### Scenario: Fallo con 20 segundos restantes

- **WHEN** el usuario falla con 20 segundos en el reloj
- **THEN** el reloj pasa a 17 segundos y el multiplicador vuelve a su valor inicial

### Requirement: Marca válida con precisión mínima

La app MUST considerar válida una marca de contrarreloj solo si la precisión es del 90 % o superior, y excluir las marcas no válidas de los récords.

#### Scenario: Marca no válida

- **WHEN** el usuario termina un esprint con 12 aciertos y 3 fallos, un 80 % de precisión
- **THEN** la app muestra «Marca no válida: precisión del 80 %. La rapidez solo cuenta con precisión»
- **AND** la marca no sustituye a su récord

#### Scenario: Récord

- **WHEN** el usuario termina con 15 aciertos y ningún fallo, superando su mejor marca
- **THEN** la app registra el nuevo récord

### Requirement: La interrupción anula el esprint

Si la app pasa a segundo plano durante un esprint, el esprint MUST anularse en lugar de pausarse.

#### Scenario: Interrupción

- **WHEN** entra una llamada durante un esprint
- **THEN** el esprint se anula, no se registra marca y la app lo explica al volver

### Requirement: Variante sin cuenta atrás

La app MUST ofrecer una variante del contrarreloj que mide el tiempo sin limitarlo, para quien no puede o no quiere usar la cuenta atrás.

#### Scenario: Ejercicios sin límite de tiempo

- **GIVEN** el ajuste «ejercicios sin límite de tiempo» activado
- **WHEN** el usuario empieza un contrarreloj
- **THEN** responde una serie de ejercicios sin cuenta atrás y al final ve su tiempo medio

### Requirement: Los fallos pasan al repaso

Los ejercicios fallados en un contrarreloj MUST entrar en la cola de repaso espaciado.

#### Scenario: Fallo en el esprint

- **WHEN** el usuario falla un ejercicio durante un esprint
- **THEN** la plantilla de ese ejercicio aparece en su repaso
