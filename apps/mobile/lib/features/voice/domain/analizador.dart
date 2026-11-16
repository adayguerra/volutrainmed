/// Analizador de respuestas habladas en español de España (sección 7.3).
///
/// Espejo de `packages/engine/src/spoken.ts`. El reconocedor devuelve texto;
/// este analizador lo convierte en una cifra con su unidad, en un comando o
/// en una ambigüedad que hay que preguntar. Antes del análisis se aplica el
/// léxico de confusiones. Debe pasar los mismos casos que el motor TS en
/// `contracts/fixtures/spoken.json`. No guarda nada: solo interpreta.
library;

/// Comandos de voz (mismos nombres que en el contrato).
abstract final class SpokenCommand {
  static const repite = 'repite';
  static const repiteDatos = 'repite_datos';
  static const siguiente = 'siguiente';
  static const noLoSe = 'no_lo_se';
  static const pausa = 'pausa';
  static const continua = 'continua';
  static const si = 'si';
  static const no = 'no';
  static const explica = 'explica';
  static const salta = 'salta';
  static const masDespacio = 'mas_despacio';
  static const masRapido = 'mas_rapido';
  static const cifraACifra = 'cifra_a_cifra';
  static const teclado = 'teclado';
  static const salir = 'salir';
  static const masInformacion = 'mas_informacion';
  static const empezar = 'empezar';
}

const defaultCommands = <String, List<String>>{
  'repite': ['repite', 'otra vez', 'repítelo', 'repitelo'],
  'repite_datos': ['repite los datos', 'los datos'],
  'siguiente': ['siguiente', 'continuar'],
  'no_lo_se': ['no lo sé', 'no lo se', 'ni idea'],
  'pausa': ['pausa', 'espera', 'un momento'],
  'continua': ['continúa', 'continua', 'sigue'],
  'si': ['sí', 'si', 'correcto', 'eso es', 'vale', 'confirmar'],
  'no': ['no', 'incorrecto', 'corrige'],
  'explica': ['explica', 'cómo se hace', 'como se hace'],
  'salta': ['salta'],
  'mas_despacio': ['más despacio', 'mas despacio'],
  'mas_rapido': ['más rápido', 'mas rapido'],
  'cifra_a_cifra': ['cifra a cifra'],
  'teclado': ['teclado', 'escribir'],
  'salir': ['salir', 'terminar'],
  'mas_informacion': ['más información', 'mas informacion', 'más info'],
  'empezar': ['empezar', 'empieza'],
};

const defaultConfusions = <String, String>{
  'como': 'coma',
  'toma': 'coma',
  'goma': 'coma',
  'cerro': 'cero',
  'tos': 'dos',
  'ocio': 'ocho',
  'sei': 'seis',
};

/// Formas habladas de las unidades (léxico de unidades).
const defaultUnitForms = <String, List<String>>{
  'ml/h': ['mililitros por hora', 'mililitros hora', 'mililitros a la hora', 'mililitro por hora'],
  'gotas/min': ['gotas por minuto', 'gotas minuto', 'gotas al minuto'],
  'mg/ml': ['miligramos por mililitro', 'miligramos mililitro'],
  'µg/ml': ['microgramos por mililitro', 'microgramos mililitro'],
  'µg/kg/min': ['microgramos por kilo y minuto', 'microgramos kilo minuto', 'microgramos por kilo por minuto'],
  'mg/kg': ['miligramos por kilo', 'miligramos kilo'],
  'µg/h': ['microgramos por hora', 'microgramos hora'],
  'µg/min': ['microgramos por minuto', 'microgramos minuto'],
  'mg/h': ['miligramos por hora', 'miligramos hora'],
  'UI/ml': ['unidades por mililitro', 'unidades internacionales por mililitro'],
  'ml': ['mililitros', 'mililitro', 'eme ele', 'ce ce', 'centímetros cúbicos', 'centimetros cubicos'],
  'mg': ['miligramos', 'miligramo'],
  'µg': ['microgramos', 'microgramo'],
  'g': ['gramos', 'gramo'],
  'UI': ['unidades internacionales', 'unidades', 'unidad'],
  '%': ['por ciento'],
  'h': ['horas', 'hora'],
  'min': ['minutos', 'minuto'],
  'kg': ['kilos', 'kilo', 'kilogramos'],
  'gotas': ['gotas', 'gota'],
};

class SpokenOptions {
  const SpokenOptions({this.digitByDigit = false, this.confusions, this.commands, this.unitForms, this.synonyms});
  final bool digitByDigit;
  final Map<String, String>? confusions;
  final Map<String, List<String>>? commands;
  final Map<String, List<String>>? unitForms;

  /// Sinónimos activados: forma hablada → unidad. «gammas» → «µg».
  final Map<String, String>? synonyms;
}

sealed class SpokenResult {
  const SpokenResult();
}

class SpokenNumber extends SpokenResult {
  const SpokenNumber(this.value, this.unit, [this.spokenUnit]);

  /// Cifra canónica con punto.
  final String value;
  final String? unit;
  final String? spokenUnit;
}

class SpokenCommandResult extends SpokenResult {
  const SpokenCommandResult(this.command);
  final String command;
}

class SpokenAmbiguous extends SpokenResult {
  const SpokenAmbiguous(this.options, this.question, this.unit);
  final List<String> options;
  final String question;
  final String? unit;
}

class SpokenUnparsed extends SpokenResult {
  const SpokenUnparsed(this.reason);

  /// 'empty' | 'no_number'.
  final String reason;
}

const _digit = <String, int>{
  'cero': 0, 'uno': 1, 'un': 1, 'una': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, //
  'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
};
const _small = <String, int>{
  ..._digit,
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15, 'dieciseis': 16, //
  'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19, 'veinte': 20, 'veintiuno': 21, 'veintiun': 21,
  'veintiuna': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26,
  'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
};
const _tensMap = <String, int>{
  'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90, //
};
const _hundreds = <String, int>{
  'cien': 100, 'ciento': 100, 'doscientos': 200, 'doscientas': 200, 'trescientos': 300, 'trescientas': 300, //
  'cuatrocientos': 400, 'cuatrocientas': 400, 'quinientos': 500, 'quinientas': 500, 'seiscientos': 600,
  'seiscientas': 600, 'setecientos': 700, 'setecientas': 700, 'ochocientos': 800, 'ochocientas': 800,
  'novecientos': 900, 'novecientas': 900,
};

const _diacritics = <String, String>{
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n', 'à': 'a', 'è': 'e', 'ì': 'i', //
  'ò': 'o', 'ù': 'u', 'ï': 'i', 'â': 'a', 'ê': 'e', 'î': 'i', 'ô': 'o', 'û': 'u', 'ç': 'c',
  'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N', 'Ç': 'C',
};

/// Quita las marcas diacríticas, como NFD + eliminar marcas combinantes en TS
/// (también «ñ» pasa a «n»). Las letras no latinas y «µ» se conservan.
String stripDiacritics(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    // Marcas combinantes U+0300–U+036F (por si el texto llega ya descompuesto).
    if (r >= 0x300 && r <= 0x36f) continue;
    final ch = String.fromCharCode(r);
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString();
}

List<String> _normalizeUtterance(String text, Map<String, String> confusions) {
  final words = stripDiacritics(text.toLowerCase())
      .replaceAll(RegExp(r'[¿?¡!.,;:«»"]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return words.map((w) => confusions[w] ?? w).toList();
}

bool _isNumberWord(String w) =>
    _small.containsKey(w) || _tensMap.containsKey(w) || _hundreds.containsKey(w) || w == 'mil' || w == 'y';

/// Cardinal de 0 a 999 999 en palabras → número, o null si no encaja.
int? parseCardinal(List<String> words) {
  if (words.isEmpty) return null;
  var total = 0;
  var current = 0;
  var i = 0;
  var sawAny = false;
  while (i < words.length) {
    final w = words[i];
    if (_hundreds.containsKey(w)) {
      current += _hundreds[w]!;
      sawAny = true;
      i++;
      continue;
    }
    if (_tensMap.containsKey(w)) {
      current += _tensMap[w]!;
      sawAny = true;
      i++;
      if (i + 1 < words.length && words[i] == 'y' && _digit.containsKey(words[i + 1]) && _digit[words[i + 1]]! > 0) {
        current += _digit[words[i + 1]]!;
        i += 2;
      }
      continue;
    }
    if (_small.containsKey(w)) {
      current += _small[w]!;
      sawAny = true;
      i++;
      continue;
    }
    if (w == 'mil') {
      total += (current == 0 ? 1 : current) * 1000;
      current = 0;
      sawAny = true;
      i++;
      continue;
    }
    return null;
  }
  return sawAny ? total + current : null;
}

/// ¿Es una secuencia de cifras sueltas («dos cinco»)?
bool _allDigits(List<String> words) => words.length > 1 && words.every(_digit.containsKey);

/// Parte decimal: cifras sueltas («cero cinco») o cardinales («veinticinco»).
String? _parseDecimalWords(List<String> words) {
  final out = StringBuffer();
  var i = 0;
  while (i < words.length) {
    final w = words[i];
    if (_digit.containsKey(w) && !(i + 1 < words.length && words[i + 1] == 'y')) {
      out.write(_digit[w]);
      i++;
      continue;
    }
    // Cardinal de varias palabras: toma el tramo máximo que encaje.
    var j = words.length;
    int? found;
    for (; j > i; j--) {
      final v = parseCardinal(words.sublist(i, j));
      if (v != null) {
        found = v;
        break;
      }
    }
    if (found == null) return null;
    out.write(found);
    i = j;
  }
  return out.toString();
}

String _canonDecimal(String intPart, String frac) {
  final f = frac.replaceFirst(RegExp(r'0+$'), '');
  final i = BigInt.parse(intPart.isEmpty ? '0' : intPart).toString();
  return f.isNotEmpty ? '$i.$f' : i;
}

String? _matchCommand(List<String> words, Map<String, List<String>> commands) {
  final utter = words.join(' ');
  String? bestCmd;
  var bestLen = -1;
  commands.forEach((cmd, syns) {
    for (final s in syns) {
      final norm = stripDiacritics(s.toLowerCase());
      if (utter == norm && norm.length > bestLen) {
        bestCmd = cmd;
        bestLen = norm.length;
      }
    }
  });
  return bestCmd;
}

class _UnitExtraction {
  const _UnitExtraction(this.unit, this.spoken, this.rest);
  final String? unit;
  final String? spoken;
  final List<String> rest;
}

_UnitExtraction _extractUnit(List<String> words, Map<String, List<String>> unitForms, Map<String, String> synonyms) {
  final text = words.join(' ');
  final candidates = <(String, String)>[];
  unitForms.forEach((unit, forms) {
    for (final f in forms) {
      candidates.add((unit, stripDiacritics(f.toLowerCase())));
    }
  });
  synonyms.forEach((form, unit) => candidates.add((unit, stripDiacritics(form.toLowerCase()))));
  // Orden estable por longitud descendente (como Array.prototype.sort en TS).
  final indexed = candidates.indexed.toList()
    ..sort((a, b) {
      final c = b.$2.$2.length.compareTo(a.$2.$2.length);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  for (final (_, (unit, form)) in indexed) {
    if (text == form || text.endsWith(' $form')) {
      final rest = text.substring(0, text.length - form.length).trim();
      return _UnitExtraction(unit, form, rest.isEmpty ? const [] : rest.split(' '));
    }
  }
  return _UnitExtraction(null, null, words);
}

const _fractions = <String, String>{'medio': '5', 'media': '5', 'cuarto': '25'};

SpokenResult parseSpoken(String text, {SpokenOptions opts = const SpokenOptions()}) {
  final confusions = {...defaultConfusions, ...?opts.confusions};
  final words = _normalizeUtterance(text, confusions);
  if (words.isEmpty) return const SpokenUnparsed('empty');

  final cmd = _matchCommand(words, opts.commands ?? defaultCommands);
  if (cmd != null) return SpokenCommandResult(cmd);

  final ex = _extractUnit(words, opts.unitForms ?? defaultUnitForms, opts.synonyms ?? const {});
  final unit = ex.unit;
  final spoken = ex.spoken;
  final w = ex.rest;
  if (w.isEmpty) return const SpokenUnparsed('no_number');

  // Fracciones habladas.
  if (w.length == 1 && (w[0] == 'medio' || w[0] == 'media')) return SpokenNumber('0.5', unit, spoken);
  if (w.join(' ') == 'un cuarto') return SpokenNumber('0.25', unit, spoken);
  if (w.join(' ') == 'tres cuartos') return SpokenNumber('0.75', unit, spoken);
  final last = w.last;
  if (w.length >= 3 && w[w.length - 2] == 'y' && _fractions.containsKey(last)) {
    final n = parseCardinal(w.sublist(0, w.length - 2));
    if (n != null) return SpokenNumber(_canonDecimal('$n', _fractions[last]!), unit, spoken);
  }

  // Separador decimal: «coma», «con», «punto».
  final sepIdx = w.indexWhere((x) => x == 'coma' || x == 'con' || x == 'punto');
  if (sepIdx >= 0) {
    final intWords = w.sublist(0, sepIdx);
    final fracWords = w.sublist(sepIdx + 1);
    String intVal;
    if (intWords.isEmpty) {
      intVal = '0';
    } else if (_allDigits(intWords)) {
      intVal = intWords.map((x) => '${_digit[x]}').join();
    } else {
      final n = parseCardinal(intWords);
      if (n == null) return const SpokenUnparsed('no_number');
      intVal = '$n';
    }
    final frac = _parseDecimalWords(fracWords);
    if (frac == null || frac.isEmpty) return const SpokenUnparsed('no_number');
    return SpokenNumber(_canonDecimal(intVal, frac), unit, spoken);
  }

  if (!w.every(_isNumberWord)) return const SpokenUnparsed('no_number');

  if (opts.digitByDigit && w.every(_digit.containsKey)) {
    return SpokenNumber(BigInt.parse(w.map((x) => '${_digit[x]}').join()).toString(), unit, spoken);
  }
  if (_allDigits(w)) {
    if (w.length == 2) {
      final a = _digit[w[0]]!;
      final b = _digit[w[1]]!;
      final asInt = '${a * 10 + b}';
      final asDec = _canonDecimal('$a', '$b');
      return SpokenAmbiguous(
        [asInt, asDec],
        '¿${_capital(_intWordsFor(asInt))} o ${_intWordsFor('$a')} coma ${_intWordsFor('$b')}?',
        unit,
      );
    }
    return SpokenNumber(BigInt.parse(w.map((x) => '${_digit[x]}').join()).toString(), unit, spoken);
  }
  final n = parseCardinal(w);
  if (n == null) return const SpokenUnparsed('no_number');
  return SpokenNumber('$n', unit, spoken);
}

const _simpleWords = ['cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve'];
const _teenWords = <int, String>{
  10: 'diez', 11: 'once', 12: 'doce', 13: 'trece', 14: 'catorce', 15: 'quince', 16: 'dieciséis', //
  17: 'diecisiete', 18: 'dieciocho', 19: 'diecinueve', 20: 'veinte', 21: 'veintiuno', 22: 'veintidós',
  23: 'veintitrés', 24: 'veinticuatro', 25: 'veinticinco', 26: 'veintiséis', 27: 'veintisiete', 28: 'veintiocho',
  29: 'veintinueve',
};
const _tensWords = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];

String _intWordsFor(String s) {
  final n = int.parse(s);
  if (n < 10) return _simpleWords[n];
  if (n < 30) return _teenWords[n]!;
  final t = n ~/ 10;
  final u = n % 10;
  return _tensWords[t] + (u > 0 ? ' y ${_simpleWords[u]}' : '');
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Pares de unidades que suenan parecido y obligan a preguntar.
const confusableUnits = <(String, String, String)>[
  ('mg', 'µg', '¿Miligramos o microgramos?'),
  ('mg', 'ml', '¿Miligramos o mililitros?'),
  ('µg', 'ml', '¿Microgramos o mililitros?'),
];

String? unitQuestion(String a, String b) {
  for (final (x, y, q) in confusableUnits) {
    if ((x == a && y == b) || (x == b && y == a)) return q;
  }
  return null;
}
