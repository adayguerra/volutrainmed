/// Aritmética decimal exacta y formato de cifras en español de España.
///
/// Espejo de `packages/engine/src/decimal.ts`:
/// - Nunca se usa coma flotante binaria: 0,1 + 0,2 = 0,3. Internamente se
///   trabaja con racionales exactos ([Rational]).
/// - Redondeo aritmético: el 5 sube (half-up, alejándose de cero).
/// - Formato: coma decimal, cero inicial obligatorio, ningún cero final y
///   espacio fino (U+2009) a partir de cinco cifras enteras (12 500).
library;

import 'package:decimal/decimal.dart';
// `rational` llega como dependencia de `decimal`; conviene declararla directa.
import 'package:rational/rational.dart';

export 'package:rational/rational.dart' show Rational;

/// Espacio fino para separar miles en pantalla.
const thinSpace = ' ';

final _ten = BigInt.from(10);

/// Interpreta una cadena decimal canónica («0.96», «1500», «-2.5»).
Rational dec(String v) => Decimal.parse(v.trim()).toRational();

Rational _toRational(Object v) {
  if (v is Rational) return v;
  if (v is Decimal) return v.toRational();
  if (v is int) return Rational.fromInt(v);
  if (v is BigInt) return Rational(v);
  return dec('$v');
}

/// Cadena canónica con punto, sin ceros finales y con cero inicial.
///
/// Los racionales no terminantes (1/3) se expresan con 60 decimales
/// redondeados, como decimal.js con precisión 60.
String canon(Object v) {
  final r = _toRational(v);
  if (r == Rational.zero) return '0';
  final d = r.hasFinitePrecision ? r.toDecimal() : roundPlaces(r, 60).toDecimal();
  var s = d.toString();
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s == '-0' ? '0' : s;
}

/// Redondea a [places] decimales (half-up).
Rational roundPlaces(Rational v, int places) {
  final f = Rational(_ten.pow(places));
  return Rational((v * f).round()) / f;
}

/// Redondea al múltiplo más cercano de [step] (redondeo aritmético).
Rational roundStep(Rational v, Rational step) {
  if (step == Rational.zero) return v;
  return Rational((v / step).round()) * step;
}

/// Número de decimales de una cadena canónica.
int decimalsOf(String s) {
  final i = s.indexOf('.');
  return i < 0 ? 0 : s.length - i - 1;
}

/// Presentación en pantalla: «0,96», «12 500», «1500».
String formatEs(Object v) {
  final s = canon(v);
  final neg = s.startsWith('-');
  final abs = neg ? s.substring(1) : s;
  final parts = abs.split('.');
  final intPart = parts[0];
  final frac = parts.length > 1 ? parts[1] : null;
  var intOut = intPart;
  if (intPart.length >= 5) {
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(thinSpace);
      buf.write(intPart[i]);
    }
    intOut = buf.toString();
  }
  return '${neg ? '-' : ''}$intOut${frac != null && frac.isNotEmpty ? ',$frac' : ''}';
}

/// Cantidad con su unidad para pantalla: «0,96 ml», «2 %».
String formatQty(String value, String unit) =>
    unit == '%' ? '${formatEs(value)} %' : '${formatEs(value)} $unit'.trim();

class ParsedUserNumber {
  const ParsedUserNumber.ok(String this.value, String this.normalizedDisplay, this.unsafeFormat)
      : ok = true,
        error = null;
  const ParsedUserNumber.error(String this.error)
      : ok = false,
        value = null,
        normalizedDisplay = null,
        unsafeFormat = null;

  final bool ok;

  /// Valor canónico con punto.
  final String? value;

  /// Lo que el usuario escribió, normalizado a coma, para mostrar.
  final String? normalizedDisplay;

  /// Formato inseguro corregido: «,5» → 'missing_leading_zero'; «5,0» → 'trailing_zero'.
  final String? unsafeFormat;

  /// 'empty' | 'invalid' | 'two_separators'.
  final String? error;
}

final _validNumber = RegExp(r'^-?(\d+)?(,\d*)?$');

/// Interpreta una cifra tecleada: acepta coma o punto (el punto se convierte),
/// detecta el formato inseguro y nunca acepta separador de miles.
ParsedUserNumber parseUserNumber(String raw) {
  final s = raw.trim().replaceAll(RegExp('[\\s$thinSpace]'), '');
  if (s.isEmpty) return const ParsedUserNumber.error('empty');
  final norm = s.replaceFirst('.', ',');
  if (','.allMatches(norm).length > 1 || RegExp(r'[.,]').allMatches(s).length > 1) {
    return const ParsedUserNumber.error('two_separators');
  }
  if (!_validNumber.hasMatch(norm) || norm == ',' || norm == '-') {
    return const ParsedUserNumber.error('invalid');
  }
  String? unsafe;
  if (RegExp(r'^-?,').hasMatch(norm)) unsafe = 'missing_leading_zero';
  final commaIdx = norm.indexOf(',');
  final frac = commaIdx >= 0 ? norm.substring(commaIdx + 1) : null;
  if (frac != null && frac.isNotEmpty && frac.endsWith('0')) unsafe ??= 'trailing_zero';
  if (frac != null && frac.isEmpty) unsafe ??= 'trailing_zero';
  var dotted = norm.replaceFirst(',', '.');
  dotted = dotted.replaceFirstMapped(RegExp(r'^(-?)\.'), (m) => '${m[1]}0.');
  dotted = dotted.replaceFirst(RegExp(r'\.$'), '');
  final value = canon(dotted);
  return ParsedUserNumber.ok(value, formatEs(value), unsafe);
}
