/// Prueba de nivel adaptativa y reanudable (capacidad onboarding-account).
///
/// - Parte de la unidad que corresponde al nivel declarado ('cero' → 1.ª,
///   'afianzar' → 2.ª, 'agilidad' → 3.ª).
/// - Pregunta 2 ítems por unidad, tomados de `ItineraryPackage.placement`.
/// - Sube mientras acierta los dos; tras el primer fallo deja de subir y baja
///   desde la unidad inicial − 1 para comprobar las anteriores.
/// - Si aún no llega a 8 ítems y quedan unidades sin comprobar por encima,
///   sigue con ellas. Nunca pasa de 12 ítems.
/// - «No lo sé» cuenta como fallo. No se corrige durante la prueba: el
///   llamador solo informa de si la respuesta fue correcta.
///
/// Todo el estado es serializable a JSON para reanudar en la misma pregunta.
library;

import '../../../core/domain/content_models.dart';

const minimoItemsPrueba = 8;
const maximoItemsPrueba = 12;
const itemsPorUnidad = 2;

int unidadInicialPorNivel(String? nivelDeclarado, int numUnidades) {
  final i = switch (nivelDeclarado) { 'afianzar' => 1, 'agilidad' => 2, _ => 0 };
  if (numUnidades <= 0) return 0;
  return i.clamp(0, numUnidades - 1);
}

class ResultadoPrueba {
  const ResultadoPrueba({required this.unidadesConvalidadas, required this.unidadEntrada, required this.itemsRespondidos, this.omitida = false});

  /// Ids de unidades convalidadas, en orden de la ruta.
  final List<String> unidadesConvalidadas;

  /// Primera unidad no convalidada; null si todas están convalidadas.
  final String? unidadEntrada;
  final int itemsRespondidos;
  final bool omitida;
}

class PruebaNivel {
  PruebaNivel._({
    required this.unidades,
    required this.items,
    required this.inicio,
    required this.respuestas,
    required this.unidadActual,
    required this.fase,
    required this.preguntadas,
    required this.terminada,
  });

  /// Ids de unidades en orden de la ruta.
  final List<String> unidades;

  /// Ítems (ids de variante) de cada unidad, como mucho [itemsPorUnidad].
  final Map<String, List<String>> items;
  final int inicio;

  /// Respuestas registradas por unidad (true = acierto).
  final Map<String, List<bool>> respuestas;
  int? unidadActual;

  /// 'sube', 'baja' o 'relleno'.
  String fase;

  /// Unidades ya comprobadas (índices), en orden de pregunta.
  final List<int> preguntadas;
  bool terminada;

  factory PruebaNivel.iniciar(ItineraryPackage pkg, String? nivelDeclarado) {
    final unidades = pkg.units.map((u) => u.id).toList();
    final items = <String, List<String>>{
      for (final p in pkg.placement) p.unitId: p.variantIds.take(itemsPorUnidad).toList(),
    };
    final inicio = unidadInicialPorNivel(nivelDeclarado, unidades.length);
    final prueba = PruebaNivel._(
      unidades: unidades,
      items: items,
      inicio: inicio,
      respuestas: {},
      unidadActual: null,
      fase: 'sube',
      preguntadas: [],
      terminada: false,
    );
    prueba._avanzarUnidad(primera: true);
    return prueba;
  }

  /// Resultado de elegir «Empezar por el principio».
  static ResultadoPrueba omitir(ItineraryPackage pkg) => ResultadoPrueba(
        unidadesConvalidadas: const [],
        unidadEntrada: pkg.units.isEmpty ? null : pkg.units.first.id,
        itemsRespondidos: 0,
        omitida: true,
      );

  int get itemsRespondidos => respuestas.values.fold(0, (a, l) => a + l.length);

  int get totalItemsDisponibles => unidades.fold(0, (a, u) => a + (items[u]?.length ?? 0));

  /// Máximo anunciado al usuario: «Pregunta 4 de 10, como máximo».
  int get maximo => totalItemsDisponibles < maximoItemsPrueba ? totalItemsDisponibles : maximoItemsPrueba;

  /// Número de la pregunta actual (1…).
  int get numeroPregunta => itemsRespondidos + 1;

  String? get unidadIdActual => unidadActual == null ? null : unidades[unidadActual!];

  /// Variante que hay que presentar ahora, o null si la prueba ha terminado.
  String? get varianteActual {
    if (terminada || unidadActual == null) return null;
    final u = unidades[unidadActual!];
    final hechas = respuestas[u]?.length ?? 0;
    final lista = items[u] ?? const [];
    return hechas < lista.length ? lista[hechas] : null;
  }

  /// Registra la respuesta a la pregunta actual. «No lo sé» = `correcto: false`.
  void responder({required bool correcto}) {
    if (terminada || unidadActual == null) return;
    final u = unidades[unidadActual!];
    (respuestas[u] ??= []).add(correcto);
    if (itemsRespondidos >= maximoItemsPrueba) {
      terminada = true;
      unidadActual = null;
      return;
    }
    if (respuestas[u]!.length >= (items[u]?.length ?? 0)) {
      final superada = respuestas[u]!.every((x) => x);
      if (fase == 'sube' && !superada) fase = 'baja';
      _avanzarUnidad();
    }
  }

  bool _probable(int i) => !preguntadas.contains(i) && (items[unidades[i]]?.isNotEmpty ?? false);

  void _avanzarUnidad({bool primera = false}) {
    int? siguiente;
    if (primera) {
      siguiente = _primeraProbableDesde(inicio, 1);
    } else {
      if (fase == 'sube') {
        siguiente = _primeraProbableDesde(unidadActual! + 1, 1);
        if (siguiente == null) fase = 'baja';
      }
      if (fase == 'baja') {
        siguiente = _primeraProbableDesde(inicio - 1, -1);
        if (siguiente == null) fase = 'relleno';
      }
      if (fase == 'relleno') {
        siguiente = itemsRespondidos < minimoItemsPrueba ? _primeraProbableDesde(0, 1) : null;
      }
    }
    if (siguiente == null) {
      terminada = true;
      unidadActual = null;
    } else {
      unidadActual = siguiente;
      preguntadas.add(siguiente);
    }
  }

  int? _primeraProbableDesde(int desde, int paso) {
    for (var i = desde; i >= 0 && i < unidades.length; i += paso) {
      if (_probable(i)) return i;
    }
    return null;
  }

  ResultadoPrueba resultado() {
    final convalidadas = <String>[];
    for (final u in unidades) {
      final r = respuestas[u];
      final n = items[u]?.length ?? 0;
      if (r == null || n == 0 || r.length < n || !r.every((x) => x)) break;
      convalidadas.add(u);
    }
    final entrada = convalidadas.length < unidades.length ? unidades[convalidadas.length] : null;
    return ResultadoPrueba(unidadesConvalidadas: convalidadas, unidadEntrada: entrada, itemsRespondidos: itemsRespondidos);
  }

  Map<String, dynamic> toJson() => {
        'unidades': unidades,
        'items': items,
        'inicio': inicio,
        'respuestas': respuestas,
        'unidadActual': unidadActual,
        'fase': fase,
        'preguntadas': preguntadas,
        'terminada': terminada,
      };

  factory PruebaNivel.fromJson(Map<String, dynamic> j) => PruebaNivel._(
        unidades: (j['unidades'] as List).map((e) => '$e').toList(),
        items: ((j['items'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as List).map((e) => '$e').toList())),
        inicio: (j['inicio'] as num?)?.toInt() ?? 0,
        respuestas: ((j['respuestas'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as List).map((e) => e == true).toList())),
        unidadActual: (j['unidadActual'] as num?)?.toInt(),
        fase: '${j['fase'] ?? 'sube'}',
        preguntadas: ((j['preguntadas'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
        terminada: j['terminada'] == true,
      );
}
