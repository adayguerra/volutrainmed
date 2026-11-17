import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/voice/data/paquete_voz.dart';
import 'package:volutrainmed/features/voice/ui/pantalla_manos_libres.dart';

import '../helpers/arnes.dart';

/// Pruebas de widget de manos libres (M40–M49).
void main() {
  late Map<String, dynamic> meta;
  late Uint8List bytes;

  setUpAll(() async {
    await cargarContenidoDePrueba();
    meta = (jsonDecode(await File('test/voice/fixtures/voice-pack.json').readAsString()) as Map).cast<String, dynamic>();
    bytes = await File('test/voice/fixtures/voice-pack.gz').readAsBytes();
  });

  Future<void> sembrarPaquete(Arnes a) async {
    await a.claves.escribir(claveBytesPaqueteVoz, base64.encode(bytes));
    await a.claves.escribirJson(claveMetaPaqueteVoz, meta);
  }

  Arnes arnes({bool conexion = true, PermisosFalsos? permisos, MotorDeVoz? voz, ManejadorHttp? http, List<SessionRecord> sesiones = const [], Ajustes? ajustes}) => Arnes(
        ajustes: ajustes,
        conexion: conexion,
        permisos: permisos ?? PermisosFalsos(microfono: EstadoPermiso.concedido),
        motorVoz: voz,
        http: http,
        sesiones: sesiones,
      );

  Future<void> empezarSesion(WidgetTester t) async {
    await t.tap(find.text('Continuar'));
    await Arnes.asentar(t);
    await t.tap(find.text('Empezar'));
    await Arnes.asentar(t);
  }

  Future<void> tocar(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await Arnes.asentar(t);
  }

  String estado(WidgetTester t) => t.widget<Text>(find.byKey(const ValueKey('estado-voz'))).data!;

  testWidgets('hands-free-voice · Toque en la pantalla: un toque en cualquier zona pausa la sesión y otro la reanuda', (t) async {
    final a = arnes();
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    await empezarSesion(t);
    expect(estado(t), 'Te escucho');
    await t.tap(find.byKey(const ValueKey('zona-pausa')));
    await Arnes.asentar(t);
    expect(estado(t), 'En pausa');
    await t.tap(find.byKey(const ValueKey('zona-pausa')));
    await Arnes.asentar(t);
    expect(estado(t), 'Te escucho');
  });

  testWidgets('hands-free-voice · Sin tráfico de voz: con conexión, una sesión manos libres no hace ninguna petición de red', (t) async {
    final voz = MotorDeVozGuionado(const [VozTexto('no lo sé'), VozTexto('siguiente'), VozTexto('no lo sé'), VozTexto('siguiente')]);
    final a = arnes(voz: voz, http: (req) async => throw StateError('petición inesperada: ${req.url}'));
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    await empezarSesion(t);
    expect(voz.escuchas, greaterThanOrEqualTo(4));
    expect(await t.runAsync(() => a.aprendizaje.intentos()), hasLength(2));
    expect(a.peticiones, isEmpty, reason: 'ni audio ni texto reconocido salen del dispositivo');
    expect(a.sintetizador.dichos, isNotEmpty, reason: 'la lectura funciona con la voz del dispositivo');
    expect(find.text(textoVozLocal), findsOneWidget);
  });

  testWidgets('hands-free-voice · Sin oír: el enunciado, lo entendido y el veredicto se leen en pantalla', (t) async {
    final voz = MotorDeVozGuionado(const [VozTexto('no lo sé')]);
    final a = arnes(voz: voz);
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    await empezarSesion(t);
    expect(t.widget<Text>(find.byKey(const ValueKey('texto-dicho'))).data, a.sintetizador.dichos.last);
    expect(a.sintetizador.dichos.last, startsWith('La respuesta es'));
    expect(estado(t), 'Respuesta');
    expect(find.byKey(const ValueKey('boton-siguiente')), findsOneWidget);
    expect(t.getSize(find.byKey(const ValueKey('boton-siguiente'))).height, greaterThanOrEqualTo(72));
  });

  testWidgets('hands-free-voice · Sin paquete y sin conexión: explica que hace falta conexión y ofrece el modo táctil', (t) async {
    final a = arnes(conexion: false);
    await a.montar(t, ruta: Rutas.manosLibres);
    expect(find.text(textoSinPaqueteSinConexion), findsOneWidget);
    expect(find.text('Usar el modo táctil'), findsOneWidget);
    expect(find.text('Descargar'), findsNothing);
    await t.tap(find.text('Usar el modo táctil'));
    await Arnes.asentar(t);
    expect(a.ubicacion.ruta, Rutas.inicio);
  });

  testWidgets('hands-free-voice · Paquete alterado: si la verificación falla lo descarta y ofrece descargarlo de nuevo', (t) async {
    var alterar = true;
    final a = arnes(http: (req) async {
      if (req.url.path == '/v1/voice/pack') return http.Response(jsonEncode(meta), 200);
      final b = Uint8List.fromList(bytes);
      if (alterar) b[20] ^= 0xFF;
      return http.Response.bytes(b, 200);
    });
    await a.montar(t, ruta: Rutas.manosLibres);
    expect(find.textContaining('KB'), findsOneWidget, reason: 'indica el tamaño antes de descargar');
    await t.tap(find.text('Descargar'));
    await Arnes.asentar(t);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await Arnes.asentar(t);
    expect(find.text(textoPaqueteAlterado), findsOneWidget);
    expect(find.text('Descargar de nuevo'), findsOneWidget);
    expect(await a.claves.leer(claveBytesPaqueteVoz), isNull, reason: 'el paquete alterado se descarta');

    alterar = false;
    await t.tap(find.text('Descargar de nuevo'));
    await Arnes.asentar(t);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await Arnes.asentar(t);
    expect(find.text('Paquete de voz'), findsOneWidget);
    expect(await a.claves.leer(claveBytesPaqueteVoz), isNotNull);
  });

  testWidgets('onboarding-account · Micrófono denegado: ofrece el modo táctil y explica cómo activar el permiso más adelante', (t) async {
    final permisos = PermisosFalsos(respuestaMicrofono: EstadoPermiso.denegado);
    final a = arnes(permisos: permisos);
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    expect(permisos.solicitudes, 0, reason: 'se pide al pulsar, con su motivo');
    expect(find.textContaining('El audio no se guarda ni sale del dispositivo'), findsWidgets);
    await tocar(t, find.text('Permitir el micrófono'));
    expect(permisos.solicitudes, 1);
    await t.scrollUntilVisible(find.text(textoMicrofonoDenegado), 120, scrollable: find.byType(Scrollable).first);
    expect(find.text(textoMicrofonoDenegado), findsOneWidget);
    expect(find.text('Usar el modo táctil'), findsOneWidget);
    await tocar(t, find.text('Abrir ajustes'));
    expect(permisos.ajustesAbiertos, 1);
    expect((await a.claves.leerJson('usuario'))!['microfonoOfrecido'], isTrue);
  });

  testWidgets('premium-subscription · Límite de manos libres en el plan gratuito: con 5 minutos usados hoy indica el límite y ofrece modo táctil y Premium', (t) async {
    final hoy = SessionRecord(
      id: 's-hf',
      deviceId: 'disp-prueba',
      mode: SessionMode.handsfree,
      startedAt: ahoraPrueba.subtract(const Duration(hours: 1)),
      endedAt: ahoraPrueba.subtract(const Duration(minutes: 55)),
      completed: true,
      practiceMs: 5 * 60000,
      inputMode: InputMode.voice,
      contentVersion: '2026.11.0',
    );
    final a = arnes(sesiones: [hoy]);
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    expect(find.text('Límite diario alcanzado'), findsOneWidget);
    expect(find.textContaining('Has usado hoy tus 5 minutos de manos libres'), findsOneWidget);
    expect(find.text('Seguir en modo táctil'), findsOneWidget);
    expect(find.text('Ver Premium'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
  });

  testWidgets('manos libres en tablet: enunciado y lista de la sesión en el panel derecho (T04)', (t) async {
    final a = arnes(voz: MotorDeVozGuionado(const [VozTexto('no lo sé'), VozTexto('siguiente')]));
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres, tamano: const Size(1194, 834));
    await empezarSesion(t);
    expect(find.text('ESTA SESIÓN'), findsOneWidget);
    expect(find.text('Enunciado'), findsOneWidget);
    expect(find.text('Incorrecto'), findsWidgets, reason: 'el ejercicio respondido con «no lo sé» aparece en la lista');
  });

  testWidgets('modo bolsillo: pantalla negra con el toque bloqueado y doble toque para despertar (M47)', (t) async {
    final a = arnes(ajustes: const Ajustes(modoBolsillo: true));
    await sembrarPaquete(a);
    await a.montar(t, ruta: Rutas.manosLibres);
    await empezarSesion(t);
    expect(find.byKey(const ValueKey('modo-bolsillo')), findsOneWidget);
    expect(find.text('Toque bloqueado · doble toque para despertar'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('modo-bolsillo')));
    await Arnes.asentar(t);
    expect(find.byKey(const ValueKey('modo-bolsillo')), findsOneWidget, reason: 'un toque no hace nada');
    await t.tap(find.byKey(const ValueKey('modo-bolsillo')));
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const ValueKey('modo-bolsillo')));
    await Arnes.asentar(t);
    expect(find.byKey(const ValueKey('modo-bolsillo')), findsNothing);
  });
}
