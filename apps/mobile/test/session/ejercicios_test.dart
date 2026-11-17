import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/widgets/teclado.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import 'fixtures_sesion.dart';
import 'ui_sesion.dart';

/// Sesión táctil: tipos de ejercicio, teclado propio, unidad, «No lo sé»,
/// salida, segundo plano y tiempos (exercise-session).
void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('exercise-session · Respuesta numérica: enunciado, campo con su unidad y teclado numérico propio', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'));
    expect(find.textContaining('Caso simulado'), findsOneWidget);
    expect(find.textContaining('A cuántos mililitros por hora'), findsOneWidget);
    expect(find.byType(CampoRespuesta), findsOneWidget);
    expect(find.descendant(of: find.byType(CampoRespuesta), matching: find.text('ml/h')), findsOneWidget);
    expect(find.byType(TecladoNumerico), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'sin teclado del sistema');
    for (final k in TecladoNumerico.teclas) {
      expect(t.getSize(find.byKey(ValueKey('tecla-$k'))).height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('exercise-session · Selección única con opciones diagnósticas: las falsas son errores previsibles y el orden cambia', (t) async {
    // En el contenido publicado, cada opción falsa lleva su tipo de error y
    // el orden de las opciones cambia entre variantes de una misma plantilla.
    final c = contenidoPrueba;
    final t2 = c.fundamentos!.variants.where((v) => v.exerciseTypeId == 'T2').toList();
    expect(t2, isNotEmpty);
    for (final v in t2) {
      for (final o in v.options!.where((o) => !o.correct)) {
        expect(o.errorCode, isNotNull, reason: '${v.id} opción ${o.label}');
      }
    }
    final porPlantilla = <String, Set<int>>{};
    for (final v in t2) {
      porPlantilla.putIfAbsent(v.itemKey, () => {}).add(v.options!.indexWhere((o) => o.correct));
    }
    expect(porPlantilla.values.any((s) => s.length > 1), isTrue, reason: 'la opción correcta cambia de posición entre variantes');

    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-t2'));
    for (final l in ['1 mg/ml', '0,1 mg/ml', '0,01 mg/ml', '10 mg/ml']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('comprobar'))).onPressed, isNull);
    await tocar(t, find.byKey(const ValueKey('opcion-a')));
    await comprobar(t);
    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.text('Esa es la concentración 1:1000.'), findsOneWidget);
    expect(find.text('E2 · Orden de magnitud'), findsOneWidget);
  });

  testWidgets('exercise-session · Ordenar pasos con equivalencias: cualquiera de los órdenes válidos es correcto', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-t3'));
    // Segundo orden válido declarado: c, a, b, d.
    for (final id in ['c', 'a', 'b', 'd']) {
      await tocar(t, find.byKey(ValueKey('paso-$id')));
    }
    await comprobar(t);
    expect(find.text('Correcto'), findsOneWidget);
    expect((await a.aprendizaje.intentos()).single.verdict, Verdict.correct);
  });

  testWidgets('adaptive-accessible-ui · Ordenar pasos sin arrastrar: tocar los pasos en orden los deja ordenados', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-t3'));
    await tocar(t, find.byKey(const ValueKey('paso-a')));
    await tocar(t, find.byKey(const ValueKey('paso-b')));
    expect(find.bySemanticsLabel(RegExp('^Posición 1: Multiplicar la dosis por el peso')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Posición 2: Multiplicar por 60')), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('deshacer')));
    expect(find.bySemanticsLabel(RegExp('^Posición 2, vacía')), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('paso-b')));
    await tocar(t, find.byKey(const ValueKey('paso-c')));
    await tocar(t, find.byKey(const ValueKey('paso-d')));
    expect(find.byType(Draggable), findsNothing, reason: 'no hace falta arrastrar');
    await comprobar(t);
    expect(find.text('Correcto'), findsOneWidget);
  });

  testWidgets('exercise-session · Conversión relámpago: serie de diez conversiones con 60 segundos en total', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-t7'));
    expect(motor.actual!.variante.series, hasLength(10));
    int restante() => int.parse(t.widget<Text>(find.textContaining(RegExp(r'^\d+ s$'))).data!.split(' ').first);
    final inicio = restante();
    expect(inicio, inInclusiveRange(57, 60), reason: '60 s en total');
    expect(find.textContaining('Conversión 1 de 10'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    expect(restante(), inicio - 5);
    // Se agota el tiempo: se corrige lo contestado.
    await t.pump(Duration(seconds: inicio));
    await Arnes.asentar(t);
    expect(motor.fase, FaseSesion.correccion);
    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.textContaining('0 de 10 conversiones bien'), findsWidgets);
  });

  testWidgets('la serie T7 contestada entera dentro del tiempo es correcta', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-t7'));
    await responderBienUI(t);
    expect(find.text('Correcto'), findsOneWidget);
    expect((await a.aprendizaje.intentos()).single.verdict, Verdict.correct);
  });

  testWidgets('exercise-session · Segunda coma: la coma no se escribe y hay una señal háptica breve', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'));
    await teclear(t, '4,8');
    a.vibrador.senales.clear();
    await teclear(t, ',');
    expect(find.byKey(const ValueKey('campo-respuesta')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('campo-respuesta'))).data, '4,8');
    expect(a.vibrador.senales, [Senal.aviso]);
  });

  testWidgets('exercise-session · Teclado físico en tablet: «4.8» e Intro muestran «4,8» y comprueban', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'), tamano: const Size(1194, 834));
    await t.sendKeyEvent(LogicalKeyboardKey.digit4);
    await t.sendKeyDownEvent(LogicalKeyboardKey.period, character: '.');
    await t.sendKeyUpEvent(LogicalKeyboardKey.period);
    await t.sendKeyEvent(LogicalKeyboardKey.digit8);
    await t.pump();
    expect(t.widget<Text>(find.byKey(const ValueKey('campo-respuesta'))).data, '4,8');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await Arnes.asentar(t);
    expect(motor.fase, FaseSesion.correccion);
    expect(find.text('Correcto'), findsOneWidget);
  });

  testWidgets('exercise-session · Unidad fija: nivel 2 en ml muestra «ml» como sufijo y solo se escribe la cifra', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-vol'));
    expect(motor.actual!.nivel, 2);
    expect(find.descendant(of: find.byType(CampoRespuesta), matching: find.text('ml')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    await teclear(t, '0,96');
    await comprobar(t);
    expect(find.text('Correcto'), findsOneWidget);
  });

  testWidgets('exercise-session · Unidad a elegir: en nivel 4 «Comprobar» espera a la cifra y a la unidad', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-lido'));
    expect(motor.actual!.nivel, 4);
    FilledButton boton() => t.widget<FilledButton>(find.byKey(const ValueKey('comprobar')));
    expect(boton().onPressed, isNull);
    await teclear(t, '3');
    expect(boton().onPressed, isNull, reason: 'falta la unidad');
    await tocar(t, find.byKey(const ValueKey('unidad-ml/h')));
    expect(boton().onPressed, isNotNull);
    await comprobar(t);
    expect(find.text('Correcto'), findsOneWidget);
  });

  testWidgets('exercise-session · No lo sé: resolución paso a paso sin diagnóstico y el ejercicio entra en repaso', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'));
    await noLoSeUI(t);
    expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
    expect(find.byKey(const ValueKey('diagnostico')), findsNothing);
    final intento = (await a.aprendizaje.intentos()).single;
    expect(intento.verdict, Verdict.dontKnow);
    expect(intento.correct, isFalse);
    await continuar(t);
    final p = a.contenedor.read(proyeccionProvider);
    expect(p!.fichas.containsKey(intento.cardKey), isTrue);
  });

  testWidgets('exercise-session · Salida a mitad de lección: en el ejercicio 6 de 10 los cinco anteriores quedan guardados', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('u-f-1-l3'));
    for (var i = 0; i < 5; i++) {
      await noLoSeUI(t);
      await continuar(t);
    }
    expect(find.text('6 de 10'), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('cerrar-sesion')));
    expect(find.text('¿Salir de la lección?'), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('confirmar-salir')));
    expect(await a.aprendizaje.intentos(), hasLength(5));
    final s = (await a.aprendizaje.sesiones()).single;
    expect(s.completed, isFalse);
    expect(s.lessonId, 'u-f-1-l3');
    expect(a.ubicacion.ruta, Rutas.inicio);
  });

  testWidgets('exercise-session · Gesto de atrás: abre la confirmación de salida en lugar de abandonar', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.inicio);
    a.contenedor.read(routerProvider).push(Rutas.leccion('l-nora'));
    await Arnes.asentar(t);
    expect(find.byType(TecladoNumerico), findsOneWidget);
    await t.binding.handlePopRoute();
    await Arnes.asentar(t);
    expect(find.text('¿Salir de la lección?'), findsOneWidget);
    await tocar(t, find.text('Seguir con la lección'));
    expect(find.byType(TecladoNumerico), findsOneWidget, reason: 'la sesión sigue');
  });

  testWidgets('exercise-session · Llamada entrante: el ejercicio sigue en pantalla y los dos minutos no cuentan', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'));
    await teclear(t, '4');
    a.avanzarMs(5000);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    a.avanzarMs(120000);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await Arnes.asentar(t);
    expect(t.widget<Text>(find.byKey(const ValueKey('campo-respuesta'))).data, '4', reason: 'mismo ejercicio y misma respuesta');
    a.avanzarMs(4000);
    await teclear(t, ',8');
    await comprobar(t);
    expect((await a.aprendizaje.intentos()).single.responseMs, 9000);
  });

  testWidgets('exercise-session · Tiempo de un ejercicio: 18 s de respuesta y 40 s de explicación registran 18 s', (t) async {
    final a = arnesSesion();
    await a.montar(t, ruta: Rutas.leccion('l-nora'));
    a.avanzarMs(18000);
    await teclear(t, '0,08');
    await comprobar(t);
    a.avanzarMs(40000);
    await continuar(t);
    expect((await a.aprendizaje.intentos()).single.responseMs, 18000);
  });

  testWidgets('exercise-session · Lección en modo avión: los ejercicios se suceden sin esperas de carga', (t) async {
    final a = arnesSesion(conexion: false);
    await a.montar(t, ruta: Rutas.leccion('u-f-1-l3'));
    for (var i = 0; i < 3; i++) {
      await responderBienUI(t);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await t.pump();
      // El siguiente ejercicio aparece en el mismo fotograma, sin esqueleto de carga.
      expect(find.byKey(const ValueKey('comprobar')), findsOneWidget);
      await Arnes.asentar(t);
    }
    expect(a.peticiones, isEmpty, reason: 'ninguna petición de red durante la lección');
  });

  testWidgets('exercise-session · Variante defectuosa: se salta, se registra y la lección continúa con la siguiente', (t) async {
    final base = contenidoSesion(contenidoPrueba);
    final it = base.itinerarios['it-prueba-sesion']!;
    // La primera plantilla de «l-dos» (tpl-vol) llega sin respuesta.
    final rotas = it.variants.map((v) => v.templateId == 'tpl-vol' ? sinRespuesta(v) : v).toList();
    final a = Arnes(contenido: conVariantes(base, rotas), derechos: premiumActivo(ahoraPrueba));
    await a.montar(t, ruta: Rutas.leccion('l-dos'));
    expect(motor.saltadas.single.motivo, 'Falta la respuesta');
    expect(motor.actual!.variante.templateId, 'tpl-nora');
    expect(find.textContaining('noradrenalina'), findsWidgets);
    final eventos = await a.aprendizaje.pendientes(ahora: ahoraPrueba, kind: 'event');
    expect(eventos.single.payload, contains('variant_skipped'));
  });
}
