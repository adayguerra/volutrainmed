import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/ui/pausa_promocional.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import 'fixtures_sesion.dart';
import 'ui_sesion.dart';

/// Fin de lección, celebraciones, repaso y pausas promocionales en la sesión.

int _n = 0;
Attempt semilla({
  String template = 'tpl-f-mg-ug',
  int level = 1,
  String skill = 'H1',
  bool acierto = true,
  int dias = 1,
  int puntos = 0,
  String? error,
}) =>
    Attempt(
      id: 'semilla-${_n++}',
      sessionId: 'sesion-semilla',
      deviceId: 'disp-prueba',
      mode: SessionMode.lesson,
      templateId: template,
      variantId: '$template.v1.L$level.semilla',
      skillId: skill,
      exerciseTypeId: 'T1',
      level: level,
      answerValue: '1',
      answerUnit: 'ml',
      verdict: acierto ? Verdict.correct : Verdict.incorrect,
      errorCode: error,
      responseMs: 8000,
      targetMs: 15000,
      points: puntos,
      contentVersion: '2026.11.0',
      deviceTime: ahoraPrueba.subtract(Duration(days: dias, minutes: _n)),
    );

/// Responde mal: con un error previsible si el ejercicio numérico lo tiene.
Future<bool> responderMalUI(WidgetTester t) async {
  final e = motor.actual!;
  final p = e.variante.predictedErrors;
  if (e.bloque == 'numeric_unit' && p.isNotEmpty && !e.unidadAElegir) {
    await teclear(t, formatEs(p.first.value));
    await comprobar(t);
    return true;
  }
  await noLoSeUI(t);
  return false;
}

Future<void> cerrarPausaSiHay(WidgetTester t) async {
  if (find.byType(PausaPromocional).evaluate().isNotEmpty) {
    await tocar(t, find.descendant(of: find.byType(PausaPromocional), matching: find.text('Continuar')));
  }
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('Fin de lección', () {
    testWidgets('gamification-progress · Lección con fallos: «Lección completada: 2 fichas van a repaso», cifras y fallos con su tipo', (t) async {
      final a = arnesSesion();
      await a.montar(t, ruta: Rutas.leccion('u-f-1-l3'));
      var fallados = 0;
      for (var i = 0; i < 10; i++) {
        final e = motor.actual!;
        final conPrevisto = e.bloque == 'numeric_unit' && e.variante.predictedErrors.isNotEmpty && !e.unidadAElegir;
        if (fallados < 2 && conPrevisto) {
          await responderMalUI(t);
          fallados++;
        } else {
          await responderBienUI(t);
        }
        await continuar(t);
      }
      expect(fallados, 2);
      expect(find.text('Lección completada: 2 fichas van a repaso'), findsOneWidget);
      expect(find.text('8 de 10'), findsOneWidget);
      expect(find.bySemanticsLabel('Precisión 80 %'), findsOneWidget);
      expect(find.bySemanticsLabel('Puntos +80'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Tiempo medio .* objetivo')), findsOneWidget);
      await t.scrollUntilVisible(find.text('FALLOS'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('FALLOS'), findsOneWidget);
      final codigos = motor.fallos.map((f) => f.errorCode).toList();
      expect(codigos.every((c) => c != null), isTrue);
      for (final f in motor.fallos) {
        await t.scrollUntilVisible(find.textContaining('${f.errorCode} · '), 200, scrollable: find.byType(Scrollable).first);
        expect(find.textContaining('${f.errorCode} · '), findsWidgets);
      }
    });

    testWidgets('gamification-progress · Cambio de estado de una habilidad: el fin de lección indica que pasa a «consolidada»', (t) async {
      final a = arnesSesion(intentos: [for (var i = 0; i < 19; i++) semilla()]);
      await a.montar(t, ruta: Rutas.leccion('l-h1'));
      await responderBienUI(t);
      await continuar(t);
      expect(find.text('Habilidad consolidada'), findsOneWidget, reason: 'hito');
      await tocar(t, find.byKey(const ValueKey('hito')));
      expect(find.text('HABILIDADES QUE CAMBIAN'), findsOneWidget);
      expect(find.text('En aprendizaje'), findsOneWidget);
      expect(find.text('Consolidada'), findsOneWidget);
      expect(find.text(contenidoPrueba.global.skillName('H1')), findsWidgets);
    });

    testWidgets('gamification-progress · Subida de nivel: celebración de 1,2 s como máximo al terminar la lección', (t) async {
      final a = arnesSesion(intentos: [semilla(skill: 'H7', puntos: 95)]);
      await a.montar(t, ruta: Rutas.leccion('l-vol'));
      await responderBienUI(t);
      await tocar(t, find.byKey(const ValueKey('continuar')));
      expect(find.text('Subes al nivel 2'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1200));
      expect(find.byKey(const ValueKey('celebracion-nivel')), findsNothing, reason: '1,2 s como máximo');
      expect(find.text('Nivel 2'), findsOneWidget);
    });

    testWidgets('la celebración de nivel se ve y se cierra con un toque', (t) async {
      final a = arnesSesion(intentos: [semilla(skill: 'H7', puntos: 95)]);
      await a.montar(t, ruta: Rutas.leccion('l-vol'));
      await responderBienUI(t);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Subes al nivel 2'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('celebracion-nivel')));
      await t.pump();
      expect(find.byKey(const ValueKey('celebracion-nivel')), findsNothing);
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('adaptive-accessible-ui · Fin de lección con movimiento reducido: cifras con su valor final, sin conteo ni celebración', (t) async {
      final a = arnesSesion(intentos: [semilla(skill: 'H7', puntos: 95)]);
      await a.montar(t, ruta: Rutas.leccion('l-vol'), movimientoReducido: true);
      await responderBienUI(t);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await t.pump();
      await t.pump();
      expect(find.byType(TweenAnimationBuilder<int>), findsNothing);
      expect(find.text('+10'), findsOneWidget);
      expect(find.text('100 %'), findsOneWidget);
      expect(find.byKey(const ValueKey('celebracion-nivel')), findsNothing);
      expect(find.text('Nivel 2'), findsOneWidget);
    });

    testWidgets('tras la primera lección sin cuenta se ofrece crearla', (t) async {
      final a = arnesSesion(usuario: usuarioDePrueba(primeraLeccion: false));
      await a.montar(t, ruta: Rutas.leccion('l-vol'));
      await responderBienUI(t);
      await continuar(t);
      await tocar(t, find.byKey(const ValueKey('continuar-fin')));
      expect(a.ubicacion.ruta, Rutas.cuenta);
      expect(a.contenedor.read(usuarioProvider).value!.primeraLeccionHecha, isTrue);
      expect((await a.aprendizaje.sesiones()).single.completed, isTrue);
    });
  });

  group('Repaso', () {
    List<Attempt> fallosAyer() => [
          semilla(template: 'tpl-f-mg-ug', acierto: false, error: 'E2'),
          semilla(template: 'tpl-f-g-mg', acierto: false, error: 'E2'),
        ];

    testWidgets('spaced-review · Motivo de la ficha: la pantalla indica cuándo se falló y con qué tipo de error', (t) async {
      final a = arnesSesion(intentos: fallosAyer());
      await a.montar(t, ruta: Rutas.sesionRepaso());
      expect(motor.modo, SessionMode.review);
      expect(find.text('Fallaste esta ayer: orden de magnitud.'), findsOneWidget);
    });

    testWidgets('spaced-review · Ficha fallada en el repaso: ve la explicación y la ficha reaparece al final', (t) async {
      final a = arnesSesion(intentos: fallosAyer());
      await a.montar(t, ruta: Rutas.sesionRepaso());
      final primera = motor.actual!.ficha!.clave;
      await noLoSeUI(t);
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
      await continuar(t);
      expect(motor.actual!.ficha!.clave, isNot(primera));
      await responderBienUI(t);
      await continuar(t);
      expect(motor.actual!.ficha!.clave, primera, reason: 'vuelve al final de la sesión');
      await responderBienUI(t);
      await continuar(t);
      expect(find.text('Repaso terminado'), findsOneWidget);
      expect((await a.aprendizaje.intentos()).where((i) => i.mode == SessionMode.review), hasLength(3));
    });
  });

  group('Pausa promocional en la sesión', () {
    testWidgets('house-ads · Último ejercicio de la lección: pausa al cerrar la corrección y después el fin de lección', (t) async {
      final a = arnesSesion(premium: false);
      await a.montar(t, ruta: Rutas.leccion('l-vol'));
      await responderBienUI(t);
      expect(find.byType(PausaPromocional), findsNothing);
      await continuar(t);
      expect(find.byType(PausaPromocional), findsOneWidget);
      await cerrarPausaSiHay(t);
      expect(find.byKey(const ValueKey('titulo-fin')), findsOneWidget);
    });

    testWidgets('house-ads · Respuesta incorrecta con explicación: veredicto, respuesta y explicación sin anuncio; la pausa llega al continuar', (t) async {
      final a = arnesSesion(premium: false);
      await a.montar(t, ruta: Rutas.leccion('l-dos'));
      await teclear(t, '2');
      await comprobar(t);
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
      expect(find.byType(PausaPromocional), findsNothing);
      await continuar(t);
      expect(find.byType(PausaPromocional), findsOneWidget);
      await cerrarPausaSiHay(t);
      expect(find.textContaining('noradrenalina'), findsWidgets);
    });

    testWidgets('sin pausas durante la primera lección tras el alta', (t) async {
      final a = arnesSesion(premium: false, usuario: usuarioDePrueba(primeraLeccion: false));
      await a.montar(t, ruta: Rutas.leccion('l-dos'));
      await responderBienUI(t);
      await continuar(t);
      expect(find.byType(PausaPromocional), findsNothing);
      expect(motor.actual!.variante.templateId, 'tpl-nora');
    });

    testWidgets('premium-subscription · Compra a mitad de lección: tras comprar en el ejercicio 3 no hay más pausas', (t) async {
      final a = arnesSesion(premium: false);
      await a.montar(t, ruta: Rutas.leccion('u-f-1-l3'));
      for (var i = 0; i < 2; i++) {
        await noLoSeUI(t);
        await continuar(t);
        expect(find.byType(PausaPromocional), findsOneWidget);
        await cerrarPausaSiHay(t);
      }
      await noLoSeUI(t);
      await continuar(t);
      expect(find.byType(PausaPromocional), findsOneWidget);
      // Compra desde la acción del anuncio: los derechos pasan a Premium.
      await a.contenedor.read(derechosProvider.notifier).guardar(premiumActivo(ahoraPrueba));
      await cerrarPausaSiHay(t);
      for (var i = 3; i < 10; i++) {
        await noLoSeUI(t);
        await continuar(t);
        expect(find.byType(PausaPromocional), findsNothing, reason: 'ejercicio ${i + 1}');
      }
      expect(motor.fase, FaseSesion.terminada);
    });

    testWidgets('premium-subscription · Lección completa con Premium: de cada corrección al siguiente sin ninguna pausa', (t) async {
      final a = arnesSesion(premium: true);
      await a.montar(t, ruta: Rutas.leccion('u-f-1-l3'));
      for (var i = 0; i < 10; i++) {
        await noLoSeUI(t);
        await continuar(t);
        expect(find.byType(PausaPromocional), findsNothing);
      }
      expect(find.byKey(const ValueKey('titulo-fin')), findsOneWidget);
      expect(motor.tiempoAnunciosMs, 0);
    });

    testWidgets('organizations · Miembro de una organización: con plaza activa no ve ninguna pausa promocional', (t) async {
      final org = Entitlements(
        premium: true,
        noAds: true,
        source: 'organization',
        plan: 'organization',
        status: 'active',
        validatedAt: ahoraPrueba,
        organization: const OrganizationRef(id: 'org-1', name: 'Facultad de Enfermería', nominal: false),
      );
      final a = arnesSesion(derechos: org, premium: false);
      await a.montar(t, ruta: Rutas.leccion('l-dos'));
      for (var i = 0; i < 2; i++) {
        await responderBienUI(t);
        await continuar(t);
        expect(find.byType(PausaPromocional), findsNothing);
      }
      expect(find.byKey(const ValueKey('titulo-fin')), findsOneWidget);
    });

    testWidgets('organizations · Miembro sin conexión: plaza validada hace 10 días y sin conexión, sigue sin pausas', (t) async {
      final org = Entitlements(
        premium: true,
        noAds: true,
        source: 'organization',
        plan: 'organization',
        status: 'active',
        validatedAt: ahoraPrueba.subtract(const Duration(days: 10)),
        organization: const OrganizationRef(id: 'org-1', name: 'Hospital', nominal: false),
      );
      final a = arnesSesion(derechos: org, premium: false, conexion: false);
      await a.montar(t, ruta: Rutas.leccion('l-dos'));
      for (var i = 0; i < 2; i++) {
        await responderBienUI(t);
        await continuar(t);
        expect(find.byType(PausaPromocional), findsNothing);
      }
      expect(find.byKey(const ValueKey('titulo-fin')), findsOneWidget);
    });
  });
}
