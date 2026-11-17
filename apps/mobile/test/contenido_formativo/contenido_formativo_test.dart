import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/contenido/verificador.dart';
import 'package:volutrainmed/core/domain/content_models.dart';

/// Comprobaciones del límite formativo sobre TODO el contenido incluido en
/// la app (`assets/content/*.vtmpkg`) y las muestras del servidor
/// (`contracts/sample/*.json`): principio activo, casos simulados y pauta en
/// el enunciado.

/// Principios activos que aparecen en el contenido (denominación común, en
/// minúsculas). Un nombre nuevo obliga a revisarlo y añadirlo aquí.
const principiosActivos = {
  'paracetamol', 'fentanilo', 'noradrenalina', 'meloxicam', 'buprenorfina', 'lidocaína', 'atropina', //
  'midazolam', 'furosemida', 'efedrina', 'ondansetrón', 'bupivacaína', 'adrenalina', 'heparina', 'insulina', 'morfina', 'ketamina',
};

/// Marcas comerciales frecuentes en España que nunca deben aparecer.
const marcas = [
  'Nolotil', 'Gelocatil', 'Voltaren', 'Augmentine', 'Dalsy', 'Termalgin', 'Efferalgan', 'Enantyum', 'Adiro', 'Sintrom', //
  'Apiretal', 'Frenadol', 'Ibuprofeno Cinfa', 'Paracetamol Kern', 'Fentanest', 'Dormicum', 'Seguril', 'Xylocaína', 'Metacam', 'Buprex',
];

class Caso {
  Caso(this.origen, this.v);
  final String origen;
  final Variant v;
  String get enunciado => v.statement.map((s) => s.isQty ? '{${s.value} ${s.unit}}' : s.text!).join();

  /// Todo el texto que ve u oye el usuario.
  String get textos => [
        enunciado,
        v.question,
        v.tts,
        v.approach ?? '',
        v.hint ?? '',
        v.plausibility,
        for (final p in v.steps) '${p.text} ${p.operation}',
        for (final o in v.options ?? const <ChoiceOption>[]) '${o.label} ${o.message ?? ''}',
        for (final e in v.predictedErrors) e.message,
      ].join(' \n ');
}

void main() {
  final casos = <Caso>[];
  final textosGlobales = <String>[];

  setUpAll(() {
    for (final f in Directory('assets/content').listSync().whereType<File>().where((f) => f.path.endsWith('.vtmpkg'))) {
      final j = decodificarPaquete(f.readAsBytesSync());
      if (j['variants'] is List) {
        casos.addAll(ItineraryPackage.fromJson(j).variants.map((v) => Caso(f.path, v)));
      } else {
        textosGlobales.add(jsonEncode(j));
      }
    }
    for (final f in Directory('../../contracts/sample').listSync().whereType<File>().where((f) => f.path.endsWith('.json') && !f.path.endsWith('manifest.json'))) {
      final j = (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
      if (j['variants'] is List) {
        casos.addAll(ItineraryPackage.fromJson(j).variants.map((v) => Caso(f.path, v)));
      } else {
        textosGlobales.add(jsonEncode(j));
      }
    }
  });

  test('se revisa todo el contenido incluido y las muestras del servidor', () {
    expect(casos.length, greaterThan(1500));
    expect(casos.map((c) => c.origen).toSet().length, greaterThanOrEqualTo(4));
    expect(textosGlobales, isNotEmpty);
  });

  test('formative-boundary · Principio activo: los enunciados nombran los fármacos por su principio activo, nunca por una marca comercial', () {
    final posicionFarmaco = RegExp(r'(?:Pauta(?: del caso)?: |\} de |ampolla de |máximo de \{[^}]*\} de )([A-Za-zÁÉÍÓÚáéíóúñÑ]+)');
    final nombrados = <String>{};
    for (final c in casos) {
      final t = c.textos;
      expect(t.contains('®') || t.contains('™'), isFalse, reason: '${c.v.id}: símbolo de marca');
      for (final m in marcas) {
        expect(t.toLowerCase().contains(m.toLowerCase()), isFalse, reason: '${c.v.id}: marca «$m»');
      }
      // Ningún nombre propio a mitad de frase (las marcas van en mayúscula).
      final propio = RegExp(r'(?<=[a-záéíóúñ,] )[A-ZÁÉÍÓÚ][a-záéíóúñ]+').firstMatch('${c.enunciado} ${c.v.question}');
      expect(propio, isNull, reason: '${c.v.id}: «${propio?.group(0)}» parece un nombre comercial');
      for (final m in posicionFarmaco.allMatches(c.enunciado)) {
        final w = m.group(1)!;
        if (w == 'un' || w == 'una') continue; // «un fármaco con presentación de…»
        expect(w, w.toLowerCase(), reason: '${c.v.id}: «$w» en mayúscula');
        expect(principiosActivos, contains(w), reason: '${c.v.id}: «$w» no es un principio activo de la lista');
        nombrados.add(w);
      }
    }
    expect(nombrados, containsAll(['paracetamol', 'noradrenalina', 'meloxicam', 'lidocaína']), reason: 'la comprobación encuentra los fármacos');
    for (final g in textosGlobales) {
      for (final m in marcas) {
        expect(g.toLowerCase().contains(m.toLowerCase()), isFalse, reason: 'contenido global: marca «$m»');
      }
      expect(g.contains('®') || g.contains('™'), isFalse);
    }
  });

  test('formative-boundary · Paciente simulado: toda persona o animal del enunciado se presenta como simulado y sin datos identificativos', () {
    final sujeto = RegExp(r'\b(paciente|niño|niña|bebé|mujer|hombre|perro|perra|gato|gata|caballo|conejo|hurón)\b', caseSensitive: false);
    var conSujeto = 0;
    for (final c in casos) {
      final e = c.enunciado;
      if (!sujeto.hasMatch(e)) continue;
      conSujeto++;
      expect(e.toLowerCase(), contains('simulad'), reason: '${c.v.id}: «$e»');
      // Sin nombres, iniciales, edades exactas de nacimiento ni números de historia.
      expect(RegExp(r'\b(historia|NHC|DNI|cama|habitación|nacid[oa])\b', caseSensitive: false).hasMatch(e), isFalse, reason: c.v.id);
    }
    expect(conSujeto, greaterThan(300));
  });

  test('formative-boundary · Enunciado con pauta: todo caso con peso trae la pauta por peso como dato del enunciado', () {
    var conPeso = 0;
    for (final c in casos) {
      final unidades = c.v.statement.where((s) => s.isQty).map((s) => s.unit!).toList();
      if (!unidades.contains('kg')) continue;
      conPeso++;
      expect(unidades.any((u) => u.contains('/kg')), isTrue, reason: '${c.v.id}: «${c.enunciado}» sin pauta por peso');
    }
    expect(conPeso, greaterThan(300));
  });

  test('formative-boundary · Límite de dosis como dato: los casos con dosis máxima la dan en el enunciado como dato del caso', () {
    final conLimite = casos.where((c) => c.v.steps.any((p) => RegExp(r'límite|máximo|mín\(', caseSensitive: false).hasMatch('${p.text} ${p.operation}'))).toList();
    expect(conLimite, isNotEmpty);
    for (final c in conLimite) {
      expect(c.enunciado.toLowerCase(), contains('máximo'), reason: '${c.v.id}: «${c.enunciado}»');
      expect(c.enunciado, isNot(contains('recomend')), reason: 'la app no recomienda pautas');
    }
  });
}
