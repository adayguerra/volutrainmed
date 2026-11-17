import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/core/contenido/actualizador.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/data/almacenes.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/review/domain/review_projection.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';

/// Pruebas del actualizador de contenido con paquetes firmados reales
/// (`contracts/sample`, firmados con la clave de la app).
void main() {
  setUpAll(cargarContenidoDePrueba);

  final manifiestoMuestra = jsonDecode(File('../../contracts/sample/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  final bytesAnestesia = File('../../contracts/sample/it-anestesia.json.gz').readAsBytesSync();
  Map<String, dynamic> paquete(String id) => (manifiestoMuestra['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['id'] == id);

  Map<String, dynamic> archivo(Map<String, dynamic> f, {String? itinerario, String? version, String? minApp}) => {
        'id': f['id'],
        'version': version ?? f['version'],
        'url': '/v1/content/files/${f['id']}',
        'sha256': f['sha256'],
        'signature': f['signature'],
        'size': f['size'],
        'minAppVersion': minApp ?? f['minAppVersion'],
        'itineraryId': ?itinerario,
      };

  http.Response json(Object o) => http.Response(jsonEncode(o), 200, headers: {'content-type': 'application/json'});

  Map<String, dynamic> manifiesto({List<Map<String, dynamic>>? paquetes, Map<String, dynamic>? global, Map<String, dynamic>? revocaciones, String? appNueva}) => {
        'contentVersion': '2026.11.0',
        'releaseId': 'r1',
        'rolloutBucket': 3,
        'publicKeyId': 'vtm-content-2026-1',
        'global': global ?? archivo((manifiestoMuestra['global'] as Map).cast()),
        'packages': paquetes ?? [archivo(paquete('it-anestesia'), itinerario: 'it-anestesia')],
        'revocations': revocaciones ?? {'version': 0, 'templateIds': [], 'questionIds': [], 'variantIds': []},
        'newerRequiresAppVersion': appNueva,
      };

  /// Responde con los bytes del archivo respetando la cabecera Range.
  http.Response servir(http.Request r, Uint8List bytes) {
    final rango = r.headers['range'];
    if (rango == null) return http.Response.bytes(bytes, 200);
    final desde = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(rango)!.group(1)!);
    if (desde >= bytes.length) return http.Response('', 416, headers: {'content-range': 'bytes */${bytes.length}'});
    return http.Response.bytes(bytes.sublist(desde), 206, headers: {'content-range': 'bytes $desde-${bytes.length - 1}/${bytes.length}'});
  }

  Future<Arnes> preparar(Future<http.Response> Function(http.Request) manejador) async {
    final a = Arnes(http: manejador);
    await a.contenedorSinInterfaz();
    await a.deps.repositorio.instalarIncluido();
    return a;
  }

  List<http.Request> archivos(Arnes a) => a.peticiones.where((r) => r.url.path.startsWith('/v1/content/files/')).toList();

  test('offline-sync · Paquete válido: el contenido queda disponible sin conexión', () async {
    final a = await preparar((r) async => r.url.path.endsWith('/manifest') ? json(manifiesto()) : servir(r, bytesAnestesia));
    final act = a.contenedor.read(actualizadorProvider);
    await act.descargarItinerario('it-anestesia');
    expect((await a.almacenContenido.paquetes(status: 'staged')).single.clave, 'it-anestesia');
    expect(await act.aplicarPreparadas(), isTrue);
    expect(a.contenedor.read(contenidoProvider).value!.itinerario('it-anestesia'), isNotNull);

    // Sin conexión, el contenido se carga del dispositivo.
    a.manejador = sinRed;
    final sinRedCargado = await a.deps.repositorio.cargar();
    expect(sinRedCargado.itinerario('it-anestesia')!.units, isNotEmpty);
    expect(await act.itinerariosInstalados(), containsAll(['it-fundamentos', 'it-anestesia']));
  });

  test('offline-sync · Paquete no válido: se descarta, se conserva la versión anterior y se reintenta la descarga', () async {
    var n = 0;
    final a = await preparar((r) async {
      if (r.url.path.endsWith('/manifest')) return json(manifiesto());
      n++;
      final b = Uint8List.fromList(bytesAnestesia);
      if (n == 1) b[200] ^= 0xFF; // primera descarga alterada
      return servir(r, b);
    });
    final act = a.contenedor.read(actualizadorProvider);
    await act.descargarItinerario('it-anestesia');
    final descargas = archivos(a);
    expect(descargas, hasLength(2), reason: 'reintenta tras descartar la alterada');
    expect(descargas[1].headers['range'], isNull, reason: 'los bytes alterados se descartan y se empieza de cero');
    expect((await a.almacenContenido.paquetes(status: 'staged')).single.version, '2026.11.0');

    // Una versión global nueva cuya firma no cuadra: se rechaza y sigue la anterior.
    final g = (manifiestoMuestra['global'] as Map).cast<String, dynamic>();
    final bytesGlobal = await leerActivoDisco('assets/content/global.vtmpkg');
    a.manejador = (r) async => r.url.path.endsWith('/manifest') ? json(manifiesto(global: archivo(g, version: '2026.11.5'), paquetes: const [])) : servir(r, bytesGlobal);
    await act.comprobar();
    expect(act.estado.value.error, contains('no es válido'));
    final globales = (await a.almacenContenido.paquetes()).where((p) => p.clave == 'global').toList();
    expect(globales.where((p) => p.status == 'active').single.version, '2026.11.0');
    expect(globales.where((p) => p.status == 'staged'), isEmpty);
    expect(await a.almacenContenido.descarga('global', '2026.11.5'), isNull, reason: 'no quedan bytes descartados');
  });

  test('offline-sync · Descarga interrumpida: se reanuda desde el punto alcanzado', () async {
    var n = 0;
    final a = await preparar((r) async {
      if (r.url.path.endsWith('/manifest')) return json(manifiesto());
      n++;
      if (n == 1) {
        // Llega solo una parte y la conexión se corta.
        return http.Response.bytes(bytesAnestesia.sublist(0, 10000), 206, headers: {'content-range': 'bytes 0-9999/${bytesAnestesia.length}'});
      }
      if (n == 2) throw http.ClientException('conexión perdida');
      return servir(r, bytesAnestesia);
    });
    final act = a.contenedor.read(actualizadorProvider);
    await expectLater(act.descargarItinerario('it-anestesia'), throwsA(isA<DescargaFallida>()));
    final parcial = await a.almacenContenido.descarga('it-anestesia', '2026.11.0');
    expect(parcial!.partial.length, 10000);
    expect(parcial.failures, 1);

    await act.descargarItinerario('it-anestesia');
    expect(archivos(a).last.headers['range'], 'bytes=10000-');
    expect((await a.almacenContenido.paquetes(status: 'staged')).single.clave, 'it-anestesia');
    expect(await a.almacenContenido.descarga('it-anestesia', '2026.11.0'), isNull);
  });

  test('una descarga parcial ya completa se verifica sin volver a bajarla', () async {
    final a = await preparar((r) async => r.url.path.endsWith('/manifest') ? json(manifiesto()) : servir(r, bytesAnestesia));
    final f = paquete('it-anestesia');
    await a.almacenContenido.guardarDescarga(DescargaParcial(
      clave: 'it-anestesia',
      fileId: 'it-anestesia',
      version: '2026.11.0',
      url: '/v1/content/files/it-anestesia',
      sha256: '${f['sha256']}',
      signature: '${f['signature']}',
      size: 0,
      minAppVersion: '1.0.0',
      partial: Uint8List.fromList(bytesAnestesia),
      failures: 1,
    ));
    await a.contenedor.read(actualizadorProvider).descargarItinerario('it-anestesia');
    expect(archivos(a), isEmpty, reason: 'ya estaban todos los bytes: solo se verifica');
    expect((await a.almacenContenido.paquetes(status: 'staged')).single.clave, 'it-anestesia');
  });

  test('offline-sync · Contenido que exige una app más reciente: se conserva el compatible y se avisa', () async {
    final f = paquete('it-fundamentos');
    final a = await preparar((r) async => json(manifiesto(
          paquetes: [archivo(f, itinerario: 'it-fundamentos', version: '2026.12.0', minApp: '9.0.0')],
          appNueva: '9.0.0',
        )));
    final act = a.contenedor.read(actualizadorProvider);
    await act.comprobar();
    expect(act.estado.value.avisoAppAntigua, textoActualizaApp);
    expect(archivos(a), isEmpty, reason: 'no se descarga lo incompatible');
    final activos = await a.almacenContenido.paquetes(status: 'active');
    expect(activos.firstWhere((p) => p.clave == 'it-fundamentos').version, '2026.11.0');
    await a.contenedor.read(contenidoProvider.notifier).recargar();
    final c = a.contenedor.read(contenidoProvider).value!;
    expect(c.avisoAppAntigua, 'Actualiza la app para ver el contenido nuevo');
    expect(c.fundamentos!.contentVersion, '2026.11.0');
  });

  test('offline-sync · Ejercicio retirado: la plantilla deja de aparecer en lecciones y en repasos', () async {
    final a = await preparar((r) async => json(manifiesto(
          paquetes: const [],
          revocaciones: {'version': 1, 'templateIds': ['tpl-f-mg-ug'], 'questionIds': [], 'variantIds': []},
        )));
    await a.contenedor.read(actualizadorProvider).comprobar();
    final c = a.contenedor.read(contenidoProvider).value!;
    expect(c.revocaciones.templateIds, {'tpl-f-mg-ug'});
    expect(c.variantes('tpl-f-mg-ug', 1), isEmpty);

    // Lección: ningún ejercicio de la plantilla retirada.
    final presentados = <String?>[];
    final m = MotorSesion(
      contenido: c,
      modo: SessionMode.lesson,
      deviceId: 'd',
      relojMs: () => 0,
      ahora: () => ahoraPrueba,
      leccion: c.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l1'),
      azar: Random(2),
    )..preparar();
    while (m.fase != FaseSesion.terminada) {
      presentados.add(m.actual!.variante.templateId);
      responderBien(m);
      m.continuar();
    }
    expect(presentados, isNotEmpty);
    expect(presentados, isNot(contains('tpl-f-mg-ug')));

    // Repaso: la ficha de la plantilla retirada no se presenta.
    final v = contenidoPrueba.variantes('tpl-f-mg-ug', 1).first;
    final ficha = FichaRepaso(clave: v.cardKey, templateId: 'tpl-f-mg-ug', questionId: null, level: 1, skillId: 'H1', creada: ahoraPrueba);
    final r = MotorSesion(contenido: c, modo: SessionMode.review, deviceId: 'd', relojMs: () => 0, ahora: () => ahoraPrueba, fichasRepaso: [ficha])..preparar();
    expect(r.fase, FaseSesion.terminada);
    expect(r.actual, isNull);
  });

  test('actualización contra la API local (2026.11.1)', () async {
    final a = Arnes();
    await a.contenedorSinInterfaz();
    await a.deps.repositorio.instalarIncluido();
    final real = http.Client();
    a.manejador = (r) async {
      final req = http.Request(r.method, Uri.parse('http://localhost:8787${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}'))..headers.addAll(r.headers);
      return http.Response.fromStream(await real.send(req));
    };
    final act = a.contenedor.read(actualizadorProvider);
    await act.comprobar();
    expect(act.estado.value.error, isNull);
    final preparados = await a.almacenContenido.paquetes(status: 'staged');
    expect(preparados.map((p) => p.clave), containsAll(['global', 'it-fundamentos']));
    expect(preparados.every((p) => compararVersionesPrueba(p.version, '2026.11.0') > 0), isTrue);
    await act.aplicarPreparadas();
    final c = a.contenedor.read(contenidoProvider).value!;
    expect(c.version, preparados.firstWhere((p) => p.clave == 'global').version);
    real.close();
  }, skip: Platform.environment['VTM_API_LIVE'] == '1' ? false : 'Requiere VTM_API_LIVE=1 y la API en marcha');
}

int compararVersionesPrueba(String a, String b) {
  final x = a.split('.').map(int.parse).toList();
  final y = b.split('.').map(int.parse).toList();
  for (var i = 0; i < 3; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}
