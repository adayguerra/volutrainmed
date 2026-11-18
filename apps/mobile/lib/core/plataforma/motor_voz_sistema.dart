import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'plataforma.dart';

/// Reconocimiento de voz del sistema, **solo en el dispositivo**.
///
/// Garantías (nunca hay reconocimiento en la nube):
/// - iOS: se comprueba `SFSpeechRecognizer(locale: es-ES).supportsOnDeviceRecognition`
///   por un canal propio y se escucha con `onDevice: true`, que en el
///   complemento fija `requiresOnDeviceRecognition = true`.
/// - Android: solo desde Android 12 (API 31) y si
///   `SpeechRecognizer.isOnDeviceRecognitionAvailable` es cierto (y, desde
///   API 33, si es-ES está instalado en el reconocedor local). Con
///   `onDevice: true` el complemento usa entonces
///   `createOnDeviceSpeechRecognizer`. En versiones anteriores el complemento
///   solo «prefiere» sin conexión, así que se considera no disponible.
/// - Web y escritorio: no disponible.
/// Si no se puede garantizar, el motor no escucha y manos libres sigue con el
/// teclado y los botones. No se descarga ningún modelo de terceros y no se
/// guarda audio ni texto.

const localeVoz = 'es_ES';
const etiquetaLocaleVoz = 'es-ES';
const motivoSinReconocimientoLocal =
    'Este dispositivo no puede reconocer la voz en español sin enviarla fuera. Para proteger tu privacidad no usamos reconocimiento en la nube: responde con el teclado o los botones. La lectura en voz alta sí funciona.';
const motivoVozWeb = 'En la web no hay reconocimiento de voz en el dispositivo. Responde con el teclado o los botones.';
const motivoPermisoVoz = 'Falta el permiso de micrófono o de reconocimiento de voz. Actívalo en los ajustes del sistema o responde con el teclado.';

/// Resultado de una escucha, ya sin dependencia del complemento.
class ResultadoReconocido {
  const ResultadoReconocido({required this.texto, required this.esFinal, this.confianza = 1, this.alternativas = const []});
  final String texto;
  final bool esFinal;
  final double confianza;
  final List<String> alternativas;
}

/// Envoltorio fino del reconocedor de la plataforma (para poder probar el
/// motor sin canales nativos).
abstract class ReconocedorPlataforma {
  /// ¿Puede el dispositivo reconocer [etiquetaLocale] íntegramente en local?
  Future<bool> soportaLocal(String etiquetaLocale);

  /// Inicializa el reconocedor (pide los permisos si faltan).
  Future<bool> inicializar({required void Function(String error) alError, required void Function(String estado) alEstado});

  Future<void> escuchar({
    required String locale,
    required bool soloEnDispositivo,
    required Duration pausa,
    required Duration maximo,
    required void Function(ResultadoReconocido r) alResultado,
    required void Function(double nivel) alNivel,
  });

  Future<void> parar();
}

/// Implementación real con `speech_to_text` y un canal propio para la
/// comprobación de reconocimiento local.
class ReconocedorSpeechToText implements ReconocedorPlataforma {
  final _stt = SpeechToText();
  static const _canal = MethodChannel('volutrainmed/voz_local');

  @override
  Future<bool> soportaLocal(String etiquetaLocale) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final r = await _canal.invokeMethod<bool>('soportaReconocimientoLocal', {'locale': etiquetaLocale}).timeout(const Duration(seconds: 4));
      return r == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> inicializar({required void Function(String error) alError, required void Function(String estado) alEstado}) =>
      _stt.initialize(onError: (SpeechRecognitionError e) => alError(e.errorMsg), onStatus: alEstado);

  @override
  Future<void> escuchar({
    required String locale,
    required bool soloEnDispositivo,
    required Duration pausa,
    required Duration maximo,
    required void Function(ResultadoReconocido r) alResultado,
    required void Function(double nivel) alNivel,
  }) =>
      _stt.listen(
        onResult: (SpeechRecognitionResult r) => alResultado(ResultadoReconocido(
          texto: r.recognizedWords,
          esFinal: r.finalResult,
          confianza: r.hasConfidenceRating ? r.confidence : 1,
          alternativas: [for (final a in r.alternates.skip(1)) a.recognizedWords],
        )),
        onSoundLevelChange: alNivel,
        listenOptions: SpeechListenOptions(
          onDevice: soloEnDispositivo,
          localeId: locale,
          // Los parciales solo sirven para saber que ya hay voz; no se muestran ni se guardan.
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          pauseFor: pausa,
          listenFor: maximo,
          autoPunctuation: false,
          enableHapticFeedback: false,
        ),
      );

  @override
  Future<void> parar() => _stt.cancel();
}

/// Umbral de ruido por plataforma: iOS informa en dBFS (≤ 0) y Android en
/// dB RMS (aprox. de −2 a 10).
double umbralRuidoPorDefecto() => defaultTargetPlatform == TargetPlatform.iOS ? -18 : 8.5;

class MotorDeVozSistema implements MotorDeVoz {
  MotorDeVozSistema({
    ReconocedorPlataforma? reconocedor,
    this.esperaSilencio = const Duration(seconds: 6),
    this.ventanaRuido = const Duration(milliseconds: 700),
    this.maximo = const Duration(seconds: 20),
    double? umbralRuido,
    int Function()? relojMs,
  })  : reconocedor = reconocedor ?? ReconocedorSpeechToText(),
        umbralRuido = umbralRuido ?? umbralRuidoPorDefecto(),
        _relojMs = relojMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final ReconocedorPlataforma reconocedor;

  /// Sin voz en este tiempo: «No te he oído. ¿Lo repito?».
  final Duration esperaSilencio;
  final Duration ventanaRuido;
  final Duration maximo;
  final double umbralRuido;
  final int Function() _relojMs;

  bool _soportado = false;
  bool _inicializado = false;
  String? _motivo = motivoSinReconocimientoLocal;
  _Escucha? _actual;

  @override
  bool get disponible => _soportado;
  @override
  String? get motivoNoDisponible => _soportado ? null : _motivo;

  /// Comprueba (sin pedir permisos) si el dispositivo reconoce es-ES en
  /// local. Se llama al arrancar; hasta entonces el motor no está disponible.
  Future<void> preparar() async {
    if (kIsWeb) {
      _soportado = false;
      _motivo = motivoVozWeb;
      return;
    }
    _soportado = await reconocedor.soportaLocal(etiquetaLocaleVoz);
    _motivo = _soportado ? null : motivoSinReconocimientoLocal;
  }

  void _desactivar(String motivo) {
    _soportado = false;
    _motivo = motivo;
  }

  @override
  Stream<EventoVoz> escuchar({Duration silencioCorte = const Duration(milliseconds: 900)}) {
    if (!_soportado) return const Stream.empty();
    final ctrl = StreamController<EventoVoz>();
    final e = _Escucha(ctrl, _relojMs());
    _actual = e;

    void terminar(EventoVoz? ev) {
      if (e.cerrada) return;
      e.cerrada = true;
      e.silencio?.cancel();
      if (ev != null) ctrl.add(ev);
      unawaited(reconocedor.parar().catchError((_) {}));
      unawaited(ctrl.close());
      if (identical(_actual, e)) _actual = null;
    }

    Future<void> abrir() async {
      try {
        // Se vuelve a comprobar justo antes de escuchar: nunca hay nube.
        if (!await reconocedor.soportaLocal(etiquetaLocaleVoz)) {
          _desactivar(motivoSinReconocimientoLocal);
          return terminar(const VozNoEntendida());
        }
        if (!_inicializado) {
          _inicializado = await reconocedor.inicializar(
            alError: (err) => _alError(err),
            alEstado: (s) => _alEstado(s),
          );
          if (!_inicializado) {
            _desactivar(motivoPermisoVoz);
            return terminar(const VozNoEntendida());
          }
        }
        if (e.cerrada) return;
        e.terminar = terminar;
        e.silencio = Timer(esperaSilencio, () {
          if (!e.hayVoz) terminar(const VozSilencio());
        });
        await reconocedor.escuchar(
          locale: localeVoz,
          soloEnDispositivo: true,
          pausa: silencioCorte,
          maximo: maximo,
          alResultado: (r) {
            if (e.cerrada) return;
            if (r.texto.trim().isNotEmpty && !e.hayVoz) {
              e.hayVoz = true;
              e.silencio?.cancel();
            }
            final finVoz = e.ultimaVozMs ?? e.inicioMs;
            if (r.texto.trim().isNotEmpty && !r.esFinal) e.ultimaVozMs = _relojMs();
            if (!r.esFinal) return;
            if (r.texto.trim().isEmpty) return terminar(e.hayVoz ? const VozNoEntendida() : const VozSilencio());
            terminar(VozTexto(
              r.texto.trim(),
              confianza: r.confianza <= 0 ? 1 : r.confianza.clamp(0, 1).toDouble(),
              alternativas: r.alternativas,
              ms: (_relojMs() - finVoz).clamp(0, 60000),
            ));
          },
          alNivel: (nivel) {
            if (e.cerrada || e.hayVoz || e.ruidoEvaluado) return;
            e.niveles.add(nivel);
            if (_relojMs() - e.inicioMs < ventanaRuido.inMilliseconds) return;
            e.ruidoEvaluado = true;
            final media = e.niveles.reduce((a, b) => a + b) / e.niveles.length;
            if (media > umbralRuido) terminar(const VozRuido());
          },
        );
      } catch (_) {
        // P. ej. el sistema rechaza la escucha local: no se reintenta en la nube.
        _desactivar(motivoSinReconocimientoLocal);
        terminar(const VozNoEntendida());
      }
    }

    ctrl.onCancel = () => terminar(null);
    unawaited(abrir());
    return ctrl.stream;
  }

  void _alError(String error) {
    final e = _actual;
    if (e == null || e.cerrada) return;
    final sinVoz = error.contains('no_match') || error.contains('speech_timeout');
    if (error.contains('assets_not_installed') || error.contains('language_not_supported') || error.contains('language_unavailable')) {
      _desactivar(motivoSinReconocimientoLocal);
    }
    if (error.contains('permission') || error.contains('not_authorized')) _desactivar(motivoPermisoVoz);
    e.terminar?.call(sinVoz && !e.hayVoz ? const VozSilencio() : const VozNoEntendida());
  }

  void _alEstado(String estado) {
    final e = _actual;
    if (e == null || e.cerrada || estado != 'done') return;
    // Terminó sin resultado final: se espera un instante por si llega.
    Timer(const Duration(milliseconds: 400), () {
      if (!e.cerrada) e.terminar?.call(e.hayVoz ? const VozNoEntendida() : const VozSilencio());
    });
  }

  @override
  Future<void> parar() async {
    final e = _actual;
    if (e != null && !e.cerrada) {
      e.terminar?.call(null);
      if (!e.cerrada) {
        e.cerrada = true;
        await e.ctrl.close();
      }
    }
    try {
      await reconocedor.parar();
    } catch (_) {}
  }
}

class _Escucha {
  _Escucha(this.ctrl, this.inicioMs);
  final StreamController<EventoVoz> ctrl;
  final int inicioMs;
  bool cerrada = false;
  bool hayVoz = false;
  bool ruidoEvaluado = false;
  int? ultimaVozMs;
  Timer? silencio;
  final niveles = <double>[];
  void Function(EventoVoz?)? terminar;
}
