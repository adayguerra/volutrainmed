import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de la actualización de contenido para la interfaz (centro de
/// sincronización, descarga del alta, avisos).
@immutable
class EstadoActualizacion {
  const EstadoActualizacion({
    this.comprobando = false,
    this.descargando,
    this.recibidos = 0,
    this.total = 0,
    this.preparada,
    this.error,
    this.avisoAppAntigua,
    this.ultimaComprobacion,
  });

  final bool comprobando;

  /// Clave lógica (`global` o itinerario) que se está descargando.
  final String? descargando;
  final int recibidos;
  final int total;

  /// Versión descargada y verificada, pendiente de aplicarse entre sesiones.
  final String? preparada;
  final String? error;

  /// «Actualiza la app para ver el contenido nuevo».
  final String? avisoAppAntigua;
  final DateTime? ultimaComprobacion;

  double? get fraccion => total <= 0 ? null : (recibidos / total).clamp(0, 1).toDouble();
}

/// Descarga, verificación y cambio de versión del contenido (offline-sync,
/// diseño D8). Interfaz estable; la implementación completa (manifiesto,
/// descarga reanudable con `Range`, firma, lista de retirada, versión mínima
/// de la app) la aporta la capacidad de sincronización.
abstract class ActualizadorContenido {
  ValueListenable<EstadoActualizacion> get estado;

  /// Pide el manifiesto, aplica al momento la lista de retirada y descarga y
  /// prepara las versiones nuevas del contenido global y de los itinerarios
  /// instalados. No cambia el contenido en uso.
  Future<void> comprobar();

  /// Descarga (o reanuda) y verifica el paquete de un itinerario y lo deja
  /// preparado. [progreso] recibe bytes recibidos y totales.
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso});

  /// Aplica las versiones preparadas si no hay ninguna sesión en curso.
  /// Devuelve true si el contenido ha cambiado.
  Future<bool> aplicarPreparadas();

  /// Itinerarios disponibles en el dispositivo (incluidos o descargados).
  Future<Set<String>> itinerariosInstalados();
}

/// Implementación provisional sin red: solo hay contenido incluido.
class ActualizadorSinRed implements ActualizadorContenido {
  final _estado = ValueNotifier(const EstadoActualizacion());
  @override
  ValueListenable<EstadoActualizacion> get estado => _estado;
  @override
  Future<void> comprobar() async {}
  @override
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso}) async {}
  @override
  Future<bool> aplicarPreparadas() async => false;
  @override
  Future<Set<String>> itinerariosInstalados() async => {'it-fundamentos'};
}

final actualizadorProvider = Provider<ActualizadorContenido>((ref) => ActualizadorSinRed());
