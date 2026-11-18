import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:volutrainmed/core/data/api_client.dart';

/// Contrato del cliente frente a `contracts/api.md` y las rutas de
/// `services/api/src/routes/{app,sync,content,store,growth-app}.ts`.
class Llamada {
  Llamada(this.req, this.body);
  final http.Request req;
  final Object? body;
}

void main() {
  late List<Llamada> llamadas;
  late http.Response Function(http.Request) respuesta;

  ApiClient cliente({String? token = 'tok'}) {
    llamadas = [];
    respuesta = (_) => http.Response('{}', 200, headers: {'content-type': 'application/json'});
    final mock = MockClient((req) async {
      llamadas.add(Llamada(req, req.body.isEmpty ? null : jsonDecode(req.body)));
      return respuesta(req);
    });
    return ApiClient(baseUrl: 'http://api.test/', client: mock, token: () => token);
  }

  test('las peticiones sin cuerpo no declaran content-type JSON', () async {
    final c = cliente();
    await c.storeRestore();
    await c.storeCancel();
    await c.exportRequest();
    await c.orgLeave();
    for (final l in llamadas) {
      expect(l.req.method, 'POST');
      expect(l.req.headers.containsKey('content-type'), isFalse, reason: l.req.url.path);
      expect(l.req.headers['authorization'], 'Bearer tok');
    }
    expect(llamadas.map((l) => l.req.url.path), ['/v1/store/restore', '/v1/store/cancel', '/v1/me/export', '/v1/orgs/leave']);
  });

  test('las peticiones con cuerpo envían JSON', () async {
    final c = cliente();
    await c.otpRequest('a@b.es');
    expect(llamadas.single.req.headers['content-type'], startsWith('application/json'));
    expect(llamadas.single.body, {'email': 'a@b.es'});
  });

  test('verificación del código con perfil local para la fusión', () async {
    final c = cliente(token: null);
    respuesta = (_) => http.Response(jsonEncode({'token': 't', 'user': {}, 'isNew': true, 'merged': true}), 200);
    final r = await c.otpVerify(email: 'a@b.es', code: '123456', deviceId: 'dev', localProfile: {'alias': 'X'});
    expect(r['token'], 't');
    expect(llamadas.single.req.url.path, '/v1/auth/otp/verify');
    expect(llamadas.single.body, {'email': 'a@b.es', 'code': '123456', 'deviceId': 'dev', 'localProfile': {'alias': 'X'}});
    expect(llamadas.single.req.headers.containsKey('authorization'), isFalse);
  });

  test('eliminar la cuenta envía la confirmación escrita', () async {
    final c = cliente();
    respuesta = (_) => http.Response('', 204);
    await c.deleteMe();
    expect(llamadas.single.req.method, 'DELETE');
    expect(llamadas.single.req.url.path, '/v1/me');
    expect(llamadas.single.body, {'confirmation': 'ELIMINAR'});
  });

  test('envío y recepción de la sincronización', () async {
    final c = cliente();
    await c.syncPush({'deviceId': 'd', 'appVersion': '1.0.0', 'attempts': [], 'sessions': [], 'events': []});
    await c.syncPull('12:3', limit: 500);
    await c.syncPull(null);
    expect(llamadas[0].req.url.path, '/v1/sync/push');
    expect((llamadas[0].body as Map).keys, containsAll(['deviceId', 'appVersion', 'attempts', 'sessions', 'events']));
    expect(llamadas[1].req.url.queryParameters, {'cursor': '12:3', 'limit': '500'});
    expect(llamadas[2].req.url.query, isEmpty);
  });

  test('manifiesto con dispositivo, versión de la app y código de prueba opcional', () async {
    final c = cliente();
    await c.manifest(deviceId: 'd', appVersion: '1.0.0');
    await c.manifest(deviceId: 'd', appVersion: '1.0.0', testCode: 'QR1');
    expect(llamadas[0].req.url.path, '/v1/content/manifest');
    expect(llamadas[0].req.url.queryParameters, {'deviceId': 'd', 'appVersion': '1.0.0'});
    expect(llamadas[1].req.url.queryParameters['testCode'], 'QR1');
  });

  test('la consulta lleva el identificador del dispositivo', () async {
    final c = cliente(token: null);
    await c.postInquiry({'id': 'q1', 'type': 'technical', 'message': 'hola', 'replyEmail': null, 'createdAt': '2026-11-17T10:00:00Z'}, deviceId: 'dev');
    expect(llamadas.single.req.url.path, '/v1/inquiries');
    expect((llamadas.single.body as Map)['deviceId'], 'dev');
    expect((llamadas.single.body as Map)['id'], 'q1');
  });

  test('rutas de tienda, organizaciones y ligas', () async {
    final c = cliente();
    await c.storeProducts();
    await c.storePurchase({'productId': 'vtm_premium_annual', 'withTrial': true, 'receipt': 'sandbox', 'simulate': 'ok', 'attributedAdId': 'PA-02'});
    await c.entitlements();
    await c.orgPreview('ABC123');
    await c.orgJoin('ABC123', true);
    await c.orgMine();
    await c.orgDomainOffer();
    await c.leagueCurrent();
    await c.leaguesPrivate();
    await c.leagueParticipation(false);
    await c.leagueParticipation(true, alias: 'Menisco12');
    expect(llamadas.map((l) => '${l.req.method} ${l.req.url.path}'), [
      'GET /v1/store/products',
      'POST /v1/store/purchase',
      'GET /v1/entitlements',
      'POST /v1/orgs/preview',
      'POST /v1/orgs/join',
      'GET /v1/orgs/mine',
      'GET /v1/orgs/domain-offer',
      'GET /v1/leagues/current',
      'GET /v1/leagues/private',
      'POST /v1/leagues/participation',
      'POST /v1/leagues/participation',
    ]);
    expect(llamadas[1].body, containsPair('attributedAdId', 'PA-02'));
    expect(llamadas[4].body, {'code': 'ABC123', 'acceptNominal': true});
    expect(llamadas[9].body, {'participate': false});
    expect(llamadas[10].body, {'participate': true, 'alias': 'Menisco12'});
  });

  test('los errores de la API se convierten en ApiException con código', () async {
    final c = cliente();
    respuesta = (_) => http.Response(jsonEncode({'error': {'code': 'seats_exhausted', 'message': 'Sin plazas'}}), 409);
    await expectLater(
      c.orgJoin('X', false),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'seats_exhausted').having((e) => e.status, 'status', 409)),
    );
  });

  test('un fallo de red se convierte en SinConexionException', () async {
    final mock = MockClient((_) async => throw http.ClientException('sin red'));
    final c = ApiClient(baseUrl: 'http://api.test', client: mock);
    await expectLater(c.me(), throwsA(isA<SinConexionException>()));
    expect(await c.health(), isFalse);
  });

  group('Descarga reanudable', () {
    test('pide el rango desde el byte alcanzado y lee el total', () async {
      final c = cliente();
      respuesta = (_) => http.Response.bytes(Uint8List.fromList([4, 5, 6]), 206, headers: {'content-range': 'bytes 3-5/6'});
      final r = await c.descargar('/v1/content/files/2026.11.1%3Ait-anestesia', desde: 3);
      expect(llamadas.single.req.headers['range'], 'bytes=3-');
      expect(r.status, 206);
      expect(r.bytes, [4, 5, 6]);
      expect(r.totalSize, 6);
    });

    test('sin rango la respuesta completa da el tamaño total', () async {
      final c = cliente();
      respuesta = (_) => http.Response.bytes(Uint8List.fromList([1, 2]), 200);
      final r = await c.descargar('it-fundamentos');
      expect(llamadas.single.req.url.path, '/v1/content/files/it-fundamentos');
      expect(llamadas.single.req.headers.containsKey('range'), isFalse);
      expect(r.totalSize, 2);
    });

    test('416 al final del archivo significa descarga ya completa', () async {
      final c = cliente();
      respuesta = (_) => http.Response('', 416, headers: {'content-range': 'bytes */6'});
      final r = await c.descargar('/v1/content/files/x', desde: 6);
      expect(r.status, 416);
      expect(r.bytes, isEmpty);
      expect(r.totalSize, 6);
    });

    test('otros errores de descarga se notifican', () async {
      final c = cliente();
      respuesta = (_) => http.Response('', 404);
      await expectLater(c.descargar('/v1/content/files/x'), throwsA(isA<ApiException>()));
    });
  });
}
