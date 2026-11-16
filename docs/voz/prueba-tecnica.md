# Prueba técnica de voz (tareas 1.1, 1.2 y 10.3 del MVP)

Objetivo: decidir el motor de reconocimiento embebido (sherpa-onnx con modelo Zipformer de español en flujo continuo, o Vosk con vocabulario restringido como plan B) con un criterio medible antes de integrarlo en la app.

## Estado

| Parte | Estado |
| --- | --- |
| Corpus de 500 respuestas numéricas (capa de texto) | Hecho: `contracts/fixtures/voice-regression-500.json`, generado con `packages/engine/scripts/voice-corpus.ts` |
| Gramática y analizador de cifras habladas | Hecho y verificado: el analizador TypeScript interpreta las 500 al primer intento (`packages/engine/test/engine.test.ts`); la app Dart pasa las mismas fixtures de voz |
| Interfaz `MotorDeVoz` intercambiable en la app | Hecho (ver `apps/mobile/README.md`) |
| Grabaciones de 20 hablantes en silencio y con 65 dB en seis dispositivos | **Pendiente: requiere personas y dispositivos físicos** |
| Medida de acierto por motor y decisión (tarea 1.2) | **Pendiente de las grabaciones** |
| Licencias del modelo y de la voz embebida | **Pendiente de revisión jurídica** |

## Protocolo

1. **Hablantes.** 20 personas con acentos distintos de España (al menos: centro, Andalucía, Canarias, Cataluña, Galicia, País Vasco, Murcia y Comunidad Valenciana), 10 mujeres y 10 hombres, de 20 a 65 años.
2. **Guion.** Cada hablante lee 25 locuciones del corpus (500 en total), repartidas por categoría en la misma proporción que el corpus: enteros, decimales con «coma», «con» y «punto», decimales cifra a cifra, coma inicial, fracciones, cifras con unidad, cifra a cifra y frases con palabras que el reconocedor confunde.
3. **Condiciones.** Dos tomas por locución: silencio (sala con menos de 35 dB) y ruido de 65 dB (ruido de planta hospitalaria grabado, reproducido a 1 m y medido con sonómetro calibrado).
4. **Dispositivos.** Seis: iPhone de gama media y alta, iPad, Android de 3 GB de memoria (mínimo admitido), Android de 4 GB (referencia) y una tablet Android. Micrófono integrado y, en una submuestra, auriculares con micrófono.
5. **Procedimiento.** La app de pruebas reproduce el ejercicio, abre la escucha y registra solo la cifra interpretada, la confianza y la latencia (sin guardar audio, igual que en producción). Las grabaciones de referencia para reproducir la prueba se guardan aparte, con consentimiento informado, cifradas y fuera del producto.
6. **Métricas.** Respuestas bien interpretadas al primer intento (cifra y unidad), por condición, dispositivo, acento y categoría; latencia desde el fin del silencio de corte hasta la cifra en pantalla (objetivo 400 ms, límite 800 ms en el dispositivo de referencia).

## Criterio de aceptación

- 97 % de respuestas bien interpretadas al primer intento en silencio.
- 92 % con ruido de 65 dB.
- Latencia máxima de 800 ms en el dispositivo de referencia de 4 GB.

Si sherpa-onnx no alcanza el criterio y Vosk con vocabulario restringido sí, se elige Vosk (decisión D3). Si ninguno lo alcanza, se mantiene la confirmación obligatoria, el modo cifra a cifra por defecto y la caída al teclado, y se repite la prueba con el modelo ajustado.

## Regresión en cada versión (tarea 10.3)

- Capa de texto: la prueba automática del motor y de la app sobre las 500 locuciones.
- Capa acústica: reproducción automática de las grabaciones de referencia en el dispositivo de referencia, con el mismo criterio, en cada versión que cambie el motor, el modelo o la gramática.
- Inspección de red del módulo de voz (tarea 10.2): ninguna petición durante una sesión manos libres con conexión.
