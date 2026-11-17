# VolutrainMed · app Flutter

Entrenador formativo de cálculo de dosis y volúmenes para iOS, Android y web. Funciona sin conexión con el contenido firmado incluido (Fundamentos, 2026.11.0) y descarga el resto de `services/api`.

## Puesta en marcha

```sh
flutter pub get
flutter run --dart-define=API_BASE=http://localhost:8787   # API local (services/api)
flutter test                                              # pruebas (la de contrato en vivo se omite)
VTM_API_LIVE=1 flutter test test/data/api_contract_live_test.dart test/contenido   # contra la API real
```

Modo demostración para capturas (solo depuración): `--dart-define=VTM_DEMO=1 --dart-define=VTM_RUTA=/progreso --dart-define=VTM_TEMA=oscuro` siembra un perfil local con unos días de práctica. Las capturas están en `docs/capturas/`.

## Arquitectura

- `lib/core/domain`, `lib/features/*/domain`: dominio puro Dart (corrección exacta, formato decimal español, unidades, voz, FSRS, proyecciones desde intentos, contrarreloj, prueba de nivel, anuncios propios, derechos, ligas) y el motor de sesión (`features/session/domain/motor_sesion.dart`).
- `lib/core/data`: Drift (SQLite; en la web, `sqlite3.wasm` y `drift_worker.js`), almacenes y cliente HTTP según `contracts/api.md`.
- `lib/core/contenido`: verificación SHA-256 + Ed25519 con la clave fijada, contenido incluido, actualización reanudable entre sesiones y lista de retirada.
- `lib/core/sync`: bandeja de salida por lotes idempotentes y recepción con cursor.
- `lib/core/plataforma`: costuras con el sistema (conexión, síntesis con flutter_tts, `MotorDeVoz`, vibración y sonido, permisos, notificaciones locales) y sus dobles de prueba.
- `lib/app`: tema (tokens de Stitch y del lienzo de Claude), disposición adaptativa, rutas (go_router) y estado (Riverpod).
- `lib/features/*/ui`: pantallas M01–M61 y T01–T08.

## Límites conocidos

- Reconocimiento de voz: el motor embebido (sherpa-onnx o Vosk) está pendiente de la prueba técnica. La app nunca usa reconocimiento en la nube; mientras tanto, manos libres lee en voz alta y se responde con botones y teclado.
- La compra pasa por la tienda de pruebas de `services/api`; falta la integración con App Store, Google Play y RevenueCat.
- Apple y Google solo funcionan en desarrollo (`dev:<correo>`).
