import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/features/onboarding/domain/placement.dart';

void main() {
  late ItineraryPackage pkg;

  setUpAll(() {
    final raw = File('../../contracts/sample/it-fundamentos.json').readAsStringSync();
    pkg = ItineraryPackage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  });

  /// Responde acertando las unidades de [aciertaUnidades] y fallando el resto.
  void responderSegun(PruebaNivel p, Set<int> aciertaUnidades) {
    final ids = pkg.units.map((u) => u.id).toList();
    while (!p.terminada) {
      final u = p.unidadIdActual!;
      p.responder(correcto: aciertaUnidades.contains(ids.indexOf(u)));
    }
  }

  test('[onboarding-account] Escenario: Unidades convalidadas', () {
    final p = PruebaNivel.iniciar(pkg, 'cero');
    expect(p.varianteActual, pkg.placement.first.variantIds.first);
    responderSegun(p, {0, 1, 2});
    final r = p.resultado();
    expect(r.unidadesConvalidadas, ['u-f-1', 'u-f-2', 'u-f-3']);
    expect(r.unidadEntrada, 'u-f-4');
    expect(r.itemsRespondidos, inInclusiveRange(8, 12));
  });

  test('[onboarding-account] Escenario: Omitir la prueba', () {
    final r = PruebaNivel.omitir(pkg);
    expect(r.unidadesConvalidadas, isEmpty);
    expect(r.unidadEntrada, 'u-f-1');
    expect(r.omitida, isTrue);
  });

  test('[onboarding-account] Escenario: Prueba interrumpida', () {
    final p = PruebaNivel.iniciar(pkg, 'afianzar');
    p.responder(correcto: true);
    p.responder(correcto: true);
    p.responder(correcto: true);
    final pregunta = p.numeroPregunta;
    final variante = p.varianteActual;
    final guardado = jsonEncode(p.toJson());
    final reanudada = PruebaNivel.fromJson(jsonDecode(guardado) as Map<String, dynamic>);
    expect(reanudada.numeroPregunta, pregunta);
    expect(reanudada.varianteActual, variante);
    reanudada.responder(correcto: false);
    expect(reanudada.terminada, isFalse);
  });

  test('es adaptativa: parte del nivel declarado y baja tras un fallo', () {
    final p = PruebaNivel.iniciar(pkg, 'agilidad');
    expect(p.unidadIdActual, 'u-f-3');
    p.responder(correcto: false);
    p.responder(correcto: true);
    expect(p.unidadIdActual, 'u-f-2');
  });

  test('todo acertado convalida todas las unidades y no pasa de 12 ítems', () {
    final p = PruebaNivel.iniciar(pkg, 'cero');
    responderSegun(p, {0, 1, 2, 3, 4});
    final r = p.resultado();
    expect(r.unidadesConvalidadas.length, 5);
    expect(r.unidadEntrada, isNull);
    expect(r.itemsRespondidos, lessThanOrEqualTo(12));
    expect(p.maximo, 10);
  });

  test('«No lo sé» cuenta como fallo y no convalida la unidad', () {
    final p = PruebaNivel.iniciar(pkg, 'cero');
    p.responder(correcto: false);
    responderSegun(p, {0, 1, 2, 3, 4});
    expect(p.resultado().unidadesConvalidadas, isEmpty);
    expect(p.resultado().itemsRespondidos, greaterThanOrEqualTo(8));
  });
}
