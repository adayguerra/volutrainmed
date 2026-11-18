import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/contenido/repositorio_contenido.dart';
import '../core/data/almacenes.dart';
import '../core/data/api_client.dart';
import '../core/domain/reloj.dart';
import '../core/plataforma/plataforma.dart';

/// Todo lo que la app necesita del exterior. `main.dart` crea la versión real
/// (Drift, HTTP, flutter_tts…) y las pruebas una con almacenes en memoria y
/// dobles de prueba (`test/helpers/arnes.dart`).
class Dependencias {
  Dependencias({
    required this.contenido,
    required this.aprendizaje,
    required this.claves,
    required this.api,
    required this.reloj,
    required this.conectividad,
    required this.sintetizador,
    required this.motorVoz,
    required this.vibrador,
    required this.sonido,
    required this.permisos,
    required this.notificador,
    required this.leerActivo,
    int Function()? relojMs,
    Random? azar,
  })  : relojMs = relojMs ?? _cronometro(),
        azar = azar ?? Random();

  final AlmacenContenido contenido;
  final AlmacenAprendizaje aprendizaje;
  final AlmacenClaves claves;
  final ApiClient api;
  final Reloj reloj;
  final Conectividad conectividad;
  final Sintetizador sintetizador;
  final MotorDeVoz motorVoz;
  final Vibrador vibrador;
  final Sonido sonido;
  final Permisos permisos;
  final Notificador notificador;
  final LectorActivos leerActivo;

  /// Reloj monótono en milisegundos para medir tiempos de respuesta.
  final int Function() relojMs;
  final Random azar;

  static int Function() _cronometro() {
    final s = Stopwatch()..start();
    return () => s.elapsedMilliseconds;
  }

  RepositorioContenido get repositorio => RepositorioContenido(almacen: contenido, claves: claves, leerActivo: leerActivo);
}

final dependenciasProvider = Provider<Dependencias>((ref) => throw UnimplementedError('Las dependencias se inyectan en main.dart o en las pruebas'));
