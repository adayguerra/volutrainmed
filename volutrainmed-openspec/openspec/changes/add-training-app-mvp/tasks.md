# Tasks

## 1. Prueba técnica y cimientos

- [ ] 1.1 Prueba técnica de voz: 500 locuciones numéricas, 20 hablantes, silencio y ruido de 65 dB, seis dispositivos
- [ ] 1.2 Decidir el motor de voz según el criterio de aceptación (97 % en silencio y 92 % con ruido)
- [x] 1.3 Proyecto Flutter con arquitectura por capacidades, temas claro y oscuro y tokens de diseño
- [x] 1.4 Base de datos local: tablas de contenido, de aprendizaje y bandeja de salida
- [ ] 1.5 Integración continua con pruebas de imagen por clase de tamaño

## 2. Contenido y sin conexión

- [x] 2.1 Descarga reanudable de paquetes con verificación de resumen y firma
- [x] 2.2 Cambio atómico de versión de contenido al iniciar la siguiente sesión
- [x] 2.3 Lista de retirada de ejercicios
- [x] 2.4 Sincronizador: envío de intentos por lotes, idempotente y con reintentos
- [x] 2.5 Reconstrucción de proyecciones a partir de intentos en un dispositivo nuevo
- [x] 2.6 Distintivo de conexión, avisos de cambio y centro de sincronización

## 3. Alta y cuenta

- [x] 3.1 Bienvenida, sector, nivel declarado, meta y aviso formativo con aceptación
- [x] 3.2 Prueba de nivel adaptativa y pantalla de resultado
- [x] 3.3 Perfil local y fusión al crear la cuenta
- [ ] 3.4 Acceso con código por correo, Apple y Google
- [x] 3.5 Perfil, exportación de datos y eliminación de cuenta
- [x] 3.6 Formulario de consulta con envío diferido

## 4. Ruta y sesión

- [x] 4.1 Inicio con ruta, estados de nodo y acción «Continuar»
- [x] 4.2 Detalle de unidad con guía rápida
- [x] 4.3 Motor de sesión: precarga de la lección, dificultad adaptativa, pausa y salida
- [x] 4.4 Intérprete genérico de tipos y definición de T1, T2, T3, T6 y T7
- [x] 4.5 Teclado numérico propio y selector de unidad
- [x] 4.6 Reto de unidad y desbloqueo de la unidad siguiente

## 5. Corrección y explicación

- [x] 5.1 Comparador decimal exacto con tolerancias y redondeo
- [x] 5.2 Veredictos, normalización de formato y unidades equivalentes
- [x] 5.3 Diagnóstico por respuestas erróneas previsibles y marca de error crítico
- [x] 5.4 Hoja de corrección con pasos, unidades canceladas y paso del desvío
- [x] 5.5 Segundo intento con otra variante

## 6. Repaso, dominio y contrarreloj

- [x] 6.1 Integración de FSRS y calificación automática
- [x] 6.2 Cola diaria, cuarentena de errores críticos y tope configurable
- [x] 6.3 Proyección de estados de habilidad
- [x] 6.4 Calentamiento de repaso al inicio de la sesión diaria
- [x] 6.5 Esprint de contrarreloj con penalización, validez de la marca y variante sin cuenta atrás

## 7. Manos libres

- [ ] 7.1 Interfaz `MotorDeVoz` e integración del motor elegido
- [x] 7.2 Descarga y verificación del paquete de voz
- [x] 7.3 Normalizador de lectura de cifras y unidades
- [x] 7.4 Analizador de respuestas numéricas, léxico de unidades y léxico de confusiones
- [x] 7.5 Máquina de estados del turno: lectura, escucha, confirmación, veredicto y explicación
- [x] 7.6 Comandos de voz, recuperación de errores, cifra a cifra y caída al teclado
- [x] 7.7 Pantalla de manos libres, zona táctil completa, botones de 72 dp y modo bolsillo
- [x] 7.8 Ajustes de voz y prueba de micrófono

## 8. Gamificación y progreso

- [x] 8.1 Meta diaria o semanal y racha
- [x] 8.2 Puntos, niveles y cinco logros fijos
- [x] 8.3 Pantalla de fin de lección
- [x] 8.4 Progreso y estadísticas por habilidad con resumen en texto y vista en tabla

## 9. Diseño adaptativo y accesibilidad

- [x] 9.1 Navegación por barra inferior y por carril lateral según la clase de tamaño
- [x] 9.2 Disposición de dos paneles en tablet y hoja de borrador
- [x] 9.3 Etiquetas, orden de foco y lectura completa de cantidades
- [x] 9.4 Texto al 200 %, movimiento reducido y alternativas a los gestos

## 10. Pruebas y lanzamiento

- [ ] 10.1 Batería en modo avión: lección, repaso, contrarreloj y manos libres
- [ ] 10.2 Inspección de red del módulo de voz: ningún tráfico
- [ ] 10.3 Conjunto de regresión de voz con las 500 locuciones
- [ ] 10.4 Pruebas en móvil pequeño, móvil grande y tablet, en vertical y horizontal
- [ ] 10.5 Pruebas con lector de pantalla en iOS y Android
- [ ] 10.6 Validación por un profesional de todo el contenido incluido
- [ ] 10.7 Revisión regulatoria y fichas de las tiendas con el posicionamiento formativo
