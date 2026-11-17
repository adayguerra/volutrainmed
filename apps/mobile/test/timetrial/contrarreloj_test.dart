import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/ui/pausa_promocional.dart';
import 'package:volutrainmed/features/timetrial/data/controlador_crono.dart';
import 'package:volutrainmed/features/timetrial/domain/timetrial.dart';

import '../helpers/arnes.dart';
import 'soporte_crono.dart';

void main() {
  setUpAll(cargarContenidoDePrueba);

  Future<Arnes> abrir(WidgetTester t, {List<Attempt>? intentos, List<SessionRecord> sesiones = const [], bool premium = true, Ajustes? ajustes, bool conexion = true, EstadoUsuario? usuario, ApiSync? api}) async {
    final a = Arnes(
      intentos: intentos ?? intentosConsolidanH1(),
      sesiones: sesiones,
      derechos: premium ? premiumHoy() : null,
      ajustes: ajustes,
      conexion: conexion,
      usuario: usuario,
      http: api?.call,
    );
    await a.montar(t, ruta: Rutas.contrarreloj);
    return a;
  }

  Future<void> empezarH1(WidgetTester t) async {
    await t.ensureVisible(find.byKey(const ValueKey('empezar-H1')));
    await t.tap(find.byKey(const ValueKey('empezar-H1')));
    await asentarPoco(t);
  }

  List<SessionRecord> sesionesCrono(Arnes a) =>
      (a.contenedor.read(aprendizajeProvider).value!.sesiones).where((s) => s.mode == SessionMode.timetrial || s.mode == SessionMode.timetrialUntimed).toList();

  group('time-trial', () {
    testWidgets('time-trial · Habilidad sin consolidar: la app indica que debe consolidarla antes y cómo conseguirlo', (t) async {
      await abrir(t, intentos: [...intentosConsolidanH1(), ...intentosH2EnAprendizaje()]);
      expect(find.byKey(const ValueKey('empezar-H2')), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('habilidad-H2')));
      await t.tap(find.byKey(const ValueKey('habilidad-H2')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('explicacion-consolidar')), findsOneWidget);
      expect(find.text(explicacionConsolidar), findsOneWidget);
    });

    testWidgets('time-trial · Sin ninguna habilidad consolidada: ve «Consolida una habilidad para abrir el contrarreloj»', (t) async {
      await abrir(t, intentos: const []);
      expect(find.text(mensajeSinHabilidadConsolidada), findsOneWidget);
      expect(find.textContaining('Empezar'), findsNothing);
    });

    testWidgets('time-trial · Acierto en el esprint: el siguiente aparece de inmediato, sin banda de veredicto', (t) async {
      final a = await abrir(t);
      await empezarH1(t);
      final primero = crono.actual.id;
      expect(crono.actual.skillId, 'H1');
      a.avanzarMs(2000);
      await responderCrono(t, bien: true);
      expect(crono.respondidos, 1);
      expect(crono.actual.id, isNot(primero));
      expect(crono.actual.skillId, 'H1', reason: 'una sola habilidad');
      expect(find.byKey(const ValueKey('fallo-crono')), findsNothing);
      expect(find.text('Correcto'), findsNothing);
      expect(find.byKey(const ValueKey('reloj-crono')), findsOneWidget);
    });

    testWidgets('time-trial · Fallo con 20 segundos restantes: el reloj pasa a 17 segundos y el multiplicador vuelve a su valor inicial', (t) async {
      final a = await abrir(t);
      await empezarH1(t);
      a.avanzarMs(1000);
      await responderCrono(t, bien: true);
      a.avanzarMs(1000);
      await responderCrono(t, bien: true);
      expect(crono.multiplicador, greaterThan(1));
      a.avanzarMs(38000);
      await t.pump(const Duration(milliseconds: 150));
      expect(find.text('0:20'), findsOneWidget);
      final v = crono.actual;
      final esNum = crono.bloque == 'numeric_unit';
      if (esNum) {
        await t.tap(find.byKey(const ValueKey('tecla-9')));
        await t.tap(find.byKey(const ValueKey('tecla-9')));
        await t.tap(find.byKey(const ValueKey('tecla-7')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('comprobar-crono')));
      } else {
        await t.tap(find.byKey(ValueKey('opcion-${v.options!.firstWhere((o) => !o.correct).id}')));
      }
      await t.pump(const Duration(milliseconds: 150));
      expect(find.text('0:17'), findsOneWidget);
      expect(crono.multiplicador, 1.0);
      expect(find.byKey(const ValueKey('fallo-crono')), findsOneWidget);
      expect(find.textContaining('Era '), findsOneWidget, reason: 'muestra la respuesta correcta');
      await t.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const ValueKey('fallo-crono')), findsNothing, reason: 'tras 1,2 s llega el siguiente');
    });

    testWidgets('time-trial · Marca no válida: 12 aciertos y 3 fallos muestran el 80 % y no sustituyen al récord', (t) async {
      final a = await abrir(t, sesiones: [marcaAnterior(10)]);
      await empezarH1(t);
      for (var i = 0; i < 15; i++) {
        a.avanzarMs(1500);
        await responderCrono(t, bien: i % 5 != 4);
      }
      a.avanzarMs(60000);
      await asentarPoco(t);
      expect(find.text('Marca no válida: precisión del 80 %. La rapidez solo cuenta con precisión'), findsOneWidget);
      expect(find.byKey(const ValueKey('nuevo-record')), findsNothing);
      final sesiones = sesionesCrono(a);
      expect(sesiones.where((s) => s.id == crono.sessionId).single.summary!.valid, isFalse);
      expect(mejorMarcaValida(sesiones, 'H1'), 10, reason: 'la marca no válida no sustituye al récord');
    });

    testWidgets('time-trial · Récord: 15 aciertos sin fallos superan la mejor marca y se registra el nuevo récord', (t) async {
      final a = await abrir(t, sesiones: [marcaAnterior(14)]);
      await empezarH1(t);
      for (var i = 0; i < 15; i++) {
        a.avanzarMs(2000);
        await responderCrono(t, bien: true);
      }
      a.avanzarMs(60000);
      await asentarPoco(t);
      expect(find.byKey(const ValueKey('nuevo-record')), findsOneWidget);
      expect(find.text('15 aciertos'), findsOneWidget);
      expect(find.text('Anterior: 14'), findsOneWidget);
      expect(mejorMarcaValida(sesionesCrono(a), 'H1'), 15);
    });

    testWidgets('time-trial · Interrupción: una llamada anula el esprint, no se registra marca y se explica al volver', (t) async {
      final a = await abrir(t);
      await empezarH1(t);
      a.avanzarMs(2000);
      await responderCrono(t, bien: true);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      a.avanzarMs(30000);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await asentarPoco(t);
      expect(find.text(motivoInterrupcion), findsOneWidget);
      expect(sesionesCrono(a), isEmpty, reason: 'no se registra marca');
      expect(crono.resultado().anulado, isTrue);
    });

    testWidgets('time-trial · Ejercicios sin límite de tiempo: serie sin cuenta atrás y tiempo medio al final', (t) async {
      final a = await abrir(t, ajustes: const Ajustes(sinLimiteTiempo: true));
      expect(find.textContaining('Ejercicios sin límite de tiempo'), findsOneWidget);
      await empezarH1(t);
      expect(find.byKey(const ValueKey('reloj-crono')), findsNothing, reason: 'sin cuenta atrás');
      expect(crono.sinCuentaAtras, isTrue);
      for (var i = 0; i < ejerciciosSerieSinLimite; i++) {
        a.avanzarMs(3000);
        await responderCrono(t, bien: true);
      }
      await asentarPoco(t);
      expect(find.text('Tiempo medio: 3 s'), findsOneWidget);
      final s = sesionesCrono(a).single;
      expect(s.mode, SessionMode.timetrialUntimed);
      expect(s.summary!.avgMs, 3000);
    });

    testWidgets('time-trial · Fallo en el esprint: la plantilla del ejercicio fallado aparece en su repaso', (t) async {
      final a = await abrir(t);
      await empezarH1(t);
      final fallado = crono.actual;
      a.avanzarMs(2000);
      await responderCrono(t, bien: false);
      final proy = a.contenedor.read(proyeccionProvider)!;
      final clave = '${fallado.itemKey}@${fallado.level}';
      expect(proy.fichas.containsKey(clave), isTrue);
      expect(crono.intentos.single.mode, SessionMode.timetrial);
      expect(a.aprendizaje.intentos(), completion(contains(predicate<Attempt>((x) => x.variantId == fallado.id && !x.correct))));
    });

    testWidgets('time-trial · Esprint sin conexión: la marca se guarda en el dispositivo y se sincroniza al recuperar la conexión', (t) async {
      final api = ApiSync(enLinea: false);
      final a = await abrir(t, conexion: false, usuario: usuarioDePrueba(token: 'tok'), api: api);
      await empezarH1(t);
      for (var i = 0; i < 10; i++) {
        a.avanzarMs(2000);
        await responderCrono(t, bien: true);
      }
      a.avanzarMs(60000);
      await asentarPoco(t);
      final id = crono.sessionId;
      expect(sesionesCrono(a).single.id, id, reason: 'marca guardada en el dispositivo');
      final pendientes = await t.runAsync(() => a.aprendizaje.pendientes(ahora: DateTime(2100), kind: 'session'));
      expect(pendientes!.map((e) => e.refId), contains(id));
      expect(api.empujes, isEmpty, reason: 'sin conexión no se envía nada');
      api.enLinea = true;
      a.conectividad.conectado = true;
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(api.sesionesSubidas, contains(id));
      expect(await t.runAsync(() => a.aprendizaje.contarPendientes()), 0);
    });
  });

  group('house-ads', () {
    testWidgets('house-ads · Contrarreloj: sin pausa entre ejercicios y una única pausa al terminar el esprint, antes del resumen', (t) async {
      final a = await abrir(t, premium: false);
      await empezarH1(t);
      for (var i = 0; i < 5; i++) {
        a.avanzarMs(2000);
        await responderCrono(t, bien: true);
        expect(find.byType(PausaPromocional), findsNothing, reason: 'el siguiente aparece de inmediato');
      }
      a.avanzarMs(60000);
      await asentarPoco(t);
      expect(find.byType(PausaPromocional), findsOneWidget);
      expect(find.byKey(const ValueKey('otra-vez')), findsNothing, reason: 'el resumen va después');
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 500));
      }
      await t.tap(find.descendant(of: find.byType(PausaPromocional), matching: find.text('Continuar')));
      await asentarPoco(t);
      expect(find.byType(PausaPromocional), findsNothing);
      expect(find.byKey(const ValueKey('otra-vez')), findsOneWidget);
    });
  });
}
