/// Proyecciones de progreso recalculadas desde intentos y sesiones (D5).
///
/// Todo se deriva de lo que se sincroniza (intentos y sesiones), de modo que
/// un dispositivo nuevo o dos dispositivos fusionados obtienen el mismo
/// resultado: estados de habilidad, progreso de lección, estados de unidad,
/// racha, puntos, nivel, logros y estadísticas.
///
/// Decisiones:
/// - Los estados «consolidada» y «dominada» exigen al menos 20 primeros
///   intentos de la habilidad (la ventana de «los últimos 20»). Con menos, la
///   habilidad queda «en aprendizaje».
/// - «Repartidos en 7 o más días»: entre el primer y el último día de la
///   ventana hay al menos 6 días de diferencia (siete días naturales).
/// - La fecha de los logros de habilidades y unidades dominadas es la del
///   último intento (se evalúan al final de la reproducción).
library;

import 'dart:math' as math;

import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import '../../review/domain/review_projection.dart';

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

List<SessionRecord> ordenarSesiones(Iterable<SessionRecord> sesiones) {
  final porId = <String, SessionRecord>{};
  for (final s in sesiones) {
    porId.putIfAbsent(s.id, () => s);
  }
  return porId.values.toList()
    ..sort((a, b) {
      final c = a.startedAt.compareTo(b.startedAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
}

/// Primeros intentos que cuentan para el dominio (sin prueba de nivel).
bool cuentaParaDominio(Attempt a) => a.attemptNumber == 1 && a.mode != SessionMode.placement;

bool _esRepaso(SessionMode m) => m == SessionMode.review || m == SessionMode.warmup;

double mediana(List<num> v) {
  if (v.isEmpty) return 0;
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

String porcentaje(double r) => '${(r * 100).round()} %';

const _numerosEnLetra = {
  1: 'una',
  2: 'dos',
  3: 'tres',
  4: 'cuatro',
  5: 'cinco',
  6: 'seis',
  7: 'siete',
  8: 'ocho',
  9: 'nueve',
  10: 'diez',
  11: 'once',
  12: 'doce',
};

String _enLetra(int n) => _numerosEnLetra[n] ?? '$n';

// ---------------------------------------------------------------------------
// Estados de habilidad
// ---------------------------------------------------------------------------

enum EstadoHabilidad { nueva, enAprendizaje, consolidada, dominada, porRefrescar }

extension EstadoHabilidadEtiqueta on EstadoHabilidad {
  String get etiqueta => switch (this) {
        EstadoHabilidad.nueva => 'Nueva',
        EstadoHabilidad.enAprendizaje => 'En aprendizaje',
        EstadoHabilidad.consolidada => 'Consolidada',
        EstadoHabilidad.dominada => 'Dominada',
        EstadoHabilidad.porRefrescar => 'Por refrescar',
      };

  /// Abre el contrarreloj (time-trial).
  bool get abreContrarreloj =>
      this == EstadoHabilidad.consolidada || this == EstadoHabilidad.dominada || this == EstadoHabilidad.porRefrescar;
}

class EstadoHabilidadInfo {
  const EstadoHabilidadInfo({
    required this.skillId,
    required this.estado,
    required this.intentos,
    required this.precisionUltimos20,
    required this.medianaMs,
    required this.medianaObjetivoMs,
    required this.diasDistintos,
  });
  final String skillId;
  final EstadoHabilidad estado;

  /// Primeros intentos que cuentan para el dominio.
  final int intentos;
  final double precisionUltimos20;
  final double medianaMs;
  final double medianaObjetivoMs;
  final int diasDistintos;
}

const ventanaDominio = 20;

EstadoHabilidad _estadoBase(List<Attempt> ventana) {
  if (ventana.isEmpty) return EstadoHabilidad.nueva;
  if (ventana.length < ventanaDominio) return EstadoHabilidad.enAprendizaje;
  final ultimos = ventana.sublist(ventana.length - ventanaDominio);
  final aciertos = ultimos.where((a) => a.correct).length / ultimos.length;
  final dias = ultimos.map((a) => diaLocal(a.deviceTime)).toSet().toList()..sort();
  final reparto = dias.length < 2 ? 0 : diasEntre(dias.first, dias.last);
  final sinCriticos = ultimos.every((a) => !a.critical);
  final enObjetivo =
      mediana(ultimos.map((a) => a.responseMs).toList()) <= mediana(ultimos.map((a) => a.targetMs).toList());
  if (aciertos >= 0.95 && dias.length >= 3 && reparto >= 6 && sinCriticos && enObjetivo) {
    return EstadoHabilidad.dominada;
  }
  if (aciertos >= 0.85 && dias.length >= 2) return EstadoHabilidad.consolidada;
  return EstadoHabilidad.enAprendizaje;
}

Map<String, EstadoHabilidadInfo> proyectarHabilidades(
  List<Attempt> ordenados,
  Map<String, FichaRepaso> fichas,
  DateTime now, {
  Iterable<String> habilidadesConocidas = const [],
}) {
  final porSkill = <String, List<Attempt>>{};
  for (final a in ordenados.where(cuentaParaDominio)) {
    porSkill.putIfAbsent(a.skillId, () => []).add(a);
  }
  final out = <String, EstadoHabilidadInfo>{};
  for (final id in habilidadesConocidas) {
    out[id] = EstadoHabilidadInfo(
      skillId: id,
      estado: EstadoHabilidad.nueva,
      intentos: 0,
      precisionUltimos20: 0,
      medianaMs: 0,
      medianaObjetivoMs: 0,
      diasDistintos: 0,
    );
  }
  porSkill.forEach((skill, lista) {
    var fueDominada = false;
    var refrescar = false;
    var recuperada = false;
    var seguidas = 0;
    var base = EstadoHabilidad.nueva;
    final ventana = <Attempt>[];
    for (final a in lista) {
      ventana.add(a);
      if (refrescar) {
        if (_esRepaso(a.mode)) {
          seguidas = a.correct ? seguidas + 1 : 0;
          if (seguidas >= 3) {
            refrescar = false;
            recuperada = true;
          }
        }
      } else if (fueDominada && _esRepaso(a.mode) && !a.correct) {
        refrescar = true;
        recuperada = false;
        seguidas = 0;
      }
      base = _estadoBase(ventana);
      if (base == EstadoHabilidad.dominada) fueDominada = true;
    }
    if (fueDominada && !refrescar) {
      final vencidaLarga = fichas.values.any((f) => f.skillId == skill && f.vencida(now) && diasEntre(f.vence, now) > 14);
      if (vencidaLarga) {
        refrescar = true;
        recuperada = false;
      }
    }
    final estado = refrescar
        ? EstadoHabilidad.porRefrescar
        : (recuperada && base != EstadoHabilidad.dominada ? EstadoHabilidad.dominada : base);
    final ultimos = lista.length > ventanaDominio ? lista.sublist(lista.length - ventanaDominio) : lista;
    out[skill] = EstadoHabilidadInfo(
      skillId: skill,
      estado: estado,
      intentos: lista.length,
      precisionUltimos20: ultimos.isEmpty ? 0 : ultimos.where((a) => a.correct).length / ultimos.length,
      medianaMs: mediana(ultimos.map((a) => a.responseMs).toList()),
      medianaObjetivoMs: mediana(ultimos.map((a) => a.targetMs).toList()),
      diasDistintos: ultimos.map((a) => diaLocal(a.deviceTime)).toSet().length,
    );
  });
  return out;
}

class CambioEstado {
  const CambioEstado(this.skillId, this.de, this.a);
  final String skillId;
  final EstadoHabilidad de;
  final EstadoHabilidad a;
  @override
  bool operator ==(Object other) => other is CambioEstado && other.skillId == skillId && other.de == de && other.a == a;
  @override
  int get hashCode => Object.hash(skillId, de, a);
  @override
  String toString() => '$skillId: ${de.etiqueta} → ${a.etiqueta}';
}

/// Habilidades que cambian de estado entre dos proyecciones (fin de lección).
List<CambioEstado> cambiosDeEstado(Map<String, EstadoHabilidad> antes, Map<String, EstadoHabilidad> despues) {
  final out = <CambioEstado>[];
  final claves = {...antes.keys, ...despues.keys}.toList()..sort();
  for (final k in claves) {
    final de = antes[k] ?? EstadoHabilidad.nueva;
    final a = despues[k] ?? EstadoHabilidad.nueva;
    if (de != a) out.add(CambioEstado(k, de, a));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Lecciones y unidades
// ---------------------------------------------------------------------------

class ProgresoLeccion {
  const ProgresoLeccion({required this.lessonId, required this.completada, this.mejorPrecision, this.fecha, this.veces = 0});
  final String lessonId;
  final bool completada;
  final double? mejorPrecision;
  final DateTime? fecha;
  final int veces;
}

enum EstadoUnidad { bloqueada, disponible, enCurso, superada, dominada, porRefrescar }

extension EstadoUnidadEtiqueta on EstadoUnidad {
  String get etiqueta => switch (this) {
        EstadoUnidad.bloqueada => 'Bloqueada',
        EstadoUnidad.disponible => 'Disponible',
        EstadoUnidad.enCurso => 'En curso',
        EstadoUnidad.superada => 'Superada',
        EstadoUnidad.dominada => 'Dominada',
        EstadoUnidad.porRefrescar => 'Por refrescar',
      };

  bool get superadaOMas =>
      this == EstadoUnidad.superada || this == EstadoUnidad.dominada || this == EstadoUnidad.porRefrescar;
}

enum EstadoLeccion { bloqueada, disponible, completada, convalidada }

extension EstadoLeccionEtiqueta on EstadoLeccion {
  String get etiqueta => switch (this) {
        EstadoLeccion.bloqueada => 'Bloqueada',
        EstadoLeccion.disponible => 'Disponible',
        EstadoLeccion.completada => 'Superada',
        EstadoLeccion.convalidada => 'Convalidada',
      };

  bool get hecha => this == EstadoLeccion.completada || this == EstadoLeccion.convalidada;
}

/// Regla del reto de unidad: 10 ejercicios, 9 aciertos o más y ningún crítico.
bool retoSuperado(List<Attempt> primerosIntentos) {
  final diez = primerosIntentos.take(10).toList();
  if (diez.length < 10) return false;
  return diez.where((a) => a.correct).length >= 9 && diez.every((a) => !a.critical);
}

class InfoUnidad {
  const InfoUnidad({
    required this.unit,
    required this.estado,
    required this.leccionesHechas,
    required this.leccionesTotales,
    required this.convalidada,
    required this.retoSuperado,
  });
  final Unit unit;
  final EstadoUnidad estado;
  final int leccionesHechas;
  final int leccionesTotales;
  final bool convalidada;
  final bool retoSuperado;
}

// ---------------------------------------------------------------------------
// Racha y meta
// ---------------------------------------------------------------------------

class RachaInfo {
  const RachaInfo({
    required this.tipo,
    required this.actual,
    required this.mejor,
    this.ultimoCumplido,
    this.aviso,
    required this.metaCumplidaHoy,
    required this.progresoHoy,
    required this.objetivo,
    required this.minutosHoy,
    required this.diasSemana,
  });

  final GoalKind tipo;

  /// Días (o semanas) seguidos con la meta cumplida.
  final int actual;
  final int mejor;
  final DateTime? ultimoCumplido;

  /// «Tu racha se quedó en 12 días. Hoy empieza otra».
  final String? aviso;

  /// Meta del periodo actual cumplida (hoy o esta semana).
  final bool metaCumplidaHoy;

  /// Progreso de la meta actual en minutos o días (según [tipo]).
  final double progresoHoy;
  final int objetivo;
  final double minutosHoy;
  final int diasSemana;

  double get fraccion => objetivo <= 0 ? 0 : (progresoHoy / objetivo).clamp(0, 1).toDouble();
}

/// Minutos de práctica por día local. Solo cuenta `practiceMs`: el tiempo de
/// las pausas promocionales (`adMs`) nunca suma a la meta (house-ads D7).
Map<DateTime, int> practicaPorDia(Iterable<SessionRecord> sesiones) {
  final out = <DateTime, int>{};
  for (final s in sesiones) {
    if (s.practiceMs <= 0) continue;
    final d = diaLocal(s.startedAt);
    out[d] = (out[d] ?? 0) + s.practiceMs;
  }
  return out;
}

RachaInfo proyectarRacha(List<SessionRecord> sesiones, Goal? goal, DateTime now) {
  final meta = goal ?? const Goal.daily(5);
  final porDia = practicaPorDia(sesiones);
  final hoy = diaLocal(now);
  final msHoy = porDia[hoy] ?? 0;
  if (meta.kind == GoalKind.daily) {
    final objetivoMs = (meta.minutes ?? 5) * 60000;
    final cumplidos = porDia.entries.where((e) => e.value >= objetivoMs).map((e) => e.key).toSet();
    final ordenados = cumplidos.toList()..sort();
    // Mejor racha.
    var mejor = 0;
    var corriente = 0;
    DateTime? previo;
    for (final d in ordenados) {
      corriente = (previo != null && diasEntre(previo, d) == 1) ? corriente + 1 : 1;
      if (corriente > mejor) mejor = corriente;
      previo = d;
    }
    int rachaHasta(DateTime fin) {
      var n = 0;
      var d = fin;
      while (cumplidos.contains(d)) {
        n++;
        d = DateTime(d.year, d.month, d.day - 1);
      }
      return n;
    }

    final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
    final actual = cumplidos.contains(hoy) ? rachaHasta(hoy) : rachaHasta(ayer);
    final anteriores = ordenados.where((d) => d.isBefore(hoy)).toList();
    String? aviso;
    if (anteriores.isNotEmpty && diasEntre(anteriores.last, hoy) >= 2) {
      final n = rachaHasta(anteriores.last);
      aviso = 'Tu racha se quedó en $n ${n == 1 ? 'día' : 'días'}. Hoy empieza otra';
    }
    return RachaInfo(
      tipo: GoalKind.daily,
      actual: actual,
      mejor: mejor,
      ultimoCumplido: ordenados.isEmpty ? null : ordenados.last,
      aviso: aviso,
      metaCumplidaHoy: msHoy >= objetivoMs,
      progresoHoy: msHoy / 60000,
      objetivo: meta.minutes ?? 5,
      minutosHoy: msHoy / 60000,
      diasSemana: porDia.keys.where((d) => lunesDe(d) == lunesDe(now)).length,
    );
  }
  // Meta semanal: días con práctica en la semana de lunes a domingo.
  final objetivoDias = meta.days ?? 4;
  final diasPorSemana = <DateTime, int>{};
  for (final d in porDia.keys) {
    final l = lunesDe(d);
    diasPorSemana[l] = (diasPorSemana[l] ?? 0) + 1;
  }
  final cumplidas = diasPorSemana.entries.where((e) => e.value >= objetivoDias).map((e) => e.key).toSet();
  final ordenadas = cumplidas.toList()..sort();
  DateTime semanaAntes(DateTime l) => DateTime(l.year, l.month, l.day - 7);
  var mejor = 0;
  var corriente = 0;
  DateTime? previa;
  for (final l in ordenadas) {
    corriente = (previa != null && semanaAntes(l) == previa) ? corriente + 1 : 1;
    if (corriente > mejor) mejor = corriente;
    previa = l;
  }
  int rachaHasta(DateTime fin) {
    var n = 0;
    var l = fin;
    while (cumplidas.contains(l)) {
      n++;
      l = semanaAntes(l);
    }
    return n;
  }

  final esta = lunesDe(now);
  final actual = cumplidas.contains(esta) ? rachaHasta(esta) : rachaHasta(semanaAntes(esta));
  final anteriores = ordenadas.where((l) => l.isBefore(esta)).toList();
  String? aviso;
  if (anteriores.isNotEmpty && anteriores.last.isBefore(semanaAntes(esta))) {
    final n = rachaHasta(anteriores.last);
    aviso = 'Tu racha se quedó en $n ${n == 1 ? 'semana' : 'semanas'}. Hoy empieza otra';
  }
  final diasEsta = diasPorSemana[esta] ?? 0;
  return RachaInfo(
    tipo: GoalKind.weekly,
    actual: actual,
    mejor: mejor,
    ultimoCumplido: ordenadas.isEmpty ? null : ordenadas.last,
    aviso: aviso,
    metaCumplidaHoy: diasEsta >= objetivoDias,
    progresoHoy: diasEsta.toDouble(),
    objetivo: objetivoDias,
    minutosHoy: msHoy / 60000,
    diasSemana: diasEsta,
  );
}

// ---------------------------------------------------------------------------
// Puntos y niveles
// ---------------------------------------------------------------------------

/// Umbrales de puntos de cada nivel (nivel 1 desde 0 puntos).
const umbralesNivel = <int>[0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000, 5000, 6200, 7600, 9200, 11000];

class NivelInfo {
  const NivelInfo({required this.nivel, required this.desde, required this.hasta, required this.puntos});
  final int nivel;
  final int desde;

  /// Umbral del nivel siguiente (null en el nivel máximo).
  final int? hasta;
  final int puntos;
  double get progreso => hasta == null ? 1 : ((puntos - desde) / (hasta! - desde)).clamp(0, 1).toDouble();
}

NivelInfo nivelPorPuntos(int puntos) {
  var nivel = 1;
  for (var i = 0; i < umbralesNivel.length; i++) {
    if (puntos >= umbralesNivel[i]) nivel = i + 1;
  }
  return NivelInfo(
    nivel: nivel,
    desde: umbralesNivel[nivel - 1],
    hasta: nivel < umbralesNivel.length ? umbralesNivel[nivel] : null,
    puntos: puntos,
  );
}

// ---------------------------------------------------------------------------
// Logros
// ---------------------------------------------------------------------------

class LogroEstado {
  const LogroEstado({required this.logro, required this.obtenido, this.fecha, required this.progreso, required this.valor});
  final Achievement logro;
  final bool obtenido;
  final DateTime? fecha;
  final double progreso;
  final int valor;
}

// ---------------------------------------------------------------------------
// Estadísticas
// ---------------------------------------------------------------------------

class PuntoSemanal {
  const PuntoSemanal({required this.semana, required this.precision, required this.medianaMs, required this.intentos});
  final DateTime semana;
  final double precision;
  final double medianaMs;
  final int intentos;
}

class EstadisticasHabilidad {
  const EstadisticasHabilidad({
    required this.skillId,
    required this.semanas,
    required this.erroresPorTipo,
    required this.plantillasMasFalladas,
    required this.resumen,
  });
  final String skillId;

  /// Últimas 8 semanas con datos, de la más antigua a la más reciente.
  final List<PuntoSemanal> semanas;

  /// Código de error → veces, ordenado de más a menos.
  final List<MapEntry<String, int>> erroresPorTipo;
  final List<MapEntry<String, int>> plantillasMasFalladas;

  /// «Tu precisión ha pasado del 82 % al 93 % en cuatro semanas».
  final String resumen;
}

EstadisticasHabilidad estadisticasDeHabilidad(String skillId, List<Attempt> ordenados) {
  final lista = ordenados.where((a) => cuentaParaDominio(a) && a.skillId == skillId).toList();
  final porSemana = <DateTime, List<Attempt>>{};
  for (final a in lista) {
    porSemana.putIfAbsent(lunesDe(a.deviceTime), () => []).add(a);
  }
  final claves = porSemana.keys.toList()..sort();
  final ultimas = claves.length > 8 ? claves.sublist(claves.length - 8) : claves;
  final semanas = [
    for (final k in ultimas)
      PuntoSemanal(
        semana: k,
        precision: porSemana[k]!.where((a) => a.correct).length / porSemana[k]!.length,
        medianaMs: mediana(porSemana[k]!.map((a) => a.responseMs).toList()),
        intentos: porSemana[k]!.length,
      ),
  ];
  final errores = <String, int>{};
  final plantillas = <String, int>{};
  for (final a in lista.where((a) => !a.correct)) {
    final code = a.errorCode ?? 'E0';
    errores[code] = (errores[code] ?? 0) + 1;
    final p = a.templateId ?? a.questionId ?? a.variantId;
    plantillas[p] = (plantillas[p] ?? 0) + 1;
  }
  int ordenar(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  String resumen;
  if (semanas.isEmpty) {
    resumen = 'Aún no has practicado esta habilidad.';
  } else if (semanas.length < 2) {
    resumen = 'Tu precisión esta semana es del ${porcentaje(semanas.last.precision)}.';
  } else {
    final n = (diasEntre(semanas.first.semana, semanas.last.semana) ~/ 7) + 1;
    resumen = 'Tu precisión ha pasado del ${porcentaje(semanas.first.precision)} al '
        '${porcentaje(semanas.last.precision)} en ${_enLetra(n)} semanas';
  }
  return EstadisticasHabilidad(
    skillId: skillId,
    semanas: semanas,
    erroresPorTipo: errores.entries.toList()..sort(ordenar),
    plantillasMasFalladas: plantillas.entries.toList()..sort(ordenar),
    resumen: resumen,
  );
}

class ResumenGlobal {
  const ResumenGlobal({
    required this.precision7d,
    required this.tiempoFrenteObjetivo,
    required this.diasActivosSemana,
    required this.calendario,
    required this.sesionesCompletadas,
  });

  /// Precisión de los últimos 7 días (null sin datos).
  final double? precision7d;

  /// Tiempo medio ÷ tiempo objetivo medio de los últimos 7 días.
  final double? tiempoFrenteObjetivo;
  final int diasActivosSemana;

  /// Minutos de práctica de los 35 días que terminan hoy (5 semanas).
  final Map<DateTime, int> calendario;
  final int sesionesCompletadas;

  bool get datosInsuficientes => sesionesCompletadas < 3;
  static const mensajeDatosInsuficientes = 'Completa tres sesiones para ver tu evolución';
}

// ---------------------------------------------------------------------------
// Proyección completa
// ---------------------------------------------------------------------------

class Proyeccion {
  Proyeccion._({
    required this.intentos,
    required this.sesiones,
    required this.fichas,
    required this.habilidades,
    required this.lecciones,
    required this.unidades,
    required this.racha,
    required this.puntosTotales,
    required this.puntosSemana,
    required this.nivel,
    required this.logros,
    required this.resumen,
    required this.now,
    required this.topeRepaso,
    required this.leccionesPorId,
    required this.leccionesPorUnidad,
    required this.infoUnidades,
  });

  final List<Attempt> intentos;
  final List<SessionRecord> sesiones;
  final Map<String, FichaRepaso> fichas;
  final Map<String, EstadoHabilidadInfo> habilidades;
  final Map<String, ProgresoLeccion> lecciones;
  final Map<String, EstadoUnidad> unidades;
  final RachaInfo racha;
  final int puntosTotales;
  final int puntosSemana;
  final NivelInfo nivel;
  final List<LogroEstado> logros;
  final ResumenGlobal resumen;
  final DateTime now;
  final int topeRepaso;
  final Map<String, Lesson> leccionesPorId;
  final Map<String, List<Lesson>> leccionesPorUnidad;
  final Map<String, InfoUnidad> infoUnidades;

  EstadoHabilidad estadoHabilidad(String skillId) => habilidades[skillId]?.estado ?? EstadoHabilidad.nueva;

  Map<String, EstadoHabilidad> get mapaEstados => habilidades.map((k, v) => MapEntry(k, v.estado));

  InfoUnidad? infoUnidad(String unitId) => infoUnidades[unitId];

  List<FichaRepaso> get colaHoy => colaDeHoy(fichas.values, now, tope: topeRepaso);

  int get fichasVencidas => fichas.values.where((f) => f.vencida(now)).length;

  ({DateTime fecha, int fichas})? get proximo => proximoRepaso(fichas.values, now);

  EstadoLeccion estadoLeccion(String lessonId) {
    final l = leccionesPorId[lessonId];
    if (l == null) return EstadoLeccion.bloqueada;
    final unidad = unidades[l.unitId] ?? EstadoUnidad.bloqueada;
    if (lecciones[lessonId]?.completada == true) return EstadoLeccion.completada;
    if (unidad.superadaOMas) return EstadoLeccion.convalidada;
    if (unidad == EstadoUnidad.bloqueada) return EstadoLeccion.bloqueada;
    if (l.kind == LessonKind.challenge) return EstadoLeccion.disponible;
    final hermanas = leccionesPorUnidad[l.unitId] ?? const [];
    final anterior = hermanas.where((x) => x.order == l.order - 1).firstOrNull;
    if (anterior == null) return EstadoLeccion.disponible;
    return lecciones[anterior.id]?.completada == true ? EstadoLeccion.disponible : EstadoLeccion.bloqueada;
  }

  /// «Completa antes la lección N» si la lección está bloqueada.
  String? mensajeBloqueo(String lessonId) {
    final l = leccionesPorId[lessonId];
    if (l == null || estadoLeccion(lessonId) != EstadoLeccion.bloqueada) return null;
    if ((unidades[l.unitId] ?? EstadoUnidad.bloqueada) == EstadoUnidad.bloqueada) {
      return 'Supera antes la unidad anterior';
    }
    final hermanas = leccionesPorUnidad[l.unitId] ?? const [];
    final pendiente = hermanas
        .where((x) => x.order < l.order && lecciones[x.id]?.completada != true)
        .fold<Lesson?>(null, (acc, x) => acc == null || x.order > acc.order ? x : acc);
    return 'Completa antes la lección ${pendiente?.order ?? l.order - 1}';
  }

  /// Lección de «Continuar»: primera lección pendiente de la primera unidad
  /// disponible y no superada.
  Lesson? siguienteLeccion(ItineraryPackage itinerario) {
    for (final u in itinerario.units) {
      final estado = unidades[u.id] ?? EstadoUnidad.bloqueada;
      if (estado == EstadoUnidad.bloqueada || estado.superadaOMas) continue;
      final ls = leccionesPorUnidad[u.id] ?? const [];
      for (final l in ls) {
        if (lecciones[l.id]?.completada == true) continue;
        if (estadoLeccion(l.id) == EstadoLeccion.disponible) return l;
      }
    }
    return null;
  }

  EstadisticasHabilidad estadisticas(String skillId) => estadisticasDeHabilidad(skillId, intentos);
}

/// Proyecta todo el progreso a partir de intentos y sesiones.
Proyeccion proyectar({
  required Iterable<Attempt> attempts,
  required Iterable<SessionRecord> sessions,
  List<ItineraryPackage> itineraries = const [],
  List<Achievement> achievements = const [],
  Goal? goal,
  required DateTime now,
  int? topeRepaso,
  Iterable<String> habilidadesConocidas = const [],
}) {
  final intentos = ordenarIntentos(attempts);
  final sesiones = ordenarSesiones(sessions);
  final fichas = proyectarFichas(intentos);
  final habilidades = proyectarHabilidades(intentos, fichas, now, habilidadesConocidas: habilidadesConocidas);

  // Lecciones.
  final intentosPorSesion = <String, List<Attempt>>{};
  for (final a in intentos) {
    intentosPorSesion.putIfAbsent(a.sessionId, () => []).add(a);
  }
  final lecciones = <String, ProgresoLeccion>{};
  for (final s in sesiones) {
    if (s.lessonId == null || !s.completed) continue;
    if (s.mode != SessionMode.lesson && s.mode != SessionMode.challenge) continue;
    final previo = lecciones[s.lessonId!];
    final precision = s.summary?.accuracy;
    lecciones[s.lessonId!] = ProgresoLeccion(
      lessonId: s.lessonId!,
      completada: true,
      mejorPrecision: [previo?.mejorPrecision, precision].whereType<double>().fold<double?>(null, (m, v) => m == null || v > m ? v : m),
      fecha: s.endedAt,
      veces: (previo?.veces ?? 0) + 1,
    );
  }

  // Convalidaciones (prueba de nivel o reto) y retos superados.
  final convalidadas = <String>{};
  final retos = <String>{};
  for (final s in sesiones) {
    if (!s.completed) continue;
    if (s.mode == SessionMode.placement || s.mode == SessionMode.challenge) {
      convalidadas.addAll(s.summary?.convalidatedUnitIds ?? const []);
    }
    if (s.mode == SessionMode.challenge && s.lessonId != null) {
      final passed = s.summary?.passed ??
          retoSuperado((intentosPorSesion[s.id] ?? const []).where((a) => a.attemptNumber == 1).toList());
      if (passed) retos.add(s.lessonId!);
    }
  }

  final leccionesPorId = <String, Lesson>{};
  final leccionesPorUnidad = <String, List<Lesson>>{};
  for (final it in itineraries) {
    for (final l in it.lessons) {
      leccionesPorId[l.id] = l;
      leccionesPorUnidad.putIfAbsent(l.unitId, () => []).add(l);
    }
  }
  for (final ls in leccionesPorUnidad.values) {
    ls.sort((a, b) => a.order.compareTo(b.order));
  }

  final unidades = <String, EstadoUnidad>{};
  final info = <String, InfoUnidad>{};
  for (final it in itineraries) {
    final superadas = <String>{};
    for (final u in it.units) {
      final ls = leccionesPorUnidad[u.id] ?? const <Lesson>[];
      final reto = ls.where((l) => l.kind == LessonKind.challenge).map((l) => l.id).toSet();
      final porReto = reto.any(retos.contains);
      final conv = convalidadas.contains(u.id);
      final superada = porReto || conv;
      if (superada) superadas.add(u.id);
      final disponible = u.prerequisiteUnitId == null || superadas.contains(u.prerequisiteUnitId);
      final hechas = ls.where((l) => lecciones[l.id]?.completada == true).length;
      EstadoUnidad estado;
      if (superada) {
        final estados = u.skills.map((s) => habilidades[s]?.estado ?? EstadoHabilidad.nueva).toList();
        if (estados.isNotEmpty && estados.contains(EstadoHabilidad.porRefrescar)) {
          estado = EstadoUnidad.porRefrescar;
        } else if (estados.isNotEmpty && estados.every((e) => e == EstadoHabilidad.dominada)) {
          estado = EstadoUnidad.dominada;
        } else {
          estado = EstadoUnidad.superada;
        }
      } else if (!disponible) {
        estado = EstadoUnidad.bloqueada;
      } else {
        estado = hechas > 0 ? EstadoUnidad.enCurso : EstadoUnidad.disponible;
      }
      unidades[u.id] = estado;
      info[u.id] = InfoUnidad(
        unit: u,
        estado: estado,
        leccionesHechas: superada ? ls.length : hechas,
        leccionesTotales: ls.length,
        convalidada: conv,
        retoSuperado: porReto,
      );
    }
  }

  final racha = proyectarRacha(sesiones, goal, now);
  final puntosTotales = intentos.fold<int>(0, (s, a) => s + a.points);
  final lunes = lunesDe(now);
  final puntosSemana =
      intentos.where((a) => !diaLocal(a.deviceTime).isBefore(lunes)).fold<int>(0, (s, a) => s + a.points);

  final logros = _proyectarLogros(
    achievements: achievements,
    intentos: intentos,
    sesiones: sesiones,
    goal: goal,
    habilidades: habilidades,
    unidades: unidades,
    now: now,
  );

  // Resumen global.
  final hace7 = DateTime(diaLocal(now).year, diaLocal(now).month, diaLocal(now).day - 6);
  final recientes = intentos.where((a) => cuentaParaDominio(a) && !diaLocal(a.deviceTime).isBefore(hace7)).toList();
  final porDia = practicaPorDia(sesiones);
  final diasActividad = {...porDia.keys, ...intentos.map((a) => diaLocal(a.deviceTime))};
  final calendario = <DateTime, int>{};
  final hoy = diaLocal(now);
  for (var i = 34; i >= 0; i--) {
    final d = DateTime(hoy.year, hoy.month, hoy.day - i);
    calendario[d] = ((porDia[d] ?? 0) / 60000).round();
  }
  final resumen = ResumenGlobal(
    precision7d: recientes.isEmpty ? null : recientes.where((a) => a.correct).length / recientes.length,
    tiempoFrenteObjetivo: recientes.isEmpty
        ? null
        : recientes.fold<int>(0, (s, a) => s + a.responseMs) / math.max(1, recientes.fold<int>(0, (s, a) => s + a.targetMs)),
    diasActivosSemana: diasActividad.where((d) => lunesDe(d) == lunes).length,
    calendario: calendario,
    sesionesCompletadas: sesiones.where((s) => s.completed && s.mode != SessionMode.placement).length,
  );

  return Proyeccion._(
    intentos: intentos,
    sesiones: sesiones,
    fichas: fichas,
    habilidades: habilidades,
    lecciones: lecciones,
    unidades: unidades,
    racha: racha,
    puntosTotales: puntosTotales,
    puntosSemana: puntosSemana,
    nivel: nivelPorPuntos(puntosTotales),
    logros: logros,
    resumen: resumen,
    now: now,
    topeRepaso: normalizarTope(topeRepaso),
    leccionesPorId: leccionesPorId,
    leccionesPorUnidad: leccionesPorUnidad,
    infoUnidades: info,
  );
}

List<LogroEstado> _proyectarLogros({
  required List<Achievement> achievements,
  required List<Attempt> intentos,
  required List<SessionRecord> sesiones,
  required Goal? goal,
  required Map<String, EstadoHabilidadInfo> habilidades,
  required Map<String, EstadoUnidad> unidades,
  required DateTime now,
}) {
  if (achievements.isEmpty) return const [];
  // Eventos cronológicos: intentos y finales de sesión.
  final eventos = <(DateTime, String, Object)>[
    for (final a in intentos) (a.deviceTime, 'a${a.id}', a),
    for (final s in sesiones) (s.endedAt, 's${s.id}', s),
  ]..sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });

  final valores = <String, int>{
    'lessons_completed': 0,
    'handsfree_sessions': 0,
    'valid_timetrial': 0,
    'correct_in_row': 0,
    'no_critical_exercises': 0,
    'streak_days': 0,
  };
  final obtenidos = <String, DateTime>{};
  var aciertosSeguidos = 0;
  var sinCriticos = 0;
  final sesionesHasta = <SessionRecord>[];

  bool enVigencia(Achievement l, DateTime t) {
    final desde = l.validFrom == null ? null : DateTime.tryParse(l.validFrom!);
    final hasta = l.validTo == null ? null : DateTime.tryParse(l.validTo!);
    if (desde != null && t.isBefore(desde)) return false;
    if (hasta != null && t.isAfter(hasta)) return false;
    return true;
  }

  void comprobar(DateTime t) {
    for (final l in achievements) {
      if (obtenidos.containsKey(l.id)) continue;
      final v = valores[l.condition.metric];
      if (v == null) continue;
      if (enVigencia(l, t) && l.condition.evaluate(v)) obtenidos[l.id] = t;
    }
  }

  for (final (t, _, e) in eventos) {
    if (e is Attempt) {
      if (!cuentaParaDominio(e)) continue;
      aciertosSeguidos = e.correct ? aciertosSeguidos + 1 : 0;
      sinCriticos = e.critical ? 0 : sinCriticos + 1;
      if (aciertosSeguidos > valores['correct_in_row']!) valores['correct_in_row'] = aciertosSeguidos;
      if (sinCriticos > valores['no_critical_exercises']!) valores['no_critical_exercises'] = sinCriticos;
    } else if (e is SessionRecord) {
      sesionesHasta.add(e);
      if (e.completed && e.lessonId != null && (e.mode == SessionMode.lesson || e.mode == SessionMode.challenge)) {
        valores['lessons_completed'] = valores['lessons_completed']! + 1;
      }
      if (e.completed && e.mode == SessionMode.handsfree) {
        valores['handsfree_sessions'] = valores['handsfree_sessions']! + 1;
      }
      if (e.completed && e.mode == SessionMode.timetrial && e.summary?.valid == true) {
        valores['valid_timetrial'] = valores['valid_timetrial']! + 1;
      }
      final r = proyectarRacha(sesionesHasta, goal, t).actual;
      if (r > valores['streak_days']!) valores['streak_days'] = r;
    }
    comprobar(t);
  }

  // Métricas de estado final.
  valores['skills_mastered'] = habilidades.values.where((h) => h.estado == EstadoHabilidad.dominada).length;
  valores['units_mastered'] = unidades.values.where((u) => u == EstadoUnidad.dominada).length;
  final fin = intentos.isEmpty ? now : intentos.last.deviceTime;
  comprobar(fin);

  return [
    for (final l in achievements)
      if (!l.secret || obtenidos.containsKey(l.id))
        LogroEstado(
          logro: l,
          obtenido: obtenidos.containsKey(l.id),
          fecha: obtenidos[l.id],
          valor: valores[l.condition.metric] ?? 0,
          progreso: obtenidos.containsKey(l.id)
              ? 1
              : (l.condition.value <= 0 ? 0 : ((valores[l.condition.metric] ?? 0) / l.condition.value).clamp(0, 1).toDouble()),
        ),
  ];
}
