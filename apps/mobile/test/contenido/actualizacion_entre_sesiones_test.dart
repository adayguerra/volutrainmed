import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/core/contenido/actualizador.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';

/// Actualización de contenido entre sesiones con los paquetes reales de la
/// versión 2026.11.1 publicada en `services/api` (firmados con la clave de la
/// app y guardados como datos de prueba).
void main() {
  setUpAll(cargarContenidoDePrueba);

  final manifiesto = jsonDecode(File('test/contenido/fixtures/manifest-2026.11.1.json').readAsStringSync()) as Map<String, dynamic>;
  final archivos = {
    '2026.11.1:global': File('test/contenido/fixtures/global-2026.11.1.gz').readAsBytesSync(),
    '2026.11.1:it-fundamentos': File('test/contenido/fixtures/it-fundamentos-2026.11.1.gz').readAsBytesSync(),
  };

  Future<http.Response> servidor(http.Request r) async {
    if (r.url.path == '/v1/content/manifest') {
      return http.Response.bytes(utf8.encode(jsonEncode(manifiesto)), 200, headers: {'content-type': 'application/json'});
    }
    if (r.url.path.startsWith('/v1/content/files/')) {
      final id = Uri.decodeComponent(r.url.pathSegments.last);
      final b = archivos[id];
      return b == null ? http.Response('', 404) : http.Response.bytes(b, 200);
    }
    return http.Response('', 404);
  }

  test('offline-sync · Contenido nuevo durante una lección: la lección continúa con la versión con la que empezó y la nueva se aplica en la sesión siguiente', () async {
    final a = Arnes(http: servidor);
    await a.contenedorSinInterfaz();
    await a.deps.repositorio.instalarIncluido();
    final act = a.contenedor.read(actualizadorProvider);

    final c0 = a.contenedor.read(contenidoProvider).value!;
    expect(c0.version, '2026.11.0');
    var ms = 0;
    final intentos = <Attempt>[];
    MotorSesion leccion(ContenidoCargado c) => MotorSesion(
          contenido: c,
          modo: SessionMode.lesson,
          deviceId: 'disp-prueba',
          relojMs: () => ms,
          ahora: () => ahoraPrueba,
          leccion: c.fundamentos!.lessons.firstWhere((l) => l.id == 'u-f-1-l3'),
          azar: Random(2),
          alRegistrar: intentos.add,
        )..preparar();

    // Empieza la lección con 2026.11.0.
    final m = leccion(c0);
    responderBien(m);
    m.continuar();

    // A mitad de la lección termina de descargarse la versión 2026.11.1.
    await act.comprobar();
    final preparados = await a.almacenContenido.paquetes(status: 'staged');
    expect({for (final p in preparados) p.clave: p.version}, {'global': '2026.11.1', 'it-fundamentos': '2026.11.1'});
    expect(act.estado.value.preparada, '2026.11.1');
    expect(a.contenedor.read(contenidoProvider).value!.version, '2026.11.0', reason: 'no se aplica durante la sesión');

    // La lección sigue con la versión con la que empezó.
    ms += 5000;
    responderBien(m);
    expect(intentos.map((i) => i.contentVersion).toSet(), {'2026.11.0'});
    expect(m.contenido, same(c0));

    // Al empezar la sesión siguiente se aplica la nueva (como hace PantallaSesion).
    expect(await act.aplicarPreparadas(), isTrue);
    final c1 = a.contenedor.read(contenidoProvider).value!;
    expect(c1.version, '2026.11.1');
    expect(c1.fundamentos!.contentVersion, '2026.11.1');
    final siguiente = leccion(c1);
    responderBien(siguiente);
    expect(intentos.last.contentVersion, '2026.11.1');
    expect((await a.almacenContenido.paquetes(status: 'previous')).map((p) => p.version).toSet(), {'2026.11.0'});
  });

  test('la comprobación al arrancar detecta la versión publicada 2026.11.1 y la deja preparada', () async {
    final a = Arnes(http: servidor);
    await a.contenedorSinInterfaz();
    await a.deps.repositorio.instalarIncluido();
    await a.contenedor.read(actualizadorProvider).comprobar();
    expect(a.peticiones.first.url.path, '/v1/content/manifest');
    expect(a.peticiones.where((r) => r.url.path.startsWith('/v1/content/files/')), hasLength(2));
    expect(a.contenedor.read(actualizadorProvider).estado.value.preparada, '2026.11.1');
  });
}
