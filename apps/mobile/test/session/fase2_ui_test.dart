import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/widgets/teclado.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

import '../helpers/arnes.dart';
import 'fixtures_fase2.dart';
import 'fixtures_sesion.dart';
import 'ui_sesion.dart';

/// Interfaz de los tipos de la fase 2: todo con toques.
void main() {
  setUpAll(cargarContenidoDePrueba);

  Arnes arnes({bool conexion = true}) => Arnes(
        contenido: contenidoFase2(contenidoPrueba),
        derechos: premiumActivo(ahoraPrueba),
        conexion: conexion,
      );

  Future<void> tocarFicha(WidgetTester t, String ficha) async {
    await tocar(t, find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('ficha-$ficha-')).first);
  }

  testWidgets('exercise-session · Completar el planteamiento: con las fichas correctas en los huecos, aunque sobren, la respuesta es correcta', (t) async {
    final a = arnes();
    await a.montar(t, ruta: Rutas.leccion('l-t4'));
    final g = motor.actual!.variante.gapFill!;
    expect(find.byType(TextField), findsNothing);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('comprobar'))).onPressed, isNull, reason: 'faltan huecos');
    // Posiciones intercambiables: el peso en g1 y la pauta en g2.
    await tocarFicha(t, g.gapAnswers['g2']!);
    await tocar(t, find.byKey(const ValueKey('hueco-g1')));
    await tocarFicha(t, g.gapAnswers['g1']!);
    await tocar(t, find.byKey(const ValueKey('hueco-g2')));
    await tocarFicha(t, '5');
    await tocar(t, find.byKey(const ValueKey('hueco-g3')));
    await comprobar(t);
    expect(find.text('Correcto'), findsOneWidget);
    expect(a.aprendizaje.intentos().then((l) => l.single.verdict), completion(Verdict.correct));
  });

  testWidgets('completar el planteamiento: un hueco mal se marca en la corrección y tocar un hueco lleno lo vacía', (t) async {
    final a = arnes();
    await a.montar(t, ruta: Rutas.leccion('l-t4'));
    final g = motor.actual!.variante.gapFill!;
    await tocarFicha(t, '50');
    await tocar(t, find.byKey(const ValueKey('hueco-g1')));
    expect(find.descendant(of: find.byKey(const ValueKey('hueco-g1')), matching: find.text('50')), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('hueco-g1')));
    expect(find.descendant(of: find.byKey(const ValueKey('hueco-g1')), matching: find.text('50')), findsNothing, reason: 'el hueco se vacía');
    await tocarFicha(t, g.gapAnswers['g1']!);
    await tocar(t, find.byKey(const ValueKey('hueco-g1')));
    await tocarFicha(t, g.gapAnswers['g2']!);
    await tocar(t, find.byKey(const ValueKey('hueco-g2')));
    await tocarFicha(t, '2,4');
    await tocar(t, find.byKey(const ValueKey('hueco-g3')));
    await comprobar(t);
    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.text('Un hueco no es correcto'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Hueco 3: 2,4, incorrecto')), findsOneWidget);
  });

  testWidgets('detectar el error: tocar el paso con el error es correcto; otro paso muestra la corrección', (t) async {
    final a = arnes();
    await a.montar(t, ruta: Rutas.leccion('l-t5'));
    await tocar(t, find.byKey(const ValueKey('paso-resuelto-1')));
    await comprobar(t);
    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.text('El error está en el paso 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('paso-erroneo-2')), findsOneWidget);
    expect(find.textContaining('Corrección: Falta multiplicar por 60'), findsOneWidget);
  });

  testWidgets('exercise-session · Emparejar: se une un elemento de cada columna con toques, cada par se corrige y al unirlos todos termina', (t) async {
    final a = arnes();
    await a.montar(t, ruta: Rutas.leccion('l-t10'));
    Future<void> unir(String izq, String der) async {
      await tocar(t, find.byKey(ValueKey('izq-$izq')));
      await tocar(t, find.byKey(ValueKey('der-$der')));
    }

    await unir('1 mg', '1000 µg');
    expect(find.bySemanticsLabel(RegExp('^1 mg unido con 1000 µg: correcto')), findsOneWidget, reason: 'corrección inmediata del par');
    await unir('1 g', '60 min');
    expect(find.bySemanticsLabel(RegExp('^1 g unido con 60 min: incorrecto')), findsOneWidget);
    expect(find.text('2 de 4 unidas'), findsOneWidget);
    expect(motor.actual, isNotNull, reason: 'aún no están todos unidos');
    await unir('1 h', '1000 mg');
    await unir('1 %', '10 mg/ml');
    expect(find.text('Incorrecto'), findsOneWidget, reason: 'el ejercicio se corrige al unir el último par');
    expect(find.text('2 de 4 parejas bien'), findsOneWidget);
    expect(find.textContaining('1 g = 1000 mg (uniste 60 min)'), findsOneWidget);
  });

  testWidgets('exercise-session · Tipo de fase 2 sin conexión: cada parte del caso encadenado se corrige y tras un fallo se sigue con el valor correcto', (t) async {
    final a = arnes(conexion: false);
    await a.montar(t, ruta: Rutas.leccion('l-t8'));
    expect(find.byType(TecladoNumerico), findsOneWidget);
    expect(find.text('¿Cuántos µg por minuto?'), findsOneWidget);
    expect(find.descendant(of: find.byType(CampoRespuesta), matching: find.text('µg/min')), findsOneWidget);
    await teclear(t, '8');
    await comprobar(t);
    expect(find.text('Parte 1: correcto, 8 µg/min'), findsOneWidget);
    await teclear(t, '8');
    await comprobar(t);
    expect(find.text('Parte 2: incorrecto. Sigue con 480 µg/h'), findsOneWidget);
    expect(find.text('Con la dosis por hora, ¿a cuántos ml/h?'), findsOneWidget, reason: 'la siguiente parte continúa');
    await teclear(t, '4,8');
    await comprobar(t);
    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.byKey(const ValueKey('parte-corregida-1')), findsOneWidget);
    expect(find.textContaining('Era 480 µg/h'), findsOneWidget);
    final intento = (await t.runAsync(a.aprendizaje.intentos))!.single;
    final partes = ((intento.answerPayload as Map)['parts'] as List).cast<Map>();
    expect(partes.map((p) => p['verdict']), ['correct', 'incorrect', 'correct']);
    expect(a.peticiones, isEmpty, reason: 'sin conexión: todo se corrige en el dispositivo');
  });
}
