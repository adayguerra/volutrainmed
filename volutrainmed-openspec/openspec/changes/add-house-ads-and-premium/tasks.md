# Tasks

## 1. Modelo y configuración de campañas

- [ ] 1.1 Definir el esquema de campaña y de creatividad: identificador, titular, texto, acción, ilustración, cuña, contexto, peso, tope diario, vigencia y sector
- [ ] 1.2 Añadir al paquete de contenido la sección de campañas y los parámetros globales: espera, frecuencia táctil y frecuencia en manos libres
- [ ] 1.3 Cargar las doce creatividades de `house-ads-catalog.md` como campaña inicial
- [ ] 1.4 Implementar el resolutor de variables de texto con datos reales (`{espera_s}`, `{ejercicios}`, `{total_s}`, `{dias}`, `{equivalente_mes}`, `{ahorro_pct}`)

## 2. Pausa promocional en la sesión táctil

- [ ] 2.1 Insertar el punto de pausa en el motor de sesión, tras cerrar la corrección y antes del ejercicio siguiente
- [ ] 2.2 Implementar el selector de anuncio: vigencia, sector, tope diario, no repetición, contexto y peso
- [ ] 2.3 Construir la tarjeta de pausa con rótulo, titular, texto, ilustración, acción y «Continuar» con cuenta atrás
- [ ] 2.4 Aplicar las exclusiones: Premium, prueba, prueba de nivel, primera lección y contrarreloj en curso
- [ ] 2.5 Retrasar la pausa hasta después del segundo intento tras un error crítico
- [ ] 2.6 Excluir el tiempo de pausa del tiempo de respuesta, de la meta diaria y de las marcas de contrarreloj
- [ ] 2.7 Adaptar la tarjeta a tablet: 560 dp de ancho máximo en horizontal

## 3. Cuña hablada en manos libres

- [ ] 3.1 Insertar la cuña tras el veredicto hablado, con su frecuencia propia
- [ ] 3.2 Añadir los comandos «siguiente» (salta la cuña) y «más información» (guarda el interés)
- [ ] 3.3 Mostrar en el resumen de la sesión el anuncio por el que se pidió más información
- [ ] 3.4 Comprobar que cada cuña dura 4 segundos como máximo con la voz y la velocidad por defecto

## 4. Suscripción Premium

- [ ] 4.1 Dar de alta los productos mensual y anual y la prueba de 7 días en las dos tiendas
- [ ] 4.2 Integrar el proveedor de suscripciones: compra, restauración y validación de recibos
- [ ] 4.3 Construir la pantalla de suscripción con precios, condiciones y cierre visible
- [ ] 4.4 Guardar los derechos de acceso en local con la fecha de validación y la vigencia de 30 días sin conexión
- [ ] 4.5 Retirar las pausas en la sesión en curso en cuanto se activa Premium
- [ ] 4.6 Implementar la caducidad: aviso único y vuelta al plan gratuito
- [ ] 4.7 Programar la notificación local previa al fin de la prueba
- [ ] 4.8 Mostrar el estado de la suscripción en Perfil
- [ ] 4.9 Aplicar los beneficios adicionales: manos libres sin límite, todos los itinerarios y estadísticas avanzadas

## 5. Back office

- [ ] 5.1 Pantalla de campañas: lista, estado, vigencia, segmento y rendimiento
- [ ] 5.2 Editor de creatividad con vista previa en móvil y tablet y escucha de la cuña
- [ ] 5.3 Comprobaciones automáticas: longitud del texto, duración de la cuña, variables válidas y lista de términos vetados
- [ ] 5.4 Revisión de creatividades antes de publicar, con el ciclo de estados del contenido
- [ ] 5.5 Parámetros globales de espera y frecuencia, con registro de auditoría

## 6. Medición y experimentación

- [ ] 6.1 Emitir `ad_impression`, `ad_continue`, `ad_cta_tapped`, `ad_voice_skipped` y `ad_voice_more_info`, con encolado sin conexión
- [ ] 6.2 Atribuir la compra al último anuncio cuya acción se tocó en la sesión
- [ ] 6.3 Preparar el experimento de frecuencia y de espera, con sus métricas de guarda
- [ ] 6.4 Panel de rendimiento por anuncio: impresiones, toques, pruebas iniciadas y compras

## 7. Pruebas

- [ ] 7.1 Lección completa en modo avión con anuncios e ilustraciones visibles
- [ ] 7.2 Inspección de red: ninguna petición publicitaria ni identificador publicitario
- [ ] 7.3 Lector de pantalla, texto al 200 % y movimiento reducido en la tarjeta de pausa
- [ ] 7.4 Compra, restauración, cancelación, caducidad y 31 días sin conexión
- [ ] 7.5 Sesión de manos libres con cuñas, salto por voz y «más información»
- [ ] 7.6 Revisión de los textos por la guía de tono y por la norma de comunicación sin uso clínico
