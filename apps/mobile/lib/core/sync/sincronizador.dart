import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const textoErrorSync = 'No se ha podido sincronizar. Lo reintentaremos';

/// Estado de la sincronización para la interfaz (centro de sincronización).
@immutable
class EstadoSync {
  const EstadoSync({this.sincronizando = false, this.pendientes = 0, this.ultima, this.error});
  final bool sincronizando;
  final int pendientes;
  final DateTime? ultima;

  /// «No se ha podido sincronizar. Lo reintentaremos» tras un fallo.
  final String? error;
}

/// Sincronización del progreso (offline-sync, diseños D5 y D6): sube la
/// bandeja de salida por lotes idempotentes y baja lo de otros dispositivos.
/// Interfaz estable; la implementación completa (lotes de 500, reintentos
/// con espera creciente, eventos y consultas sin cuenta, recepción con
/// cursor) la aporta la capacidad de sincronización.
abstract class Sincronizador {
  ValueListenable<EstadoSync> get estado;

  /// Sincroniza ahora (en segundo plano; nunca interrumpe el entrenamiento).
  Future<void> sincronizar();

  /// Tras iniciar sesión en un dispositivo nuevo: baja todo el historial.
  Future<void> recuperarHistorial();
}

class SincronizadorInactivo implements Sincronizador {
  final _estado = ValueNotifier(const EstadoSync());
  @override
  ValueListenable<EstadoSync> get estado => _estado;
  @override
  Future<void> sincronizar() async {}
  @override
  Future<void> recuperarHistorial() async {}
}

final sincronizadorProvider = Provider<Sincronizador>((ref) => SincronizadorInactivo());
