import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';
import 'package:volutrainmed/features/session/ui/pantalla_sesion.dart';

import '../helpers/arnes.dart';
import 'fixtures_sesion.dart';

/// Ayudas para manejar la pantalla de sesión desde las pruebas de widget.

MotorSesion get motor => PantallaSesion.ultimoMotor!;

/// Arnés con el contenido de prueba de la sesión y, por defecto, Premium
/// (sin pausas promocionales).
Arnes arnesSesion({
  bool premium = true,
  Entitlements? derechos,
  EstadoUsuario? usuario,
  List<Attempt> intentos = const [],
  List<SessionRecord> sesiones = const [],
  bool conexion = true,
  Ajustes? ajustes,
}) =>
    Arnes(
      contenido: contenidoSesion(contenidoPrueba),
      derechos: derechos ?? (premium ? premiumActivo(ahoraPrueba) : null),
      usuario: usuario,
      intentos: intentos,
      sesiones: sesiones,
      conexion: conexion,
      ajustes: ajustes,
    );

Future<void> teclear(WidgetTester t, String texto) async {
  for (final ch in texto.split('')) {
    await t.tap(find.byKey(ValueKey('tecla-$ch')));
    await t.pump();
  }
}

Future<void> tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await Arnes.asentar(t);
}

Future<void> comprobar(WidgetTester t) => tocar(t, find.byKey(const ValueKey('comprobar')));

/// «Continuar» tras la corrección (y cierra la pausa si aparece).
Future<void> continuar(WidgetTester t) async {
  await tocar(t, find.byKey(const ValueKey('continuar')));
}

/// Responde bien el ejercicio actual mediante la interfaz.
Future<void> responderBienUI(WidgetTester t) async {
  final e = motor.actual!;
  final v = e.variante;
  switch (e.bloque) {
    case 'numeric_unit':
      await teclear(t, formatEs(v.answer!.value));
      if (e.unidadAElegir) await tocar(t, find.byKey(ValueKey('unidad-${v.answer!.unit}')));
      await comprobar(t);
    case 'single_choice' || 'range_choice':
      await tocar(t, find.byKey(ValueKey('opcion-${v.options!.firstWhere((o) => o.correct).id}')));
      await comprobar(t);
    case 'ordering':
      for (final id in v.validOrders!.first) {
        await tocar(t, find.byKey(ValueKey('paso-$id')));
      }
      await comprobar(t);
    case 'conversion_series':
      for (final s in v.series!) {
        await teclear(t, formatEs(s.answer.value));
        await comprobar(t);
      }
  }
}

/// «No lo sé» en el ejercicio actual.
Future<void> noLoSeUI(WidgetTester t) => tocar(t, find.byKey(const ValueKey('no-lo-se')));
