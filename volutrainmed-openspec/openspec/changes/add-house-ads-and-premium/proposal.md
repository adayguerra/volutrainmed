# Proposal

## Why

El producto necesita un modelo de ingresos que no cierre el contenido a quien no paga. La decisión de negocio es un plan gratuito completo con una pausa promocional tras cada ejercicio y una suscripción Premium que la elimina.

Los anuncios son propios de la app y promocionan Premium. Una red publicitaria de terceros no es viable aquí: exige conexión, y la app funciona sin ella por norma; añade rastreo, incompatible con la postura de privacidad; y expone a un público sanitario a anuncios que el producto no controla.

Fase 1. Depende de `add-training-app-mvp` (la pausa se engancha a la sesión de ejercicios) y de `add-content-backoffice` (las campañas se gestionan y se publican desde el back office).

## What Changes

- Se añade una **pausa promocional** tras cada ejercicio para los usuarios sin Premium: una tarjeta con un anuncio propio, después de la corrección y antes del ejercicio siguiente.
- La pausa nunca aparece antes ni encima de la corrección, espera al segundo intento tras un error crítico y su tiempo no cuenta en ninguna métrica de aprendizaje.
- Los anuncios viajan en el paquete de contenido y se muestran en modo avión. No se integra ningún SDK publicitario ni se usa identificador publicitario.
- Se añade una **serie de doce anuncios propios** (`house-ads-catalog.md`), con rotación, activación por contexto y versión hablada para el modo manos libres.
- Se añade la **suscripción Premium**: planes mensual y anual, prueba de 7 días, compra en la tienda, restauración y validez sin conexión. El acceso por plaza de organización llega con `add-growth-features`.
- Las campañas (creatividades, pesos, fechas, segmentos, espera y frecuencia) se configuran desde el back office sin publicar una versión de la app.

## Capabilities

### New Capabilities

- `house-ads`: pausa promocional con anuncios propios tras cada ejercicio, sus reglas de colocación, rotación, exclusiones, accesibilidad y medición.
- `premium-subscription`: planes, prueba, compra, derechos de acceso, validez sin conexión y caducidad de la suscripción que elimina los anuncios.

### Modified Capabilities

Ninguna. Las capacidades de `add-training-app-mvp` no cambian sus requisitos: la sesión ya excluye del tiempo de respuesta todo lo que ocurre entre ejercicios.

## Impact

- **App**: nueva pantalla intermedia entre ejercicios, pantalla de suscripción, estado de suscripción en Perfil y comando de voz para saltar la cuña.
- **Contenido**: el paquete de contenido incorpora campañas y creatividades. Tamaño estimado inferior a 1 MB.
- **Back office**: gestión de campañas y revisión de creatividades antes de publicar.
- **Dependencias**: proveedor de suscripciones para las compras en las tiendas. Ninguna dependencia publicitaria.
- **Métricas**: eventos de impresión, espera, toque y conversión; métricas de guarda sobre finalización de lección y retención.
- **Control de cambios regulatorio**: el cambio no añade cálculo libre ni datos de pacientes. Los textos de los anuncios pasan la misma norma que el resto de la comunicación: ninguna alusión al uso con pacientes reales.
- **Definición funcional**: sustituye el supuesto S9 («no hay publicidad») y actualiza el modelo de la pantalla de suscripción.
