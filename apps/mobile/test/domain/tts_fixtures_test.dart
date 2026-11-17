import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/units.dart';
import 'package:volutrainmed/features/voice/domain/normalizador.dart';

/// Casos compartidos con el motor TS (`contracts/fixtures/tts.json`).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('../../contracts/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('Fixtures de lectura compartidas con el motor TS', () {
    final f = _load('tts.json');
    for (final q in (f['quantities'] as List).cast<Map<String, dynamic>>()) {
      test('[hands-free-voice] Fixture: ${q['value']} ${q['unit']}', () {
        expect(readQuantity('${q['value']}', '${q['unit']}'), q['spoken']);
      });
    }
    for (final t in (f['texts'] as List).cast<Map<String, dynamic>>()) {
      test('[hands-free-voice] Fixture: ${t['text']}', () {
        expect(speakText('${t['text']}'), t['spoken']);
      });
    }
  });

  group('Normalizador', () {
    test('[adaptive-accessible-ui] Escenario: Lectura de una cantidad', () {
      expect(readQuantity('0.2', 'mg/kg'), 'cero coma dos miligramos por kilo');
    });

    test('[hands-free-voice] Escenario: Turno completo (confirmación con unidad)', () {
      expect(confirmationText('4.8', 'ml/h'), 'Cuatro coma ocho mililitros por hora');
    });

    test('[hands-free-voice] Escenario: Cifras que se confunden', () {
      expect(spellingFor('60'), 'seis, cero');
      expect(spellingFor('4.8'), isNull);
      expect(spellingFor('7'), isNull);
    });

    test('[hands-free-voice] Lectura de un enunciado con datos y pregunta', () {
      expect(
        speakText('Paciente simulado de 80 kg. Pauta: noradrenalina a 0,1 µg/kg/min. Dilución de 100 µg/ml.'),
        'Paciente simulado de ochenta kilos. Pauta: noradrenalina a cero coma uno microgramos por kilo y minuto. '
        'Dilución de cien microgramos por mililitro.',
      );
      expect(speakText('Hay 21 ejercicios'), 'Hay veintiuno ejercicios');
    });

    test('cardinales', () {
      expect(intToWords(BigInt.from(1500)), 'mil quinientos');
      expect(intToWords(BigInt.from(2000000)), 'dos millones');
      expect(intToWords(BigInt.from(21000)), 'veintiún mil');
      expect(numberToWords('0.05'), 'cero coma cero cinco');
      expect(numberToWords('1.2345'), 'uno coma dos tres cuatro cinco');
    });
  });

  group('Formato decimal en español de España', () {
    test('[answer-grading] Formato: coma, cero inicial, sin ceros finales y espacio fino', () {
      expect(formatEs('12500'), '12 500');
      expect(formatEs('1500'), '1500');
      expect(formatEs('0.5'), '0,5');
      expect(formatEs('5.0'), '5');
      expect(formatEs('-0.25'), '-0,25');
      expect(formatQty('2', '%'), '2 %');
      expect(formatQty('0.96', 'ml'), '0,96 ml');
    });

    test('parseUserNumber', () {
      final a = parseUserNumber(',5');
      expect(a.ok, isTrue);
      expect(a.value, '0.5');
      expect(a.unsafeFormat, 'missing_leading_zero');
      expect(parseUserNumber('5,').unsafeFormat, 'trailing_zero');
      expect(parseUserNumber('4.8').value, '4.8');
      expect(parseUserNumber('4,8,1').error, 'two_separators');
      expect(parseUserNumber('4.8,1').error, 'two_separators');
      expect(parseUserNumber('').error, 'empty');
      expect(parseUserNumber('abc').error, 'invalid');
      expect(parseUserNumber('12 500').value, '12500');
    });

    test('canon y redondeo exactos', () {
      expect(canon(dec('0.30')), '0.3');
      expect(canon(roundPlaces(dec('0.2667'), 2)), '0.27');
      expect(canon(roundPlaces(dec('0.125'), 2)), '0.13');
      expect(canon(roundPlaces(dec('-0.125'), 2)), '-0.13');
      expect(canon(roundStep(dec('0.53'), dec('0.2'))), '0.6');
      expect(decimalsOf(canon(dec('1') / dec('3'))), 60);
    });

    test('unidades: análisis dimensional', () {
      expect(canon(convert(dec('0.25'), 'mg', 'µg')), '250');
      expect(canon(convert(dec('2'), '%', 'mg/ml')), '20');
      expect(sameDims(parseUnit('µg/kg/min').dims, parseUnit('mg/kg/h').dims), isTrue);
      expect(unitsEquivalent('mcg', 'µg'), isTrue);
      expect(() => parseUnit('foo'), throwsA(isA<UnitError>()));
    });
  });
}
