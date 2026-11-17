import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import 'fixtures_fase2.dart';

/// Motor de sesión con los tipos de la fase 2 y la lección mixta.
void main() {
  late ContenidoCargado c;
  setUpAll(() async => c = contenidoFase2(await cargarContenidoDePrueba()));

  Lesson leccion(String id) => c.itinerarios.values.expand((i) => i.lessons).firstWhere((l) => l.id == id);

  ({MotorSesion m, List<Attempt> intentos}) crear(String leccionId, {bool soloVoz = false}) {
    final intentos = <Attempt>[];
    final m = MotorSesion(
      contenido: c,
      modo: soloVoz ? SessionMode.handsfree : SessionMode.lesson,
      deviceId: 'd',
      relojMs: () => 0,
      ahora: () => ahoraPrueba,
      leccion: leccion(leccionId),
      soloVoz: soloVoz,
      azar: Random(2),
      alRegistrar: intentos.add,
    )..preparar();
    return (m: m, intentos: intentos);
  }

  group('Completar el planteamiento (T4)', () {
    test('exercise-session · Completar el planteamiento: fichas correctas aunque sobren y posiciones intercambiables aceptadas', () {
      final s = crear('l-t4');
      expect(s.m.actual!.bloque, 'fill_gaps');
      final g = s.m.actual!.variante.gapFill!;
      expect(g.tiles.length, greaterThan(g.gapIds.length), reason: 'sobran fichas');
      // g1 y g2 se declaran intercambiables: el peso en g1 y la pauta en g2.
      final r = s.m.responderHuecos({'g1': g.gapAnswers['g2']!, 'g2': g.gapAnswers['g1']!, 'g3': g.gapAnswers['g3']!});
      expect(r.verdict, Verdict.correct);
      expect(s.intentos.single.verdict, Verdict.correct);
      expect(s.intentos.single.points, puntosPorAcierto);
    });

    test('un hueco con una ficha sobrante es incorrecto y se marca', () {
      final s = crear('l-t4');
      final g = s.m.actual!.variante.gapFill!;
      final r = s.m.responderHuecos({'g1': g.gapAnswers['g1']!, 'g2': g.gapAnswers['g2']!, 'g3': '2,4'});
      expect(r.verdict, Verdict.incorrect);
      expect((r.payload as Map)['wrongGaps'], ['g3']);
      expect(r.diagnostico, 'Un hueco no es correcto');
      expect(r.correcta, contains('÷ 5 mg/ml'));
      expect(s.m.segundoIntentoDisponible, isTrue, reason: 'hay otra variante de la plantilla');
    });
  });

  group('Detectar el error (T5)', () {
    test('señalar un paso erróneo es correcto', () {
      final s = crear('l-t5');
      expect(s.m.actual!.bloque, 'step_pick');
      expect(s.m.responderPaso(2).verdict, Verdict.correct);
    });

    test('señalar un paso correcto o «No hay ningún error» es incorrecto y muestra la corrección', () {
      final s = crear('l-t5');
      final r = s.m.responderPaso(1);
      expect(r.verdict, Verdict.incorrect);
      expect(r.correcta, startsWith('Paso 2: Falta multiplicar por 60'));
      expect(r.pasoDesvio, 2);
      final s2 = crear('l-t5');
      expect(s2.m.responderPaso(null).verdict, Verdict.incorrect);
    });
  });

  group('Emparejar (T10)', () {
    test('exercise-session · Emparejar: cada par se corrige por separado y el ejercicio termina con todos unidos', () {
      final s = crear('l-t10');
      expect(s.m.actual!.bloque, 'matching');
      expect(s.m.corregirPar('1 mg', '1000 µg'), isTrue);
      expect(s.m.corregirPar('1 g', '60 min'), isFalse);
      expect(s.m.fase, FaseSesion.ejercicio, reason: 'corregir un par no cierra el ejercicio');
      final r = s.m.responderPares({'1 mg': '1000 µg', '1 g': '60 min', '1 h': '1000 mg', '1 %': '10 mg/ml'});
      expect(r.verdict, Verdict.incorrect);
      expect((r.payload as Map)['wrongLefts'], ['1 g', '1 h']);
      expect(r.diagnostico, '2 de 4 parejas bien');
      expect(s.m.fase, FaseSesion.correccion);
    });
  });

  group('Caso encadenado (T8)', () {
    test('exercise-session · Tipo de fase 2 sin conexión: cada parte se corrige y tras un fallo la siguiente sigue con el valor correcto', () {
      // El motor no usa la red: corrige con los valores del contenido descargado.
      final s = crear('l-t8');
      expect(s.m.actual!.bloque, 'chain');
      expect(isCorrectVerdict(s.m.corregirParte(0, '8').verdict), isTrue);
      final fallo = s.m.corregirParte(1, '8');
      expect(fallo.verdict, Verdict.incorrect);
      expect(fallo.errorCode, 'E4');
      expect(fallo.correctDisplay, '480 µg/h', reason: 'la siguiente parte continúa con este valor');
      // La tercera parte se resuelve con el valor correcto de la segunda.
      expect(isCorrectVerdict(s.m.corregirParte(2, '4,8').verdict), isTrue);
      final r = s.m.responderCadena(['8', '8', '4,8']);
      expect(r.verdict, Verdict.incorrect);
      final partes = ((r.payload as Map)['parts'] as List).cast<Map>();
      expect(partes.map((p) => p['verdict']), ['correct', 'incorrect', 'correct']);
      expect(r.errorCode, 'E4');
      expect(r.pasoDesvio, 2);
      expect(s.intentos.single.answerPayload, isA<Map>());
    });

    test('todas las partes bien dan el caso por correcto', () {
      final s = crear('l-t8');
      expect(s.m.responderCadena(['8', '480', '4,8']).verdict, Verdict.correct);
    });
  });

  test('las variantes de fase 2 mal formadas se saltan y se registran', () {
    final t4 = c.variantes('tpl-t4', 2).first;
    final sinHuecos = Variant(
      id: t4.id,
      templateId: t4.templateId,
      questionId: null,
      templateVersion: 1,
      level: 2,
      exerciseTypeId: 'T4',
      exerciseTypeVersion: 1,
      skillId: t4.skillId,
      sectorId: 'comun',
      statement: t4.statement,
      question: t4.question,
      tts: '',
      targetTimeS: 30,
    );
    expect(motivoDefecto(sinHuecos, c.tipo('T4')), 'Faltan los huecos');
    expect(motivoDefecto(c.variantes('tpl-t10', 2).first, c.tipo('T10')), isNull);
  });

  test('manos libres deja fuera los tipos de fase 2 que no son de voz', () {
    final s = crear('l-fase2-mezcla', soloVoz: true);
    expect(s.m.excluidosPorVoz, 2, reason: 'T4 y T10 quedan para el modo táctil');
    expect(s.m.actual!.bloque, 'numeric_unit');
  });

  test('learning-path · Lección mixta: la mixta de la unidad 2 alterna la habilidad nueva con habilidades anteriores', () {
    final base = contenidoPrueba;
    final mixta = base.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-2-l4');
    expect(mixta.kind, LessonKind.mixed);
    final m = MotorSesion(contenido: base, modo: SessionMode.lesson, deviceId: 'd', relojMs: () => 0, ahora: () => ahoraPrueba, leccion: mixta, azar: Random(4))..preparar();
    final habilidades = <String>[];
    while (m.fase != FaseSesion.terminada) {
      habilidades.add(m.actual!.variante.skillId);
      m.noLoSe();
      m.continuar();
    }
    expect(habilidades, hasLength(10));
    expect(habilidades.toSet(), {'H2', 'H1'}, reason: 'habilidad de la unidad 2 y de la unidad 1');
    // Alterna: nunca más de dos ejercicios seguidos de la misma habilidad.
    var racha = 1;
    for (var i = 1; i < habilidades.length; i++) {
      racha = habilidades[i] == habilidades[i - 1] ? racha + 1 : 1;
      expect(racha, lessThanOrEqualTo(2), reason: habilidades.join(','));
    }
    expect(habilidades.first, 'H2');
  });
}
