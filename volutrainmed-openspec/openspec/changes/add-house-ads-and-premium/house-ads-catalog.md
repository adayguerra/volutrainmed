# Catálogo de anuncios propios

Serie inicial de doce anuncios que promocionan Premium en la pausa tras cada ejercicio. Es la campaña de lanzamiento; se carga en el back office y viaja en el paquete de contenido.

## Guía de tono

- Se tutea. Frases cortas. Hechos y cifras, no adjetivos.
- La cifra es real: sale de la configuración vigente o de los datos del usuario.
- Nada de culpa, de urgencia falsa ni de signos de exclamación dobles.
- Ninguna alusión a pacientes, guardias, errores clínicos o resultados de salud.
- El anuncio dice qué se gana, no qué se pierde.

Términos vetados en titular, texto y cuña: «paciente», «guardia», «salva», «evita errores», «última oportunidad», «solo hoy», «no te lo pierdas», «te echamos de menos».

## Formato de la tarjeta

| Elemento | Especificación |
| --- | --- |
| Rótulo | «Promoción de VolutrainMed», arriba, en texto secundario de 12 sp |
| Ilustración | Vectorial, sobre el elemento de marca (el menisco). Un solo color de marca más el ámbar de acento. Sin fotografías ni personajes |
| Titular | 44 caracteres como máximo. Figtree 24 sp, peso 600. Las cifras, en la tipografía de cifras |
| Texto | 90 caracteres como máximo. Noto Sans 16 sp |
| Acción del anuncio | Botón primario, 52 dp de alto |
| «Continuar» | Botón secundario bajo la acción, con la cuenta atrás dentro: «Continuar (3)» |
| Ancho | Pantalla completa en móvil; 560 dp como máximo en tablet |
| Cuña | 4 segundos como máximo a velocidad 1,0; unas 12 palabras |

## Variables

| Variable | Valor |
| --- | --- |
| `{espera_s}` | Segundos de espera configurados |
| `{ejercicios}` | Ejercicios de la lección en curso |
| `{total_s}` | `{espera_s}` × `{ejercicios}` |
| `{aciertos}` | Aciertos al primer intento en la lección |
| `{dias}` | Días de la racha actual |
| `{equivalente_mes}` | Precio anual de la tienda ÷ 12, con dos decimales |
| `{ahorro_pct}` | (1 − precio anual ÷ (12 × precio mensual)) × 100, sin decimales |

Con los precios de trabajo (6,99 € al mes y 39,99 € al año): `{equivalente_mes}` = 3,33 y `{ahorro_pct}` = 52.

## Reglas de rotación de la campaña inicial

| Anuncio | Tipo | Peso | Tope diario | Condición |
| --- | --- | --- | --- | --- |
| PA-01 | Genérico y de reserva | 3 | Sin tope | Siempre |
| PA-02 | Genérico | 2 | 4 | Espera mayor que 0, dentro de una lección |
| PA-03 | Genérico | 3 | 6 | Prueba gratuita disponible |
| PA-04 | Contextual | 3 | 3 | Límite diario de manos libres agotado, o tras una sesión de manos libres |
| PA-05 | Contextual | 3 | 2 | Racha de 3 días o más |
| PA-06 | Genérico | 2 | 3 | Precios de la tienda obtenidos en los últimos 7 días |
| PA-07 | Contextual | 2 | 2 | Tras completar una unidad |
| PA-08 | Contextual | 2 | 2 | Última pausa de una lección con algún fallo |
| PA-09 | Genérico | 1 | 2 | Siempre |
| PA-10 | Contextual | 3 | 2 | Última pausa de una lección sin fallos |
| PA-11 | Contextual | 3 | 3 | Pausa única al terminar un contrarreloj |
| PA-12 | Genérico | 1 | 1 | Desde que existan organizaciones (fase 2) |

## Anuncios

### PA-01 · Sin pausas

| Campo | Contenido |
| --- | --- |
| Titular | Entrena sin pausas |
| Texto | Con Premium pasas de un ejercicio al siguiente sin anuncios. |
| Acción | Quitar anuncios |
| Cuña | «Con Premium, entrenas sin estas pausas.» |
| Ilustración | El menisco sube de forma continua por una escala, sin cortes |
| Idea | El beneficio principal, dicho tal cual |

### PA-02 · La cuenta

| Campo | Contenido |
| --- | --- |
| Titular | {espera_s} s × {ejercicios} ejercicios = {total_s} s |
| Texto | Es lo que duran las pausas de esta lección. Con Premium son tiempo de práctica. |
| Acción | Quitar anuncios |
| Cuña | «Estas pausas suman {total_s} segundos por lección. Premium las quita.» |
| Ilustración | La operación escrita como un paso de una explicación, con sus unidades |
| Idea | El anuncio habla el idioma del producto: un cálculo con unidades. Ejemplo: «3 s × 10 ejercicios = 30 s» |

### PA-03 · Siete días

| Campo | Contenido |
| --- | --- |
| Titular | 7 días de Premium, gratis |
| Texto | Sin anuncios y con manos libres sin límite. Cancela cuando quieras. |
| Acción | Probar gratis |
| Cuña | «Prueba Premium siete días gratis, sin anuncios.» |
| Ilustración | Escala con siete divisiones; la primera, llena |
| Idea | Quita el riesgo de probar |

### PA-04 · Manos ocupadas

| Campo | Contenido |
| --- | --- |
| Titular | Sigue con las manos ocupadas |
| Texto | Manos libres sin límite diario. Tu voz se procesa en el dispositivo. |
| Acción | Ver Premium |
| Cuña | «Con Premium, manos libres sin límite diario.» |
| Ilustración | Auriculares con el halo del micrófono |
| Idea | Aparece cuando el usuario acaba de tocar el límite. Depende de la pregunta abierta 1 del diseño |

### PA-05 · Racha

| Campo | Contenido |
| --- | --- |
| Titular | Llevas {dias} días seguidos |
| Texto | Mantén el ritmo sin interrupciones entre ejercicios. |
| Acción | Quitar anuncios |
| Cuña | «Llevas {dias} días seguidos. Con Premium, sin pausas.» |
| Ilustración | Contador de racha sobre el menisco lleno |
| Idea | Reconoce un hecho del usuario antes de proponer nada |

### PA-06 · Plan anual

| Campo | Contenido |
| --- | --- |
| Titular | Premium por {equivalente_mes} € al mes |
| Texto | Con el plan anual pagas un {ahorro_pct} % menos que mes a mes. |
| Acción | Ver planes |
| Cuña | «El plan anual de Premium sale a {equivalente_mes} euros al mes.» |
| Ilustración | Dos barras con su valor: mensual y anual |
| Idea | Una comparación con cifras de la tienda. No se muestra con precios de más de 7 días |

### PA-07 · Todos los itinerarios

| Campo | Contenido |
| --- | --- |
| Titular | Un sector hoy, otro mañana |
| Texto | Premium abre todos los itinerarios: anestesia, urgencias, pediatría, veterinaria. |
| Acción | Ver Premium |
| Cuña | «Premium abre todos los itinerarios.» |
| Ilustración | La ruta de aprendizaje con varios ramales |
| Idea | Tras completar una unidad, enseña que hay más recorrido. Depende de la pregunta abierta 1 |

### PA-08 · Estadísticas

| Campo | Contenido |
| --- | --- |
| Titular | ¿Dónde se te va el tiempo? |
| Texto | Premium muestra tu evolución por habilidad y tus errores más frecuentes. |
| Acción | Ver Premium |
| Cuña | «Premium muestra tus errores más frecuentes por habilidad.» |
| Ilustración | Gráfica de línea ascendente con etiquetas directas |
| Idea | Tras una lección con fallos, ofrece entenderlos. Depende de la pregunta abierta 1 |

### PA-09 · Contenido validado

| Campo | Contenido |
| --- | --- |
| Titular | Cada ejercicio lo revisa un profesional |
| Texto | Tu suscripción financia la validación experta del contenido. |
| Acción | Apoyar con Premium |
| Cuña | «Tu suscripción financia la revisión experta del contenido.» |
| Ilustración | Sello de validación con su marca |
| Idea | Da un motivo distinto del propio beneficio: sostener la calidad |

### PA-10 · Lección perfecta

| Campo | Contenido |
| --- | --- |
| Titular | {aciertos} de {ejercicios} |
| Texto | Buen ritmo. Con Premium, además, sin pausas entre ejercicios. |
| Acción | Probar gratis, o Quitar anuncios si la prueba ya se usó |
| Cuña | «{aciertos} de {ejercicios}. Con Premium, sin pausas.» |
| Ilustración | El menisco lleno, con un brillo breve |
| Idea | Aprovecha el mejor momento de la sesión. Ejemplo: «10 de 10» |

### PA-11 · Contrarreloj

| Campo | Contenido |
| --- | --- |
| Titular | Tu ritmo, sin cortes |
| Texto | En las lecciones, Premium te lleva de un ejercicio al siguiente sin anuncios. |
| Acción | Quitar anuncios |
| Cuña | No aplica: el contrarreloj no tiene modo manos libres en el MVP |
| Ilustración | Barra de tiempo continua |
| Idea | El usuario acaba de trabajar la agilidad; el anuncio la conecta con las lecciones |

### PA-12 · Código de organización

| Campo | Contenido |
| --- | --- |
| Titular | ¿Tu facultad o tu hospital usa VolutrainMed? |
| Texto | Con un código de organización entrenas sin anuncios y sin pagar tú. |
| Acción | Tengo un código |
| Cuña | «Con un código de tu organización, entrenas sin anuncios.» |
| Ilustración | Edificio con una marca de acceso |
| Idea | Abre la vía de las licencias. Se activa cuando existan organizaciones |

## Comprobación antes de publicar una creatividad

- [ ] El titular tiene 44 caracteres o menos y el texto, 90 o menos, también con las variables resueltas en su valor más largo.
- [ ] La cuña dura 4 segundos o menos con la voz por defecto.
- [ ] Toda cifra procede de una variable, no está escrita a mano.
- [ ] No contiene ningún término vetado.
- [ ] La afirmación es cierta hoy: el beneficio existe en el plan Premium vigente.
- [ ] Se ha visto en móvil pequeño, en tablet, en tema oscuro y con el texto al 200 %.
