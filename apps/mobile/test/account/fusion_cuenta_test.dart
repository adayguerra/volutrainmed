import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/core/sync/sincronizador.dart';
import 'package:volutrainmed/features/account/servicio_cuenta.dart';

import '../helpers/arnes.dart';
import '../sync/servidor_falso.dart';
import '../sync/sincronizador_test.dart' show hacerLeccion;

/// Fusión del perfil local al crear la cuenta, de extremo a extremo con el
/// sincronizador real y un servidor en memoria que sigue el contrato.
void main() {
  setUpAll(cargarContenidoDePrueba);

  test('onboarding-account · Fusión al registrarse: las tres lecciones del perfil local aparecen en la cuenta y en otro dispositivo', () async {
    final servidor = ServidorFalso();
    Map<String, dynamic>? perfilEnviado;
    Future<http.Response> api(http.Request r) async {
      if (r.url.path == '/v1/auth/otp/verify') {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        perfilEnviado = (b['localProfile'] as Map?)?.cast<String, dynamic>();
        return ServidorFalso.json({
          'token': 'tok-cuenta',
          'user': {
            'id': 'u-1',
            'email': 'lucia@example.com',
            'alias': perfilEnviado?['alias'] ?? 'MeniscoÁgil12',
            'sectorId': perfilEnviado?['sectorId'],
            'itineraryId': perfilEnviado?['itineraryId'],
            'declaredLevel': perfilEnviado?['declaredLevel'],
            'goal': perfilEnviado?['goal'],
            'disclaimerAcceptedAt': perfilEnviado?['disclaimerAcceptedAt'],
            'leaguesOptIn': true,
            'createdAt': '2026-11-14T10:00:00Z',
          },
          'isNew': true,
          'merged': true,
        });
      }
      if (r.url.path == '/v1/orgs/domain-offer') return ServidorFalso.json({'organization': null});
      return servidor.manejar(r);
    }

    // Móvil con perfil local y tres lecciones completadas, sin cuenta.
    final movil = Arnes(http: api);
    final c = contenidoPrueba;
    for (final (i, l) in ['u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3'].indexed) {
      await hacerLeccion(movil.aprendizaje, c, l, 'disp-prueba', ahoraPrueba.subtract(Duration(days: 3 - i)));
    }
    await movil.contenedorSinInterfaz();
    expect(movil.contenedor.read(proyeccionProvider)!.lecciones.keys, containsAll(['u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3']));
    expect(servidor.sesiones, isEmpty, reason: 'sin cuenta no se sube nada');

    // Crea la cuenta con el código de un solo uso.
    await movil.contenedor.read(servicioCuentaProvider).verificarCodigo('lucia@example.com', '123456');
    expect(perfilEnviado!['sectorId'], 'enfermeria', reason: 'el perfil local se envía para fusionarlo');
    expect(movil.contenedor.read(usuarioProvider).value!.conCuenta, isTrue);
    expect(servidor.sesiones.values.map((s) => s['lessonId']).toSet(), {'u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3'}, reason: 'las tres lecciones aparecen en la cuenta');
    expect(await movil.aprendizaje.contarPendientes(), 0);

    // Inicia sesión en la tablet: recupera las tres lecciones.
    final tablet = Arnes(http: servidor.manejar, usuario: usuarioDePrueba(token: 'tok-cuenta').copyWith());
    await tablet.contenedorSinInterfaz();
    expect(tablet.contenedor.read(proyeccionProvider)!.lecciones, isEmpty);
    await tablet.contenedor.read(sincronizadorProvider).recuperarHistorial();
    final enTablet = tablet.contenedor.read(proyeccionProvider)!.lecciones;
    expect(enTablet.keys, containsAll(['u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3']));
    expect(enTablet.values.every((l) => l.completada), isTrue);
  });
}
