import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/features/timetrial/domain/timetrial.dart';

void main() {
  group('Elegibilidad', () {
    test('[time-trial] Escenario: Habilidad sin consolidar', () {
      final e = elegibilidad(EstadoHabilidadCrono.enAprendizaje);
      expect(e.abierta, isFalse);
      expect(e.mensaje, contains('Consolida esta habilidad'));
      expect(e.mensaje, contains('85 %'));
    });

    test('[time-trial] Escenario: Sin ninguna habilidad consolidada', () {
      expect(mensajeSeleccion({'H1': EstadoHabilidadCrono.nueva, 'H2': EstadoHabilidadCrono.enAprendizaje}),
          'Consolida una habilidad para abrir el contrarreloj');
      expect(mensajeSeleccion({'H1': EstadoHabilidadCrono.porRefrescar}), isNull);
      expect(elegibilidad(EstadoHabilidadCrono.dominada).abierta, isTrue);
      expect(elegibilidad(estadoCronoDesde('consolidada')).abierta, isTrue);
    });
  });

  group('Esprint', () {
    test('[time-trial] Escenario: Acierto en el esprint (siguiente inmediato y multiplicador)', () {
      final e = Esprint(inicioMs: 0);
      expect(e.responder(correcto: true, ahoraMs: 2000), isTrue);
      expect(e.mostrarCorrectaHasta, isNull);
      expect(e.multiplicador, 1.15);
      expect(e.puntos, 10);
      e.responder(correcto: true, ahoraMs: 4000);
      expect(e.puntos, 10 + 12); // 10 × 1,15 = 11,5 → 12
    });

    test('[time-trial] Escenario: Fallo con 20 segundos restantes', () {
      final e = Esprint(inicioMs: 0);
      e.responder(correcto: true, ahoraMs: 20000);
      e.responder(correcto: true, ahoraMs: 39000);
      expect(e.multiplicador, greaterThan(1));
      expect(e.restanteMs(40000), 20000);
      e.responder(correcto: false, ahoraMs: 40000);
      expect(e.restanteMs(40000), 17000);
      expect(e.multiplicador, 1.0);
      expect(e.mostrarCorrectaHasta, 41200);
    });

    test('el esprint dura 60 s y termina al llegar a 0', () {
      final e = Esprint(inicioMs: 1000);
      expect(e.terminado(60999), isFalse);
      expect(e.terminado(61000), isTrue);
      expect(e.responder(correcto: true, ahoraMs: 61500), isFalse);
    });

    test('[time-trial] Escenario: Marca no válida (12 aciertos y 3 fallos, 80 %)', () {
      final e = Esprint(inicioMs: 0, mejorMarcaValida: 10);
      var t = 0;
      for (var i = 0; i < 12; i++) {
        e.responder(correcto: true, ahoraMs: t += 1000);
      }
      for (var i = 0; i < 3; i++) {
        e.responder(correcto: false, ahoraMs: t += 1000);
      }
      final r = e.resultado();
      expect(r.precisionPct, 80);
      expect(r.valida, isFalse);
      expect(r.esRecord, isFalse);
      expect(r.mensajeNoValida, 'Marca no válida: precisión del 80 %. La rapidez solo cuenta con precisión');
    });

    test('[time-trial] Escenario: Récord (15 aciertos sin fallos)', () {
      final e = Esprint(inicioMs: 0, mejorMarcaValida: 14);
      for (var i = 1; i <= 15; i++) {
        e.responder(correcto: true, ahoraMs: i * 3000);
      }
      final r = e.resultado();
      expect(r.valida, isTrue);
      expect(r.esRecord, isTrue);
      expect(r.tiempoMedioMs, 3000);
    });

    test('[time-trial] Escenario: Interrupción', () {
      final e = Esprint(inicioMs: 0);
      e.responder(correcto: true, ahoraMs: 1000);
      e.interrumpir();
      final r = e.resultado();
      expect(r.anulado, isTrue);
      expect(r.valida, isFalse);
      expect(r.puntos, 0);
      expect(r.motivoAnulacion, contains('segundo plano'));
      expect(e.terminado(2000), isTrue);
    });

    test('el tiempo que se muestra la correcta no cuenta como tiempo de respuesta', () {
      final e = Esprint(inicioMs: 0);
      e.responder(correcto: false, ahoraMs: 2000);
      e.presentarSiguiente(3200);
      e.responder(correcto: true, ahoraMs: 5200);
      expect(e.resultado().tiempoMedioMs, (2000 + 2000) ~/ 2);
    });
  });

  test('[time-trial] Escenario: Ejercicios sin límite de tiempo', () {
    final s = SerieSinLimite(ejercicios: 3, inicioMs: 0);
    s.responder(correcto: true, ahoraMs: 70000);
    s.responder(correcto: true, ahoraMs: 100000);
    s.responder(correcto: false, ahoraMs: 120000);
    expect(s.terminada, isTrue);
    expect(s.tiempoMedioMs, 40000);
    expect(s.responder(correcto: true, ahoraMs: 130000), isFalse);
  });
}
