# Design

## Context

Los usuarios del back office son farmacólogos, docentes y personal de soporte, sin perfil técnico. El contenido que producen acaba en dispositivos que funcionan sin conexión y que no calculan fórmulas: reciben variantes ya resueltas.

## Goals / Non-Goals

**Goals:**

- Que una plantilla validada produzca cientos de ejercicios correctos sin trabajo adicional.
- Que ningún ejercicio llegue a un usuario sin validación experta y sin doble cálculo.
- Que un error publicado pueda retirarse en minutos.

**Non-Goals:**

- Creador de tipos de ejercicio por bloques (cambio `add-growth-features`).
- Gestión de organizaciones y ligas (cambio `add-growth-features`).
- Edición de contenido desde la app móvil.

## Decisions

### D1. Aplicación a medida en React y TypeScript

Los editores clave (plantillas, revisión, vista previa con voz) son específicos del producto. Un gestor de contenidos genérico obligaría a desarrollarlos igualmente como extensiones.

### D2. Variantes generadas en el servidor al publicar

Cada plantilla genera 300 variantes por nivel de dificultad, con su respuesta, sus pasos y sus respuestas erróneas previsibles. El revisor ve una muestra y los extremos.

- Motivo: el dispositivo no calcula, y lo que se valida es exactamente lo que se entrega.

### D3. Doble cálculo independiente

Las respuestas se recalculan con una segunda implementación, distinta del motor de plantillas. Cualquier discrepancia bloquea la publicación.

### D4. Motor de plantillas como biblioteca compartida

La misma biblioteca de TypeScript alimenta la vista previa del back office y el servicio de publicación. Incluye la comprobación dimensional: cada variable lleva su unidad y la fórmula debe producir la unidad de respuesta declarada.

### D5. Tabla de casos

Las combinaciones de fármaco, pauta, presentación y especie se definen como filas coherentes, no como rangos independientes. Motivo: evita casos farmacológicamente absurdos.

### D6. Separación de funciones

Validar es exclusivo del rol de revisor experto, acreditado por sector, y nadie valida contenido propio. La validación caduca a los 24 meses.

### D7. Publicación gradual y reversible

Paquete firmado por itinerario, despliegue al 5 %, al 50 % y al 100 %, reversión con una acción y lista de retirada independiente de las versiones.

### D8. Vista previa con el mismo normalizador de lectura

El texto hablado de la vista previa se genera con el normalizador de la app, y se muestra escrito junto al audio para detectar lecturas erróneas.

## Risks / Trade-offs

- **Faltan revisores y el contenido se atasca.** Plantillas parametrizadas, importación masiva y red de colaboradores académicos.
- **El editor de plantillas resulta difícil para un usuario no técnico.** Asistente por pasos, comprobación dimensional en vivo, errores habituales con un botón y pruebas con usuarios reales del perfil.
- **Paquetes grandes por el número de variantes.** El número por nivel es configurable.
- **Un error validado llega a producción.** Doble cálculo, muestra de extremos, analítica de variantes anómalas y retirada inmediata.
