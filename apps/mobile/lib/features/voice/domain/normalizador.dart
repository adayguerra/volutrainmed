/// Normalizador de lectura: de cifra escrita a texto hablado en español de España.
///
/// Espejo de `packages/engine/src/speech.ts`. Lo usan la voz de manos libres
/// y el lector de pantalla (las cantidades se anuncian completas). Debe pasar
/// los mismos casos que el motor TS en `contracts/fixtures/tts.json`.
///
///   0,25 mg      → «cero coma veinticinco miligramos»
///   1 mg, 1 UI   → «un miligramo», «una unidad»
///   21 mg        → «veintiún miligramos»
///   1:10 000     → «uno en diez mil»
///   250 mg/5 ml  → «doscientos cincuenta miligramos en cinco mililitros»
///   µg/kg/min    → «microgramos por kilo y minuto»
library;

const _units0to29 = [
  'cero', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve', //
  'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve',
  'veinte', 'veintiuno', 'veintidós', 'veintitrés', 'veinticuatro', 'veinticinco', 'veintiséis', 'veintisiete',
  'veintiocho', 'veintinueve',
];
const _tens = ['', '', '', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'];
const _hundredsM = [
  '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', //
  'ochocientos', 'novecientos',
];
const _hundredsF = [
  '', 'ciento', 'doscientas', 'trescientas', 'cuatrocientas', 'quinientas', 'seiscientas', 'setecientas', //
  'ochocientas', 'novecientas',
];

/// Género gramatical de la unidad: 'm' o 'f'.
typedef Gender = String;

/// Cómo termina «uno»: 'plain' (uno), 'apocope' (un) o 'fem' (una).
typedef OneMode = String;

String _fixOne(String words, OneMode mode) {
  if (mode == 'plain') return words;
  if (mode == 'apocope') {
    return words
        .replaceFirst(RegExp(r'veintiuno$'), 'veintiún')
        .replaceFirstMapped(RegExp(r'(^|\s)uno$'), (m) => '${m[1]}un');
  }
  return words
      .replaceFirst(RegExp(r'veintiuno$'), 'veintiuna')
      .replaceFirstMapped(RegExp(r'(^|\s)uno$'), (m) => '${m[1]}una');
}

String _below1000(int n, Gender g) {
  if (n == 100) return 'cien';
  final h = n ~/ 100;
  final r = n % 100;
  final parts = <String>[];
  if (h > 0) parts.add((g == 'f' ? _hundredsF : _hundredsM)[h]);
  if (r > 0) {
    if (r < 30) {
      parts.add(_units0to29[r]);
    } else {
      final t = r ~/ 10;
      final u = r % 10;
      parts.add(_tens[t] + (u > 0 ? ' y ${_units0to29[u]}' : ''));
    }
  }
  return parts.join(' ');
}

/// Cardinal en palabras.
String intToWords(BigInt n, [Gender g = 'm', OneMode oneMode = 'plain']) {
  var v = n;
  if (v == BigInt.zero) return 'cero';
  final neg = v.isNegative;
  if (neg) v = -v;
  final million = BigInt.from(1000000);
  final thousand = BigInt.from(1000);
  final millions = (v ~/ million);
  final thousands = ((v ~/ thousand) % thousand).toInt();
  final rest = (v % thousand).toInt();
  final parts = <String>[];
  if (millions > BigInt.zero) {
    parts.add(millions == BigInt.one ? 'un millón' : '${_fixOne(intToWords(millions, 'm'), 'apocope')} millones');
  }
  if (thousands > 0) {
    parts.add(thousands == 1 ? 'mil' : '${_fixOne(_below1000(thousands, g), g == 'f' ? 'fem' : 'apocope')} mil');
  }
  if (rest > 0) parts.add(_fixOne(_below1000(rest, g), oneMode));
  return '${neg ? 'menos ' : ''}${parts.join(' ')}';
}

/// Parte decimal: ceros iniciales cifra a cifra y el resto como cardinal (hasta 3 cifras).
String _fracToWords(String frac) {
  final lead = RegExp(r'^0*').firstMatch(frac)!.group(0)!;
  final rest = frac.substring(lead.length);
  final words = <String>[for (var i = 0; i < lead.length; i++) 'cero'];
  if (rest.isNotEmpty) {
    if (rest.length <= 3) {
      words.add(intToWords(BigInt.parse(rest)));
    } else {
      words.addAll(rest.split('').map((d) => _units0to29[int.parse(d)]));
    }
  }
  return words.join(' ');
}

class UnitReading {
  const UnitReading(this.singular, this.plural, this.gender);
  final String singular;
  final String plural;
  final Gender gender;
}

/// Lecturas de las unidades atómicas. Editables desde el catálogo del back office.
const unitReadings = <String, UnitReading>{
  'g': UnitReading('gramo', 'gramos', 'm'),
  'mg': UnitReading('miligramo', 'miligramos', 'm'),
  'µg': UnitReading('microgramo', 'microgramos', 'm'),
  'mcg': UnitReading('microgramo', 'microgramos', 'm'),
  'ng': UnitReading('nanogramo', 'nanogramos', 'm'),
  'kg': UnitReading('kilo', 'kilos', 'm'),
  'ml': UnitReading('mililitro', 'mililitros', 'm'),
  'l': UnitReading('litro', 'litros', 'm'),
  'µl': UnitReading('microlitro', 'microlitros', 'm'),
  's': UnitReading('segundo', 'segundos', 'm'),
  'min': UnitReading('minuto', 'minutos', 'm'),
  'h': UnitReading('hora', 'horas', 'f'),
  'día': UnitReading('día', 'días', 'm'),
  'gotas': UnitReading('gota', 'gotas', 'f'),
  'UI': UnitReading('unidad', 'unidades internacionales', 'f'),
  'tomas': UnitReading('toma', 'tomas', 'f'),
  '%': UnitReading('por ciento', 'por ciento', 'm'),
};

class UnitText {
  const UnitText(this.text, this.gender);
  final String text;
  final Gender gender;
}

/// Lectura de una unidad compuesta. «µg/kg/min» → «microgramos por kilo y minuto».
UnitText readUnit(String unit, [bool plural = true]) {
  final parts = unit.split('/').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return const UnitText('', 'm');
  final head = unitReadings[parts.first];
  final headText = head != null ? (plural ? head.plural : head.singular) : parts.first;
  final dens = parts.skip(1).map((p) => unitReadings[p]?.singular ?? p).toList();
  var text = headText;
  if (dens.length == 1) {
    text += ' por ${dens.first}';
  } else if (dens.length > 1) {
    text += ' por ${dens.sublist(0, dens.length - 1).join(', ')} y ${dens.last}';
  }
  return UnitText(text, head?.gender ?? 'm');
}

/// Cifra canónica («0.25», «1500») a palabras, concordando con la unidad.
String numberToWords(String value, [Gender gender = 'm', bool beforeNoun = false]) {
  final neg = value.startsWith('-');
  final v = neg ? value.substring(1) : value;
  final parts = v.split('.');
  final intPart = parts[0];
  final frac = parts.length > 1 ? parts[1] : null;
  final hasFrac = frac != null && frac.isNotEmpty;
  final OneMode oneMode = hasFrac ? 'plain' : (beforeNoun ? (gender == 'f' ? 'fem' : 'apocope') : 'plain');
  var words = intToWords(BigInt.parse(intPart.isEmpty ? '0' : intPart), beforeNoun ? gender : 'm', oneMode);
  if (hasFrac) words += ' coma ${_fracToWords(frac)}';
  return '${neg ? 'menos ' : ''}$words';
}

/// Cantidad con unidad. «0.2», «mg/kg» → «cero coma dos miligramos por kilo».
String readQuantity(String value, String unit) {
  if (unit.isEmpty) return numberToWords(value);
  if (unit == '%') return '${numberToWords(value)} por ciento';
  final isOne = value == '1';
  final u = readUnit(unit, !isOne);
  return '${numberToWords(value, u.gender, true)} ${u.text}';
}

const _num = r'\d{1,3}(?:[  ]\d{3})+(?:,\d+)?|\d+(?:,\d+)?';
const _unitToken = r'(?:µg|mcg|mg|ng|kg|g|ml|µl|l|UI|gotas|gota|min|h|s|día|días|tomas|toma|%)';
const _unitRe = '$_unitToken(?:/$_unitToken)*';

final _ratioRe = RegExp('\\b($_num):($_num)\\b');
final _presentationRe = RegExp('($_num)\\s?($_unitToken)/($_num)\\s?($_unitToken)(?![\\p{L}/])', unicode: true);
final _quantityRe = RegExp('($_num)\\s?($_unitRe)(?![\\p{L}])', unicode: true);
final _looseRe = RegExp('(?<![\\p{L}\\d])($_num)(?![\\d])', unicode: true);

String _toCanon(String num) => num.replaceAll(RegExp('[  ]'), '').replaceFirst(',', '.');

/// Normaliza un texto completo para la voz: sustituye razones, presentaciones
/// «250 mg/5 ml» y cantidades con unidad por su lectura.
String speakText(String text) => speakFragment(text).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Igual que [speakText] pero conserva los espacios de los extremos (para unir segmentos).
String speakFragment(String text) {
  var out = text;
  out = out.replaceAllMapped(
    _ratioRe,
    (m) => '${numberToWords(_toCanon(m[1]!))} en ${numberToWords(_toCanon(m[2]!))}',
  );
  out = out.replaceAllMapped(
    _presentationRe,
    (m) => '${readQuantity(_toCanon(m[1]!), m[2]!)} en ${readQuantity(_toCanon(m[3]!), m[4]!)}',
  );
  out = out.replaceAllMapped(_quantityRe, (m) => readQuantity(_toCanon(m[1]!), m[2]!));
  out = out.replaceAllMapped(_looseRe, (m) => numberToWords(_toCanon(m[1]!)));
  return out;
}

/// Lectura para la confirmación hablada: «Cuatro coma ocho mililitros por hora».
String confirmationText(String value, String unit) {
  final s = readQuantity(value, unit);
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

final _confusable = RegExp(
  r'\b(sesenta|setenta|dos|doce|tres|trece|seis|dieciséis|siete|diecisiete|cuatro|catorce|cinco|quince)\b',
);

/// Si la cifra contiene palabras que se confunden, se deletrea: «Sesenta: seis, cero».
String? spellingFor(String value) {
  final words = numberToWords(value);
  if (!_confusable.hasMatch(words)) return null;
  final intPart = value.split('.').first;
  if (intPart.length < 2) return null;
  final digits = value.replaceFirst('-', '').split('').map((c) => c == '.' ? 'coma' : _units0to29[int.parse(c)]);
  return digits.join(', ');
}
