import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';
import 'package:volutrainmed/features/subscription/data/tienda.dart';
import 'package:volutrainmed/features/subscription/domain/entitlements_policy.dart';
import 'package:volutrainmed/features/subscription/ui/pantalla_suscripcion.dart';

import '../ads/soporte.dart';
import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';

Entitlements derechos({bool premium = true, String plan = 'annual', String status = 'active', bool trialUsed = true, DateTime? hasta, DateTime? validado}) =>
    Entitlements.fromJson(derechosJson(premium: premium, plan: plan, status: status, trialUsed: trialUsed, hasta: hasta, validado: validado));

/// Recorre una lección entera y devuelve cuántas pausas promocionales ha habido.
int pausasEnUnaLeccion(bool sinAnuncios) {
  var pausas = 0;
  final m = MotorSesion(
    contenido: contenidoPrueba,
    modo: SessionMode.lesson,
    deviceId: 'd',
    relojMs: () => 0,
    ahora: () => ahoraPrueba,
    leccion: contenidoPrueba.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l3'),
    sinAnuncios: sinAnuncios,
    azar: Random(1),
  )..preparar();
  while (m.fase != FaseSesion.terminada) {
    responderBien(m);
    m.continuar();
    if (m.fase == FaseSesion.pausaPromocional) {
      pausas++;
      m.cerrarPausa();
    }
  }
  return pausas;
}

FilledButton botonPrincipal(WidgetTester t) => t.widget<FilledButton>(find.byKey(const ValueKey('accion-principal-suscripcion')));

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('premium-subscription · pantalla de suscripción', () {
    testWidgets('premium-subscription · Inicio de la prueba: quien nunca tuvo Premium ve «Probar 7 días gratis»', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      await t.scrollUntilVisible(find.byKey(const ValueKey('accion-principal-suscripcion')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.descendant(of: find.byKey(const ValueKey('accion-principal-suscripcion')), matching: find.text('Probar 7 días gratis')), findsOneWidget);
      expect(botonPrincipal(t).onPressed, isNotNull);
    });

    testWidgets('premium-subscription · Prueba ya consumida: la acción es «Suscribirme» y no se ofrece otra prueba', (t) async {
      final tienda = TiendaSimulada()..pruebaUsada = true;
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar, derechos: derechos(premium: false, trialUsed: true));
      await a.montar(t, ruta: Rutas.suscripcion);
      await t.scrollUntilVisible(find.byKey(const ValueKey('accion-principal-suscripcion')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.descendant(of: find.byKey(const ValueKey('accion-principal-suscripcion')), matching: find.text('Suscribirme')), findsOneWidget);
      expect(find.text('Probar 7 días gratis'), findsNothing);
      expect(find.textContaining('días gratis'), findsNothing);
    });

    testWidgets('premium-subscription · Información antes de comprar: precio y periodo de cada plan, primer cobro y cómo cancelar', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: TiendaSimulada().manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      expect(find.text('39,99 €/año'), findsOneWidget);
      expect(find.text('6,99 €/mes'), findsOneWidget);
      expect(find.text('Ahorra un 52 %'), findsOneWidget);
      // 17 de noviembre + 7 días de prueba.
      expect(find.textContaining('Primer cobro el 24 de noviembre: 39,99 € al año'), findsOneWidget);
      expect(find.textContaining('se renueva salvo que canceles'), findsOneWidget);
      await t.scrollUntilVisible(find.text(textoCancelar), 100, scrollable: find.byType(Scrollable).last);
      expect(find.text(textoCancelar), findsOneWidget);
      expect(find.byKey(const ValueKey('cerrar-suscripcion')), findsOneWidget);
      // El botón de cierre se ve siempre, también al desplazarse.
      await t.scrollUntilVisible(find.byKey(const ValueKey('restaurar-compras')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const ValueKey('cerrar-suscripcion')).hitTestable(), findsOneWidget);
    });

    testWidgets('premium-subscription · Precios no disponibles: sin conexión explica que hace falta conexión y no muestra precios desactualizados', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false);
      await t.runAsync(() => a.claves.escribirJson(claveProductos, {
            'products': productosJson,
            'fetchedAt': ahoraPrueba.subtract(const Duration(days: 1)).toIso8601String(),
          }));
      await a.montar(t, ruta: Rutas.suscripcion);
      expect(find.text(textoCompraSinConexion), findsOneWidget);
      expect(find.text('39,99 €/año'), findsNothing);
      expect(find.text('6,99 €/mes'), findsNothing);
      expect(find.textContaining('€'), findsNothing);
    });

    testWidgets('precios de más de 7 días con conexión pero sin respuesta de la tienda no se muestran', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: true);
      await t.runAsync(() => a.claves.escribirJson(claveProductos, {
            'products': productosJson,
            'fetchedAt': ahoraPrueba.subtract(const Duration(days: 8)).toIso8601String(),
          }));
      await a.montar(t, ruta: Rutas.suscripcion);
      expect(find.text('39,99 €/año'), findsNothing);
      expect(find.text(textoSinPrecios), findsOneWidget);
    });

    testWidgets('offline-sync · Compra sin conexión: al intentar suscribirse sin conexión la app explica que la compra requiere conexión', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false);
      await a.montar(t, ruta: Rutas.suscripcion);
      expect(find.text(textoCompraSinConexion), findsOneWidget);
      await t.scrollUntilVisible(find.byKey(const ValueKey('accion-principal-suscripcion')), 200, scrollable: find.byType(Scrollable).last);
      expect(botonPrincipal(t).onPressed, isNull);
      expect(a.peticiones.where((r) => r.url.path == '/v1/store/purchase'), isEmpty);
    });

    testWidgets('premium-subscription · Compra cancelada: vuelve a la pantalla sin cargos y sin mensaje de error', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      await t.scrollUntilVisible(find.text('Cancelado'), 200, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Cancelado'));
      await t.pump();
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      expect(tienda.compras.single['simulate'], 'cancel');
      expect(find.byType(PantallaSuscripcion), findsOneWidget);
      expect(find.text(textoCompraFallida), findsNothing);
      expect(find.byKey(const ValueKey('reintentar-compra')), findsNothing);
      expect(a.contenedor.read(derechosEfectivosProvider).premium, isFalse);
    });

    testWidgets('premium-subscription · Compra fallida: explica que no se ha completado y ofrece reintentar', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      await t.scrollUntilVisible(find.text('Fallido'), 200, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Fallido'));
      await t.pump();
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      expect(find.text(textoCompraFallida), findsOneWidget);
      expect(find.byKey(const ValueKey('reintentar-compra')), findsOneWidget);
      // Reintento con éxito.
      await t.scrollUntilVisible(find.text('Correcto'), -200, scrollable: find.byType(Scrollable).last);
      await t.tap(find.text('Correcto'));
      await t.pump();
      await tocar(t, const ValueKey('reintentar-compra'));
      await Arnes.asentar(t);
      expect(tienda.compras.map((c) => c['simulate']), ['fail', 'ok']);
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isTrue);
    });

    testWidgets('sin cuenta, la compra explica que hace falta una cuenta y no llama a la tienda', (t) async {
      final a = Arnes(http: TiendaSimulada().manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      expect(find.text(textoNecesitaCuenta), findsOneWidget);
      expect(a.peticiones.where((r) => r.url.path == '/v1/store/purchase'), isEmpty);
    });

    testWidgets('premium-subscription · Restauración en un dispositivo nuevo: «Restaurar compras» activa Premium y no hay pausas', (t) async {
      final tienda = TiendaSimulada()
        ..premiumEnCuenta = true
        ..pruebaUsada = true;
      // Dispositivo nuevo: sin derechos guardados. Se evita la revalidación
      // al abrir para comprobar el botón «Restaurar compras».
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: (req) async {
        if (req.url.path == '/v1/entitlements') throw StateError('sin revalidar en esta prueba');
        return tienda.manejar(req);
      });
      await a.montar(t, ruta: Rutas.suscripcion);
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isFalse);
      await tocar(t, const ValueKey('restaurar-compras'));
      await Arnes.asentar(t);
      expect(find.text('Compras restauradas: Premium activo'), findsOneWidget);
      final sinAnuncios = a.contenedor.read(derechosEfectivosProvider).sinAnuncios;
      expect(sinAnuncios, isTrue);
      expect(pausasEnUnaLeccion(sinAnuncios), 0);
    });

    testWidgets('al iniciar la app con cuenta y conexión se revalidan los derechos (restauración al iniciar sesión)', (t) async {
      final tienda = TiendaSimulada()..premiumEnCuenta = true;
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await a.montar(t, ruta: Rutas.inicio);
      expect(a.peticiones.map((r) => r.url.path), contains('/v1/entitlements'));
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isTrue);
    });

    testWidgets('premium-subscription · Aviso previo al cobro: se programa una notificación local con la fecha y el importe', (t) async {
      final tienda = TiendaSimulada();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: tienda.manejar);
      await a.montar(t, ruta: Rutas.suscripcion);
      await tocar(t, const ValueKey('accion-principal-suscripcion'));
      await Arnes.asentar(t);
      final n = a.notificador.programadas[idRecordatorioPrueba]!;
      // Prueba hasta el 24 de noviembre: aviso 48 h antes (día 5 de la prueba).
      expect(n.cuando.isAtSameMomentAs(ahoraPrueba.add(const Duration(days: 5))), isTrue, reason: '${n.cuando}');
      expect(n.texto, contains('24 de noviembre'));
      expect(n.texto, contains('39,99 €'));
      // Ya programada: se entrega aunque luego no haya conexión.
      a.conectividad.conectado = false;
      expect(a.notificador.programadas.containsKey(idRecordatorioPrueba), isTrue);
    });
  });

  group('premium-subscription · derechos al abrir la app', () {
    testWidgets('premium-subscription · Dos semanas sin conexión: Premium validado hace 14 días, la lección va sin pausas', (t) async {
      final a = Arnes(conexion: false, derechos: derechos(hasta: ahoraPrueba.add(const Duration(days: 200)), validado: ahoraPrueba.subtract(const Duration(days: 14))));
      await a.montar(t, ruta: Rutas.inicio);
      expect(find.text(avisoRevalidar), findsNothing);
      final sinAnuncios = a.contenedor.read(derechosEfectivosProvider).sinAnuncios;
      expect(sinAnuncios, isTrue);
      expect(pausasEnUnaLeccion(sinAnuncios), 0);
    });

    testWidgets('premium-subscription · Más de treinta días sin conexión: aviso «Conéctate para comprobar tu suscripción» y plan gratuito', (t) async {
      final a = Arnes(conexion: false, derechos: derechos(hasta: ahoraPrueba.add(const Duration(days: 200)), validado: ahoraPrueba.subtract(const Duration(days: 31))));
      await a.montar(t, ruta: Rutas.inicio);
      expect(find.text(avisoRevalidar), findsOneWidget);
      final sinAnuncios = a.contenedor.read(derechosEfectivosProvider).sinAnuncios;
      expect(sinAnuncios, isFalse);
      expect(pausasEnUnaLeccion(sinAnuncios), greaterThan(0));
    });

    testWidgets('premium-subscription · Cancelación a mitad de periodo: sigue sin pausas los 10 días que quedan', (t) async {
      final a = Arnes(derechos: derechos(status: 'cancelled', hasta: ahoraPrueba.add(const Duration(days: 10))));
      await t.runAsync(a.contenedorSinInterfaz);
      for (var d = 0; d < 10; d++) {
        expect(derechosEfectivos(a.contenedor.read(derechosProvider), a.reloj.ahora()).sinAnuncios, isTrue, reason: 'día $d');
        a.reloj.avanzar(const Duration(days: 1));
      }
      expect(derechosEfectivos(a.contenedor.read(derechosProvider), a.reloj.ahora()).sinAnuncios, isFalse);
      a.contenedor.dispose();
    });

    testWidgets('premium-subscription · Suscripción caducada: aviso «Tu Premium ha terminado» una sola vez y vuelven las pausas', (t) async {
      final a = Arnes(conexion: false, derechos: derechos(status: 'active', hasta: ahoraPrueba.subtract(const Duration(hours: 2)), validado: ahoraPrueba.subtract(const Duration(days: 3))));
      await a.montar(t, ruta: Rutas.inicio);
      expect(find.text(avisoPremiumTerminado), findsOneWidget);
      final sinAnuncios = a.contenedor.read(derechosEfectivosProvider).sinAnuncios;
      expect(sinAnuncios, isFalse);
      expect(pausasEnUnaLeccion(sinAnuncios), greaterThan(0));
      // Segunda apertura: no se repite.
      final otra = await t.runAsync(() => avisosDerechos(a.contenedor.read));
      expect(otra, isEmpty);
    });
  });
}
