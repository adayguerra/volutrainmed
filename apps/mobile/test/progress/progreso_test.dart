import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';

/// Pruebas de Progreso y del detalle de habilidad (M50, M51, T05).

/// H1 en dos semanas separadas: 80 % hace tres semanas y 90 % esta semana.
List<Attempt> evolucionH1() => [
      for (var i = 0; i < 10; i++)
        f.intento(t: DateTime(2026, 10, 27, 10, i), skill: 'H1', plantilla: 'tpl-f-mg-ug', correcto: i >= 2, errorCode: i < 2 ? 'E2' : null, responseMs: 12000, targetMs: 15000),
      for (var i = 0; i < 10; i++)
        f.intento(t: DateTime(2026, 11, 16, 10, i), skill: 'H1', plantilla: 'tpl-f-g-mg', correcto: i >= 1, errorCode: i < 1 ? 'E3' : null, responseMs: 9000, targetMs: 15000),
    ];

List<SessionRecord> sesiones(int n) => [for (var i = 0; i < n; i++) f.sesion(id: 's$i', inicio: ahoraPrueba.subtract(Duration(days: i + 1)))];

void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('gamification-progress · Datos insuficientes: con menos de tres sesiones se pide completar tres', (t) async {
    final a = Arnes(sesiones: sesiones(2));
    await a.montar(t, ruta: Rutas.progreso);
    expect(find.text('Completa tres sesiones para ver tu evolución'), findsOneWidget);
  });

  testWidgets('con tres sesiones completadas ya no se muestra el aviso de datos insuficientes', (t) async {
    final a = Arnes(sesiones: sesiones(3));
    await a.montar(t, ruta: Rutas.progreso);
    expect(find.text('Completa tres sesiones para ver tu evolución'), findsNothing);
  });

  testWidgets('gamification-progress · Evolución de la precisión: el detalle muestra la precisión semanal con su frase y la tabla', (t) async {
    final a = Arnes(intentos: evolucionH1(), sesiones: sesiones(3));
    await a.montar(t, ruta: Rutas.habilidad('H1'));
    expect(
      t.widget<Text>(find.byKey(const ValueKey('resumen-habilidad'))).data,
      'Tu precisión ha pasado del 80 % al 90 % en cuatro semanas',
    );
    expect(find.byKey(const ValueKey('grafica-precision')), findsOneWidget);
    expect(find.bySemanticsLabel('Tu precisión ha pasado del 80 % al 90 % en cuatro semanas'), findsWidgets);
    expect(find.text('E2 · Orden de magnitud'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ver-tabla')));
    await t.pump();
    expect(find.byKey(const ValueKey('tabla-habilidad')), findsOneWidget);
    expect(find.text('80 %'), findsOneWidget);
    expect(find.text('90 %'), findsOneWidget);
  });

  testWidgets('gamification-progress · Estadísticas sin conexión: Progreso calcula las cifras en el dispositivo', (t) async {
    final a = Arnes(conexion: false, intentos: evolucionH1(), sesiones: sesiones(3));
    await a.montar(t, ruta: Rutas.progreso);
    expect(find.text('Sin conexión'), findsOneWidget);
    // Últimos 7 días: los diez intentos de esta semana, 9 aciertos.
    expect(t.widget<Text>(find.byKey(const ValueKey('cifra-precision'))).data, '90 %');
    expect(t.widget<Text>(find.byKey(const ValueKey('cifra-tiempo'))).data, '0,6');
    await t.tap(find.text('Todo'));
    await t.pump();
    expect(t.widget<Text>(find.byKey(const ValueKey('cifra-precision'))).data, '85 %');
    expect(a.peticiones, isEmpty, reason: 'nada se pide a la red');
  });

  testWidgets('Progreso en tablet muestra la lista a la izquierda y el detalle a la derecha', (t) async {
    final a = Arnes(intentos: evolucionH1(), sesiones: sesiones(3));
    await a.montar(t, ruta: Rutas.progreso, tamano: const Size(1194, 834));
    final detalle = find.byKey(const ValueKey('detalle-habilidad-H1'));
    expect(detalle, findsOneWidget);
    expect(t.getCenter(detalle).dx, greaterThan(t.getCenter(find.byKey(const ValueKey('habilidad-H1'))).dx));
  });

  testWidgets('Progreso y detalle con el texto al 200 % no desbordan', (t) async {
    final a = Arnes(intentos: evolucionH1(), sesiones: sesiones(3));
    await a.montar(t, ruta: Rutas.progreso, escalaTexto: 2.0);
    sinDesbordes(t);
    await t.ensureVisible(find.byKey(const ValueKey('habilidad-H1')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('habilidad-H1')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    sinDesbordes(t);
    expect(find.byKey(const ValueKey('resumen-habilidad')), findsOneWidget);
  });
}
