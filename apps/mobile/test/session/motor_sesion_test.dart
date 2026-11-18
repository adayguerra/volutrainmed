import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/review/domain/review_projection.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';

/// Pruebas del motor de sesión (lógica pura, sin interfaz).
void main() {
  late ContenidoCargado c;
  setUpAll(() async => c = await cargarContenidoDePrueba());

  Lesson leccion(String id) => c.fundamentos!.lessons.firstWhere((l) => l.id == id);

  ({MotorSesion m, List<Attempt> intentos, void Function(int) avanzar}) crear({
    String? leccionId = 'u-f-1-l3',
    SessionMode modo = SessionMode.lesson,
    bool sinAnuncios = true,
    bool primera = false,
    List<FichaRepaso> calentamiento = const [],
    List<FichaRepaso> repaso = const [],
    ContenidoCargado? contenido,
  }) {
    var ms = 0;
    final intentos = <Attempt>[];
    final m = MotorSesion(
      contenido: contenido ?? c,
      modo: modo,
      deviceId: 'd',
      relojMs: () => ms,
      ahora: () => ahoraPrueba.add(Duration(milliseconds: ms)),
      leccion: leccionId == null ? null : leccion(leccionId),
      calentamiento: calentamiento,
      fichasRepaso: repaso,
      sinAnuncios: sinAnuncios,
      esPrimeraLeccion: primera,
      azar: Random(3),
      alRegistrar: intentos.add,
    )..preparar();
    return (m: m, intentos: intentos, avanzar: (int d) => ms += d);
  }

  void cerrar(MotorSesion m) {
    m.continuar();
    if (m.fase == FaseSesion.pausaPromocional) m.cerrarPausa();
  }

  group('exercise-session', () {
    test('la lección se prepara entera antes de empezar y sin red', () {
      final s = crear();
      expect(s.m.fase, FaseSesion.ejercicio);
      expect(s.m.total, 10);
      expect(s.m.actual!.variante.statement, isNotEmpty);
    });

    test('exercise-session · Tiempo de un ejercicio: responde a los 18 s y lee 40 s la explicación; el intento registra 18 s', () {
      final s = crear();
      s.avanzar(18000);
      final r = responderBien(s.m);
      expect(r.respuestaMs, 18000);
      s.avanzar(40000); // lectura de la explicación
      cerrar(s.m);
      expect(s.intentos.single.responseMs, 18000);
    });

    test('exercise-session · Llamada entrante: dos minutos en segundo plano no cuentan en el tiempo de respuesta', () {
      final s = crear();
      final antes = s.m.actual;
      s.avanzar(5000);
      s.m.pausar();
      s.avanzar(120000);
      s.m.reanudar();
      expect(s.m.actual, same(antes), reason: 'el ejercicio sigue en pantalla');
      s.avanzar(4000);
      final r = responderBien(s.m);
      expect(r.respuestaMs, 9000);
    });

    test('exercise-session · Variante defectuosa: se salta, se registra y la lección continúa', () {
      final eventos = <String>[];
      // Contenido con una variante T1 sin respuesta en el primer hueco.
      final it = c.fundamentos!;
      final defectuosa = it.variants.where((v) => v.templateId == 'tpl-f-mg-ug').map((v) => Variant(
            id: v.id,
            templateId: v.templateId,
            questionId: v.questionId,
            templateVersion: v.templateVersion,
            level: v.level,
            exerciseTypeId: 'T1',
            exerciseTypeVersion: 1,
            skillId: v.skillId,
            sectorId: v.sectorId,
            statement: v.statement,
            question: v.question,
            tts: v.tts,
            targetTimeS: v.targetTimeS,
          ));
      final variantes = [...defectuosa, ...it.variants.where((v) => v.templateId != 'tpl-f-mg-ug')];
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
      final c2 = ContenidoCargado(global: c.global, itinerarios: {it2.itinerary.id: it2}, revocaciones: const Revocaciones());
      var ms = 0;
      final m = MotorSesion(
        contenido: c2,
        modo: SessionMode.lesson,
        deviceId: 'd',
        relojMs: () => ms,
        ahora: () => ahoraPrueba,
        leccion: leccion('u-f-1-l1'),
        azar: Random(1),
        alEvento: (n, _) => eventos.add(n),
      )..preparar();
      expect(m.saltadas, isNotEmpty);
      expect(m.saltadas.first.motivo, 'Falta la respuesta');
      expect(eventos, contains('variant_skipped'));
      expect(m.fase, FaseSesion.ejercicio);
      expect(m.actual!.variante.templateId, isNot('tpl-f-mg-ug'));
      ms += 1;
    });

    test('exercise-session · No lo sé: resolución sin diagnóstico y el ejercicio entra en la cola de repaso', () {
      final s = crear();
      final r = s.m.noLoSe();
      expect(r.verdict, Verdict.dontKnow);
      expect(r.diagnostico, isNull);
      expect(r.errorCode, isNull);
      expect(r.correcta, isNotEmpty);
      final fichas = proyectarFichas(s.intentos);
      expect(fichas.containsKey(s.intentos.single.cardKey), isTrue);
      expect(fichas.values.single.vencida(ahoraPrueba.add(const Duration(days: 1))), isTrue);
    });

    test('salir a mitad deja los intentos guardados y la lección sin completar', () {
      final s = crear();
      for (var i = 0; i < 5; i++) {
        responderBien(s.m);
        cerrar(s.m);
      }
      final reg = s.m.registro(completada: false);
      expect(s.intentos, hasLength(5));
      expect(reg.completed, isFalse);
    });

    test('el motor conserva el contenido con el que empezó aunque se cargue otro', () {
      final s = crear();
      // Una versión nueva se carga en la app mientras tanto; el motor conserva la suya.
      final nueva = ContenidoCargado(global: c.global, itinerarios: const {}, revocaciones: const Revocaciones());
      expect(nueva.version, c.version);
      responderBien(s.m);
      cerrar(s.m);
      expect(s.m.contenido, same(c));
      expect(s.intentos.single.contentVersion, '2026.11.0');
      expect(s.m.actual, isNotNull);
    });
  });

  group('learning-path', () {
    test('learning-path · Subida de nivel: tres aciertos seguidos dentro del tiempo suben un nivel', () {
      final s = crear(leccionId: 'u-f-1-l3');
      final base = s.m.actual!.slot!.difficulty;
      for (var i = 0; i < 3; i++) {
        s.avanzar(1000);
        responderBien(s.m);
        cerrar(s.m);
      }
      expect(s.m.desplazamientoNivel, 1);
      final siguiente = s.m.actual!;
      final niveles = c.niveles(siguiente.itemKey);
      final esperado = (siguiente.slot!.difficulty + 1).clamp(niveles.first, niveles.last);
      expect(siguiente.nivel, esperado);
      expect(base, greaterThan(0));
    });

    test('learning-path · Bajada de nivel con apoyo: dos fallos seguidos bajan un nivel y muestran el planteamiento', () {
      final s = crear(leccionId: 'u-f-1-l3');
      for (var i = 0; i < 2; i++) {
        responderMal(s.m);
        cerrar(s.m);
      }
      expect(s.m.desplazamientoNivel, -1);
      final e = s.m.actual!;
      final niveles = c.niveles(e.itemKey);
      expect(e.nivel, (e.slot!.difficulty - 1).clamp(niveles.first, niveles.last));
      expect(e.planteamientoVisible, isTrue);
    });

    test('learning-path · Reto superado: 9 de 10 sin errores críticos supera la unidad', () {
      final s = crear(leccionId: 'u-f-1-l5');
      expect(s.m.esReto, isTrue);
      expect(s.m.pistasPermitidas, isFalse);
      for (var i = 0; i < 10; i++) {
        i == 4 ? responderMal(s.m) : responderBien(s.m);
        expect(s.m.segundoIntentoDisponible, isFalse, reason: 'el reto no ofrece segundo intento');
        cerrar(s.m);
      }
      expect(s.m.fase, FaseSesion.terminada);
      final reg = s.m.registro(completada: true);
      expect(reg.mode, SessionMode.challenge);
      expect(reg.summary!.passed, isTrue);
      expect(reg.summary!.convalidatedUnitIds, ['u-f-1']);
    });

    test('learning-path · Reto no superado por un error crítico: 9 de 10 con un fallo de factor diez', () {
      final s = crear(leccionId: 'u-f-1-l5');
      for (var i = 0; i < 10; i++) {
        if (i == 2) {
          final r = responderMal(s.m, critico: true);
          expect(r.critico, isTrue);
        } else {
          responderBien(s.m);
        }
        cerrar(s.m);
      }
      final reg = s.m.registro(completada: true);
      expect(reg.summary!.correct, 9);
      expect(reg.summary!.passed, isFalse);
      final fallo = s.intentos.firstWhere((a) => !a.correct);
      expect(proyectarFichas(s.intentos).containsKey(fallo.cardKey), isTrue, reason: 'el fallo pasa al repaso');
    });

    test('learning-path · Sesión con repaso pendiente: 12 fichas vencidas, primero 5 de repaso y después la lección', () {
      final fichas = <FichaRepaso>[];
      for (final v in c.fundamentos!.variants.where((v) => v.templateId != null && v.exerciseTypeId == 'T1').take(200)) {
        if (fichas.any((f) => f.clave == v.cardKey)) continue;
        fichas.add(FichaRepaso(clave: v.cardKey, templateId: v.templateId, questionId: null, level: v.level, skillId: v.skillId, creada: ahoraPrueba));
        if (fichas.length == 12) break;
      }
      final s = crear(calentamiento: fichas);
      for (var i = 0; i < 5; i++) {
        expect(s.m.actual!.origen, OrigenEjercicio.calentamiento);
        responderBien(s.m);
        cerrar(s.m);
      }
      expect(s.m.actual!.origen, OrigenEjercicio.leccion);
      expect(s.intentos.take(5).every((a) => a.mode == SessionMode.warmup), isTrue);
    });

    test('learning-path · Sesión sin repaso pendiente: la lección empieza directamente', () {
      final s = crear();
      expect(s.m.actual!.origen, OrigenEjercicio.leccion);
    });
  });

  group('answer-grading y gamification-progress', () {
    test('answer-grading · Segundo intento acertado: la lección sigue, sin puntos, y el primer fallo queda en repaso', () {
      final s = crear();
      responderMal(s.m);
      expect(s.m.segundoIntentoDisponible, isTrue);
      final primera = s.m.actual!.variante.id;
      s.m.iniciarSegundoIntento();
      expect(s.m.actual!.intentoNumero, 2);
      expect(s.m.actual!.variante.id, isNot(primera));
      expect(s.m.actual!.variante.templateId, s.intentos.first.templateId);
      final r = responderBien(s.m);
      expect(r.puntos, 0);
      expect(s.intentos.last.attemptNumber, 2);
      cerrar(s.m);
      expect(s.m.fase, FaseSesion.ejercicio);
      expect(proyectarFichas(s.intentos).containsKey(s.intentos.first.cardKey), isTrue);
    });

    test('gamification-progress · Acierto al primer intento: recibe los puntos del ejercicio', () {
      final s = crear();
      final r = responderBien(s.m);
      expect(r.puntos, puntosPorAcierto);
      expect(s.intentos.single.points, puntosPorAcierto);
    });

    test('gamification-progress · Lección con muchos fallos: siete fallos seguidos y la lección continúa', () {
      final s = crear();
      for (var i = 0; i < 7; i++) {
        responderMal(s.m);
        cerrar(s.m);
      }
      expect(s.m.fase, FaseSesion.ejercicio);
      for (var i = 0; i < 3; i++) {
        responderMal(s.m);
        cerrar(s.m);
      }
      expect(s.m.fase, FaseSesion.terminada);
      expect(s.m.registro(completada: true).completed, isTrue, reason: 'sin vidas ni bloqueos: se puede empezar otra');
    });
  });

  group('house-ads en la sesión', () {
    test('house-ads · Respuesta correcta en una lección: tras el ejercicio 4 hay pausa y al cerrarla llega el 5', () {
      final s = crear(sinAnuncios: false);
      for (var i = 0; i < 3; i++) {
        responderBien(s.m);
        cerrar(s.m);
      }
      responderBien(s.m);
      s.m.continuar();
      expect(s.m.fase, FaseSesion.pausaPromocional);
      s.m.cerrarPausa();
      expect(s.m.fase, FaseSesion.ejercicio);
      expect(s.m.posicion, 5);
    });

    test('house-ads · Primera lección: sin pausas entre ejercicios', () {
      final s = crear(sinAnuncios: false, primera: true);
      responderBien(s.m);
      s.m.continuar();
      expect(s.m.fase, FaseSesion.ejercicio);
    });

    test('house-ads · Usuario con Premium: completa la lección sin ninguna pausa', () {
      final s = crear(sinAnuncios: true);
      while (s.m.fase != FaseSesion.terminada) {
        responderBien(s.m);
        s.m.continuar();
        expect(s.m.fase, isNot(FaseSesion.pausaPromocional));
      }
    });

    test('house-ads · Error crítico con segundo intento: sin pausa antes del segundo intento y con pausa al cerrarlo', () {
      final s = crear(sinAnuncios: false);
      responderMal(s.m, critico: true);
      s.m.iniciarSegundoIntento();
      expect(s.m.fase, FaseSesion.ejercicio, reason: 'no hay pausa entre la explicación y el segundo intento');
      responderBien(s.m);
      s.m.continuar();
      expect(s.m.fase, FaseSesion.pausaPromocional);
    });

    test('house-ads · Meta diaria de cinco minutos: el tiempo de las pausas no cuenta como práctica', () {
      final s = crear(sinAnuncios: false);
      s.avanzar(60000);
      responderBien(s.m);
      s.m.continuar();
      s.avanzar(30000); // pausa promocional
      s.m.cerrarPausa();
      s.avanzar(60000);
      final reg = s.m.registro(completada: false);
      expect(reg.adMs, 30000);
      expect(reg.practiceMs, 120000);
    });
  });

  group('spaced-review', () {
    test('la sesión de repaso usa otra variante y una ficha fallada vuelve al final', () {
      final v = c.variantes('tpl-f-mg-ug', 1).first;
      final f = FichaRepaso(clave: v.cardKey, templateId: v.templateId, questionId: null, level: 1, skillId: 'H1', creada: ahoraPrueba)..variantesVistas.add(v.id);
      final v2 = c.variantes('tpl-f-g-mg', 1).first;
      final f2 = FichaRepaso(clave: v2.cardKey, templateId: v2.templateId, questionId: null, level: 1, skillId: 'H1', creada: ahoraPrueba);
      final s = crear(leccionId: null, modo: SessionMode.review, repaso: [f, f2]);
      expect(s.m.actual!.variante.id, isNot(v.id), reason: 'variante nueva en el repaso');
      responderMal(s.m);
      cerrar(s.m);
      responderBien(s.m);
      cerrar(s.m);
      expect(s.m.actual!.ficha!.clave, f.clave, reason: 'la ficha fallada reaparece al final');
      expect(s.intentos.every((a) => a.mode == SessionMode.review), isTrue);
    });
  });
}
