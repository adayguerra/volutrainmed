# Design

## Context

La app funciona sin conexión por norma, procesa la voz en el dispositivo y se dirige a un público sanitario profesional con un tono sobrio. El modelo de ingresos fijado es un plan gratuito con una pausa promocional tras cada ejercicio y una suscripción Premium que la elimina.

Una lección tiene de 8 a 12 ejercicios y dura de 3 a 5 minutos. Una pausa por ejercicio es, por tanto, la intervención más frecuente de toda la interfaz. Con 3 segundos de espera y 10 ejercicios, añade al menos 30 segundos a una lección de 4 minutos: un 12,5 % más. En manos libres, una cuña de 4 segundos sobre turnos de 15 a 20 segundos añade entre un 20 % y un 27 %.

## Goals / Non-Goals

**Goals:**

- Que la pausa sea el motivo principal para suscribirse, sin deteriorar el aprendizaje ni la medida del progreso.
- Que los anuncios funcionen en modo avión y no introduzcan rastreo.
- Que el negocio pueda ajustar creatividades, frecuencia y espera sin publicar una versión de la app.
- Que el tono de los anuncios sea el del resto del producto: hechos, tuteo y ninguna culpa.

**Non-Goals:**

- Redes publicitarias de terceros, anuncios de vídeo, anuncios recompensados o patrocinio de laboratorios.
- Compra por voz dentro del modo manos libres.
- Precios regionales y ofertas temporales.
- Bloquear contenido del itinerario elegido tras un muro de pago.

## Decisions

### D1. Solo anuncios propios, servidos desde el dispositivo

Las creatividades y las campañas viajan en el paquete de contenido firmado. No se integra ningún SDK publicitario.

- Motivo de uso: la app debe funcionar en modo avión, y una red publicitaria no puede servir anuncios sin red. La pausa dejaría de existir justo donde la app más se usa.
- Motivo de privacidad: sin SDK publicitario no hay identificador publicitario, ni consentimiento de rastreo, ni terceros que traten datos.
- Motivo de marca: el producto controla lo que ve un profesional sanitario. Un anuncio ajeno de un fármaco o de un suplemento dañaría la credibilidad del contenido.
- Alternativa descartada: red de terceros con anuncios propios de relleno. Añade las tres desventajas anteriores y un ingreso por impresión bajo en una audiencia pequeña.

### D2. La pausa va después de la corrección, nunca antes

El orden es veredicto, explicación, segundo intento si lo hay, pausa y ejercicio siguiente.

- Motivo de aprendizaje: la corrección inmediata es el mecanismo central del producto. Un anuncio entre la respuesta y su corrección rompería justo el momento en que más se aprende.
- Tras un error crítico, la pausa espera al segundo intento, que es reparador y no debe interrumpirse.

### D3. Tarjeta a pantalla completa con espera configurable

«Continuar» se activa tras una espera de 0 a 5 segundos, de 3 por defecto, con cuenta atrás visible.

- Motivo: la espera es la fricción que justifica la suscripción. Con cuenta atrás visible y sin botones falsos, es una fricción honesta.
- Alternativa descartada: franja incrustada bajo el veredicto, sin espera. Molesta menos, pero apenas da motivo para pagar y compite visualmente con la corrección.
- Alternativa descartada: vídeo de 15 a 30 segundos. Desproporcionado frente a ejercicios de 20 segundos.

### D4. Frecuencia por defecto: cada ejercicio, y configurable

La frecuencia es un parámetro de campaña (1 = cada ejercicio). El valor por defecto es 1, como fija el modelo de negocio.

- Se recomienda contrastarlo pronto con un experimento: frecuencia 1 frente a 2 y 3, y espera de 3 frente a 2 segundos.
- Métrica principal: inicio de prueba de Premium por usuario activo.
- Métricas de guarda: finalización de lección, retención a 7 días, sesiones por semana y precisión al primer intento. Si una variante mejora la conversión y empeora las guardas más de lo acordado, no se adopta.

### D5. Cuña hablada en manos libres, con frecuencia propia

En manos libres la pausa es una frase de 4 segundos como máximo, que se salta con «siguiente». Su frecuencia se configura aparte de la táctil.

- Motivo: no se puede mostrar una tarjeta a quien no mira la pantalla, y una espera muda sería confusa.
- «Más información» no abre la compra por voz: guarda el interés y lo muestra en el resumen final. Comprar exige mirar precio y condiciones.

### D6. Primera lección y prueba de nivel sin pausas

- Motivo: el usuario debe llegar a su primer acierto y a su primera corrección sin fricción. Enseñar la pausa antes de haber mostrado valor aumenta el abandono en el alta.
- La prueba de nivel mide; cualquier interrupción la alarga y sesga los tiempos.

### D7. El tiempo de anuncio queda fuera de toda métrica de aprendizaje

Tiempo de respuesta, tiempo medio, minutos de la meta diaria y marcas de contrarreloj excluyen las pausas.

- Motivo: la meta diaria no puede cumplirse viendo anuncios, y los tiempos objetivo de las plantillas se calibran con tiempos de respuesta reales.

### D8. Anuncios con datos reales y calculados

Los textos admiten variables (`{espera_s}`, `{ejercicios}`, `{total_s}`, `{dias}`, `{equivalente_mes}`, `{ahorro_pct}`) que se resuelven en el dispositivo con la configuración y los datos del usuario.

- Motivo: un producto de cálculo no puede anunciarse con cifras aproximadas. Si cambia la espera, el anuncio «3 s × 10 ejercicios = 30 s» cambia con ella.
- Los anuncios con precio solo se muestran si hay precios de la tienda obtenidos en los últimos 7 días.

### D9. Derechos de acceso evaluados en el dispositivo

El derecho «sin anuncios» se guarda en local con la fecha de la última validación y vale 30 días sin conexión.

- Motivo: quien ha pagado no debe volver a ver anuncios por estar en un sótano de hospital.
- La compra pasa por el proveedor de suscripciones, que valida los recibos en el servidor. Las plazas de organización usarán el mismo derecho cuando llegue `add-growth-features`.

### D10. Elección del anuncio

1. Se descartan los anuncios no vigentes, de otro sector, sobre su tope diario o iguales al anterior.
2. Si hay algún anuncio contextual cuyo contexto se cumple, se elige entre ellos por peso.
3. Si no, se elige entre los genéricos por peso.
4. Si no queda ninguno, se muestra el anuncio de reserva PA-01, que no tiene tope.

## Risks / Trade-offs

- **La pausa tras cada ejercicio rompe el flujo y reduce la retención.** Es el riesgo principal del modelo. Mitigación: primera lección sin pausas, espera corta, experimento de frecuencia con métricas de guarda (D4).
- **En manos libres la cuña repetida cansa antes que la tarjeta.** Mitigación: frecuencia propia, cuñas de 4 segundos y salto por voz. Es el primer sitio donde bajar la frecuencia si las guardas empeoran.
- **Doce anuncios se agotan pronto con diez impresiones por lección.** Mitigación: topes diarios, variables que cambian el texto y renovación de campañas desde el back office.
- **El tono promocional choca con el público profesional.** Mitigación: guía de tono del catálogo y revisión de cada creatividad antes de publicar.
- **Un anuncio con una cifra desfasada sería publicidad engañosa.** Mitigación: variables calculadas y caducidad de precios (D8).
- **Revisión de las tiendas.** Los anuncios propios que llevan a una compra dentro de la app son un patrón admitido. Los precios y las condiciones deben verse en la pantalla de suscripción, no solo en el anuncio.

## Open Questions

1. ¿Premium es solo «sin anuncios» o incluye también manos libres sin límite, todos los itinerarios y estadísticas avanzadas? La especificación asume lo segundo; los anuncios PA-04, PA-07 y PA-08 dependen de ello.
2. ¿Precios? Hipótesis de trabajo: 6,99 € al mes y 39,99 € al año.
3. ¿Se mantiene la frecuencia 1 en manos libres o se parte de una frecuencia menor?
4. ¿Se confirma la exención de la primera lección?
5. ¿Las plazas de organización eliminan siempre los anuncios, o hay organizaciones con plan gratuito?
