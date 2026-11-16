# Proposal

## Why

El cálculo de dosis y volúmenes se aprende una vez y después se oxida: se practica poco, bajo presión y sin corrección inmediata. Los fallos habituales (un factor de diez, una unidad cambiada, minutos por horas) son de automatismo, no de conocimiento.

VolutrainMed los entrena con sesiones de 3 a 5 minutos, corrección paso a paso, repaso espaciado de los errores y un modo manos libres que funciona sin nube. Este cambio define la app de entrenamiento del producto mínimo viable.

Fase 1. Es la base de la que dependen `add-house-ads-and-premium`, `add-content-backoffice` y `add-growth-features`.

## What Changes

- App para iOS y Android, móvil y tablet, con una sola base de código y diseño adaptativo.
- Alta en cuatro pasos, prueba de nivel opcional y registro después de la primera lección.
- Ruta de aprendizaje por sector, itinerario, unidad y lección, con dominio medido por habilidad.
- Sesión de ejercicios con teclado numérico propio y cinco tipos de ejercicio: respuesta numérica, selección única, ordenar pasos, estimación rápida y conversión relámpago.
- Corrección con aritmética decimal exacta, tres veredictos, diagnóstico del tipo de error y explicación paso a paso.
- Repaso espaciado de errores y contrarreloj con regla de precisión.
- Modo manos libres con lectura y reconocimiento de voz íntegramente en el dispositivo.
- Funcionamiento completo sin conexión, con sincronización posterior y contenido en paquetes firmados.
- Metas, rachas, puntos, niveles, cinco logros fijos y estadísticas por habilidad.
- Límite formativo: ninguna función de calculadora clínica.

## Capabilities

### New Capabilities

- `formative-boundary`: reglas que mantienen el producto como entrenador formativo y fuera del uso clínico.
- `onboarding-account`: alta, prueba de nivel, cuenta, perfil, gestión de datos personales y formulario de consulta.
- `learning-path`: estructura del contenido, ruta, secuencia de lecciones, reto de unidad y estados de dominio por habilidad.
- `exercise-session`: sesión de ejercicios en modo táctil, tipos de ejercicio del MVP, teclado propio y medida del tiempo.
- `answer-grading`: corrección numérica, redondeo, unidades, diagnóstico del error y explicación paso a paso.
- `spaced-review`: repaso espaciado de los errores, con su programación y su cola diaria.
- `time-trial`: contrarreloj orientado a la agilidad, con regla de precisión.
- `hands-free-voice`: sesión manos libres con síntesis y reconocimiento de voz en el dispositivo.
- `offline-sync`: funcionamiento sin conexión, sincronización de intentos y distribución de contenido.
- `gamification-progress`: metas, rachas, puntos, niveles, logros fijos, fin de lección y estadísticas.
- `adaptive-accessible-ui`: disposición por clase de tamaño en móvil y tablet, y requisitos de accesibilidad.

### Modified Capabilities

Ninguna. Es el primer cambio del producto.

## Impact

- **Código**: aplicación Flutter nueva, base de datos local, sincronizador, módulo de voz y motor de sesión.
- **API**: envío de intentos por lotes, manifiesto de contenido, autenticación y consultas.
- **Dependencias**: motor de voz embebido y su modelo de español, biblioteca de repaso espaciado, proveedor de autenticación.
- **Contenido**: exige al menos el itinerario de Fundamentos y dos itinerarios de sector validados por un profesional.
- **Control de cambios regulatorio**: el cambio fija por requisito que no hay entrada libre de datos de pacientes, que la pauta viene dada en el enunciado y que la comunicación no sugiere uso clínico.
- **Riesgo técnico principal**: fiabilidad del reconocimiento de cifras en español con ruido. Se resuelve con una prueba técnica previa (500 locuciones, seis dispositivos).
