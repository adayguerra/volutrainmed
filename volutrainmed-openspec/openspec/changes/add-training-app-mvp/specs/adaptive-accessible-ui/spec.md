# Spec Delta

## Purpose

Define cómo se adapta la interfaz a móvil y tablet con una sola base de código, sin estirar la disposición del móvil, y los requisitos de accesibilidad que cumplen todas las pantallas.

## ADDED Requirements

### Requirement: Disposición por clase de tamaño

La app MUST adaptar navegación y disposición a tres clases de ancho: compacta (menos de 600 dp), media (de 600 a 839 dp) y expandida (840 dp o más).

#### Scenario: Móvil

- **WHEN** la app se abre en una pantalla de menos de 600 dp de ancho
- **THEN** la navegación es una barra inferior de cinco destinos con icono y etiqueta, y el contenido ocupa una columna

#### Scenario: Tablet en horizontal

- **WHEN** la app se abre en una pantalla de 840 dp o más de ancho
- **THEN** la navegación es un carril lateral y las pantallas principales muestran dos paneles

#### Scenario: Giro del dispositivo

- **WHEN** el usuario gira la tablet durante una sesión
- **THEN** la disposición cambia de clase sin perder la respuesta escrita ni el progreso

#### Scenario: Disposición sin conexión

- **GIVEN** el dispositivo sin conexión
- **WHEN** el usuario abre cualquier pantalla de entrenamiento
- **THEN** tipografías, iconos e ilustraciones se muestran completos, porque van incluidos en la app

### Requirement: La tablet no estira el móvil

En las clases media y expandida, la app MUST limitar el ancho del texto de lectura a 640 dp y el del teclado numérico a 420 dp, y dedicar el espacio restante a un panel con función propia.

#### Scenario: Sesión en tablet horizontal

- **WHEN** el usuario hace un ejercicio en una tablet en horizontal
- **THEN** ve el enunciado, la respuesta y el teclado a un lado y una hoja de borrador al otro

#### Scenario: Inicio en tablet horizontal

- **WHEN** el usuario abre Inicio en una tablet en horizontal
- **THEN** ve la ruta a la izquierda y el detalle de la unidad seleccionada a la derecha

### Requirement: Hoja de borrador no persistente

La hoja de borrador de la tablet MUST aceptar trazos de lápiz o de dedo, vaciarse al cambiar de ejercicio y no guardarse ni sincronizarse.

#### Scenario: Cambio de ejercicio

- **WHEN** el usuario pasa al ejercicio siguiente
- **THEN** la hoja de borrador aparece vacía

### Requirement: Contraste y color no exclusivo

Todo texto MUST tener un contraste mínimo de 4,5:1 con su fondo, y la app MUST NOT comunicar ningún estado solo con color.

#### Scenario: Veredicto

- **WHEN** se muestra el veredicto de un ejercicio
- **THEN** lleva un icono y la palabra «Correcto» o «Incorrecto», además del color

#### Scenario: Tema oscuro

- **WHEN** el usuario activa el tema oscuro
- **THEN** todos los textos mantienen un contraste de 4,5:1 como mínimo

### Requirement: Texto ampliable

La app MUST admitir el tamaño de texto del sistema hasta el 200 % sin truncar contenido ni ocultar controles.

#### Scenario: Texto al 200 %

- **GIVEN** el tamaño de texto del sistema al 200 %
- **WHEN** se presenta un ejercicio con un enunciado largo
- **THEN** el enunciado se desplaza y el teclado y la acción «Comprobar» siguen visibles

### Requirement: Objetivos táctiles

Todo control interactivo MUST tener un área táctil de 48 dp por 48 dp como mínimo y 8 dp de separación con los controles vecinos.

#### Scenario: Icono pequeño

- **WHEN** un control muestra un icono de 24 dp
- **THEN** su área táctil mide al menos 48 dp por 48 dp

### Requirement: Compatibilidad con lector de pantalla

Todo control MUST tener un nombre accesible, el orden de lectura MUST coincidir con el visual y las cantidades MUST leerse completas con su unidad.

#### Scenario: Lectura de una cantidad

- **WHEN** el lector de pantalla llega a «0,2 mg/kg»
- **THEN** anuncia «cero coma dos miligramos por kilo»

#### Scenario: Anuncio del veredicto

- **WHEN** el usuario comprueba una respuesta incorrecta con el lector activo
- **THEN** el lector anuncia «Incorrecto» y la respuesta correcta con su unidad

### Requirement: Movimiento reducido

Con la preferencia de movimiento reducido activada, la app MUST sustituir las animaciones por fundidos de 150 ms y suprimir las celebraciones animadas.

#### Scenario: Fin de lección con movimiento reducido

- **GIVEN** la preferencia de movimiento reducido activada
- **WHEN** el usuario termina una lección
- **THEN** las cifras aparecen con su valor final, sin conteo ni llenado animado

### Requirement: Alternativa a los gestos

Toda acción que pueda hacerse con un arrastre o un gesto MUST poder hacerse también con toques o botones.

#### Scenario: Ordenar pasos sin arrastrar

- **WHEN** el usuario toca los pasos de un ejercicio de ordenar en el orden deseado
- **THEN** los pasos quedan ordenados sin necesidad de arrastrarlos

#### Scenario: Cerrar una hoja

- **WHEN** se abre la hoja de corrección
- **THEN** puede cerrarse con un botón, además de con el gesto

### Requirement: Respuesta háptica y sonora configurable

La app MUST acompañar aciertos, fallos e hitos con señales hápticas y sonoras distintas, respetar el modo silencio del dispositivo y permitir desactivar cada tipo de señal.

#### Scenario: Modo silencio

- **GIVEN** el dispositivo en modo silencio
- **WHEN** el usuario acierta un ejercicio
- **THEN** no suena ningún tono y sí se percibe la señal háptica

#### Scenario: Háptica desactivada

- **GIVEN** la respuesta háptica desactivada en ajustes
- **WHEN** el usuario pulsa una tecla
- **THEN** no hay vibración
