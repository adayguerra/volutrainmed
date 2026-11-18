import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/app.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/app/widgets/comunes.dart';
import 'package:volutrainmed/app/widgets/teclado.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:volutrainmed/core/plataforma/archivos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/profile/ui/ajustes.dart';
import 'package:volutrainmed/features/profile/ui/perfil.dart';
import 'package:volutrainmed/features/profile/ui/privacidad.dart';

import '../helpers/arnes.dart';
import '../sync/sincronizador_test.dart' show intentoSintetico;

http.Response json(Object o, [int s = 200]) => http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json'});

/// Arnés con el guardador de archivos de prueba.
class ArnesArchivos extends Arnes {
  ArnesArchivos({super.usuario, super.http});
  final guardador = GuardadorArchivosFalso();
  @override
  List<Override> get overrides => [...super.overrides, guardadorArchivosProvider.overrideWithValue(guardador)];
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  Future<void> mostrar(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  }

  String rutaActual(Arnes a) => a.contenedor.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

  Future<void> tocar(WidgetTester t, Finder f) async {
    await mostrar(t, f);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await Arnes.asentar(t);
  }

  testWidgets('onboarding-account · Registro pospuesto: sigue con el perfil local y el perfil recuerda crear la cuenta', (t) async {
    final a = Arnes(usuario: usuarioDePrueba().copyWith(registroPospuesto: true));
    await a.montar(t, ruta: Rutas.perfil);
    expect(find.text(textoRecordatorioCuenta), findsOneWidget);
    expect(find.text('MeniscoÁgil12'), findsOneWidget, reason: 'el perfil local sigue activo');
    await tocar(t, find.text(textoRecordatorioCuenta));
    expect(rutaActual(a), Rutas.cuenta);
  });

  testWidgets('onboarding-account · Exportación de datos: confirmación de la solicitud y archivo con perfil e historial', (t) async {
    var consultas = 0;
    final a = ArnesArchivos(
      usuario: usuarioDePrueba(token: 'tok'),
      http: (r) async {
        if (r.url.path == '/v1/me/export' && r.method == 'POST') return json({'requestId': '7', 'status': 'pending'}, 202);
        if (r.url.path == '/v1/me/export/7') {
          consultas++;
          return consultas < 2
              ? json({'status': 'pending'})
              : json({
                  'status': 'ready',
                  'file': {
                    'profile': {'alias': 'MeniscoÁgil12'},
                    'attempts': [{}, {}, {}],
                    'sessions': [{}],
                    'inquiries': [],
                  },
                });
        }
        return json({'attempts': [], 'sessions': [], 'cursor': '0:0', 'hasMore': false});
      },
    );
    await a.montar(t, ruta: Rutas.privacidad);
    await t.tap(find.text('Exportar mis datos'));
    await t.pump();
    expect(find.text(textoSolicitudExportacion), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await Arnes.asentar(t);
    expect(find.text(textoArchivoListo), findsOneWidget);
    expect(find.textContaining('Perfil, 3 intentos, 1 sesiones'), findsOneWidget);
    expect(a.peticiones.where((r) => r.url.path == '/v1/me/export' && r.method == 'POST'), hasLength(1));

    // El archivo se entrega como archivo real (descarga o documentos de la app).
    await tocar(t, find.text('Guardar el archivo'));
    final g = a.guardador.guardados.single;
    expect(g.nombre, 'volutrainmed-datos-2026-11-17.json');
    expect(g.mime, 'application/json');
    final contenido = jsonDecode(g.contenido) as Map<String, dynamic>;
    expect((contenido['profile'] as Map)['alias'], 'MeniscoÁgil12');
    expect(contenido['attempts'], hasLength(3));
    expect(contenido['sessions'], hasLength(1));
    expect(find.textContaining('volutrainmed-datos-2026-11-17.json'), findsOneWidget);

    // Compartir reutiliza el archivo ya guardado.
    await tocar(t, find.text('Compartir'));
    expect(a.guardador.compartidos.single.nombre, g.nombre);
    expect(a.guardador.guardados, hasLength(1));
  });

  testWidgets('onboarding-account · Eliminación de la cuenta: confirmada por escrito, la cuenta se cierra y los datos se suprimen', (t) async {
    final borrados = <http.Request>[];
    final a = Arnes(
      usuario: usuarioDePrueba(token: 'tok'),
      intentos: [intentoSintetico(1), intentoSintetico(2)],
      http: (r) async {
        if (r.method == 'DELETE' && r.url.path == '/v1/me') {
          borrados.add(r);
          return http.Response('', 204);
        }
        return json({'attempts': [], 'sessions': [], 'cursor': '0:0', 'hasMore': false});
      },
    );
    await a.montar(t, ruta: Rutas.privacidad);
    await tocar(t, find.text('Eliminar cuenta'));
    final boton = find.widgetWithText(FilledButton, 'Eliminar la cuenta');
    expect(t.widget<FilledButton>(boton).onPressed, isNull, reason: 'hay que escribir ELIMINAR');
    await t.enterText(find.byType(TextField), 'ELIMI');
    await t.pump();
    expect(t.widget<FilledButton>(boton).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'ELIMINAR');
    await t.pump();
    await tocar(t, boton);
    expect(borrados, hasLength(1));
    expect(jsonDecode(borrados.single.body), {'confirmation': 'ELIMINAR'});
    expect(await a.aprendizaje.intentos(), isEmpty);
    final u = a.contenedor.read(usuarioProvider).value!;
    expect(u.conCuenta, isFalse);
    expect(u.perfil, isNull);
    expect(a.ubicacion.ruta, Rutas.bienvenida);
  });

  testWidgets('formative-boundary · Aviso disponible en ajustes: desde el apartado legal se lee el aviso formativo completo', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.perfil);
    await tocar(t, find.text('Legal'));
    expect(find.text(avisoFormativo), findsOneWidget);
    expect(avisoFormativo, 'VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.');
    for (final p in puntosAvisoFormativo) {
      expect(find.text(p), findsOneWidget);
    }
  });

  testWidgets('formative-boundary · Aviso sin conexión: el texto se muestra completo porque va incluido en la app', (t) async {
    final a = Arnes(conexion: false);
    await a.montar(t, ruta: Rutas.legal);
    expect(find.text(avisoFormativo), findsOneWidget);
    expect(find.text(puntosAvisoFormativo.last), findsOneWidget);
    expect(a.peticiones, isEmpty, reason: 'no hace falta la red');
  });

  testWidgets('premium-subscription · Usuario con plan anual: ve «Premium anual», la renovación y el enlace para gestionarla', (t) async {
    final a = Arnes(
      derechos: Entitlements(
        premium: true,
        noAds: true,
        source: 'store',
        plan: 'annual',
        status: 'active',
        renewsAt: DateTime(2027, 3, 1, 12),
        expiresAt: DateTime(2027, 3, 1, 12),
        trialUsed: true,
        validatedAt: ahoraPrueba,
      ),
    );
    await a.montar(t, ruta: Rutas.perfil);
    expect(find.textContaining('Premium anual'), findsOneWidget);
    expect(find.textContaining('Se renueva el 1 de marzo'), findsOneWidget);
    expect(find.textContaining('Gestionar en la tienda'), findsOneWidget);
    await tocar(t, find.textContaining('Premium anual'));
    expect(rutaActual(a), startsWith(Rutas.suscripcion));
  });

  testWidgets('adaptive-accessible-ui · Háptica desactivada: con la respuesta háptica desactivada, pulsar una tecla no vibra', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.accesibilidad);
    final interruptor = find.widgetWithText(SwitchListTile, 'Respuesta háptica');
    await mostrar(t, interruptor);
    expect(t.widget<SwitchListTile>(interruptor).value, isTrue);
    await tocar(t, interruptor);
    expect(a.contenedor.read(ajustesProvider).haptica, isFalse);

    final entrada = EntradaNumerica();
    final senales = a.contenedor.read(senalesProvider);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TecladoNumerico(entrada: entrada, senales: senales),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('tecla-4')));
    await t.pump();
    expect(entrada.texto, '4');
    expect(a.vibrador.senales, isEmpty);

    // Con la háptica activada sí hay vibración.
    await a.contenedor.read(ajustesProvider.notifier).cambiar((x) => x.copyWith(haptica: true));
    await t.tap(find.byKey(const ValueKey('tecla-8')));
    await t.pump();
    expect(a.vibrador.senales, [Senal.tecla]);
  });

  testWidgets('offline-sync · Pérdida de conexión: en Perfil aparece el distintivo y el aviso se muestra una sola vez', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.perfil);
    expect(find.text(DistintivoSinConexion.texto), findsNothing);
    a.conectividad.conectado = false;
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text(textoSinConexion), findsOneWidget);
    expect(find.text(DistintivoSinConexion.texto), findsOneWidget);
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await Arnes.asentar(t);
    expect(find.text(textoSinConexion), findsNothing, reason: 'el aviso no se repite');
    expect(find.text(DistintivoSinConexion.texto), findsOneWidget, reason: 'el distintivo sigue visible');
  });

  testWidgets('el tema oscuro se activa desde accesibilidad y apariencia', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.accesibilidad);
    await tocar(t, find.text('Oscuro'));
    expect(a.contenedor.read(ajustesProvider).tema, ThemeMode.dark);
    expect(Theme.of(t.element(find.text('Accesibilidad y apariencia').first)).brightness, Brightness.dark);
  });

  testWidgets('escuchar el ejemplo de voz usa la síntesis del dispositivo', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.voz);
    expect(find.textContaining('Reconocimiento no disponible'), findsOneWidget);
    await tocar(t, find.text('Escuchar ejemplo'));
    expect(a.sintetizador.dichos, [PantallaAjustesVoz.ejemplo]);
  });

  testWidgets('cambiar a un itinerario no descargado sin conexión lo explica y no cambia nada', (t) async {
    final a = Arnes(conexion: false);
    await a.montar(t, ruta: Rutas.itinerario);
    await tocar(t, find.text('Anestesia y reanimación'));
    expect(find.textContaining('Hace falta conexión para descargar este itinerario'), findsOneWidget);
    expect(a.contenedor.read(usuarioProvider).value!.perfil!.itineraryId, 'it-fundamentos');
  });

  for (final ruta in [Rutas.perfil, Rutas.accesibilidad, Rutas.voz, Rutas.sincronizacion, Rutas.privacidad, Rutas.legal]) {
    testWidgets('$ruta con texto al 200 % no desborda', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: ruta, escalaTexto: 2);
      sinDesbordes(t);
    });
  }
}
