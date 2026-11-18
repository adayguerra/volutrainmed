import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';

import '../helpers/arnes.dart';

/// Ningún texto de la pantalla de cuenta se trunca con puntos suspensivos a
/// 390 px de ancho (el texto de ayuda del correo debe pasar a otra línea).
void main() {
  setUpAll(cargarContenidoDePrueba);

  const ayuda = 'Te enviaremos un código de seis cifras. Sin contraseñas.';

  for (final escala in [1.0, 1.3]) {
    testWidgets('«Guarda tu progreso» a 390 px (texto × $escala): ningún texto de ayuda queda truncado', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: Rutas.cuenta, tamano: const Size(390, 844), escalaTexto: escala);
      expect(find.text(ayuda), findsOneWidget);
      final truncados = <String>[];
      for (final r in t.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        // La etiqueta flotante del campo se mide aparte (Flutter la dibuja a
        // escala reducida) y da un falso positivo: se comprueba el resto.
        if (r.text.toPlainText() == 'Correo electrónico') continue;
        if (r.didExceedMaxLines) truncados.add(r.text.toPlainText());
      }
      expect(truncados, isEmpty, reason: 'textos truncados: $truncados');
      final texto = t.widget<Text>(find.text(ayuda));
      expect(texto.maxLines == null || texto.maxLines! > 1, isTrue, reason: 'el texto de ayuda puede ocupar varias líneas');
    });
  }
}
