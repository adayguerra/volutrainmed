// Fábrica de intentos, sesiones e itinerarios para las pruebas de dominio.
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

int _n = 0;

/// Lunes 16 de noviembre de 2026, 10:00 (hora local).
final lunesBase = DateTime(2026, 11, 16, 10);

DateTime dia(int d, [int hora = 10, int minuto = 0]) => DateTime(2026, 11, 16 + d, hora, minuto);

Attempt intento({
  required DateTime t,
  String skill = 'H1',
  String plantilla = 'tpl-a',
  int nivel = 1,
  bool correcto = true,
  Verdict? veredicto,
  bool critico = false,
  String? errorCode,
  int responseMs = 10000,
  int targetMs = 30000,
  int pistas = 0,
  int numero = 1,
  SessionMode modo = SessionMode.lesson,
  String sesion = 's0',
  String? lessonId,
  String? variante,
  int puntos = 0,
  String dispositivo = 'dev-a',
  String? id,
}) {
  _n++;
  return Attempt(
    id: id ?? '$dispositivo-${t.millisecondsSinceEpoch}-${_n.toString().padLeft(6, '0')}',
    sessionId: sesion,
    deviceId: dispositivo,
    mode: modo,
    lessonId: lessonId,
    templateId: plantilla,
    variantId: variante ?? '$plantilla.v1.L$nivel.$_n',
    skillId: skill,
    exerciseTypeId: 'T1',
    level: nivel,
    attemptNumber: numero,
    verdict: veredicto ?? (correcto ? Verdict.correct : Verdict.incorrect),
    errorCode: errorCode,
    critical: critico,
    hintsUsed: pistas,
    responseMs: responseMs,
    targetMs: targetMs,
    points: puntos,
    contentVersion: '2026.11.1',
    deviceTime: t,
  );
}

SessionRecord sesion({
  required String id,
  required DateTime inicio,
  SessionMode modo = SessionMode.lesson,
  String? lessonId,
  int practiceMs = 4 * 60000,
  int adMs = 0,
  bool completada = true,
  SessionSummary? resumen,
  String dispositivo = 'dev-a',
}) =>
    SessionRecord(
      id: id,
      deviceId: dispositivo,
      mode: modo,
      lessonId: lessonId,
      startedAt: inicio,
      endedAt: inicio.add(Duration(milliseconds: practiceMs + adMs)),
      completed: completada,
      practiceMs: practiceMs,
      adMs: adMs,
      contentVersion: '2026.11.1',
      summary: resumen,
    );

Lesson _leccion(String unitId, int orden, LessonKind kind, String skill) => Lesson(
      id: '$unitId-l$orden',
      unitId: unitId,
      order: orden,
      kind: kind,
      title: lessonKindLabel[kind]!,
      estimatedMinutes: 4,
      slots: [LessonSlot(position: 1, templateId: 'tpl-$unitId', difficulty: 1, skillId: skill)],
    );

/// Itinerario de tres unidades encadenadas con cinco lecciones cada una.
ItineraryPackage itinerarioPrueba() {
  const kinds = LessonKind.values;
  final units = <Unit>[];
  final lessons = <Lesson>[];
  for (var i = 1; i <= 3; i++) {
    final id = 'u$i';
    final skill = 'H$i';
    units.add(Unit(
      id: id,
      itineraryId: 'it-prueba',
      order: i,
      name: 'Unidad $i',
      description: '',
      skills: [skill],
      prerequisiteUnitId: i == 1 ? null : 'u${i - 1}',
      guide: UnitGuide.fromJson(null),
    ));
    for (var o = 1; o <= 5; o++) {
      lessons.add(_leccion(id, o, kinds[o - 1], skill));
    }
  }
  return ItineraryPackage(
    contentVersion: '2026.11.1',
    minAppVersion: '1.0.0',
    itinerary: const ItinerarySummary(
      id: 'it-prueba',
      sectorId: 'comun',
      name: 'Prueba',
      description: '',
      recommendedLevel: 'cero',
      order: 0,
      isFoundations: true,
    ),
    units: units,
    lessons: lessons,
    templates: const [],
    variants: const [],
    placement: const [],
  );
}

/// Los cinco logros fijos del paquete global.
List<Achievement> logrosFijos() => [
      for (final (id, metrica, valor) in [
        ('ach-first-lesson', 'lessons_completed', 1),
        ('ach-streak-7', 'streak_days', 7),
        ('ach-first-unit-mastered', 'units_mastered', 1),
        ('ach-first-handsfree', 'handsfree_sessions', 1),
        ('ach-100-no-critical', 'no_critical_exercises', 100),
      ])
        Achievement(
          id: id,
          name: id,
          description: '',
          category: 'constancia',
          icon: 'flag',
          condition: AchievementCondition(metric: metrica, op: '>=', value: valor, scope: 'global'),
        ),
    ];
