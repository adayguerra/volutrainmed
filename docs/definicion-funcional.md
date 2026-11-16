# VolutrainMed — Definición funcional

Nov 16, 2026 · @Aday Francisco Guerra

VolutrainMed es un entrenador móvil de cálculo de dosis y volúmenes para sanitarios y veterinarios, con sesiones cortas, corrección paso a paso y un modo manos libres que funciona sin nube. Este documento define producto, pantallas, voz, back office, datos y arquitectura para que diseño y desarrollo puedan empezar.

## Decisiones clave

| Decisión | Elección | Sección |
| --- | --- | --- |
| Límite del producto | Entrenador con casos simulados. Sin calculadora y sin datos de pacientes | 1 y 11 |
| Aprendizaje | Progreso por habilidad, repaso espaciado y error clasificado y explicado | 2 |
| Ejercicios | Diez tipos; cinco en el producto mínimo viable | 3 |
| Voz | Modelo embebido, vocabulario cerrado y confirmación antes de corregir | 7 y 10 |
| Contenido | Plantillas parametrizadas, variantes generadas y verificadas en el servidor, y validación por un experto | 8 y 10 |
| Diseño | Accesible y minimalista, sobre la skill UI/UX Pro Max. Sin mascota | 6 |
| Tecnología | Flutter, sherpa-onnx, SQLite con sincronización propia, Supabase en la UE y back office en React | 10 |
| Alcance | Producto mínimo viable con dos itinerarios, manos libres y back office de contenido. Ligas y organizaciones, después | 13 |

Estado: primera versión para revisión. Todos los ejemplos de ejercicio están pendientes de validación por un profesional. No se han hecho preguntas previas: las decisiones tomadas en su lugar figuran como supuestos en la sección 14, junto a ocho preguntas abiertas.

## 1. Visión de producto

VolutrainMed es un entrenador de cálculo de dosis y volúmenes: el usuario practica con casos simulados hasta resolverlos rápido y sin errores. En ningún punto del producto se calcula nada para un paciente real.

### 1.1 Propuesta de valor

El cálculo de dosis se aprende una vez y después se oxida. Se practica poco, casi siempre bajo presión y sin corrección inmediata. Los fallos habituales (un factor de diez, una unidad cambiada, minutos por horas) no son de conocimiento, sino de automatismo.

VolutrainMed convierte ese cálculo en un hábito de entrenamiento:

- **Exactitud primero, agilidad después.** Sesiones de 3 a 5 minutos con corrección inmediata y resolución paso a paso. El contrarreloj solo se abre cuando la habilidad ya está dominada.
- **Manos libres sin nube.** La app lee la pregunta y escucha la respuesta con procesamiento íntegro en el dispositivo. Funciona en modo avión.
- **El lenguaje de cada sector.** Itinerarios, fármacos, unidades y vocabulario propios de enfermería, anestesia, emergencias, farmacia, medicina o veterinaria.
- **Contenido validado y trazable.** Cada ejercicio publicado tiene autor, revisor experto y versión.
- **Sin conexión por defecto.** Contenido descargado, progreso en local y sincronización cuando hay red.

### 1.2 Lo que el producto no es

El límite entre entrenador y calculadora clínica condiciona el diseño, los textos y el encaje regulatorio (sección 11).

| Entrenador (dentro del producto) | Calculadora clínica (fuera del producto) |
| --- | --- |
| Casos simulados, generados a partir de plantillas validadas | Introducir los datos de un paciente real |
| La pauta (mg/kg, ritmo, límite) viene dada en el enunciado | Recomendar o proponer una dosis |
| El usuario calcula y la app corrige | La app calcula y el usuario administra |
| El resultado es progreso de aprendizaje | El resultado es una cifra para administrar |

Regla de diseño derivada: no existe ninguna pantalla con campos libres de peso, fármaco y dosis que devuelva un resultado.

### 1.3 Perfiles de usuario por sector

| Sector | Perfil tipo | Objetivo | Contexto de uso | Cálculos propios |
| --- | --- | --- | --- | --- |
| Enfermería | Estudiante de grado, opositor (EIR, OPE), enfermera de planta o de críticos | Superar pruebas de cálculo y preparar medicación con seguridad | Transporte, pausas, estudio en casa | ml/h, gotas/min, diluciones, UI (insulina, heparina), dosis por toma |
| Medicina | Estudiante y residente | Pautar sin dudar en la guardia | Ratos cortos entre actividad docente | mg/kg, dosis máximas, perfusiones, conversiones |
| Anestesia y reanimación | Residente, adjunto, enfermería de anestesia | Automatizar diluciones y perfusiones habituales | Desplazamientos y antes del turno; manos libres | µg/kg/min, dilución de vasoactivos, dosis máxima de anestésico local, concentraciones en % |
| Emergencias | Técnico (TES), enfermería y medicina de urgencias | Calcular rápido y bien bajo presión | Base sin actividad, zonas sin cobertura | Adrenalina 1:1000 y 1:10 000, dosis pediátricas por peso, perfusiones |
| Farmacia | Estudiante, farmacia hospitalaria, técnico | Exactitud en reconstitución y mezclas | Estudio y formación interna | Reconstitución, %, proporciones, concentración final |
| Pediatría (transversal) | Residentes y enfermería pediátrica | Evitar el error de factor diez | El de su sector base | mg/kg/día repartido en tomas, suspensiones en mg/5 ml, dosis máxima |
| Veterinaria | Estudiante, veterinario clínico, auxiliar | Dosificar por especie y peso con concentraciones muy distintas | Clínica entre consultas, con guantes; manos libres | mg/kg por especie, volúmenes muy pequeños, infusiones continuas, ml/kg/día |

El modo manos libres sirve para entrenar con las manos ocupadas o con guantes: prácticas, laboratorio, desplazamientos a pie, tareas domésticas. No está pensado para usarse mientras se atiende a un paciente ni se promociona para conducir.

### 1.4 Principios de diseño

1. **Entrenador, no calculadora.** Todo caso es simulado y la pauta viene dada. Motivo: mantiene el propósito formativo y evita que un resultado se use para administrar.
2. **Exactitud antes que velocidad.** La rapidez solo puntúa con precisión alta. Motivo: practicar rápido lo que aún se hace mal consolida el error.
3. **La unidad forma parte de la respuesta.** Siempre visible, siempre exigida. Motivo: los errores graves de medicación suelen ser de unidad o de orden de magnitud, no de aritmética fina.
4. **El error es el material de trabajo.** Cada fallo se clasifica, se explica y vuelve en el repaso. No hay vidas ni bloqueos por fallar. Motivo: castigar el error lleva a evitar los ejercicios difíciles, que son los que más enseñan.
5. **Cinco minutos, una mano o ninguna.** Sesiones cortas, operables con el pulgar o por voz. Motivo: el hábito se sostiene en huecos pequeños del día.
6. **Sin conexión como norma.** La red solo mejora la experiencia; nunca la bloquea. Motivo: hospitales, sótanos y vehículos tienen mala cobertura.
7. **Profesional, no infantil.** Se celebra el dominio con sobriedad. Motivo: el usuario es un sanitario adulto; el tono condiciona la credibilidad del contenido.
8. **Contenido validado y trazable.** Nada se publica sin revisión experta. Motivo: un ejemplo erróneo entrena un error.
9. **Mismo motor, lenguaje del sector.** Un veterinario ve especies y un anestesista ve perfusiones. Motivo: la transferencia al trabajo real es mayor cuando el caso se parece al propio.
10. **Privacidad por diseño.** La voz no sale del dispositivo y se recogen los datos mínimos.
11. **Accesible por defecto.** Contraste 4,5:1 como mínimo, texto ampliable, objetivos táctiles de 44 pt o 48 dp, y alternativa a todo gesto y a toda señal de color.

## 2. Modelo pedagógico

El contenido se organiza en cinco niveles y el progreso se mide por habilidad, no por pantallas completadas. Cada fallo se clasifica, se explica paso a paso y vuelve en el repaso espaciado.

### 2.1 Estructura del contenido

| Nivel | Qué es | Ejemplo | Tamaño orientativo |
| --- | --- | --- | --- |
| Sector | Ámbito profesional. Fija vocabulario, fármacos y ejemplos | Veterinaria | 7 en el catálogo completo |
| Itinerario | Recorrido con un objetivo formativo dentro de un sector | Anestesia de pequeños animales | 2 a 5 por sector |
| Unidad | Bloque temático que trabaja de 1 a 3 habilidades | Infusiones continuas | 6 a 12 por itinerario |
| Lección | Sesión de 3 a 5 minutos | Infusión en µg/kg/min: práctica guiada | 4 a 6 por unidad |
| Ejercicio | Una variante numérica de una plantilla, con una mecánica concreta | Lidocaína a 50 µg/kg/min en un perro de 20 kg | 8 a 12 por lección |

Dos entidades cruzan esa jerarquía:

- **Plantilla.** Define un ejercicio con variables, rangos, fórmula, unidades y tolerancia. De cada plantilla se generan cientos de variantes numéricas validadas (sección 8.5).
- **Habilidad.** Es lo que se aprende y lo que se mide. Una plantilla entrena una habilidad principal y, si acaso, alguna secundaria.

Catálogo inicial de habilidades, común a todos los sectores:

| Código | Habilidad |
| --- | --- |
| H1 | Conversión de unidades de masa, volumen y tiempo |
| H2 | Concentraciones: mg/ml, porcentaje, razones 1:N y UI/ml |
| H3 | Dosis por peso (mg/kg, µg/kg, UI/kg) |
| H4 | Volumen a cargar según la concentración |
| H5 | Dosis diaria repartida en tomas |
| H6 | Reconstitución y dilución |
| H7 | Ritmo de perfusión en ml/h |
| H8 | Goteo en gotas/min |
| H9 | Perfusión por peso y tiempo (µg/kg/min y ml/h) |
| H10 | Dosis máxima y comprobación de límites |
| H11 | Redondeo según el instrumento de medida |
| H12 | Estimación y plausibilidad del resultado |

Todos los sectores comparten un itinerario de **Fundamentos** (H1, H2, H4, H11 y H12). La prueba de nivel permite saltarlo a quien ya lo domina.

### 2.2 Progresión de dificultad

Dentro de cada unidad las lecciones siguen siempre la misma secuencia. El motivo es retirar la ayuda de forma gradual: primero se ve el procedimiento, luego se completa y al final se ejecuta sin apoyo.

| Lección | Qué hace el usuario | Motivo de aprendizaje |
| --- | --- | --- |
| 1. Concepto guiado | Sigue un ejemplo resuelto y completa pasos sueltos | Un ejemplo resuelto reduce la carga cuando el procedimiento es nuevo |
| 2. Práctica con apoyos | Resuelve con el planteamiento visible y pistas disponibles | La ayuda se retira poco a poco |
| 3. Práctica libre | Resuelve sin planteamiento ni pistas | Recuperar el procedimiento de memoria lo fija |
| 4. Mixta | Alterna la habilidad nueva con las anteriores | Intercalar obliga a decidir qué procedimiento toca, que es lo que ocurre en la práctica |
| 5. Reto de unidad | 10 ejercicios sin pistas; se supera con 9 aciertos y ningún error crítico | Comprueba el dominio antes de abrir la unidad siguiente |

Cada plantilla tiene cinco niveles de dificultad, que el autor construye combinando cinco mandos:

| Mando | Nivel bajo | Nivel alto |
| --- | --- | --- |
| Números | Enteros y resultados limpios | Decimales incómodos y redondeo |
| Pasos | Un paso | Tres o cuatro pasos encadenados |
| Unidades | Alineadas | Con conversión intermedia |
| Datos | Los justos | Con datos sobrantes |
| Tiempo | Sin referencia | Con tiempo objetivo visible |

Dentro de una lección la dificultad se ajusta sola: tres aciertos seguidos dentro del tiempo objetivo suben un nivel; dos fallos seguidos lo bajan y muestran el planteamiento.

### 2.3 Repetición espaciada

Lo que se programa para repasar es la **ficha de repaso**: una plantilla en un nivel de dificultad. Cada repaso usa una variante numérica distinta, para que se recuerde el procedimiento y no la cifra.

El calendario lo calcula el algoritmo abierto FSRS, con una retención objetivo del 90 %. Frente a un sistema de cajas con intervalos fijos, ajusta el intervalo de cada ficha a la dificultad y al historial de cada usuario. La calificación no se pregunta: se deduce de la respuesta.

| Calificación FSRS | Cuándo se asigna |
| --- | --- |
| Otra vez | Respuesta incorrecta o «no lo sé» |
| Difícil | Correcta con pista, o en más del doble del tiempo objetivo |
| Bien | Correcta al primer intento |
| Fácil | Correcta al primer intento en menos del 60 % del tiempo objetivo |

Reglas propias sobre el algoritmo:

- **Cuarentena de errores críticos.** Tras un error crítico la ficha vuelve al día siguiente y no alarga su intervalo hasta acumular dos aciertos en días distintos.
- **Tope diario.** 20 fichas de repaso al día por defecto, configurable entre 10 y 40. Evita una cola inabarcable tras unos días sin entrar.
- **Orden.** Primero las fichas con error crítico, después las más vencidas.

### 2.4 Criterios de dominio

El dominio se calcula por habilidad, con los ejercicios respondidos al primer intento.

| Estado | Criterio |
| --- | --- |
| Nueva | Sin intentos |
| En aprendizaje | Con intentos, sin alcanzar el siguiente estado |
| Consolidada | 85 % de acierto o más en los últimos 20 ejercicios, en al menos 2 días distintos |
| Dominada | 95 % o más en los últimos 20, en al menos 3 días repartidos en 7 o más, sin errores críticos y con mediana de tiempo dentro del objetivo |
| Por refrescar | Dominada con un fallo en repaso o con fichas vencidas más de 14 días. Se recupera con 3 repasos correctos seguidos |

El **tiempo objetivo** lo fija el autor por plantilla y nivel. Cuando una plantilla acumula 200 respuestas correctas de usuarios con la habilidad dominada, el back office propone recalibrarlo con el percentil 40 de esos tiempos.

El contrarreloj de una habilidad se abre cuando pasa a Consolidada. Antes de ese punto, entrenar la velocidad fijaría errores.

### 2.5 Tratamiento del error

Cada plantilla declara sus **respuestas erróneas previsibles**: el resultado que se obtiene al cometer un fallo conocido. Si la respuesta del usuario coincide con una de ellas, la app sabe qué ha pasado y lo explica.

| Código | Tipo de error | Cómo se detecta | Crítico |
| --- | --- | --- | --- |
| E1 | Unidad | Coincide con el resultado sin una conversión (mg por µg, minutos por horas) | Sí |
| E2 | Orden de magnitud | La respuesta es la correcta multiplicada o dividida por 10, 100 o 1000 | Sí |
| E3 | Operación invertida | Coincide con dividir donde había que multiplicar, o al revés | Según la desviación |
| E4 | Paso omitido | Coincide con un resultado intermedio (da los mg cuando se piden los ml) | No |
| E5 | Dato equivocado | Usa un dato sobrante del enunciado | No |
| E6 | Límite no aplicado | Supera la dosis máxima indicada en el enunciado | Sí |
| E7 | Redondeo | Valor correcto mal redondeado | No; cuenta como correcta con observación |
| E0 | Sin clasificar | No coincide con ningún patrón | Según la desviación |

Además de E1, E2 y E6, es crítica cualquier respuesta que se desvíe del valor correcto en un factor de 5 o más.

Secuencia tras un fallo:

1. **Veredicto inmediato**, en menos de 300 ms, con la respuesta correcta y su unidad.
2. **Diagnóstico en una frase**: «Tu respuesta es diez veces mayor. Revisa la coma al pasar de µg a mg».
3. **Resolución paso a paso** por análisis dimensional. Cada paso muestra la operación con las unidades que se cancelan y se revela de uno en uno. El paso donde se desvió el usuario queda marcado.
4. **Comprobación de plausibilidad**: «0,96 ml en una jeringa de 1 ml. Tiene sentido».
5. **Segundo intento con otros números**, inmediato y sobre la misma plantilla. No puntúa; sirve para salir de la pantalla habiendo acertado.
6. **Ficha al repaso**, con calificación «Otra vez».

«No lo sé» es una respuesta de pleno derecho: lleva directamente a la resolución guiada y cuenta como «Otra vez». Motivo: es preferible reconocer la duda a responder al azar, también como hábito profesional.

## 3. Catálogo de tipos de ejercicio

El catálogo inicial tiene diez tipos y su núcleo es la respuesta numérica con unidad. Todos comparten las mismas reglas de corrección, redondeo y unidades.

**Todos los ejemplos de este documento están pendientes de validación por un profesional antes de publicarse.** Las pautas aparecen en el enunciado para entrenar el cálculo; no son recomendaciones de dosis.

### 3.1 Reglas comunes

**Corrección numérica**

- La aritmética es decimal exacta, nunca de coma flotante binaria. Motivo: 0,1 + 0,2 debe dar 0,3 también en la corrección.
- Hay tres veredictos: correcta, correcta con observación e incorrecta.
- La tolerancia se define en la plantilla: exacta sobre el valor redondeado (por defecto), absoluta (± x en la unidad de respuesta) o relativa (± x %).
- El redondeo es aritmético: el 5 sube. El enunciado indica siempre cómo redondear cuando el resultado no es exacto, por decimales o por instrumento.
- «Correcta con observación» cubre dos casos: más decimales de los pedidos que redondean al valor correcto (0,2667 por 0,27) y formato inseguro («,5» o «5,0»).

**Redondeo por instrumento** (catálogo editable en el back office; valores pendientes de validación)

| Instrumento | Precisión de la respuesta |
| --- | --- |
| Jeringa de 1 ml | 0,01 ml |
| Jeringa de 2 o 3 ml | 0,1 ml |
| Jeringa de 5 o 10 ml | 0,2 ml |
| Jeringa de 20 o 50 ml | 1 ml |
| Bomba de perfusión | 0,1 ml/h |
| Sistema de goteo | Gota entera |

**Formato de los números**

- Coma decimal en pantalla. El punto se acepta al escribir y se convierte.
- Cero delante de la coma siempre (0,5) y ningún cero final (5, no 5,0). Motivo: son las dos convenciones de escritura que evitan leer una dosis diez veces mayor o menor. La app las enseña normalizando la respuesta y avisando.
- Sin separador de miles al escribir. En pantalla, espacio fino a partir de cinco cifras (12 500). Nunca punto de millar.

**Unidades**

- En los niveles 1 a 3 la unidad de respuesta es fija y aparece como sufijo del campo. En los niveles 4 y 5 el usuario la elige.
- Si la plantilla lo permite, se aceptan unidades equivalentes (0,5 mg o 500 µg).
- El valor correcto con la unidad equivocada es incorrecto, con diagnóstico E1.
- En pantalla se usa «µg». Una organización puede cambiarlo a «mcg» o a la palabra completa. La voz dice siempre «microgramos» y «unidades internacionales».

**Formas de entrada**

- **Teclado numérico propio**: cifras, coma, borrar y fila de unidades. Teclas de 56 dp como mínimo. Motivo: el teclado del sistema cambia según el dispositivo, tapa media pantalla y no siempre ofrece la coma.
- **Voz**: número y, si la unidad no es fija, unidad (sección 7).
- **Selección** y **ordenación**: por toque, con alternativa a todo arrastre.

### 3.2 Resumen del catálogo

| Tipo | Mecánica | Entrada | Manos libres | Habilidades típicas | Fase |
| --- | --- | --- | --- | --- | --- |
| T1 Respuesta numérica | Caso simulado con pauta; una respuesta con unidad | Teclado, voz | Sí | Todas | MVP |
| T2 Selección única | Elegir entre 3 o 4 opciones | Toque, voz | Sí | H2, H10, H11 | MVP |
| T3 Ordenar pasos | Poner en orden los pasos de un cálculo | Toque o arrastre | No | H6, H9 | MVP |
| T4 Completar el planteamiento | Colocar fichas en los huecos de la operación | Toque | No | H3, H4, H5, H9 | 2 |
| T5 Detectar el error | Señalar el paso equivocado de un cálculo resuelto | Toque, voz | Sí | H10, H12 | 2 |
| T6 Estimación rápida | Elegir la franja en la que cae el resultado | Toque, voz | Sí | H12 | MVP |
| T7 Conversión relámpago | Serie corta de conversiones con tiempo | Teclado, voz | Sí | H1, H2 | MVP |
| T8 Caso encadenado | De 2 a 4 respuestas sucesivas sobre un mismo caso | Teclado, voz | Sí | H6, H9 | 2 |
| T9 Marcar en la jeringa | Llevar el émbolo hasta el volumen | Gesto y botones | No | H11 | 3 |
| T10 Emparejar | Unir equivalencias | Toque | No | H2 | 2 |

### 3.3 T1. Respuesta numérica con unidad

- **Mecánica.** Enunciado con un caso simulado, la pauta y la presentación. El usuario da una cifra.
- **Entrada.** Teclado propio o voz.
- **Corrección.** Exacta tras el redondeo indicado, salvo tolerancia de la plantilla. Si coincide con una respuesta errónea previsible, se muestra su diagnóstico.
- **Unidades.** Fija en los niveles 1 a 3; a elegir en los niveles 4 y 5.

**Ejemplo A. Dosis por peso y volumen (veterinaria).** Perro de 24 kg. Pauta: meloxicam 0,2 mg/kg por vía subcutánea. Presentación: 5 mg/ml. ¿Qué volumen cargas?

1. Dosis: 0,2 mg/kg × 24 kg = 4,8 mg.
2. Volumen: 4,8 mg ÷ 5 mg/ml = 0,96 ml.

Respuesta: **0,96 ml**. Cabe en una jeringa de 1 ml. Errores previsibles: 9,6 ml (E2), 4,8 (E4, da los mg) y 24 (E3, multiplica por la concentración).

**Ejemplo B. Perfusión por peso y tiempo (anestesia).** Paciente simulado de 80 kg. Pauta: noradrenalina a 0,1 µg/kg/min. Dilución: 10 mg en 100 ml. ¿A qué ritmo programas la bomba, en ml/h?

1. Concentración: 10 mg ÷ 100 ml = 0,1 mg/ml = 100 µg/ml.
2. Dosis por minuto: 0,1 µg/kg/min × 80 kg = 8 µg/min.
3. Dosis por hora: 8 µg/min × 60 min/h = 480 µg/h.
4. Ritmo: 480 µg/h ÷ 100 µg/ml = 4,8 ml/h.

Respuesta: **4,8 ml/h**. Errores previsibles: 0,08 ml/h (E1, no pasa de minutos a horas) y 4800 ml/h (E1, no convierte mg a µg).

**Ejemplo C. Goteo (enfermería).** Hay que administrar 1000 ml de suero en 8 horas con un sistema de 20 gotas/ml. ¿A cuántas gotas por minuto? Redondea a gota entera.

1. Gotas totales: 1000 ml × 20 gotas/ml = 20 000 gotas.
2. Minutos: 8 h × 60 min/h = 480 min.
3. Ritmo: 20 000 gotas ÷ 480 min = 41,67 gotas/min, que redondea a 42.

Respuesta: **42 gotas/min**.

### 3.4 T2. Selección única

- **Mecánica.** Pregunta con 3 o 4 opciones. Las opciones falsas son las respuestas erróneas previsibles, no cifras al azar.
- **Entrada.** Toque. Por voz, «opción be» o el propio valor.
- **Corrección.** Exacta. El orden de las opciones cambia en cada variante.
- **Unidades.** Cada opción lleva la suya; puede haber opciones con el mismo número y distinta unidad.

**Ejemplo.** ¿Qué concentración tiene la adrenalina 1:10 000? Opciones: 1 mg/ml, 0,1 mg/ml, 0,01 mg/ml, 10 mg/ml.

1. 1:10 000 significa 1 g en 10 000 ml.
2. 1 g = 1000 mg.
3. 1000 mg ÷ 10 000 ml = 0,1 mg/ml.

Respuesta: **0,1 mg/ml**, que equivale a 100 µg/ml.

### 3.5 T3. Ordenar pasos

- **Mecánica.** Se muestran desordenados los pasos de un procedimiento.
- **Entrada.** Tocar los pasos en orden o arrastrarlos. El toque es la alternativa accesible al arrastre.
- **Corrección.** La plantilla declara los órdenes válidos; se acepta cualquiera de ellos.
- **Unidades.** Cada paso nombra la unidad que produce.

**Ejemplo.** Ordena los pasos para convertir una pauta en µg/kg/min en un ritmo en ml/h.

1. Multiplicar la dosis por el peso: se obtienen µg/min.
2. Multiplicar por 60: se obtienen µg/h.
3. Expresar la concentración de la dilución en µg/ml.
4. Dividir la dosis por hora entre la concentración: se obtienen ml/h.

El paso 3 puede ir en cualquier posición anterior al 4. Los tres órdenes resultantes son válidos.

### 3.6 T4. Completar el planteamiento

- **Mecánica.** La operación aparece escrita con huecos. El usuario coloca fichas con datos del enunciado; sobran fichas.
- **Entrada.** Tocar ficha y hueco.
- **Corrección.** Todos los huecos deben ser correctos. Se aceptan las posiciones intercambiables que declare la plantilla.
- **Unidades.** Cada ficha lleva su unidad; el planteamiento muestra cómo se cancelan.

**Ejemplo (pediatría).** Niño de 18 kg. Pauta: amoxicilina 50 mg/kg/día repartida cada 8 horas. Suspensión de 250 mg/5 ml. Completa el cálculo del volumen por toma. Fichas: 18 kg, 3 tomas, 5 ml, 250 mg, 8 h, 24 h.

1. Dosis diaria: 50 mg/kg/día × 18 kg = 900 mg/día.
2. Dosis por toma: 900 mg ÷ 3 tomas = 300 mg.
3. Volumen por toma: 300 mg × 5 ml ÷ 250 mg = 6 ml.

Respuesta: **6 ml por toma**. Las fichas «8 h» y «24 h» sobran.

### 3.7 T5. Detectar el error

- **Mecánica.** Se muestra un cálculo resuelto en pasos. Uno está mal, o ninguno.
- **Entrada.** Tocar el paso erróneo o «No hay error». Por voz, «paso dos».
- **Corrección.** Exacta sobre el paso señalado.
- **Unidades.** El error suele estar en una unidad o en una equivalencia.

**Ejemplo (pediatría).** Niño de 20 kg. Pauta: morfina 0,1 mg/kg por vía intravenosa. Ampolla al 1 %. Cálculo mostrado: paso 1, 0,1 mg/kg × 20 kg = 2 mg; paso 2, 1 % = 1 mg/ml; paso 3, 2 mg ÷ 1 mg/ml = 2 ml.

1. El paso 1 es correcto: 2 mg.
2. El paso 2 es erróneo: 1 % es 1 g en 100 ml, es decir, 10 mg/ml.
3. El volumen correcto es 2 mg ÷ 10 mg/ml = 0,2 ml.

Respuesta: **paso 2**. El cálculo mostrado da diez veces el volumen correcto.

### 3.8 T6. Estimación rápida

- **Mecánica.** Sin calcular con exactitud, elegir la franja del resultado. Tiempo límite de 10 a 15 segundos.
- **Entrada.** Toque o voz.
- **Corrección.** Franja exacta.
- **Unidades.** Las franjas se expresan en la unidad de respuesta.

**Ejemplo (pediatría).** Niño de 15 kg. Pauta: atropina 0,02 mg/kg. Ampolla de 1 mg/ml. ¿En qué franja está el volumen? Opciones: menos de 0,1 ml; entre 0,1 y 1 ml; entre 1 y 10 ml; más de 10 ml.

1. Dosis: 0,02 mg/kg × 15 kg = 0,3 mg.
2. Volumen: 0,3 mg ÷ 1 mg/ml = 0,3 ml.

Respuesta: **entre 0,1 y 1 ml**. Motivo del tipo: acostumbra a comprobar el orden de magnitud antes de dar por buena una cifra.

### 3.9 T7. Conversión relámpago

- **Mecánica.** Diez conversiones seguidas en 60 segundos.
- **Entrada.** Teclado o voz. No hay paso de confirmación táctil.
- **Corrección.** Exacta.
- **Unidades.** La unidad de destino es fija y está a la vista.

**Ejemplos resueltos.**

| Pregunta | Operación | Respuesta |
| --- | --- | --- |
| 0,25 mg en µg | 0,25 × 1000 | 250 µg |
| 1,5 g en mg | 1,5 × 1000 | 1500 mg |
| 2 % en mg/ml | 2 g en 100 ml = 2000 mg ÷ 100 ml | 20 mg/ml |
| 0,9 % en mg/ml | 0,9 g en 100 ml = 900 mg ÷ 100 ml | 9 mg/ml |
| 1:1000 en mg/ml | 1000 mg ÷ 1000 ml | 1 mg/ml |
| 90 min en horas | 90 ÷ 60 | 1,5 h |

### 3.10 T8. Caso encadenado

- **Mecánica.** Un caso con 2 a 4 preguntas sucesivas. Cada respuesta alimenta la siguiente.
- **Entrada.** Teclado o voz.
- **Corrección.** Cada parte por separado. Si una parte falla, se muestra el valor correcto y el caso continúa con él. Motivo: evita arrastrar el error y penalizarlo dos veces.
- **Unidades.** Cada parte tiene su unidad de respuesta.

**Ejemplo (anestesia).** Preparas una perfusión de remifentanilo con 2 mg diluidos hasta 40 ml. Paciente simulado de 70 kg. Pauta: 0,1 µg/kg/min.

1. Concentración: 2 mg = 2000 µg; 2000 µg ÷ 40 ml = 50 µg/ml.
2. Dosis por hora: 0,1 µg/kg/min × 70 kg = 7 µg/min; 7 µg/min × 60 = 420 µg/h.
3. Ritmo: 420 µg/h ÷ 50 µg/ml = 8,4 ml/h.

Respuestas: **50 µg/ml**, **420 µg/h** y **8,4 ml/h**.

### 3.11 T9. Marcar en la jeringa

- **Mecánica.** Tras calcular, el usuario lleva el émbolo de una jeringa dibujada hasta el volumen.
- **Entrada.** Deslizar, con botones de más y menos como alternativa.
- **Corrección.** División exacta de la jeringa.
- **Unidades.** Las de la escala del instrumento.

**Ejemplo (veterinaria).** Gato de 4 kg. Pauta: buprenorfina 0,02 mg/kg. Presentación: 0,3 mg/ml. Marca el volumen en una jeringa de 1 ml.

1. Dosis: 0,02 mg/kg × 4 kg = 0,08 mg.
2. Volumen: 0,08 mg ÷ 0,3 mg/ml = 0,2667 ml.
3. Redondeo a la división de la jeringa (0,01 ml): 0,27 ml.

Respuesta: **0,27 ml**.

### 3.12 T10. Emparejar

- **Mecánica.** Dos columnas; unir cada expresión con su equivalente.
- **Entrada.** Tocar un elemento de cada columna.
- **Corrección.** Par a par; el ejercicio termina cuando todos están unidos.
- **Unidades.** Son el contenido del ejercicio.

**Ejemplo resuelto.**

| Expresión | Equivale a | Operación |
| --- | --- | --- |
| 1 % | 10 mg/ml | 1000 mg ÷ 100 ml |
| 0,5 % | 5 mg/ml | 500 mg ÷ 100 ml |
| 1:1000 | 1 mg/ml | 1000 mg ÷ 1000 ml |
| 1:10 000 | 0,1 mg/ml | 1000 mg ÷ 10 000 ml |
| 1:200 000 | 5 µg/ml | 1000 mg ÷ 200 000 ml = 0,005 mg/ml |

### 3.13 Ejemplos resueltos del resto de cálculos

Completan la cobertura mínima pedida. Todos usan el tipo T1.

| Cálculo | Enunciado | Resolución | Respuesta |
| --- | --- | --- | --- |
| Volumen con concentración en % | Necesitas 60 mg de lidocaína. Presentación al 2 % | 2 % = 20 mg/ml; 60 mg ÷ 20 mg/ml | 3 ml |
| Unidades internacionales | Paciente simulado de 75 kg. Pauta: bolo de heparina sódica de 80 UI/kg. Vial de 1000 UI/ml | 80 UI/kg × 75 kg = 6000 UI; 6000 UI ÷ 1000 UI/ml | 6 ml |
| Reconstitución | Vial de ceftriaxona de 1 g reconstituido hasta un volumen final de 10 ml. Pauta: 750 mg | 1000 mg ÷ 10 ml = 100 mg/ml; 750 mg ÷ 100 mg/ml | 7,5 ml |
| Dilución | Diluyes una ampolla de efedrina de 50 mg en 1 ml hasta 10 ml. ¿Qué volumen contiene 10 mg? | 50 mg ÷ 10 ml = 5 mg/ml; 10 mg ÷ 5 mg/ml | 2 ml |
| Dosis máxima por dosis | Paciente simulado de 70 kg. Pauta: paracetamol intravenoso 15 mg/kg, máximo 1 g por dosis. Presentación: 10 mg/ml | 15 mg/kg × 70 kg = 1050 mg, supera el máximo: se aplican 1000 mg; 1000 mg ÷ 10 mg/ml | 100 ml (105 ml es el error E6) |
| Dosis máxima por peso | El protocolo del caso fija un máximo de 2 mg/kg de bupivacaína. Paciente simulado de 60 kg. Presentación al 0,5 %. ¿Volumen máximo? | 2 mg/kg × 60 kg = 120 mg; 0,5 % = 5 mg/ml; 120 mg ÷ 5 mg/ml | 24 ml |
| Pediatría | Niño de 12 kg. Pauta: adrenalina 0,01 mg/kg intravenosa. Dilución 1:10 000 | 0,01 mg/kg × 12 kg = 0,12 mg; 1:10 000 = 0,1 mg/ml; 0,12 mg ÷ 0,1 mg/ml | 1,2 ml |
| Veterinaria, por especie | Perro de 20 kg. Pauta: lidocaína en infusión continua a 50 µg/kg/min. Presentación al 2 %. ¿Ritmo en ml/h sin diluir? | 50 µg/kg/min × 20 kg = 1000 µg/min = 1 mg/min; 1 mg/min × 60 = 60 mg/h; 2 % = 20 mg/ml; 60 mg/h ÷ 20 mg/ml | 3 ml/h |

Las plantillas de veterinaria llevan etiqueta de especie. La del último ejemplo solo genera casos de perro, y el revisor añade la nota de especie que corresponda.

## 4. Mapa de navegación y flujos principales

La app tiene cinco destinos de primer nivel y una sesión de ejercicios a pantalla completa. De la sesión solo se sale terminándola o con una salida explícita y confirmada.

### 4.1 Mapa de navegación

&#91;embedded content: mapa de navegación · 5 destinos y la sesión\]

Inicio y Practicar son las dos entradas a la sesión. Al terminarla o salir, la app vuelve al destino desde el que se entró.

| Destino | Contiene |
| --- | --- |
| Inicio | Ruta de aprendizaje, meta diaria, racha y la acción «Continuar» |
| Practicar | Repaso de errores, contrarreloj, manos libres y práctica libre por habilidad |
| Progreso | Estadísticas, estado de las habilidades e historial |
| Ligas | Liga semanal y logros |
| Perfil | Cuenta, sector, ajustes de voz y accesibilidad, suscripción, consulta y textos legales |

Reglas de navegación:

- Cinco destinos como máximo, siempre con icono y etiqueta. En móvil, barra inferior; en tablet de 840 dp o más, carril lateral. No se mezclan los dos patrones.
- La sesión oculta la navegación. Motivo: una lección dura pocos minutos y cualquier salida accidental rompe la concentración y la medida del tiempo.
- El gesto y el botón de atrás son predecibles: dentro de una sesión abren la confirmación de salida; fuera, vuelven a la pantalla anterior conservando la posición.
- Enlaces profundos a unidad, lección, repaso, contrarreloj y liga, para las notificaciones.

### 4.2 Alta

1. **Bienvenida.** Propuesta en tres frases y dos acciones: «Empezar» y «Ya tengo cuenta».
2. **Sector.** Selección única. La app propone el itinerario más habitual del sector.
3. **Nivel declarado.** «Empiezo de cero», «Lo uso y quiero afianzarlo» o «Lo domino y busco agilidad».
4. **Meta.** 5, 10 o 15 minutos al día, o meta semanal para quien trabaja a turnos.
5. **Aviso formativo.** «VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales». Requiere aceptación expresa.
6. **Prueba de nivel**, opcional, de 3 a 4 minutos.
7. **Descarga del itinerario**, con barra de progreso y tres tarjetas que explican el funcionamiento.
8. **Primera lección.**
9. **Crear cuenta**, al terminar la primera lección: correo con código, Apple o Google. Se puede posponer; el progreso queda en un perfil local.
10. **Permisos.** Notificaciones, tras la primera lección y con su motivo. Micrófono, solo al entrar por primera vez en manos libres.

El registro va después de la primera lección porque pedir datos antes de mostrar valor es el punto donde más usuarios abandonan.

### 4.3 Primera sesión

1. Empieza en la primera unidad no superada según la prueba de nivel.
2. Los dos primeros ejercicios llevan ayudas integradas: teclado propio, unidad de respuesta y botón «No lo sé».
3. Ocho ejercicios. El primer fallo abre la corrección paso a paso con una indicación de cómo avanzar por ella.
4. Fin de lección con precisión, tiempo, puntos y primer día de racha.
5. Invitación a probar el modo manos libres en un minuto.
6. Creación de cuenta y recordatorio diario.

### 4.4 Sesión diaria

1. Entrada por notificación o por el icono. Inicio muestra una única acción principal: «Continuar».
2. Si hay repaso pendiente, la sesión arranca con un calentamiento de hasta 5 fichas. Motivo: el repaso espaciado ocurre sin depender de que el usuario lo elija.
3. Lección de 8 a 12 ejercicios con corrección inmediata.
4. Fin de lección. Si se cumple la meta, se actualiza la racha.
5. Una sugerencia de continuidad: repaso restante, contrarreloj o salir.

### 4.5 Sesión manos libres

1. Entrada desde Practicar o desde el botón de auriculares al inicio de una lección compatible.
2. Comprobaciones previas: paquete de voz descargado, permiso de micrófono, volumen y prueba de micrófono («di empezar»).
3. Elección de contenido (repaso, lección actual o una habilidad) y de duración (5, 10 o 15 minutos, o sin límite). Solo entran ejercicios compatibles con voz.
4. Bucle por ejercicio: lectura, escucha, confirmación, veredicto, explicación breve si hay fallo y siguiente (sección 7).
5. Los comandos de voz funcionan en cualquier momento.
6. Las interrupciones (llamada, otra app que toma el audio) pausan la sesión. Se reanuda con «continúa» o con un toque.
7. Cierre con resumen hablado y pantalla de resumen.

### 4.6 Repaso de errores

1. Entrada desde Practicar, desde la tarjeta de Inicio o desde la notificación.
2. Cola del día, con las fichas de error crítico primero.
3. Cada ficha presenta una variante nueva. Si se acierta, sale de la cola. Si se falla, se corrige paso a paso y vuelve al final de la sesión, dos veces como máximo.
4. Cierre con fichas resueltas, fecha del próximo repaso y habilidades que cambian de estado.
5. Sin fichas pendientes: se muestra la fecha del próximo repaso y se ofrece práctica libre.

## 5. Pantallas de la aplicación

La app tiene 18 pantallas. Todas comparten las convenciones de 5.0, de modo que cada ficha solo describe lo que le es propio.

### 5.0 Convenciones comunes

**Clases de tamaño**

| Clase | Ancho | Dispositivo | Navegación | Disposición |
| --- | --- | --- | --- | --- |
| Compacta | Menos de 600 dp | Móvil | Barra inferior | Una columna |
| Media | 600 a 839 dp | Tablet en vertical, plegables | Carril lateral | Una columna ancha con paneles plegables |
| Expandida | 840 dp o más | Tablet en horizontal | Carril lateral | Dos paneles |

En tablet nada se estira: el texto de lectura no pasa de 640 dp de ancho, el teclado propio no pasa de 420 dp y el espacio sobrante se usa para un segundo panel con función propia.

**Estados globales**

- **Carga.** Esqueleto de la pantalla si la espera supera 300 ms. Nunca un indicador giratorio a pantalla completa.
- **Vacío.** Una frase que explica por qué no hay nada y una acción para remediarlo.
- **Error.** Causa en lenguaje llano y vía de recuperación (reintentar, continuar sin eso, escribir a soporte).
- **Sin conexión.** Distintivo discreto «Sin conexión · tu progreso se guarda en el dispositivo». No bloquea nada que pueda hacerse en local (5.18).

**Respuesta háptica y sonora**

| Señal | Háptica | Sonido | Duración |
| --- | --- | --- | --- |
| Pulsación de tecla u opción | Toque ligero | Ninguno | 10 ms |
| Acierto | Patrón de éxito del sistema | Tono ascendente | 250 ms |
| Fallo | Dos pulsos suaves | Tono grave y breve | 200 ms |
| Hito (lección, racha, nivel) | Pulso medio | Acorde | Hasta 1,2 s |
| Acción no permitida | Pulso seco | Ninguno | 30 ms |

Los sonidos respetan el modo silencio y se desactivan en ajustes, igual que la háptica.

**Movimiento**

- Duraciones: micro 100 ms, corta 200 ms, media 300 ms, larga 450 ms. Las celebraciones duran 1,5 s como máximo y se saltan con un toque.
- La entrada desacelera y la salida acelera y dura un 70 % de la entrada.
- Solo se animan opacidad y transformaciones. Ninguna animación bloquea la entrada del usuario.
- Con «reducir movimiento» activo, todo se sustituye por fundidos de 150 ms.

**Accesibilidad común**

- Contraste mínimo de 4,5:1 en texto y de 3:1 en iconos y bordes con significado.
- Texto ampliable hasta el 200 % sin truncar; las pantallas pasan a desplazarse.
- Objetivos táctiles de 48 dp como mínimo con 8 dp de separación.
- Ningún estado se comunica solo con color: siempre icono o texto.
- Etiquetas para lector de pantalla en todo control, y orden de foco igual al visual.
- Las cantidades se leen completas: «0,2 mg/kg» se anuncia como «cero coma dos miligramos por kilo», con el mismo normalizador que usa la voz.
- Con teclado físico en tablet: las cifras se escriben directamente e Intro comprueba.

**Analítica común**

Todas las pantallas emiten `screen_viewed` con `screen_name`. Todos los eventos llevan: identificador seudónimo de usuario, `session_id`, `sector`, `itinerary_id`, `content_version`, `app_version`, `device_class`, `input_mode`, `connectivity` y `locale`. En cada ficha solo se listan los eventos propios.

### 5.1 Bienvenida y alta

- **Objetivo y momento.** Primer arranque. Explica qué es el producto en cinco segundos y lleva a la primera lección. También da acceso a quien ya tiene cuenta.
- **Móvil.** Marca arriba; titular «Calcula dosis con seguridad y rapidez»; tres frases de valor con icono; «Empezar» (primaria) y «Ya tengo cuenta» (secundaria) ancladas abajo, en la zona del pulgar; línea de pie «Entrenador formativo. No es una calculadora clínica». La creación de cuenta es una hoja inferior con correo y código de seis cifras, botones de Apple y Google, y «Ahora no».
- **Tablet.** Dos columnas: a la izquierda, una vista animada de la ruta de aprendizaje; a la derecha, texto y acciones en un bloque de 480 dp. En vertical se apilan con márgenes de 32 dp.
- **Estados.** Carga: marca estática mientras se prepara la base local, un segundo como máximo. Error al enviar el código: mensaje junto al campo y «Reintentar», sin borrar lo escrito. Sin conexión: «Empezar» funciona con la primera unidad de Fundamentos, que va dentro de la app; crear cuenta queda desactivado con su explicación.
- **Microinteracciones.** El titular entra con fundido y subida de 12 dp (300 ms). El menisco de la marca se llena una vez (800 ms). Los botones reducen su escala a 0,97 al pulsar (100 ms) con toque háptico ligero. El código avanza de casilla solo y se valida al completar la sexta; si es erróneo, las casillas se sacuden 6 dp (200 ms) con háptica de fallo.
- **Voz.** No aplica.
- **Accesibilidad.** El código admite autorrelleno y pegado. No hay prueba cognitiva de acceso. Orden de foco: titular, frases, acciones.
- **Analítica.** `onboarding_started`, `auth_method_selected` {method}, `auth_code_requested`, `auth_completed` {method, is\_new}, `auth_failed` {reason}, `signup_deferred`.

### 5.2 Selección de sector y nivel

- **Objetivo y momento.** Tras «Empezar». Personaliza el itinerario en cuatro pasos cortos: sector, nivel, meta y aviso formativo.
- **Móvil.** Una pregunta por pantalla con barra de cuatro pasos. Sector: tarjetas a ancho completo con icono, nombre y una línea de cálculos típicos. Nivel: tres opciones. Meta: 5, 10 o 15 minutos y conmutador de meta semanal. Aviso: texto breve y casilla «Lo entiendo». «Continuar» fijo abajo, desactivado hasta elegir.
- **Tablet.** Tarjetas en cuadrícula de dos columnas (media) o tres (expandida). En expandida, panel derecho con la vista previa del itinerario propuesto, que cambia al tocar cada sector.
- **Estados.** Carga: el catálogo de sectores va dentro de la app; no hay espera. Error en la descarga del itinerario: «Reintentar» y «Empezar con Fundamentos». Sin conexión: los sectores no descargados indican «Se descargará cuando haya conexión» y se puede empezar por Fundamentos.
- **Microinteracciones.** La tarjeta elegida gana borde de 2 dp y una marca que crece de 0 a 1 (150 ms) con toque háptico. Entre pasos, deslizamiento horizontal de 250 ms; la barra de pasos avanza en 200 ms.
- **Voz.** No aplica.
- **Accesibilidad.** Las tarjetas se exponen como botones de opción con su estado. La selección se indica con marca y borde, no solo con color.
- **Analítica.** `sector_selected` {sector}, `level_declared` {level}, `goal_set` {type, minutes}, `disclaimer_accepted`, `itinerary_download_started`, `itinerary_download_completed` {size\_mb, duration\_ms}, `itinerary_download_failed` {reason}.

### 5.3 Prueba de nivel

- **Objetivo y momento.** Opcional, tras el alta, y repetible desde Perfil. Sitúa al usuario en la ruta en 3 o 4 minutos con 8 a 12 ejercicios de los tipos T1, T2 y T6. Es adaptativa: parte del nivel declarado y sube o baja de unidad según las respuestas.
- **Móvil.** Barra de avance por preguntas, sin puntuación; enunciado; campo; teclado propio; «No lo sé» bien visible con la nota «Si no lo sabes, dilo: ajustamos mejor». No se corrige durante la prueba. Resultado: unidades convalidadas, punto de entrada y «Empezar aquí», con la opción de empezar antes.
- **Tablet.** Ejercicio a la izquierda y hoja de borrador a la derecha. En el resultado, ruta a la izquierda y resumen a la derecha.
- **Estados.** Carga: esqueleto del ejercicio. Interrupción: se guarda y se reanuda en el punto exacto. Sin conexión: funciona; las preguntas van en el paquete descargado.
- **Microinteracciones.** Sin sonido de acierto ni de fallo, para no condicionar. Fundido cruzado de 200 ms entre preguntas. Al terminar, las unidades convalidadas se marcan en cascada, con 40 ms entre una y otra.
- **Voz.** No disponible en la prueba.
- **Accesibilidad.** El tiempo se mide pero no limita. Cada pregunta se anuncia con su posición: «Pregunta 4 de 10, como máximo».
- **Analítica.** `placement_started`, `placement_item_answered` {template\_id, correct, time\_ms, skipped}, `placement_completed` {entry\_unit, units\_skipped, duration\_ms}, `placement_abandoned` {items\_done}.

No se corrige durante la prueba porque su fin es medir, no enseñar; así dura la mitad.

### 5.4 Inicio con ruta de aprendizaje

- **Objetivo y momento.** Cada apertura. Dice qué toca hoy y lo lanza con un toque.
- **Móvil.** Cabecera compacta con racha, anillo de meta diaria y puntos de la semana. Tarjeta de repaso si hay fichas («12 fichas para hoy»). Ruta vertical: una línea recta con las unidades como nodos y la unidad en curso desplegada con sus lecciones. Acción primaria única, fija abajo: «Continuar · Lección 3». Estados de nodo: bloqueada, disponible, en curso, superada, dominada y por refrescar; cada uno con icono y texto.
- **Tablet.** Dos paneles: ruta a la izquierda (40 %) y, a la derecha, el detalle de la unidad seleccionada con las tarjetas de repaso y contrarreloj. En vertical, la ruta ocupa el ancho y el detalle entra como hoja lateral.
- **Estados.** Carga: esqueleto de tres nodos. Vacío (sin itinerario): «Elige un itinerario». Error de base local: «Reparar» vuelve a descargar el contenido sin tocar el progreso. Sin conexión: todo operativo; las unidades no descargadas indican «Disponible al conectar».
- **Microinteracciones.** Al volver de una lección superada, el nodo se llena como un menisco (600 ms) y la línea avanza al siguiente (400 ms), con pulso háptico medio. El anillo de meta crece hasta su valor (500 ms). Al abrir, la ruta se desplaza sola a la unidad en curso (300 ms).
- **Voz.** No aplica; el acceso a manos libres está en Practicar y en el detalle de unidad.
- **Accesibilidad.** La ruta es una lista con encabezados. Cada nodo se anuncia completo: «Unidad 4, Perfusiones, en curso, 2 de 5 lecciones». La acción primaria es el primer elemento enfocable tras la cabecera.
- **Analítica.** `home_viewed` {streak\_days, due\_reviews, goal\_progress}, `continue_tapped` {lesson\_id}, `unit_opened` {unit\_id, state}, `review_card_tapped` {due}.

La ruta es recta y sobria, no un camino serpenteante con ilustraciones. Conserva lo que funciona del modelo (se ve dónde estás y qué viene) sin el tono de juego infantil.

### 5.5 Detalle de unidad

- **Objetivo y momento.** Al tocar una unidad. Muestra qué se aprende, las lecciones y su estado, y da entrada a la lección, a la guía rápida y al reto para saltar la unidad.
- **Móvil.** Título, habilidades como etiquetas y progreso. «Guía rápida» plegable con las equivalencias clave y un ejemplo resuelto. Lista de cinco lecciones con estado, duración estimada y mejor precisión. «Empezar lección N» (primaria), «Hacer el reto y saltar la unidad» (secundaria) y botón de manos libres si la lección es compatible.
- **Tablet.** Es el panel derecho de Inicio. A pantalla completa: guía a la izquierda y lecciones a la derecha.
- **Estados.** Carga: esqueleto. Vacío: «Contenido en preparación». Sin conexión con la unidad sin descargar: acción desactivada y «Se descargará al conectar».
- **Microinteracciones.** La guía se despliega en 250 ms. Al tocar una lección bloqueada, el candado se sacude (150 ms) y aparece «Completa antes la lección 2».
- **Voz.** Botón de manos libres; no hay comandos en esta pantalla.
- **Accesibilidad.** Las operaciones de la guía tienen texto alternativo leído en orden: «miligramos dividido entre miligramos por mililitro».
- **Analítica.** `unit_viewed` {unit\_id}, `guide_opened`, `lesson_started` {lesson\_id, mode}, `unit_challenge_started` {unit\_id}.

### 5.6 Sesión de ejercicio en modo táctil

- **Objetivo y momento.** Durante una lección, un repaso o un reto. Es la pantalla donde el usuario pasa casi todo el tiempo; todo lo que no ayuda a responder desaparece.
- **Móvil.** De arriba abajo: barra con cierre, progreso por segmentos y tiempo (solo si aplica); enunciado a 18 o 20 sp con los datos clave resaltados en la tipografía de cifras; campo de respuesta grande con la unidad como sufijo; fila de unidades cuando hay que elegirla; teclado propio en el tercio inferior; «Comprobar» (primaria, activa al haber respuesta), «No lo sé» y «Pista». En T2 y T6 las opciones ocupan el lugar del teclado; en T3, la lista ordenable. Todos los controles quedan en el 60 % inferior, al alcance del pulgar.
- **Tablet.** En horizontal: a la izquierda, enunciado, respuesta y teclado; a la derecha, la hoja de borrador para lápiz o dedo y, en lecciones con apoyo, el planteamiento. En vertical: enunciado arriba, borrador plegable en el centro y teclado centrado abajo. El borrador no se guarda ni se sincroniza y se limpia en cada ejercicio.
- **Estados.** Carga: no hay; la lección entera se prepara antes de empezar. Error en una variante: se salta, se registra y la lección sigue. Segundo plano: el tiempo se detiene y al volver se muestra «Sigues donde lo dejaste». Salida: confirmación «Se guarda lo hecho hasta aquí». Sin conexión: sin diferencias.
- **Microinteracciones.** Cada tecla se oscurece 80 ms con toque háptico. Una segunda coma no se escribe y da un pulso seco. Al comprobar, el botón se transforma en la banda de veredicto (250 ms). Acierto: banda verde con marca que se dibuja (300 ms), tono y háptica de éxito; avanza sola a los 900 ms o al tocar. Fallo: banda roja con icono, tono grave y doble pulso; sube la hoja de corrección (300 ms). El segmento de progreso se llena en 200 ms. Cinco aciertos seguidos muestran «5 seguidas» en la barra durante 600 ms, sin ventana.
- **Voz.** Botón de micrófono en el campo para dictar solo la respuesta: escucha, escribe la cifra entendida y el usuario comprueba.
- **Accesibilidad.** El enunciado se anuncia al cargar. El veredicto se comunica por región viva: «Incorrecto. La respuesta es cuatro coma ocho mililitros por hora». Con texto ampliado, el enunciado se desplaza y el teclado conserva su tamaño.
- **Analítica.** `exercise_presented` {exercise\_id, template\_id, variant\_id, type, difficulty, position}, `answer_submitted` {value, unit, verdict, error\_code, time\_ms, hints\_used, attempts}, `hint_requested`, `dont_know_tapped`, `session_paused`, `session_resumed`, `session_exited` {position, reason}, `exercise_load_failed` {variant\_id}.

### 5.7 Sesión en modo manos libres

- **Objetivo y momento.** Entrenar sin mirar ni tocar la pantalla. Se entra desde Practicar o desde una lección compatible.
- **Móvil.** Pocos elementos, enormes y legibles a un metro. Estado actual con icono y palabra («Leyendo», «Te escucho», «¿Correcto?», «Correcto», «Incorrecto»). Debajo, lo entendido en cifras muy grandes («4,8 ml/h»). Halo de micrófono. Enunciado plegable. Toda la pantalla es una zona táctil: un toque pausa o continúa. Fila inferior con tres botones de 72 dp, pensados para guantes: «Repetir», «No lo sé» y «Siguiente». Acceso al teclado. Progreso y tiempo restante. Distintivo fijo «Voz procesada en este dispositivo». La pantalla no se apaga; el modo bolsillo la oscurece a los 10 segundos y bloquea el tacto, y se despierta con doble toque.
- **Tablet.** En horizontal: a la izquierda, estado y cifra entendida; a la derecha, enunciado completo con los datos como etiquetas e historial de la sesión. Tamaños multiplicados por 1,5, para leer con la tablet apoyada a un metro.
- **Estados.** Carga: «Preparando la voz», dos segundos como máximo. Paquete de voz sin descargar: descarga con tamaño indicado; sin conexión, se explica y se ofrece el modo táctil. Micrófono denegado: pasos para activarlo en ajustes. Ruido alto: «Hay mucho ruido. Acerca el micrófono o usa los botones». Dos fallos de reconocimiento: modo cifra a cifra; tres: se abre el teclado. Pausa: «En pausa. Di continúa o toca la pantalla».
- **Microinteracciones.** El halo late con el nivel de entrada en tiempo real. Al abrir la escucha, señal sonora ascendente de 120 ms y toque háptico; al cerrarla, señal de 80 ms. La cifra entendida aparece creciendo de 0,9 a 1 (150 ms). El veredicto tiñe la pantalla al 20 % de opacidad durante 300 ms, con sonido y patrón háptico distintos: un pulso largo para acierto y dos cortos para fallo. Los cambios de estado son fundidos de 200 ms.
- **Voz.** Es la pantalla del diseño conversacional completo (sección 7).
- **Accesibilidad.** Se usa entera sin ver (voz y háptica), sin hablar (botones) y sin oír (todo lo dicho aparece escrito). Con lector de pantalla activo, la voz de la app sustituye sus anuncios en esta pantalla para no hablar dos veces.
- **Analítica.** `handsfree_session_started` {content, duration\_target, headset}, `voice_prompt_played` {exercise\_id, tts\_ms}, `voice_answer_captured` {asr\_ms, confidence, parse\_ok}, `voice_confirmation` {result}, `voice_command_used` {command}, `voice_recognition_failed` {reason}, `voice_fallback_keyboard` {failures}, `handsfree_session_completed` {exercises, accuracy, duration\_ms, fallback\_count}. No se registra audio ni texto transcrito: solo la respuesta interpretada y la categoría del fallo.

### 5.8 Corrección y explicación

- **Objetivo y momento.** Tras cada respuesta: breve si es correcta, completa si no. También a demanda con «Ver cómo se hace».
- **Móvil.** Hoja inferior que sube sobre el ejercicio; el enunciado sigue visible. Contiene, por orden: veredicto con icono y la respuesta correcta en grande; diagnóstico en una frase con la etiqueta del tipo de error; pasos en tarjetas numeradas, con la operación y las unidades que se cancelan; comprobación de plausibilidad; acciones «Probar con otros números» (primaria tras un fallo) y «Continuar»; enlace «Informar de un error en este ejercicio». Si la respuesta es correcta, solo una banda con la cifra, «Ver cómo se hace» y «Continuar». Con observación, banda ámbar con la nota («Se redondea a 0,27 ml»).
- **Tablet.** La explicación ocupa el panel derecho, junto al ejercicio y a la respuesta del usuario. Los pasos se ven todos a la vez.
- **Estados.** Sin carga: las explicaciones van en el paquete. Una plantilla sin pasos no puede publicarse, así que no hay estado vacío. Sin conexión: sin diferencias; el aviso de error en el ejercicio se encola.
- **Microinteracciones.** La hoja sube en 300 ms. Cada paso entra con fundido y subida de 8 dp (200 ms). Al cancelarse dos unidades, una línea las tacha (250 ms) y bajan al 40 % de opacidad. El paso donde se desvió el usuario marca su borde una vez (400 ms). «Probar con otros números» cambia de variante con fundido cruzado de 250 ms.
- **Voz.** En manos libres se lee el diagnóstico y el resultado. «Explica» lee los pasos uno a uno; «siguiente» y «repite» los recorren.
- **Accesibilidad.** Los pasos son una lista ordenada. La cancelación de unidades tiene equivalente textual («miligramos se cancela con miligramos»). El foco pasa al veredicto al abrirse la hoja y la hoja se cierra con botón, no solo con gesto.
- **Analítica.** `feedback_viewed` {verdict, error\_code}, `explanation_step_viewed` {step\_index}, `explanation_completed`, `retry_variant_started`, `retry_variant_result` {correct}, `content_issue_reported` {exercise\_id}.

### 5.9 Fin de lección

- **Objetivo y momento.** Tras el último ejercicio. Cierra el ciclo: resultado, qué ha cambiado y siguiente paso.
- **Móvil.** Titular según el resultado («Lección superada» o «Lección completada: 2 fichas van a repaso»). Tres cifras grandes: precisión, tiempo medio frente al objetivo y puntos. Racha, si se ha cumplido la meta. Habilidades que cambian de estado. Lista de fallos con su tipo; al tocar uno se abre su explicación. «Continuar» (primaria) y «Repasar ahora los fallos» (secundaria).
- **Tablet.** Dos columnas: cifras y racha a la izquierda; a la derecha, la lista de ejercicios de la lección con veredicto y tiempo.
- **Estados.** Sin conexión: los puntos se guardan en local y se indica «Se sumará a tu liga cuando haya conexión».
- **Microinteracciones.** Las cifras cuentan hasta su valor (600 ms). La cabecera se llena como un menisco hasta el porcentaje de precisión (900 ms); con el 100 %, un brillo breve, acorde y pulso medio. El contador de racha gira al nuevo día (300 ms). La subida de nivel es una capa aparte de 1,2 s que se salta con un toque. No hay confeti.
- **Voz.** En manos libres, resumen hablado: «Ocho de diez. Dos fichas a repaso. Di siguiente o salir».
- **Accesibilidad.** El lector anuncia solo los valores finales. Con movimiento reducido no hay conteo ni llenado.
- **Analítica.** `lesson_completed` {lesson\_id, accuracy, avg\_time\_ms, points, critical\_errors, duration\_ms, mode}, `streak_extended` {days}, `skill_state_changed` {skill\_id, from, to}, `level_up` {level}, `post_lesson_action` {action}.

### 5.10 Repaso de errores

- **Objetivo y momento.** Vaciar la cola de repaso del día. Se entra desde Practicar, Inicio o la notificación.
- **Móvil.** Pantalla de entrada: fichas para hoy, minutos estimados, reparto por tipo de error y por habilidad, y «Tus errores más frecuentes» («Minutos por horas · 4 veces»). Acción primaria «Empezar repaso (12)». La sesión es la de 5.6 con cabecera «Repaso» y una línea que explica por qué vuelve la ficha («Fallaste esta el martes: unidad»). Cierre con fichas resueltas y próxima fecha.
- **Tablet.** A la izquierda, la cola agrupada por habilidad; a la derecha, el detalle del grupo elegido con su historial de errores y «Empezar».
- **Estados.** Carga: esqueleto. Vacío: «No tienes fichas para hoy. Próximo repaso: jueves», con oferta de práctica libre. Sin conexión: funciona completo; la cola se calcula en el dispositivo.
- **Microinteracciones.** El contador de fichas baja con cada acierto (200 ms). La ficha resuelta muestra su marca y sale deslizando (250 ms). Al terminar, la barra de la cola se vacía (500 ms).
- **Voz.** El repaso es uno de los contenidos del modo manos libres.
- **Accesibilidad.** Los repartos por tipo y habilidad tienen equivalente en texto.
- **Analítica.** `review_session_started` {due\_count, critical\_count}, `review_item_answered` {card\_id, template\_id, grade, time\_ms, interval\_days\_before}, `review_session_completed` {resolved, relapsed, duration\_ms}, `review_empty_viewed`.

### 5.11 Contrarreloj

- **Objetivo y momento.** Ganar agilidad en habilidades ya consolidadas. Se entra desde Practicar. Dos formatos: **esprint** (máximos aciertos en 60 segundos) y **serie** (10 ejercicios contra el tiempo objetivo).
- **Regla de precisión.** Cada fallo resta 3 segundos y corta el multiplicador. Una marca con menos del 90 % de precisión no es válida para récords ni ligas: «Marca no válida: precisión del 80 %. La rapidez solo cuenta con precisión». Motivo: sin esta regla, el modo premiaría responder deprisa y mal.
- **Móvil.** Selección: habilidades disponibles con la mejor marca; las bloqueadas explican cómo abrirse. En juego: barra de tiempo arriba con los segundos, ejercicio compacto, campo y teclado. Cierre: aciertos, precisión, tiempo medio, comparación con la mejor marca y lista de fallos, que pasan al repaso.
- **Tablet.** En horizontal: ejercicio y teclado a la izquierda; a la derecha, la tira de respuestas de la serie y la referencia de la mejor marca.
- **Estados.** Bloqueado: «Consolida una habilidad para abrir el contrarreloj». Interrupción: el esprint se anula, no se pausa, para que las marcas sean comparables. Sin conexión: funciona; las marcas se sincronizan después.
- **Microinteracciones.** La barra se consume de forma lineal y pasa a ámbar en los últimos 10 segundos, con un toque háptico por segundo (desactivable). Acierto: destello verde de 150 ms en el campo y siguiente ejercicio sin banda. Fallo: el campo se sacude y muestra la respuesta correcta 1,2 s. El multiplicador crece de 1 a 1,15 y vuelve (200 ms). Récord: capa de 1,2 s con acorde.
- **Voz.** No disponible en el MVP: la confirmación hablada distorsiona la medida del tiempo.
- **Accesibilidad.** Existe una variante sin cuenta atrás que mide el tiempo sin limitarlo. El lector anuncia el tiempo a los 30 y a los 10 segundos. Nada parpadea.
- **Analítica.** `timetrial_started` {skill\_id, format}, `timetrial_answer` {correct, time\_ms}, `timetrial_completed` {correct, errors, accuracy, valid, avg\_time\_ms, is\_record}, `timetrial_cancelled` {reason}.

### 5.12 Progreso y estadísticas

- **Objetivo y momento.** Pestaña propia. Muestra la mejora en exactitud y en rapidez, que es lo que motiva a un profesional.
- **Móvil.** Tres tarjetas de resumen: precisión de los últimos 7 días, tiempo medio frente al objetivo y días activos. Lista de habilidades con su estado y barra. Detalle de habilidad: evolución semanal de la precisión (línea), tiempo mediano (línea), errores por tipo (barras horizontales ordenadas) y plantillas más falladas. Calendario de actividad de cinco semanas e historial de sesiones.
- **Tablet.** Cuadrícula de dos o tres columnas. Lista de habilidades a la izquierda y detalle a la derecha.
- **Estados.** Carga: esqueleto de tarjetas. Vacío (menos de tres sesiones): «Completa tres sesiones para ver tu evolución», sobre una vista de ejemplo atenuada. Sin conexión: datos locales con la nota «Calculado en este dispositivo».
- **Microinteracciones.** Las gráficas se dibujan una vez en 400 ms. Tocar un punto muestra su valor con toque háptico. El cambio de periodo es un fundido de 200 ms.
- **Voz.** No aplica.
- **Accesibilidad.** Cada gráfica lleva una frase de resumen («Tu precisión ha pasado del 82 % al 93 % en cuatro semanas»), etiquetas directas y vista alternativa en tabla. Las series se distinguen por forma y etiqueta, no solo por color.
- **Analítica.** `progress_viewed`, `skill_detail_viewed` {skill\_id, state}, `stats_period_changed` {period}, `chart_table_toggled`.

### 5.13 Ligas y logros

- **Objetivo y momento.** Pestaña propia. Añade motivación social semanal y reconoce hitos.
- **Reglas de liga.** Grupos semanales de 30 usuarios, del mismo sector cuando sea posible. Cinco divisiones: Bronce, Plata, Oro, Platino y Titanio. Suben los 7 primeros y bajan los 5 últimos. Solo puntúan los aciertos al primer intento; la bonificación por rapidez exige una marca válida de contrarreloj; hay un tope de 300 puntos al día. Se participa con alias y se puede salir de las ligas en cualquier momento.
- **Móvil.** Control de dos segmentos: Liga y Logros. Liga: división y días restantes; clasificación con posición, alias y puntos; zonas de ascenso y descenso separadas por líneas con rótulo; la fila propia queda fija a la vista. Logros: cuadrícula por categoría (constancia, precisión, agilidad y dominio) con su progreso.
- **Tablet.** Liga a la izquierda y logros a la derecha, a la vez.
- **Estados.** Carga: esqueleto de filas. Vacío: explicación y «Unirme a la liga de esta semana». Fuera de ligas: «No participas en ligas», con la opción de volver. Sin conexión: última clasificación con su hora («Clasificación de hace 3 h») y los puntos propios en espera.
- **Microinteracciones.** Si la posición ha cambiado, la fila propia se desplaza a su sitio al abrir (400 ms). Ascenso al cierre de la semana: capa de 1,5 s. Logro nuevo: la insignia crece de 0,8 a 1 con rebote (350 ms) y acorde.
- **Voz.** No aplica.
- **Accesibilidad.** La clasificación es una lista con la posición anunciada. Las zonas llevan rótulo, no solo color. Cada insignia tiene nombre y descripción.
- **Analítica.** `league_viewed` {division, position}, `league_joined`, `league_opted_out`, `league_week_result` {result, position}, `achievement_unlocked` {achievement\_id}, `achievement_viewed`.

La puntuación premia la precisión y no el volumen para que la liga empuje hacia el objetivo del producto. El alias y la salida voluntaria existen porque muchos profesionales no quieren exponer su rendimiento ante compañeros.

### 5.14 Formulario de consulta

- **Objetivo y momento.** Avisar de un error en un ejercicio, plantear una duda sobre una explicación o sobre la app, o sugerir contenido. Se llega desde Perfil y desde «Informar de un error en este ejercicio». Lleva un aviso fijo: «No respondemos consultas sobre pacientes ni tratamientos».
- **Móvil.** Selector de tipo (error en un ejercicio, duda sobre una explicación, problema técnico, sugerencia de contenido, otro). Contexto del ejercicio adjunto como etiqueta eliminable: identificador, variante y respuesta dada. Campo de mensaje con rótulo visible y texto de ayuda. Correo de respuesta, ya rellenado. Captura opcional. «Enviar». Confirmación con referencia y lista «Mis consultas» con su estado: recibida, en revisión o respondida.
- **Tablet.** Formulario a la izquierda, con 560 dp de ancho máximo, y «Mis consultas» a la derecha.
- **Estados.** Envío: botón con indicador y desactivado. Error: mensaje con «Reintentar» y borrador conservado. Sin conexión: «Se enviará cuando haya conexión»; la consulta aparece como pendiente de envío. Lista vacía: «Aún no has enviado consultas».
- **Microinteracciones.** Validación al salir del campo, con el error debajo. Guardado automático del borrador. Al enviar, marca de confirmación (300 ms) con háptica de éxito.
- **Voz.** No aplica; funciona el dictado del sistema.
- **Accesibilidad.** Rótulos visibles, errores asociados a su campo y foco en el primer error tras un envío fallido.
- **Analítica.** `inquiry_opened` {source, type}, `inquiry_submitted` {type, has\_exercise, queued\_offline}, `inquiry_failed` {reason}, `inquiry_reply_viewed`.

### 5.15 Perfil

- **Objetivo y momento.** Pestaña propia. Reúne cuenta, itinerario y preferencias.
- **Móvil.** Cabecera con alias, sector, nivel y puntos. Lista de apartados: Mi itinerario (cambiar de sector o itinerario, repetir la prueba de nivel), Meta y recordatorios, Voz y accesibilidad, Suscripción, Organización (unirse con código y ver qué datos ve la organización), Descargas y sincronización, Consulta y ayuda, Privacidad (exportar datos, eliminar cuenta) y Legal. «Cerrar sesión» va separado, al final. Pie con versión de la app y del contenido.
- **Tablet.** Lista de apartados a la izquierda y contenido a la derecha.
- **Estados.** Perfil local sin cuenta: banda «Crea tu cuenta para no perder el progreso». Sin conexión: los cambios de cuenta se desactivan con su motivo; las preferencias locales siguen editables.
- **Microinteracciones.** Transiciones estándar de navegación. Conmutadores en 150 ms. Eliminar la cuenta exige confirmación escrita.
- **Voz.** No aplica.
- **Accesibilidad.** Las acciones destructivas están separadas del resto y rotuladas como tales.
- **Analítica.** `profile_viewed`, `itinerary_changed` {from, to}, `reminder_changed` {enabled, time}, `org_joined` {org\_id}, `data_export_requested`, `account_deletion_requested`, `logout`.

### 5.16 Ajustes de voz y accesibilidad

- **Objetivo y momento.** Ajustar la voz y la accesibilidad. Se llega desde Perfil y desde el engranaje de la sesión manos libres.
- **Móvil, bloque de voz.** Paquete de voz: estado, tamaño, actualizar y eliminar. Lectura: voz, velocidad de 0,8 a 1,5 y «Escuchar ejemplo». Reconocimiento: confirmación (siempre, solo si hay duda, nunca), espera de silencio (0,6, 0,9 o 1,5 segundos), cifra a cifra por defecto y sensibilidad al ruido. Prueba de micrófono con medidor y frase de prueba, que muestra lo entendido. Vocabulario: sinónimos de sector, como «gammas» por microgramos. Lista de comandos. Señales sonoras, lectura de explicaciones (breve, completa o ninguna) y modo bolsillo.
- **Móvil, bloque de accesibilidad.** Tamaño de texto adicional al del sistema, alto contraste, reducir movimiento, háptica, sonidos, ejercicios sin límite de tiempo, mano dominante (desplaza el teclado en pantallas grandes) y tema claro, oscuro o del sistema.
- **Tablet.** Dos columnas, voz y accesibilidad, con un ejercicio de muestra que refleja los cambios al instante.
- **Estados.** Descarga del paquete con progreso y reanudación. Sin conexión: la descarga queda en espera. Micrófono denegado: explicación y acceso a los ajustes del sistema.
- **Microinteracciones.** Los deslizadores marcan cada paso con un toque háptico. La prueba de micrófono muestra el nivel en tiempo real. Todo cambio se aplica al momento.
- **Voz.** La prueba ejecuta el reconocimiento real con la frase «cuatro coma ocho mililitros por hora».
- **Accesibilidad.** Cada ajuste tiene rótulo, valor actual anunciado y descripción de su efecto.
- **Analítica.** `voice_settings_changed` {setting, value}, `voice_pack_download_started`, `voice_pack_download_completed` {size\_mb}, `voice_pack_download_failed` {reason}, `mic_test_run` {understood, noise\_level}, `accessibility_setting_changed` {setting, value}.

### 5.17 Suscripción

- **Objetivo y momento.** Explicar el plan de pago y permitir la compra. Aparece desde Perfil, al tocar contenido de pago y al acabar la prueba.
- **Modelo supuesto.** Gratis: Fundamentos completo, las dos primeras unidades del itinerario elegido, repaso sin límite de lo ya abierto y 5 minutos diarios de manos libres. De pago: todos los itinerarios y sectores, manos libres sin límite, contrarreloj completo y estadísticas avanzadas. Prueba de 7 días. Las organizaciones dan acceso con código, sin compra en la app.
- **Móvil.** Titular de beneficio; cuatro ventajas con icono; selector de plan anual y mensual; precio con periodo y condiciones de renovación en lenguaje llano; «Probar 7 días gratis» (primaria); «Restaurar compras»; «Tengo un código de organización»; enlaces a términos y privacidad. Botón de cierre siempre visible y la frase «Cancela cuando quieras desde los ajustes de la tienda».
- **Tablet.** Ventajas a la izquierda; planes y acción a la derecha, con 420 dp de ancho máximo.
- **Estados.** Precios cargando: esqueleto; si falla, «No se pueden cargar los precios» y «Reintentar». Compra en curso, completada, cancelada y fallida, cada una con su mensaje. Sin conexión: no se puede comprar; el acceso ya adquirido sigue activo 30 días sin validar.
- **Microinteracciones.** El plan elegido se resalta en 150 ms con borde y marca. Compra completada: marca de confirmación y háptica de éxito.
- **Voz.** No aplica.
- **Accesibilidad.** El precio se lee con su periodo («treinta y nueve con noventa y nueve euros al año»). El plan elegido se indica con marca, no solo con color.
- **Analítica.** `paywall_viewed` {source}, `plan_selected` {plan}, `trial_started`, `purchase_completed` {plan, price, currency}, `purchase_failed` {reason}, `purchase_cancelled`, `restore_tapped`, `org_code_redeemed`.

### 5.18 Estados sin conexión

- **Objetivo y momento.** No es una pantalla, sino un comportamiento de toda la app y tres piezas visibles: el distintivo de conexión, los avisos de cambio y el centro de sincronización de Perfil.

| Función | Sin conexión | Al recuperar la red |
| --- | --- | --- |
| Lecciones, repaso, contrarreloj y manos libres | Completos con el contenido descargado | Se suben los intentos |
| Progreso y racha | Se calculan en el dispositivo | Se concilian con el servidor |
| Ligas | Última clasificación con su hora; puntos propios en espera | Se suman los puntos |
| Descarga de contenido y de voz | En cola | Se reanudan |
| Alta e inicio de sesión | No disponibles; se entrena con perfil local | Se puede crear la cuenta y fusionar el progreso |
| Compra | No disponible; el acceso adquirido se mantiene 30 días | Se revalida |
| Consulta | Se encola | Se envía |

- **Móvil.** Distintivo con icono y texto en las cabeceras de Inicio y Perfil. Aviso único al cambiar: «Sin conexión. Puedes seguir entrenando» y «Conexión recuperada. Progreso sincronizado», de 4 segundos. Centro de sincronización: última sincronización, elementos pendientes y «Sincronizar ahora».
- **Tablet.** Igual; el centro de sincronización es un panel de Perfil.
- **Estados.** Sincronizando. Error de sincronización: «No se ha podido sincronizar. Lo reintentaremos», con reintentos espaciados. Almacenamiento lleno: «Libera espacio para guardar tu progreso». Contenido nuevo: se descarga en segundo plano y se aplica al empezar la siguiente sesión. Contenido que exige una app más reciente: «Actualiza la app para ver el contenido nuevo».
- **Microinteracciones.** El distintivo aparece con un fundido de 200 ms. El icono de sincronización gira mientras trabaja; con movimiento reducido, es un texto. Los avisos no roban el foco.
- **Voz.** En manos libres no se anuncian cambios de conexión: no afectan a la sesión.
- **Accesibilidad.** Los cambios de estado se anuncian por región viva no intrusiva.
- **Analítica.** `connectivity_changed` {state}, `sync_started`, `sync_completed` {events\_uploaded, duration\_ms}, `sync_failed` {reason, retry\_in\_s}, `content_update_applied` {from, to}, `offline_action_blocked` {action}.

## 6. Sistema de diseño

El sistema parte del perfil sanitario, accesible y minimalista de la skill [UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) y lo ajusta a un entrenador con gamificación sobria. Dos de sus propuestas automáticas se descartan de forma expresa.

### 6.1 Dirección visual

| Decisión | Elegido | Descartado y motivo |
| --- | --- | --- |
| Estilo | Accesible y minimalista, de raíz suiza, con microinteracciones | Claymorphism: es lo que la skill propone para apps educativas, pero está pensado para público infantil. Neumorphism: lo propone para apps de salud, y sus propios datos le asignan riesgo alto de accesibilidad por bajo contraste |
| Profundidad | Superficies planas y un único nivel de sombra para hojas y capas | Degradados, vidrio y sombras múltiples |
| Forma | Radio de 12 dp en tarjetas, 16 dp en hojas y píldora en etiquetas; borde de 1 dp | Formas blandas y bordes gruesos |
| Densidad | Espaciosa en la sesión; estándar en listas y estadísticas | Densidad de panel de datos |
| Color | Un color de marca, dos de veredicto y un acento reservado a la gamificación | Colores neón y degradados morado-rosa |
| Iconos | Vectoriales de una sola familia | Emojis como iconos |

### 6.2 Paleta

La base es la paleta «Healthcare App» de la skill: cian sereno y verde salud. Su primario (#0891B2) y su verde (#059669) no alcanzan 4,5:1 sobre blanco, así que se oscurecen un paso para texto y botones. Las razones de contraste están calculadas para los dos temas; en el oscuro, todos los pares de texto superan 5,6:1.

| Token | Claro | Oscuro | Uso | Contraste en claro |
| --- | --- | --- | --- | --- |
| `color.primary` | #0E7490 | #22D3EE | Acción primaria, enlaces, nodo en curso | 5,4:1 con blanco |
| `color.brand` | #0891B2 | #22D3EE | Marca, ilustración y rellenos grandes | 3,7:1; no se usa en texto normal |
| `color.background` | #F4FAFB | #0B1D24 | Fondo de pantalla | — |
| `color.surface` | #FFFFFF | #12262E | Tarjetas y hojas | — |
| `color.foreground` | #164E63 | #E6F4F7 | Texto principal | 9,1:1 |
| `color.muted-foreground` | #475569 | #A8BCC4 | Texto secundario | 7,6:1 |
| `color.border` | #C5D9E0 | #2A4550 | Bordes y divisores | — |
| `color.success` | #047857 | #34D399 | Veredicto correcto | 5,5:1 |
| `color.error` | #DC2626 | #F87171 | Veredicto incorrecto y acciones destructivas | 4,8:1 |
| `color.warning` | #B45309 | #FBBF24 | Correcta con observación, avisos | 5,0:1 |
| `color.accent` | #D97706 | #FBBF24 | Racha, puntos y logros, solo en gráficos | 3,2:1; en texto se usa #92400E (7,1:1) |

Reglas de uso:

- En los componentes solo aparecen tokens semánticos, nunca valores hexadecimales.
- Verde y rojo significan veredicto y nada más. Van siempre con icono y palabra.
- El ámbar es exclusivo de la gamificación, para que un premio no se confunda con un aviso de corrección.
- El fondo es una versión menos saturada del que propone la skill (#ECFEFF), para que no compita con los colores de veredicto.

### 6.3 Tipografía

| Familia | Uso | Motivo |
| --- | --- | --- |
| Figtree (600 y 700) | Títulos e interfaz | Pareja «Medical Clean» de la skill: limpia y profesional |
| Noto Sans (400 y 500) | Cuerpo y enunciados | Misma pareja; cubre los idiomas de fases posteriores |
| Atkinson Hyperlegible Mono (400 y 700) | Cifras de cálculo: datos del enunciado, campo de respuesta, teclado y pasos | Diseñada para distinguir caracteres parecidos (0 y O, 1 y l). Al ser de ancho fijo, las cifras se alinean en los pasos y no saltan en los contadores |

| Rol | Tamaño e interlineado | Peso |
| --- | --- | --- |
| Titular | 32/40 sp | 700 |
| Título | 24/32 sp | 600 |
| Subtítulo | 20/28 sp | 600 |
| Enunciado | 18/28 sp | 400 |
| Cuerpo | 16/24 sp | 400 |
| Cuerpo pequeño | 14/20 sp | 400 |
| Etiqueta (mínimo) | 12/16 sp | 500 |
| Cifra de respuesta | 40/48 sp | 700 |
| Cifra en manos libres | 64 a 96 sp | 700 |

- **Coma reforzada.** En el campo de respuesta y en los resultados, la coma decimal se dibuja con más peso y con espacio a ambos lados. Motivo: una coma que pasa inadvertida es un error de factor diez.
- Número y unidad nunca se separan en dos líneas. El número va en negrita y la unidad en peso normal.
- Las fuentes van dentro de la app, para funcionar sin conexión. Sus licencias abiertas deben confirmarse antes de publicar.

### 6.4 Iconografía

- Una sola familia de trazo: Lucide, a 2 dp. La variante rellena se reserva para el destino activo de la navegación.
- Un juego propio de iconos de dominio en la misma retícula: jeringa, vial, ampolla, gotero, bomba de perfusión y especies.
- Tamaños por token: 16, 20, 24 y 32 dp. El área táctil es siempre de 48 dp como mínimo.
- Los iconos decorativos junto a un texto se ocultan al lector de pantalla; los que actúan solos llevan nombre accesible.

### 6.5 Componentes

| Componente | Variantes y estados | Notas |
| --- | --- | --- |
| Botón | Primario, secundario, terciario, destructivo; reposo, pulsado, desactivado, cargando | 52 dp de alto; un solo primario por pantalla |
| Teclado numérico | Cifras, coma, borrar; fila de unidades | Teclas de 56 dp; 420 dp de ancho máximo |
| Campo de respuesta | Vacío, con valor, correcto, con observación, incorrecto | Unidad como sufijo; coma reforzada |
| Etiqueta de dato | Cantidad y unidad | Resalta los datos clave del enunciado |
| Selector de unidad | Reposo, seleccionada | Etiquetas de 48 dp de alto |
| Tarjeta de opción | Reposo, seleccionada, correcta, incorrecta | Para T2, T5 y T6 |
| Lista ordenable | Reposo, en arrastre, colocada | Arrastre y toque |
| Banda de veredicto | Correcto, con observación, incorrecto | Icono, palabra y cifra |
| Tarjeta de paso | Normal, paso del desvío | Número, operación y unidades canceladas |
| Nodo de ruta | Bloqueada, disponible, en curso, superada, dominada, por refrescar | Icono y texto en todos los estados |
| Progreso de lección | Segmentos | Un segmento por ejercicio |
| Indicador de voz | Leyendo, escuchando, confirmando, en pausa | Icono, palabra y halo |
| Hoja inferior y capa | Corrección, cuenta, celebración | Con botón de cierre además del gesto |
| Aviso breve | Información, éxito, error | 4 segundos; no roba el foco |
| Gráfica | Línea, barras | Etiquetas directas y vista en tabla |

Espaciado en pasos de 4 y 8 dp: 4, 8, 12, 16, 24, 32 y 48. Márgenes laterales de 16, 24 y 32 dp según la clase de tamaño.

### 6.6 Elemento de marca: el menisco

No se propone mascota. Un personaje con emociones encaja mal con un público profesional y obliga a un tono que el producto quiere evitar.

El elemento de marca es el **menisco**: la superficie curva del líquido en una jeringa o una ampolla. Aparece en cuatro sitios:

- **Logotipo.** Una V cuyo interior muestra un nivel de líquido.
- **Progreso.** Nodos, cabeceras y anillos se llenan como un líquido que sube.
- **Celebración.** El llenado completo, con un brillo breve.
- **Espera.** El nivel oscila mientras algo carga.

Es propio del dominio, alude a la lectura precisa de un volumen y admite desde lo sobrio hasta lo celebratorio sin personaje. La parte emocional la llevan los textos y la voz. Si la investigación con usuarios pidiera un personaje, se probaría en una fase posterior.

### 6.7 Tono de los textos

Se tutea, con frases cortas. La cifra va siempre con su unidad. Se celebra con hechos, no con adjetivos. Un error dice qué ha pasado y qué hacer. Nunca se culpa al usuario por una racha rota.

| Situación | Sí | No |
| --- | --- | --- |
| Acierto | «Correcto. 4,8 ml/h» | «¡¡Genial, eres un crack!!» |
| Fallo | «No es correcto. Era 4,8 ml/h. Falta pasar de minutos a horas» | «¡Ups! Inténtalo otra vez» |
| Fin de lección | «9 de 10. Una ficha va a repaso» | «¡Increíble trabajo, campeón!» |
| Racha rota | «Tu racha se quedó en 12 días. Hoy empieza otra» | «¡Has perdido tu racha!» |
| Recordatorio | «Tienes 8 fichas de repaso. Son unos 4 minutos» | «Te echamos de menos» |
| Aviso formativo | «Esto es un entrenamiento. No lo uses con pacientes reales» | Letra pequeña al pie |

### 6.8 Pautas de movimiento

- Toda animación expresa una causa y un efecto: el segmento se llena porque se ha respondido.
- Uno o dos elementos animados por vista, como máximo.
- Duraciones y curvas por token (5.0). Rebote solo en logros e insignias.
- Las animaciones se pueden interrumpir y nunca bloquean un toque.
- Las transiciones entre pantallas conservan la continuidad: avanzar desplaza hacia la izquierda y volver, hacia la derecha.
- Con movimiento reducido, solo fundidos.

### 6.9 Comprobación antes de entregar una pantalla

Adaptada de la lista de la skill para apps nativas:

- Probada en móvil pequeño (375 dp), móvil grande y tablet, en vertical y en horizontal.
- Probada con el tamaño de texto máximo y con movimiento reducido.
- Contraste comprobado por separado en tema claro y oscuro.
- Todos los objetivos táctiles miden 48 dp y nada queda bajo las zonas seguras ni tras barras fijas.
- Ningún estado depende solo del color.
- Todo arrastre o gesto tiene una alternativa con botón.
- El orden del lector de pantalla coincide con el visual y cada control tiene nombre.
- Solo hay una acción primaria y los estados pulsado y desactivado se distinguen.

## 7. Experiencia de voz

La voz funciona entera en el dispositivo con un vocabulario cerrado: números, unidades y una docena de comandos. Esa restricción permite reconocer bien con un modelo pequeño. Lo entendido se confirma siempre antes de corregir.

### 7.1 Diseño conversacional

&#91;embedded content: turno de voz · 8 estados y 2 bucles de recuperación\]

Un «no» en la confirmación devuelve a la escucha. Si la app no entiende, reintenta, pasa a cifra a cifra y, al tercer fallo, abre el teclado.

| Estado | Qué hace la app | Qué puede decir el usuario |
| --- | --- | --- |
| Lectura | Lee los datos y, al final, la pregunta | «repite», «más despacio», «pausa» |
| Escucha | Señal sonora y micrófono abierto hasta 0,9 s de silencio, 12 s como máximo | La respuesta o un comando |
| Confirmación | Repite lo entendido con su unidad y pregunta «¿Correcto?» | «sí», «no» u otra cifra directamente |
| Veredicto | Dice el resultado y, si hay fallo, la respuesta correcta y el diagnóstico | «explica», «siguiente», «repite» |
| Explicación | Lee los pasos de uno en uno | «siguiente», «repite», «salta» |
| Pausa | Calla y solo atiende a «continúa» y «salir» | «continúa», «salir» |

Guion de un turno:

- **App:** «Ejercicio 3 de 10. Paciente simulado de 80 kilos. Noradrenalina a cero coma uno microgramos por kilo y minuto. Dilución de 100 microgramos por mililitro. ¿A cuántos mililitros por hora?»
- **Usuario:** «Cuatro coma ocho».
- **App:** «Cuatro coma ocho mililitros por hora. ¿Correcto?»
- **Usuario:** «Sí».
- **App:** «Correcto. Siguiente».

Reglas del diálogo:

- **Texto para voz propio.** Cada plantilla tiene una versión hablada, más corta que la escrita: primero los datos, con 400 ms de pausa entre ellos, y la pregunta al final. Motivo: lo último que se oye es lo que hay que responder.
- **Turnos alternos.** Por el altavoz, el micrófono no se abre mientras la app habla, para que no se oiga a sí misma. Con auriculares se puede interrumpir la lectura.
- **Confirmación con unidad.** Si la unidad es fija, basta decir la cifra; la confirmación la añade. Si hay que elegirla y falta, la app pregunta «¿En qué unidad?».
- **Cifras que se confunden.** Con pares como sesenta y setenta, dos y doce, o tres y trece, la confirmación deletrea: «Sesenta: seis, cero. ¿Correcto?».
- **Confirmación abreviada.** Opción de ajustes: si la confianza es alta, la app repite la cifra sin preguntar y deja 1,5 s para decir «no».
- **Un fallo de reconocimiento nunca cuenta como respuesta incorrecta.**

### 7.2 Comandos de voz

| Comando | Sinónimos | Efecto |
| --- | --- | --- |
| «repite» | «otra vez», «repítelo» | Repite la última locución |
| «repite los datos» | «los datos» | Repite solo los datos del enunciado |
| «siguiente» | «continuar» | Avanza. En escucha pregunta antes «¿Saltar este ejercicio?» |
| «no lo sé» | «ni idea» | Registra «no lo sé» y pasa al veredicto |
| «pausa» | «espera», «un momento» | Pausa la sesión |
| «continúa» | «sigue» | Reanuda |
| «sí» | «correcto», «eso es», «vale» | Confirma lo entendido |
| «no» | «incorrecto», «corrige» | Rechaza y vuelve a escuchar |
| «explica» | «cómo se hace» | Lee la resolución paso a paso |
| «salta» | — | Salta la explicación |
| «más despacio», «más rápido» | — | Cambia la velocidad de lectura |
| «cifra a cifra» | — | Activa el dictado cifra a cifra |
| «teclado» | «escribir» | Abre el teclado |
| «salir» | «terminar» | Pide confirmación y cierra la sesión |

Ningún comando coincide con una palabra de la gramática numérica ni con una respuesta posible. Por eso «paso» no es sinónimo de saltar: «paso dos» es una respuesta del tipo T5.

### 7.3 Gramática de respuestas numéricas

Una respuesta es un número y, si procede, una unidad.

- **Entero.** Cardinal de 0 a 999 999: «cero», «cuarenta y dos», «mil quinientos».
- **Separador decimal.** «coma», «con» o «punto».
- **Decimales.** Cifras sueltas («cero cinco») o un cardinal de dos o tres cifras («veinticinco»). Los ceros iniciales se dicen.
- **Fracciones habladas.** «medio», «y medio», «un cuarto», «y cuarto» y «tres cuartos».

| Lo que se dice | Lo que se interpreta |
| --- | --- |
| «cuatro coma ocho» | 4,8 |
| «cero coma cinco», «coma cinco», «cero con cinco», «cero punto cinco», «medio» | 0,5 |
| «dos y medio» | 2,5 |
| «cero coma veinticinco», «cero coma dos cinco», «un cuarto» | 0,25 |
| «cero coma cero cinco» | 0,05 |
| «tres coma doce» | 3,12 |
| «uno coma cinco cero» | 1,5 (se elimina el cero final) |
| «mil quinientos» | 1500 |
| «uno, dos, cero» en modo cifra a cifra | 120 |
| «dos cinco» sin separador | Ambiguo: la app pregunta «¿Veinticinco o dos coma cinco?» |

El reconocedor devuelve texto y un analizador propio lo convierte en número. Antes del análisis se aplica un **léxico de confusiones** editable desde el back office: «como» y «toma» pasan a «coma», «cerro» a «cero», «tos» a «dos».

**Léxico de unidades**

| Unidad | Formas habladas aceptadas |
| --- | --- |
| ml | «mililitros», «eme ele», «ce ce», «centímetros cúbicos» |
| ml/h | «mililitros por hora», «mililitros hora», «mililitros a la hora» |
| mg | «miligramos» |
| µg | «microgramos» y, con el sinónimo de sector activado, «gammas» |
| g | «gramos» |
| UI | «unidades», «unidades internacionales» |
| gotas/min | «gotas por minuto», «gotas minuto» |
| mg/ml | «miligramos por mililitro», «miligramos mililitro» |
| µg/kg/min | «microgramos por kilo y minuto», «microgramos kilo minuto» |
| % | «por ciento» |

«Miligramos», «microgramos» y «mililitros» suenan parecido. Cuando el usuario elige la unidad y el reconocedor duda entre dos, la app pregunta: «¿Miligramos o microgramos?».

**De cifra a voz.** El normalizador de lectura es el mismo en la app, en el lector de pantalla y en la vista previa del back office.

| Escrito | Leído |
| --- | --- |
| 0,25 mg | «cero coma veinticinco miligramos» |
| 0,05 mg | «cero coma cero cinco miligramos» |
| 1 mg, 1 UI, 21 mg | «un miligramo», «una unidad», «veintiún miligramos» |
| 2 % | «dos por ciento» |
| 1:10 000 | «uno en diez mil» |
| 250 mg/5 ml | «doscientos cincuenta miligramos en cinco mililitros» |
| µg/kg/min | «microgramos por kilo y minuto» |

### 7.4 Gestión de errores de reconocimiento

| Situación | Cómo se detecta | Qué hace la app |
| --- | --- | --- |
| No se oye voz | Sin voz en 6 s | «No te he oído. ¿Lo repito?». A la segunda vez, pausa |
| Voz que no encaja en la gramática | El analizador no obtiene un número | «No te he entendido. Di solo la cifra» |
| Respuesta ambigua o confianza baja | Dos interpretaciones o confianza bajo el umbral | Pregunta de desambiguación |
| Segundo fallo en el mismo ejercicio | Contador | Pasa a cifra a cifra: «Dilo cifra a cifra» |
| Tercer fallo | Contador | Abre el teclado y lo dice: «Te abro el teclado» |
| Dos «no» seguidos en la confirmación | Contador | Pasa a cifra a cifra |
| Ruido ambiente alto | Nivel de ruido medido antes de hablar | Avisa, sube el umbral de detección de voz y sugiere auriculares |
| Otra app toma el audio o entra una llamada | Aviso del sistema | Pausa |

Uso con guantes o manos ocupadas:

- Toda la pantalla pausa o continúa con un toque, que también funciona con el nudillo o el antebrazo.
- Tres botones de 72 dp para los comandos más usados.
- El botón de los auriculares pausa y reanuda.
- El modo bolsillo bloquea el tacto y oscurece la pantalla.

### 7.5 Latencia objetivo

Medida en un dispositivo de referencia de gama media con 4 GB de memoria.

| Tramo | Objetivo | Límite |
| --- | --- | --- |
| Fin de la lectura a micrófono abierto | 150 ms | 300 ms |
| Fin del silencio de corte a cifra en pantalla | 400 ms | 800 ms |
| Cifra entendida a inicio de la confirmación hablada | 200 ms | 400 ms |
| «Sí» a veredicto sonoro | 300 ms | 600 ms |
| Arranque del motor de voz | 1,5 s | 3 s |

Un turno completo dura entre 15 y 20 segundos, de modo que una sesión de 10 minutos da para unos 30 ejercicios. El tiempo de respuesta por voz se mide aparte del táctil y no incluye la lectura ni la confirmación.

### 7.6 Privacidad de la voz

- El audio vive solo en memoria mientras se reconoce. No se escribe en disco ni se envía a ningún servidor.
- El módulo de voz no tiene ninguna ruta de red. Se comprueba con una batería de pruebas en modo avión en cada versión.
- Se guarda lo mismo que si se hubiera tecleado: la respuesta interpretada. Aparte, métricas técnicas sin contenido: latencia, confianza y categoría del fallo.
- No se guarda texto transcrito.
- El permiso de micrófono se pide al entrar por primera vez en manos libres, con su explicación. Mientras el micrófono está abierto se ve el halo, además del indicador del sistema.
- Los modelos de voz se descargan de la infraestructura propia, firmados y verificados.

### 7.7 Idiomas

- El MVP sale en español de España. La gramática acepta desde el principio «punto» como separador decimal.
- Cada idioma es un **paquete de idioma**: modelo de reconocimiento, voz de síntesis, gramática numérica, léxico de unidades y comandos, normalizador de lectura y textos. Añadir un idioma no exige cambiar el motor.
- La interfaz puede traducirse a un idioma antes de que tenga voz; en ese caso, el modo manos libres no se ofrece en él.
- El orden de los siguientes idiomas es una pregunta abierta (sección 14).

## 8. Back office

El back office es una aplicación web con la que un administrador no técnico crea, valida y publica contenido sin tocar código ni esperar a una versión nueva de la app. Nada llega a los usuarios sin la validación de un experto distinto del autor.

### 8.1 Roles y permisos

| Capacidad | Superadministrador | Administrador de contenido | Autor | Revisor experto | Administrador de organización | Analista | Soporte |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Sectores e itinerarios | Sí | Sí | No | No | No | No | No |
| Crear y editar preguntas y plantillas | Sí | Sí | Las suyas | Solo comentar | No | No | No |
| Crear tipos de ejercicio | Sí | Sí | No | No | No | No | No |
| Importación masiva | Sí | Sí | Sí | No | No | No | No |
| Validar contenido | No | No | No | Sí, en sus sectores | No | No | No |
| Publicar versiones | Sí | Sí | No | No | No | No | No |
| Usuarios | Sí | No | No | No | Los de su organización | No | Consulta y acciones de soporte |
| Organizaciones | Sí | No | No | No | La suya | No | Consulta |
| Analítica de contenido | Sí | Sí | La de su contenido | La de sus sectores | Agregada de su organización | Sí | No |
| Logros y ligas | Sí | Sí | No | No | Ligas privadas de su organización | No | No |
| Consultas de usuarios | Sí | Sí | Las asignadas | Las asignadas | No | No | Sí |
| Registro de auditoría | Sí | Consulta | No | No | No | No | No |

Reglas transversales:

- **Cuatro ojos.** Nadie valida contenido del que es autor. Validar es exclusivo del revisor experto, acreditado por sector.
- **Doble factor obligatorio** para todos los roles del back office.
- **Nada se borra.** El contenido se retira y se archiva; toda acción queda en el registro de auditoría.

### 8.2 Convenciones del back office

- **Disposición.** Pensado para escritorio a partir de 1280 px, utilizable desde 1024 px. Barra lateral con las secciones y zona de trabajo en patrón lista y detalle.
- **Estados del contenido.** Borrador, en revisión, cambios solicitados, validado, publicado y retirado. Cada uno con etiqueta de texto e icono.
- **Guardado.** Automático en borradores, con indicador «Guardado». Los cambios sobre contenido publicado crean una versión nueva en borrador.
- **Estados de pantalla.** Carga con esqueleto; vacío con una acción; error con causa y reintento. Sin conexión: banda «Sin conexión: tus cambios se conservan en este navegador y se guardarán al volver».
- **Lenguaje.** Sin términos técnicos: «fórmula», «variable», «variante», «publicar».
- **Accesibilidad.** Todo se opera con teclado, el foco es visible, los errores de formulario se listan en un resumen enlazado a cada campo y ningún arrastre es la única forma de hacer algo.
- **Analítica.** Eventos con prefijo `bo_` y el rol del usuario.

### 8.3 Panel de control

- **Objetivo.** Ver de un vistazo qué requiere atención, según el rol.
- **Contenido y jerarquía.** Primero, «Mi trabajo»: borradores propios, revisiones pendientes y cambios solicitados. Después, alertas de calidad: plantillas con tasa de fallo anómala, avisos de error en ejercicios y tiempos objetivo descalibrados. Luego, estado del catálogo por sector (plantillas y variantes publicadas, cobertura por habilidad) y actividad (usuarios activos, sesiones, precisión media). Al pie, la última publicación y «Preparar publicación».
- **Estados.** Carga: esqueleto de tarjetas. Vacío en una instalación nueva: guía de cinco pasos (sector, itinerario, plantilla, revisión y publicación). Error por tarjeta, con reintento, sin tumbar el panel.
- **Microinteracciones.** Las cifras cuentan hasta su valor una vez (300 ms). Cada alerta enlaza con el elemento afectado. Marca «Actualizado hace 2 min» y refresco cada 5 minutos.
- **Accesibilidad.** Cada tarjeta es una región con encabezado. La gravedad de una alerta se indica con icono y palabra.
- **Analítica.** `bo_dashboard_viewed` {role}, `bo_alert_opened` {alert\_type}, `bo_onboarding_step_completed` {step}.

### 8.4 Gestión de sectores e itinerarios

- **Objetivo.** Construir el árbol de sector, itinerario, unidad y lección, y decidir qué ejercicios lleva cada lección.
- **Contenido y jerarquía.** Tres columnas. Izquierda: el árbol, reordenable. Centro: ficha del nodo elegido (nombre, descripción, icono, habilidades, requisito previo y estado). Derecha, en una lección: sus huecos de ejercicio, cada uno con plantilla, nivel de dificultad y tipo, o bien la regla «automática por habilidad». La ficha de sector incluye su vocabulario, la notación de unidades, las especies y los instrumentos. Un indicador de cobertura señala las unidades sin lecciones y las lecciones con pocas plantillas validadas.
- **Estados.** Árbol vacío: «Crear el primer sector». Validación: una lección sin ejercicios no puede enviarse a publicar. Edición simultánea: «María está editando esta unidad», en modo de solo lectura hasta que termine.
- **Microinteracciones.** Al arrastrar, hueco de destino resaltado. «Guardado» aparece 200 ms después de cada cambio. Reordenar y retirar se deshacen desde un aviso de 5 segundos.
- **Accesibilidad.** El árbol se recorre con las flechas. Reordenar también se hace con los botones «subir» y «bajar».
- **Analítica.** `bo_structure_node_created` {level}, `bo_structure_reordered`, `bo_lesson_composed` {slots}, `bo_structure_validation_failed` {reason}.

### 8.5 Editor de plantillas parametrizadas

- **Objetivo.** Definir un ejercicio que genera cientos de variantes numéricas correctas, sin código. Es la pantalla central del back office.
- **Contenido y jerarquía.** Asistente de seis pasos a la izquierda, vista previa a la derecha y panel de pruebas abajo.

| Paso | Qué se define | Detalle |
| --- | --- | --- |
| 1. Datos generales | Nombre, sector, habilidad, tipo de ejercicio y especie | La especie solo en veterinaria |
| 2. Variables | Nombre, tipo, rango, paso, unidad y si se muestra en el enunciado | Tipos: entero, decimal, lista, tabla de casos y calculada |
| 3. Enunciado | Texto con las variables insertadas como etiquetas; texto para voz | El texto para voz se genera solo y se puede editar y escuchar |
| 4. Fórmula y respuesta | Fórmula, unidad, redondeo, tolerancia y unidades equivalentes | Con comprobación dimensional |
| 5. Restricciones y errores previsibles | Rango admitido del resultado, condiciones entre variables y fórmulas erróneas con su código de error | Botones para añadir los errores habituales |
| 6. Explicación y niveles | Pasos de la resolución con sus valores intermedios; rangos por nivel de dificultad | Cinco niveles |

- **Tabla de casos.** Una variable puede ser una tabla cuyas filas son combinaciones coherentes: fármaco, pauta, presentación y especie. El generador elige una fila entera. Motivo: combinar rangos independientes produciría casos farmacológicamente absurdos.
- **Comprobación dimensional.** Mientras se escribe la fórmula, el editor calcula la unidad resultante: «mg/kg × kg ÷ mg/ml = ml», correcto; o «El resultado sale en mg, no en ml». Una fórmula que no cuadra en unidades no se puede guardar.
- **Funciones disponibles.** Suma, resta, multiplicación, división, paréntesis, redondear, mínimo, máximo y condición «si». Con mínimo se expresa la dosis máxima.
- **Panel de pruebas.** «Generar 20 variantes de muestra» muestra variables, respuesta y pasos. «Prueba masiva» genera 1000 e informa de: porcentaje descartado por las restricciones, distribución de las respuestas, repeticiones, valores extremos y colisiones entre la respuesta correcta y una errónea previsible. Se fija el número de variantes que se publicarán por nivel, 300 por defecto.
- **Estados.** Borrador con guardado automático. Error de fórmula o de unidades junto al campo. Generación en curso con progreso. Variantes insuficientes: «Solo 42 variantes cumplen las restricciones. Amplía los rangos».
- **Microinteracciones.** La comprobación dimensional se actualiza 200 ms después de dejar de escribir, con icono y texto. Al pasar por una fila de muestra, sus valores se resaltan en la vista previa.
- **Accesibilidad.** La fórmula se construye entera con teclado y tiene lectura en texto. Las tablas de variables y de muestra son navegables por celdas.
- **Analítica.** `bo_template_created`, `bo_template_variable_added` {type}, `bo_template_formula_error` {kind}, `bo_template_sample_generated` {n, discarded\_pct}, `bo_template_mass_test_run` {n, issues}, `bo_template_submitted_for_review`.

Ejemplo de plantilla, con el ejemplo A de la sección 3:

| Elemento | Valor |
| --- | --- |
| Variables | `peso`: entero, de 5 a 40 kg, paso 1. `caso`: tabla con meloxicam, 0,2 mg/kg, 5 mg/ml, perro |
| Enunciado | Perro de {peso} kg. Pauta: {fármaco} {dosis} mg/kg por vía subcutánea. Presentación: {concentración} mg/ml. ¿Qué volumen cargas? |
| Fórmula | dosis × peso ÷ concentración |
| Unidad y redondeo | ml; jeringa según el volumen |
| Restricción | Resultado entre 0,1 y 3 ml |
| Errores previsibles | Resultado × 10 (E2); dosis × peso (E4); dosis × peso × concentración (E3) |
| Pasos | 1) dosis × peso = mg; 2) mg ÷ concentración = ml |

### 8.6 Editor de preguntas

- **Objetivo.** Crear una pregunta fija, sin variantes: conceptual o con números cerrados. Es habitual en los tipos T2, T3, T5 y T10.
- **Contenido y jerarquía.** Formulario a la izquierda: tipo de ejercicio, sector, unidad, habilidad, enunciado, opciones o pasos según el tipo, respuesta correcta, código de error de cada opción falsa, explicación paso a paso, texto para voz, dificultad y tiempo objetivo. A la derecha, vista previa en móvil o tablet y en tema claro u oscuro. Abajo, «Guardar borrador» y «Enviar a revisión». Las cantidades se insertan como elementos de número y unidad, lo que garantiza su formato y su lectura.
- **Comprobaciones automáticas al enviar.** Campos obligatorios, cantidades con unidad, explicación presente, texto para voz presente y aviso de posible duplicado.
- **Estados.** Borrador. Errores junto al campo y en resumen. Vista previa cargando. Conflicto de edición.
- **Microinteracciones.** La vista previa se actualiza 300 ms después de cada cambio. La barra inclinada abre el insertador de cantidades.
- **Accesibilidad.** Rótulos visibles y resumen de errores con foco. La vista previa tiene equivalente en texto.
- **Analítica.** `bo_question_created` {type}, `bo_question_submitted_for_review`, `bo_question_validation_failed` {rule}.

### 8.7 Creador de tipos de ejercicio

- **Objetivo.** Definir una mecánica nueva combinando bloques ya existentes, sin código y sin publicar una versión de la app.
- **Concepto.** Un tipo es una secuencia de pasos de interacción. Cada paso combina bloques de presentación, un bloque de respuesta y una regla de corrección. La app incluye un intérprete genérico que dibuja cualquier combinación.

| Familia | Bloques disponibles |
| --- | --- |
| Presentación | Enunciado, datos destacados, imagen, operación con huecos, lista de pasos, cálculo resuelto, temporizador |
| Respuesta | Numérica con unidad, selección única, selección múltiple, ordenar, emparejar, rellenar huecos, sí o no |
| Corrección | Numérica con tolerancia, coincidencia exacta, orden con equivalencias, conjunto de pares |
| Comportamiento | Pistas, tiempo límite, puntuación, segundo intento |

- **Contenido y jerarquía.** Paleta de bloques a la izquierda. En el centro, la lista vertical de pasos. A la derecha, propiedades del bloque elegido y vista previa con «Probar con una pregunta de ejemplo». La compatibilidad con voz se calcula sola: el tipo es compatible si todos sus bloques de respuesta lo son.
- **Límite que hay que conocer.** Un tipo nuevo es una combinación nueva de bloques. Un bloque nuevo, como la jeringa deslizable, sí exige una versión de la app. Cada tipo declara la versión mínima de la app; las anteriores no muestran ese contenido. Antes de publicar, el back office indica qué porcentaje de los dispositivos activos lo admite.
- **Estados.** Borrador. Aviso de compatibilidad. Tipo en uso: no se retira y sus cambios crean una versión. Error de validación: paso sin bloque de respuesta.
- **Microinteracciones.** Un bloque añadido entra en 200 ms y la vista previa se refresca al momento.
- **Accesibilidad.** Los bloques se añaden y se ordenan con botones además de con arrastre.
- **Analítica.** `bo_exercise_type_created` {blocks}, `bo_exercise_type_tested`, `bo_exercise_type_published` {min\_app\_version, supported\_base\_pct}.

### 8.8 Importación masiva y flujo de revisión

**Importación masiva**

- **Objetivo.** Cargar muchas preguntas, o las filas de una tabla de casos, desde una hoja de cálculo.
- **Contenido y jerarquía.** Cuatro pasos: descargar la hoja modelo del tipo de ejercicio; subir el archivo (CSV o XLSX); emparejar columnas y validar; confirmar. La validación muestra cada fila con su estado y el motivo: «Fila 14: falta la unidad de la respuesta». Se admiten 2000 filas por archivo. Lo importado entra siempre como borrador, nunca publicado.
- **Estados.** Subida y análisis con progreso. Formato no reconocido. Todas las filas con error. Importación parcial con informe descargable. Cancelada.
- **Microinteracciones.** Filtro «solo errores». Las celdas con error se corrigen en la propia tabla y se revalidan al salir.
- **Accesibilidad.** El estado de cada fila es texto. Hay un resumen de errores con enlaces a las filas.
- **Analítica.** `bo_import_started` {type, rows}, `bo_import_validated` {ok, warnings, errors}, `bo_import_completed` {imported}, `bo_import_cancelled`.

**Revisión y validación por un experto**

- **Objetivo.** Que un experto del sector compruebe cada pregunta y cada plantilla antes de publicarse.
- **Ciclo.** Borrador, en revisión, cambios solicitados (vuelve a borrador), validado, publicado y retirado.
- **Contenido y jerarquía.** Bandeja con filtros por sector, tipo y antigüedad. Ficha de revisión en tres zonas. Izquierda: el ejercicio tal como lo verá el usuario, con lectura en voz alta. Centro: en plantillas, 20 variantes al azar más los valores extremos, con el recálculo independiente del sistema junto a cada respuesta. Derecha: lista de comprobación obligatoria, comentarios anclados y decisión («Validar», «Solicitar cambios» con comentario obligatorio, «Rechazar»).
- **Lista de comprobación del revisor.** Pauta plausible; presentación existente; unidades correctas; aritmética verificada; redondeo adecuado al instrumento; explicación clara; texto para voz correcto; errores previsibles pertinentes.
- **Firma.** La validación guarda revisor, acreditación, fecha y huella de la versión. Caduca a los 24 meses, o antes si se marca un cambio en la información del fármaco; el contenido caducado vuelve a la bandeja. Los sectores que se configuren, como pediatría, exigen dos revisores.
- **Estados.** Bandeja vacía. Contenido modificado durante la revisión: se muestra la diferencia y se reinicia la lista. Revisor sin acreditación en el sector: puede comentar y no validar.
- **Microinteracciones.** La lista de comprobación muestra su avance. La vista de diferencias marca lo añadido y lo eliminado con signo y color.
- **Accesibilidad.** Los comentarios se crean y se recorren con teclado. Las diferencias no dependen del color.
- **Analítica.** `bo_review_started`, `bo_review_comment_added`, `bo_review_decision` {decision, hours\_in\_review}, `bo_review_checklist_item_failed` {item}.

### 8.9 Versionado y publicación de contenido

- **Objetivo.** Reunir contenido validado en una versión y entregarla a las apps sin pasar por las tiendas.
- **Cómo funciona.** Una publicación es una foto del contenido validado. Al publicar, el servidor genera las variantes de cada plantilla, las recalcula con un segundo motor independiente, construye un paquete firmado por itinerario y lo deja en la red de distribución con su manifiesto. Las apps lo descargan al conectarse y lo aplican al empezar la siguiente sesión.
- **Contenido y jerarquía.** Izquierda: versiones con su estado (en preparación, en pruebas, publicada, revertida). Centro: «Cambios en esta versión», con lo añadido, lo modificado y lo retirado frente a la versión activa; lo no validado aparece atenuado con su motivo y no puede incluirse. Derecha: comprobaciones y acciones.
- **Comprobaciones automáticas.** Variantes generadas en la cantidad pedida; doble cálculo coincidente; ninguna colisión entre respuesta correcta y errónea previsible; todos los ejercicios con explicación y texto para voz; versión mínima de la app y porcentaje de dispositivos compatibles; tamaño del paquete.
- **Acciones.** «Generar paquete de prueba», que se instala en dispositivos de prueba con un código QR. «Publicar», con despliegue gradual al 5 %, al 50 % y al 100 %. «Revertir» a la versión anterior con una sola acción. «Retirar ejercicio ahora» publica una lista de retirada que las apps aplican en cuanto tienen conexión, sin esperar a una versión.
- **Estados.** Comprobaciones en curso. Comprobación fallida: bloquea la publicación y enlaza con el elemento. Publicando. Publicada. Reversión en curso. Sin cambios que publicar.
- **Microinteracciones.** Cada comprobación se marca al superarse. Publicar exige escribir el nombre de la versión. El avance del despliegue se ve en una barra.
- **Accesibilidad.** Las diferencias llevan signo además de color. Los estados son texto.
- **Analítica.** `bo_release_created`, `bo_release_checks_run` {passed, failed}, `bo_release_test_package_built`, `bo_release_published` {version, added, changed, retired, rollout\_pct}, `bo_release_rolled_back` {version, reason}, `bo_item_withdrawn` {item\_id}.

### 8.10 Vista previa con lectura en voz alta

- **Objetivo.** Ver y oír un ejercicio exactamente como lo recibirá el usuario, desde cualquier editor y desde la revisión.
- **Contenido y jerarquía.** Marco de dispositivo con opciones: móvil o tablet, vertical u horizontal, tema claro u oscuro y texto al 100, 150 o 200 %. Dos modos: táctil y manos libres. En manos libres se reproduce el turno completo con el mismo normalizador de lectura de la app, y a su lado aparece el texto que se dice, con las cantidades resaltadas. «Simular respuesta» permite escribir lo que diría el usuario y muestra cómo lo interpreta la gramática y qué veredicto recibe. En plantillas se elige variante: una concreta, al azar o los extremos. «Probar en un dispositivo» envía el ejercicio a la app de pruebas con un código QR.
- **Estados.** Audio generándose. Voz no disponible en el navegador: se muestra solo el texto que se diría, con aviso. Variante no válida.
- **Microinteracciones.** El texto se resalta palabra a palabra al ritmo del audio. Controles de reproducción y de velocidad.
- **Accesibilidad.** El texto de lo que se dice está siempre disponible. Los controles tienen nombre y atajo de teclado.
- **Analítica.** `bo_preview_opened` {mode, device}, `bo_preview_audio_played`, `bo_preview_answer_simulated` {parsed\_ok}, `bo_preview_device_test_started`.

El texto resaltado junto al audio existe porque los errores de lectura, como una razón 1:10 000 mal dicha, se detectan mejor leyendo y oyendo a la vez.

### 8.11 Gestión de usuarios y organizaciones

- **Objetivo.** Dar soporte a los usuarios y administrar las organizaciones cliente: universidades, hospitales y clínicas.
- **Usuarios.** Lista con búsqueda por alias, correo, sector, plan, organización y última actividad. Ficha con perfil, plan, dispositivos, resumen de progreso de solo lectura y consultas. Acciones: restablecer el acceso, conceder días de plan de pago, exportar los datos, eliminar o anonimizar la cuenta y bloquear. Las acciones sensibles exigen motivo y quedan en auditoría.
- **Organizaciones.** Ficha con datos, plan (plazas contratadas y usadas, fechas), administradores, grupos, formas de acceso (código de invitación o dominio de correo), itinerarios asignados, ligas privadas e informe de grupo: finalización, precisión y habilidades dominadas.
- **Qué ve la organización.** Por defecto, solo datos agregados del grupo. Los datos individuales exigen activar el modo nominal, que informa de ello a cada usuario antes de unirse. Motivo: el rendimiento de un profesional ante su empleador es un dato delicado (sección 11).
- **Estados.** Sin resultados. Plazas agotadas. Invitaciones pendientes. Usuario que ya pertenece a otra organización.
- **Microinteracciones.** Invitación masiva por archivo con validación fila a fila. El contador de plazas se actualiza al momento. El código de invitación se copia con un clic y lo confirma.
- **Accesibilidad.** Tablas con cabeceras ordenables que anuncian el sentido de la ordenación.
- **Analítica.** `bo_user_searched`, `bo_user_action` {action}, `bo_org_created`, `bo_org_seats_changed`, `bo_org_invites_sent` {n}, `bo_org_report_viewed`, `bo_data_export_fulfilled`, `bo_account_deleted`.

### 8.12 Analítica de contenido

- **Objetivo.** Encontrar los ejercicios que fallan demasiado o demasiado poco, los tiempos mal calibrados y las explicaciones que no funcionan.
- **Contenido y jerarquía.** Filtros por sector, itinerario, unidad, habilidad, tipo, periodo y versión. Tabla de plantillas y preguntas con: respuestas, acierto al primer intento, tiempo mediano frente al objetivo, porcentaje de «no lo sé», errores críticos, error más frecuente, abandono en el ejercicio y avisos de error recibidos.
- **Ficha de un elemento.** Respuestas erróneas más dadas, con su código de error; las no clasificadas se agrupan y se pueden convertir en error previsible con «Añadir como error previsible». Acierto por nivel de dificultad, por variante y por modo de entrada (voz o táctil). Distribución de tiempos. Evolución entre versiones.
- **Alertas.** Acierto inferior al 40 % o superior al 98 %; «no lo sé» por encima del 25 %; errores sin clasificar por encima del 30 %; tiempo mediano superior al doble del objetivo; una variante con acierto muy inferior al resto de su plantilla.
- **Estados.** Datos insuficientes, con menos de 50 respuestas. Carga. Exportación a CSV.
- **Microinteracciones.** Tocar una barra filtra la tabla. Los valores se ven al pasar el cursor o al enfocar con el teclado.
- **Accesibilidad.** Toda gráfica tiene su tabla equivalente y una frase de resumen.
- **Analítica.** `bo_content_analytics_viewed` {filters}, `bo_item_analytics_opened` {item\_id}, `bo_error_pattern_promoted`, `bo_analytics_exported`.

### 8.13 Gestión de logros y ligas

- **Objetivo.** Configurar la gamificación sin código.
- **Logros.** Lista y editor con nombre, descripción, categoría, icono de la biblioteca y condición. La condición se arma con métrica, operador, valor y ámbito. Métricas: días de racha, aciertos seguidos, habilidades dominadas, sesiones de manos libres, marca válida de contrarreloj y ejercicios sin error crítico. Se define si es visible o secreto, su vigencia y si se concede con efecto retroactivo. «Probar con un usuario de ejemplo» muestra si lo obtendría.
- **Ligas.** Tamaño de grupo, divisiones, ascensos y descensos, puntuación (puntos por acierto, bonificaciones y tope diario), día de inicio de la semana y agrupación por sector. Estado de la semana en curso. Lista de usuarios marcados por patrones anómalos, como velocidades imposibles, para su revisión.
- **Regla.** Los cambios de reglas entran en vigor al empezar la semana siguiente, nunca a mitad de semana.
- **Estados.** Sin logros. Condición incompleta. Cambio programado para la próxima semana.
- **Microinteracciones.** La insignia se previsualiza al cambiar icono o categoría. La prueba de condición responde en menos de un segundo.
- **Accesibilidad.** El constructor de condiciones es un formulario con rótulos, no un lienzo gráfico.
- **Analítica.** `bo_achievement_created`, `bo_achievement_rule_tested`, `bo_league_config_changed` {field}, `bo_league_user_flagged`.

### 8.14 Consultas, catálogos de voz y auditoría

**Consultas de usuarios**

- **Objetivo.** Atender lo que llega del formulario de consulta de la app.
- **Contenido.** Bandeja con tipo, estado, antigüedad y persona asignada. La ficha muestra la variante exacta del ejercicio y la respuesta que dio el usuario. Acciones: responder (con respuestas modelo), convertir en corrección de contenido (crea un borrador enlazado) y retirar el ejercicio de inmediato. Las consultas sobre pacientes reciben una respuesta modelo que las declina.
- **Analítica.** `bo_inquiry_opened`, `bo_inquiry_answered` {hours\_to\_answer}, `bo_inquiry_converted_to_fix`.

**Catálogos de unidades y de voz**

- **Objetivo.** Mantener lo que comparten todos los ejercicios.
- **Contenido.** Unidades: símbolo, nombre, lectura en voz, formas habladas aceptadas, magnitud y factor de conversión. Instrumentos y su precisión. Léxico de confusiones del reconocimiento. Comandos y sinónimos por idioma. Sinónimos por sector. Cuadro de prueba: «Escribe lo que diría el usuario», con la interpretación resultante.
- **Regla.** Un cambio de catálogo sigue el mismo ciclo de revisión y publicación que el contenido.
- **Analítica.** `bo_catalog_item_changed` {catalog}, `bo_voice_lexicon_tested` {parsed\_ok}.

**Registro de auditoría**

- **Objetivo.** Saber quién hizo qué y cuándo.
- **Contenido.** Registro inalterable con autor, acción, fecha y valores anterior y posterior. Filtros por persona, tipo de acción, elemento y fechas. Exportación.
- **Analítica.** `bo_audit_viewed`, `bo_audit_exported`.

## 9. Modelo de datos

El modelo tiene tres ámbitos: contenido, que se crea en el back office y es inmutable una vez publicado; usuarios y organizaciones; y aprendizaje, que nace en el dispositivo y se sincroniza. El hecho central es el **intento**: todo el progreso se deriva de él.

### 9.1 Principios

- **El intento es la fuente de verdad.** Los intentos solo se añaden, nunca se modifican. Fichas de repaso, estado de las habilidades, rachas y progreso son proyecciones que se recalculan a partir de ellos.
- **Sin conflictos de sincronización.** Dos dispositivos sin conexión generan intentos distintos, y unirlos es sumar conjuntos. Las proyecciones dan el mismo resultado en cualquier dispositivo.
- **Identificadores creados en el dispositivo.** UUID ordenables en el tiempo (versión 7), para crear registros sin red.
- **Contenido versionado e inmutable.** Una variante pertenece a una versión concreta de su plantilla. Un intento apunta a su variante, de modo que la analítica distingue versiones.
- **Datos personales mínimos.** Alias y correo. Ningún dato de salud ni de pacientes.

### 9.2 Contenido

| Entidad | Campos principales | Relaciones |
| --- | --- | --- |
| Sector | id, código, nombre, descripción, icono, notación de unidades, orden, estado | Tiene itinerarios |
| Itinerario | id, nombre, descripción, nivel recomendado, orden, estado | Pertenece a un sector; tiene unidades |
| Unidad | id, nombre, guía rápida, unidad requisito, orden | Pertenece a un itinerario; tiene lecciones; trabaja habilidades |
| Lección | id, tipo de lección, regla de composición, duración estimada, orden | Pertenece a una unidad; tiene huecos |
| Hueco de lección | id, posición, nivel de dificultad | Une una lección con una plantilla o una pregunta |
| Habilidad | id, código, nombre, descripción | Referida por plantillas, preguntas y unidades |
| Tipo de ejercicio | id, nombre, definición de pasos y bloques, compatible con voz, versión mínima de la app, versión | Usado por plantillas y preguntas |
| Plantilla | id, variables, tabla de casos, enunciado, texto para voz, fórmula, unidad de respuesta, redondeo, tolerancia, unidades aceptadas, restricciones, errores previsibles, pasos, rangos y tiempo objetivo por nivel, especie, estado, versión | Tiene un tipo, una habilidad y un sector; genera variantes |
| Pregunta | id, enunciado, opciones o pasos, respuesta, explicación, texto para voz, dificultad, tiempo objetivo, estado, versión | Tiene un tipo, una habilidad y un sector |
| Variante | id, versión de la plantilla, nivel, valores de las variables, respuesta canónica, unidad, respuestas erróneas con su código, pasos resueltos, texto para voz resuelto | Pertenece a una plantilla |
| Revisión | id, versión revisada, decisión, lista de comprobación, comentarios, fecha, caducidad, huella | De una plantilla, pregunta o catálogo; hecha por un revisor |
| Versión de contenido | id, número, estado, notas, porcentaje de despliegue, versión mínima de la app, fecha de publicación | Incluye plantillas, preguntas y catálogos validados |
| Paquete | id, dirección, tamaño, resumen criptográfico, firma | De una versión y un itinerario |
| Unidad de medida | símbolo, nombre, lectura, formas habladas, magnitud, factor de conversión | Catálogo |
| Instrumento | nombre, capacidad, precisión | Catálogo |
| Léxico de voz | idioma, clase (confusión, comando, sinónimo), entrada, salida | Opcionalmente ligado a un sector |
| Logro | id, nombre, descripción, categoría, icono, condición, vigencia | — |
| Configuración de liga | tamaño de grupo, divisiones, reglas de ascenso, puntuación, tope diario | — |

### 9.3 Usuarios y organizaciones

| Entidad | Campos principales | Relaciones |
| --- | --- | --- |
| Usuario | id, alias, correo, sector principal, itinerario activo, nivel declarado, idioma, consentimientos, estado, fecha de alta | Tiene dispositivos, suscripción y pertenencias |
| Dispositivo | id, plataforma, modelo, versión de la app, versión del contenido, paquete de voz, última sincronización | Pertenece a un usuario |
| Cuenta de back office | rol, sectores acreditados, acreditación profesional, doble factor | Extiende a un usuario |
| Organización | id, nombre, tipo, plan, plazas, vigencia, modo de visibilidad | Tiene grupos y pertenencias |
| Grupo | id, nombre | Pertenece a una organización |
| Pertenencia | rol, fecha, aceptación del modo nominal | Une usuario, organización y grupo |
| Suscripción | plan, origen (tienda u organización), estado, inicio, renovación, identificador externo | De un usuario o de una organización |

### 9.4 Aprendizaje

| Entidad | Campos principales | Relaciones |
| --- | --- | --- |
| Sesión | id, tipo (lección, repaso, contrarreloj, manos libres, prueba de nivel), inicio, fin, modo de entrada, versión del contenido | De un usuario y un dispositivo; opcionalmente de una lección |
| Intento | id, nivel, valor y unidad de la respuesta, veredicto, código de error, crítico, tiempo, pistas, número de intento, modo de entrada, métricas de voz, hora del dispositivo, hora del servidor | De una sesión; apunta a una variante o a una pregunta, y a su plantilla y habilidad |
| Ficha de repaso | estabilidad, dificultad, vencimiento, último repaso, repeticiones, fallos, en cuarentena | De un usuario, una plantilla y un nivel. Proyección |
| Estado de habilidad | estado, precisión de los últimos 20, mediana de tiempo, días distintos | De un usuario y una habilidad. Proyección |
| Progreso de lección | estado, mejor precisión, fecha | De un usuario y una lección. Proyección |
| Racha | días actuales, mejor racha, último día cumplido, tipo de meta | De un usuario. Proyección |
| Participación en liga | semana, grupo, división, puntos, posición | De un usuario. Se calcula en el servidor |
| Logro obtenido | fecha | Une usuario y logro |
| Marca de contrarreloj | formato, aciertos, precisión, válida, fecha | De un usuario y una habilidad |
| Consulta | tipo, mensaje, respuesta dada en el ejercicio, estado, persona asignada, respuesta, fechas | De un usuario; opcionalmente de una variante |
| Registro de auditoría | autor, acción, elemento, valor anterior, valor posterior, fecha | Del back office |

### 9.5 Base de datos local

El dispositivo guarda tres grupos de tablas:

- **Contenido**, de solo lectura, cargado desde los paquetes: estructura del itinerario, tipos, preguntas, variantes y catálogos.
- **Aprendizaje**, de lectura y escritura: sesiones, intentos y sus proyecciones.
- **Bandeja de salida**: intentos, consultas y eventos de analítica pendientes de subir, con su número de reintentos.

## 10. Arquitectura y tecnologías

Se recomienda Flutter en el dispositivo, reconocimiento de voz con un modelo embebido ejecutado por sherpa-onnx, SQLite con sincronización propia, Supabase en la UE y un back office web a medida en React. El estado de cada tecnología se ha comprobado en noviembre de 2026; las fuentes están al final del documento.

### 10.1 Visión general

&#91;embedded content: arquitectura · back office, nube en la UE y dispositivo\]

Solo dos flujos cruzan entre la nube y el dispositivo: bajan paquetes de contenido firmados y suben intentos. La voz no tiene ninguna conexión con la nube.

Decisión de arquitectura que condiciona el resto: **el dispositivo no calcula fórmulas**. Las variantes de cada plantilla se generan y se verifican en el servidor al publicar, y viajan en el paquete con su respuesta, sus pasos y sus respuestas erróneas previsibles. El dispositivo solo compara.

- Motivo de seguridad: ninguna cifra llega al usuario sin haber pasado por el doble cálculo y por la muestra del revisor.
- Motivo técnico: hay un único motor de fórmulas, en el servidor. No hay dos implementaciones que puedan divergir entre app y back office.
- Coste: paquetes mayores. Con 100 plantillas, 5 niveles y 300 variantes por nivel, un itinerario ocupa entre 10 y 20 MB comprimido. Es una estimación que debe medirse.

### 10.2 Framework multiplataforma

| Criterio | Flutter | React Native con Expo | Kotlin Multiplatform con Compose |
| --- | --- | --- | --- |
| Estado en noviembre de 2026 | 3.47 estable desde agosto de 2026; 3.50 prevista para noviembre. Motor Impeller por defecto en Android desde la 3.44 | 0.88, de octubre de 2026. La nueva arquitectura es la única desde la 0.82 | Compose Multiplatform es estable en iOS desde la 1.8.0, de mayo de 2025; va por la 1.11 |
| Interfaz a medida y animación | Motor de dibujo propio: idéntico en iOS y Android | Componentes nativos: más ajustes por plataforma | Bueno en Android; más joven en iOS |
| Diseño adaptativo en tablet | Bueno | Bueno | Bueno |
| Voz en el dispositivo | Paquete oficial de sherpa-onnx | Enlaces mantenidos por la comunidad | Integración nativa propia en cada plataforma |
| Base local y sincronización | Drift sobre SQLite; SDK de PowerSync | SQLite con varias bibliotecas; SDK de PowerSync | SQLDelight; SDK de PowerSync |
| Lenguaje común con el back office | No (Dart y TypeScript) | Sí (TypeScript) | No |
| Disponibilidad de perfiles | Amplia | La más amplia | Menor |

**Recomendación: Flutter.** El riesgo del producto está en una interfaz muy a medida, animada y adaptativa, y en la voz en el dispositivo. Flutter dibuja igual en las dos plataformas, lo que reduce la matriz de pruebas, y tiene enlace oficial con el motor de voz elegido. La ventaja de React Native, compartir TypeScript con el back office, pierde peso porque el dispositivo no ejecuta fórmulas. Si el equipo disponible es de React, React Native con Expo es una segunda opción válida.

### 10.3 Reconocimiento de voz en el dispositivo

El requisito es estricto: sin nube y en modo avión, garantizado en todos los dispositivos admitidos.

| Opción | Tamaño | A favor | En contra |
| --- | --- | --- | --- |
| Motores nativos: Speech de Apple y SpeechRecognizer de Android | 0 MB en la app | Sin descarga; buena calidad general; los mantiene el sistema | En iOS, la API nueva (SpeechAnalyzer) solo existe desde iOS 26. En Android, el reconocedor en el dispositivo existe desde la API 31, pero depende del dispositivo y del paquete de idioma instalado, y falla si no está. No se puede garantizar el modo avión en todo el parque |
| Vosk, modelo pequeño de español | 39 MB | Muy ligero; permite limitar el reconocimiento a una lista de palabras; licencia Apache 2.0 | Tecnología más antigua; tasa de error del 16 % en dictado abierto (Common Voice) y del 11 % en MLS |
| sherpa-onnx con modelo Zipformer de español en flujo continuo | De 70 a 150 MB según la cuantización (dato de terceros, por medir) | Paquete oficial para Flutter y en desarrollo activo; reconoce mientras se habla; incluye detección de voz y síntesis en el mismo motor; admite sesgo hacia un vocabulario | Modelo más pesado; licencia del modelo de español por confirmar |
| Whisper (tiny, base o small) | 75, 142 o 466 MB | Muy buena calidad en dictado abierto; el modelo small ajustado a español ronda el 8 % de error | No reconoce en flujo continuo; más latencia; tiende a inventar texto con audios cortos o silencio, que es justo el caso de una cifra |

**Recomendación: modelo embebido con sherpa-onnx**, detrás de una interfaz propia (`MotorDeVoz`) que permite cambiar de motor sin tocar el resto de la app.

- Es la única vía que garantiza el mismo comportamiento, sin red, en iOS y en Android.
- La tasa de error en dictado abierto no es la métrica relevante. Aquí el vocabulario es cerrado, de unas 150 palabras, y hay confirmación hablada.
- Vosk con vocabulario restringido queda como plan B si la prueba técnica muestra mejor acierto con cifras.
- Los motores nativos pueden añadirse más adelante como opción en los dispositivos donde el reconocimiento local esté garantizado, para ahorrar la descarga.

**Prueba técnica previa, en la fase 0.** 500 respuestas numéricas grabadas por 20 hablantes con acentos distintos, en silencio y con ruido de 65 dB, en seis dispositivos. Criterio de aceptación: 97 % de respuestas bien interpretadas al primer intento en silencio y 92 % con ruido.

### 10.4 Síntesis de voz en el dispositivo

| Opción | Tamaño | A favor | En contra |
| --- | --- | --- | --- |
| Voces del sistema (AVSpeechSynthesizer y TextToSpeech) | 0 MB | Sin descarga; latencia baja; el usuario ya las conoce | En Android dependen del motor y de las voces instaladas; la calidad varía entre fabricantes |
| Piper, ejecutado por sherpa-onnx | Unos 60 MB por voz | Misma voz en todos los dispositivos; funciona sin red | Muchas voces publicadas tienen licencia no comercial: hay que elegir o encargar una voz con licencia comercial |
| Modelos nuevos multilingües (por ejemplo, Kokoro) | Desde 80 MB | Mejor naturalidad | Calidad en español por evaluar; integración más reciente |

**Recomendación: voz del sistema por defecto y Piper como respaldo.** En el alta de manos libres, la app comprueba que hay una voz de español que no requiere red. Si no la hay, descarga la voz embebida con el paquete de voz. La app controla lo que se dice con su normalizador, de modo que la lectura de cifras y unidades es la misma con cualquier voz.

### 10.5 Requisitos mínimos de dispositivo

Valores propuestos, por confirmar en la prueba técnica.

| Concepto | Requisito |
| --- | --- |
| iOS y iPadOS | 16 o posterior |
| Android | 9 (API 28) o posterior, procesador ARM de 64 bits |
| Memoria para manos libres | 3 GB como mínimo; 4 GB recomendados |
| Paquete de voz | De 80 a 220 MB: reconocimiento, detección de voz y, si hace falta, voz de síntesis. Se descarga bajo demanda, no va en el instalador |
| Contenido | De 10 a 20 MB por itinerario |
| Espacio libre recomendado | 400 MB |

### 10.6 Base de datos local y sincronización

| Opción | A favor | En contra |
| --- | --- | --- |
| SQLite con Drift y sincronización propia por bandeja de salida | Control total; el modelo de solo añadir hace sencilla la sincronización; sin coste por usuario | Hay que construir y probar reintentos e idempotencia |
| PowerSync entre SQLite y Postgres | Sincronización bidireccional resuelta, con SDK para Flutter e integración con Supabase | Servicio y coste añadidos; resuelve más de lo que este modelo necesita |
| Firestore con caché sin conexión | Arranque rápido | Modelo documental, consultas locales limitadas y datos fuera de Postgres |

**Recomendación: SQLite con Drift y sincronización propia.**

- **Subida.** Lotes de intentos, identificados por su UUID. Repetir un envío no duplica nada.
- **Bajada.** Clasificación de la liga, respuestas a consultas y, en un dispositivo nuevo, el historial de intentos para reconstruir las proyecciones.
- **Preferencias.** Gana la última escritura.
- **Repaso espaciado.** La biblioteca `fsrs` para Dart, de código abierto con licencia MIT, se ejecuta en el dispositivo.

PowerSync es la alternativa si el equipo prefiere comprar la sincronización en lugar de construirla.

### 10.7 Backend y API

| Opción | A favor | En contra |
| --- | --- | --- |
| Supabase: Postgres gestionado, autenticación, almacenamiento y funciones, en región de la UE | Rápido de poner en marcha; Postgres estándar; se puede autoalojar | Dependencia de un proveedor; límites en las funciones |
| Firebase | Muy maduro en móvil | Base documental; analítica de contenido más difícil; mayor dependencia |
| Backend a medida sobre Postgres | Control total | Más tiempo y más operación |

**Recomendación: Supabase en la UE y un servicio propio de publicación en TypeScript.** El servicio genera variantes, hace el doble cálculo con una segunda implementación independiente, construye y firma los paquetes y calcula las ligas con una tarea programada. La API es REST con contrato OpenAPI. Puntos principales: envío de intentos por lotes, manifiesto de contenido, liga actual y consultas.

### 10.8 Back office web

| Opción | A favor | En contra |
| --- | --- | --- |
| A medida con React, TypeScript y una biblioteca de administración (Refine o React Admin) | Los editores clave son específicos: plantillas, tipos, revisión y vista previa con voz | Más desarrollo inicial |
| Gestor de contenidos sin cabecera (Payload, Directus, Strapi) | Formularios, roles y versiones de serie | El editor de fórmulas, la comprobación dimensional y el flujo de revisión habría que desarrollarlos igualmente como extensiones |
| Herramienta de bajo código (Retool, Appsmith) | Lo más rápido | Experiencia limitada para un usuario no técnico; licencias por usuario |

**Recomendación: a medida con React y TypeScript.** El motor de plantillas es una biblioteca de TypeScript que usan tanto la vista previa del back office como el servicio de publicación.

### 10.9 Autenticación, analítica y distribución de contenido

| Área | Alternativas | Recomendación y motivo |
| --- | --- | --- |
| Autenticación | Supabase Auth, Firebase Auth, Auth0, Keycloak | Supabase Auth: correo con código de un solo uso, Apple y Google. Perfil local antes de crear cuenta. Doble factor en el back office. Acceso corporativo para organizaciones en la fase 3 |
| Analítica de producto | PostHog, Firebase Analytics, Amplitude, Mixpanel | PostHog en su nube de la UE: embudos, retención y activación gradual de funciones. Los eventos se encolan sin conexión |
| Analítica de aprendizaje | La misma herramienta o datos propios | Tabla de intentos propia en Postgres. Los datos pedagógicos no deben depender de una herramienta externa |
| Distribución de contenido | Paquetes propios en una red de distribución; recursos bajo demanda de cada tienda | Paquetes por itinerario en almacenamiento de objetos con red de distribución. Manifiesto con versión, tamaño, resumen SHA-256 y firma. Descarga reanudable, cambio atómico al empezar la siguiente sesión y despliegue gradual |
| Suscripciones | Integración directa con cada tienda o RevenueCat | RevenueCat para las compras en las tiendas; facturación aparte para las organizaciones |
| Avisos | Locales o remotos | Recordatorios como notificaciones locales, que funcionan sin red; remotas solo para resultados de liga |
| Errores y calidad | Sentry, Crashlytics | Sentry en la UE. Pruebas de imagen para los diseños adaptativos, batería en modo avión y conjunto de regresión de voz |

## 11. Seguridad, privacidad y regulación

Mientras su finalidad prevista sea formativa y no procese datos de pacientes, VolutrainMed queda fuera de la normativa de producto sanitario. Ese encaje depende de decisiones de diseño concretas. Este análisis no es asesoramiento jurídico: debe confirmarlo un especialista en regulación sanitaria y en protección de datos antes del lanzamiento.

### 11.1 Protección de datos (RGPD)

| Aspecto | Decisión |
| --- | --- |
| Datos que se tratan | Cuenta (correo y alias), perfil (sector y nivel declarado), aprendizaje (intentos, tiempos y errores), dispositivo (modelo y versiones), estado de la suscripción y consultas |
| Datos que no se tratan | Datos de pacientes, datos de salud del usuario, audio, texto transcrito, ubicación y contactos. Los datos de pago los trata la tienda |
| Bases jurídicas | Ejecución del contrato para prestar el servicio. Consentimiento para comunicaciones comerciales. La base de la analítica de producto (interés legítimo o consentimiento) se decide con asesoría |
| Minimización | Alias en las ligas, identificador seudónimo en la analítica, sin publicidad ni componentes publicitarios |
| Conservación | Mientras la cuenta esté activa. Propuesta: anonimizar a los 24 meses de inactividad. Los intentos anonimizados se conservan para la analítica de contenido |
| Derechos | Exportación y supresión desde Perfil; rectificación y oposición a la analítica |
| Encargados | Backend, analítica y registro de errores en la UE. El proveedor de suscripciones puede implicar transferencia internacional, que exige garantías contractuales |
| Organizaciones | Contrato de encargo con cada organización cliente. Por defecto solo ven datos agregados; el modo nominal exige informar antes a cada usuario |
| Menores | Propuesta: edad mínima de 16 años en los términos de uso. Pregunta abierta, porque hay estudiantes de formación profesional sanitaria de esa edad |
| Evaluación de impacto | Previsiblemente no obligatoria: no hay categorías especiales ni observación a gran escala. Se documenta un análisis de riesgos y se revisa al activar el modo nominal |

El rendimiento de un profesional visto por su empleador es un dato delicado aunque no sea de categoría especial. Por eso el modo nominal está desactivado por defecto y requiere revisión laboral en cada cliente.

### 11.2 Tratamiento de los datos de voz

- El audio se procesa en el dispositivo y solo en memoria. No se guarda ni se transmite.
- No hay identificación por voz, así que la voz no se trata como dato biométrico.
- No se guarda texto transcrito, solo la respuesta interpretada, que equivale a la tecleada.
- El módulo de voz no incluye componentes de terceros con acceso a la red.
- El permiso de micrófono se pide en contexto y la app funciona entera sin concederlo.
- La ficha de privacidad de las tiendas declara que no se recogen datos de audio. La batería de pruebas en modo avión lo respalda en cada versión.
- Si en el futuro se usan los motores del sistema, será solo forzando el reconocimiento local; donde no pueda garantizarse, no se ofrecerán.

### 11.3 Seguridad

- Comunicaciones cifradas y credenciales en el almacén seguro del sistema.
- Base local protegida por el cifrado del dispositivo; cifrado adicional de la base si una organización lo exige.
- Paquetes de contenido y modelos de voz firmados. La app rechaza lo que no verifica.
- Back office con doble factor, permisos por rol aplicados también en la base de datos y registro de auditoría.
- Copias de seguridad con restauración probada, análisis de dependencias y prueba de intrusión antes del lanzamiento.
- Ligas: el servidor comprueba la plausibilidad de los intentos (tiempos imposibles, relojes manipulados).
- Los clientes del sector público español pueden exigir el Esquema Nacional de Seguridad. Se valora en la fase 3.

### 11.4 Por qué queda fuera de la normativa de producto sanitario

El Reglamento (UE) 2017/745 define el producto sanitario por la finalidad prevista por el fabricante. La guía [MDCG 2019-11 rev.1](https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en), de junio de 2025, concreta cómo aplicarlo al software. Según el [resumen de OpenRegulatory](https://openregulatory.com/mdcg/mdcg-2019-11), la finalidad prevista se deduce del etiquetado, las instrucciones y la promoción, y el software que calcula dosis para un paciente suele calificarse como producto sanitario.

| Criterio | Situación de VolutrainMed |
| --- | --- |
| Finalidad prevista declarada | Formación y entrenamiento de estudiantes y profesionales. Ni diagnóstico ni tratamiento |
| Datos de pacientes individuales | No se procesan. Los casos son simulados y no existe entrada libre de datos |
| Información para una decisión clínica | No se produce. El resultado es un veredicto sobre la respuesta del usuario a un caso ficticio |
| Recomendación de pautas | No hay. La pauta es un dato del enunciado |
| Promoción | Habla de entrenar, aprender y ganar agilidad. Nunca de calcular dosis en la práctica |

### 11.5 Decisiones de diseño que lo harían entrar

| Decisión | Por qué cruza la línea | Tratamiento |
| --- | --- | --- |
| Modo calculadora con peso, fármaco y dosis libres | Calcula una dosis para un paciente. Con la regla 11 sería clase IIa como mínimo, y IIb o III según el daño posible | Prohibido por diseño |
| «Practica con tus propios datos»: introducir un peso real | Tiene el mismo efecto que una calculadora | Prohibido por diseño |
| Comprobador: «escribe tu cálculo y te digo si está bien» | Apoya una decisión sobre un caso real | Prohibido por diseño |
| Tablas de dosis recomendadas enlazadas a un cálculo | Información para decisiones terapéuticas | Fuera de alcance |
| Integración con historia clínica, prescripciones o bombas | Trata datos de pacientes e influye en la atención | Fuera de alcance |
| Guardar casos reales del usuario | Datos de pacientes | Fuera de alcance |
| Mensajes como «úsalo en tu guardia» o «calcula la dosis de tu paciente» | La promoción también define la finalidad prevista | Vetados en la guía de comunicación |
| Promocionar el modo manos libres para usarlo durante la atención | Sugiere uso clínico | Vetado en la guía de comunicación |

Salvaguardas permanentes:

- Aviso formativo en el alta, en ajustes, en los términos y en la descripción de las tiendas.
- Todo caso se rotula como simulado y usa principios activos, no marcas.
- **Control de cambios regulatorio**: cualquier función nueva pasa por las preguntas de la tabla anterior antes de entrar en el plan.
- Justificación escrita de la calificación, archivada y revisada cada año.
- Seguimiento de la reforma del reglamento que la Comisión propuso en diciembre de 2025, que afecta a la clasificación del software.

### 11.6 Normas de las tiendas de aplicaciones

- **Apple.** La [norma 1.4.2](https://developer.apple.com/app-store/review/guidelines/) reserva las calculadoras de dosis a fabricantes, hospitales, universidades, aseguradoras, farmacias u otras entidades aprobadas, o exige aprobación regulatoria. Un revisor podría tomar la app por una calculadora. Mitigación: ficha y capturas centradas en la formación, notas para el revisor que expliquen que los casos son simulados y que no hay cálculo libre, y vídeo de demostración. Plan B: publicar con el respaldo de una universidad o una institución sanitaria.
- **Apple, acceso.** La norma 4.8 obliga a ofrecer una opción de acceso respetuosa con la privacidad si se ofrece el acceso con Google. Se cumple con el acceso de Apple.
- **Google Play.** Hay que completar la [declaración de apps de salud](https://support.google.com/googleplay/android-developer/answer/14738291), en la categoría de referencia y educación médica. Su [política de funciones médicas](https://support.google.com/googleplay/android-developer/answer/16555673) exige un aviso a las apps sin aprobación regulatoria y está incorporando la guía europea.

### 11.7 Otras normas que conviene vigilar

Estos tres puntos se citan de memoria y deben confirmarse con asesoría.

- **Accesibilidad.** La Directiva (UE) 2019/882, traspuesta en España por la Ley 11/2023, alcanza a determinados servicios digitales de consumo desde junio de 2025, con excepciones para microempresas. El diseño se ajusta a WCAG 2.2 nivel AA en cualquier caso.
- **Reglamento de inteligencia artificial.** La corrección es aritmética determinista y el reconocimiento de voz es un método de entrada con confirmación humana. Hay que confirmar que eso mantiene el producto fuera de los sistemas de alto riesgo en educación, sobre todo si una institución lo usa para evaluar o certificar.
- **Consumo.** Transparencia de precios y renovación, y derecho de desistimiento en las suscripciones.

## 12. Métricas

La métrica principal es el número de **habilidades dominadas y mantenidas por usuario activo al mes**. Mide a la vez que el usuario vuelve y que aprende. Los objetivos numéricos son hipótesis de partida, por calibrar con los primeros datos.

### 12.1 Aprendizaje

| Métrica | Definición | Objetivo inicial | Eventos |
| --- | --- | --- | --- |
| Precisión al primer intento | Aciertos al primer intento entre ejercicios respondidos, por habilidad | 95 % al dominar | `answer_submitted` |
| Tasa de errores críticos | Intentos con error crítico entre intentos | Mitad en la cuarta semana que en la primera | `answer_submitted` {error\_code} |
| Tiempo frente al objetivo | Mediana del tiempo de respuesta dividida por el tiempo objetivo | 1,0 o menos al dominar | `answer_submitted` {time\_ms} |
| Retención del aprendizaje | Precisión en repasos con intervalo de 7 días o más, y de 30 o más | 90 % | `review_item_answered` |
| Tiempo hasta el dominio | Días y ejercicios desde el primer intento hasta «Dominada» | Sin objetivo; se observa | `skill_state_changed` |
| Transferencia | Precisión en lecciones mixtas y retos de unidad | 85 % | `lesson_completed` |
| Recaídas | Fichas falladas tras dos aciertos seguidos | Menos del 10 % | `review_item_answered` |
| Calidad de la voz | Respuestas interpretadas a la primera; sesiones con caída al teclado | 95 %; menos del 5 % | `voice_answer_captured`, `voice_fallback_keyboard` |

### 12.2 Retención

| Métrica | Definición | Objetivo inicial | Eventos |
| --- | --- | --- | --- |
| Activación | Altas que completan la primera lección el primer día | 70 % | `onboarding_started`, `lesson_completed` |
| Retención a 1, 7 y 30 días | Usuarios que vuelven ese día | Por calibrar | `screen_viewed`, `lesson_completed` |
| Usuarios semanales con tres sesiones o más | Sobre el total de activos semanales | 40 % | `lesson_completed`, `review_session_completed` |
| Finalización de lección | Lecciones completadas entre iniciadas | 85 % | `lesson_started`, `lesson_completed`, `session_exited` |
| Cumplimiento del repaso | Fichas repasadas entre fichas vencidas | 70 % | `review_session_completed` |
| Rachas | Racha media y usuarios con 7 días o más | Por calibrar | `streak_extended` |
| Uso de manos libres | Activos semanales con al menos una sesión de voz | 20 % | `handsfree_session_started` |

### 12.3 Negocio

| Métrica | Definición | Eventos o fuente |
| --- | --- | --- |
| Conversión a prueba y a pago | De ver la pantalla de suscripción a iniciar la prueba y a pagar | `paywall_viewed`, `trial_started`, `purchase_completed` |
| Ingresos recurrentes, ingreso por usuario y bajas | Mensuales, por plan | Proveedor de suscripciones |
| Coste de adquisición y valor de vida | Por canal | Marketing y proveedor de suscripciones |
| Organizaciones | Plazas activadas entre contratadas; renovación | `org_joined`, `bo_org_seats_changed` |
| Ritmo de contenido | Plantillas validadas por semana; horas de revisión por plantilla | `bo_review_decision` |
| Calidad de contenido | Avisos de error por cada 1000 ejercicios; tiempo hasta la corrección | `content_issue_reported`, `bo_inquiry_converted_to_fix` |

### 12.4 Métricas de guarda

- La precisión no debe bajar cuando sube el uso del contrarreloj o de las ligas.
- Proporción de marcas de contrarreloj no válidas: si crece, el modo está empujando a correr.
- Ningún experimento altera la corrección ni el contenido validado. Se experimenta con presentación, orden y gamificación.

## 13. Alcance por fases

El producto mínimo viable responde a tres preguntas: si la voz sin nube reconoce bien las cifras, si el usuario vuelve y si un administrador no técnico produce contenido validado a buen ritmo. Lo que no ayuda a responderlas pasa a fases posteriores.

&#91;embedded content: hoja de ruta · 4 fases y 3 criterios de paso\]

Criterios de paso: de la fase 0 a la 1, un 97 % de cifras bien interpretadas en silencio y el encaje regulatorio confirmado; de la 1 a la 2, retención en objetivo y contenido sin errores críticos notificados; de la 2 a la 3, organizaciones piloto que renuevan.

| Fase | Incluye | Queda fuera |
| --- | --- | --- |
| 0. Validación | Prueba técnica de voz (500 locuciones, 6 dispositivos). 40 plantillas validadas de un itinerario. Prototipo navegable de la sesión táctil y de manos libres. Consulta regulatoria y de tiendas | Todo lo demás |
| 1. Producto mínimo viable | Español de España. Fundamentos y dos itinerarios. Tipos T1, T2, T3, T6 y T7. Ruta, lección, corrección paso a paso, repaso espaciado, rachas, puntos y niveles, cinco logros fijos, esprint de contrarreloj. Manos libres con T1, T2, T6 y T7. Funcionamiento completo sin conexión. Diseño adaptativo en tablet. Cuenta, suscripción individual y consulta. Back office: estructura, plantillas, preguntas, importación, revisión, publicación con reversión, vista previa con voz, usuarios y analítica básica de contenido | Ligas, organizaciones, creador de tipos, logros configurables |
| 2. Crecimiento | Ligas y logros configurables. Organizaciones: grupos, informes agregados y ligas privadas. Creador de tipos de ejercicio. Tipos T4, T5, T8 y T10. Resto de sectores. Serie de contrarreloj. Ajuste personalizado del repaso | Idiomas, examen y certificados |
| 3. Expansión | Paquetes de idioma. Tipo T9. Modo examen y certificados de formación. Acceso corporativo. Integración con plataformas de formación. Motores de voz del sistema como opción. Requisitos del sector público | — |

Criterio de cada corte:

- **Ligas, a la fase 2.** Un grupo de 30 personas del mismo sector exige una base de usuarios que el lanzamiento no tiene. Una liga medio vacía desmotiva.
- **Creador de tipos, a la fase 2.** Aporta valor cuando el catálogo fijo se queda corto. El intérprete genérico de tipos sí se construye en el MVP, de modo que los tipos son datos desde el primer día y no hay que rehacer nada.
- **Organizaciones, a la fase 2.** Su ciclo de venta es largo. El modelo de datos las contempla desde el principio.
- **Manos libres, en el MVP.** Es el diferencial y el mayor riesgo técnico; cuanto antes se pruebe con usuarios reales, mejor.
- **Tablet, en el MVP.** Rehacer las disposiciones después cuesta más que diseñarlas a la vez.

## 14. Riesgos, supuestos y preguntas abiertas

Los tres riesgos que pueden parar el proyecto son el reconocimiento de cifras, el rechazo en la tienda de Apple y la publicación de un ejercicio erróneo. Los tres tienen mitigación dentro de la fase 0 o del propio diseño.

### 14.1 Riesgos

| Riesgo | Probabilidad | Impacto | Mitigación |
| --- | --- | --- | --- |
| El reconocimiento de cifras no es fiable con ruido o con ciertos acentos | Media | Alto | Prueba técnica en la fase 0; vocabulario cerrado; confirmación; cifra a cifra; teclado; motor intercambiable |
| Apple rechaza la app por la norma de calculadoras de dosis | Media | Alto | Posicionamiento formativo, notas al revisor y respaldo de una universidad o institución |
| Se publica un ejercicio con un error farmacológico o aritmético | Baja | Muy alto | Cuatro ojos, doble cálculo, muestra de variantes, retirada inmediata y caducidad de la validación |
| Deriva hacia una calculadora por presión comercial o de usuarios | Media | Alto | Control de cambios regulatorio y primer principio de diseño |
| Faltan revisores expertos y el contenido se atasca | Alta | Medio | Una plantilla validada produce cientos de ejercicios; importación masiva; red de colaboradores académicos |
| El tamaño del paquete de voz frena la adopción | Media | Medio | Descarga bajo demanda y por wifi; modelo ligero como alternativa |
| Las licencias de modelos o voces no permiten uso comercial | Media | Medio | Revisión de licencias antes de integrar; presupuesto para una voz propia |
| La gamificación premia la velocidad sobre la exactitud | Media | Alto | Reglas de precisión en contrarreloj y ligas; métricas de guarda |
| Fragmentación de Android en memoria y audio | Media | Medio | Requisitos mínimos, lista de dispositivos de prueba y paso al modo táctil |
| Los estudiantes no están dispuestos a pagar | Media | Alto | Plan gratuito útil; licencias a universidades |
| Una organización usa los datos de rendimiento contra sus empleados | Baja | Alto | Datos agregados por defecto; modo nominal informado |
| Cambios normativos en producto sanitario o inteligencia artificial | Media | Medio | Revisión anual de la calificación |
| Dependencia del proveedor de backend | Baja | Medio | Postgres estándar y plan de salida |

### 14.2 Supuestos

Decisiones tomadas sin dato de partida. Cualquiera puede cambiarse; se indica qué arrastra.

| N.º | Supuesto | Si cambia, afecta a |
| --- | --- | --- |
| S1 | El lanzamiento es en español de España | Paquete de idioma y contenido |
| S2 | El MVP abre con Fundamentos, anestesia y veterinaria de pequeños animales. Se deduce del nombre del proyecto | Contenido y revisores de la fase 1 |
| S3 | Modelo mixto: suscripción individual con plan gratuito y licencias a organizaciones | Pantalla de suscripción y fase de organizaciones |
| S4 | Precios de trabajo: 6,99 € al mes y 39,99 € al año. Por validar | Solo la pantalla de suscripción |
| S5 | Equipo de dos desarrolladores de móvil, uno de backend, uno de web, un diseñador, un responsable de producto y un revisor farmacólogo a tiempo parcial. Con él, la fase 0 dura unas 6 semanas y el MVP, de 5 a 6 meses. Orientativo | Calendario |
| S6 | La empresa está establecida en la UE y toda la infraestructura está en la UE | Protección de datos |
| S7 | Los usuarios tienen 16 años o más | Términos y alta |
| S8 | Se publican 300 variantes por plantilla y nivel | Tamaño de los paquetes |
| S9 | No hay publicidad | Privacidad y modelo de ingresos |
| S10 | No hay mascota; la marca se apoya en el menisco | Sistema de diseño |
| S11 | El contenido se elabora a partir de información pública de los fármacos y lo valida un profesional por sector | Flujo de revisión |
| S12 | Las ligas agrupan por sector y usan alias | Reglas de liga |

### 14.3 Preguntas abiertas

1. ¿Qué dos sectores abren el MVP y quién valida su contenido?
2. ¿Hay una universidad, un hospital o un colegio profesional dispuesto a ser piloto y a respaldar la publicación en la tienda de Apple?
3. ¿Se vende primero a particulares, a organizaciones o a ambos?
4. ¿Qué notación se usa por defecto para los microgramos: µg, mcg o la palabra completa?
5. ¿Edad mínima de 16 o de 18 años?
6. ¿Qué idiomas siguen al español?
7. ¿Se quiere emitir certificados o créditos de formación? Cambia la evaluación y el análisis normativo.
8. ¿Hay presupuesto para una voz de síntesis propia si las del sistema no dan la calidad esperada?

## Fuentes

Consultadas en noviembre de 2026.

- Flutter: [novedades de versiones](https://docs.flutter.dev/release/whats-new.html) y [calendario de publicaciones](https://docs.flutter.dev/install/archive)
- React Native: [versión 0.84](https://reactnative.dev/blog/2026/02/11/react-native-0.84) y [versión 0.88](https://www.gitclear.com/open_repos/facebook/react-native/release/v0.88.0)
- Compose Multiplatform: [versión 1.8.0, estable en iOS](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released-compose-multiplatform-for-ios-is-stable-and-production-ready/) y [novedades de la 1.11](https://kotlinlang.org/docs/multiplatform/whats-new-compose-111.html)
- Apple: [análisis de SpeechAnalyzer](https://blog.addpipe.com/apple-speechanalyzer-api/) y [normas de revisión de la App Store](https://developer.apple.com/app-store/review/guidelines/)
- Android: [reconocedor en el dispositivo, API 31](https://developer.android.com/sdk/api_diff/31/changes/android.speech.SpeechRecognizer) y [API de reconocimiento de ML Kit](https://developers.google.com/ml-kit/genai/speech-recognition/android)
- Reconocimiento embebido: [sherpa-onnx para Flutter](https://pub.dev/documentation/sherpa_onnx/), [modelos de Vosk](https://alphacephei.com/vosk/models) y [Whisper small ajustado a español](https://huggingface.co/danielizham/whisper-small-es)
- Síntesis embebida: [voces de Piper y sus licencias](https://tts.ai/voices/piper/?lang=es)
- Repaso espaciado: [paquete fsrs para Dart](https://pub.dev/packages/fsrs)
- Sincronización: [PowerSync con Supabase](https://docs.powersync.com/integration-guides/supabase-+-powersync)
- Regulación: [MDCG 2019-11 rev.1, Comisión Europea](https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en) y [resumen de OpenRegulatory](https://openregulatory.com/mdcg/mdcg-2019-11)
- Google Play: [declaración de apps de salud](https://support.google.com/googleplay/android-developer/answer/14738291) y [política de funciones médicas](https://support.google.com/googleplay/android-developer/answer/16555673)
- Diseño: [skill UI/UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill)
