import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/contenido/actualizador.dart';
import 'package:volutrainmed/features/voice/data/paquete_voz.dart';

import '../helpers/arnes.dart';

/// Ajuste «Descargar solo con wifi»: con datos móviles no se bajan paquetes
/// de contenido ni el paquete de voz, salvo permiso expreso del usuario.
void main() {
  setUpAll(cargarContenidoDePrueba);

  final manifiesto = jsonDecode(File('test/contenido/fixtures/manifest-2026.11.1.json').readAsStringSync()) as Map<String, dynamic>;
  final archivos = {
    '2026.11.1:global': File('test/contenido/fixtures/global-2026.11.1.gz').readAsBytesSync(),
    '2026.11.1:it-fundamentos': File('test/contenido/fixtures/it-fundamentos-2026.11.1.gz').readAsBytesSync(),
    '2026.11.0:it-anestesia': File('../../contracts/sample/it-anestesia.json.gz').readAsBytesSync(),
  };
  final muestra = jsonDecode(File('../../contracts/sample/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  final anestesia = (muestra['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['id'] == 'it-anestesia');

  /// Manifiesto 2026.11.1 con una retirada y el itinerario de anestesia de
  /// la muestra (firmado con la clave de la app).
  Map<String, dynamic> manifiestoConRetirada() => {
        ...manifiesto,
        'revocations': {
          'version': 7,
          'templateIds': ['tpl-f-mg-ug'],
          'questionIds': [],
          'variantIds': [],
        },
        'packages': [
          ...(manifiesto['packages'] as List).where((p) => (p as Map)['itineraryId'] == 'it-fundamentos'),
          {...anestesia, 'url': '/v1/content/files/2026.11.0%3Ait-anestesia', 'itineraryId': 'it-anestesia'},
        ],
      };

  Future<http.Response> servidor(http.Request r) async {
    if (r.url.path == '/v1/content/manifest') {
      return http.Response.bytes(utf8.encode(jsonEncode(manifiestoConRetirada())), 200, headers: {'content-type': 'application/json'});
    }
    if (r.url.path.startsWith('/v1/content/files/')) {
      final id = Uri.decodeComponent(r.url.pathSegments.last);
      final b = archivos[id] ?? archivos['2026.11.0:$id'];
      return b == null ? http.Response('', 404) : http.Response.bytes(b, 200);
    }
    return http.Response('', 404);
  }

  List<http.Request> descargas(Arnes a) => a.peticiones.where((r) => r.url.path.startsWith('/v1/content/files/')).toList();

  Future<Arnes> preparar({bool soloWifi = true, bool datos = true}) async {
    final a = Arnes(http: servidor, ajustes: Ajustes(soloWifi: soloWifi));
    a.conectividad.datosMoviles = datos;
    await a.contenedorSinInterfaz();
    await a.deps.repositorio.instalarIncluido();
    return a;
  }

  test('solo wifi con datos móviles: la comprobación aplica la lista de retirada pero no descarga paquetes', () async {
    final a = await preparar();
    final act = a.contenedor.read(actualizadorProvider);
    await act.comprobar();
    expect(descargas(a), isEmpty, reason: 'ningún paquete por datos móviles');
    expect(await a.almacenContenido.paquetes(status: 'staged'), isEmpty);
    expect(act.estado.value.esperaWifi, isTrue);
    expect(a.contenedor.read(contenidoProvider).value!.revocaciones.templateIds, {'tpl-f-mg-ug'}, reason: 'la retirada no espera a la wifi');

    // Al pasar a wifi, la misma comprobación descarga y prepara la versión.
    a.conectividad.datosMoviles = false;
    await act.comprobar();
    expect(descargas(a), hasLength(2));
    expect(act.estado.value.esperaWifi, isFalse);
    expect(act.estado.value.preparada, '2026.11.1');
  });

  test('con el ajuste desactivado se descarga también con datos móviles', () async {
    final a = await preparar(soloWifi: false);
    await a.contenedor.read(actualizadorProvider).comprobar();
    expect(descargas(a), hasLength(2));
  });

  test('una descarga pedida con datos móviles se rechaza con el motivo y se permite con permiso expreso', () async {
    final a = await preparar();
    final act = a.contenedor.read(actualizadorProvider);
    await expectLater(
      act.descargarItinerario('it-anestesia'),
      throwsA(isA<SoloWifi>().having((e) => e.mensaje, 'mensaje', textoSoloWifi)),
    );
    expect(descargas(a), isEmpty);
    await act.descargarItinerario('it-anestesia', conDatos: true);
    expect(descargas(a), hasLength(1));
    expect((await a.almacenContenido.paquetes(status: 'staged')).single.clave, 'it-anestesia');
  });

  test('el paquete de voz tampoco se descarga con datos móviles sin permiso', () async {
    final meta = (jsonDecode(File('test/voice/fixtures/voice-pack.json').readAsStringSync()) as Map).cast<String, dynamic>();
    final bytes = File('test/voice/fixtures/voice-pack.gz').readAsBytesSync();
    final a = Arnes(
      ajustes: const Ajustes(soloWifi: true),
      http: (r) async => r.url.path == '/v1/voice/pack'
          ? http.Response(jsonEncode(meta), 200, headers: {'content-type': 'application/json'})
          : http.Response.bytes(bytes, 200),
    );
    a.conectividad.datosMoviles = true;
    await a.contenedorSinInterfaz();
    final s = ServicioPaqueteVoz(api: a.deps.api, claves: a.deps.claves, restringido: a.contenedor.read(restriccionWifiProvider));
    await expectLater(s.descargar(), throwsA(isA<SoloWifi>()));
    expect(a.peticiones, isEmpty);
    expect(await s.instalado(), isNull);
    final p = await s.descargar(conDatos: true);
    expect((await s.instalado())!.version, p.version);
  });

  testWidgets('el centro de descargas explica el ajuste y ofrece «Descargar ahora con datos»', (t) async {
    final a = Arnes(http: servidor, ajustes: const Ajustes(soloWifi: true));
    a.conectividad.datosMoviles = true;
    await a.montar(t, ruta: Rutas.sincronizacion);
    await t.runAsync(() => a.deps.repositorio.instalarIncluido());
    final boton = find.widgetWithText(TextButton, 'Descargar').first;
    await t.ensureVisible(boton);
    await t.tap(boton);
    await Arnes.asentar(t);
    expect(find.text(textoSoloWifi), findsOneWidget);
    expect(descargas(a), isEmpty);

    // «Esperar a la wifi» no descarga nada.
    await t.tap(find.text('Esperar a la wifi'));
    await Arnes.asentar(t);
    expect(descargas(a), isEmpty);

    // «Descargar ahora con datos» sí.
    await t.tap(find.widgetWithText(TextButton, 'Descargar').first);
    await Arnes.asentar(t);
    await t.tap(find.text('Descargar ahora con datos'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await Arnes.asentar(t);
    expect(descargas(a).map((r) => Uri.decodeComponent(r.url.pathSegments.last)), contains('2026.11.0:it-anestesia'));
  });
}
