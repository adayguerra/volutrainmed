import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/leagues/data/repositorio_liga.dart';
import 'package:volutrainmed/features/leagues/domain/league.dart';
import 'package:volutrainmed/features/leagues/ui/pantalla_ligas.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';
import '../timetrial/soporte_crono.dart' show ApiSync;

/// Pestaña Ligas: liga semanal por alias y logros evaluados en el dispositivo.

Map<String, dynamic> ligaServidor({bool participa = true}) => participa
    ? {
        'participating': true,
        'week': '2026-11-16',
        'endsAt': '2026-11-23T00:00:00.000Z',
        'division': 'Oro',
        'divisionIndex': 2,
        'standings': [
          for (var i = 1; i <= 14; i++) {'position': i, 'alias': i == 6 ? 'MeniscoÁgil12' : 'Alias$i', 'points': 600 - i * 20, 'me': i == 6},
        ],
        'zones': {'promote': 7, 'relegate': 5},
        'dailyCap': 300,
        'computedAt': '2026-11-17T09:00:00.000Z',
      }
    : {'participating': false, 'week': '2026-11-16'};

http.Response _json(Object o, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(o)), status, headers: {'content-type': 'application/json; charset=utf-8'});

class ApiLiga {
  ApiLiga({this.enLinea = true});
  bool enLinea;
  bool participa = true;
  final participaciones = <Map<String, dynamic>>[];
  Map<String, dynamic>? privadas;
  Future<http.Response> call(http.Request req) async {
    if (!enLinea) throw http.ClientException('sin red');
    switch (req.url.path) {
      case '/v1/leagues/current':
        return _json((ligaServidor(participa: participa)), 200);
      case '/v1/leagues/private':
        return _json((privadas ?? {'leagues': []}), 200);
      case '/v1/leagues/participation':
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        participaciones.add(b);
        participa = b['participate'] == true;
        return _json(({'participating': participa}), 200);
      case '/v1/sync/pull':
        return _json(({'attempts': [], 'sessions': [], 'cursor': '0:0', 'hasMore': false}), 200);
    }
    return http.Response('{}', 200);
  }
}

Attempt aciertoHoy(int i) => f.intento(t: ahoraPrueba.subtract(Duration(minutes: 60 - i)), skill: 'H1', plantilla: 'tpl-f-mg-ug', puntos: 10, id: 'pend-$i');

/// Contenido con un logro más publicado desde el back office.
ContenidoCargado conLogro(ContenidoCargado c, Achievement extra) {
  final g = c.global;
  final g2 = GlobalPackage(
    contentVersion: '2026.11.2',
    minAppVersion: g.minAppVersion,
    sectors: g.sectors,
    itineraries: g.itineraries,
    skills: g.skills,
    exerciseTypes: g.exerciseTypes,
    units: g.units,
    instruments: g.instruments,
    voiceLexicon: g.voiceLexicon,
    achievements: [...g.achievements, extra],
    league: g.league,
    adParams: g.adParams,
    campaigns: g.campaigns,
    freePlan: g.freePlan,
    orgsEnabled: g.orgsEnabled,
  );
  return ContenidoCargado(global: g2, itinerarios: c.itinerarios, revocaciones: c.revocaciones);
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  Future<void> abrirLogros(WidgetTester t) async {
    await t.tap(find.text('Logros'));
    await t.pumpAndSettle();
  }

  group('leagues', () {
    testWidgets('leagues · Clasificación con alias: ve alias, nunca nombres ni correos', (t) async {
      final api = ApiLiga();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: api.call);
      await a.montar(t, ruta: Rutas.ligas);
      expect(find.text('Liga Oro'), findsOneWidget);
      expect(find.text(textoReglaLiga), findsOneWidget);
      expect(find.text('Alias1'), findsOneWidget);
      expect(find.text('MeniscoÁgil12 (tú)'), findsOneWidget);
      expect(find.textContaining('@'), findsNothing);
      final h = t.ensureSemantics();
      await t.pump();
      expect(find.bySemanticsLabel('Posición 6, MeniscoÁgil12, 480 puntos, tú'), findsOneWidget);
      h.dispose();
      expect(find.text('Zona de ascenso · suben los 7 primeros'), findsOneWidget);
    });

    testWidgets('leagues · Salida de las ligas: deja de aparecer y la pestaña indica «No participas en ligas» con la opción de volver', (t) async {
      final api = ApiLiga();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: api.call);
      await a.montar(t, ruta: Rutas.ligas);
      await t.scrollUntilVisible(find.byKey(const ValueKey('dejar-ligas')), 300, scrollable: find.descendant(of: find.byType(PestanaLiga), matching: find.byType(Scrollable)).first);
      await t.ensureVisible(find.byKey(const ValueKey('dejar-ligas')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('dejar-ligas')));
      await Arnes.asentar(t);
      expect(api.participaciones.last, {'participate': false});
      expect(find.text(textoNoParticipas), findsOneWidget);
      expect(find.text('MeniscoÁgil12 (tú)'), findsNothing);
      expect(find.byKey(const ValueKey('volver-a-participar')), findsOneWidget);
      expect(a.contenedor.read(usuarioProvider).value!.perfil!.leaguesOptIn, isFalse);
      await t.tap(find.byKey(const ValueKey('volver-a-participar')));
      await Arnes.asentar(t);
      expect(api.participaciones.last, {'participate': true});
      expect(find.text('MeniscoÁgil12 (tú)'), findsOneWidget);
    });

    testWidgets('leagues · Liga sin conexión: ve «Clasificación de hace 3 h» y sus puntos pendientes de sumar', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false);
      await t.runAsync(() async {
        await a.claves.escribirJson(claveLigaCache, {...ligaServidor(), 'computedAt': ahoraPrueba.subtract(const Duration(hours: 3)).toUtc().toIso8601String()});
        for (var i = 0; i < 3; i++) {
          await a.aprendizaje.guardarIntento(aciertoHoy(i));
        }
      });
      await a.montar(t, ruta: Rutas.ligas);
      expect(find.text('Clasificación de hace 3 h'), findsOneWidget);
      expect(find.text('30 puntos pendientes de sumar'), findsOneWidget);
      expect(find.text('Alias1'), findsOneWidget, reason: 'última clasificación conocida');
    });

    testWidgets('leagues · Tope diario: con más de 300 puntos hoy la puntuación de liga no aumenta', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false);
      await t.runAsync(() async {
        await a.claves.escribirJson(claveLigaCache, {...ligaServidor(), 'computedAt': ahoraPrueba.subtract(const Duration(hours: 1)).toUtc().toIso8601String()});
        for (var i = 0; i < 35; i++) {
          await a.aprendizaje.guardarIntento(aciertoHoy(i));
        }
      });
      await a.montar(t, ruta: Rutas.ligas);
      expect(find.text('300 puntos pendientes de sumar'), findsOneWidget, reason: '35 aciertos = 350, con tope de 300');
    });

    testWidgets('sin cuenta, la pestaña explica que las ligas necesitan una cuenta y no llama a la API', (t) async {
      final a = Arnes(http: (r) async => http.Response('{}', 200));
      await a.montar(t, ruta: Rutas.ligas);
      expect(find.text(textoLigaSinCuenta), findsOneWidget);
      expect(a.peticiones.where((r) => r.url.path.startsWith('/v1/leagues')), isEmpty);
    });

    testWidgets('organizations · Liga de una promoción: los miembros que participan ven una clasificación solo con alias de su grupo', (t) async {
      final api = ApiLiga()
        ..privadas = {
          'leagues': [
            {
              'id': 'pl1',
              'name': 'Promoción EIR 2026',
              'standings': [
                {'position': 1, 'alias': 'BuretaClara20', 'points': 120, 'me': false},
                {'position': 2, 'alias': 'MeniscoÁgil12', 'points': 90, 'me': true},
              ],
            }
          ]
        };
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: api.call);
      await a.montar(t, ruta: Rutas.ligas);
      await t.scrollUntilVisible(find.byKey(const ValueKey('liga-privada-pl1')), 300, scrollable: find.descendant(of: find.byType(PestanaLiga), matching: find.byType(Scrollable)).first);
      final liga = find.byKey(const ValueKey('liga-privada-pl1'));
      expect(find.descendant(of: liga, matching: find.text('Promoción EIR 2026')), findsOneWidget);
      expect(find.descendant(of: liga, matching: find.text('BuretaClara20')), findsOneWidget);
      expect(find.descendant(of: liga, matching: find.text('MeniscoÁgil12 (tú)')), findsOneWidget);
      expect(find.descendant(of: liga, matching: find.textContaining('@')), findsNothing);
    });
  });

  group('gamification-progress', () {
    testWidgets('gamification-progress · Logro configurado en el back office: «30 días de racha» se concede sin versión nueva de la app', (t) async {
      const extra = Achievement(
        id: 'ach-streak-30',
        name: '30 días de racha',
        description: 'Treinta días seguidos con la meta cumplida',
        category: 'constancia',
        icon: 'local_fire_department',
        condition: AchievementCondition(metric: 'streak_days', op: '>=', value: 30, scope: 'global'),
      );
      final sesiones = [
        for (var d = 29; d >= 0; d--)
          f.sesion(id: 'dia-$d', inicio: DateTime(2026, 11, 17, 8).subtract(Duration(days: d)), practiceMs: 11 * 60000, lessonId: 'u-f-1-l1'),
      ];
      final a = Arnes(contenido: conLogro(contenidoPrueba, extra), sesiones: sesiones);
      await a.montar(t, ruta: Rutas.ligas);
      await abrirLogros(t);
      await t.scrollUntilVisible(find.byKey(const ValueKey('logro-ach-streak-30')), 200, scrollable: find.descendant(of: find.byType(PestanaLogros), matching: find.byType(Scrollable)).first);
      final logro = find.byKey(const ValueKey('logro-ach-streak-30'));
      expect(find.descendant(of: logro, matching: find.textContaining('Obtenido')), findsOneWidget);
      expect(a.contenedor.read(proyeccionProvider)!.logros.firstWhere((l) => l.logro.id == 'ach-streak-30').obtenido, isTrue);
    });

    testWidgets('gamification-progress · Logro obtenido sin conexión: se concede en el dispositivo y se sincroniza al recuperar la conexión', (t) async {
      final api = ApiSync(enLinea: false);
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false, http: api.call);
      await a.montar(t, ruta: Rutas.ligas);
      await abrirLogros(t);
      final antes = find.descendant(of: find.byKey(const ValueKey('logro-ach-first-handsfree')), matching: find.textContaining('Obtenido'));
      expect(antes, findsNothing);
      final s = SessionRecord(
        id: 'manos-libres-1',
        deviceId: 'disp-prueba',
        mode: SessionMode.handsfree,
        startedAt: ahoraPrueba.subtract(const Duration(minutes: 6)),
        endedAt: ahoraPrueba.subtract(const Duration(minutes: 1)),
        completed: true,
        practiceMs: 5 * 60000,
        inputMode: InputMode.voice,
        contentVersion: '2026.11.0',
      );
      await t.runAsync(() => a.contenedor.read(aprendizajeProvider.notifier).registrarSesion(s));
      await t.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('logro-ach-first-handsfree')), matching: find.textContaining('Obtenido')), findsOneWidget);
      expect(api.empujes, isEmpty);
      api.enLinea = true;
      a.conectividad.conectado = true;
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(api.sesionesSubidas, contains('manos-libres-1'));
    });
  });
}
