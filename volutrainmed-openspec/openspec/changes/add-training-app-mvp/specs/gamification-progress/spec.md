# Spec Delta

## Purpose

Define los elementos de motivación del producto mínimo viable y la presentación del progreso: metas, rachas, puntos, niveles, logros fijos, pantalla de fin de lección y estadísticas por habilidad, con un tono adecuado a un público profesional.

## ADDED Requirements

### Requirement: Meta de práctica diaria o semanal

La app MUST permitir elegir una meta diaria de 5, 10 o 15 minutos de práctica, o una meta semanal de días de práctica para quien trabaja a turnos.

#### Scenario: Meta diaria cumplida

- **GIVEN** una meta diaria de 5 minutos
- **WHEN** el usuario acumula 5 minutos de práctica en el día
- **THEN** el anillo de meta se completa

#### Scenario: Meta semanal

- **GIVEN** una meta semanal de 4 días
- **WHEN** el usuario practica 4 días de una semana, no consecutivos
- **THEN** la meta de esa semana se cumple y su racha semanal aumenta

### Requirement: Racha

La app MUST llevar una racha de días o semanas con la meta cumplida y, cuando se interrumpe, comunicarlo sin reproches.

#### Scenario: Racha extendida

- **WHEN** el usuario cumple la meta un día más
- **THEN** la racha aumenta en uno

#### Scenario: Racha interrumpida

- **GIVEN** una racha de 12 días
- **WHEN** el usuario no cumple la meta un día y vuelve al siguiente
- **THEN** la app muestra «Tu racha se quedó en 12 días. Hoy empieza otra»

#### Scenario: Racha sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario cumple la meta
- **THEN** la racha se actualiza en el dispositivo

### Requirement: Puntos por aciertos al primer intento

La app MUST otorgar puntos solo por los ejercicios acertados al primer intento.

#### Scenario: Segundo intento

- **WHEN** el usuario falla un ejercicio y acierta el segundo intento con otros números
- **THEN** no recibe puntos por ese ejercicio

#### Scenario: Acierto al primer intento

- **WHEN** el usuario acierta un ejercicio al primer intento
- **THEN** recibe los puntos del ejercicio

### Requirement: Niveles

La app MUST asignar al usuario un nivel según sus puntos acumulados y comunicar la subida de nivel con una celebración breve que se puede saltar.

#### Scenario: Subida de nivel

- **WHEN** los puntos del usuario alcanzan el umbral del nivel siguiente
- **THEN** al terminar la lección aparece una celebración de 1,2 segundos como máximo, que se cierra con un toque

### Requirement: Logros fijos

La app MUST conceder cinco logros: primera lección completada, siete días de racha, primera unidad dominada, primera sesión manos libres y cien ejercicios sin error crítico.

#### Scenario: Primera sesión manos libres

- **WHEN** el usuario completa su primera sesión manos libres
- **THEN** obtiene el logro correspondiente y lo ve en su perfil

### Requirement: Fin de lección

Al terminar una lección, la app MUST mostrar la precisión, el tiempo medio frente al objetivo, los puntos obtenidos, la racha si se ha cumplido la meta, las habilidades que cambian de estado y la lista de fallos.

#### Scenario: Lección con fallos

- **WHEN** el usuario termina una lección con 8 aciertos de 10
- **THEN** ve «Lección completada: 2 fichas van a repaso», sus cifras y los dos fallos con su tipo de error

#### Scenario: Cambio de estado de una habilidad

- **WHEN** una habilidad pasa a «consolidada» durante la lección
- **THEN** la pantalla de fin de lección lo indica

### Requirement: Estadísticas por habilidad

La app MUST mostrar por habilidad la evolución de la precisión, el tiempo mediano y los errores por tipo, cada gráfica con una frase de resumen y una vista alternativa en tabla.

#### Scenario: Evolución de la precisión

- **WHEN** el usuario abre el detalle de una habilidad
- **THEN** ve su precisión semanal y una frase como «Tu precisión ha pasado del 82 % al 93 % en cuatro semanas»

#### Scenario: Datos insuficientes

- **WHEN** un usuario con menos de tres sesiones abre Progreso
- **THEN** ve «Completa tres sesiones para ver tu evolución»

#### Scenario: Estadísticas sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario abre Progreso
- **THEN** ve sus estadísticas calculadas en el dispositivo

### Requirement: Fallar no bloquea la práctica

La app MUST permitir seguir practicando con independencia del número de fallos, sin vidas, esperas ni bloqueos.

#### Scenario: Lección con muchos fallos

- **WHEN** el usuario falla siete ejercicios seguidos
- **THEN** la lección continúa y puede empezar otra a continuación
