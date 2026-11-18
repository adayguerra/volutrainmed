import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/timetrial/data/controlador_crono.dart';
import 'package:volutrainmed/features/timetrial/ui/pantalla_contrarreloj.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';

/// Ayudas de las pruebas del contrarreloj.

ControladorCrono get crono => PantallaContrarreloj.ultimo!;

/// 20 aciertos de H1 en dos días distintos: H1 queda consolidada.
List<Attempt> intentosConsolidanH1() => [
      for (var i = 0; i < 20; i++)
        f.intento(t: f.dia(i < 10 ? -1 : 0, 9, i), skill: 'H1', plantilla: 'tpl-f-mg-ug', responseMs: 8000, targetMs: 15000),
    ];

/// Algunos ejercicios de H2: en aprendizaje.
List<Attempt> intentosH2EnAprendizaje() => [
      for (var i = 0; i < 4; i++) f.intento(t: f.dia(0, 8, i), skill: 'H2', plantilla: 'tpl-f-pct-mgml', correcto: i.isEven),
    ];

/// Marca válida anterior de H1 con [aciertos].
SessionRecord marcaAnterior(int aciertos) => SessionRecord(
      id: 'crono-previo',
      deviceId: 'disp-prueba',
      mode: SessionMode.timetrial,
      skillId: 'H1',
      startedAt: f.dia(-1, 12),
      endedAt: f.dia(-1, 12, 1),
      completed: true,
      practiceMs: 60000,
      contentVersion: '2026.11.0',
      summary: SessionSummary(correct: aciertos, total: aciertos, errors: 0, accuracy: 1, valid: true, avgMs: 3500),
    );

Future<void> asentarPoco(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 120));
  }
}

/// Responde el ejercicio actual desde la interfaz, bien o mal.
Future<void> responderCrono(WidgetTester t, {required bool bien}) async {
  final v = crono.actual;
  if (crono.bloque == 'numeric_unit') {
    final valor = bien ? formatEs(v.answer!.value) : formatEs(canon(dec(v.answer!.value) * dec('3') + dec('1')));
    for (final ch in valor.split('')) {
      await t.tap(find.byKey(ValueKey('tecla-$ch')));
    }
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('comprobar-crono')));
    await t.tap(find.byKey(const ValueKey('comprobar-crono')));
  } else {
    final o = v.options!.firstWhere((o) => o.correct == bien);
    await t.ensureVisible(find.byKey(ValueKey('opcion-${o.id}')));
    await t.tap(find.byKey(ValueKey('opcion-${o.id}')));
  }
  await t.pump();
  if (!bien) {
    // La respuesta correcta se muestra 1,2 s antes del siguiente.
    await t.pump(const Duration(milliseconds: 1300));
  }
}

/// API simulada para la sincronización al recuperar la conexión.
class ApiSync {
  ApiSync({this.enLinea = true});
  bool enLinea;
  final empujes = <Map<String, dynamic>>[];
  Future<http.Response> call(http.Request req) async {
    if (!enLinea) throw http.ClientException('sin red');
    final p = req.url.path;
    if (p == '/v1/sync/push') {
      final b = jsonDecode(req.body) as Map<String, dynamic>;
      empujes.add(b);
      return http.Response(
          jsonEncode({
            'accepted': {'attempts': (b['attempts'] as List).length, 'sessions': (b['sessions'] as List).length, 'events': (b['events'] as List).length},
            'duplicates': {'attempts': 0, 'sessions': 0, 'events': 0},
            'serverTime': '2026-11-17T10:00:00Z'
          }),
          200);
    }
    if (p == '/v1/sync/pull') return http.Response(jsonEncode({'attempts': [], 'sessions': [], 'cursor': '0:0', 'hasMore': false}), 200);
    if (p == '/v1/inquiries') return http.Response(jsonEncode({'items': []}), 200);
    if (p == '/v1/entitlements') {
      return http.Response(jsonEncode({'premium': true, 'noAds': true, 'source': 'support_grant', 'status': 'active', 'trialUsed': true, 'validatedAt': '2026-11-17T10:00:00Z'}), 200);
    }
    return http.Response('{}', 200);
  }

  List<String> get sesionesSubidas => [for (final e in empujes) for (final s in (e['sessions'] as List)) '${(s as Map)['id']}'];
  List<String> get intentosSubidos => [for (final e in empujes) for (final a in (e['attempts'] as List)) '${(a as Map)['id']}'];
}

Entitlements premiumHoy() => Entitlements(premium: true, noAds: true, source: 'support_grant', status: 'active', validatedAt: ahoraPrueba);
