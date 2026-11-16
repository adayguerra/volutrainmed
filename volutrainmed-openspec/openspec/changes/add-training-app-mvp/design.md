# Design

## Context

Producto nuevo, sin código previo. Los condicionantes vienen de los requisitos irrenunciables: una sola base de código para iOS y Android con diseño adaptativo en tablet; voz procesada íntegramente en el dispositivo y operativa en modo avión; funcionamiento sin conexión como norma; y contenido que cambia sin publicar versiones de la app.

El detalle de pantallas, sistema de diseño y comparativa de tecnologías está en la definición funcional del producto. Aquí se recogen las decisiones que condicionan la implementación.

## Goals / Non-Goals

**Goals:**

- Que una lección completa pueda hacerse en modo avión, táctil o por voz.
- Que ninguna cifra llegue al usuario sin haber sido generada y verificada en el servidor.
- Que el progreso sea correcto con varios dispositivos y periodos largos sin conexión.
- Que la interfaz sea accesible y aproveche la tablet con paneles propios.

**Non-Goals:**

- Ligas, organizaciones y creador de tipos de ejercicio (cambio `add-growth-features`).
- Tipos de ejercicio T4, T5, T8, T9 y T10.
- Idiomas distintos del español de España.
- Contrarreloj por voz.
- Cualquier función de cálculo sobre datos introducidos por el usuario.

## Decisions

### D1. Flutter como framework

Dibuja igual en iOS y Android, lo que reduce la matriz de pruebas de una interfaz muy a medida, y tiene enlace oficial con el motor de voz elegido.

- Alternativas: React Native con Expo (comparte TypeScript con el back office; segunda opción si el equipo es de React) y Kotlin Multiplatform con Compose (más joven en iOS).

### D2. El dispositivo no calcula fórmulas

Cada variante llega en el paquete con su respuesta canónica, sus pasos resueltos y sus respuestas erróneas previsibles. El dispositivo compara.

- Motivo de seguridad: toda cifra ha pasado por el doble cálculo y por la muestra del revisor.
- Motivo técnico: un único motor de fórmulas, en el servidor.
- Coste: paquetes de 10 a 20 MB por itinerario (estimación por medir).

### D3. Reconocimiento de voz con modelo embebido

Motor sherpa-onnx con un modelo de español en flujo continuo, detrás de una interfaz propia `MotorDeVoz`.

- Motivo: es la única vía que garantiza el mismo comportamiento sin red en todos los dispositivos admitidos. Los motores del sistema dependen del dispositivo y del paquete de idioma instalado.
- El vocabulario es cerrado (unas 150 palabras) y hay confirmación hablada; la tasa de error en dictado abierto no es la métrica relevante.
- Plan B: Vosk con vocabulario restringido, si la prueba técnica da mejor acierto con cifras.
- Criterio de aceptación de la prueba técnica: 97 % de respuestas bien interpretadas al primer intento en silencio y 92 % con ruido de 65 dB.

### D4. Síntesis con la voz del sistema y respaldo embebido

Se usa la voz de español del sistema si no requiere red; si no existe, se descarga una voz embebida con licencia comercial. El texto que se dice lo genera un normalizador propio, de modo que cifras y unidades se leen igual con cualquier voz.

### D5. El intento como fuente de verdad

Los intentos solo se añaden. Fichas de repaso, estados de habilidad, rachas y progreso son proyecciones recalculadas a partir de ellos. Dos dispositivos sin conexión se fusionan sumando conjuntos de intentos, sin conflictos. Los identificadores son UUID versión 7 creados en el dispositivo.

### D6. SQLite con Drift y sincronización propia

Bandeja de salida con envío por lotes e idempotente. Alternativa: PowerSync, si el equipo prefiere comprar la sincronización.

### D7. Repaso espaciado con FSRS

Biblioteca `fsrs` para Dart, ejecutada en el dispositivo, con retención objetivo del 90 %. La calificación se deduce de la respuesta: acierto, uso de pistas y tiempo frente al objetivo.

### D8. Contenido en paquetes firmados

Paquete por itinerario con manifiesto, resumen SHA-256 y firma. Descarga reanudable, verificación y cambio atómico al empezar la siguiente sesión. Lista de retirada para ejercicios con errores.

### D9. Intérprete genérico de tipos de ejercicio

Los cinco tipos del MVP se definen como datos (pasos y bloques) y los dibuja un intérprete genérico. Así el creador de tipos de la fase 2 no exige rehacer la sesión.

### D10. Supabase en la UE

Postgres gestionado, autenticación y almacenamiento en región de la UE. Alternativas: Firebase (base documental) y backend a medida (más operación).

### D11. Requisitos mínimos

iOS y iPadOS 16; Android 9 con ARM de 64 bits; 3 GB de memoria para manos libres (4 GB recomendados). Paquete de voz de 80 a 220 MB, descargado bajo demanda.

## Risks / Trade-offs

- **Reconocimiento de cifras insuficiente con ruido o acentos.** Prueba técnica previa, confirmación, modo cifra a cifra, teclado y motor intercambiable.
- **Rechazo en la tienda de Apple por la norma de calculadoras de dosis.** Posicionamiento formativo, notas al revisor y respaldo institucional.
- **Tamaño del paquete de voz.** Descarga bajo demanda y por wifi; modelo ligero como alternativa.
- **Fragmentación de Android en memoria y audio.** Requisitos mínimos, lista de dispositivos de prueba y paso al modo táctil.
- **Licencias de modelos y voces.** Revisión antes de integrar.
- **Paquetes de contenido grandes.** Medir pronto y ajustar el número de variantes por nivel.
