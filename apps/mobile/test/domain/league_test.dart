import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/leagues/domain/league.dart';

Attempt _acierto(int i, DateTime t, {int intento = 1, Verdict v = Verdict.correct}) => Attempt(
      id: 'a$i',
      sessionId: 's',
      deviceId: 'd',
      mode: SessionMode.lesson,
      variantId: 'v$i',
      skillId: 'H1',
      exerciseTypeId: 'T1',
      level: 1,
      attemptNumber: intento,
      verdict: v,
      responseMs: 5000,
      targetMs: 20000,
      contentVersion: '2026.11.1',
      deviceTime: t,
    );

SessionRecord _crono(String id, DateTime t, {required bool valida}) => SessionRecord(
      id: id,
      deviceId: 'd',
      mode: SessionMode.timetrial,
      startedAt: t,
      endedAt: t,
      completed: true,
      practiceMs: 60000,
      contentVersion: '2026.11.1',
      summary: SessionSummary(correct: 12, total: 15, errors: 3, accuracy: valida ? 0.95 : 0.8, valid: valida),
    );

void main() {
  const config = LeagueConfig();
  final hoy = DateTime(2026, 11, 16, 9);

  test('[leagues] Escenario: Tope diario', () {
    final intentos = [for (var i = 0; i < 35; i++) _acierto(i, hoy.add(Duration(minutes: i)))];
    final p = puntosLiga(intentos: intentos, sesiones: const [], config: config);
    expect(p.hoy(hoy), 300);
    final manana = [...intentos, _acierto(99, hoy.add(const Duration(days: 1)))];
    expect(puntosLiga(intentos: manana, sesiones: const [], config: config).total, 310);
  });

  test('solo puntúan los aciertos al primer intento', () {
    final intentos = [
      _acierto(1, hoy),
      _acierto(2, hoy, intento: 2),
      _acierto(3, hoy, v: Verdict.incorrect),
      _acierto(4, hoy, v: Verdict.correctNote),
    ];
    expect(puntosLiga(intentos: intentos, sesiones: const [], config: config).total, 20);
  });

  test('[leagues] Escenario: Marca de contrarreloj no válida', () {
    expect(puntosLiga(intentos: const [], sesiones: [_crono('c1', hoy, valida: false)], config: config).total, 0);
    expect(puntosLiga(intentos: const [], sesiones: [_crono('c2', hoy, valida: true)], config: config).total, 20);
  });

  test('[leagues] Escenario: Liga sin conexión', () {
    final calculada = hoy.subtract(const Duration(hours: 3));
    expect(textoAntiguedad(calculada, hoy), 'Clasificación de hace 3 h');
    expect(textoAntiguedad(hoy.subtract(const Duration(minutes: 12)), hoy), 'Clasificación de hace 12 min');
    expect(textoAntiguedad(hoy.subtract(const Duration(days: 2)), hoy), 'Clasificación de hace 2 días');
  });

  test('[leagues] Escenario: Clasificación con alias', () {
    final json = {
      'participating': true,
      'week': '2026-W47',
      'division': 'Oro',
      'endsAt': '2026-11-22T23:59:59Z',
      'standings': [
        for (var i = 1; i <= 30; i++) {'position': i, 'alias': 'alias_$i', 'points': 600 - i * 10, 'me': i == 6},
      ],
      'zones': {'promote': 7, 'relegate': 5},
      'computedAt': '2026-11-16T06:00:00Z',
      'pendingPoints': 40,
    };
    final c = ClasificacionLiga.fromJson(json);
    final copia = ClasificacionLiga.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(copia.standings.length, 30);
    expect(copia.propia!.alias, 'alias_6');
    expect(copia.pendingPoints, 40);
    expect(copia.zonaDe(copia.standings[6]), ZonaLiga.ascenso);
    expect(copia.zonaDe(copia.standings[7]), ZonaLiga.permanencia);
    expect(copia.zonaDe(copia.standings[25]), ZonaLiga.descenso);
    expect(ClasificacionLiga.etiquetaFila(copia.propia!), 'Posición 6, alias_6, 540 puntos, tú');
    // La fila no expone nombre ni correo: solo alias.
    expect(copia.standings.first.toJson().keys, unorderedEquals(['position', 'alias', 'points', 'me']));
  });
}
