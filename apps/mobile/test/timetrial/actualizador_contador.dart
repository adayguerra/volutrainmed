import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:volutrainmed/core/contenido/actualizador.dart';

import '../helpers/arnes.dart';

/// Actualizador de prueba que cuenta cuántas veces se aplican las versiones
/// preparadas (el contenido nuevo solo se aplica al empezar una sesión).
class ActualizadorContador implements ActualizadorContenido {
  int aplicaciones = 0;
  int comprobaciones = 0;
  final _estado = ValueNotifier(const EstadoActualizacion());
  @override
  ValueListenable<EstadoActualizacion> get estado => _estado;
  @override
  Future<void> comprobar() async => comprobaciones++;
  @override
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso}) async {}
  @override
  Future<bool> aplicarPreparadas() async {
    aplicaciones++;
    return false;
  }

  @override
  Future<Set<String>> itinerariosInstalados() async => {'it-fundamentos'};
}

/// Arnés con el actualizador contador.
class ArnesActualizador extends Arnes {
  ArnesActualizador({super.intentos, super.sesiones, super.derechos, super.permisos, super.motorVoz, super.ajustes});
  final actualizador = ActualizadorContador();
  @override
  List<Override> get overrides => [...super.overrides, actualizadorProvider.overrideWithValue(actualizador)];
}
