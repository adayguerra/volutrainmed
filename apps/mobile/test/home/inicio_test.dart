import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/home/ui/pantalla_inicio.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';

/// Pruebas de Inicio, detalle de unidad y Practicar (M12–M16, T01).

/// Reto de la unidad 1 superado: la unidad 2 queda disponible.
SessionRecord retoUnidad1() => f.sesion(
      id: 'reto-u1',
      inicio: ahoraPrueba.subtract(const Duration(days: 2)),
      modo: SessionMode.challenge,
      lessonId: 'u-f-1-l5',
      resumen: const SessionSummary(correct: 10, total: 10, errors: 0, accuracy: 1, passed: true),
    );

SessionRecord leccionHecha(String lessonId, {int haceDias = 1}) => f.sesion(
      id: 'ses-$lessonId',
      inicio: ahoraPrueba.subtract(Duration(days: haceDias)),
      lessonId: lessonId,
      resumen: const SessionSummary(correct: 8, total: 8, errors: 0, accuracy: 1),
    );

/// Fallos en plantillas distintas hace dos días: fichas vencidas hoy.
List<Attempt> fallosVencidos(int n, {int criticos = 0}) => [
      for (var i = 0; i < n; i++)
        f.intento(
          t: ahoraPrueba.subtract(Duration(days: 2, minutes: i)),
          plantilla: 'tpl-f-repaso-$i',
          correcto: false,
          critico: i < criticos,
          errorCode: i < criticos ? 'E2' : 'E5',
          sesion: 'ses-fallos',
        ),
    ];

/// Ruta visible, incluidas las pantallas apiladas con `push`.
String rutaActual(Arnes a) => a.contenedor.read(routerProvider).state.uri.toString();

Future<void> pocosFotogramas(WidgetTester t) async {
  for (var i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('learning-path', () {
    testWidgets('learning-path · Ruta con estados: las unidades aparecen en orden con su estado en icono y texto', (t) async {
      final a = Arnes(sesiones: [retoUnidad1(), leccionHecha('u-f-2-l1')]);
      await a.montar(t);
      String estado(String u) => t.widget<Text>(find.byKey(ValueKey('estado-$u'))).data!;
      expect(estado('u-f-1'), 'Superada');
      expect(estado('u-f-2'), 'En curso · 1 de 5 lecciones');
      expect(estado('u-f-3'), 'Bloqueada');
      expect(estado('u-f-5'), 'Bloqueada');
      // Orden visual = orden del itinerario.
      final ys = [for (var i = 1; i <= 5; i++) t.getTopLeft(find.byKey(ValueKey('unidad-u-f-$i'))).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      // Cada estado lleva icono además del texto.
      for (var i = 1; i <= 5; i++) {
        expect(find.descendant(of: find.byKey(ValueKey('unidad-u-f-$i')), matching: find.byType(Icon)), findsWidgets);
      }
      // La unidad en curso se despliega con sus cinco lecciones.
      for (var l = 1; l <= 5; l++) {
        expect(find.byKey(ValueKey('leccion-u-f-2-l$l')), findsOneWidget);
      }
    });

    testWidgets('learning-path · Ruta sin conexión: la ruta se muestra completa y las lecciones descargadas pueden iniciarse', (t) async {
      final a = Arnes(conexion: false);
      await a.montar(t);
      expect(find.text(textoBannerSinConexion), findsOneWidget);
      for (var i = 1; i <= 5; i++) {
        expect(find.byKey(ValueKey('unidad-u-f-$i')), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('leccion-u-f-1-l1')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.leccion('u-f-1-l1'));
    });

    testWidgets('learning-path · Continuar: con dos lecciones hechas de la unidad, «Continuar» empieza la lección 3', (t) async {
      final a = Arnes(sesiones: [retoUnidad1(), leccionHecha('u-f-2-l1', haceDias: 2), leccionHecha('u-f-2-l2')]);
      await a.montar(t);
      expect(find.text('Continuar · Lección 3'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continuar · Lección 3'), findsOneWidget, reason: 'única acción principal');
      expect(find.byType(FilledButton), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.leccion('u-f-2-l3'));
    });

    testWidgets('learning-path · Sesión sin repaso pendiente (Inicio): sin fichas vencidas, «Continuar» abre la lección directamente', (t) async {
      final a = Arnes();
      await a.montar(t);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.leccion('u-f-1-l1'));
      expect(rutaActual(a), isNot(contains('calentamiento')));
    });

    testWidgets('learning-path · Sesión con repaso pendiente (Inicio): con 12 fichas vencidas, «Continuar» antepone el calentamiento', (t) async {
      final a = Arnes(intentos: fallosVencidos(12));
      await a.montar(t);
      expect(find.text('12 fichas para hoy'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('continuar')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.leccion('u-f-1-l1', calentamiento: true));
      expect(Uri.parse(rutaActual(a)).queryParameters['calentamiento'], '1');
    });

    testWidgets('learning-path · Lección bloqueada: tocar la lección 3 sin la 2 indica «Completa antes la lección 2» y no la inicia', (t) async {
      final a = Arnes(sesiones: [leccionHecha('u-f-1-l1')]);
      await a.montar(t);
      await t.tap(find.byKey(const ValueKey('leccion-u-f-1-l3')));
      await pocosFotogramas(t);
      expect(find.text('Completa antes la lección 2'), findsOneWidget);
      expect(rutaActual(a), Rutas.inicio);
    });

    testWidgets('learning-path · Saltar una unidad con el reto: «Reto y saltar» abre el reto aunque falten lecciones', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: Rutas.unidad('u-f-1'));
      expect(find.text('0 de 5 lecciones'), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('reto-y-saltar')));
      await t.tap(find.byKey(const ValueKey('reto-y-saltar')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.leccion('u-f-1-l5'));
    });
  });

  group('gamification-progress', () {
    testWidgets('gamification-progress · Meta diaria cumplida: con 5 minutos de práctica hoy el anillo se completa', (t) async {
      final a = Arnes(
        usuario: usuarioDePrueba(meta: const Goal.daily(5)),
        sesiones: [f.sesion(id: 'hoy', inicio: ahoraPrueba.subtract(const Duration(hours: 1)), practiceMs: 5 * 60000)],
      );
      await a.montar(t);
      expect(find.text('Meta de hoy 5 de 5 minutos'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Meta cumplida')), findsOneWidget);
    });

    testWidgets('gamification-progress · Meta diaria a medias: con 4 minutos el anillo no se completa', (t) async {
      final a = Arnes(
        usuario: usuarioDePrueba(meta: const Goal.daily(5)),
        sesiones: [f.sesion(id: 'hoy', inicio: ahoraPrueba.subtract(const Duration(hours: 1)), practiceMs: 4 * 60000, adMs: 60000)],
      );
      await a.montar(t);
      expect(find.text('Meta de hoy 4 de 5 minutos'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Meta cumplida')), findsNothing);
    });

    testWidgets('gamification-progress · Meta semanal: cuatro días no consecutivos cumplen la semana y la racha semanal aumenta', (t) async {
      final domingo = DateTime(2026, 11, 22, 18);
      final dias = [DateTime(2026, 11, 16, 9), DateTime(2026, 11, 18, 9), DateTime(2026, 11, 20, 9), DateTime(2026, 11, 22, 9)];
      final a = Arnes(
        ahora: domingo,
        usuario: usuarioDePrueba(meta: const Goal.weekly(4)),
        sesiones: [for (final (i, d) in dias.indexed) f.sesion(id: 'sem-$i', inicio: d, practiceMs: 3 * 60000)],
      );
      await a.montar(t);
      expect(find.text('Meta semanal 4 de 4 días'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Meta cumplida')), findsOneWidget);
      expect(find.text('1 semana'), findsOneWidget);
      expect(a.contenedor.read(proyeccionProvider)!.racha.actual, 1);
    });

    testWidgets('gamification-progress · Racha interrumpida: tras 12 días y un día sin meta se muestra el aviso sin reproches', (t) async {
      final a = Arnes(
        usuario: usuarioDePrueba(meta: const Goal.daily(5)),
        sesiones: [
          for (var d = 2; d <= 13; d++) f.sesion(id: 'r$d', inicio: ahoraPrueba.subtract(Duration(days: d)), practiceMs: 6 * 60000),
        ],
      );
      await a.montar(t);
      expect(find.text('Tu racha se quedó en 12 días. Hoy empieza otra'), findsOneWidget);
    });
  });

  group('adaptive-accessible-ui', () {
    testWidgets('adaptive-accessible-ui · Inicio en tablet horizontal: ruta a la izquierda y detalle de la unidad seleccionada a la derecha', (t) async {
      final a = Arnes(sesiones: [retoUnidad1()]);
      await a.montar(t, tamano: const Size(1194, 834));
      final ruta = t.getCenter(find.byKey(const ValueKey('unidad-u-f-2')));
      final detalle = find.byKey(const ValueKey('detalle-u-f-2'));
      expect(detalle, findsOneWidget);
      expect(t.getCenter(detalle).dx, greaterThan(ruta.dx));
      expect(t.getCenter(detalle).dx, greaterThan(1194 / 2));
      await t.tap(find.byKey(const ValueKey('unidad-u-f-1')));
      await pocosFotogramas(t);
      expect(find.byKey(const ValueKey('detalle-u-f-1')), findsOneWidget);
      expect(rutaActual(a), Rutas.inicio, reason: 'en tablet seleccionar no navega');
    });

    testWidgets('adaptive-accessible-ui · Disposición sin conexión: tipografías e iconos son los incluidos en la app', (t) async {
      final a = Arnes(conexion: false);
      await a.montar(t);
      const incluidas = {'SpaceGrotesk', 'NotoSans', 'SpaceMono'};
      final textos = t.widgetList<RichText>(find.byType(RichText)).toList();
      expect(textos, isNotEmpty);
      for (final r in textos) {
        final familia = r.text.style?.fontFamily;
        if (familia == null) continue;
        expect(incluidas.contains(familia) || familia.contains('MaterialSymbols') || familia == 'MaterialIcons', isTrue, reason: 'fuente $familia');
      }
      for (final i in t.widgetList<Icon>(find.byType(Icon))) {
        expect(i.icon!.fontPackage == 'material_symbols_icons' || i.icon!.fontFamily == 'MaterialIcons', isTrue, reason: '${i.icon!.fontFamily} ${i.icon!.fontPackage}');
      }
      expect(find.byType(Image), findsNothing, reason: 'sin imágenes de red');
    });

    testWidgets('Inicio con el texto al 200 % no desborda', (t) async {
      final a = Arnes(sesiones: [retoUnidad1()], intentos: fallosVencidos(3, criticos: 1));
      await a.montar(t, escalaTexto: 2.0);
      sinDesbordes(t);
      expect(find.byKey(const ValueKey('continuar')), findsOneWidget);
    });
  });

  testWidgets('Detalle de unidad y Practicar con el texto al 200 % no desbordan', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.unidad('u-f-1'), escalaTexto: 2.0);
    sinDesbordes(t);
    expect(find.byKey(const ValueKey('detalle-u-f-1')), findsOneWidget);
    final b = Arnes();
    await b.montar(t, ruta: Rutas.practicar, escalaTexto: 2.0);
    sinDesbordes(t);
    expect(find.byKey(const ValueKey('practicar-repaso')), findsOneWidget);
  });

  group('offline-sync', () {
    testWidgets('offline-sync · Pérdida de conexión: aviso único y distintivo visible en Inicio', (t) async {
      final a = Arnes();
      await a.montar(t);
      expect(find.text('Sin conexión'), findsNothing);
      a.conectividad.conectado = false;
      await pocosFotogramas(t);
      expect(find.text('Sin conexión. Puedes seguir entrenando'), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget, reason: 'distintivo en Inicio');
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 6));
      await pocosFotogramas(t);
      // El aviso no se repite mientras sigue sin conexión.
      expect(find.text('Sin conexión. Puedes seguir entrenando'), findsNothing);
      expect(find.text('Sin conexión'), findsOneWidget);
    });

    testWidgets('offline-sync · Semana sin conexión: rachas y estadísticas se actualizan en el dispositivo', (t) async {
      final sesiones = <SessionRecord>[];
      final intentos = <Attempt>[];
      for (var d = 0; d < 7; d++) {
        final dia = ahoraPrueba.subtract(Duration(days: 6 - d, hours: 1));
        sesiones.add(f.sesion(id: 'sem-$d', inicio: dia, practiceMs: 10 * 60000));
        for (var i = 0; i < 4; i++) {
          intentos.add(f.intento(t: dia.add(Duration(minutes: i)), correcto: i != 3, sesion: 'sem-$d', plantilla: 'tpl-f-mg-ug', puntos: i != 3 ? 10 : 0));
        }
      }
      final a = Arnes(conexion: false, sesiones: sesiones, intentos: intentos);
      await a.montar(t);
      expect(find.text('7 días'), findsOneWidget);
      expect(find.text('210'), findsOneWidget, reason: 'puntos calculados en el dispositivo');
      await t.tap(find.text('Progreso'));
      await pocosFotogramas(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('cifra-precision'))).data, '75 %');
      expect(t.widget<Text>(find.byKey(const ValueKey('cifra-dias'))).data, '2/7');
    });
  });

  group('Practicar', () {
    testWidgets('Practicar ofrece repaso, manos libres, contrarreloj y práctica por habilidad', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: Rutas.practicar);
      expect(find.text('Entrena sin mirar ni tocar. La voz no sale del dispositivo.'), findsOneWidget);
      expect(find.text('Consolida una habilidad para abrir el contrarreloj'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('practica-H1')));
      await pocosFotogramas(t);
      expect(rutaActual(a), Rutas.practicaHabilidad('H1'));
    });
  });
}
