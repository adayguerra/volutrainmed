import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

/// Ayudas para responder en las pruebas del motor de sesión.

/// Responde bien el ejercicio actual, sea del tipo que sea.
ResultadoEjercicio responderBien(MotorSesion m) {
  final e = m.actual!;
  final v = e.variante;
  switch (e.bloque) {
    case 'numeric_unit':
      return m.responderNumerico(formatEs(v.answer!.value), unidad: v.answer!.unit);
    case 'single_choice' || 'range_choice':
      return m.responderOpcion(v.options!.firstWhere((o) => o.correct).id);
    case 'ordering':
      return m.responderOrden(v.validOrders!.first);
    case 'conversion_series':
      return m.responderSerie([for (final s in v.series!) formatEs(s.answer.value)]);
  }
  throw StateError('Bloque desconocido ${e.bloque}');
}

/// Responde mal el ejercicio actual (sin coincidir con un error previsible
/// cuando [critico] es false).
ResultadoEjercicio responderMal(MotorSesion m, {bool critico = false}) {
  final e = m.actual!;
  final v = e.variante;
  switch (e.bloque) {
    case 'numeric_unit':
      final buena = dec(v.answer!.value);
      // Un 10 % más: incorrecta y lejos del factor cinco. Con [critico], × 10.
      final mala = critico ? buena * dec('10') : buena * dec('1.1') + dec('0.07');
      return m.responderNumerico(formatEs(canon(mala)), unidad: v.answer!.unit);
    case 'single_choice' || 'range_choice':
      final mala = v.options!.firstWhere((o) => !o.correct && (!critico || o.errorCode == 'E2'), orElse: () => v.options!.firstWhere((o) => !o.correct));
      return m.responderOpcion(mala.id);
    case 'ordering':
      return m.responderOrden(v.validOrders!.first.reversed.toList());
    case 'conversion_series':
      return m.responderSerie(List.filled(v.series!.length, '1'));
  }
  throw StateError('Bloque desconocido ${e.bloque}');
}
