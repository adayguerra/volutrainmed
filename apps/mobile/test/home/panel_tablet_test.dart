import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/arnes.dart';

/// En tablet o escritorio bajo (1441 × 724), las acciones de la unidad del
/// panel derecho quedan a la vista sin desplazar el panel.
void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('Inicio a 1441 × 724: «Empezar lección», «Manos libres» y «Reto y saltar» se ven enteros en el panel derecho', (t) async {
    final a = Arnes();
    await a.montar(t, tamano: const Size(1441, 724));
    for (final clave in ['empezar-leccion', 'manos-libres-unidad', 'reto-y-saltar']) {
      final f = find.byKey(ValueKey(clave));
      expect(f, findsOneWidget, reason: clave);
      final r = t.getRect(f);
      expect(r.top, greaterThanOrEqualTo(0), reason: clave);
      expect(r.bottom, lessThanOrEqualTo(724), reason: '$clave queda cortado');
      expect(r.left, greaterThan(1441 * 0.4), reason: '$clave está en el panel derecho');
    }
    expect(t.takeException(), isNull);
  });
}
