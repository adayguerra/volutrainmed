import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/home/ui/componentes_inicio.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';

/// Pruebas de la entrada de repaso y de la cola vacía (M32, M35).

List<Attempt> fallos(int n, {int criticos = 0, int criticosDesde = 0}) => [
      for (var i = 0; i < n; i++)
        f.intento(
          t: ahoraPrueba.subtract(Duration(days: 3, minutes: i)),
          plantilla: 'tpl-f-repaso-$i',
          correcto: false,
          critico: i >= criticosDesde && i < criticosDesde + criticos,
          errorCode: (i >= criticosDesde && i < criticosDesde + criticos) ? 'E2' : 'E5',
          sesion: 'ses-fallos',
        ),
    ];

String rutaActual(Arnes a) => a.contenedor.read(routerProvider).state.uri.toString();

void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('spaced-review · Tope por defecto: con 35 fichas vencidas y el tope por defecto la cola de hoy tiene 20', (t) async {
    final a = Arnes(intentos: fallos(35));
    await a.montar(t, ruta: Rutas.repaso);
    expect(a.contenedor.read(proyeccionProvider)!.fichasVencidas, 35);
    expect(t.widget<Text>(find.byKey(const ValueKey('total-fichas'))).data, '20 fichas para hoy');
    expect(find.text('Empezar repaso (20)'), findsOneWidget);
    expect(find.text('Unos 10 minutos'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('empezar-repaso')));
    await t.tap(find.byKey(const ValueKey('empezar-repaso')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(rutaActual(a), Rutas.sesionRepaso());
  });

  testWidgets('spaced-review · Orden de la cola: las fichas de error crítico se presentan primero', (t) async {
    // Los críticos son los fallos más recientes (menos vencidos): aun así van delante.
    final a = Arnes(intentos: fallos(6, criticos: 2, criticosDesde: 4));
    await a.montar(t, ruta: Rutas.repaso);
    expect(find.text('2 con error crítico van primero'), findsOneWidget);
    expect(find.byKey(const ValueKey('critica-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('critica-1')), findsOneWidget);
    for (var i = 2; i < 6; i++) {
      expect(find.byKey(ValueKey('critica-$i')), findsNothing);
    }
    final cola = a.contenedor.read(proyeccionProvider)!.colaHoy;
    expect(cola.take(2).every((f) => f.critica), isTrue);
    expect(cola.skip(2).any((f) => f.critica), isFalse);
  });

  testWidgets('spaced-review · Cola vacía: «No tienes fichas para hoy» con la fecha del próximo repaso y práctica libre', (t) async {
    // Un fallo de hace una hora: la ficha vence más adelante, no hoy.
    final a = Arnes(intentos: [
      f.intento(t: ahoraPrueba.subtract(const Duration(hours: 1)), plantilla: 'tpl-f-mg-ug', correcto: false, errorCode: 'E2', critico: true),
    ]);
    await a.montar(t, ruta: Rutas.repaso);
    final p = a.contenedor.read(proyeccionProvider)!;
    expect(p.colaHoy, isEmpty);
    final prox = p.proximo!;
    expect(find.text('No tienes fichas para hoy'), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const ValueKey('proximo-repaso'))).data,
      startsWith('Tu próximo repaso es ${cuandoRelativo(prox.fecha, ahoraPrueba)}, con 1 ficha.'),
    );
    expect(cuandoRelativo(prox.fecha, ahoraPrueba), 'mañana');
    await t.tap(find.byKey(const ValueKey('practica-libre')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(rutaActual(a), Rutas.practicar);
  });

  testWidgets('la entrada de repaso desglosa por tipo de error y por habilidad', (t) async {
    final a = Arnes(intentos: fallos(5, criticos: 2));
    await a.montar(t, ruta: Rutas.repaso);
    expect(find.text('E2 · Orden de magnitud'), findsOneWidget);
    expect(find.text('E5 · Dato equivocado'), findsOneWidget);
    expect(find.text('POR HABILIDAD'), findsOneWidget);
  });

  testWidgets('la entrada de repaso con el texto al 200 % no desborda', (t) async {
    final a = Arnes(intentos: fallos(8, criticos: 3));
    await a.montar(t, ruta: Rutas.repaso, escalaTexto: 2.0);
    sinDesbordes(t);
    expect(find.byKey(const ValueKey('empezar-repaso')), findsOneWidget);
  });
}
