import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/motor_voz_sistema.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';

import '../helpers/arnes.dart';

/// Doble del reconocedor de la plataforma: registra cómo se le llama y deja
/// que la prueba emita resultados, niveles de sonido y errores.
class ReconocedorFalso implements ReconocedorPlataforma {
  ReconocedorFalso({this.local = true, this.inicializa = true, this.fallaAlEscuchar = false});
  bool local;
  bool inicializa;
  bool fallaAlEscuchar;
  final consultas = <String>[];
  final escuchas = <({String locale, bool soloEnDispositivo, Duration pausa})>[];
  int inicializaciones = 0;
  int paradas = 0;
  void Function(ResultadoReconocido)? resultado;
  void Function(double)? nivel;
  void Function(String)? error;
  void Function(String)? estado;

  @override
  Future<bool> soportaLocal(String etiquetaLocale) async {
    consultas.add(etiquetaLocale);
    return local;
  }

  @override
  Future<bool> inicializar({required void Function(String error) alError, required void Function(String estado) alEstado}) async {
    inicializaciones++;
    error = alError;
    estado = alEstado;
    return inicializa;
  }

  @override
  Future<void> escuchar({
    required String locale,
    required bool soloEnDispositivo,
    required Duration pausa,
    required Duration maximo,
    required void Function(ResultadoReconocido r) alResultado,
    required void Function(double nivel) alNivel,
  }) async {
    if (fallaAlEscuchar) throw StateError('on device recognition is not supported on this device');
    escuchas.add((locale: locale, soloEnDispositivo: soloEnDispositivo, pausa: pausa));
    resultado = alResultado;
    nivel = alNivel;
  }

  @override
  Future<void> parar() async => paradas++;
}

void main() {
  /// Abre una escucha dentro de un reloj simulado y devuelve lo emitido.
  List<EventoVoz> escuchar(FakeAsync fa, MotorDeVozSistema m, void Function() guion, {Duration espera = const Duration(seconds: 8)}) {
    final eventos = <EventoVoz>[];
    m.escuchar().listen(eventos.add);
    fa.flushMicrotasks();
    guion();
    fa.elapse(espera);
    return eventos;
  }

  MotorDeVozSistema motor(ReconocedorFalso r, FakeAsync fa) => MotorDeVozSistema(reconocedor: r, umbralRuido: 8.5, relojMs: () => fa.elapsed.inMilliseconds);

  group('Motor de voz del sistema: solo en el dispositivo', () {
    test('sin reconocimiento local el motor no está disponible, no escucha y explica el teclado', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso(local: false);
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        expect(m.disponible, isFalse);
        expect(m.motivoNoDisponible, contains('teclado'));
        expect(m.motivoNoDisponible, contains('no usamos reconocimiento en la nube'));
        final ev = escuchar(fa, m, () {});
        expect(ev, isEmpty);
        expect(r.escuchas, isEmpty, reason: 'nunca se abre el micrófono');
        expect(r.inicializaciones, 0, reason: 'ni se piden permisos');
      });
    });

    test('antes de preparar (o en la web) el motor no está disponible', () {
      final m = MotorDeVozSistema(reconocedor: ReconocedorFalso());
      expect(m.disponible, isFalse);
    });

    test('hands-free-voice · Sin tráfico de voz: siempre escucha con el reconocimiento forzado en el dispositivo y en es-ES', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        expect(m.disponible, isTrue);
        expect(r.consultas, ['es-ES']);
        for (var i = 0; i < 3; i++) {
          final ev = escuchar(fa, m, () => r.resultado!(const ResultadoReconocido(texto: 'cuatro coma ocho', esFinal: true, confianza: 0.93)));
          expect(ev.single, isA<VozTexto>());
        }
        expect(r.escuchas, hasLength(3));
        expect(r.escuchas.every((e) => e.soloEnDispositivo), isTrue, reason: 'nunca se escucha con onDevice a false');
        expect(r.escuchas.every((e) => e.locale == 'es_ES'), isTrue);
        expect(r.inicializaciones, 1, reason: 'los permisos se piden al escuchar por primera vez, no al arrancar');
      });
    });

    test('si el soporte local desaparece antes de escuchar, se niega a escuchar y pasa al teclado', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        r.local = false; // p. ej. el usuario desinstala el idioma sin conexión
        final ev = escuchar(fa, m, () {});
        expect(ev.single, isA<VozNoEntendida>());
        expect(r.escuchas, isEmpty);
        expect(m.disponible, isFalse);
      });
    });

    test('si el sistema rechaza la escucha local no se reintenta de otro modo', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso(fallaAlEscuchar: true);
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final ev = escuchar(fa, m, () {});
        expect(ev.single, isA<VozNoEntendida>());
        expect(m.disponible, isFalse);
        expect(r.escuchas, isEmpty);
      });
    });

    test('permiso denegado: el motor queda no disponible con su motivo', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso(inicializa: false);
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final ev = escuchar(fa, m, () {});
        expect(ev.single, isA<VozNoEntendida>());
        expect(m.disponible, isFalse);
        expect(m.motivoNoDisponible, contains('permiso'));
      });
    });
  });

  group('Motor de voz del sistema: eventos', () {
    test('el resultado final lleva texto, confianza, alternativas y tiempo desde el fin de la voz', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final eventos = <EventoVoz>[];
        m.escuchar().listen(eventos.add);
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        r.resultado!(const ResultadoReconocido(texto: 'cuatro coma', esFinal: false));
        fa.elapse(const Duration(milliseconds: 500));
        r.resultado!(const ResultadoReconocido(texto: 'cuatro coma ocho', esFinal: false));
        fa.elapse(const Duration(milliseconds: 600));
        r.resultado!(const ResultadoReconocido(texto: ' cuatro coma ocho ', esFinal: true, confianza: 0.9, alternativas: ['catorce coma ocho']));
        fa.elapse(const Duration(seconds: 10));
        final v = eventos.single as VozTexto;
        expect(v.texto, 'cuatro coma ocho');
        expect(v.confianza, 0.9);
        expect(v.alternativas, ['catorce coma ocho']);
        expect(v.ms, 600);
        expect(r.paradas, greaterThan(0), reason: 'el micrófono se cierra al terminar el turno');
      });
    });

    test('hands-free-voice · Silencio: seis segundos sin voz emiten silencio', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final eventos = <EventoVoz>[];
        m.escuchar().listen(eventos.add);
        fa.flushMicrotasks();
        fa.elapse(const Duration(milliseconds: 5900));
        expect(eventos, isEmpty);
        fa.elapse(const Duration(milliseconds: 200));
        expect(eventos.single, isA<VozSilencio>());
      });
    });

    test('con voz ya empezada, el temporizador de silencio no corta la escucha', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final eventos = <EventoVoz>[];
        m.escuchar().listen(eventos.add);
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 5));
        r.resultado!(const ResultadoReconocido(texto: 'dos', esFinal: false));
        fa.elapse(const Duration(seconds: 3));
        expect(eventos, isEmpty);
        r.resultado!(const ResultadoReconocido(texto: 'dos y medio', esFinal: true));
        fa.flushMicrotasks();
        expect((eventos.single as VozTexto).texto, 'dos y medio');
      });
    });

    test('hands-free-voice · Entorno ruidoso: nivel alto antes de hablar emite ruido', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final eventos = <EventoVoz>[];
        m.escuchar().listen(eventos.add);
        fa.flushMicrotasks();
        for (var i = 0; i < 10; i++) {
          r.nivel!(9.5);
          fa.elapse(const Duration(milliseconds: 100));
        }
        expect(eventos.single, isA<VozRuido>());
      });
    });

    test('un nivel de sonido normal no se toma por ruido', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final eventos = <EventoVoz>[];
        m.escuchar().listen(eventos.add);
        fa.flushMicrotasks();
        for (var i = 0; i < 10; i++) {
          r.nivel!(2);
          fa.elapse(const Duration(milliseconds: 100));
        }
        expect(eventos, isEmpty);
      });
    });

    test('los errores del reconocedor se convierten en «no entendida» o en silencio', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        var ev = escuchar(fa, m, () => r.error!('error_no_match'), espera: const Duration(seconds: 1));
        expect(ev.single, isA<VozSilencio>(), reason: 'sin voz detectada');
        ev = escuchar(fa, m, () {
          r.resultado!(const ResultadoReconocido(texto: 'mmm', esFinal: false));
          r.error!('error_no_match');
        }, espera: const Duration(seconds: 1));
        expect(ev.single, isA<VozNoEntendida>());
        ev = escuchar(fa, m, () => r.error!('error_audio_error'), espera: const Duration(seconds: 1));
        expect(ev.single, isA<VozNoEntendida>());
        expect(m.disponible, isTrue);
        // Idioma local no instalado: deja de estar disponible (nunca la nube).
        ev = escuchar(fa, m, () => r.error!('error_language_unavailable'), espera: const Duration(seconds: 1));
        expect(ev.single, isA<VozNoEntendida>());
        expect(m.disponible, isFalse);
      });
    });

    test('la escucha que termina sin resultado final se cierra sola', () {
      fakeAsync((fa) {
        final r = ReconocedorFalso();
        final m = motor(r, fa);
        m.preparar();
        fa.flushMicrotasks();
        final ev = escuchar(fa, m, () {
          r.resultado!(const ResultadoReconocido(texto: 'cua', esFinal: false));
          r.estado!('done');
        }, espera: const Duration(seconds: 1));
        expect(ev.single, isA<VozNoEntendida>());
      });
    });
  });

  group('Prueba de micrófono (ajustes de voz)', () {
    setUpAll(cargarContenidoDePrueba);

    testWidgets('dice «cuatro coma ocho mililitros por hora» y ve la cifra entendida', (t) async {
      final a = Arnes(
        motorVoz: MotorDeVozGuionado(const [VozTexto('cuatro coma ocho mililitros por hora')]),
        permisos: PermisosFalsos(microfono: EstadoPermiso.concedido),
      );
      await a.montar(t, ruta: Rutas.voz);
      final boton = find.byKey(const ValueKey('probar-microfono'));
      await t.scrollUntilVisible(boton, 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(boton);
      await t.pumpAndSettle();
      await t.tap(boton);
      await Arnes.asentar(t);
      expect(find.textContaining(RegExp(r'Entendido: 4,8\sml/h')), findsOneWidget);
      expect(a.peticionesSinContenido, isEmpty, reason: 'la prueba no usa la red');
    });

    testWidgets('sin reconocimiento en el dispositivo la prueba explica el teclado y no hay botón', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: Rutas.voz);
      expect(find.byKey(const ValueKey('probar-microfono')), findsNothing);
      expect(find.textContaining('teclado'), findsWidgets);
    });

    testWidgets('sin permiso de micrófono la prueba lo explica y no escucha', (t) async {
      final voz = MotorDeVozGuionado(const [VozTexto('cuatro coma ocho')]);
      final a = Arnes(motorVoz: voz, permisos: PermisosFalsos(respuestaMicrofono: EstadoPermiso.denegado));
      await a.montar(t, ruta: Rutas.voz);
      final boton = find.byKey(const ValueKey('probar-microfono'));
      await t.scrollUntilVisible(boton, 300, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(boton);
      await t.pumpAndSettle();
      await t.tap(boton);
      await Arnes.asentar(t);
      expect(find.textContaining('Sin permiso de micrófono'), findsOneWidget);
      expect(voz.escuchas, 0);
    });
  });
}
