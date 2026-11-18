import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/widgets/comunes.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/session/ui/borrador.dart';

import '../helpers/arnes.dart';
import 'ui_sesion.dart';

/// Corrección, explicación, accesibilidad y límite formativo en la sesión.
void main() {
  setUpAll(cargarContenidoDePrueba);

  Future<Arnes> abrir(WidgetTester t, String leccion, {Size tamano = const Size(390, 844), bool conexion = true, double escala = 1, Ajustes? ajustes}) async {
    final a = arnesSesion(conexion: conexion, ajustes: ajustes);
    await a.montar(t, ruta: Rutas.leccion(leccion), tamano: tamano, escalaTexto: escala);
    return a;
  }

  Future<void> responder(WidgetTester t, String cifra) async {
    await teclear(t, cifra);
    await comprobar(t);
  }

  group('answer-grading', () {
    testWidgets('answer-grading · Más decimales de los pedidos: «0,2667» es correcta con observación «Se redondea a 0,27 ml»', (t) async {
      await abrir(t, 'l-bupre');
      await responder(t, '0,2667');
      expect(find.text('Correcta con observación'), findsOneWidget);
      expect(find.text('Se redondea a 0,27 ml'), findsOneWidget);
    });

    testWidgets('answer-grading · Formato inseguro: «,96» se normaliza a «0,96» con una nota', (t) async {
      final a = await abrir(t, 'l-vol');
      await responder(t, ',96');
      expect(find.text('Se escribe con cero delante: 0,96'), findsOneWidget);
      expect((await a.aprendizaje.intentos()).single.answerValue, '0.96');
    });

    testWidgets('answer-grading · Formato inseguro: «100,0» se normaliza a «100» con una nota', (t) async {
      await abrir(t, 'l-max');
      await responder(t, '100,0');
      expect(find.text('Sin ceros finales: 100'), findsOneWidget);
    });

    testWidgets('answer-grading · Respuesta incorrecta: veredicto «incorrecta» con la respuesta correcta y su unidad', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '2');
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.text('Era'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('banda-veredicto')), matching: find.text('0,96 ml')), findsOneWidget);
    });

    testWidgets('answer-grading · Factor diez: «9,6» frente a 0,96 ml indica que es diez veces mayor', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '9,6');
      expect(find.textContaining('diez veces mayor'), findsOneWidget);
      expect(find.text('E2 · Orden de magnitud'), findsOneWidget);
    });

    testWidgets('answer-grading · Paso omitido: «4,8» indica que ha dado la dosis y falta el volumen', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '4,8');
      expect(find.text('E4 · Paso omitido'), findsOneWidget);
      expect(find.textContaining('falta calcular el volumen'), findsOneWidget);
    });

    testWidgets('answer-grading · Error sin clasificar: respuesta correcta y explicación, sin diagnóstico', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '0,5');
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.byKey(const ValueKey('diagnostico')), findsNothing);
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
    });

    testWidgets('answer-grading · Explicación de una perfusión: pasos hasta 4,8 ml/h y desvío en el paso de minutos a horas', (t) async {
      await abrir(t, 'l-nora');
      await responder(t, '0,08');
      expect(find.text('E1 · Unidad'), findsOneWidget);
      expect(find.text('Falta pasar de minutos a horas.'), findsOneWidget);
      final pasos = find.byKey(const ValueKey('pasos-explicacion'));
      expect(pasos, findsOneWidget);
      expect(find.descendant(of: pasos, matching: find.textContaining('= 4,8 ml/h')), findsOneWidget);
      final desvio = find.byKey(const ValueKey('paso-desvio'));
      expect(find.descendant(of: desvio, matching: find.text('Dosis por hora')), findsOneWidget);
      expect(find.descendant(of: desvio, matching: find.text('Aquí te desviaste')), findsOneWidget);
      expect(find.text('4,8 ml/h en una bomba de perfusión. Tiene sentido.'), findsOneWidget);
    });

    testWidgets('answer-grading · Explicación a demanda tras un acierto: «Ver cómo se hace» muestra los pasos', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '0,96');
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsNothing);
      await tocar(t, find.byKey(const ValueKey('ver-como-se-hace')));
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
      expect(find.textContaining('4,8 mg ÷ 5 mg/ml'), findsOneWidget);
    });

    testWidgets('adaptive-accessible-ui · Cerrar una hoja: la hoja de corrección se cierra con un botón', (t) async {
      await abrir(t, 'l-vol');
      await responder(t, '0,96');
      await tocar(t, find.byKey(const ValueKey('ver-como-se-hace')));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('cerrar-hoja')), findsOneWidget);
      await tocar(t, find.byKey(const ValueKey('cerrar-hoja')));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('continuar')), findsOneWidget);
    });

    testWidgets('answer-grading · Segundo intento acertado: la lección sigue, sin puntos, y el fallo queda en repaso', (t) async {
      final a = await abrir(t, 'l-dos');
      await responder(t, '2');
      await tocar(t, find.byKey(const ValueKey('segundo-intento')));
      expect(find.text('Segundo intento · no puntúa'), findsOneWidget);
      expect(motor.actual!.variante.id, 'tpl-vol.v1.L2.b');
      await responder(t, '1,2');
      expect(find.text('Correcto'), findsOneWidget);
      final intentos = await a.aprendizaje.intentos();
      expect(intentos.last.attemptNumber, 2);
      expect(intentos.last.points, 0);
      await continuar(t);
      expect(find.textContaining('noradrenalina'), findsWidgets, reason: 'la lección continúa');
      final p = a.contenedor.read(proyeccionProvider)!;
      expect(p.fichas.containsKey(intentos.first.cardKey), isTrue);
      expect(p.puntosTotales, 0);
    });

    testWidgets('gamification-progress · Segundo intento: fallar y acertar con otros números no da puntos', (t) async {
      final a = await abrir(t, 'l-vol');
      await responder(t, '9,6');
      await tocar(t, find.byKey(const ValueKey('segundo-intento')));
      await responder(t, '1,2');
      final intentos = await a.aprendizaje.intentos();
      expect(intentos.map((i) => i.points), [0, 0]);
      expect(intentos.last.correct, isTrue);
    });

    testWidgets('answer-grading · Corrección en modo avión: veredicto, diagnóstico y explicación completos', (t) async {
      final a = await abrir(t, 'l-nora', conexion: false);
      await responder(t, '0,08');
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.byKey(const ValueKey('diagnostico')), findsOneWidget);
      expect(find.byKey(const ValueKey('pasos-explicacion')), findsOneWidget);
      expect(a.peticiones, isEmpty);
    });
  });

  group('adaptive-accessible-ui', () {
    testWidgets('adaptive-accessible-ui · Veredicto: lleva icono y la palabra «Correcto» o «Incorrecto», además del color', (t) async {
      await abrir(t, 'l-dos');
      await responder(t, '0,96');
      final banda = find.byKey(const ValueKey('banda-veredicto'));
      expect(find.descendant(of: banda, matching: find.text('Correcto')), findsOneWidget);
      expect(find.descendant(of: banda, matching: find.byIcon(Symbols.check_circle)), findsOneWidget);
      await continuar(t);
      await responder(t, '1');
      expect(find.descendant(of: banda, matching: find.text('Incorrecto')), findsOneWidget);
      expect(find.descendant(of: banda, matching: find.byIcon(Symbols.cancel)), findsOneWidget);
    });

    testWidgets('adaptive-accessible-ui · Anuncio del veredicto: el lector anuncia «Incorrecto» y la respuesta con su unidad', (t) async {
      final anuncios = <String>[];
      t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (m) async {
        final mapa = m as Map;
        if (mapa['type'] == 'announce') anuncios.add('${(mapa['data'] as Map)['message']}');
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
      await abrir(t, 'l-vol');
      await responder(t, '2');
      expect(anuncios, hasLength(1));
      expect(anuncios.single, startsWith('Incorrecto'));
      expect(anuncios.single, contains(lecturaCantidad('0.96', 'ml')));
      expect(find.bySemanticsLabel(RegExp('^Incorrecto. La respuesta correcta es')), findsOneWidget);
    });

    testWidgets('adaptive-accessible-ui · Lectura de una cantidad: «0,2 mg/kg» se anuncia «cero coma dos miligramos por kilo»', (t) async {
      await abrir(t, 'l-vol');
      expect(lecturaCantidad('0.2', 'mg/kg'), 'cero coma dos miligramos por kilo');
      expect(find.bySemanticsLabel(RegExp('cero coma dos miligramos por kilo')), findsOneWidget);
    });

    testWidgets('adaptive-accessible-ui · Modo silencio: al acertar no suena ningún tono y sí hay señal háptica', (t) async {
      final a = await abrir(t, 'l-vol');
      a.sonido.silencio = true;
      await responder(t, '0,96');
      expect(a.sonido.sonados, isEmpty);
      expect(a.vibrador.senales, contains(Senal.acierto));
    });

    testWidgets('el sonido de acierto suena si el dispositivo no está en silencio', (t) async {
      final a = await abrir(t, 'l-vol');
      await responder(t, '0,96');
      expect(a.sonido.sonados, [Senal.acierto]);
    });

    testWidgets('adaptive-accessible-ui · Háptica desactivada: al pulsar una tecla no hay vibración', (t) async {
      final a = await abrir(t, 'l-vol', ajustes: const Ajustes(haptica: false));
      await teclear(t, '1,,');
      expect(a.vibrador.senales, isEmpty);
    });

    testWidgets('adaptive-accessible-ui · Icono pequeño: los controles con icono de 24 dp miden al menos 48 × 48 dp', (t) async {
      await abrir(t, 'l-nora');
      for (final k in ['cerrar-sesion', 'boton-pista', 'no-lo-se']) {
        final s = t.getSize(find.byKey(ValueKey(k)));
        expect(s.width, greaterThanOrEqualTo(48), reason: k);
        expect(s.height, greaterThanOrEqualTo(48), reason: k);
      }
      expect(t.widget<Icon>(find.descendant(of: find.byKey(const ValueKey('cerrar-sesion')), matching: find.byType(Icon))).size ?? 24, 24);
    });

    testWidgets('adaptive-accessible-ui · Texto al 200 %: el enunciado se desplaza y el teclado y «Comprobar» siguen visibles', (t) async {
      await abrir(t, 'l-nora', escala: 2.0);
      sinDesbordes(t);
      final pantalla = Rect.fromLTWH(0, 0, 390, 844);
      final boton = t.getRect(find.byKey(const ValueKey('comprobar')));
      expect(pantalla.contains(boton.topLeft) && pantalla.contains(boton.bottomRight), isTrue, reason: '«Comprobar» visible: $boton');
      for (final k in ['1', '0', ',']) {
        final r = t.getRect(find.byKey(ValueKey('tecla-$k')));
        expect(pantalla.contains(r.center), isTrue, reason: 'tecla $k visible');
      }
      expect(find.descendant(of: find.byKey(const ValueKey('scroll-ejercicio')), matching: find.byType(Scrollable)), findsWidgets);
      await teclear(t, '4,8');
      await comprobar(t);
      sinDesbordes(t);
      expect(find.text('Correcto'), findsOneWidget);
    });

    testWidgets('adaptive-accessible-ui · Sesión en tablet horizontal: enunciado, respuesta y teclado a un lado y borrador al otro', (t) async {
      await abrir(t, 'l-nora', tamano: const Size(1194, 834));
      expect(find.byType(Borrador), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      final izq = t.getRect(find.byKey(const ValueKey('tecla-1')));
      final der = t.getRect(find.byKey(const ValueKey('tecla-3')));
      final teclado = Rect.fromLTRB(izq.left, izq.top, der.right, der.bottom);
      final borrador = t.getRect(find.byType(Borrador));
      expect(teclado.width, lessThanOrEqualTo(420));
      expect(teclado.right, lessThanOrEqualTo(borrador.left));
      expect(t.getRect(find.byType(Enunciado)).width, lessThanOrEqualTo(640));
    });

    testWidgets('adaptive-accessible-ui · Cambio de ejercicio: la hoja de borrador aparece vacía en el siguiente', (t) async {
      await abrir(t, 'l-dos', tamano: const Size(1194, 834));
      await t.drag(find.byKey(const ValueKey('lienzo-borrador')), const Offset(80, 40));
      await t.pump();
      expect(t.state<EstadoBorrador>(find.byType(Borrador)).trazos, hasLength(1));
      await responder(t, '0,96');
      await continuar(t);
      expect(find.textContaining('noradrenalina'), findsWidgets);
      expect(t.state<EstadoBorrador>(find.byType(Borrador)).trazos, isEmpty);
    });

    testWidgets('adaptive-accessible-ui · Giro del dispositivo: cambia la clase sin perder la respuesta escrita ni el progreso', (t) async {
      await abrir(t, 'l-dos', tamano: const Size(1194, 834));
      await responder(t, '0,96');
      await continuar(t);
      await teclear(t, '4,');
      t.view.physicalSize = const Size(834, 1194);
      await Arnes.asentar(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('campo-respuesta'))).data, '4,');
      expect(find.text('2 de 2'), findsOneWidget);
      t.view.physicalSize = const Size(390, 844);
      await Arnes.asentar(t);
      expect(t.widget<Text>(find.byKey(const ValueKey('campo-respuesta'))).data, '4,');
      expect(find.byType(Borrador), findsNothing);
    });

    testWidgets('en tablet la corrección aparece en el panel derecho', (t) async {
      await abrir(t, 'l-nora', tamano: const Size(1194, 834));
      await responder(t, '0,08');
      final pasos = t.getRect(find.byKey(const ValueKey('pasos-explicacion')));
      final banda = t.getRect(find.byKey(const ValueKey('banda-veredicto')));
      expect(pasos.left, greaterThan(banda.right));
    });
  });

  group('formative-boundary', () {
    testWidgets('formative-boundary · La respuesta del usuario solo se corrige: se compara con el caso y no se calcula nada con ella', (t) async {
      final a = await abrir(t, 'l-vol');
      await responder(t, '7');
      // Se muestra el veredicto y la respuesta del caso simulado, no una cifra derivada de la del usuario.
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('banda-veredicto')), matching: find.text('0,96 ml')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('banda-veredicto')), matching: find.text('7 ml')), findsOneWidget);
      final i = (await a.aprendizaje.intentos()).single;
      expect(i.answerValue, '7');
      expect(i.verdict, Verdict.incorrect);
    });

    testWidgets('formative-boundary · No existe entrada libre de datos: ninguna pantalla de la sesión acepta texto libre', (t) async {
      for (final l in ['l-nora', 'l-t2', 'l-t3', 'l-t6', 'l-t7', 'l-lido']) {
        await abrir(t, l);
        expect(find.byType(EditableText), findsNothing, reason: l);
        expect(find.byType(TextField), findsNothing, reason: l);
        await t.pumpWidget(const SizedBox());
      }
    });

    testWidgets('formative-boundary · Enunciado con pauta: el ejercicio de dosis por peso da la pauta «0,2 mg/kg»', (t) async {
      await abrir(t, 'l-vol');
      expect(find.bySemanticsLabel(RegExp('Pauta: meloxicam cero coma dos miligramos por kilo')), findsOneWidget);
      // Todas las variantes de dosis por peso del contenido incluido llevan la pauta en el enunciado.
      final porPeso = contenidoPrueba.fundamentos!.variants.where((v) => v.statement.any((s) => s.isQty && s.unit == 'mg/kg'));
      expect(porPeso, isNotEmpty);
      for (final v in porPeso) {
        expect(v.statement.any((s) => s.isQty && s.unit == 'mg/kg'), isTrue);
      }
    });

    testWidgets('formative-boundary · Límite de dosis como dato: el máximo aparece en el enunciado', (t) async {
      await abrir(t, 'l-max');
      expect(find.bySemanticsLabel(RegExp('máximo un gramo por dosis|máximo uno gramo')), findsOneWidget);
    });

    testWidgets('formative-boundary · Paciente simulado: las personas aparecen como casos simulados', (t) async {
      await abrir(t, 'l-nora');
      expect(find.textContaining('Caso simulado'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Paciente simulado de ochenta kilos')), findsOneWidget);
      final personas = RegExp(r'\b(Paciente|Niño|Niña|Adulto|Mujer|Hombre)\b');
      for (final v in contenidoPrueba.fundamentos!.variants) {
        final texto = v.statement.where((s) => !s.isQty).map((s) => s.text).join();
        if (personas.hasMatch(texto)) expect(texto, contains('simulad'), reason: v.id);
      }
    });
  });
}
