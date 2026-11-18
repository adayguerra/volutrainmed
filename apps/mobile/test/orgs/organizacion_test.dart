import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/domain/ad_selector.dart';
import 'package:volutrainmed/features/orgs/data/organizacion.dart';

import '../domain/progress/fabrica.dart' as f;
import '../helpers/arnes.dart';

/// Perfil › Organización: unión por código, modo nominal informado, qué ve la
/// organización, itinerario asignado, plazas y vigencia.

http.Response _json(Object o, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), status, headers: {'content-type': 'application/json; charset=utf-8'});

const datosAgregados = ['Solo datos agregados del grupo: finalización, precisión media y habilidades dominadas, sin nombres'];
const datosNominales = ['Tu alias y tu correo', 'Lecciones completadas', 'Precisión por habilidad', 'Habilidades dominadas', 'Minutos de práctica'];

Map<String, dynamic> entOrg({bool activa = true}) => {
      'premium': activa,
      'noAds': activa,
      'source': 'organization',
      'plan': activa ? 'organization' : null,
      'status': activa ? 'active' : 'expired',
      'trialUsed': false,
      'validatedAt': '2026-11-17T09:00:00Z',
      'organization': {'id': 'org1', 'name': 'Universidad de Valencia', 'nominal': false},
    };

class ApiOrg {
  ApiOrg({this.nominal = false, this.asignados = const [], this.miembro = false, this.plazas = true, this.caducada = false});
  final bool nominal;
  final List<String> asignados;
  bool miembro;
  final bool plazas;
  final bool caducada;
  final uniones = <Map<String, dynamic>>[];

  Map<String, dynamic> get _org => {'id': 'org1', 'name': 'Universidad de Valencia', 'nominal': nominal, 'visibleData': nominal ? datosNominales : datosAgregados};

  Future<http.Response> call(http.Request req) async {
    switch (req.url.path) {
      case '/v1/orgs/preview':
        return _json({'organization': _org, 'group': {'id': 'g1', 'name': 'EIR 1'}});
      case '/v1/orgs/join':
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        uniones.add(b);
        if (!plazas) return _json({'error': {'code': 'seats_exhausted', 'message': 'Sin plazas'}}, 409);
        if (nominal && b['acceptNominal'] != true) return _json({'error': {'code': 'nominal_not_accepted', 'message': 'Acepta'}}, 400);
        miembro = true;
        return _json({'membership': {'orgId': 'org1', 'name': 'Universidad de Valencia', 'groupId': 'g1', 'nominal': nominal}, 'entitlements': entOrg()});
      case '/v1/orgs/mine':
        if (!miembro) return _json({'organization': null});
        return _json({
          'organization': {'id': 'org1', 'name': 'Universidad de Valencia', 'nominal': nominal},
          'group': {'id': 'g1', 'name': 'EIR 1'},
          'visibleData': nominal ? datosNominales : datosAgregados,
          'assignedItineraries': asignados,
        });
      case '/v1/entitlements':
        if (caducada) return _json(entOrg(activa: false));
        return _json(miembro ? entOrg() : {'premium': false, 'noAds': false, 'source': 'none', 'status': 'none', 'validatedAt': '2026-11-17T09:00:00Z'});
      case '/v1/sync/pull':
        return _json({'attempts': [], 'sessions': [], 'cursor': '0:0', 'hasMore': false});
    }
    return _json({});
  }
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  Future<Arnes> abrir(WidgetTester t, ApiOrg api, {Entitlements? derechos, List<Attempt> intentos = const [], String ruta = Rutas.organizacion}) async {
    final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), http: api.call, derechos: derechos, intentos: intentos);
    await a.montar(t, ruta: ruta);
    return a;
  }

  Future<void> tocar(WidgetTester t, Key k) async {
    await t.ensureVisible(find.byKey(k));
    await t.pumpAndSettle();
    await t.tap(find.byKey(k));
    await Arnes.asentar(t);
  }

  group('organizations', () {
    testWidgets('organizations · Código de invitación: un código válido vincula a la organización y a su grupo', (t) async {
      final api = ApiOrg();
      final a = await abrir(t, api);
      await t.enterText(find.byKey(const ValueKey('campo-codigo')), 'uv-eir1');
      await tocar(t, const ValueKey('comprobar-codigo'));
      expect(find.byKey(const ValueKey('vista-previa-org')), findsOneWidget);
      expect(find.text(datosAgregados.single, findRichText: true), findsNothing);
      expect(find.text('• ${datosAgregados.single}'), findsOneWidget);
      await tocar(t, const ValueKey('unirse-org'));
      expect(api.uniones.single, {'code': 'UV-EIR1', 'acceptNominal': false});
      expect(find.text('Universidad de Valencia'), findsOneWidget);
      expect(find.text('Grupo: EIR 1'), findsOneWidget);
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isTrue, reason: 'la plaza elimina los anuncios');
    });

    testWidgets('organizations · Unión a una organización en modo nominal: muestra qué datos verá y pide aceptación antes de unirse', (t) async {
      final api = ApiOrg(nominal: true);
      await abrir(t, api);
      await t.enterText(find.byKey(const ValueKey('campo-codigo')), 'HOSP1');
      await tocar(t, const ValueKey('comprobar-codigo'));
      for (final d in datosNominales) {
        expect(find.text('• $d'), findsOneWidget);
      }
      expect(find.text('Esta organización usa el modo nominal. Verá:'), findsOneWidget);
      final boton = t.widget<FilledButton>(find.byKey(const ValueKey('unirse-org')));
      expect(boton.onPressed, isNull, reason: 'no se une sin aceptar');
      await t.tap(find.byKey(const ValueKey('unirse-org')), warnIfMissed: false);
      await t.pump();
      expect(api.uniones, isEmpty);
      await tocar(t, const ValueKey('aceptar-nominal'));
      await tocar(t, const ValueKey('unirse-org'));
      expect(api.uniones.single, {'code': 'HOSP1', 'acceptNominal': true});
    });

    testWidgets('organizations · Qué ve la organización: el apartado Organización muestra siempre qué datos suyos son visibles', (t) async {
      final api = ApiOrg(nominal: true, miembro: true);
      final a = await abrir(t, api);
      expect(find.text('Qué ve tu organización'.toUpperCase()), findsOneWidget);
      for (final d in datosNominales) {
        expect(find.descendant(of: find.byKey(const ValueKey('que-ve')), matching: find.text(d)), findsOneWidget);
      }
      // También sin conexión, con lo guardado en el dispositivo.
      final guardado = await t.runAsync(() => a.claves.leerJson(claveOrgCache));
      expect(MiOrganizacion.fromJson(guardado)!.datosVisibles, datosNominales);
    });

    testWidgets('organizations · Itinerario asignado: los miembros del grupo lo ven destacado en su app', (t) async {
      final api = ApiOrg(miembro: true, asignados: ['it-vet-pequenos']);
      final a = await abrir(t, api);
      final tarjeta = find.byKey(const ValueKey('asignado-it-vet-pequenos'));
      expect(find.descendant(of: tarjeta, matching: find.text('Anestesia y clínica de pequeños animales')), findsOneWidget);
      expect(find.descendant(of: tarjeta, matching: find.text('Asignado por tu organización')), findsOneWidget);
      a.contenedor.read(routerProvider).go(Rutas.inicio);
      await Arnes.asentar(t);
      expect(find.byKey(const ValueKey('destacado-organizacion')), findsOneWidget);
      expect(find.text('Asignado por tu organización: Anestesia y clínica de pequeños animales'), findsOneWidget);
    });

    testWidgets('organizations · Plazas agotadas: no se une y explica que la organización ya ha recibido el aviso', (t) async {
      final api = ApiOrg(plazas: false);
      final a = await abrir(t, api);
      await t.enterText(find.byKey(const ValueKey('campo-codigo')), 'LLENA');
      await tocar(t, const ValueKey('comprobar-codigo'));
      await tocar(t, const ValueKey('unirse-org'));
      expect(find.text(textoPlazasAgotadas), findsOneWidget);
      expect(a.contenedor.read(derechosEfectivosProvider).sinAnuncios, isFalse);
      expect(find.text('Salir de la organización'), findsNothing, reason: 'no queda vinculado');
    });

    testWidgets('organizations · Vigencia terminada: los miembros conservan su progreso y pasan al plan gratuito', (t) async {
      final api = ApiOrg(caducada: true);
      final intentos = [for (var i = 0; i < 5; i++) f.intento(t: f.dia(0, 9, i), skill: 'H1', plantilla: 'tpl-f-mg-ug')];
      final a = await abrir(t, api, derechos: Entitlements.fromJson(entOrg(activa: false)), intentos: intentos);
      expect(find.text(textoVigenciaTerminada), findsOneWidget);
      final ef = a.contenedor.read(derechosEfectivosProvider);
      expect(ef.premium, isFalse);
      expect(
        PoliticaPausa.debeMostrar(sinAnuncios: ef.sinAnuncios, modo: SessionMode.lesson, esPrimeraLeccion: false, enContrarrelojEntreEjercicios: true, contadorEjercicios: 1, frecuencia: 1),
        isTrue,
        reason: 'las pausas promocionales vuelven',
      );
      expect(a.contenedor.read(aprendizajeProvider).value!.intentos, hasLength(5), reason: 'conserva su progreso');
    });
  });
}
