import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/ads/domain/ad_selector.dart';
import 'package:volutrainmed/features/ads/domain/ad_variables.dart';

void main() {
  late GlobalPackage global;
  late SelectorAnuncios selector;
  final ahora = DateTime(2026, 11, 16, 10);

  setUpAll(() {
    final raw = File('../../contracts/sample/global.json').readAsStringSync();
    global = GlobalPackage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    selector = SelectorAnuncios(campanas: global.campaigns, params: global.adParams);
  });

  ContextoAnuncio ctx({
    ContadorImpresiones? impresiones,
    String? anterior,
    int racha = 0,
    bool limiteHf = false,
    String? sector = 'enfermeria',
    DateTime? cuando,
    bool voz = false,
    int espera = 3,
    int ejercicios = 10,
  }) =>
      ContextoAnuncio(
        ahora: cuando ?? ahora,
        impresiones: impresiones ?? ContadorImpresiones(),
        anterior: anterior,
        rachaDias: racha,
        limiteManosLibresAgotado: limiteHf,
        sectorId: sector,
        modoVoz: voz,
        esperaS: espera,
        ejerciciosLeccion: ejercicios,
      );

  test('la campaña de lanzamiento trae los doce anuncios con PA-01 de reserva', () {
    final ids = global.campaigns.expand((c) => c.creatives).map((a) => a.id).toList();
    expect(ids.length, 12);
    expect(selector.topeDiario(global.campaigns.first.creatives.firstWhere((a) => a.id == 'PA-01')), isNull);
  });

  test('[house-ads] Escenario: Sin repetición consecutiva', () {
    final rnd = Random(7);
    final imp = ContadorImpresiones();
    String? anterior;
    // Seis pausas: con los topes de la campaña siempre queda un anuncio
    // distinto del anterior (la reserva PA-01 solo se repite si no hay otro).
    for (var i = 0; i < 6; i++) {
      final a = selector.elegir(ctx(impresiones: imp, anterior: anterior), rnd)!;
      expect(a.id, isNot(anterior));
      imp.registrar(a.id, ahora);
      anterior = a.id;
    }
  });

  test('[house-ads] Escenario: Tope diario alcanzado', () {
    final imp = ContadorImpresiones();
    for (var i = 0; i < 6; i++) {
      imp.registrar('PA-03', ahora);
    }
    final ids = selector.elegibles(ctx(impresiones: imp)).map((a) => a.id);
    expect(ids, isNot(contains('PA-03')));
    // El contador se puede guardar y recuperar.
    final copia = ContadorImpresiones.fromJson(jsonDecode(jsonEncode(imp.toJson())) as Map<String, dynamic>);
    expect(copia.hoy('PA-03', ahora), 6);
    // Al día siguiente vuelve a entrar.
    final manana = ahora.add(const Duration(days: 1));
    expect(selector.elegibles(ctx(impresiones: imp, cuando: manana)).map((a) => a.id), contains('PA-03'));
  });

  test('[house-ads] Escenario: Racha de varios días', () {
    final a = selector.elegir(ctx(racha: 5), Random(1))!;
    expect(a.id, 'PA-05');
    expect(a.titular, 'Llevas 5 días seguidos');
  });

  test('[house-ads] Escenario: Límite diario de manos libres agotado', () {
    final a = selector.elegir(ctx(limiteHf: true), Random(3))!;
    expect(a.id, 'PA-04');
  });

  test('sin contexto cumplido elige entre genéricos y, si no queda ninguno, PA-01', () {
    final elegido = selector.elegir(ctx(), Random(2))!;
    expect(['PA-01', 'PA-02', 'PA-09'], contains(elegido.id));
    final lleno = ContadorImpresiones();
    for (final id in ['PA-02', 'PA-09']) {
      for (var i = 0; i < 10; i++) {
        lleno.registrar(id, ahora);
      }
    }
    expect(selector.elegir(ctx(impresiones: lleno, anterior: 'PA-01'), Random(2))!.id, 'PA-01');
  });

  test('en manos libres solo entran anuncios con cuña', () {
    final elegibles = selector.elegibles(ctx(voz: true));
    expect(elegibles.every((a) => a.voiceSpot != null), isTrue);
    expect(elegibles.map((a) => a.id), isNot(contains('PA-11')));
  });

  test('sin precios frescos no se muestran anuncios con precio', () {
    expect(selector.elegibles(ctx()).map((a) => a.id), isNot(contains('PA-06')));
    final conPrecios = ContextoAnuncio(
      ahora: ahora,
      impresiones: ContadorImpresiones(),
      precioMensual: '6.99',
      precioAnual: '39.99',
      preciosObtenidosEn: ahora.subtract(const Duration(days: 2)),
    );
    expect(selector.elegibles(conPrecios).map((a) => a.id), contains('PA-06'));
    final pa06 = global.campaigns.first.creatives.firstWhere((a) => a.id == 'PA-06');
    final r = selector.resolver(pa06, conPrecios);
    expect(r.titular, 'Premium por 3,33 € al mes');
    expect(r.texto, 'Con el plan anual pagas un 52 % menos que mes a mes.');
    final caducados = ContextoAnuncio(
      ahora: ahora,
      impresiones: ContadorImpresiones(),
      precioMensual: '6.99',
      precioAnual: '39.99',
      preciosObtenidosEn: ahora.subtract(const Duration(days: 8)),
    );
    expect(selector.elegibles(caducados).map((a) => a.id), isNot(contains('PA-06')));
  });

  test('[house-ads] Escenario: Cifras calculadas con la configuración vigente', () {
    final pa02 = global.campaigns.first.creatives.firstWhere((a) => a.id == 'PA-02');
    expect(selector.resolver(pa02, ctx(espera: 3, ejercicios: 10)).titular, '3 s × 10 ejercicios = 30 s');
    expect(selector.resolver(pa02, ctx(espera: 2, ejercicios: 8)).titular, '2 s × 8 ejercicios = 16 s');
    expect(equivalenteMes('39.99'), '3,33');
    expect(ahorroPct('6.99', '39.99'), '52');
  });

  test('[house-ads] Escenario: Espera desactivada', () {
    // Con espera 0 el anuncio que cuantifica las pausas no tiene sentido.
    expect(selector.elegibles(ctx(espera: 0)).where((a) => a.context == 'wait_gt0_in_lesson' && ctx(espera: 0).cumple(a.context)), isEmpty);
    expect(AdParams.fromJson({'waitS': 0}).waitS, 0);
    expect(AdParams.fromJson({'waitS': 9}).waitS, 5);
  });

  test('[house-ads] Escenario: Campaña por sector', () {
    final vet = AdCampaign(
      id: 'camp-vet',
      name: 'Veterinaria',
      sectorIds: const ['veterinaria'],
      creatives: const [
        AdCreative(id: 'VET-1', kind: 'contextual', context: 'always', weight: 100, dailyCap: 6, headline: 'h', body: 'b', cta: 'c', ctaAction: 'paywall', illustration: 'x'),
      ],
    );
    final s = SelectorAnuncios(campanas: [...global.campaigns, vet], params: global.adParams);
    expect(s.elegibles(ctx(sector: 'enfermeria')).map((a) => a.id), isNot(contains('VET-1')));
    expect(s.elegir(ctx(sector: 'veterinaria'), Random(1))!.id, 'VET-1');
  });

  test('[house-ads] Escenario: Campaña caducada sin conexión', () {
    final vieja = AdCampaign(
      id: 'camp-vieja',
      name: 'Caducada',
      endsAt: DateTime(2026, 10, 1),
      creatives: const [
        AdCreative(id: 'OLD-1', kind: 'contextual', context: 'always', weight: 100, dailyCap: 6, headline: 'h', body: 'b', cta: 'c', ctaAction: 'paywall', illustration: 'x'),
      ],
    );
    final s = SelectorAnuncios(campanas: [vieja, ...global.campaigns], params: global.adParams);
    final a = s.elegir(ctx(), Random(1))!;
    expect(a.id, isNot('OLD-1'));
  });

  test('trial_or_paywall usa la acción alternativa si la prueba ya se usó', () {
    final pa10 = global.campaigns.first.creatives.firstWhere((a) => a.id == 'PA-10');
    final sinPrueba = selector.resolver(pa10, ctx());
    expect(sinPrueba.accion, 'Quitar anuncios');
    final conPrueba = selector.resolver(
      pa10,
      ContextoAnuncio(ahora: ahora, impresiones: ContadorImpresiones(), pruebaDisponible: true, aciertosLeccion: 10, ejerciciosLeccion: 10),
    );
    expect(conPrueba.accion, 'Probar gratis');
    expect(conPrueba.abrePrueba, isTrue);
    expect(conPrueba.titular, '10 de 10');
  });

  group('Política de la pausa', () {
    bool mostrar({bool sinAnuncios = false, SessionMode modo = SessionMode.lesson, bool primera = false, bool entreCrono = false, int n = 4, int f = 1}) =>
        PoliticaPausa.debeMostrar(
          sinAnuncios: sinAnuncios,
          modo: modo,
          esPrimeraLeccion: primera,
          enContrarrelojEntreEjercicios: entreCrono,
          contadorEjercicios: n,
          frecuencia: f,
        );

    test('[house-ads] Escenario: Respuesta correcta en una lección (pausa tras cada ejercicio)', () {
      expect(mostrar(), isTrue);
    });

    test('[house-ads] Escenario: Usuario con Premium', () {
      expect(mostrar(sinAnuncios: true), isFalse);
    });

    test('[house-ads] Escenario: Primera lección', () {
      expect(mostrar(primera: true), isFalse);
    });

    test('[house-ads] Escenario: Contrarreloj', () {
      expect(mostrar(modo: SessionMode.timetrial, entreCrono: true), isFalse);
      expect(mostrar(modo: SessionMode.timetrial, entreCrono: false), isTrue);
    });

    test('[house-ads] Escenario: Prueba de nivel', () {
      expect(mostrar(modo: SessionMode.placement), isFalse);
    });

    test('frecuencia 2 muestra la pausa en ejercicios alternos', () {
      expect(mostrar(n: 1, f: 2), isFalse);
      expect(mostrar(n: 2, f: 2), isTrue);
    });
  });
}
