import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/sync/sincronizador.dart';
import 'package:volutrainmed/features/account/servicio_cuenta.dart';

import '../helpers/arnes.dart';

/// Pruebas del acceso a la cuenta (M02–M03).

class SincronizadorFalso implements Sincronizador {
  int sincronizaciones = 0;
  int recuperaciones = 0;
  @override
  ValueListenable<EstadoSync> get estado => ValueNotifier(const EstadoSync());
  @override
  Future<void> sincronizar({bool forzar = false}) async => sincronizaciones++;
  @override
  Future<void> recuperarHistorial() async => recuperaciones++;
  @override
  Future<void> refrescar() async {}
}

class ArnesCuenta extends Arnes {
  ArnesCuenta({super.usuario, super.http, super.conexion, super.sesiones});
  final sync = SincronizadorFalso();
  @override
  List<Override> get overrides => [...super.overrides, sincronizadorProvider.overrideWithValue(sync)];
}

http.Response json(Object cuerpo, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(cuerpo)), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> usuarioServidor({String? sector = 'enfermeria'}) => {
      'id': 'u-1',
      'email': 'lucia@correo.es',
      'alias': 'MeniscoÁgil12',
      'sectorId': sector,
      'itineraryId': 'it-fundamentos',
      'declaredLevel': 'afianzar',
      'goal': {'kind': 'daily', 'minutes': 10},
      'disclaimerAcceptedAt': '2026-11-14T10:00:00.000Z',
      'leaguesOptIn': true,
      'createdAt': '2026-11-17T10:00:00.000Z',
    };

/// API simulada del acceso. [codigoBueno] es el único código válido.
ManejadorHttp apiAcceso({String codigoBueno = '482913', Map<String, dynamic>? oferta}) => (req) async {
      switch (req.url.path) {
        case '/v1/auth/otp/request':
          return http.Response('', 204);
        case '/v1/auth/otp/verify':
          final b = jsonDecode(req.body) as Map;
          if (b['code'] != codigoBueno) return json({'error': {'code': 'invalid_code', 'message': 'El código no es correcto'}}, 400);
          return json({
            'token': 'tok-1',
            'user': usuarioServidor(),
            'isNew': false,
            'merged': true,
            'entitlements': {'premium': false, 'noAds': false, 'source': 'none', 'status': 'none', 'trialUsed': false, 'validatedAt': '2026-11-17T10:00:00.000Z'},
          });
        case '/v1/orgs/domain-offer':
          return json({'organization': oferta});
      }
      return json({'error': {'code': 'not_found', 'message': 'No'}}, 404);
    };

Future<void> tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await Arnes.asentar(t);
}

List<http.Request> verificaciones(Arnes a) => a.peticiones.where((r) => r.url.path == '/v1/auth/otp/verify').toList();

void main() {
  setUpAll(cargarContenidoDePrueba);

  String rutaCodigo(String email) => Uri(path: Rutas.codigo, queryParameters: {'email': email}).toString();

  testWidgets('onboarding-account · Código correcto: la sesión se inicia al completar la sexta cifra', (t) async {
    final a = ArnesCuenta(http: apiAcceso());
    await a.montar(t, ruta: rutaCodigo('lucia@correo.es'));
    expect(find.text('Revisa tu correo'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '48291');
    await Arnes.asentar(t);
    expect(verificaciones(a), isEmpty, reason: 'con cinco cifras aún no se comprueba');
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '482913');
    await Arnes.asentar(t);
    expect(verificaciones(a), hasLength(1));
    final u = a.contenedor.read(usuarioProvider).value!;
    expect(u.conCuenta, isTrue);
    expect(u.token, 'tok-1');
    expect(u.perfil!.email, 'lucia@correo.es');
    expect(a.ubicacion.ruta, Rutas.inicio);
  });

  testWidgets('onboarding-account · Código incorrecto: se indica junto al campo y se puede pedir otro sin borrar el correo', (t) async {
    final a = ArnesCuenta(http: apiAcceso());
    await a.montar(t, ruta: rutaCodigo('lucia@correo.es'));
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '111111');
    await Arnes.asentar(t);
    expect(find.byKey(const ValueKey('error-codigo')), findsOneWidget);
    expect(find.text(textoCodigoIncorrecto), findsOneWidget);
    expect(a.contenedor.read(usuarioProvider).value!.conCuenta, isFalse);
    // Se puede pedir otro código al momento.
    final reenviar = find.widgetWithText(TextButton, 'Reenviar el código');
    expect(t.widget<TextButton>(reenviar).onPressed, isNotNull);
    await tocar(t, reenviar);
    expect(a.peticiones.where((r) => r.url.path == '/v1/auth/otp/request'), hasLength(1));
    expect(jsonDecode(a.peticionesSinContenido.last.body)['email'], 'lucia@correo.es');
    // Al volver a la pantalla del correo, el correo escrito sigue ahí.
    await tocar(t, find.byTooltip('Cambiar el correo'));
    expect(t.widget<TextField>(find.byKey(const ValueKey('campo-correo'))).controller!.text, 'lucia@correo.es');
  });

  testWidgets('el correo lleva a la pantalla del código y envía la solicitud', (t) async {
    final a = ArnesCuenta(http: apiAcceso());
    await a.montar(t, ruta: Rutas.cuenta);
    expect(find.text('Guarda tu progreso'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('campo-correo')), 'Lucia@Correo.es');
    await Arnes.asentar(t);
    await tocar(t, find.text('Enviarme el código'));
    expect(a.peticionesSinContenido.single.url.path, '/v1/auth/otp/request');
    expect(a.ubicacion.ruta, rutaCodigo('lucia@correo.es'));
  });

  testWidgets('onboarding-account · Fusión al registrarse: el perfil local viaja para fusionarse y su progreso sube por sincronización', (t) async {
    final sesiones = [
      for (var i = 1; i <= 3; i++)
        SessionRecord(
          id: 's$i',
          deviceId: 'disp-prueba',
          mode: SessionMode.lesson,
          lessonId: 'u-f-1-l$i',
          startedAt: ahoraPrueba.subtract(Duration(days: i)),
          endedAt: ahoraPrueba.subtract(Duration(days: i)).add(const Duration(minutes: 5)),
          completed: true,
          practiceMs: 300000,
          contentVersion: '2026.11.0',
        ),
    ];
    final a = ArnesCuenta(http: apiAcceso(), sesiones: sesiones);
    await a.montar(t, ruta: rutaCodigo('lucia@correo.es'));
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '482913');
    await Arnes.asentar(t);
    final cuerpo = jsonDecode(verificaciones(a).single.body) as Map;
    expect(cuerpo['deviceId'], 'disp-prueba');
    final local = cuerpo['localProfile'] as Map;
    expect(local['sectorId'], 'enfermeria');
    expect(local['itineraryId'], 'it-fundamentos');
    expect(local['alias'], 'MeniscoÁgil12');
    expect(local['disclaimerAcceptedAt'], isNotNull);
    // Tras el acceso se sube la bandeja de salida y se baja el historial.
    expect(a.sync.sincronizaciones, 1);
    expect(a.sync.recuperaciones, 1);
    // Las tres lecciones siguen en el dispositivo, ya con la cuenta.
    final p = a.contenedor.read(proyeccionProvider)!;
    expect(['u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3'].every((id) => p.lecciones[id]?.completada == true), isTrue);
    expect(a.contenedor.read(usuarioProvider).value!.conCuenta, isTrue);
  });

  testWidgets('offline-sync · Crear la cuenta sin conexión: se explica que hace falta conexión y el progreso sigue en el perfil local', (t) async {
    final a = ArnesCuenta(http: apiAcceso(), conexion: false);
    await a.montar(t, ruta: Rutas.cuenta);
    expect(find.text(textoCuentaSinConexion), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('campo-correo')), 'lucia@correo.es');
    await Arnes.asentar(t);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviarme el código')).onPressed, isNull);
    expect(a.peticionesSinContenido, isEmpty);
    // «Ahora no» conserva el perfil local y deja el recordatorio pendiente.
    await tocar(t, find.text('Ahora no'));
    final u = a.contenedor.read(usuarioProvider).value!;
    expect(u.conCuenta, isFalse);
    expect(u.perfil!.alias, 'MeniscoÁgil12');
    expect(u.registroPospuesto, isTrue);
    expect(a.ubicacion.ruta, Rutas.inicio);
  });

  testWidgets('organizations · Dominio autorizado: tras registrarse con un correo del dominio se ofrece unirse', (t) async {
    final a = ArnesCuenta(http: apiAcceso(oferta: {'id': 'org-1', 'name': 'Hospital Simulado del Turia', 'nominal': false, 'code': 'TURIA1'}));
    await a.montar(t, ruta: rutaCodigo('lucia@hospital.es'));
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '482913');
    await Arnes.asentar(t);
    expect(find.text('Tu organización te ofrece una plaza'), findsOneWidget);
    expect(find.textContaining('Hospital Simulado del Turia'), findsOneWidget);
    await tocar(t, find.text('Ver la organización'));
    expect(a.ubicacion.ruta, Rutas.organizacion);
  });

  testWidgets('«Ya tengo cuenta» con una cuenta completa termina el alta y abre Inicio', (t) async {
    final a = ArnesCuenta(http: apiAcceso(), usuario: const EstadoUsuario(deviceId: 'disp-prueba'));
    await a.montar(t, ruta: Rutas.bienvenida);
    await tocar(t, find.text('Ya tengo cuenta'));
    expect(find.text('Entra en tu cuenta'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('campo-correo')), 'lucia@correo.es');
    await Arnes.asentar(t);
    await tocar(t, find.text('Enviarme el código'));
    await t.enterText(find.byKey(const ValueKey('campo-codigo')), '482913');
    await Arnes.asentar(t);
    final u = a.contenedor.read(usuarioProvider).value!;
    expect(u.altaCompletada, isTrue);
    expect(u.perfil!.sectorId, 'enfermeria');
    expect(a.ubicacion.ruta, Rutas.inicio);
  });

  testWidgets('Apple y Google de desarrollo envían el token «dev:» con el correo', (t) async {
    final a = ArnesCuenta(http: (req) async {
      if (req.url.path == '/v1/auth/google') {
        return json({'token': 'tok-g', 'user': usuarioServidor(), 'isNew': true, 'merged': true});
      }
      return apiAcceso()(req);
    });
    await a.montar(t, ruta: Rutas.cuenta);
    await tocar(t, find.text('Continuar con Google'));
    expect(find.textContaining('Escribe tu correo arriba'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('campo-correo')), 'lucia@correo.es');
    await Arnes.asentar(t);
    await tocar(t, find.text('Continuar con Google'));
    final r = a.peticiones.firstWhere((r) => r.url.path == '/v1/auth/google');
    expect(jsonDecode(r.body)['idToken'], 'dev:lucia@correo.es');
    expect(a.contenedor.read(usuarioProvider).value!.token, 'tok-g');
  });
}
