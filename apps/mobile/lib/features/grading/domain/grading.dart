/// Corrección de respuestas (capacidad answer-grading).
///
/// Espejo exacto de `packages/engine/src/grading.ts`. El dispositivo no
/// calcula fórmulas (diseño D2): compara la respuesta con los valores
/// verificados de la variante, con aritmética racional exacta. Debe pasar los
/// mismos casos que el motor TS en `contracts/fixtures/grading.json`.
library;

import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/units.dart';

class GradeInput {
  const GradeInput(this.raw, {this.unit});
  final String raw;

  /// Unidad elegida por el usuario; se ignora si la unidad es fija.
  final String? unit;
}

class GradeResult {
  const GradeResult({
    required this.verdict,
    required this.value,
    required this.unit,
    this.note,
    this.errorCode,
    this.diagnosis,
    this.critical = false,
    this.deviationStep,
    required this.correctDisplay,
  });

  /// [Verdict.correct], [Verdict.correctNote] o [Verdict.incorrect].
  final Verdict verdict;

  /// Cifra canónica que se registra en el intento.
  final String? value;
  final String? unit;
  final String? note;
  final String? errorCode;
  final String? diagnosis;
  final bool critical;
  final int? deviationStep;
  final String correctDisplay;

  GradeResult _with({
    required Verdict verdict,
    String? note,
    String? errorCode,
    String? diagnosis,
    bool critical = false,
    int? deviationStep,
  }) =>
      GradeResult(
        verdict: verdict,
        value: value,
        unit: unit,
        note: note,
        errorCode: errorCode,
        diagnosis: diagnosis,
        critical: critical,
        deviationStep: deviationStep,
        correctDisplay: correctDisplay,
      );
}

/// Cantidad para pantalla («0,96 ml», «2 %»).
String displayQty(String value, String unit) => formatQty(value, unit);

Rational _applyRounding(Rational v, AnswerSpec spec) => switch (spec.rounding) {
      RoundDecimals(:final places) => roundPlaces(v, places),
      RoundInstrument(:final step) => roundStep(v, dec(step)),
      RoundInteger() => roundPlaces(v, 0),
      RoundNone() => v,
    };

int? _requiredPlaces(AnswerSpec spec) => switch (spec.rounding) {
      RoundDecimals(:final places) => places,
      RoundInteger() => 0,
      RoundInstrument(:final step) => decimalsOf(canon(step)),
      RoundNone() => null,
    };

bool _withinTolerance(Rational v, Rational correct, AnswerSpec spec) => switch (spec.tolerance) {
      TolExact() => v == correct,
      TolAbs(:final value) => (v - correct).abs() <= dec(value),
      TolRel(:final percent) => (v - correct).abs() <= correct.abs() * dec(percent) / Rational.fromInt(100),
    };

/// Valor del usuario expresado en la unidad de la respuesta, o null si la
/// unidad no es equivalente.
Rational? _toAnswerUnit(Rational v, String unit, AnswerSpec spec) {
  if (unit == spec.unit) return v;
  for (final e in spec.equivalents) {
    if (e.unit == unit) return v / dec(e.factor);
  }
  return null;
}

final _fifth = Rational.one / Rational.fromInt(5);
final _five = Rational.fromInt(5);

bool _isCritical(String? code, Rational? v, Rational correct) {
  if (code != null && criticalCodes.contains(code)) return true;
  if (v == null) return false;
  if (correct == Rational.zero) return v != Rational.zero;
  if (v == Rational.zero) return true;
  final ratio = (v / correct).abs();
  return ratio >= _five || ratio <= _fifth;
}

bool _matchesPredicted(Rational v, String userUnit, AnswerSpec spec, PredictedError p) {
  var target = dec(p.value);
  // Si la unidad prevista es convertible a la del usuario, se compara en la unidad del usuario.
  if (p.unit.isNotEmpty && p.unit != userUnit) {
    try {
      final a = parseUnit(p.unit);
      final b = parseUnit(userUnit);
      if (sameDims(a.dims, b.dims)) {
        target = target * a.factor / b.factor;
      } else if (!spec.unitFixed) {
        return false; // con unidad elegida, la magnitud debe coincidir
      }
    } on UnitError {
      // Unidad no catalogada: compara la cifra.
    }
  }
  final places = _requiredPlaces(spec);
  if (v == target) return true;
  if (places != null) return roundPlaces(v, places) == roundPlaces(target, places);
  return false;
}

GradeResult grade(AnswerSpec spec, List<PredictedError> predicted, GradeInput input) {
  final correct = dec(spec.value);
  final correctDisplay = displayQty(spec.value, spec.unit);
  final parsed = parseUserNumber(input.raw);
  final base = GradeResult(
    verdict: Verdict.incorrect,
    value: parsed.value,
    unit: spec.unitFixed ? spec.unit : input.unit,
    correctDisplay: correctDisplay,
  );
  if (!parsed.ok || parsed.value == null) {
    return base._with(verdict: Verdict.incorrect);
  }
  final v = dec(parsed.value!);
  final userUnit = spec.unitFixed ? spec.unit : (input.unit ?? '');
  final formatNote = switch (parsed.unsafeFormat) {
    'missing_leading_zero' => 'Se escribe con cero delante: ${formatEs(parsed.value!)}',
    'trailing_zero' => 'Sin ceros finales: ${formatEs(parsed.value!)}',
    _ => null,
  };

  final inAnswerUnit = _toAnswerUnit(v, userUnit, spec);
  if (inAnswerUnit != null) {
    if (_withinTolerance(inAnswerUnit, correct, spec)) {
      return base._with(verdict: formatNote != null ? Verdict.correctNote : Verdict.correct, note: formatNote);
    }
    // Más decimales de los pedidos que redondean al valor correcto.
    final places = _requiredPlaces(spec);
    if (places != null &&
        decimalsOf(canon(inAnswerUnit)) > places &&
        _withinTolerance(_applyRounding(inAnswerUnit, spec), correct, spec)) {
      return base._with(verdict: Verdict.correctNote, note: 'Se redondea a $correctDisplay');
    }
  }

  // Respuesta incorrecta: diagnóstico por respuestas erróneas previsibles.
  for (final p in predicted) {
    if (_matchesPredicted(v, userUnit, spec, p)) {
      if (p.code == 'E7') {
        return base._with(verdict: Verdict.correctNote, note: p.message, errorCode: 'E7');
      }
      return base._with(
        verdict: Verdict.incorrect,
        errorCode: p.code,
        diagnosis: p.message,
        critical: _isCritical(p.code, inAnswerUnit, correct),
        deviationStep: p.deviationStep,
      );
    }
  }

  // Cifra correcta con una unidad equivocada: E1.
  if (inAnswerUnit == null) {
    final sameNumber = v == correct;
    return base._with(
      verdict: Verdict.incorrect,
      errorCode: 'E1',
      diagnosis: sameNumber
          ? 'La cifra es correcta, pero en ${spec.unit}, no en $userUnit'
          : 'La unidad no corresponde: se pedía en ${spec.unit}',
      critical: true,
    );
  }

  // Orden de magnitud no declarado: ×/÷ 10, 100 o 1000.
  if (correct != Rational.zero && inAnswerUnit != Rational.zero) {
    final ratio = inAnswerUnit / correct;
    for (final k in const [10, 100, 1000]) {
      final rk = Rational.fromInt(k);
      if (ratio == rk || ratio == Rational.one / rk) {
        final bigger = ratio > Rational.one;
        final word = k == 10 ? 'diez' : (k == 100 ? 'cien' : 'mil');
        return base._with(
          verdict: Verdict.incorrect,
          errorCode: 'E2',
          diagnosis: 'Tu respuesta es $word veces ${bigger ? 'mayor' : 'menor'}. Revisa la coma y las conversiones',
          critical: true,
        );
      }
    }
  }

  return base._with(verdict: Verdict.incorrect, critical: _isCritical(null, inAnswerUnit, correct));
}

// ---------------------------------------------------------------------------
// Selección única (T2, T6) y ordenar pasos (T3)
// ---------------------------------------------------------------------------

class ChoiceGrade {
  const ChoiceGrade({required this.verdict, this.errorCode, this.diagnosis, this.critical = false});
  final Verdict verdict;
  final String? errorCode;
  final String? diagnosis;
  final bool critical;
}

/// Respuesta a una opción (T2, T6).
ChoiceGrade gradeChoice(List<ChoiceOption> options, String chosenId) {
  ChoiceOption? o;
  for (final x in options) {
    if (x.id == chosenId) o = x;
  }
  if (o == null) return const ChoiceGrade(verdict: Verdict.incorrect);
  if (o.correct) return const ChoiceGrade(verdict: Verdict.correct);
  final code = o.errorCode;
  return ChoiceGrade(
    verdict: Verdict.incorrect,
    errorCode: code,
    diagnosis: o.message,
    critical: code != null && criticalCodes.contains(code),
  );
}

/// Ordenar pasos (T3): válido si coincide con cualquiera de los órdenes declarados.
bool gradeOrder(List<List<String>> validOrders, List<String> answer) => validOrders.any((o) {
      if (o.length != answer.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (o[i] != answer[i]) return false;
      }
      return true;
    });

// ---------------------------------------------------------------------------
// Tipos de fase 2: completar el planteamiento (T4), detectar el error (T5) y
// emparejar (T10)
// ---------------------------------------------------------------------------

class GapGrade {
  const GapGrade({required this.correct, required this.wrongGaps});
  final bool correct;

  /// Huecos con una ficha incorrecta o vacíos.
  final List<String> wrongGaps;
}

/// T4: todos los huecos deben ser correctos. Dentro de cada grupo
/// `interchangeable`, se acepta cualquier permutación de las fichas correctas.
GapGrade gradeGapFill(GapFill g, Map<String, String> placed) {
  final wrong = <String>[];
  final grouped = <String>{};
  for (final group in g.interchangeable) {
    grouped.addAll(group);
    final expected = [for (final id in group) g.gapAnswers[id] ?? '']..sort();
    final got = [for (final id in group) placed[id] ?? '']..sort();
    var ok = expected.length == got.length;
    for (var i = 0; ok && i < expected.length; i++) {
      if (expected[i] != got[i]) ok = false;
    }
    if (!ok) {
      for (final id in group) {
        if (!expected.contains(placed[id])) wrong.add(id);
      }
      if (wrong.isEmpty) wrong.addAll(group);
    }
  }
  for (final id in g.gapIds) {
    if (grouped.contains(id)) continue;
    if (placed[id] == null || placed[id] != g.gapAnswers[id]) wrong.add(id);
  }
  return GapGrade(correct: wrong.isEmpty, wrongGaps: wrong);
}

/// T5: [chosenStepN] es el paso señalado o null para «No hay error».
/// Es correcta si señala un paso equivocado, o «No hay error» cuando todos
/// los pasos son correctos.
bool gradeWorkedStep(List<WorkedStep> worked, int? chosenStepN) {
  final wrong = worked.where((w) => !w.correct).map((w) => w.n).toSet();
  if (wrong.isEmpty) return chosenStepN == null;
  return chosenStepN != null && wrong.contains(chosenStepN);
}

class PairGrade {
  const PairGrade({required this.correct, required this.wrongLefts});
  final bool correct;

  /// Elementos de la columna izquierda mal emparejados o sin emparejar.
  final List<String> wrongLefts;
}

/// T10: corrección par a par; el ejercicio es correcto si todos están unidos bien.
PairGrade gradePairs(List<MatchPair> pairs, Map<String, String> chosen) {
  final wrong = [for (final p in pairs) if (chosen[p.left] != p.right) p.left];
  return PairGrade(correct: wrong.isEmpty, wrongLefts: wrong);
}
