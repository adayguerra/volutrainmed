import 'dart:async';
import 'dart:collection';

import 'plataforma.dart';

/// Dobles de los servicios de la plataforma para pruebas (y para un modo de
/// demostración sin hardware). Registran lo que se les pide.

class ConectividadFalsa implements Conectividad {
  ConectividadFalsa([this._conectado = true]);
  bool _conectado;
  final _ctrl = StreamController<bool>.broadcast();

  bool get conectado => _conectado;
  set conectado(bool v) {
    if (v == _conectado) return;
    _conectado = v;
    _ctrl.add(v);
  }

  /// Simula una conexión por datos móviles (sin wifi).
  bool datosMoviles = false;

  @override
  Future<bool> soloDatosMoviles() async => _conectado && datosMoviles;

  @override
  Future<bool> hayConexion() async => _conectado;
  @override
  Stream<bool> get cambios => _ctrl.stream;
}

class SintetizadorFalso implements Sintetizador {
  final dichos = <String>[];
  bool parado = false;
  @override
  Future<void> decir(String texto, {double velocidad = 1.0}) async => dichos.add(texto);
  @override
  Future<void> parar() async => parado = true;
}

/// Motor de voz que emite, en cada escucha, el siguiente evento del guion.
class MotorDeVozGuionado implements MotorDeVoz {
  MotorDeVozGuionado([Iterable<EventoVoz> guion = const []]) : guion = Queue.of(guion);
  final Queue<EventoVoz> guion;
  int escuchas = 0;
  @override
  bool get disponible => true;
  @override
  String? get motivoNoDisponible => null;
  @override
  Stream<EventoVoz> escuchar({Duration silencioCorte = const Duration(milliseconds: 900)}) {
    escuchas++;
    if (guion.isEmpty) return const Stream.empty();
    return Stream.value(guion.removeFirst());
  }

  @override
  Future<void> parar() async {}
}

class VibradorFalso implements Vibrador {
  final senales = <Senal>[];
  @override
  Future<void> vibrar(Senal s) async => senales.add(s);
}

class SonidoFalso implements Sonido {
  SonidoFalso({this.silencio = false});
  bool silencio;
  final sonados = <Senal>[];
  @override
  Future<bool> modoSilencio() async => silencio;
  @override
  Future<void> sonar(Senal s) async => sonados.add(s);
}

class PermisosFalsos implements Permisos {
  PermisosFalsos({this.microfono = EstadoPermiso.noPedido, this.notificaciones = EstadoPermiso.noPedido, this.respuestaMicrofono = EstadoPermiso.concedido, this.respuestaNotificaciones = EstadoPermiso.concedido});
  EstadoPermiso microfono;
  EstadoPermiso notificaciones;
  EstadoPermiso respuestaMicrofono;
  EstadoPermiso respuestaNotificaciones;
  int _n = 0;
  int ajustesAbiertos = 0;
  @override
  int get solicitudes => _n;
  @override
  Future<EstadoPermiso> estadoMicrofono() async => microfono;
  @override
  Future<EstadoPermiso> pedirMicrofono() async {
    _n++;
    return microfono = respuestaMicrofono;
  }

  @override
  Future<EstadoPermiso> estadoNotificaciones() async => notificaciones;
  @override
  Future<EstadoPermiso> pedirNotificaciones() async {
    _n++;
    return notificaciones = respuestaNotificaciones;
  }

  @override
  Future<void> abrirAjustes() async => ajustesAbiertos++;
}
