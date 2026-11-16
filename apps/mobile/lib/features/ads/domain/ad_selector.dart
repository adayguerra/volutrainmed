/// Pausa promocional con anuncios propios (capacidad house-ads).
///
/// - [PoliticaPausa]: decide si toca pausa (exclusiones y frecuencia).
/// - [SelectorAnuncios]: elige el anuncio según el diseño D10 (vigencia,
///   sector, tope diario, sin repetir el anterior, contextos con prioridad,
///   peso y reserva PA-01).
/// - [ContadorImpresiones]: impresiones por anuncio y día, serializable.
///
/// Inventario local: todo sale del paquete global descargado; ninguna
/// petición de red ni identificador publicitario.
library;

import 'dart:math';

import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import 'ad_variables.dart';

const rotuloPromocion = 'Promoción de VolutrainMed';
const idAnuncioReserva = 'PA-01';

/// Exclusiones y frecuencia de la pausa promocional.
class PoliticaPausa {
  const PoliticaPausa._();

  /// ¿Toca pausa tras cerrar la corrección de un ejercicio?
  ///
  /// [contadorEjercicios] es el número de ejercicios cerrados en la sesión
  /// (1 tras el primero). Con [frecuencia] 1 hay pausa tras cada ejercicio;
  /// con 2, tras el 2.º, el 4.º… En contrarreloj, la única pausa se pide al
  /// terminar el esprint con [enContrarrelojEntreEjercicios] a false.
  static bool debeMostrar({
    required bool sinAnuncios,
    required SessionMode modo,
    required bool esPrimeraLeccion,
    required bool enContrarrelojEntreEjercicios,
    required int contadorEjercicios,
    required int frecuencia,
  }) {
    if (sinAnuncios) return false;
    if (modo == SessionMode.placement) return false;
    if (esPrimeraLeccion) return false;
    final esCrono = modo == SessionMode.timetrial || modo == SessionMode.timetrialUntimed;
    if (esCrono && enContrarrelojEntreEjercicios) return false;
    if (esCrono) return true;
    if (contadorEjercicios <= 0) return false;
    final f = frecuencia < 1 ? 1 : frecuencia;
    return contadorEjercicios % f == 0;
  }
}

/// Impresiones por anuncio en el día local en curso.
class ContadorImpresiones {
  ContadorImpresiones({String? dia, Map<String, int>? cuentas}) : _cuentas = cuentas ?? {} {
    _dia = dia;
  }
  String? _dia;
  final Map<String, int> _cuentas;

  static String claveDia(DateTime t) {
    final d = diaLocal(t);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _alDia(DateTime ahora) {
    final k = claveDia(ahora);
    if (_dia != k) {
      _dia = k;
      _cuentas.clear();
    }
  }

  int hoy(String anuncioId, DateTime ahora) {
    _alDia(ahora);
    return _cuentas[anuncioId] ?? 0;
  }

  void registrar(String anuncioId, DateTime ahora) {
    _alDia(ahora);
    _cuentas[anuncioId] = (_cuentas[anuncioId] ?? 0) + 1;
  }

  Map<String, dynamic> toJson() => {'dia': _dia, 'cuentas': _cuentas};

  factory ContadorImpresiones.fromJson(Map<String, dynamic>? j) => ContadorImpresiones(
        dia: j?['dia'] as String?,
        cuentas: ((j?['cuentas'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as num).toInt())),
      );
}

/// Todo lo que el selector necesita saber del momento de la pausa.
class ContextoAnuncio {
  const ContextoAnuncio({
    required this.ahora,
    required this.impresiones,
    this.sectorId,
    this.anterior,
    this.modoVoz = false,
    this.esperaS = 3,
    this.enLeccion = true,
    this.ejerciciosLeccion = 0,
    this.aciertosLeccion = 0,
    this.pruebaDisponible = false,
    this.limiteManosLibresAgotado = false,
    this.trasSesionManosLibres = false,
    this.rachaDias = 0,
    this.precioMensual,
    this.precioAnual,
    this.preciosObtenidosEn,
    this.unidadCompletada = false,
    this.ultimaPausaLeccion = false,
    this.leccionConFallos = false,
    this.trasContrarreloj = false,
    this.organizacionesActivas = false,
  });

  final DateTime ahora;
  final ContadorImpresiones impresiones;
  final String? sectorId;

  /// Identificador del anuncio de la pausa anterior.
  final String? anterior;
  final bool modoVoz;
  final int esperaS;
  final bool enLeccion;
  final int ejerciciosLeccion;
  final int aciertosLeccion;
  final bool pruebaDisponible;
  final bool limiteManosLibresAgotado;
  final bool trasSesionManosLibres;
  final int rachaDias;
  final String? precioMensual;
  final String? precioAnual;
  final DateTime? preciosObtenidosEn;
  final bool unidadCompletada;
  final bool ultimaPausaLeccion;
  final bool leccionConFallos;
  final bool trasContrarreloj;
  final bool organizacionesActivas;

  /// Precios de la tienda obtenidos en los últimos 7 días.
  bool get preciosFrescos =>
      precioMensual != null &&
      precioAnual != null &&
      preciosObtenidosEn != null &&
      !ahora.difference(preciosObtenidosEn!).isNegative &&
      ahora.difference(preciosObtenidosEn!) <= const Duration(days: 7);

  DatosAnuncio get datos => DatosAnuncio(
        esperaS: esperaS,
        ejercicios: ejerciciosLeccion,
        aciertos: aciertosLeccion,
        dias: rachaDias,
        precioMensual: preciosFrescos ? precioMensual : null,
        precioAnual: preciosFrescos ? precioAnual : null,
      );

  bool cumple(String contexto) => switch (contexto) {
        'always' => true,
        'wait_gt0_in_lesson' => esperaS > 0 && enLeccion,
        'trial_available' => pruebaDisponible,
        'handsfree_limit_or_after_handsfree' => limiteManosLibresAgotado || trasSesionManosLibres,
        'streak_gte_3' => rachaDias >= 3,
        'prices_fresh_7d' => preciosFrescos,
        'after_unit_completed' => unidadCompletada,
        'last_pause_lesson_with_errors' => ultimaPausaLeccion && leccionConFallos,
        'last_pause_lesson_perfect' => ultimaPausaLeccion && !leccionConFallos && ejerciciosLeccion > 0,
        'after_timetrial' => trasContrarreloj,
        'orgs_enabled' => organizacionesActivas,
        _ => false,
      };
}

/// Anuncio elegido con sus textos ya resueltos.
class AnuncioResuelto {
  const AnuncioResuelto({required this.creatividad, required this.titular, required this.texto, required this.accion, this.cuna});
  final AdCreative creatividad;
  final String titular;
  final String texto;

  /// Texto del botón de acción (para trial_or_paywall depende de la prueba).
  final String accion;

  /// Cuña hablada para manos libres, si existe.
  final String? cuna;
  String get id => creatividad.id;

  /// ¿La acción debe abrir directamente la prueba gratuita?
  bool get abrePrueba => creatividad.ctaAction == 'trial' || (creatividad.ctaAction == 'trial_or_paywall' && accion == creatividad.cta);
}

class SelectorAnuncios {
  SelectorAnuncios({required this.campanas, required this.params});
  final List<AdCampaign> campanas;
  final AdParams params;

  bool _vigente(AdCampaign c, DateTime ahora) =>
      (c.startsAt == null || !ahora.isBefore(c.startsAt!)) && (c.endsAt == null || ahora.isBefore(c.endsAt!));

  bool _sector(AdCampaign c, String? sectorId) =>
      c.sectorIds == null || c.sectorIds!.isEmpty || (sectorId != null && c.sectorIds!.contains(sectorId));

  int? topeDiario(AdCreative a) => a.dailyCap ?? (a.kind == 'fallback' ? null : params.defaultDailyCap);

  bool _bajoTope(AdCreative a, ContextoAnuncio ctx) {
    final tope = topeDiario(a);
    return tope == null || ctx.impresiones.hoy(a.id, ctx.ahora) < tope;
  }

  bool _necesitaPrecios(AdCreative a) =>
      necesitaPrecios(a.headline) || necesitaPrecios(a.body) || necesitaPrecios(a.voiceSpot ?? '');

  /// Creatividades que pasan los filtros comunes (paso 1 de D10).
  List<AdCreative> elegibles(ContextoAnuncio ctx) => [
        for (final c in campanas)
          if (_vigente(c, ctx.ahora) && _sector(c, ctx.sectorId))
            for (final a in c.creatives)
              if (a.id != ctx.anterior &&
                  _bajoTope(a, ctx) &&
                  (!ctx.modoVoz || (a.voiceSpot != null && a.voiceSpot!.isNotEmpty)) &&
                  (!_necesitaPrecios(a) || ctx.preciosFrescos))
                a,
      ];

  AdCreative? _porPeso(List<AdCreative> lista, Random rnd) {
    if (lista.isEmpty) return null;
    final total = lista.fold<int>(0, (s, a) => s + (a.weight < 1 ? 1 : a.weight));
    var r = rnd.nextInt(total);
    for (final a in lista) {
      final w = a.weight < 1 ? 1 : a.weight;
      if (r < w) return a;
      r -= w;
    }
    return lista.last;
  }

  AdCreative? _reserva() {
    for (final c in campanas) {
      for (final a in c.creatives) {
        if (a.id == idAnuncioReserva) return a;
      }
    }
    for (final c in campanas) {
      for (final a in c.creatives) {
        if (a.kind == 'fallback') return a;
      }
    }
    return null;
  }

  /// Elige la creatividad (sin resolver textos). Null solo si el paquete no
  /// trae ningún anuncio.
  AdCreative? elegirCreatividad(ContextoAnuncio ctx, Random rnd) {
    final base = elegibles(ctx);
    final contextuales = base.where((a) => a.kind == 'contextual' && ctx.cumple(a.context)).toList();
    final elegida = _porPeso(contextuales, rnd) ??
        _porPeso(base.where((a) => (a.kind == 'generic' || a.kind == 'fallback') && ctx.cumple(a.context)).toList(), rnd);
    return elegida ?? _reserva();
  }

  /// Elige y resuelve el anuncio de esta pausa.
  AnuncioResuelto? elegir(ContextoAnuncio ctx, Random rnd) {
    final a = elegirCreatividad(ctx, rnd);
    if (a == null) return null;
    return resolver(a, ctx);
  }

  AnuncioResuelto resolver(AdCreative a, ContextoAnuncio ctx) {
    final d = ctx.datos;
    final accion = a.ctaAction == 'trial_or_paywall' && !ctx.pruebaDisponible ? (a.ctaAlt ?? a.cta) : a.cta;
    return AnuncioResuelto(
      creatividad: a,
      titular: resolverVariables(a.headline, d),
      texto: resolverVariables(a.body, d),
      accion: accion,
      cuna: a.voiceSpot == null ? null : resolverVariables(a.voiceSpot!, d),
    );
  }
}
