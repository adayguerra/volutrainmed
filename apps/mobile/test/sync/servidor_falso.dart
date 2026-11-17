import 'dart:convert';

import 'package:http/http.dart' as http;

/// Servidor mínimo en memoria con el comportamiento del contrato de
/// sincronización: subida idempotente por `id`, recepción con cursor,
/// eventos y consultas.
class ServidorFalso {
  final intentos = <String, Map<String, dynamic>>{};
  final orden = <String>[];
  final sesiones = <String, Map<String, dynamic>>{};
  final ordenSesiones = <String>[];
  final eventos = <String>{};
  final consultas = <String, Map<String, dynamic>>{};
  final lotes = <List<String>>[];
  int duplicados = 0;

  /// Respuesta forzada para la próxima subida (p. ej. corte tras recibirla).
  Future<http.Response> Function(http.Request)? proximaSubida;

  static http.Response json(Object o, [int status = 200]) =>
      http.Response(jsonEncode(o), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> manejar(http.Request r) async {
    final p = r.url.path;
    if (p == '/v1/sync/push' && r.method == 'POST') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final ids = <String>[];
      var acc = 0;
      for (final a in (b['attempts'] as List).cast<Map<String, dynamic>>()) {
        ids.add('${a['id']}');
        if (intentos.containsKey(a['id'])) {
          duplicados++;
        } else {
          intentos['${a['id']}'] = a;
          orden.add('${a['id']}');
          acc++;
        }
      }
      for (final s in (b['sessions'] as List).cast<Map<String, dynamic>>()) {
        if (!sesiones.containsKey(s['id'])) {
          sesiones['${s['id']}'] = s;
          ordenSesiones.add('${s['id']}');
        }
      }
      for (final e in (b['events'] as List).cast<Map>()) {
        eventos.add('${e['id']}');
      }
      lotes.add(ids);
      final forzada = proximaSubida;
      if (forzada != null) {
        proximaSubida = null;
        return forzada(r);
      }
      return json({
        'accepted': {'attempts': acc, 'sessions': 0, 'events': 0},
        'duplicates': {'attempts': ids.length - acc, 'sessions': 0, 'events': 0},
        'serverTime': '2026-11-17T10:00:00Z',
      });
    }
    if (p == '/v1/sync/pull') {
      final cur = (r.url.queryParameters['cursor'] ?? '0:0').split(':').map(int.parse).toList();
      final a = orden.skip(cur[0]).map((id) => intentos[id]).toList();
      final s = ordenSesiones.skip(cur[1]).map((id) => sesiones[id]).toList();
      return json({'attempts': a, 'sessions': s, 'cursor': '${orden.length}:${ordenSesiones.length}', 'hasMore': false});
    }
    if (p == '/v1/events') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      for (final e in (b['events'] as List).cast<Map>()) {
        eventos.add('${e['id']}');
      }
      return json({'accepted': (b['events'] as List).length});
    }
    if (p == '/v1/inquiries' && r.method == 'POST') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      consultas['${b['id']}'] = b;
      return json({'id': b['id'], 'reference': 'C-REF${consultas.length}', 'status': 'received'});
    }
    if (p == '/v1/inquiries') {
      return json({
        'items': [for (final c in consultas.values) {'id': c['id'], 'reference': 'C-REF1', 'type': c['type'], 'message': c['message'], 'status': 'received', 'reply': null}],
      });
    }
    return json({'error': {'code': 'not_found', 'message': 'No encontrado'}}, 404);
  }
}
