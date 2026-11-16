import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/features/voice/domain/analizador.dart';

/// Casos compartidos con el motor TS (`contracts/fixtures/spoken.json`).
Map<String, dynamic> _load(String name) =>
    jsonDecode(File('../../contracts/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

String? _value(SpokenResult r) => r is SpokenNumber ? r.value : null;

void main() {
  group('Fixtures del analizador hablado compartidas con el motor TS', () {
    final cases = (_load('spoken.json')['cases'] as List).cast<Map<String, dynamic>>();
    for (final c in cases) {
      test('[hands-free-voice] Fixture: «${c['said']}»', () {
        final syn = (c['synonyms'] as Map?)?.map((k, v) => MapEntry('$k', '$v'));
        final r = parseSpoken('${c['said']}', opts: SpokenOptions(digitByDigit: c['digitByDigit'] == true, synonyms: syn));
        if (c.containsKey('value')) {
          expect(r, isA<SpokenNumber>());
          final n = r as SpokenNumber;
          expect(n.value, c['value']);
          if (c['unit'] != null) expect(n.unit, c['unit']);
        } else if (c.containsKey('ambiguous')) {
          expect(r, isA<SpokenAmbiguous>());
          final a = r as SpokenAmbiguous;
          expect(a.options, c['ambiguous']);
          expect(a.question, c['question']);
        } else if (c.containsKey('command')) {
          expect(r, isA<SpokenCommandResult>());
          expect((r as SpokenCommandResult).command, c['command']);
        } else if (c['unparsed'] == true) {
          expect(r, isA<SpokenUnparsed>());
        } else {
          fail('Caso sin expectativa: $c');
        }
      });
    }
  });

  group('Escenarios de hands-free-voice', () {
    test('[hands-free-voice] Escenario: Variantes de un mismo decimal', () {
      for (final s in ['cero coma cinco', 'coma cinco', 'cero con cinco', 'cero punto cinco', 'medio']) {
        expect(_value(parseSpoken(s)), '0.5', reason: s);
      }
    });

    test('[hands-free-voice] Escenario: Cero tras la coma', () {
      expect(_value(parseSpoken('cero coma cero cinco')), '0.05');
    });

    test('[hands-free-voice] Escenario: Entero y medio', () {
      expect(_value(parseSpoken('dos y medio')), '2.5');
    });

    test('[hands-free-voice] Escenario: Respuesta ambigua', () {
      final r = parseSpoken('dos cinco');
      expect(r, isA<SpokenAmbiguous>());
      expect((r as SpokenAmbiguous).question, '¿Veinticinco o dos coma cinco?');
    });

    test('[hands-free-voice] Escenario: Unidad fija (la cifra sola se acepta)', () {
      final r = parseSpoken('cuatro coma ocho') as SpokenNumber;
      expect(r.value, '4.8');
      expect(r.unit, isNull);
    });

    test('[hands-free-voice] Escenario: Sinónimo de sector', () {
      final r = parseSpoken('doscientas gammas', opts: const SpokenOptions(synonyms: {'gammas': 'µg'})) as SpokenNumber;
      expect(r.value, '200');
      expect(r.unit, 'µg');
      // Sin el sinónimo activado, «gammas» no es una unidad reconocida.
      expect(parseSpoken('doscientas gammas'), isA<SpokenUnparsed>());
    });

    test('[hands-free-voice] Escenario: Miligramos o microgramos', () {
      expect(unitQuestion('mg', 'µg'), '¿Miligramos o microgramos?');
      expect(unitQuestion('µg', 'mg'), '¿Miligramos o microgramos?');
      expect(unitQuestion('ml', 'h'), isNull);
    });

    test('[hands-free-voice] Escenario: Comandos de voz', () {
      final esperado = {
        'repite': 'repite',
        'siguiente': 'siguiente',
        'no lo sé': 'no_lo_se',
        'pausa': 'pausa',
        'continúa': 'continua',
        'explica': 'explica',
        'teclado': 'teclado',
        'salir': 'salir',
        'más información': 'mas_informacion',
        'Repite los datos': 'repite_datos',
      };
      esperado.forEach((dicho, cmd) {
        final r = parseSpoken(dicho);
        expect(r, isA<SpokenCommandResult>(), reason: dicho);
        expect((r as SpokenCommandResult).command, cmd, reason: dicho);
      });
    });

    test('[hands-free-voice] Léxico de confusiones y cardinales', () {
      expect(_value(parseSpoken('cuatro como ocho')), '4.8');
      expect(_value(parseSpoken('cuarenta y dos')), '42');
      expect(_value(parseSpoken('mil quinientos')), '1500');
      expect(parseCardinal(['veintiún', 'mil']), isNull); // con tilde no está normalizado
      expect(parseCardinal(['veintiun', 'mil']), 21000);
      expect(stripDiacritics('añádelo'), 'anadelo');
      expect(parseSpoken(''), isA<SpokenUnparsed>());
    });
  });
}
