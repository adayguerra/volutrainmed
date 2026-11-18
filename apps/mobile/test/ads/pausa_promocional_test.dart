import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/data/anuncios.dart';
import 'package:volutrainmed/features/ads/domain/ad_selector.dart';
import 'package:volutrainmed/features/ads/ui/pausa_promocional.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';
import 'soporte.dart';

Finder textoQueContiene(String s) => find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(s));

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('house-ads · formato y espera', () {
    testWidgets('house-ads · Elementos visibles: rótulo arriba y «Continuar» siempre a la vista con su cuenta atrás', (t) async {
      final a = Arnes();
      await montarPausa(t, a);
      final rotulo = find.byKey(const ValueKey('rotulo-promocion'));
      expect(rotulo, findsOneWidget);
      expect(find.text(rotuloPromocion.toUpperCase()), findsOneWidget);
      final continuar = find.byKey(const ValueKey('continuar-pausa'));
      expect(continuar, findsOneWidget);
      expect(t.getTopLeft(rotulo).dy, lessThan(t.getTopLeft(continuar).dy));
      expect(find.text('Continuar (3)'), findsOneWidget);
      // Visible dentro de la pantalla, también con la cuenta atrás en curso.
      expect(t.getBottomLeft(continuar).dy, lessThanOrEqualTo(844));
      expect(find.byKey(const ValueKey('accion-anuncio')), findsOneWidget);
      // Texto del anuncio de 90 caracteres como máximo en todas las creatividades.
      for (final c in contenidoPrueba.global.campaigns.expand((c) => c.creatives)) {
        expect(c.body.length, lessThanOrEqualTo(90), reason: c.id);
      }
    });

    testWidgets('house-ads · Tablet en horizontal: la tarjeta ocupa 560 dp como máximo, centrada', (t) async {
      final a = Arnes();
      await montarPausa(t, a, tamano: const Size(1194, 834));
      final tarjeta = t.getRect(find.byKey(const ValueKey('tarjeta-anuncio')));
      expect(tarjeta.width, lessThanOrEqualTo(560));
      expect(tarjeta.center.dx, closeTo(1194 / 2, 1));
    });

    testWidgets('house-ads · Espera por defecto: «Continuar» cuenta 3, 2, 1 y se activa al terminar', (t) async {
      final a = Arnes();
      final r = await montarPausa(t, a);
      FilledButton boton() => t.widget<FilledButton>(find.byKey(const ValueKey('continuar-pausa')));
      expect(find.text('Continuar (3)'), findsOneWidget);
      expect(boton().onPressed, isNull);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Continuar (2)'), findsOneWidget);
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Continuar (1)'), findsOneWidget);
      expect(boton().onPressed, isNull);
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(find.text('Continuar'), findsOneWidget);
      expect(boton().onPressed, isNotNull);
      await t.tap(find.byKey(const ValueKey('continuar-pausa')));
      await t.pump();
      expect(r, hasLength(1));
    });

    testWidgets('house-ads · Espera desactivada: con 0 segundos «Continuar» está activo desde el primer momento', (t) async {
      final a = Arnes(contenido: contenidoCon(params: const AdParams(waitS: 0)));
      await montarPausa(t, a);
      expect(find.text('Continuar'), findsOneWidget);
      expect(t.widget<FilledButton>(find.byKey(const ValueKey('continuar-pausa'))).onPressed, isNotNull);
    });

    testWidgets('house-ads · Cambio de la espera: tras descargar un paquete con 2 segundos se aplican 2 segundos', (t) async {
      final a = Arnes(contenido: contenidoCon(params: const AdParams(waitS: 2)));
      await montarPausa(t, a);
      expect(find.text('Continuar (2)'), findsOneWidget);
      await esperarCuenta(t, 2);
      expect(find.text('Continuar'), findsOneWidget);
    });
  });

  group('house-ads · inventario local', () {
    testWidgets('house-ads · Modo avión: la pausa aparece con su anuncio completo, texto e ilustración', (t) async {
      final a = Arnes(conexion: false);
      await montarPausa(t, a);
      final anterior = await t.runAsync(() => a.claves.leer(claveAnuncioAnterior));
      final creatividad = contenidoPrueba.global.campaigns.expand((c) => c.creatives).firstWhere((c) => c.id == anterior);
      expect(find.byIcon(iconoIlustracion(creatividad.illustration)), findsOneWidget);
      expect(find.byKey(const ValueKey('accion-anuncio')), findsOneWidget);
      expect(textoQueContiene(creatividad.body.split('{').first.trim()), findsOneWidget);
      expect(a.peticionesSinContenido, isEmpty);
    });

    testWidgets('house-ads · Sin tráfico publicitario: varias pausas con conexión no hacen ninguna petición de red', (t) async {
      final a = Arnes(conexion: true, http: (req) async => throw StateError('No debe haber tráfico: ${req.url}'));
      final r = await montarPausa(t, a);
      await esperarCuenta(t);
      await t.tap(find.byKey(const ValueKey('continuar-pausa')));
      await t.pump();
      expect(r, hasLength(1));
      // Segunda pausa en el mismo contenedor.
      final segunda = await t.runAsync(() => elegirAnuncio(a.contenedor.read, datosLeccion()));
      expect(segunda, isNotNull);
      expect(a.peticionesSinContenido, isEmpty);
    });

    testWidgets('house-ads · Sin repetición consecutiva: dos pausas seguidas muestran anuncios distintos', (t) async {
      final a = Arnes();
      await t.runAsync(a.contenedorSinInterfaz);
      final ids = <String>[];
      for (var i = 0; i < 8; i++) {
        final e = await t.runAsync(() => elegirAnuncio(a.contenedor.read, datosLeccion()));
        ids.add(e!.anuncio.id);
      }
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], isNot(ids[i - 1]));
      }
      a.contenedor.dispose();
    });

    testWidgets('house-ads · Tope diario alcanzado: un anuncio visto 6 veces hoy queda fuera hasta mañana', (t) async {
      final a = Arnes();
      await t.runAsync(a.contenedorSinInterfaz);
      final contador = ContadorImpresiones()
        ..registrar('PA-03', ahoraPrueba)
        ..registrar('PA-03', ahoraPrueba)
        ..registrar('PA-03', ahoraPrueba)
        ..registrar('PA-03', ahoraPrueba)
        ..registrar('PA-03', ahoraPrueba)
        ..registrar('PA-03', ahoraPrueba);
      await t.runAsync(() => a.claves.escribirJson(claveImpresiones, contador.toJson()));
      for (var i = 0; i < 20; i++) {
        final e = await t.runAsync(() => elegirAnuncio(a.contenedor.read, datosLeccion()));
        expect(e!.anuncio.id, isNot('PA-03'));
      }
      // Al día siguiente vuelve a entrar.
      a.reloj.avanzar(const Duration(days: 1));
      final ctx = await t.runAsync(() => construirContexto(a.contenedor.read, datosLeccion()));
      expect(ctx!.impresiones.hoy('PA-03', a.reloj.ahora()), 0);
      a.contenedor.dispose();
    });

    testWidgets('house-ads · Racha de varios días: con 5 días seguidos se muestra «Llevas 5 días seguidos»', (t) async {
      final a = Arnes(sesiones: rachaDe(5));
      await montarPausa(t, a);
      expect(find.text('Llevas 5 días seguidos'), findsOneWidget);
    });

    testWidgets('house-ads · Límite diario de manos libres agotado: se muestra el anuncio de manos libres sin límite', (t) async {
      final hoy = SessionRecord(
        id: 'hf-hoy',
        deviceId: 'disp-prueba',
        mode: SessionMode.handsfree,
        startedAt: ahoraPrueba.subtract(const Duration(hours: 1)),
        endedAt: ahoraPrueba.subtract(const Duration(minutes: 54)),
        completed: true,
        practiceMs: 5 * 60000,
        inputMode: InputMode.voice,
        contentVersion: '2026.11.0',
      );
      final a = Arnes(sesiones: [hoy]);
      await montarPausa(t, a);
      expect(find.text('Sigue con las manos ocupadas'), findsOneWidget);
    });

    testWidgets('house-ads · Cifras calculadas con la configuración vigente: 3 s y 10 ejercicios dan 30 s', (t) async {
      final soloPa02 = [
        AdCampaign(id: 'c', name: 'c', creatives: [contenidoPrueba.global.campaigns.first.creatives.firstWhere((c) => c.id == 'PA-02')]),
      ];
      final a = Arnes(contenido: contenidoCon(campanas: soloPa02));
      await montarPausa(t, a, datos: datosLeccion(ejercicios: 10));
      expect(find.text('3 s × 10 ejercicios = 30 s'), findsOneWidget);
    });

    testWidgets('house-ads · Campaña por sector: una campaña de veterinaria no entra en la rotación de enfermería', (t) async {
      final base = contenidoPrueba.global.campaigns.first.creatives;
      final vet = AdCampaign(id: 'vet', name: 'Veterinaria', sectorIds: const ['veterinaria'], creatives: [
        AdCreative(id: 'VET-1', kind: 'contextual', context: 'always', weight: 100, dailyCap: null, headline: 'Solo veterinaria', body: 'x', cta: 'Ver', ctaAction: 'paywall', illustration: 'two_bars'),
      ]);
      final a = Arnes(usuario: usuarioDePrueba(sector: 'enfermeria'), contenido: contenidoCon(campanas: [AdCampaign(id: 'g', name: 'g', creatives: base), vet]));
      await t.runAsync(a.contenedorSinInterfaz);
      for (var i = 0; i < 15; i++) {
        final e = await t.runAsync(() => elegirAnuncio(a.contenedor.read, datosLeccion()));
        expect(e!.anuncio.id, isNot('VET-1'));
      }
      a.contenedor.dispose();
    });

    testWidgets('house-ads · Campaña caducada sin conexión: queda fuera y se usan los anuncios vigentes', (t) async {
      final caducada = AdCampaign(id: 'old', name: 'Vieja', endsAt: ahoraPrueba.subtract(const Duration(days: 1)), creatives: [
        AdCreative(id: 'OLD-1', kind: 'contextual', context: 'always', weight: 100, dailyCap: null, headline: 'Caducado', body: 'x', cta: 'Ver', ctaAction: 'paywall', illustration: 'two_bars'),
      ]);
      final a = Arnes(conexion: false, contenido: contenidoCon(campanas: [caducada, ...contenidoPrueba.global.campaigns]));
      await t.runAsync(a.contenedorSinInterfaz);
      for (var i = 0; i < 15; i++) {
        final e = await t.runAsync(() => elegirAnuncio(a.contenedor.read, datosLeccion()));
        expect(e!.anuncio.id, isNot('OLD-1'));
      }
      a.contenedor.dispose();
    });
  });

  group('house-ads · accesibilidad', () {
    testWidgets('house-ads · Lector de pantalla: anuncia rótulo, titular y texto, y cuándo se activa «Continuar», que recibe el foco', (t) async {
      final h = t.ensureSemantics();
      final a = Arnes();
      await montarPausa(t, a);
      final anuncios = t.takeAnnouncements().map((x) => x.message).toList();
      expect(anuncios.first, startsWith(rotuloPromocion));
      final titular = find.descendant(of: find.byKey(const ValueKey('tarjeta-anuncio')), matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).toList();
      expect(anuncios.first, contains(titular[1]!));
      expect(anuncios.first, contains(titular[2]!));
      expect(find.bySemanticsLabel(RegExp('Continuar, disponible en 3 segundos')), findsOneWidget);
      await esperarCuenta(t);
      expect(t.takeAnnouncements().map((x) => x.message), contains('Ya puedes continuar'));
      final foco = t.widget<FilledButton>(find.byKey(const ValueKey('continuar-pausa'))).focusNode!;
      expect(foco.hasFocus, isTrue);
      h.dispose();
    });

    testWidgets('house-ads · Movimiento reducido: entra con un fundido y la ilustración no se anima', (t) async {
      final a = Arnes();
      await montarPausa(t, a, movimientoReducido: true);
      expect(find.byKey(const ValueKey('ilustracion-estatica')), findsOneWidget);
      expect(find.byKey(const ValueKey('ilustracion-animada')), findsNothing);
      final fundido = t.widget<FadeTransition>(find.byKey(const ValueKey('entrada-pausa')));
      expect(fundido.opacity, isA<AnimationController>());
      expect((fundido.opacity as AnimationController).duration, const Duration(milliseconds: 150));
    });
  });

  group('house-ads · medición y acción', () {
    testWidgets('house-ads · Impresión sin conexión: se encola el evento con anuncio, contexto y 4 segundos de permanencia', (t) async {
      final a = Arnes(conexion: false);
      await montarPausa(t, a);
      await esperarCuenta(t);
      a.avanzarMs(4000);
      await t.tap(find.byKey(const ValueKey('continuar-pausa')));
      await t.pump();
      final pendientes = await t.runAsync(() => a.aprendizaje.pendientes(ahora: ahoraPrueba, kind: 'event'));
      final eventos = pendientes!.map((e) => jsonDecode(e.payload) as Map<String, dynamic>).where((e) => e['name'] == 'ad_impression').toList();
      expect(eventos, hasLength(1));
      final props = eventos.single['props'] as Map<String, dynamic>;
      expect(props['adId'], startsWith('PA-'));
      expect(props['context'], isNotEmpty);
      expect(props['dwellS'], 4);
      expect(props['dwellMs'], 4000);
      expect(a.peticionesSinContenido, isEmpty, reason: 'se envía después, al recuperar la conexión');
    });

    testWidgets('house-ads · Toque en «Quitar anuncios» y vuelta: la sesión continúa en el ejercicio 7 con el progreso intacto', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      var ms = 0;
      final intentos = <Attempt>[];
      final motor = MotorSesion(
        contenido: contenidoPrueba,
        modo: SessionMode.lesson,
        deviceId: 'd',
        relojMs: () => ms,
        ahora: () => ahoraPrueba,
        leccion: contenidoPrueba.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l3'),
        sinAnuncios: false,
        azar: Random(2),
        alRegistrar: intentos.add,
      )..preparar();
      for (var i = 0; i < 5; i++) {
        responderBien(motor);
        motor.continuar();
        motor.cerrarPausa();
      }
      responderBien(motor);
      motor.continuar();
      expect(motor.fase, FaseSesion.pausaPromocional);
      ms += 1;
      final r = await montarPausa(t, a, alCerrar: (_) => motor.cerrarPausa());
      await t.tap(find.byKey(const ValueKey('accion-anuncio')));
      await Arnes.asentar(t);
      expect(find.text('Entrena todos los cálculos de tu sector'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cerrar-suscripcion')));
      await Arnes.asentar(t);
      // Vuelve a la pausa, sin compra.
      expect(find.byKey(const ValueKey('continuar-pausa')), findsOneWidget);
      expect(r, isEmpty);
      await esperarCuenta(t);
      await t.tap(find.byKey(const ValueKey('continuar-pausa')));
      await t.pump();
      expect(r.single.compro, isFalse);
      expect(motor.fase, FaseSesion.ejercicio);
      expect(motor.posicion, 7);
      expect(intentos, hasLength(6));
    });

    testWidgets('house-ads · Compra desde un anuncio: vuelve a la sesión y no ve más pausas', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      var ms = 0;
      final motor = MotorSesion(
        contenido: contenidoPrueba,
        modo: SessionMode.lesson,
        deviceId: 'd',
        relojMs: () => ms,
        ahora: () => ahoraPrueba,
        leccion: contenidoPrueba.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l3'),
        sinAnuncios: false,
        azar: Random(2),
      )..preparar();
      responderBien(motor);
      motor.continuar();
      ms += 1;
      final r = await montarPausa(t, a, alCerrar: (res) {
        if (res.compro) motor.sinAnuncios = true;
        motor.cerrarPausa();
      });
      await t.tap(find.byKey(const ValueKey('accion-anuncio')));
      await Arnes.asentar(t);
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      expect(r.single.compro, isTrue);
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isTrue);
      while (motor.fase != FaseSesion.terminada) {
        responderBien(motor);
        motor.continuar();
        expect(motor.fase, isNot(FaseSesion.pausaPromocional));
      }
    });

    testWidgets('house-ads · Conversión atribuida: la compra en la misma sesión queda atribuida al anuncio tocado', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await montarPausa(t, a);
      final anuncio = await t.runAsync(() => a.claves.leer(claveAnuncioAnterior));
      await t.tap(find.byKey(const ValueKey('accion-anuncio')));
      await Arnes.asentar(t);
      expect(a.contenedor.read(anuncioAtribuidoProvider), anuncio);
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      expect(tienda.compras.single['attributedAdId'], anuncio);
      final pendientes = await t.runAsync(() => a.aprendizaje.pendientes(ahora: ahoraPrueba, kind: 'event'));
      expect(pendientes!.map((e) => jsonDecode(e.payload)['name']), contains('ad_cta'));
    });
  });

  group('house-ads · manos libres', () {
    testWidgets('la cuña de manos libres solo usa anuncios con texto hablado', (t) async {
      final a = Arnes();
      await t.runAsync(a.contenedorSinInterfaz);
      for (var i = 0; i < 10; i++) {
        final c = await t.runAsync(() => cunaParaManosLibres(a.contenedor.read, const DatosPausa(modo: SessionMode.handsfree, sessionId: 's', trasManosLibres: true)));
        expect(c!.cuna, isNotNull);
        expect(c.cuna, isNotEmpty);
      }
      a.contenedor.dispose();
    });
  });
}
