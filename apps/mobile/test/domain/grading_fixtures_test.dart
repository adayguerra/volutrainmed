import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/grading/domain/grading.dart';

/// Casos compartidos con el motor TS (`contracts/fixtures/grading.json`).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('../../contracts/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

AnswerSpec _spec(String value, String unit, {Rounding rounding = const RoundNone(), bool fixed = true, List<UnitEquivalent> eq = const []}) =>
    AnswerSpec(value: value, unit: unit, unitFixed: fixed, unitChoices: [unit], equivalents: eq, rounding: rounding);

void main() {
  group('Fixtures de corrección compartidas con el motor TS', () {
    final cases = (_load('grading.json')['cases'] as List).cast<Map<String, dynamic>>();
    test('hay casos', () => expect(cases, isNotEmpty));
    for (final c in cases) {
      test('[answer-grading] Fixture: ${c['name']}', () {
        final spec = AnswerSpec.fromJson((c['spec'] as Map).cast<String, dynamic>());
        final predicted = (c['predicted'] as List).map((p) => PredictedError.fromJson((p as Map).cast<String, dynamic>())).toList();
        final input = (c['input'] as Map).cast<String, dynamic>();
        final r = grade(spec, predicted, GradeInput('${input['raw']}', unit: input['unit'] as String?));
        final e = (c['expect'] as Map).cast<String, dynamic>();
        expect(verdictWire(r.verdict), e['verdict']);
        if (e.containsKey('critical')) expect(r.critical, e['critical'], reason: 'critical');
        if (e.containsKey('note')) expect(r.note, e['note'], reason: 'note');
        if (e.containsKey('value')) expect(r.value, e['value'], reason: 'value');
        if (e.containsKey('errorCode')) expect(r.errorCode, e['errorCode'], reason: 'errorCode');
        if (e.containsKey('deviationStep')) expect(r.deviationStep, e['deviationStep'], reason: 'deviationStep');
      });
    }
  });

  group('Escenarios de answer-grading', () {
    test('[answer-grading] Escenario: Suma de decimales', () {
      final suma = dec('0.1') + dec('0.2');
      expect(canon(suma), '0.3');
      final r = grade(_spec(canon(suma), 'ml'), const [], const GradeInput('0,3'));
      expect(r.verdict, Verdict.correct);
    });

    test('[answer-grading] Escenario: Más decimales de los pedidos', () {
      final r = grade(_spec('0.27', 'ml', rounding: const RoundDecimals(2)), const [], const GradeInput('0,2667'));
      expect(r.verdict, Verdict.correctNote);
      expect(r.note, 'Se redondea a 0,27 ml');
    });

    test('[answer-grading] Escenario: Formato inseguro', () {
      final a = grade(_spec('0.5', 'mg'), const [], const GradeInput(',5'));
      expect(a.verdict, Verdict.correctNote);
      expect(a.value, '0.5');
      expect(a.note, contains('0,5'));
      final b = grade(_spec('5', 'ml'), const [], const GradeInput('5,0'));
      expect(b.verdict, Verdict.correctNote);
      expect(b.value, '5');
      expect(b.note, contains('5'));
    });

    test('[answer-grading] Escenario: Respuesta incorrecta', () {
      final r = grade(_spec('4.8', 'ml/h', rounding: const RoundDecimals(1)), const [], const GradeInput('5,2'));
      expect(r.verdict, Verdict.incorrect);
      expect(r.correctDisplay, '4,8 ml/h');
    });

    test('[answer-grading] Escenario: Gota entera', () {
      final r = grade(_spec('42', 'gotas/min', rounding: const RoundInteger('gota entera')), const [], const GradeInput('42'));
      expect(r.verdict, Verdict.correct);
      // 20 000 gotas ÷ 480 min = 41,67 → 42 con redondeo aritmético.
      expect(canon(roundPlaces(dec('20000') / dec('480'), 0)), '42');
    });

    test('[answer-grading] Escenario: Jeringa de 1 ml', () {
      final r = grade(_spec('0.27', 'ml', rounding: const RoundInstrument('0.01', 'jeringa de 1 ml')), const [], const GradeInput('0,27'));
      expect(r.verdict, Verdict.correct);
    });

    test('[answer-grading] Escenario: Unidad equivalente', () {
      final spec = AnswerSpec(value: '0.5', unit: 'mg', unitFixed: false, unitChoices: const ['mg', 'µg', 'g'], equivalents: const [UnitEquivalent('µg', '1000')]);
      expect(grade(spec, const [], const GradeInput('500', unit: 'µg')).verdict, Verdict.correct);
    });

    test('[answer-grading] Escenario: Unidad equivocada', () {
      const spec = AnswerSpec(value: '0.5', unit: 'mg', unitFixed: false, unitChoices: ['mg', 'µg', 'g']);
      final r = grade(spec, const [], const GradeInput('0,5', unit: 'µg'));
      expect(r.verdict, Verdict.incorrect);
      expect(r.errorCode, 'E1');
      expect(r.critical, isTrue);
    });

    const pred = [
      PredictedError(value: '9.6', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma'),
      PredictedError(value: '4.8', unit: 'mg', code: 'E4', message: 'Has dado la dosis en mg: falta calcular el volumen'),
    ];

    test('[answer-grading] Escenario: Factor diez', () {
      final r = grade(_spec('0.96', 'ml', rounding: const RoundDecimals(2)), pred, const GradeInput('9,6'));
      expect(r.errorCode, 'E2');
      expect(r.diagnosis, contains('diez veces mayor'));
      expect(r.critical, isTrue);
    });

    test('[answer-grading] Escenario: Factor diez no declarado se detecta igualmente', () {
      final r = grade(_spec('0.96', 'ml', rounding: const RoundDecimals(2)), const [], const GradeInput('96'));
      expect(r.errorCode, 'E2');
      expect(r.diagnosis, 'Tu respuesta es cien veces mayor. Revisa la coma y las conversiones');
    });

    test('[answer-grading] Escenario: Paso omitido', () {
      final r = grade(_spec('0.96', 'ml', rounding: const RoundDecimals(2)), pred, const GradeInput('4,8'));
      expect(r.errorCode, 'E4');
      expect(r.diagnosis, contains('falta calcular el volumen'));
    });

    test('[answer-grading] Escenario: Error sin clasificar', () {
      final r = grade(_spec('0.96', 'ml', rounding: const RoundDecimals(2)), pred, const GradeInput('1,1'));
      expect(r.verdict, Verdict.incorrect);
      expect(r.errorCode, isNull);
      expect(r.diagnosis, isNull);
      expect(r.correctDisplay, '0,96 ml');
    });

    test('[answer-grading] Escenario: Desviación de factor cinco', () {
      final r = grade(_spec('2', 'ml', rounding: const RoundDecimals(1)), const [], const GradeInput('10'));
      expect(r.critical, isTrue);
      final menor = grade(_spec('2', 'ml', rounding: const RoundDecimals(1)), const [], const GradeInput('0,4'));
      expect(menor.critical, isTrue);
      final leve = grade(_spec('2', 'ml', rounding: const RoundDecimals(1)), const [], const GradeInput('3'));
      expect(leve.critical, isFalse);
    });

    test('[answer-grading] Escenario: Dosis máxima no aplicada', () {
      final r = grade(
        _spec('100', 'ml', rounding: const RoundDecimals(1)),
        const [PredictedError(value: '105', unit: 'ml', code: 'E6', message: 'Has superado la dosis máxima indicada en el enunciado')],
        const GradeInput('105'),
      );
      expect(r.errorCode, 'E6');
      expect(r.critical, isTrue);
    });

    test('[answer-grading] Escenario: Explicación de una perfusión', () {
      final r = grade(
        _spec('4.8', 'ml/h', rounding: const RoundDecimals(1)),
        const [PredictedError(value: '0.08', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas', deviationStep: 3)],
        const GradeInput('0,08'),
      );
      expect(r.verdict, Verdict.incorrect);
      expect(r.deviationStep, 3);
      expect(r.errorCode, 'E1');
    });

    test('[exercise-session] Escenario: Teclado físico en tablet («4.8» se acepta como 4,8)', () {
      final r = grade(_spec('4.8', 'ml/h', rounding: const RoundDecimals(1)), const [], const GradeInput('4.8'));
      expect(r.verdict, Verdict.correct);
      expect(r.value, '4.8');
    });
  });

  group('Selección única y ordenar pasos', () {
    const opts = [
      ChoiceOption(id: 'a', label: '1 mg/ml', correct: false, errorCode: 'E2', message: 'Diez veces mayor'),
      ChoiceOption(id: 'b', label: '0,1 mg/ml', correct: true),
      ChoiceOption(id: 'c', label: '0,01 mg/ml', correct: false, errorCode: 'E5', message: 'Dato equivocado'),
    ];

    test('[exercise-session] Escenario: Selección única con opciones diagnósticas', () {
      expect(gradeChoice(opts, 'b').verdict, Verdict.correct);
      final mal = gradeChoice(opts, 'a');
      expect(mal.verdict, Verdict.incorrect);
      expect(mal.errorCode, 'E2');
      expect(mal.diagnosis, 'Diez veces mayor');
      expect(mal.critical, isTrue);
      expect(gradeChoice(opts, 'c').critical, isFalse);
      expect(gradeChoice(opts, 'z').verdict, Verdict.incorrect);
    });

    test('[exercise-session] Escenario: Ordenar pasos con equivalencias', () {
      const valid = [
        ['s1', 's2', 's3', 's4'],
        ['s1', 's3', 's2', 's4'],
        ['s3', 's1', 's2', 's4'],
      ];
      for (final o in valid) {
        expect(gradeOrder(valid, o), isTrue);
      }
      expect(gradeOrder(valid, ['s2', 's1', 's3', 's4']), isFalse);
      expect(gradeOrder(valid, ['s1', 's2', 's3']), isFalse);
    });
  });

  group('Tipos de fase 2 (T4, T5, T10)', () {
    // T4 (pediatría, sección 3.6): volumen por toma con fichas sobrantes.
    const gap = GapFill(
      template: '{g1} × {g2} = 900 mg/día; 900 mg ÷ {g3} = 300 mg; 300 mg × {g4} ÷ {g5} = 6 ml',
      tiles: ['50 mg/kg/día', '18 kg', '3 tomas', '5 ml', '250 mg', '8 h', '24 h'],
      gapAnswers: {'g1': '50 mg/kg/día', 'g2': '18 kg', 'g3': '3 tomas', 'g4': '5 ml', 'g5': '250 mg'},
      interchangeable: [
        ['g1', 'g2'],
      ],
    );

    test('[exercise-type-builder] T4: todos los huecos correctos', () {
      final r = gradeGapFill(gap, const {'g1': '50 mg/kg/día', 'g2': '18 kg', 'g3': '3 tomas', 'g4': '5 ml', 'g5': '250 mg'});
      expect(r.correct, isTrue);
    });

    test('[exercise-type-builder] T4: posiciones intercambiables declaradas', () {
      final r = gradeGapFill(gap, const {'g1': '18 kg', 'g2': '50 mg/kg/día', 'g3': '3 tomas', 'g4': '5 ml', 'g5': '250 mg'});
      expect(r.correct, isTrue);
    });

    test('[exercise-type-builder] T4: ficha sobrante en un hueco', () {
      final r = gradeGapFill(gap, const {'g1': '50 mg/kg/día', 'g2': '18 kg', 'g3': '8 h', 'g4': '5 ml', 'g5': '250 mg'});
      expect(r.correct, isFalse);
      expect(r.wrongGaps, ['g3']);
      expect(gap.gapIds, ['g1', 'g2', 'g3', 'g4', 'g5']);
    });

    const worked = [
      WorkedStep(n: 1, text: '0,1 mg/kg × 20 kg = 2 mg', correct: true),
      WorkedStep(n: 2, text: '1 % = 1 mg/ml', correct: false, correction: '1 % = 10 mg/ml'),
      WorkedStep(n: 3, text: '2 mg ÷ 1 mg/ml = 2 ml', correct: true),
    ];

    test('[exercise-type-builder] Escenario: Detectar el error', () {
      expect(gradeWorkedStep(worked, 2), isTrue);
      expect(gradeWorkedStep(worked, 1), isFalse);
      expect(gradeWorkedStep(worked, null), isFalse);
      final sinError = [for (final w in worked) WorkedStep(n: w.n, text: w.text, correct: true)];
      expect(gradeWorkedStep(sinError, null), isTrue);
      expect(gradeWorkedStep(sinError, 2), isFalse);
    });

    test('[exercise-type-builder] T10: emparejar par a par', () {
      const pairs = [MatchPair('1 %', '10 mg/ml'), MatchPair('1:1000', '1 mg/ml'), MatchPair('1:10 000', '0,1 mg/ml')];
      expect(gradePairs(pairs, const {'1 %': '10 mg/ml', '1:1000': '1 mg/ml', '1:10 000': '0,1 mg/ml'}).correct, isTrue);
      final r = gradePairs(pairs, const {'1 %': '1 mg/ml', '1:1000': '10 mg/ml', '1:10 000': '0,1 mg/ml'});
      expect(r.correct, isFalse);
      expect(r.wrongLefts, ['1 %', '1:1000']);
    });
  });
}
