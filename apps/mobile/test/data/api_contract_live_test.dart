@Tags(['live'])
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/core/data/api_client.dart';
import 'package:volutrainmed/core/domain/ids.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

/// Prueba de contrato contra la API real (`services/api` en marcha).
/// Solo se ejecuta con `VTM_API_LIVE=1 flutter test test/data/api_contract_live_test.dart`.
void main() {
  final base = Platform.environment['VTM_API_BASE'] ?? 'http://localhost:8787';
  final activa = Platform.environment['VTM_API_LIVE'] == '1';

  test('flujo completo de la app contra la API local', () async {
    String? token;
    final api = ApiClient(baseUrl: base, token: () => token);
    expect(await api.health(), isTrue);

    final email = 'contrato.${Random().nextInt(1 << 30)}@example.com';
    await api.otpRequest(email);
    final buzon = await http.get(Uri.parse('$base/v1/dev/mailbox?email=$email'));
    final codigo = RegExp(r'"body":"(\d{6})"').firstMatch(buzon.body)!.group(1)!;
    final s = await api.otpVerify(email: email, code: codigo, deviceId: 'dev-contrato', localProfile: {'alias': '', 'sectorId': 'veterinaria'});
    token = s['token'] as String;
    expect((s['user'] as Map)['sectorId'], 'veterinaria');

    final a = Attempt(
      id: nuevoId(),
      sessionId: nuevoId(),
      deviceId: 'dev-contrato',
      mode: SessionMode.lesson,
      lessonId: 'u-f-1-l1',
      templateId: 'tpl-f-mg-ug',
      variantId: 'tpl-f-mg-ug.v1.L1.x',
      skillId: 'H1',
      exerciseTypeId: 'T1',
      level: 1,
      answerValue: '1000',
      answerUnit: 'µg',
      verdict: Verdict.correct,
      responseMs: 9000,
      targetMs: 15000,
      points: 10,
      contentVersion: '2026.11.0',
      deviceTime: DateTime.now().toUtc(),
    );
    final lote = {'deviceId': 'dev-contrato', 'appVersion': '1.0.0', 'attempts': [a.toJson()], 'sessions': [], 'events': []};
    final r1 = await api.syncPush(lote);
    final r2 = await api.syncPush(lote);
    expect((r1['accepted'] as Map)['attempts'], 1);
    expect((r2['duplicates'] as Map)['attempts'], 1);

    final pull = await api.syncPull(null);
    final recibidos = (pull['attempts'] as List).map((e) => Attempt.fromJson((e as Map).cast())).toList();
    expect(recibidos.single.id, a.id);
    expect(recibidos.single.answerValue, '1000');

    expect((await api.storeRestore())['entitlements'], isA<Map>());
    expect((await api.storeProducts())['products'], hasLength(2));
    expect((await api.leagueCurrent())['participating'], isA<bool>());
    final m = await api.manifest(deviceId: 'dev-contrato', appVersion: '1.0.0');
    expect(m['contentVersion'], isNotNull);
    await api.deleteMe();
  }, skip: activa ? false : 'Requiere VTM_API_LIVE=1 y la API en marcha');
}
