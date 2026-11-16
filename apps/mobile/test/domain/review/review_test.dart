import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/domain/reloj.dart';
import 'package:volutrainmed/features/review/domain/fsrs.dart';
import 'package:volutrainmed/features/review/domain/review_projection.dart';

import '../progress/fabrica.dart';

void main() {
  group('Calificación automática', () {
    test('[spaced-review] Escenario: Acierto rápido', () {
      final a = intento(t: dia(0), responseMs: 15000, targetMs: 30000);
      expect(calificar(a), Rating.easy);
    });

    test('[spaced-review] Escenario: Acierto con pista', () {
      final a = intento(t: dia(0), responseMs: 20000, targetMs: 30000, pistas: 1);
      expect(calificar(a), Rating.hard);
    });

    test('[spaced-review] Escenario: No lo sé', () {
      final a = intento(t: dia(0), veredicto: Verdict.dontKnow);
      expect(calificar(a), Rating.again);
    });

    test('Acierto en más del doble del objetivo es difícil y en tiempo normal es bien', () {
      expect(calificar(intento(t: dia(0), responseMs: 61000, targetMs: 30000)), Rating.hard);
      expect(calificar(intento(t: dia(0), responseMs: 25000, targetMs: 30000)), Rating.good);
      expect(calificar(intento(t: dia(0), correcto: false)), Rating.again);
    });
  });

  group('FSRS', () {
    test('FSRS-4.5 es determinista y una ficha nueva fallada vence al día siguiente', () {
      const fsrs = FsrsScheduler();
      final c1 = fsrs.review(const FsrsCard(), Rating.again, dia(0));
      final c2 = fsrs.review(const FsrsCard(), Rating.again, dia(0));
      expect(c1.stability, c2.stability);
      expect(c1.due, DateTime(2026, 11, 17));
      expect(c1.state, EstadoTarjeta.aprendiendo);
    });
  });

  group('Fichas de repaso', () {
    test('[spaced-review] Escenario: Intervalo creciente', () {
      final intentos = <Attempt>[intento(t: dia(0), correcto: false)];
      var fichas = proyectarFichas(intentos);
      for (var i = 0; i < 3; i++) {
        final vence = fichas.values.single.vence;
        intentos.add(intento(t: vence.add(const Duration(hours: 9)), responseMs: 20000, modo: SessionMode.review));
        fichas = proyectarFichas(intentos);
      }
      final h = fichas.values.single.historialIntervalos;
      // Fallo inicial y tres aciertos consecutivos en repaso.
      expect(h.length, 4);
      expect(h[2], greaterThan(h[1]));
      expect(h[3], greaterThan(h[2]));
    });

    test('[spaced-review] Escenario: Error crítico', () {
      final a = intento(t: dia(0, 18), correcto: false, critico: true, errorCode: 'E2');
      final f = proyectarFichas([a]).values.single;
      expect(f.vence, DateTime(2026, 11, 17));
      expect(f.cuarentena, isTrue);
      expect(f.critica, isTrue);
    });

    test('[spaced-review] Escenario: Salida de la cuarentena', () {
      final fallo = intento(t: dia(0), correcto: false, critico: true, errorCode: 'E2');
      final ayer = intento(t: dia(1), responseMs: 20000, modo: SessionMode.review);
      var f = proyectarFichas([fallo, ayer]).values.single;
      expect(f.cuarentena, isTrue, reason: 'un solo acierto no basta');
      expect(f.vence, DateTime(2026, 11, 18), reason: 'en cuarentena no alarga el intervalo');
      final hoy = intento(t: dia(2), responseMs: 20000, modo: SessionMode.review);
      f = proyectarFichas([fallo, ayer, hoy]).values.single;
      expect(f.cuarentena, isFalse);
      expect(f.card.intervaloDias, greaterThan(1));
    });

    test('Dos aciertos el mismo día no sacan de la cuarentena', () {
      final fallo = intento(t: dia(0), correcto: false, critico: true);
      final f = proyectarFichas([
        fallo,
        intento(t: dia(1, 9), modo: SessionMode.review),
        intento(t: dia(1, 20), modo: SessionMode.review),
      ]).values.single;
      expect(f.cuarentena, isTrue);
    });

    test('Un acierto al primer intento sin fallo previo no crea ficha y la prueba de nivel no cuenta', () {
      expect(proyectarFichas([intento(t: dia(0))]), isEmpty);
      expect(proyectarFichas([intento(t: dia(0), correcto: false, modo: SessionMode.placement)]), isEmpty);
    });

    test('[answer-grading] Escenario: Segundo intento acertado (el fallo sigue en repaso)', () {
      final f = proyectarFichas([
        intento(t: dia(0), correcto: false),
        intento(t: dia(0, 10, 1), numero: 2),
      ]);
      expect(f, hasLength(1));
      expect(f.values.single.vence, DateTime(2026, 11, 17));
    });

    test('[time-trial] Escenario: Fallo en el esprint (la plantilla pasa al repaso)', () {
      final f = proyectarFichas([intento(t: dia(0), correcto: false, modo: SessionMode.timetrial, plantilla: 'tpl-crono')]);
      expect(f.keys.single, 'tpl-crono@1');
    });

    test('[spaced-review] Escenario: Variante nueva en el repaso', () {
      final fallo = intento(t: dia(0), correcto: false, variante: 'perro-24kg');
      final f = proyectarFichas([fallo]).values.single;
      expect(elegirVarianteRepaso(f, ['perro-24kg', 'perro-18kg', 'gato-4kg']), 'perro-18kg');
    });

    test('[spaced-review] Escenario: Motivo de la ficha', () {
      // Martes 17 de noviembre de 2026.
      final fallo = intento(t: dia(1), correcto: false, errorCode: 'E1');
      final f = proyectarFichas([fallo]).values.single;
      expect(motivoFicha(f, dia(4)), 'Fallaste esta el martes: unidad.');
      expect(motivoFicha(f, dia(2)), 'Fallaste esta ayer: unidad.');
    });
  });

  group('Cola diaria', () {
    List<Attempt> fallos(int n, {int criticos = 0}) => [
          for (var i = 0; i < n; i++)
            intento(
              t: dia(0, 8, i),
              plantilla: 'tpl-$i',
              correcto: false,
              critico: i >= n - criticos,
              errorCode: i >= n - criticos ? 'E2' : 'E4',
            ),
        ];

    test('[spaced-review] Escenario: Tope por defecto', () {
      final fichas = proyectarFichas(fallos(35));
      final cola = colaDeHoy(fichas.values, dia(3));
      expect(cola, hasLength(20));
      expect(colaDeHoy(fichas.values, dia(3), tope: 5), hasLength(10), reason: 'el tope mínimo es 10');
      expect(colaDeHoy(fichas.values, dia(3), tope: 99), hasLength(35), reason: 'el tope máximo es 40');
    });

    test('[spaced-review] Escenario: Orden de la cola', () {
      final intentos = [
        ...fallos(6, criticos: 2),
        // Una ordinaria más antigua, más vencida.
        intento(t: dia(-5), plantilla: 'tpl-antigua', correcto: false),
      ];
      final cola = colaDeHoy(proyectarFichas(intentos).values, dia(3));
      expect(cola.take(2).every((f) => f.critica), isTrue);
      expect(cola[2].clave, 'tpl-antigua@1');
    });

    test('[spaced-review] Escenario: Cola vacía', () {
      final fichas = proyectarFichas([intento(t: dia(0), correcto: false)]);
      expect(colaDeHoy(fichas.values, dia(0, 20)), isEmpty);
      final p = proximoRepaso(fichas.values, dia(0, 20));
      expect(p!.fecha, DateTime(2026, 11, 17));
      expect(p.fichas, 1);
    });

    test('[spaced-review] Escenario: Programación sin conexión', () {
      // Todo se calcula en el dispositivo a partir de los intentos locales.
      final fichas = proyectarFichas([
        intento(t: dia(0), correcto: false),
        intento(t: dia(1), modo: SessionMode.review),
      ]);
      expect(fichas.values.single.vence.isAfter(dia(1)), isTrue);
    });
  });

  group('Sesión de repaso', () {
    test('[spaced-review] Escenario: Ficha fallada en el repaso', () {
      final cola = ColaSesionRepaso(['a', 'b', 'c']);
      cola.responder(acierto: false); // a vuelve al final
      expect(cola.orden, ['b', 'c', 'a']);
      cola.responder(acierto: true); // b sale
      cola.responder(acierto: true); // c sale
      cola.responder(acierto: false); // a vuelve (segunda vez)
      expect(cola.orden, ['a']);
      cola.responder(acierto: false); // tercera vez: ya no vuelve
      expect(cola.terminada, isTrue);
      expect(cola.resueltas, ['b', 'c']);
      expect(cola.pendientes, ['a']);
    });
  });

  test('La fecha de vencimiento es el inicio del día local', () {
    final f = proyectarFichas([intento(t: dia(0, 23, 59), correcto: false)]).values.single;
    expect(f.vence, diaLocal(dia(1)));
  });
}
