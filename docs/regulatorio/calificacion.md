# Justificación de la calificación regulatoria · borrador

Documento de trabajo exigido por las salvaguardas permanentes de la definición funcional (sección 11.5). **No es asesoramiento jurídico: debe revisarlo y firmarlo un especialista en regulación sanitaria y protección de datos antes del lanzamiento, y revisarse cada año.**

## Finalidad prevista

Formación y entrenamiento de estudiantes y profesionales en el cálculo de dosis y volúmenes con casos simulados. Ni diagnóstico, ni tratamiento, ni apoyo a decisiones sobre pacientes reales.

## Control de cambios regulatorio aplicado en la implementación

| Pregunta del control | Cómo lo garantiza el código | Prueba |
| --- | --- | --- |
| ¿Hay entrada libre de datos de pacientes? | La app no tiene ningún formulario de peso, fármaco o dosis; la única entrada numérica es la respuesta a una variante resuelta | Escenario «No existe entrada libre de datos» (`apps/mobile`, prueba de recorrido de pantallas) |
| ¿La app calcula a partir de lo que escribe el usuario? | El dispositivo no contiene motor de fórmulas (diseño D2): compara con valores verificados en el servidor | Corrección en Dart sobre fixtures; ausencia de evaluador de fórmulas en la app |
| ¿La pauta la propone la app? | La pauta es un dato del enunciado en cada plantilla | Validación de plantillas y revisión experta con la lista de comprobación |
| ¿Algún texto sugiere uso clínico? | `findClinicalUseText` bloquea el envío a revisión de plantillas, preguntas y anuncios con frases como «úsalo en tu guardia»; los anuncios tienen además lista de términos vetados | `packages/engine/test` y `services/api/test` (escenario «Texto con alusión clínica») |
| ¿Se rotulan los casos como simulados? | La validación exige «paciente simulado» cuando el enunciado menciona a una persona; el contenido usa principios activos | Validación de plantillas |
| ¿Se tratan datos de salud o audio? | No: la voz se procesa en memoria en el dispositivo y solo se guarda la respuesta interpretada | Tareas 10.1 y 10.2 (batería en modo avión e inspección de red) |
| ¿La organización puede evaluar a profesionales? | Solo datos agregados por defecto, con umbral de 5 miembros; modo nominal informado y aceptado por cada usuario | `services/api/test` (organizaciones) |

## Funciones que harían entrar el producto en la normativa y que el código no tiene

Modo calculadora, «practica con tus propios datos», comprobador de cálculos reales, tablas de dosis recomendadas enlazadas a un cálculo, integración con historia clínica o bombas, guardado de casos reales y promoción del uso durante la atención.

## Pendiente

- Revisión por especialista en regulación sanitaria (MDR 2017/745, MDCG 2019-11 rev.1) y seguimiento de la reforma propuesta en diciembre de 2025.
- Confirmación del encaje con el Reglamento de inteligencia artificial si una institución usa el producto para evaluar o certificar.
- Revisión de la norma 1.4.2 de Apple y de la declaración de apps de salud de Google Play con las fichas de `docs/tiendas/fichas.md`.
- Validación por un profesional de todo el contenido de demostración, hoy marcado como pendiente.
