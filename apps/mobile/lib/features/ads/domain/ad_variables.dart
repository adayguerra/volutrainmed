/// Resolutor de variables de los anuncios propios (diseño D8 de
/// add-house-ads-and-premium): las cifras salen de la configuración vigente y
/// de los datos reales del usuario, nunca se escriben a mano.
///
/// Aritmética exacta con el paquete `decimal`; los precios nunca son `double`.
library;

import 'package:decimal/decimal.dart';

/// Variables que dependen de los precios de la tienda.
const variablesDePrecio = {'{equivalente_mes}', '{ahorro_pct}'};

bool necesitaPrecios(String texto) => variablesDePrecio.any(texto.contains);

/// Datos reales con los que se rellenan los textos.
class DatosAnuncio {
  const DatosAnuncio({
    required this.esperaS,
    this.ejercicios = 0,
    this.aciertos = 0,
    this.dias = 0,
    this.precioMensual,
    this.precioAnual,
  });
  final int esperaS;

  /// Ejercicios de la lección en curso.
  final int ejercicios;

  /// Aciertos al primer intento en la lección.
  final int aciertos;

  /// Días de la racha actual.
  final int dias;

  /// Precios de la tienda como cadenas decimales con punto («6.99»).
  final String? precioMensual;
  final String? precioAnual;

  bool get hayPrecios => precioMensual != null && precioAnual != null;
}

String _coma(String s) => s.replaceAll('.', ',');

/// Precio anual ÷ 12 con dos decimales y coma: 39,99 → «3,33».
String equivalenteMes(String precioAnual) {
  final r = (Decimal.parse(precioAnual) / Decimal.fromInt(12)).toDecimal(scaleOnInfinitePrecision: 12);
  return _coma(r.round(scale: 2).toStringAsFixed(2));
}

/// (1 − anual ÷ (12 × mensual)) × 100, sin decimales: 6,99 y 39,99 → «52».
String ahorroPct(String precioMensual, String precioAnual) {
  final anual = Decimal.parse(precioAnual);
  final doceMeses = Decimal.parse(precioMensual) * Decimal.fromInt(12);
  final pct = ((doceMeses - anual) * Decimal.fromInt(100)) / doceMeses;
  return pct.round().toString();
}

/// Sustituye las variables conocidas. Si falta un dato de precio, la variable
/// queda sin resolver (el selector ya excluye esos anuncios).
String resolverVariables(String texto, DatosAnuncio d) {
  var out = texto
      .replaceAll('{espera_s}', '${d.esperaS}')
      .replaceAll('{ejercicios}', '${d.ejercicios}')
      .replaceAll('{total_s}', '${d.esperaS * d.ejercicios}')
      .replaceAll('{aciertos}', '${d.aciertos}')
      .replaceAll('{dias}', '${d.dias}');
  if (d.hayPrecios) {
    out = out
        .replaceAll('{equivalente_mes}', equivalenteMes(d.precioAnual!))
        .replaceAll('{ahorro_pct}', ahorroPct(d.precioMensual!, d.precioAnual!));
  }
  return out;
}
