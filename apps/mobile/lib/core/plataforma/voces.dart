/// Elección de la voz de lectura (síntesis en el dispositivo).
///
/// La voz por defecto del sistema suele ser la «compacta», que suena metálica.
/// Aquí se ordenan las voces instaladas en español para elegir la de mejor
/// calidad que funcione sin red, y el usuario puede cambiarla en Ajustes › Voz.
library;

class VozSistema {
  const VozSistema({required this.nombre, required this.locale, this.calidad = '', this.requiereRed = false, this.genero = ''});

  factory VozSistema.deMapa(Map<Object?, Object?> m) {
    final nombre = '${m['name'] ?? ''}';
    final locale = '${m['locale'] ?? ''}'.replaceAll('_', '-');
    final red = '${m['network_required'] ?? ''}' == '1' || m['network_required'] == true || nombre.toLowerCase().contains('network') ||
        // Las voces «Google …» de Chrome se sintetizan en servidores de Google.
        nombre.startsWith('Google ');
    return VozSistema(nombre: nombre, locale: locale, calidad: '${m['quality'] ?? ''}'.toLowerCase(), requiereRed: red, genero: '${m['gender'] ?? ''}');
  }

  final String nombre;
  final String locale;

  /// iOS y macOS: `default`, `enhanced`, `premium`. Android: `very high`, `high`, `normal`, `low`.
  final String calidad;
  final bool requiereRed;
  final String genero;

  bool get esEspanol => locale.toLowerCase().startsWith('es');
  bool get esDeEspana => locale.toLowerCase() == 'es-es';

  /// Nombre legible: «Mónica (mejorada)», «Google español».
  String get etiqueta {
    final base = nombre.replaceAll(RegExp(r'\s*\((Enhanced|Premium|Mejorada|Prémium|Spanish \([^)]*\))\)', caseSensitive: false), '').trim();
    final c = switch (nivelCalidad) { 3 => ' · calidad máxima', 2 => ' · calidad alta', _ => '' };
    final zona = esDeEspana ? '' : ' · $locale';
    return '${base.isEmpty ? locale : base}$c$zona';
  }

  /// 3 = neuronal o «premium», 2 = mejorada, 1 = normal, 0 = compacta o novedad.
  int get nivelCalidad {
    final n = nombre.toLowerCase();
    if (_novedades.any(n.contains)) return 0;
    if (calidad.contains('premium') || calidad.contains('very high') || n.contains('premium') || n.contains('neural') || n.contains('natural') || n.contains('siri')) return 3;
    if (calidad.contains('enhanced') || calidad == 'high' || n.contains('enhanced') || n.contains('mejorada') || n.contains('google') || n.contains('microsoft')) return 2;
    if (n.contains('compact') || n.contains('espeak') || calidad == 'low') return 0;
    return 1;
  }

  static const _novedades = ['eddy', 'flo', 'grandma', 'grandpa', 'reed', 'rocko', 'sandy', 'shelley', 'bad news', 'bells', 'boing', 'bubbles', 'cellos', 'jester', 'organ', 'superstar', 'trinoids', 'whisper', 'wobble', 'zarvox', 'albert', 'fred', 'junior', 'ralph', 'kathy'];
}

/// Puntuación de una voz para leer casos en español de España. Las voces que
/// necesitan red no se eligen nunca: la lectura tiene que funcionar sin conexión.
int puntuarVoz(VozSistema v) {
  if (!v.esEspanol || v.requiereRed) return -1;
  return v.nivelCalidad * 10 + (v.esDeEspana ? 12 : 0);
}

/// Voces en español utilizables, de mejor a peor.
List<VozSistema> vocesEnEspanol(Iterable<VozSistema> voces) {
  final vistas = <String>{};
  var l = voces.where((v) => puntuarVoz(v) >= 0 && vistas.add('${v.nombre}|${v.locale}')).toList();
  // Las voces de novedad y las compactas solo se ofrecen si no hay otra.
  if (l.any((v) => v.nivelCalidad > 0)) l = l.where((v) => v.nivelCalidad > 0).toList();
  l.sort((a, b) {
    final d = puntuarVoz(b) - puntuarVoz(a);
    return d != 0 ? d : a.nombre.compareTo(b.nombre);
  });
  return l;
}

/// La voz [preferida] si sigue instalada; si no, la mejor disponible.
VozSistema? elegirVoz(Iterable<VozSistema> voces, {String? preferida}) {
  final l = vocesEnEspanol(voces);
  if (l.isEmpty) return null;
  if (preferida != null) {
    for (final v in l) {
      if (v.nombre == preferida) return v;
    }
  }
  return l.first;
}

/// Parte un texto en frases para que la voz respire entre el caso y la pregunta.
List<String> frasesParaLeer(String texto) {
  final t = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return const [];
  final partes = <String>[];
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    b.write(t[i]);
    final fin = '.?!:;'.contains(t[i]) && (i + 1 == t.length || t[i + 1] == ' ');
    if (fin) {
      partes.add(b.toString().trim());
      b.clear();
    }
  }
  if (b.toString().trim().isNotEmpty) partes.add(b.toString().trim());
  return partes;
}
