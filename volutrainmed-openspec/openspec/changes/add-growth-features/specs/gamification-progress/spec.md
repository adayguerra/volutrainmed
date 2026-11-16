# Spec Delta

## Purpose

Los cinco logros fijos del producto mínimo viable pasan a ser logros configurables desde el back office, sin perder ninguno de ellos ni el progreso de quien ya los obtuvo.

## MODIFIED Requirements

### Requirement: Logros fijos

La app MUST conceder los logros definidos en el contenido publicado, que incluyen al menos los cinco logros del producto mínimo viable (primera lección completada, siete días de racha, primera unidad dominada, primera sesión manos libres y cien ejercicios sin error crítico), y MUST evaluar en el dispositivo, también sin conexión, cada logro configurado por su condición de métrica, operador, valor y ámbito.

#### Scenario: Primera sesión manos libres

- **WHEN** el usuario completa su primera sesión manos libres
- **THEN** obtiene el logro correspondiente y lo ve en su perfil

#### Scenario: Logro configurado en el back office

- **GIVEN** un logro «30 días de racha» publicado desde el back office
- **WHEN** el usuario alcanza 30 días de racha
- **THEN** la app le concede el logro sin necesidad de una versión nueva

#### Scenario: Logro obtenido sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario cumple la condición de un logro configurado
- **THEN** la app concede el logro en el dispositivo y lo sincroniza al recuperar la conexión
