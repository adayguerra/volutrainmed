import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Costuras con la plataforma. Cada servicio del sistema (conexión, voz,
/// vibración, permisos, notificaciones) va detrás de una interfaz propia para
/// que la lógica sea comprobable con dobles de prueba (`falsos.dart`).

// ---------------------------------------------------------------------------
// Conexión
// ---------------------------------------------------------------------------

abstract class Conectividad {
  Future<bool> hayConexion();

  /// La conexión actual es de datos móviles (sin wifi ni cable): con el
  /// ajuste «Descargar solo con wifi» no se bajan paquetes por ella.
  Future<bool> soloDatosMoviles();
  Stream<bool> get cambios;
}

class ConectividadSistema implements Conectividad {
  final _c = Connectivity();

  static bool _conectado(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);

  @override
  Future<bool> hayConexion() async {
    try {
      return _conectado(await _c.checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> soloDatosMoviles() async {
    try {
      final r = await _c.checkConnectivity();
      const fijas = {ConnectivityResult.wifi, ConnectivityResult.ethernet};
      return r.contains(ConnectivityResult.mobile) && !r.any(fijas.contains);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get cambios => _c.onConnectivityChanged.map(_conectado).distinct();
}

// ---------------------------------------------------------------------------
// Síntesis de voz (en el dispositivo, flutter_tts)
// ---------------------------------------------------------------------------

abstract class Sintetizador {
  /// Dice [texto] y termina cuando acaba la locución (o al pararla).
  Future<void> decir(String texto, {double velocidad = 1.0});
  Future<void> parar();
}

/// Voz del sistema en español de España. No usa red: si el motor del sistema
/// necesitara red para es-ES, la app lo indica en los ajustes de voz.
class SintetizadorSistema implements Sintetizador {
  SintetizadorSistema() {
    _tts.setLanguage('es-ES');
    _tts.awaitSpeakCompletion(true);
  }
  final _tts = FlutterTts();

  @override
  Future<void> decir(String texto, {double velocidad = 1.0}) async {
    try {
      // flutter_tts usa 0,5 como velocidad normal en iOS y Android.
      await _tts.setSpeechRate((0.5 * velocidad).clamp(0.1, 1.0));
      await _tts.speak(texto);
    } catch (_) {
      // Sin voz disponible: el texto siempre aparece también en pantalla.
    }
  }

  @override
  Future<void> parar() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Reconocimiento de voz (interfaz `MotorDeVoz`, diseño D3)
// ---------------------------------------------------------------------------

/// Evento del reconocimiento. Solo viaja texto interpretable y métricas; el
/// audio no sale nunca del motor y no se guarda.
sealed class EventoVoz {
  const EventoVoz();
}

class VozTexto extends EventoVoz {
  const VozTexto(this.texto, {this.confianza = 1, this.alternativas = const [], this.ms = 0});
  final String texto;
  final double confianza;
  final List<String> alternativas;
  final int ms;
}

class VozSilencio extends EventoVoz {
  const VozSilencio();
}

class VozRuido extends EventoVoz {
  const VozRuido();
}

class VozBotonAuriculares extends EventoVoz {
  const VozBotonAuriculares();
}

class VozNoEntendida extends EventoVoz {
  const VozNoEntendida();
}

abstract class MotorDeVoz {
  /// El motor embebido está instalado y listo para escuchar sin red.
  bool get disponible;

  /// Motivo por el que no está disponible, para explicarlo en pantalla.
  String? get motivoNoDisponible;

  /// Abre la escucha. Emite un evento por turno; [silencioCorte] marca el
  /// fin de la locución.
  Stream<EventoVoz> escuchar({Duration silencioCorte = const Duration(milliseconds: 900)});
  Future<void> parar();
}

/// Motor embebido pendiente de la prueba técnica (tareas 1.1 y 1.2): hasta
/// elegir sherpa-onnx o Vosk no hay reconocimiento. Nunca se recurre a un
/// reconocimiento en la nube; la sesión manos libres se completa con los
/// botones y el teclado.
class MotorDeVozPendiente implements MotorDeVoz {
  const MotorDeVozPendiente();
  @override
  bool get disponible => false;
  @override
  String? get motivoNoDisponible =>
      'El reconocimiento embebido llegará tras la prueba técnica de voz. Mientras, responde con el teclado o los botones: la lectura sí funciona.';
  @override
  Stream<EventoVoz> escuchar({Duration silencioCorte = const Duration(milliseconds: 900)}) => const Stream.empty();
  @override
  Future<void> parar() async {}
}

// ---------------------------------------------------------------------------
// Señales hápticas y sonoras
// ---------------------------------------------------------------------------

enum Senal { tecla, acierto, fallo, hito, aviso, escucha, pausa }

abstract class Vibrador {
  Future<void> vibrar(Senal s);
}

abstract class Sonido {
  /// Si el dispositivo está en modo silencio.
  Future<bool> modoSilencio();
  Future<void> sonar(Senal s);
}

class VibradorSistema implements Vibrador {
  @override
  Future<void> vibrar(Senal s) async {
    switch (s) {
      case Senal.tecla:
        await HapticFeedback.selectionClick();
      case Senal.acierto:
        await HapticFeedback.lightImpact();
      case Senal.fallo:
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await HapticFeedback.heavyImpact();
      case Senal.hito:
        await HapticFeedback.mediumImpact();
      case Senal.aviso:
      case Senal.escucha:
      case Senal.pausa:
        await HapticFeedback.vibrate();
    }
  }
}

/// Sonidos del sistema: en iOS los sonidos del sistema ya respetan el
/// interruptor de silencio; en Android se usa el sonido de clic del sistema,
/// que sigue el perfil de sonido.
class SonidoSistema implements Sonido {
  @override
  Future<bool> modoSilencio() async => false;
  @override
  Future<void> sonar(Senal s) => SystemSound.play(s == Senal.tecla ? SystemSoundType.click : SystemSoundType.alert);
}

/// Combina vibración y sonido según los ajustes y el modo silencio.
class Senales {
  Senales({required this.vibrador, required this.sonido, required this.hapticaActiva, required this.sonidosActivos});
  final Vibrador vibrador;
  final Sonido sonido;
  final bool Function() hapticaActiva;
  final bool Function() sonidosActivos;

  Future<void> emitir(Senal s) async {
    if (hapticaActiva()) await vibrador.vibrar(s);
    if (s != Senal.tecla && sonidosActivos() && !await sonido.modoSilencio()) await sonido.sonar(s);
  }
}

// ---------------------------------------------------------------------------
// Permisos
// ---------------------------------------------------------------------------

enum EstadoPermiso { concedido, denegado, denegadoPermanente, noPedido }

abstract class Permisos {
  Future<EstadoPermiso> estadoMicrofono();
  Future<EstadoPermiso> pedirMicrofono();
  Future<EstadoPermiso> estadoNotificaciones();
  Future<EstadoPermiso> pedirNotificaciones();
  Future<void> abrirAjustes();

  /// Número de solicitudes hechas al sistema (para comprobar que no se pide
  /// nada antes de la primera lección).
  int get solicitudes;
}

class PermisosSistema implements Permisos {
  int _n = 0;
  @override
  int get solicitudes => _n;

  static EstadoPermiso _de(ph.PermissionStatus s) => switch (s) {
        ph.PermissionStatus.granted || ph.PermissionStatus.limited || ph.PermissionStatus.provisional => EstadoPermiso.concedido,
        ph.PermissionStatus.permanentlyDenied || ph.PermissionStatus.restricted => EstadoPermiso.denegadoPermanente,
        ph.PermissionStatus.denied => EstadoPermiso.denegado,
      };

  Future<EstadoPermiso> _estado(ph.Permission p) async {
    if (kIsWeb) return EstadoPermiso.noPedido;
    try {
      return _de(await p.status);
    } catch (_) {
      return EstadoPermiso.noPedido;
    }
  }

  Future<EstadoPermiso> _pedir(ph.Permission p) async {
    _n++;
    if (kIsWeb) return EstadoPermiso.denegado;
    try {
      return _de(await p.request());
    } catch (_) {
      return EstadoPermiso.denegado;
    }
  }

  @override
  Future<EstadoPermiso> estadoMicrofono() => _estado(ph.Permission.microphone);
  @override
  Future<EstadoPermiso> pedirMicrofono() => _pedir(ph.Permission.microphone);
  @override
  Future<EstadoPermiso> estadoNotificaciones() => _estado(ph.Permission.notification);
  @override
  Future<EstadoPermiso> pedirNotificaciones() => _pedir(ph.Permission.notification);
  @override
  Future<void> abrirAjustes() async {
    try {
      await ph.openAppSettings();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Notificaciones locales (recordatorio de repaso y aviso de fin de prueba)
// ---------------------------------------------------------------------------

class NotificacionProgramada {
  const NotificacionProgramada({required this.id, required this.cuando, required this.titulo, required this.texto, this.diaria = false});

  /// Se repite cada día a la misma hora (recordatorio de repaso).
  final bool diaria;
  final int id;
  final DateTime cuando;
  final String titulo;
  final String texto;
}

abstract class Notificador {
  /// Programa una notificación local: se entrega aunque no haya conexión.
  Future<void> programar(NotificacionProgramada n);
  Future<void> cancelar(int id);
}

/// Implementación mínima en memoria: registra lo programado. La entrega real
/// con flutter_local_notifications se conecta en `main.dart`.
class NotificadorRegistro implements Notificador {
  final programadas = <int, NotificacionProgramada>{};
  @override
  Future<void> programar(NotificacionProgramada n) async => programadas[n.id] = n;
  @override
  Future<void> cancelar(int id) async => programadas.remove(id);
}
