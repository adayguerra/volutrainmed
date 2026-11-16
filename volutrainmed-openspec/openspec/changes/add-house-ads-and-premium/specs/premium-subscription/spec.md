# Spec Delta

## Purpose

Define la suscripción Premium: los planes, la prueba gratuita, la compra y los derechos de acceso que eliminan la pausa promocional tras cada ejercicio, incluida su validez sin conexión y lo que ocurre al caducar.

## ADDED Requirements

### Requirement: Planes y prueba gratuita

La app MUST ofrecer un plan mensual y un plan anual de Premium, con una prueba gratuita de 7 días disponible una sola vez por cuenta.

#### Scenario: Inicio de la prueba

- **GIVEN** un usuario que nunca ha tenido Premium
- **WHEN** abre la pantalla de suscripción
- **THEN** la acción principal es «Probar 7 días gratis»

#### Scenario: Prueba ya consumida

- **GIVEN** un usuario que ya disfrutó de la prueba
- **WHEN** abre la pantalla de suscripción
- **THEN** la acción principal es «Suscribirme» y no se ofrece otra prueba

### Requirement: Premium elimina los anuncios

La app MUST dejar de mostrar pausas promocionales en cuanto el usuario tiene Premium activo, incluida la sesión que esté en curso.

#### Scenario: Compra a mitad de lección

- **GIVEN** un usuario sin Premium en el ejercicio 3 de una lección
- **WHEN** completa la compra desde la acción de un anuncio y vuelve a la sesión
- **THEN** no ve pausas promocionales en los ejercicios restantes

#### Scenario: Lección completa con Premium

- **WHEN** un usuario con Premium completa una lección de 10 ejercicios
- **THEN** pasa de cada corrección al ejercicio siguiente sin ninguna pausa

### Requirement: Beneficios adicionales de Premium

La app MUST dar a los usuarios con Premium manos libres sin límite diario, acceso a todos los itinerarios y sectores, y estadísticas avanzadas por habilidad.

#### Scenario: Límite de manos libres en el plan gratuito

- **GIVEN** un usuario sin Premium que ha usado hoy 5 minutos de manos libres
- **WHEN** intenta empezar otra sesión de manos libres
- **THEN** la app le indica que ha alcanzado el límite diario y le ofrece el modo táctil y Premium

#### Scenario: Manos libres con Premium

- **WHEN** un usuario con Premium usa el modo manos libres durante 30 minutos
- **THEN** la sesión continúa sin ningún límite

### Requirement: Compra en la tienda y restauración

La app MUST gestionar la compra mediante la tienda de aplicaciones del dispositivo y permitir restaurar una compra anterior en otro dispositivo de la misma cuenta.

#### Scenario: Restauración en un dispositivo nuevo

- **GIVEN** un usuario con Premium activo que instala la app en otro dispositivo
- **WHEN** inicia sesión o toca «Restaurar compras»
- **THEN** Premium queda activo y no ve pausas promocionales

#### Scenario: Compra cancelada

- **WHEN** el usuario cancela el diálogo de compra de la tienda
- **THEN** vuelve a la pantalla de suscripción sin cargos y sin mensaje de error

#### Scenario: Compra fallida

- **WHEN** la tienda devuelve un error de pago
- **THEN** la app explica que no se ha completado y ofrece reintentar

### Requirement: Validez sin conexión

La app MUST mantener los derechos de Premium durante 30 días sin conexión y, pasado ese plazo sin poder revalidar, volver al plan gratuito con un aviso hasta que se recupere la conexión.

#### Scenario: Dos semanas sin conexión

- **GIVEN** un usuario con Premium validado hace 14 días y sin conexión desde entonces
- **WHEN** hace una lección
- **THEN** no ve pausas promocionales

#### Scenario: Más de treinta días sin conexión

- **GIVEN** un usuario con Premium validado hace 31 días y sin conexión desde entonces
- **WHEN** abre la app
- **THEN** ve el aviso «Conéctate para comprobar tu suscripción» y el plan gratuito hasta revalidar

### Requirement: Caducidad y cancelación

La app MUST conservar Premium hasta el final del periodo pagado tras una cancelación y, al caducar, volver al plan gratuito mostrando un único aviso.

#### Scenario: Cancelación a mitad de periodo

- **GIVEN** un usuario que cancela su plan mensual 10 días antes de la renovación
- **WHEN** entrena durante esos 10 días
- **THEN** sigue sin ver pausas promocionales

#### Scenario: Suscripción caducada

- **WHEN** termina el periodo pagado sin renovación
- **THEN** la app muestra una vez el aviso «Tu Premium ha terminado» y las pausas promocionales vuelven

### Requirement: Transparencia de la oferta

La pantalla de suscripción MUST mostrar el precio con su periodo, las condiciones de renovación, cómo cancelar y un botón de cierre siempre visible.

#### Scenario: Información antes de comprar

- **WHEN** un usuario abre la pantalla de suscripción
- **THEN** ve el precio de cada plan con su periodo, la fecha del primer cobro si hay prueba y la frase «Cancela cuando quieras desde los ajustes de la tienda»

#### Scenario: Precios no disponibles

- **GIVEN** el dispositivo sin conexión
- **WHEN** un usuario abre la pantalla de suscripción
- **THEN** la app explica que hace falta conexión para comprar y no muestra precios desactualizados

### Requirement: Recordatorio antes del fin de la prueba

La app MUST avisar al usuario, entre 24 y 48 horas antes de que termine su prueba gratuita, de la fecha y el importe del primer cobro.

#### Scenario: Aviso previo al cobro

- **GIVEN** un usuario en el día 5 de su prueba de 7 días
- **WHEN** faltan 48 horas para el primer cobro
- **THEN** recibe una notificación con la fecha y el importe, aunque no tenga conexión

### Requirement: Estado de la suscripción en Perfil

La app MUST mostrar en Perfil el plan actual, la fecha de renovación o de fin, y el acceso para gestionarlo.

#### Scenario: Usuario con plan anual

- **WHEN** un usuario con plan anual abre Perfil
- **THEN** ve «Premium anual», la fecha de renovación y el enlace para gestionar la suscripción en la tienda
