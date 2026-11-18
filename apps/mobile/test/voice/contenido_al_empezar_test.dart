import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/voice/data/paquete_voz.dart';

import '../helpers/arnes.dart';
import '../timetrial/actualizador_contador.dart';

void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('manos libres aplica el contenido preparado al empezar la sesión y no durante ella', (t) async {
    final voz = MotorDeVozGuionado(const [VozTexto('no lo sé'), VozTexto('siguiente'), VozTexto('no lo sé'), VozTexto('siguiente')]);
    final a = ArnesActualizador(permisos: PermisosFalsos(microfono: EstadoPermiso.concedido), motorVoz: voz);
    await a.claves.escribir(claveBytesPaqueteVoz, base64.encode(File('test/voice/fixtures/voice-pack.gz').readAsBytesSync()));
    await a.claves.escribirJson(claveMetaPaqueteVoz, (jsonDecode(File('test/voice/fixtures/voice-pack.json').readAsStringSync()) as Map).cast<String, dynamic>());
    await a.montar(t, ruta: Rutas.manosLibres);
    await t.tap(find.text('Continuar'));
    await Arnes.asentar(t);
    expect(a.actualizador.aplicaciones, 0, reason: 'las comprobaciones previas no cambian el contenido');
    await t.tap(find.text('Empezar'));
    await Arnes.asentar(t);
    expect(a.actualizador.aplicaciones, 1, reason: 'se aplica antes del primer ejercicio');
    expect(await t.runAsync(() => a.aprendizaje.intentos()), hasLength(2), reason: 'la sesión ha avanzado dos ejercicios');
    expect(a.actualizador.aplicaciones, 1, reason: 'nunca a mitad de la sesión');
  });
}
