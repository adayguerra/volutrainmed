import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/adaptativo.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/tema.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/contenido/verificador.dart';
import 'package:volutrainmed/core/data/almacenes.dart';

import '../helpers/arnes.dart';

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('Armazón de la app', () {
    testWidgets('adaptive-accessible-ui · Móvil: menos de 600 dp muestra barra inferior de cinco destinos y una columna', (t) async {
      final a = Arnes();
      await a.montar(t, tamano: const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      final barra = t.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barra.destinations, hasLength(5));
      for (final d in ['Inicio', 'Practicar', 'Progreso', 'Ligas', 'Perfil']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(d)), findsOneWidget);
      }
      expect(barra.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow);
    });

    testWidgets('adaptive-accessible-ui · Tablet en horizontal: 840 dp o más usa carril lateral', (t) async {
      final a = Arnes();
      await a.montar(t, tamano: const Size(1194, 834));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(ClaseAncho.deAncho(1194), ClaseAncho.expandida);
      expect(ClaseAncho.deAncho(700), ClaseAncho.media);
      expect(ClaseAncho.deAncho(599), ClaseAncho.compacta);
    });

    testWidgets('sin alta completada la app abre la bienvenida', (t) async {
      final a = Arnes(usuario: usuarioDePrueba(alta: false));
      await a.montar(t, ruta: Rutas.inicio);
      expect(a.ubicacion.ruta, Rutas.bienvenida);
    });
  });

  group('Tema y contraste', () {
    for (final (nombre, c) in [('claro', VtmColores.claro), ('oscuro', VtmColores.oscuro)]) {
      test('todos los pares de texto del tema $nombre superan 4,5:1', () {
        for (final e in c.paresDeTexto.entries) {
          expect(contraste(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5), reason: '${e.key} en el tema $nombre');
        }
      });
    }

    test('adaptive-accessible-ui · Tema oscuro: todos los textos mantienen un contraste de 4,5:1', () {
      final tema = construirTema(Brightness.dark);
      final c = tema.extension<VtmColores>()!;
      expect(tema.brightness, Brightness.dark);
      expect(contraste(tema.colorScheme.onSurface, tema.colorScheme.surface), greaterThanOrEqualTo(4.5));
      expect(contraste(tema.colorScheme.onPrimary, tema.colorScheme.primary), greaterThanOrEqualTo(4.5));
      expect(contraste(tema.colorScheme.onSurfaceVariant, tema.colorScheme.surface), greaterThanOrEqualTo(4.5));
      expect(contraste(tema.colorScheme.onError, tema.colorScheme.error), greaterThanOrEqualTo(4.5));
      for (final e in c.paresDeTexto.entries) {
        expect(contraste(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5), reason: e.key);
      }
    });

    test('el tema claro usa el primario de Stitch y las fuentes del sistema de diseño', () {
      final tema = construirTema(Brightness.light);
      expect(tema.colorScheme.primary, const Color(0xFF0D5C75));
      expect(tema.textTheme.headlineSmall!.fontFamily, Fuentes.titulos);
      expect(tema.textTheme.bodyMedium!.fontFamily, Fuentes.cuerpo);
      expect(contraste(tema.colorScheme.onPrimary, tema.colorScheme.primary), greaterThanOrEqualTo(4.5));
    });
  });

  group('Contenido incluido', () {
    test('el contenido incluido se verifica y carga sin conexión', () async {
      final c = await cargarContenidoDePrueba();
      expect(c.version, '2026.11.0');
      expect(c.fundamentos!.units, hasLength(5));
      expect(c.global.sectors.map((s) => s.name), contains('Veterinaria'));
      expect(c.variantes('tpl-f-mg-ug', 1), isNotEmpty);
    });

    test('un paquete alterado no supera la verificación', () async {
      final bytes = await leerActivoDisco('assets/content/it-fundamentos.vtmpkg');
      final alterado = Uint8List.fromList(bytes)..[100] ^= 0xFF;
      const sha = '95c39fb0dca743609f68435e37b1210b2bf5ca302b1c15556156f3d8ca2a5774';
      const firma = 'ZkTNzGqj0yYXy8IbaDcLEB7PIpZKi+euvVVfAwLPfsFUIMqqBOX3h6UQjxL+ncCAvc10tTxlh/KkpKy3nBpyDw==';
      await verificarPaquete(id: 'it-fundamentos', version: '2026.11.0', sha256: sha, firmaB64: firma, bytes: bytes);
      await expectLater(
        verificarPaquete(id: 'it-fundamentos', version: '2026.11.0', sha256: sha, firmaB64: firma, bytes: alterado),
        throwsA(isA<PaqueteNoValido>().having((e) => e.motivo, 'motivo', MotivoRechazo.resumen)),
      );
      // Mismo resumen pero otra versión en la cadena firmada: la firma falla.
      await expectLater(
        verificarPaquete(id: 'it-fundamentos', version: '2026.11.9', sha256: sha, firmaB64: firma, bytes: bytes),
        throwsA(isA<PaqueteNoValido>().having((e) => e.motivo, 'motivo', MotivoRechazo.firma)),
      );
    });

    test('si el paquete activo está dañado se usa la versión anterior', () async {
      final almacen = AlmacenContenidoMemoria();
      final repo = RepositorioContenido(almacen: almacen, claves: AlmacenClavesMemoria(), leerActivo: leerActivoDisco);
      await repo.instalarIncluido();
      final bueno = (await almacen.paquetes(status: 'active')).firstWhere((p) => p.clave == 'it-fundamentos');
      final danado = Uint8List.fromList(bueno.gz)..[50] ^= 1;
      await almacen.instalarActivo(PaqueteGuardado(
        clave: 'it-fundamentos',
        id: '2026.11.1:it-fundamentos',
        version: '2026.11.1',
        sha256: bueno.sha256,
        signature: bueno.signature,
        minAppVersion: '1.0.0',
        gz: danado,
        status: 'active',
      ));
      final c = await repo.cargar();
      expect(c.fundamentos!.contentVersion, '2026.11.0');
    });
  });
}
