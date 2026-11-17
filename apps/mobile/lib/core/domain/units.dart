/// Unidades de medida y análisis dimensional (espejo de `units.ts`).
///
/// Magnitudes base: masa (M, g), volumen (V, ml), tiempo (T, s), gotas (G),
/// unidades internacionales (IU) y recuento (N: tomas, dosis). Una unidad
/// compuesta como «µg/kg/min» se interpreta como µg · kg⁻¹ · min⁻¹.
library;

import 'decimal_es.dart';

/// Magnitudes: masa, volumen, tiempo, gotas, unidades internacionales y recuento.
enum Dim { m, v, t, g, iu, n }

class AtomicUnit {
  const AtomicUnit(this.symbol, this.aliases, this.dims, this.factor);
  final String symbol;
  final List<String> aliases;
  final Map<Dim, int> dims;

  /// Factor a la unidad base de su magnitud, como cadena decimal exacta.
  final String factor;
}

const atomicUnits = <AtomicUnit>[
  AtomicUnit('g', ['gr', 'gramo', 'gramos'], {Dim.m: 1}, '1'),
  AtomicUnit('mg', ['miligramo', 'miligramos'], {Dim.m: 1}, '0.001'),
  AtomicUnit('µg', ['mcg', 'ug', 'μg', 'microgramo', 'microgramos', 'gamma', 'gammas'], {Dim.m: 1}, '0.000001'),
  AtomicUnit('ng', [], {Dim.m: 1}, '0.000000001'),
  AtomicUnit('kg', ['kilo', 'kilos'], {Dim.m: 1}, '1000'),
  AtomicUnit('ml', ['mL', 'cc', 'cm3', 'mililitro', 'mililitros'], {Dim.v: 1}, '1'),
  AtomicUnit('l', ['L', 'litro', 'litros'], {Dim.v: 1}, '1000'),
  AtomicUnit('µl', ['ul', 'μl', 'microlitro', 'microlitros'], {Dim.v: 1}, '0.001'),
  AtomicUnit('s', ['seg', 'segundo', 'segundos'], {Dim.t: 1}, '1'),
  AtomicUnit('min', ['minuto', 'minutos'], {Dim.t: 1}, '60'),
  AtomicUnit('h', ['hora', 'horas'], {Dim.t: 1}, '3600'),
  AtomicUnit('día', ['dia', 'días', 'dias', 'd'], {Dim.t: 1}, '86400'),
  AtomicUnit('gotas', ['gota', 'gt', 'gtt'], {Dim.g: 1}, '1'),
  AtomicUnit('UI', ['U', 'unidades', 'unidad'], {Dim.iu: 1}, '1'),
  AtomicUnit('tomas', ['toma', 'dosis'], {Dim.n: 1}, '1'),
  // Porcentaje masa/volumen: 1 % = 1 g en 100 ml = 0,01 g/ml.
  AtomicUnit('%', ['por ciento'], {Dim.m: 1, Dim.v: -1}, '0.01'),
];

final Map<String, AtomicUnit> _bySymbol = () {
  final m = <String, AtomicUnit>{};
  for (final u in atomicUnits) {
    m[u.symbol] = u;
    for (final a in u.aliases) {
      m[a] = u;
    }
  }
  return m;
}();

typedef DimVec = Map<Dim, int>;

DimVec emptyDims() => {for (final d in Dim.values) d: 0};

class UnitExpr {
  const UnitExpr(this.text, this.dims, this.factor);

  /// Texto original normalizado («µg/kg/min»).
  final String text;
  final DimVec dims;

  /// Factor a unidades base.
  final Rational factor;
}

class UnitError implements Exception {
  UnitError(this.message);
  final String message;
  @override
  String toString() => message;
}

Rational _pow(Rational base, int exp) {
  var r = Rational.one;
  final n = exp.abs();
  for (var i = 0; i < n; i++) {
    r = r * base;
  }
  return exp < 0 ? Rational.one / r : r;
}

final _expRe = RegExp(r'^(.+?)(\^(-?\d+))?$');

/// Interpreta «µg/kg/min», «mg/ml», «gotas/min», «ml/h», «UI/kg», «min/h», «1».
UnitExpr parseUnit(String text) {
  final t = text.trim();
  if (t.isEmpty || t == '1') return UnitExpr('', emptyDims(), Rational.one);
  final dims = emptyDims();
  var factor = Rational.one;
  final parts = t.split('/');
  for (var idx = 0; idx < parts.length; idx++) {
    final sign = idx == 0 ? 1 : -1;
    for (final raw in parts[idx].split(RegExp('[·*×]'))) {
      final sym = raw.trim();
      if (sym.isEmpty) continue;
      final m = _expRe.firstMatch(sym);
      final base = m?.group(1) ?? sym;
      final exp = m?.group(3) != null ? int.parse(m!.group(3)!) : 1;
      final u = _bySymbol[base];
      if (u == null) throw UnitError('Unidad desconocida: «$base»');
      u.dims.forEach((k, v) => dims[k] = dims[k]! + v * exp * sign);
      factor = factor * _pow(dec(u.factor), exp * sign);
    }
  }
  return UnitExpr(t, dims, factor);
}

bool sameDims(DimVec a, DimVec b) => Dim.values.every((k) => (a[k] ?? 0) == (b[k] ?? 0));

bool isDimensionless(DimVec a) => Dim.values.every((k) => (a[k] ?? 0) == 0);

/// Convierte un valor de una unidad a otra de la misma magnitud.
Rational convert(Rational value, String from, String to) {
  final a = parseUnit(from);
  final b = parseUnit(to);
  if (!sameDims(a.dims, b.dims)) throw UnitError('No se puede convertir $from en $to');
  return value * a.factor / b.factor;
}

bool unitsEquivalent(String a, String b) {
  try {
    final x = parseUnit(a);
    final y = parseUnit(b);
    return sameDims(x.dims, y.dims) && x.factor == y.factor;
  } on UnitError {
    return a == b;
  }
}
