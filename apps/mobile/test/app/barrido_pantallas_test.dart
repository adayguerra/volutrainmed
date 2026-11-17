import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/tema.dart';

import '../helpers/arnes.dart';

/// Barrido de todas las pantallas principales en las combinaciones de
/// accesibilidad y tamaño: móvil con texto al 200 % y tema oscuro, y tablet
/// en horizontal. Un desbordamiento de dibujo hace fallar la prueba.
void main() {
  setUpAll(cargarContenidoDePrueba);

  const rutas = [
    Rutas.inicio,
    '/inicio/unidad/u-f-2',
    Rutas.practicar,
    Rutas.repaso,
    Rutas.progreso,
    '/progreso/habilidad/H1',
    Rutas.ligas,
    Rutas.perfil,
    Rutas.voz,
    Rutas.accesibilidad,
    Rutas.sincronizacion,
    Rutas.privacidad,
    Rutas.legal,
    Rutas.meta,
    Rutas.itinerario,
    Rutas.organizacion,
    Rutas.consulta,
    Rutas.consultas,
    Rutas.suscripcion,
    Rutas.contrarreloj,
    Rutas.manosLibres,
  ];

  const rutasAlta = [Rutas.bienvenida, Rutas.altaSector, Rutas.altaNivel, Rutas.altaMeta, Rutas.altaAviso, Rutas.cuenta];

  for (final ruta in rutas) {
    testWidgets('móvil, texto al 200 % y tema oscuro sin desbordes: $ruta', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: ruta, escalaTexto: 2.0, brillo: Brightness.dark);
      expect(Theme.of(t.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
      expect(t.takeException(), isNull);
    });

    testWidgets('tablet en horizontal sin desbordes: $ruta', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: ruta, tamano: const Size(1194, 834));
      expect(find.byType(NavigationRail).evaluate().isNotEmpty || !ruta.startsWith('/inicio'), isTrue);
      expect(t.takeException(), isNull);
    });
  }

  // Únicos campos de texto libre de la app: ninguno sirve para calcular.
  const conCamposDeTexto = {Rutas.consulta, Rutas.organizacion, Rutas.ligas, Rutas.privacidad, Rutas.cuenta};

  testWidgets('formative-boundary · No existe entrada libre de datos: ninguna pantalla acepta peso, fármaco o dosis libres para devolver un resultado', (t) async {
    for (final ruta in [...rutas, Rutas.leccion('u-f-1-l3')]) {
      final a = Arnes();
      await a.montar(t, ruta: ruta);
      final campos = find.byType(TextField).evaluate().map((e) => e.widget as TextField).toList();
      if (!conCamposDeTexto.contains(ruta)) {
        expect(campos, isEmpty, reason: 'campo de texto inesperado en $ruta');
      }
      for (final c in campos) {
        final etiqueta = '${c.decoration?.labelText ?? ''} ${c.decoration?.hintText ?? ''}'.toLowerCase();
        expect(etiqueta, isNot(matches(RegExp(r'peso|kg|fármaco|farmaco|dosis|mg|ml'))), reason: 'campo de datos clínicos en $ruta');
      }
      await t.pumpWidget(const SizedBox());
    }
  });

  for (final ruta in rutasAlta) {
    testWidgets('alta con texto al 200 % sin desbordes: $ruta', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(alta: false));
      await a.montar(t, ruta: ruta, escalaTexto: 2.0);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('el tema oscuro aplica los colores oscuros de los tokens', (t) async {
    final a = Arnes();
    await a.montar(t, brillo: Brightness.dark);
    final tema = Theme.of(t.element(find.byType(Scaffold).first));
    expect(tema.extension<VtmColores>()!.lienzo, VtmColores.oscuro.lienzo);
  });
}
