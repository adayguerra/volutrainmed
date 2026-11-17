import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/tema.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/ui/pausa_promocional.dart';
import 'package:volutrainmed/features/subscription/ui/pantalla_suscripcion.dart';

import '../helpers/arnes.dart';

/// Ayudas de las pruebas de anuncios y suscripción.

const productosJson = [
  {'id': 'vtm_premium_monthly', 'plan': 'monthly', 'price': '6.99', 'currency': 'EUR', 'period': 'P1M', 'trialDays': 7},
  {'id': 'vtm_premium_annual', 'plan': 'annual', 'price': '39.99', 'currency': 'EUR', 'period': 'P1Y', 'trialDays': 7},
];

Map<String, dynamic> derechosJson({bool premium = false, String plan = 'trial', String status = 'active', bool trialUsed = false, DateTime? hasta, DateTime? validado}) => {
      'premium': premium,
      'noAds': premium,
      'source': premium ? 'store' : 'none',
      'plan': premium ? plan : null,
      'status': premium ? status : 'none',
      'expiresAt': hasta?.toUtc().toIso8601String(),
      'renewsAt': hasta?.toUtc().toIso8601String(),
      'trialUsed': trialUsed || (premium && plan == 'trial'),
      'trialEndsAt': premium && plan == 'trial' ? hasta?.toUtc().toIso8601String() : null,
      'validatedAt': (validado ?? ahoraPrueba).toUtc().toIso8601String(),
      'organization': null,
    };

http.Response json(Object o, [int status = 200]) => http.Response(jsonEncode(o), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// Tienda de pruebas simulada como la de `services/api`.
class TiendaSimulada {
  final compras = <Map<String, dynamic>>[];
  bool premiumEnCuenta = false;
  bool pruebaUsada = false;

  Future<http.Response> manejar(http.Request req) async {
    final p = req.url.path;
    if (p == '/v1/store/products') return json({'products': productosJson, 'fetchedAt': ahoraPrueba.toIso8601String()});
    if (p == '/v1/entitlements') return json(derechosJson(premium: premiumEnCuenta, plan: 'annual', trialUsed: pruebaUsada, hasta: ahoraPrueba.add(const Duration(days: 300))));
    if (p == '/v1/store/restore') {
      return json({'entitlements': derechosJson(premium: premiumEnCuenta, plan: 'annual', trialUsed: pruebaUsada, hasta: ahoraPrueba.add(const Duration(days: 300)))});
    }
    if (p == '/v1/store/purchase') {
      final b = (jsonDecode(req.body) as Map).cast<String, dynamic>();
      compras.add(b);
      if (b['simulate'] == 'cancel') return json({'error': {'code': 'purchase_cancelled', 'message': 'Compra cancelada'}}, 409);
      if (b['simulate'] == 'fail') return json({'error': {'code': 'payment_failed', 'message': 'La tienda no ha podido completar el pago'}}, 402);
      final trial = b['withTrial'] == true;
      return json({
        'entitlements': derechosJson(premium: true, plan: trial ? 'trial' : 'annual', hasta: ahoraPrueba.add(Duration(days: trial ? 7 : 365))),
        'firstChargeAt': ahoraPrueba.add(const Duration(days: 7)).toIso8601String(),
        'firstChargeAmount': '39.99',
      });
    }
    return json({'error': {'code': 'not_found', 'message': 'No encontrado'}}, 404);
  }
}

/// Copia del contenido con otros parámetros de anuncios o campañas.
ContenidoCargado contenidoCon({AdParams? params, List<AdCampaign>? campanas}) {
  final g = contenidoPrueba.global;
  final g2 = GlobalPackage(
    contentVersion: '2026.11.9',
    minAppVersion: g.minAppVersion,
    sectors: g.sectors,
    itineraries: g.itineraries,
    skills: g.skills,
    exerciseTypes: g.exerciseTypes,
    units: g.units,
    instruments: g.instruments,
    voiceLexicon: g.voiceLexicon,
    achievements: g.achievements,
    league: g.league,
    adParams: params ?? g.adParams,
    campaigns: campanas ?? g.campaigns,
    freePlan: g.freePlan,
    orgsEnabled: g.orgsEnabled,
  );
  return ContenidoCargado(global: g2, itinerarios: contenidoPrueba.itinerarios, revocaciones: const Revocaciones());
}

/// Sesiones de práctica de [dias] días seguidos hasta ayer, de 11 minutos.
List<SessionRecord> rachaDe(int dias) => [
      for (var i = 1; i <= dias; i++)
        SessionRecord(
          id: 'racha-$i',
          deviceId: 'disp-prueba',
          mode: SessionMode.lesson,
          startedAt: ahoraPrueba.subtract(Duration(days: i)),
          endedAt: ahoraPrueba.subtract(Duration(days: i)).add(const Duration(minutes: 11)),
          completed: true,
          practiceMs: 11 * 60000,
          contentVersion: '2026.11.0',
        ),
    ];

DatosPausa datosLeccion({int ejercicios = 10, int aciertos = 4, bool ultima = false}) =>
    DatosPausa(modo: SessionMode.lesson, sessionId: 'sesion-prueba', ejerciciosLeccion: ejercicios, aciertosLeccion: aciertos, ultimaPausa: ultima);

/// Monta solo la pausa promocional (y las pantallas a las que lleva su acción).
Future<List<ResultadoPausa>> montarPausa(
  WidgetTester t,
  Arnes a, {
  DatosPausa? datos,
  Size tamano = const Size(390, 844),
  bool movimientoReducido = false,
  void Function(ResultadoPausa r)? alCerrar,
}) async {
  await t.runAsync(a.contenedorSinInterfaz);
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: movimientoReducido);
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  addTearDown(a.contenedor.dispose);
  final resultados = <ResultadoPausa>[];
  final router = GoRouter(
    initialLocation: '/pausa',
    routes: [
      GoRoute(
        path: '/pausa',
        builder: (_, _) => PausaPromocional(
          datos: datos ?? datosLeccion(),
          alCerrar: (r) {
            resultados.add(r);
            alCerrar?.call(r);
          },
        ),
      ),
      GoRoute(path: Rutas.suscripcion, builder: (_, s) => PantallaSuscripcion(anuncioId: s.uri.queryParameters['anuncio'])),
      GoRoute(path: Rutas.organizacion, builder: (_, _) => const Scaffold(body: Text('Organización'))),
      GoRoute(path: Rutas.cuenta, builder: (_, _) => const Scaffold(body: Text('Cuenta'))),
      GoRoute(path: Rutas.legal, builder: (_, _) => const Scaffold(body: Text('Legal'))),
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: a.contenedor,
    child: MaterialApp.router(theme: construirTema(Brightness.light), routerConfig: router),
  ));
  await t.pump();
  await t.pump();
  // Fundido de entrada de 150 ms (sin él, la tarjeta aún no es legible).
  await t.pump(const Duration(milliseconds: 200));
  return resultados;
}

/// Desplaza hasta el control y lo toca.
Future<void> tocar(WidgetTester t, Key k) async {
  final f = find.byKey(k);
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
  await t.tap(f);
}

/// Deja pasar la cuenta atrás de la pausa.
Future<void> esperarCuenta(WidgetTester t, [int segundos = 3]) async {
  for (var i = 0; i < segundos; i++) {
    await t.pump(const Duration(seconds: 1));
  }
  await t.pump();
}
