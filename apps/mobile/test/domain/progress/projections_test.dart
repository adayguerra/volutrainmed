import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/progress/domain/projections.dart';

import 'fabrica.dart';

/// [n] primeros intentos de una habilidad repartidos en los días indicados.
List<Attempt> serie({
  required int n,
  required int aciertos,
  required List<int> dias,
  String skill = 'H1',
  String plantilla = 'tpl-a',
  bool criticoEnFallo = false,
  int responseMs = 10000,
  SessionMode modo = SessionMode.lesson,
}) =>
    [
      for (var i = 0; i < n; i++)
        intento(
          t: dia(dias[i * dias.length ~/ n], 9, i),
          skill: skill,
          plantilla: plantilla,
          correcto: i >= n - aciertos,
          critico: criticoEnFallo && i < n - aciertos,
          responseMs: responseMs,
          modo: modo,
        ),
    ];

void main() {
  final it = itinerarioPrueba();

  Proyeccion p({List<Attempt> a = const [], List<SessionRecord> s = const [], Goal? goal, DateTime? now}) => proyectar(
        attempts: a,
        sessions: s,
        itineraries: [it],
        achievements: logrosFijos(),
        goal: goal,
        now: now ?? dia(10, 20),
        habilidadesConocidas: const ['H1', 'H2', 'H3'],
      );

  group('Estados de habilidad', () {
    test('Sin intentos la habilidad es nueva y con pocos queda en aprendizaje', () {
      expect(p().estadoHabilidad('H2'), EstadoHabilidad.nueva);
      expect(p(a: serie(n: 10, aciertos: 10, dias: [0, 1])).estadoHabilidad('H1'), EstadoHabilidad.enAprendizaje);
    });

    test('[learning-path] Escenario: Habilidad consolidada', () {
      final r = p(a: serie(n: 20, aciertos: 17, dias: [0, 1]));
      expect(r.estadoHabilidad('H1'), EstadoHabilidad.consolidada);
      expect(r.habilidades['H1']!.precisionUltimos20, closeTo(0.85, 1e-9));
      expect(r.habilidades['H1']!.diasDistintos, 2);
      // En un solo día no se consolida.
      expect(p(a: serie(n: 20, aciertos: 20, dias: [0])).estadoHabilidad('H1'), EstadoHabilidad.enAprendizaje);
    });

    test('[learning-path] Escenario: Habilidad dominada', () {
      expect(p(a: serie(n: 20, aciertos: 19, dias: [0, 3, 7])).estadoHabilidad('H1'), EstadoHabilidad.dominada);
      // Con un error crítico en la ventana no se domina.
      expect(
        p(a: serie(n: 20, aciertos: 19, dias: [0, 3, 7], criticoEnFallo: true)).estadoHabilidad('H1'),
        EstadoHabilidad.consolidada,
      );
      // Repartida en menos de siete días tampoco.
      expect(p(a: serie(n: 20, aciertos: 20, dias: [0, 2, 4])).estadoHabilidad('H1'), EstadoHabilidad.consolidada);
      // Con la mediana de tiempo por encima del objetivo, tampoco.
      expect(
        p(a: serie(n: 20, aciertos: 20, dias: [0, 3, 7], responseMs: 40000)).estadoHabilidad('H1'),
        EstadoHabilidad.consolidada,
      );
    });

    test('[learning-path] Escenario: Habilidad por refrescar (fallo en repaso y recuperación)', () {
      final base = serie(n: 20, aciertos: 20, dias: [0, 3, 7]);
      final fallo = intento(t: dia(8), correcto: false, modo: SessionMode.review);
      expect(p(a: [...base, fallo]).estadoHabilidad('H1'), EstadoHabilidad.porRefrescar);
      final repasos = [for (var i = 0; i < 3; i++) intento(t: dia(9, 9, i), modo: SessionMode.review)];
      expect(p(a: [...base, fallo, ...repasos.take(2)]).estadoHabilidad('H1'), EstadoHabilidad.porRefrescar);
      expect(p(a: [...base, fallo, ...repasos]).estadoHabilidad('H1'), EstadoHabilidad.dominada);
    });

    test('[learning-path] Escenario: Habilidad por refrescar (fichas vencidas más de 14 días)', () {
      final viejo = intento(t: dia(-1), plantilla: 'tpl-viejo', correcto: false);
      final base = serie(n: 20, aciertos: 20, dias: [0, 3, 7]);
      expect(p(a: [viejo, ...base], now: dia(10)).estadoHabilidad('H1'), EstadoHabilidad.dominada);
      expect(p(a: [viejo, ...base], now: dia(16)).estadoHabilidad('H1'), EstadoHabilidad.porRefrescar);
    });

    test('[gamification-progress] Escenario: Cambio de estado de una habilidad', () {
      final antes = p(a: serie(n: 19, aciertos: 17, dias: [0, 1])).mapaEstados;
      final despues = p(a: serie(n: 20, aciertos: 18, dias: [0, 1])).mapaEstados;
      expect(cambiosDeEstado(antes, despues), [
        const CambioEstado('H1', EstadoHabilidad.enAprendizaje, EstadoHabilidad.consolidada),
      ]);
    });

    test('[time-trial] Escenario: Habilidad sin consolidar (no abre el contrarreloj)', () {
      expect(EstadoHabilidad.enAprendizaje.abreContrarreloj, isFalse);
      expect(EstadoHabilidad.consolidada.abreContrarreloj, isTrue);
      expect(EstadoHabilidad.porRefrescar.abreContrarreloj, isTrue);
    });
  });

  group('Ruta, lecciones y reto', () {
    test('[learning-path] Escenario: Ruta con estados', () {
      final r = p();
      expect(r.unidades['u1'], EstadoUnidad.disponible);
      expect(r.unidades['u2'], EstadoUnidad.bloqueada);
      expect(EstadoUnidad.porRefrescar.etiqueta, 'Por refrescar');
    });

    test('[learning-path] Escenario: Lección bloqueada', () {
      final r = p(s: [sesion(id: 'l1', inicio: dia(0), lessonId: 'u1-l1')]);
      expect(r.estadoLeccion('u1-l1'), EstadoLeccion.completada);
      expect(r.estadoLeccion('u1-l2'), EstadoLeccion.disponible);
      expect(r.estadoLeccion('u1-l3'), EstadoLeccion.bloqueada);
      expect(r.mensajeBloqueo('u1-l3'), 'Completa antes la lección 2');
      expect(r.unidades['u1'], EstadoUnidad.enCurso);
      // El reto siempre se puede intentar si la unidad está disponible.
      expect(r.estadoLeccion('u1-l5'), EstadoLeccion.disponible);
      expect(r.estadoLeccion('u2-l1'), EstadoLeccion.bloqueada);
    });

    test('[learning-path] Escenario: Continuar', () {
      final r = p(s: [
        sesion(id: 'l1', inicio: dia(0), lessonId: 'u1-l1'),
        sesion(id: 'l2', inicio: dia(1), lessonId: 'u1-l2'),
      ]);
      expect(r.siguienteLeccion(it)!.id, 'u1-l3');
    });

    test('Una sesión no completada no completa la lección (salida a mitad)', () {
      final r = p(s: [sesion(id: 'l1', inicio: dia(0), lessonId: 'u1-l1', completada: false)]);
      expect(r.lecciones['u1-l1'], isNull);
      expect(r.siguienteLeccion(it)!.id, 'u1-l1');
    });

    test('[learning-path] Escenario: Reto superado', () {
      final r = p(s: [
        sesion(
          id: 'reto',
          inicio: dia(0),
          modo: SessionMode.challenge,
          lessonId: 'u1-l5',
          resumen: const SessionSummary(correct: 9, total: 10, errors: 1, accuracy: 0.9, passed: true),
        ),
      ]);
      expect(r.unidades['u1'], EstadoUnidad.superada);
      expect(r.unidades['u2'], EstadoUnidad.disponible);
      expect(r.siguienteLeccion(it)!.id, 'u2-l1');
    });

    test('[learning-path] Escenario: Reto no superado por un error crítico', () {
      final intentos = [
        for (var i = 0; i < 10; i++)
          intento(
            t: dia(0, 9, i),
            sesion: 'reto',
            modo: SessionMode.challenge,
            lessonId: 'u1-l5',
            correcto: i != 4,
            critico: i == 4,
            errorCode: i == 4 ? 'E2' : null,
          ),
      ];
      final r = p(a: intentos, s: [sesion(id: 'reto', inicio: dia(0), modo: SessionMode.challenge, lessonId: 'u1-l5')]);
      expect(r.unidades['u1'], isNot(EstadoUnidad.superada));
      expect(r.unidades['u2'], EstadoUnidad.bloqueada);
      expect(r.fichas.keys, contains('tpl-a@1'), reason: 'el fallo pasa al repaso');
    });

    test('[learning-path] Escenario: Saltar una unidad con el reto', () {
      final intentos = [
        for (var i = 0; i < 10; i++)
          intento(t: dia(0, 9, i), sesion: 'reto', modo: SessionMode.challenge, lessonId: 'u1-l5', correcto: i != 0),
      ];
      final r = p(a: intentos, s: [sesion(id: 'reto', inicio: dia(0), modo: SessionMode.challenge, lessonId: 'u1-l5')]);
      expect(r.unidades['u1'], EstadoUnidad.superada);
      for (var o = 1; o <= 4; o++) {
        expect(r.estadoLeccion('u1-l$o'), EstadoLeccion.convalidada);
      }
      expect(r.infoUnidad('u1')!.retoSuperado, isTrue);
    });

    test('[onboarding-account] Escenario: Unidades convalidadas por la prueba de nivel', () {
      final r = p(s: [
        sesion(
          id: 'prueba',
          inicio: dia(0),
          modo: SessionMode.placement,
          resumen: const SessionSummary(
            correct: 6,
            total: 8,
            errors: 2,
            accuracy: 0.75,
            convalidatedUnitIds: ['u1', 'u2'],
            entryUnitId: 'u3',
          ),
        ),
      ]);
      expect(r.unidades['u1'], EstadoUnidad.superada);
      expect(r.unidades['u2'], EstadoUnidad.superada);
      expect(r.unidades['u3'], EstadoUnidad.disponible);
      expect(r.siguienteLeccion(it)!.id, 'u3-l1');
    });

    test('Unidad dominada cuando está superada y todas sus habilidades están dominadas', () {
      final r = p(
        a: serie(n: 20, aciertos: 20, dias: [0, 3, 7]),
        s: [
          sesion(
            id: 'reto',
            inicio: dia(8),
            modo: SessionMode.challenge,
            lessonId: 'u1-l5',
            resumen: const SessionSummary(correct: 10, total: 10, errors: 0, accuracy: 1, passed: true),
          ),
        ],
      );
      expect(r.unidades['u1'], EstadoUnidad.dominada);
      final logro = r.logros.firstWhere((l) => l.logro.id == 'ach-first-unit-mastered');
      expect(logro.obtenido, isTrue);
    });
  });

  group('Meta y racha', () {
    test('[gamification-progress] Escenario: Meta diaria cumplida', () {
      final r = p(s: [sesion(id: 'a', inicio: dia(10, 9), practiceMs: 5 * 60000)], goal: const Goal.daily(5));
      expect(r.racha.metaCumplidaHoy, isTrue);
      expect(r.racha.fraccion, 1);
    });

    test('[house-ads] Escenario: Meta diaria de cinco minutos (los anuncios no cuentan)', () {
      final r = p(
        s: [sesion(id: 'a', inicio: dia(10, 9), practiceMs: 4 * 60000, adMs: 60000)],
        goal: const Goal.daily(5),
      );
      expect(r.racha.minutosHoy, 4);
      expect(r.racha.metaCumplidaHoy, isFalse);
    });

    test('[gamification-progress] Escenario: Meta semanal', () {
      final s = [for (final d in [0, 2, 4, 6]) sesion(id: 'd$d', inicio: dia(d, 9), practiceMs: 60000)];
      final r = p(s: s, goal: const Goal.weekly(4), now: dia(6, 20));
      expect(r.racha.tipo, GoalKind.weekly);
      expect(r.racha.metaCumplidaHoy, isTrue);
      expect(r.racha.actual, 1);
      final antes = p(s: s.take(3).toList(), goal: const Goal.weekly(4), now: dia(5, 20));
      expect(antes.racha.metaCumplidaHoy, isFalse);
      expect(antes.racha.progresoHoy, 3);
    });

    test('[gamification-progress] Escenario: Racha extendida', () {
      final previas = [for (final d in [8, 9]) sesion(id: 'd$d', inicio: dia(d, 9), practiceMs: 5 * 60000)];
      expect(p(s: previas, goal: const Goal.daily(5)).racha.actual, 2);
      final hoy = sesion(id: 'hoy', inicio: dia(10, 9), practiceMs: 5 * 60000);
      expect(p(s: [...previas, hoy], goal: const Goal.daily(5)).racha.actual, 3);
    });

    test('[gamification-progress] Escenario: Racha interrumpida', () {
      final s = [for (var d = -3; d <= 8; d++) sesion(id: 'd$d', inicio: dia(d, 9), practiceMs: 5 * 60000)];
      // Doce días cumplidos (−3 a 8), el día 9 sin práctica y vuelve el día 10.
      final r = p(s: s, goal: const Goal.daily(5), now: dia(10, 8));
      expect(r.racha.mejor, 12);
      expect(r.racha.actual, 0);
      expect(r.racha.aviso, 'Tu racha se quedó en 12 días. Hoy empieza otra');
    });

    test('[gamification-progress] Escenario: Racha sin conexión', () {
      final r = p(s: [sesion(id: 'hoy', inicio: dia(10, 9), practiceMs: 6 * 60000)], goal: const Goal.daily(5));
      expect(r.racha.actual, 1);
    });
  });

  group('Puntos, niveles y logros', () {
    test('[gamification-progress] Escenario: Segundo intento', () {
      final r = p(a: [
        intento(t: dia(0), correcto: false),
        intento(t: dia(0, 10, 1), numero: 2, puntos: 0),
      ]);
      expect(r.puntosTotales, 0);
    });

    test('[gamification-progress] Escenario: Acierto al primer intento', () {
      final r = p(a: [intento(t: dia(10, 9), puntos: 10)]);
      expect(r.puntosTotales, 10);
      expect(r.puntosSemana, 10);
    });

    test('[gamification-progress] Escenario: Subida de nivel (umbral)', () {
      expect(nivelPorPuntos(99).nivel, 1);
      expect(nivelPorPuntos(100).nivel, 2);
      expect(nivelPorPuntos(175).progreso, closeTo(0.5, 1e-9));
    });

    test('[gamification-progress] Escenario: Primera sesión manos libres', () {
      final r = p(s: [sesion(id: 'hf', inicio: dia(3), modo: SessionMode.handsfree)]);
      final l = r.logros.firstWhere((l) => l.logro.id == 'ach-first-handsfree');
      expect(l.obtenido, isTrue);
      expect(l.fecha, isNotNull);
      final otro = r.logros.firstWhere((l) => l.logro.id == 'ach-first-lesson');
      expect(otro.obtenido, isFalse);
    });

    test('Logro de cien ejercicios sin error crítico con progreso parcial', () {
      final r = p(a: serie(n: 50, aciertos: 50, dias: [0]));
      final l = r.logros.firstWhere((l) => l.logro.id == 'ach-100-no-critical');
      expect(l.obtenido, isFalse);
      expect(l.progreso, closeTo(0.5, 1e-9));
    });
  });

  group('Estadísticas', () {
    test('[gamification-progress] Escenario: Datos insuficientes', () {
      final r = p(s: [sesion(id: 'a', inicio: dia(0)), sesion(id: 'b', inicio: dia(1))]);
      expect(r.resumen.datosInsuficientes, isTrue);
      expect(ResumenGlobal.mensajeDatosInsuficientes, 'Completa tres sesiones para ver tu evolución');
    });

    test('[gamification-progress] Escenario: Evolución de la precisión', () {
      final semana1 = [for (var i = 0; i < 50; i++) intento(t: dia(0, 9, i), skill: 'H9', correcto: i >= 9)];
      final semana4 = [for (var i = 0; i < 100; i++) intento(t: dia(21, 9, i % 60), skill: 'H9', correcto: i >= 7)];
      final r = p(a: [...semana1, ...semana4], now: dia(22));
      final e = r.estadisticas('H9');
      expect(e.semanas.first.precision, closeTo(0.82, 1e-9));
      expect(e.semanas.last.precision, closeTo(0.93, 1e-9));
      expect(e.resumen, 'Tu precisión ha pasado del 82 % al 93 % en cuatro semanas');
    });

    test('Errores por tipo y plantillas más falladas, ordenados', () {
      final r = p(a: [
        intento(t: dia(0), correcto: false, errorCode: 'E1', plantilla: 'tpl-x'),
        intento(t: dia(0, 11), correcto: false, errorCode: 'E1', plantilla: 'tpl-x'),
        intento(t: dia(0, 12), correcto: false, errorCode: 'E4', plantilla: 'tpl-y'),
      ]);
      final e = r.estadisticas('H1');
      expect(e.erroresPorTipo.first.key, 'E1');
      expect(e.erroresPorTipo.first.value, 2);
      expect(e.plantillasMasFalladas.first.key, 'tpl-x');
    });

    test('[gamification-progress] Escenario: Estadísticas sin conexión', () {
      final r = p(a: serie(n: 10, aciertos: 9, dias: [9, 10]), s: [sesion(id: 'a', inicio: dia(10, 9))]);
      expect(r.resumen.precision7d, closeTo(0.9, 1e-9));
      expect(r.resumen.calendario, hasLength(35));
    });
  });

  group('Sin conexión y fusión', () {
    test('[offline-sync] Escenario: Dos dispositivos sin conexión', () {
      final movilA = [
        intento(t: dia(1, 9), sesion: 'sa', lessonId: 'u1-l1', dispositivo: 'movil', correcto: false, errorCode: 'E2', critico: true),
        intento(t: dia(1, 9, 1), sesion: 'sa', lessonId: 'u1-l1', dispositivo: 'movil', puntos: 10),
      ];
      final tabletB = [
        intento(t: dia(1, 18), sesion: 'sb', lessonId: 'u1-l2', dispositivo: 'tablet', plantilla: 'tpl-b', correcto: false),
        intento(t: dia(1, 18, 1), sesion: 'sb', lessonId: 'u1-l2', dispositivo: 'tablet', puntos: 10),
      ];
      final sesA = [sesion(id: 'sa', inicio: dia(1, 9), lessonId: 'u1-l1', practiceMs: 3 * 60000, dispositivo: 'movil')];
      final sesB = [sesion(id: 'sb', inicio: dia(1, 18), lessonId: 'u1-l2', practiceMs: 3 * 60000, dispositivo: 'tablet')];
      final ab = p(a: [...movilA, ...tabletB], s: [...sesA, ...sesB], goal: const Goal.daily(5), now: dia(2, 8));
      // Orden inverso y con un lote repetido (envío duplicado por un corte).
      final ba = p(a: [...tabletB, ...movilA, ...movilA], s: [...sesB, ...sesA, ...sesA], goal: const Goal.daily(5), now: dia(2, 8));
      expect(ab.lecciones.keys.toSet(), {'u1-l1', 'u1-l2'});
      expect(ba.lecciones.keys.toSet(), ab.lecciones.keys.toSet());
      expect(ba.fichas.keys.toSet(), ab.fichas.keys.toSet());
      for (final k in ab.fichas.keys) {
        expect(ba.fichas[k]!.vence, ab.fichas[k]!.vence);
        expect(ba.fichas[k]!.cuarentena, ab.fichas[k]!.cuarentena);
      }
      expect(ab.racha.actual, 1, reason: '3 + 3 minutos cumplen la meta de 5');
      expect(ba.racha.actual, ab.racha.actual);
      expect(ba.puntosTotales, ab.puntosTotales);
      expect(ba.intentos.map((a) => a.id).toList(), ab.intentos.map((a) => a.id).toList());
    });

    test('[offline-sync] Escenario: Semana sin conexión', () {
      final intentos = <Attempt>[];
      final sesiones = <SessionRecord>[];
      for (var d = 0; d < 7; d++) {
        sesiones.add(sesion(id: 's$d', inicio: dia(d, 9), lessonId: d < 4 ? 'u1-l${d + 1}' : null, practiceMs: 5 * 60000));
        for (var i = 0; i < 5; i++) {
          intentos.add(intento(t: dia(d, 9, i), sesion: 's$d', correcto: i != 0 || d.isOdd, puntos: 10));
        }
      }
      final r = p(a: intentos, s: sesiones, goal: const Goal.daily(5), now: dia(6, 20));
      expect(r.racha.actual, 7);
      expect(r.logros.firstWhere((l) => l.logro.id == 'ach-streak-7').obtenido, isTrue);
      expect(r.logros.firstWhere((l) => l.logro.id == 'ach-first-lesson').obtenido, isTrue);
      expect(r.lecciones, hasLength(4));
      expect(r.siguienteLeccion(it)!.id, 'u1-l5');
      expect(r.fichas, isNotEmpty);
      expect(r.resumen.diasActivosSemana, 7);
    });
  });
}
