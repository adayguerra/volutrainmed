import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// URL base de la API, configurable con `--dart-define=API_BASE=`.
const apiBaseDefecto = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8787');

/// Error de la API con el formato `{ error: { code, message } }`.
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => 'ApiException($status, $code): $message';
}

/// No se ha podido contactar con el servidor (sin conexión, tiempo agotado…).
class SinConexionException implements Exception {
  const SinConexionException([this.detalle = '']);
  final String detalle;
  @override
  String toString() => 'SinConexionException: $detalle';
}

/// Respuesta binaria (descarga reanudable con `Range`).
class RespuestaBytes {
  const RespuestaBytes(this.status, this.bytes, this.totalSize);
  final int status;
  final Uint8List bytes;
  final int? totalSize;
}

/// Cliente HTTP de la app según `contracts/api.md`. No se usa nunca desde el
/// módulo de voz: la voz no tiene ruta de red.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client, this.token, this.timeout = const Duration(seconds: 15)})
      : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  /// Token JWT de la cuenta, o null con perfil local.
  String? Function()? token;

  Uri _u(String path, [Map<String, String>? q]) {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$b$path').replace(queryParameters: (q == null || q.isEmpty) ? null : q);
  }

  Map<String, String> _headers({bool json = true, Map<String, String>? extra}) {
    final t = token?.call();
    return {
      if (json) 'content-type': 'application/json',
      'accept': 'application/json',
      if (t != null) 'authorization': 'Bearer $t',
      ...?extra,
    };
  }

  bool get conCuenta => token?.call() != null;

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    // Sin cuerpo no se envía `content-type: application/json`: el servidor
    // (Fastify) rechaza un cuerpo JSON vacío con un error 400/500.
    final req = http.Request(method, _u(path, query))..headers.addAll(_headers(json: body != null));
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException catch (e) {
      throw SinConexionException('$e');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw SinConexionException('$e');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    String code = 'http_${res.statusCode}';
    String message = 'Error del servidor';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final e = (j as Map)['error'] as Map?;
      code = '${e?['code'] ?? code}';
      message = '${e?['message'] ?? message}';
    } catch (_) {}
    throw ApiException(res.statusCode, code, message);
  }

  Future<Map<String, dynamic>> _obj(String method, String path, {Object? body, Map<String, String>? query}) async {
    final r = await _send(method, path, body: body, query: query);
    return r is Map ? r.cast<String, dynamic>() : <String, dynamic>{};
  }

  // ---- Salud ---------------------------------------------------------------
  Future<bool> health() async {
    try {
      final r = await _obj('GET', '/v1/health');
      return r['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ---- Autenticación -------------------------------------------------------
  Future<void> otpRequest(String email) => _send('POST', '/v1/auth/otp/request', body: {'email': email});

  Future<Map<String, dynamic>> otpVerify({required String email, required String code, required String deviceId, Map<String, dynamic>? localProfile}) =>
      _obj('POST', '/v1/auth/otp/verify', body: {'email': email, 'code': code, 'deviceId': deviceId, 'localProfile': ?localProfile});

  /// Apple o Google. En desarrollo, `idToken = "dev:<email>"`.
  Future<Map<String, dynamic>> oauth({required String provider, required String idToken, required String deviceId, Map<String, dynamic>? localProfile}) =>
      _obj('POST', '/v1/auth/$provider', body: {'idToken': idToken, 'deviceId': deviceId, 'localProfile': ?localProfile});

  Future<Map<String, dynamic>> me() => _obj('GET', '/v1/me');
  Future<Map<String, dynamic>> patchMe(Map<String, dynamic> campos) => _obj('PATCH', '/v1/me', body: campos);
  Future<Map<String, dynamic>> exportRequest() => _obj('POST', '/v1/me/export');
  Future<Map<String, dynamic>> exportStatus(String id) => _obj('GET', '/v1/me/export/$id');
  Future<void> deleteMe() => _send('DELETE', '/v1/me', body: {'confirmation': 'ELIMINAR'});
  Future<Map<String, dynamic>> registerDevice(Map<String, dynamic> d) => _obj('POST', '/v1/devices', body: d);

  // ---- Sincronización ------------------------------------------------------
  Future<Map<String, dynamic>> syncPush(Map<String, dynamic> req) => _obj('POST', '/v1/sync/push', body: req);
  Future<Map<String, dynamic>> syncPull(String? cursor, {int? limit}) =>
      _obj('GET', '/v1/sync/pull', query: {'cursor': ?cursor, if (limit != null) 'limit': '$limit'});
  Future<Map<String, dynamic>> events(String deviceId, List<Map<String, dynamic>> events) =>
      _obj('POST', '/v1/events', body: {'deviceId': deviceId, 'events': events});

  // ---- Contenido -----------------------------------------------------------
  Future<Map<String, dynamic>> manifest({required String deviceId, required String appVersion, String? testCode}) =>
      _obj('GET', '/v1/content/manifest', query: {'deviceId': deviceId, 'appVersion': appVersion, 'testCode': ?testCode});

  Future<Map<String, dynamic>> revocations() => _obj('GET', '/v1/content/revocations');

  /// Descarga con `Range: bytes=<desde>-` (reanudable, 206) o completa (200).
  Future<RespuestaBytes> descargar(String pathOrUrl, {int desde = 0}) async {
    final uri = pathOrUrl.startsWith('http') ? Uri.parse(pathOrUrl) : _u(pathOrUrl.startsWith('/') ? pathOrUrl : '/v1/content/files/$pathOrUrl');
    final req = http.Request('GET', uri)..headers.addAll(_headers(json: false, extra: {if (desde > 0) 'range': 'bytes=$desde-'}));
    try {
      final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60)));
      final cr = res.headers['content-range'];
      // 416: el rango empieza en el final del archivo, es decir, la descarga
      // parcial ya estaba completa. No es un fallo: se devuelve vacío.
      if (res.statusCode == 416 && desde > 0) {
        final t = (cr != null && cr.contains('/')) ? int.tryParse(cr.split('/').last) : null;
        if (t == null || t <= desde) return RespuestaBytes(416, Uint8List(0), t ?? desde);
      }
      if (res.statusCode != 200 && res.statusCode != 206) throw ApiException(res.statusCode, 'download_failed', 'Descarga fallida');
      int? total;
      if (cr != null && cr.contains('/')) total = int.tryParse(cr.split('/').last);
      return RespuestaBytes(res.statusCode, res.bodyBytes, total ?? (res.statusCode == 200 ? res.bodyBytes.length : null));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw SinConexionException('$e');
    }
  }

  /// Clave pública de firma (Ed25519 en bruto, 32 bytes en base64). La app la
  /// lleva fijada; esta llamada solo sirve para comprobar el `keyId`.
  Future<Map<String, dynamic>> publicKey() => _obj('GET', '/v1/content/public-key');

  Future<Map<String, dynamic>> voicePack() => _obj('GET', '/v1/voice/pack');

  // ---- Consultas -----------------------------------------------------------
  /// `deviceId` permite enlazar la consulta a la cuenta si se crea después.
  Future<Map<String, dynamic>> postInquiry(Map<String, dynamic> i, {String? deviceId}) =>
      _obj('POST', '/v1/inquiries', body: {...i, 'deviceId': ?deviceId});
  Future<Map<String, dynamic>> inquiries() => _obj('GET', '/v1/inquiries');

  // ---- Tienda de pruebas ---------------------------------------------------
  Future<Map<String, dynamic>> storeProducts() => _obj('GET', '/v1/store/products');
  Future<Map<String, dynamic>> storePurchase(Map<String, dynamic> body) => _obj('POST', '/v1/store/purchase', body: body);
  Future<Map<String, dynamic>> storeRestore() => _obj('POST', '/v1/store/restore');
  Future<Map<String, dynamic>> storeCancel() => _obj('POST', '/v1/store/cancel');
  Future<Map<String, dynamic>> entitlements() => _obj('GET', '/v1/entitlements');

  // ---- Organizaciones y ligas ----------------------------------------------
  Future<Map<String, dynamic>> orgPreview(String code) => _obj('POST', '/v1/orgs/preview', body: {'code': code});
  Future<Map<String, dynamic>> orgJoin(String code, bool acceptNominal) =>
      _obj('POST', '/v1/orgs/join', body: {'code': code, 'acceptNominal': acceptNominal});
  Future<Map<String, dynamic>> orgMine() => _obj('GET', '/v1/orgs/mine');
  Future<Map<String, dynamic>> orgDomainOffer() => _obj('GET', '/v1/orgs/domain-offer');
  Future<void> orgLeave() => _send('POST', '/v1/orgs/leave');
  Future<Map<String, dynamic>> leagueCurrent() => _obj('GET', '/v1/leagues/current');
  Future<Map<String, dynamic>> leaguesPrivate() => _obj('GET', '/v1/leagues/private');
  Future<Map<String, dynamic>> leagueParticipation(bool participate, {String? alias}) =>
      _obj('POST', '/v1/leagues/participation', body: {'participate': participate, 'alias': ?alias});
}
