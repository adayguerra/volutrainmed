import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/features/inquiries/domain/consultas.dart';

import '../helpers/arnes.dart';
import '../sync/servidor_falso.dart';

void main() {
  setUpAll(cargarContenidoDePrueba);

  String rutaActual(Arnes a) => a.contenedor.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

  Future<void> mostrar(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  }

  Future<void> escribirYEnviar(WidgetTester t, String mensaje) async {
    await t.enterText(find.byType(TextField).first, mensaje);
    await t.pump();
    final enviar = find.widgetWithText(FilledButton, 'Enviar');
    await mostrar(t, enviar);
    await t.ensureVisible(enviar);
    await t.pumpAndSettle();
    await t.tap(enviar);
    await Arnes.asentar(t);
  }

  testWidgets('onboarding-account · Aviso sobre consultas clínicas: al abrir el formulario se ve «No respondemos consultas sobre pacientes ni tratamientos»', (t) async {
    final a = Arnes();
    await a.montar(t, ruta: Rutas.consulta);
    expect(find.textContaining('No respondemos consultas sobre pacientes ni tratamientos'), findsOneWidget);
    expect(textoSinConsultasClinicas, 'No respondemos consultas sobre pacientes ni tratamientos');
    await mostrar(t, find.widgetWithText(FilledButton, 'Enviar'));
    final enviar = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar'));
    expect(enviar.onPressed, isNull, reason: 'sin mensaje no se puede enviar');
  });

  testWidgets('onboarding-account · Aviso desde un ejercicio: el formulario se abre con el ejercicio, la variante y la respuesta adjuntos', (t) async {
    final s = ServidorFalso();
    final a = Arnes(http: s.manejar);
    await a.montar(t, ruta: Rutas.perfil);
    // La sesión abre el formulario al tocar «Informar de un error en este ejercicio».
    a.contenedor.read(routerProvider).push(Rutas.consulta, extra: {
      'variantId': 'tpl-f-mg-ug.v1.L1.6dib1p',
      'templateId': 'tpl-f-mg-ug',
      'questionId': null,
      'answerValue': '0.08',
      'answerUnit': 'ml/h',
    });
    await Arnes.asentar(t);
    final adjunto = t.widget<Text>(find.byKey(const ValueKey('ejercicio-adjunto'))).data!;
    expect(adjunto, contains('tpl-f-mg-ug'));
    expect(adjunto, contains('tpl-f-mg-ug.v1.L1.6dib1p'));
    expect(adjunto, contains('0,08 ml/h'));
    final chip = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Error en un ejercicio'));
    expect(chip.selected, isTrue);

    await escribirYEnviar(t, 'La explicación da la dilución en mg y el enunciado en µg.');
    final enviada = s.consultas.values.single;
    expect(enviada['type'], 'exercise_error');
    expect(enviada['exercise'], {
      'variantId': 'tpl-f-mg-ug.v1.L1.6dib1p',
      'templateId': 'tpl-f-mg-ug',
      'questionId': null,
      'answerValue': '0.08',
      'answerUnit': 'ml/h',
    });
    expect(enviada['deviceId'], 'disp-prueba');
    expect(rutaActual(a), Rutas.consultas);
    expect(find.textContaining('Consulta enviada. Referencia C-REF1'), findsOneWidget);
  });

  testWidgets('onboarding-account · Envío sin conexión: queda pendiente de envío y se envía al recuperar la conexión', (t) async {
    final s = ServidorFalso();
    final a = Arnes(conexion: false);
    await a.montar(t, ruta: Rutas.consulta);
    await escribirYEnviar(t, 'La app no me deja cambiar de itinerario.');
    expect(find.text('Pendiente de envío'), findsOneWidget);
    expect(find.textContaining('se enviará al conectar'), findsWidgets);
    final pendientes = await a.aprendizaje.pendientes(ahora: DateTime(9999), kind: 'inquiry');
    expect(pendientes, hasLength(1));
    expect(jsonDecode(pendientes.single.payload)['message'], 'La app no me deja cambiar de itinerario.');

    a.manejador = s.manejar;
    a.conectividad.conectado = true;
    await Arnes.asentar(t);
    expect(s.consultas, hasLength(1));
    expect(find.text('Recibida'), findsOneWidget);
    expect(find.text('Pendiente de envío'), findsNothing);
    expect(find.textContaining('Referencia C-REF1'), findsWidgets);
    expect(await a.aprendizaje.contarPendientes(), 0);
  });
}
