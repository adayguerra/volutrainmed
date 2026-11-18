import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';

/// Intérprete genérico de tipos por bloques (exercise-type-builder, lado app):
/// un tipo nuevo hecho con bloques que la app admite funciona sin versión
/// nueva; uno que exige una app posterior se omite sin errores.
void main() {
  late ContenidoCargado base;
  setUpAll(() async => base = await cargarContenidoDePrueba());

  Variant conTipo(Variant v, String tipo) => Variant(
        id: v.id,
        templateId: v.templateId,
        questionId: v.questionId,
        templateVersion: v.templateVersion,
        level: v.level,
        exerciseTypeId: tipo,
        exerciseTypeVersion: 1,
        skillId: v.skillId,
        sectorId: v.sectorId,
        statement: v.statement,
        question: v.question,
        tts: v.tts,
        approach: v.approach,
        hint: v.hint,
        targetTimeS: v.targetTimeS,
        answer: v.answer,
        predictedErrors: v.predictedErrors,
        steps: v.steps,
        plausibility: v.plausibility,
        options: v.options,
      );

  /// Contenido publicado con dos tipos creados en el back office: uno con un
  /// bloque que esta app admite y otro que exige una app posterior.
  ContenidoCargado publicado() {
    final g = base.global;
    const nuevo = ExerciseType(
      id: 'TC-calculo-directo',
      version: 1,
      name: 'Cálculo directo',
      description: 'Tipo creado con el creador de tipos',
      steps: [ExerciseTypeStep(presentation: ['statement', 'highlighted_data'], response: 'numeric_unit', grading: 'numeric_tolerance')],
      behaviour: ['hints', 'second_try'],
      voiceCompatible: true,
      minAppVersion: '1.0.0',
    );
    const futuro = ExerciseType(
      id: 'TC-jeringa',
      version: 1,
      name: 'Marcar en la jeringa',
      description: 'Usa un bloque de una versión posterior de la app',
      steps: [ExerciseTypeStep(presentation: ['statement', 'image'], response: 'syringe_mark', grading: 'numeric_tolerance')],
      behaviour: [],
      voiceCompatible: false,
      minAppVersion: '2.0.0',
    );
    final global = GlobalPackage(
      contentVersion: g.contentVersion,
      minAppVersion: g.minAppVersion,
      sectors: g.sectors,
      itineraries: g.itineraries,
      skills: g.skills,
      exerciseTypes: [...g.exerciseTypes, nuevo, futuro],
      units: g.units,
      instruments: g.instruments,
      voiceLexicon: g.voiceLexicon,
      achievements: g.achievements,
      league: g.league,
      adParams: g.adParams,
      campaigns: g.campaigns,
      freePlan: g.freePlan,
      orgsEnabled: g.orgsEnabled,
    );
    final it = base.fundamentos!;
    final variantes = [
      for (final v in it.variants)
        if (v.templateId == 'tpl-f-mg-ug') conTipo(v, nuevo.id) else if (v.templateId == 'tpl-f-g-mg') conTipo(v, futuro.id) else v,
    ];
    final it2 = ItineraryPackage(
      contentVersion: it.contentVersion,
      minAppVersion: it.minAppVersion,
      itinerary: it.itinerary,
      units: it.units,
      lessons: it.lessons,
      templates: it.templates,
      variants: variantes,
      placement: it.placement,
    );
    return ContenidoCargado(global: global, itinerarios: {it2.itinerary.id: it2}, revocaciones: const Revocaciones());
  }

  ({MotorSesion m, List<Attempt> intentos, List<String> eventos}) leccion(ContenidoCargado c) {
    final intentos = <Attempt>[];
    final eventos = <String>[];
    final m = MotorSesion(
      contenido: c,
      modo: SessionMode.lesson,
      deviceId: 'd',
      relojMs: () => 0,
      ahora: () => ahoraPrueba,
      leccion: c.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l3'),
      azar: Random(5),
      alRegistrar: intentos.add,
      alEvento: (n, p) => eventos.add('$n:${p['reason']}'),
    )..preparar();
    return (m: m, intentos: intentos, eventos: eventos);
  }

  void terminar(MotorSesion m) {
    while (m.fase != FaseSesion.terminada) {
      responderBien(m);
      m.continuar();
    }
  }

  test('exercise-type-builder · Tipo nuevo en una app ya instalada: se recibe con el contenido y se resuelve sin actualizar la app', () {
    final s = leccion(publicado());
    // El primer hueco de la lección es de la plantilla que usa el tipo nuevo.
    expect(s.m.actual!.variante.exerciseTypeId, 'TC-calculo-directo');
    expect(s.m.actual!.bloque, 'numeric_unit', reason: 'se dibuja con el bloque que la app ya admite');
    final r = responderBien(s.m);
    expect(r.acierto, isTrue);
    expect(s.intentos.single.exerciseTypeId, 'TC-calculo-directo');
    s.m.continuar();
    final mal = responderMal(s.m, critico: true);
    expect(mal.acierto, isFalse, reason: 'también se corrige y diagnostica');
  });

  test('exercise-type-builder · Tipo nuevo sin conexión: se presenta y se corrige con normalidad', () async {
    // Sin conexión: toda petición falla. El motor no hace ninguna.
    final a = Arnes(conexion: false, contenido: publicado());
    await a.contenedorSinInterfaz();
    final s = leccion(a.contenido);
    var delTipoNuevo = 0;
    while (s.m.fase != FaseSesion.terminada) {
      if (s.m.actual!.variante.exerciseTypeId == 'TC-calculo-directo') delTipoNuevo++;
      expect(responderBien(s.m).acierto, isTrue);
      s.m.continuar();
    }
    expect(delTipoNuevo, greaterThan(0));
    expect(a.peticiones, isEmpty);
  });

  test('exercise-type-builder · App antigua: omite los ejercicios del tipo que exige una app posterior y el resto de la lección funciona', () {
    final s = leccion(publicado());
    final huecos = s.m.leccion!.slots.length;
    final delFuturo = s.m.leccion!.slots.where((x) => x.templateId == 'tpl-f-g-mg').length;
    expect(delFuturo, greaterThan(0));
    terminar(s.m);
    expect(s.intentos.any((a) => a.exerciseTypeId == 'TC-jeringa'), isFalse);
    expect(s.intentos, hasLength(huecos - delFuturo), reason: 'el resto de la lección se hace entero');
    expect(s.m.saltadas, hasLength(delFuturo));
    expect(s.m.saltadas.first.motivo, contains('exige la app 2.0.0'));
    expect(s.eventos.where((e) => e.startsWith('variant_skipped')), hasLength(delFuturo));
    expect(s.m.registro(completada: true).completed, isTrue);
  });
}
