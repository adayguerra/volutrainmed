import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';

import '../helpers/arnes.dart';
import 'actualizador_contador.dart';
import 'soporte_crono.dart';

void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('el contrarreloj aplica el contenido preparado al empezar el esprint y no durante él', (t) async {
    final a = ArnesActualizador(intentos: intentosConsolidanH1(), derechos: premiumHoy());
    await a.montar(t, ruta: Rutas.contrarreloj);
    expect(a.actualizador.aplicaciones, 0, reason: 'la pantalla de selección no cambia el contenido');
    await t.ensureVisible(find.byKey(const ValueKey('empezar-H1')));
    await t.tap(find.byKey(const ValueKey('empezar-H1')));
    await asentarPoco(t);
    expect(a.actualizador.aplicaciones, 1, reason: 'se aplica antes del primer ejercicio');
    expect(crono.respondidos, 0);
    for (var i = 0; i < 3; i++) {
      a.avanzarMs(1500);
      await responderCrono(t, bien: true);
    }
    expect(crono.respondidos, 3);
    expect(a.actualizador.aplicaciones, 1, reason: 'nunca a mitad del esprint');
  });
}
