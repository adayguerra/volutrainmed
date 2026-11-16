# Spec Delta

## Purpose

Define las organizaciones cliente (universidades, hospitales y clínicas): plazas, formas de acceso, grupos, informes y, sobre todo, qué puede ver la organización del rendimiento de sus miembros.

## ADDED Requirements

### Requirement: Organizaciones con plazas

El back office MUST permitir dar de alta una organización con un número de plazas y una vigencia, y no admitir más miembros que plazas contratadas.

#### Scenario: Plazas agotadas

- **GIVEN** una organización con 50 plazas ocupadas de 50
- **WHEN** otro usuario intenta unirse
- **THEN** no se une y la organización recibe el aviso de plazas agotadas

#### Scenario: Vigencia terminada

- **WHEN** termina la vigencia de la organización sin renovación
- **THEN** sus miembros conservan su progreso y pasan al plan gratuito

### Requirement: Acceso por código o por dominio de correo

Un usuario MUST poder unirse a una organización con un código de invitación o con una cuenta cuyo correo pertenece a un dominio autorizado.

#### Scenario: Código de invitación

- **WHEN** un usuario introduce un código válido en su perfil
- **THEN** queda vinculado a la organización y, si procede, a su grupo

#### Scenario: Dominio autorizado

- **WHEN** un usuario se registra con un correo de un dominio autorizado por una organización con plazas libres
- **THEN** la app le ofrece unirse a ella

### Requirement: Datos agregados por defecto

Por defecto, una organización MUST ver únicamente datos agregados de sus grupos, sin resultados individuales.

#### Scenario: Informe de grupo

- **WHEN** un administrador de organización abre el informe de un grupo
- **THEN** ve la finalización, la precisión media y las habilidades dominadas del grupo, sin nombres

#### Scenario: Grupo pequeño

- **WHEN** un grupo tiene menos de 5 miembros activos
- **THEN** el informe no muestra datos agregados, para que no puedan atribuirse a personas concretas

### Requirement: Modo nominal informado

Una organización MUST poder ver datos individuales solo con el modo nominal activado, y la app MUST informar de ello a cada usuario antes de que se una.

#### Scenario: Unión a una organización en modo nominal

- **WHEN** un usuario va a unirse a una organización con modo nominal
- **THEN** la app le muestra qué datos verá la organización y le pide aceptación antes de unirse

#### Scenario: Qué ve la organización

- **WHEN** un usuario abre el apartado Organización de su perfil
- **THEN** ve en todo momento qué datos suyos son visibles para la organización

### Requirement: Grupos e itinerarios asignados

Un administrador de organización MUST poder crear grupos, invitar miembros de forma masiva y asignar itinerarios a cada grupo.

#### Scenario: Invitación masiva

- **WHEN** el administrador sube un archivo con 120 correos, 3 de ellos mal escritos
- **THEN** se envían 117 invitaciones y se listan las 3 filas con error

#### Scenario: Itinerario asignado

- **WHEN** el administrador asigna un itinerario a un grupo
- **THEN** los miembros del grupo lo ven destacado en su app

### Requirement: Ligas privadas

Una organización MUST poder crear ligas privadas entre sus miembros, que participan con alias y de forma voluntaria.

#### Scenario: Liga de una promoción

- **WHEN** el administrador crea una liga privada para un grupo
- **THEN** los miembros que aceptan participar ven una clasificación solo con alias de su grupo

### Requirement: Las plazas de organización eliminan los anuncios

Un usuario con plaza activa en una organización MUST tener los derechos de Premium, incluida la ausencia de pausas promocionales.

#### Scenario: Miembro de una organización

- **WHEN** un usuario con plaza activa completa una lección
- **THEN** no ve ninguna pausa promocional

#### Scenario: Miembro sin conexión

- **GIVEN** un usuario con plaza validada hace 10 días y sin conexión desde entonces
- **WHEN** completa una lección
- **THEN** sigue sin ver pausas promocionales
