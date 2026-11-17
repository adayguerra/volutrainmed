import 'dart:math';

import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import '../../review/domain/review_projection.dart';
import '../../session/domain/motor_sesion.dart';

/// Qué se entrena en manos libres (M41).
enum ContenidoManosLibres { repaso, leccion, habilidad }

/// Duraciones ofrecidas; null = sin límite.
const duracionesManosLibres = <int?>[5, 10, 15, null];

/// Minutos de manos libres usados hoy (para el límite del plan gratuito).
int usadoHoyManosLibresMs(Iterable<SessionRecord> sesiones, DateTime ahora) => sesiones
    .where((s) => s.mode == SessionMode.handsfree && diaLocal(s.startedAt) == diaLocal(ahora))
    .fold(0, (t, s) => t + s.practiceMs);

/// Variantes compatibles con voz para un repaso hecho en manos libres: una
/// variante nueva por ficha (spaced-review, «Variante nueva en el repaso»).
List<Variant> variantesRepasoVoz(ContenidoCargado c, List<FichaRepaso> fichas) {
  final out = <Variant>[];
  for (final f in fichas) {
    final candidatas = c
        .variantes(f.itemKey, f.nivel)
        .where((v) => motivoDefecto(v, c.tipo(v.exerciseTypeId)) == null && bloquesVoz.contains(c.tipo(v.exerciseTypeId)?.steps.firstOrNull?.response))
        .toList();
    final id = elegirVarianteRepaso(f, candidatas.map((v) => v.id).toList());
    if (id != null) out.add(candidatas.firstWhere((v) => v.id == id));
  }
  return out;
}

/// Variantes compatibles con voz de una habilidad, de varias plantillas.
List<Variant> variantesHabilidadVoz(ContenidoCargado c, ItineraryPackage it, String skillId, Random azar, {int maximo = 30}) {
  final porPlantilla = <String, List<Variant>>{};
  for (final v in it.variants) {
    if (v.skillId != skillId || v.level > 3 || c.revocaciones.retirada(v)) continue;
    final bloque = c.tipo(v.exerciseTypeId)?.steps.firstOrNull?.response;
    if (!bloquesVoz.contains(bloque) || motivoDefecto(v, c.tipo(v.exerciseTypeId)) != null) continue;
    porPlantilla.putIfAbsent(v.itemKey, () => []).add(v);
  }
  final listas = porPlantilla.values.map((l) => (l..shuffle(azar)).toList()).toList();
  final out = <Variant>[];
  var i = 0;
  while (out.length < maximo && listas.any((l) => i < l.length)) {
    for (final l in listas) {
      if (i < l.length && out.length < maximo) out.add(l[i]);
    }
    i++;
  }
  return out;
}

/// Crea el motor de una sesión manos libres: modo `handsfree`, solo tipos
/// compatibles con voz y entrada por voz.
MotorSesion crearMotorManosLibres({
  required ContenidoCargado contenido,
  required ContenidoManosLibres que,
  required String deviceId,
  required int Function() relojMs,
  required DateTime Function() ahora,
  Lesson? leccion,
  List<FichaRepaso> fichas = const [],
  List<Variant> variantes = const [],
  bool sinAnuncios = true,
  int frecuenciaAnuncios = 1,
  Random? azar,
  RegistrarIntento? alRegistrar,
  RegistrarEvento? alEvento,
}) {
  final m = MotorSesion(
    contenido: contenido,
    modo: SessionMode.handsfree,
    deviceId: deviceId,
    relojMs: relojMs,
    ahora: ahora,
    leccion: que == ContenidoManosLibres.leccion ? leccion : null,
    variantesPractica: switch (que) {
      ContenidoManosLibres.repaso => variantesRepasoVoz(contenido, fichas),
      ContenidoManosLibres.habilidad => variantes,
      ContenidoManosLibres.leccion => const [],
    },
    sinAnuncios: sinAnuncios,
    frecuenciaAnuncios: frecuenciaAnuncios,
    soloVoz: true,
    inputMode: InputMode.voice,
    azar: azar,
    alRegistrar: alRegistrar,
    alEvento: alEvento,
  );
  m.preparar();
  return m;
}
