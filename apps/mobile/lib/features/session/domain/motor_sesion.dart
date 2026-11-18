import 'dart:math';

import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/learning_models.dart';
import '../../ads/domain/ad_selector.dart';
import '../../grading/domain/grading.dart';
import '../../review/domain/review_projection.dart';

/// Motor de la sesión de ejercicios (exercise-session, learning-path,
/// answer-grading y spaced-review). Dart puro: el reloj, el azar y el
/// registro de intentos se inyectan, de modo que toda la lógica se prueba sin
/// interfaz. La interfaz solo dibuja el estado y llama a estos métodos.
///
/// Flujo: [preparar] → ([presentar] → responder… → [continuar] →
/// [cerrarPausa]?)* → [resumen]. El motor fija el contenido con el que
/// empieza: una versión nueva descargada durante la sesión no le afecta.

/// Puntos por ejercicio acertado al primer intento.
const puntosPorAcierto = 10;

/// Respuestas que el intérprete de esta versión sabe dibujar (diseño D9).
///
/// Además de los cinco del producto mínimo viable, los de la fase 2 definidos
/// con el creador de tipos (add-growth-features): completar el planteamiento
/// (`fill_gaps`, T4), detectar el error (`step_pick`, T5), emparejar
/// (`matching`, T10) y caso encadenado (`chain`, T8: pasos numéricos con
/// `Variant.chain`).
const bloquesSoportados = {
  'numeric_unit', 'single_choice', 'ordering', 'range_choice', 'conversion_series', //
  'fill_gaps', 'step_pick', 'matching', 'chain',
};

/// Bloques de respuesta compatibles con voz (hands-free-voice): T1, T2, T6, T7.
const bloquesVoz = {'numeric_unit', 'single_choice', 'range_choice', 'conversion_series'};

/// Proporción de conversiones bien para dar por buena una serie T7.
const umbralSerie = 0.9;

enum FaseSesion { preparando, ejercicio, correccion, pausaPromocional, terminada }

enum OrigenEjercicio { leccion, calentamiento, repaso, segundoIntento, practica }

/// Un ejercicio listo para presentarse.
class EjercicioPreparado {
  EjercicioPreparado({
    required this.variante,
    required this.tipo,
    required this.bloque,
    required this.origen,
    this.slot,
    this.ficha,
    this.planteamientoVisible = false,
    this.indiceSlot,
  });
  final Variant variante;
  final ExerciseType? tipo;

  /// Bloque de respuesta del primer paso del tipo (`numeric_unit`…).
  final String bloque;
  final OrigenEjercicio origen;
  final LessonSlot? slot;
  final FichaRepaso? ficha;

  /// Planteamiento visible: práctica con apoyos o bajada de nivel con apoyo.
  final bool planteamientoVisible;
  final int? indiceSlot;

  int get intentoNumero => origen == OrigenEjercicio.segundoIntento ? 2 : 1;
  String get itemKey => variante.itemKey;
  int get nivel => variante.level;

  /// Unidad a elegir en los niveles 4 y 5 (exercise-session, «Unidad de respuesta»).
  bool get unidadAElegir {
    final a = variante.answer;
    if (a == null) return false;
    return !a.unitFixed && a.unitChoices.length > 1;
  }
}

/// Resultado corregido de un ejercicio.
class ResultadoEjercicio {
  const ResultadoEjercicio({
    required this.ejercicio,
    required this.verdict,
    required this.respuestaMs,
    required this.puntos,
    required this.correcta,
    this.valor,
    this.unidad,
    this.nota,
    this.errorCode,
    this.diagnostico,
    this.critico = false,
    this.pasoDesvio,
    this.payload,
    this.detalleSerie,
    required this.intento,
  });
  final EjercicioPreparado ejercicio;
  final Verdict verdict;
  final int respuestaMs;
  final int puntos;

  /// Respuesta correcta para pantalla («4,8 ml/h»).
  final String correcta;
  final String? valor;
  final String? unidad;
  final String? nota;
  final String? errorCode;
  final String? diagnostico;
  final bool critico;
  final int? pasoDesvio;
  final Object? payload;

  /// Serie T7: acierto por conversión.
  final List<bool>? detalleSerie;
  final Attempt intento;

  bool get acierto => isCorrectVerdict(verdict);
  bool get noLoSe => verdict == Verdict.dontKnow;
}

/// Una variante que no se ha podido mostrar y se ha saltado.
class VarianteSaltada {
  const VarianteSaltada(this.variantId, this.motivo);
  final String variantId;
  final String motivo;
}

/// Bloque de respuesta con el que se dibuja una variante. Un caso encadenado
/// (T8) se define con pasos numéricos y trae sus partes en `Variant.chain`.
String bloqueRespuesta(Variant v, ExerciseType? tipo) {
  final b = tipo?.steps.firstOrNull?.response ?? '';
  if ((v.chain ?? const []).isNotEmpty && (b == 'numeric_unit' || b == 'chain')) return 'chain';
  return b;
}

/// Por qué una variante no puede dibujarse, o null si es válida.
String? motivoDefecto(Variant v, ExerciseType? tipo) {
  if (tipo == null) return 'Tipo de ejercicio desconocido: ${v.exerciseTypeId}';
  // Cada tipo declara la versión mínima de la app que lo admite: una app
  // anterior omite su contenido sin errores (exercise-type-builder).
  if (compararVersiones(tipo.minAppVersion, versionApp) > 0) return 'El tipo ${tipo.id} exige la app ${tipo.minAppVersion}';
  if (tipo.steps.isEmpty) return 'Tipo sin pasos';
  final bloque = bloqueRespuesta(v, tipo);
  if (!bloquesSoportados.contains(bloque)) return 'Bloque no soportado: $bloque';
  switch (bloque) {
    case 'numeric_unit':
      final a = v.answer;
      if (a == null) return 'Falta la respuesta';
      try {
        dec(a.value);
      } catch (_) {
        return 'Respuesta no decimal';
      }
    case 'single_choice' || 'range_choice':
      final o = v.options ?? const [];
      if (o.length < 2 || o.where((x) => x.correct).length != 1) return 'Opciones no válidas';
    case 'ordering':
      if ((v.orderItems ?? const []).length < 2 || (v.validOrders ?? const []).isEmpty) return 'Pasos no válidos';
    case 'conversion_series':
      if ((v.series ?? const []).isEmpty) return 'Serie vacía';
    case 'fill_gaps':
      final g = v.gapFill;
      if (g == null || g.gapIds.isEmpty) return 'Faltan los huecos';
      if (g.gapIds.any((id) => !g.tiles.contains(g.gapAnswers[id]))) return 'Hueco sin ficha correcta';
    case 'step_pick':
      if ((v.worked ?? const []).length < 2) return 'Faltan los pasos resueltos';
    case 'matching':
      final pares = v.pairs ?? const [];
      if (pares.length < 2 || pares.map((p) => p.left).toSet().length != pares.length) return 'Parejas no válidas';
    case 'chain':
      for (final parte in v.chain!) {
        try {
          dec(parte.answer.value);
        } catch (_) {
          return 'Parte sin respuesta decimal';
        }
      }
  }
  if (v.statement.isEmpty && v.question.isEmpty) return 'Enunciado vacío';
  return null;
}

extension FichaClave on FichaRepaso {
  String get itemKey => templateId ?? questionId ?? clave.split('@').first;
  int get nivel => level;
}

/// Callbacks hacia la persistencia (el motor no sabe de bases de datos).
typedef RegistrarIntento = void Function(Attempt a);
typedef RegistrarEvento = void Function(String nombre, Map<String, dynamic> props);

/// Sesión de lección sin terminar que se reanuda (exercise-session, «Salida
/// a mitad de lección»: al volver se empieza por el ejercicio siguiente).
class SesionPrevia {
  const SesionPrevia({required this.sessionId, required this.intentos, required this.inicio, this.practicaMs = 0, this.anuncioMs = 0});
  final String sessionId;

  /// Intentos ya guardados de esa sesión.
  final List<Attempt> intentos;
  final DateTime inicio;
  final int practicaMs;
  final int anuncioMs;
}

/// Plazo para reanudar una lección dejada a medias.
const plazoReanudar = Duration(hours: 24);

/// Busca la sesión reanudable de una lección: la última sesión de esa
/// lección, si quedó sin completar, tiene intentos y se dejó hace menos de
/// 24 horas. Pasado ese plazo (o si después se completó), la lección empieza
/// de nuevo con otros números.
SesionPrevia? sesionReanudable(Lesson leccion, Iterable<SessionRecord> sesiones, Iterable<Attempt> intentos, DateTime ahora) {
  SessionRecord? ultima;
  for (final s in sesiones) {
    if (s.lessonId != leccion.id) continue;
    if (s.mode != SessionMode.lesson && s.mode != SessionMode.challenge) continue;
    if (ultima == null || s.endedAt.isAfter(ultima.endedAt)) ultima = s;
  }
  if (ultima == null || ultima.completed) return null;
  final d = ahora.difference(ultima.endedAt);
  if (d.isNegative || d > plazoReanudar) return null;
  final suyos = intentos.where((a) => a.sessionId == ultima!.id).toList()..sort((a, b) => a.deviceTime.compareTo(b.deviceTime));
  final primeros = suyos.where((a) => a.attemptNumber == 1 && a.lessonId == leccion.id).length;
  if (primeros == 0 || primeros >= leccion.slots.length) return null;
  return SesionPrevia(sessionId: ultima.id, intentos: suyos, inicio: ultima.startedAt, practicaMs: ultima.practiceMs, anuncioMs: ultima.adMs);
}

class MotorSesion {
  MotorSesion({
    required this.contenido,
    required this.modo,
    required this.deviceId,
    required this.relojMs,
    required this.ahora,
    this.leccion,
    this.calentamiento = const [],
    this.fichasRepaso = const [],
    this.variantesPractica = const [],
    this.sinAnuncios = true,
    this.esPrimeraLeccion = false,
    this.frecuenciaAnuncios = 1,
    this.soloVoz = false,
    this.inputMode = InputMode.touch,
    this.alRegistrar,
    this.alEvento,
    this.previa,
    Random? azar,
    String? sessionId,
  })  : azar = azar ?? Random(),
        sessionId = sessionId ?? nuevoId();

  /// Sesión sin terminar de esta misma lección que se continúa: se empieza
  /// por el ejercicio siguiente y los ya respondidos cuentan en el resumen.
  /// La continuación lleva un identificador de sesión nuevo: el servidor no
  /// actualiza una sesión ya subida (`ON CONFLICT DO NOTHING`), así que la
  /// sesión sin completar se conserva tal cual y la nueva registra la lección
  /// completa. El tiempo de práctica de cada tramo queda en su sesión, sin
  /// contarse dos veces.
  final SesionPrevia? previa;

  /// Ejercicios ya respondidos en la sesión que se reanuda.
  int reanudados = 0;

  final ContenidoCargado contenido;
  final SessionMode modo;
  final String deviceId;

  /// Reloj monótono en milisegundos (cronómetro de la sesión).
  final int Function() relojMs;

  /// Hora de pared para fechar intentos y sesiones.
  final DateTime Function() ahora;
  final Lesson? leccion;
  final List<FichaRepaso> calentamiento;
  final List<FichaRepaso> fichasRepaso;
  final List<Variant> variantesPractica;

  /// El usuario tiene Premium (o plaza de organización): sin pausas. Puede
  /// cambiar a mitad de sesión tras una compra.
  bool sinAnuncios;
  final bool esPrimeraLeccion;
  final int frecuenciaAnuncios;
  final bool soloVoz;
  final InputMode inputMode;
  RegistrarIntento? alRegistrar;
  RegistrarEvento? alEvento;
  final Random azar;
  final String sessionId;

  // ---- Estado --------------------------------------------------------------
  FaseSesion fase = FaseSesion.preparando;
  final List<EjercicioPreparado> _cola = [];
  EjercicioPreparado? actual;
  ResultadoEjercicio? ultimoResultado;
  final List<ResultadoEjercicio> resultados = [];
  final List<VarianteSaltada> saltadas = [];
  ColaSesionRepaso? _colaRepaso;
  final Map<String, FichaRepaso> _fichasPorClave = {};

  /// Ejercicios de la lección que no entran en manos libres por su tipo.
  int excluidosPorVoz = 0;

  /// Total previsto (para la barra de progreso «5 de 8»).
  int total = 0;

  /// Ejercicios cerrados (cuenta para la frecuencia de la pausa).
  int cerrados = 0;

  late int _inicioSesionMs;
  late DateTime _inicioSesion;
  int _inicioEjercicioMs = 0;
  int _pausadoEnEjercicioMs = 0;
  int? _pausaDesdeMs;
  int _pausadoTotalMs = 0;
  int _anuncioMs = 0;
  int? _anuncioDesdeMs;
  bool _pausado = false;
  final Set<String> _vistas = {};

  // Dificultad adaptativa.
  int _desplazamiento = 0;
  int _aciertosSeguidos = 0;
  int _fallosSeguidos = 0;
  bool _apoyoSiguiente = false;

  bool get pausado => _pausado;
  bool get esReto => leccion?.kind == LessonKind.challenge;
  bool get pistasPermitidas => !esReto && modo != SessionMode.placement;
  int get posicion => resultados.where((r) => r.ejercicio.intentoNumero == 1).length + (fase == FaseSesion.ejercicio && actual?.intentoNumero == 1 ? 1 : 0);
  int get desplazamientoNivel => _desplazamiento;

  // ---- Preparación ---------------------------------------------------------

  /// Prepara todos los ejercicios antes de empezar: la sesión no depende de la
  /// red ni tiene esperas entre ejercicios.
  void preparar() {
    _inicioSesionMs = relojMs();
    _inicioSesion = ahora();
    _restaurarPrevios();
    for (final f in reanudados > 0 ? const <FichaRepaso>[] : calentamiento.take(5)) {
      final e = _ejercicioDeFicha(f, OrigenEjercicio.calentamiento);
      if (e != null) _cola.add(e);
    }
    if (modo == SessionMode.review) {
      for (final f in fichasRepaso) {
        _fichasPorClave[f.clave] = f;
      }
      _colaRepaso = ColaSesionRepaso(fichasRepaso.map((f) => f.clave));
    } else if (leccion != null) {
      final slots = [...leccion!.slots]..sort((a, b) => a.position.compareTo(b.position));
      for (var i = 0; i < slots.length; i++) {
        final s = slots[i];
        final key = s.templateId ?? s.questionId;
        if (key == null) continue;
        if (i < reanudados) continue; // Ya respondido antes de salir.
        final candidatas = contenido.variantesDe(key);
        if (candidatas.isEmpty) {
          saltadas.add(VarianteSaltada(key, 'Sin variantes vigentes'));
          continue;
        }
        final muestra = candidatas.first;
        final tipo = contenido.tipo(muestra.exerciseTypeId);
        final bloque = bloqueRespuesta(muestra, tipo);
        if (soloVoz && !bloquesVoz.contains(bloque)) {
          excluidosPorVoz++;
          continue;
        }
        _cola.add(EjercicioPreparado(
          variante: muestra,
          tipo: tipo,
          bloque: bloque,
          origen: OrigenEjercicio.leccion,
          slot: s,
          indiceSlot: i,
          planteamientoVisible: leccion!.kind == LessonKind.guided || leccion!.kind == LessonKind.supported,
        ));
      }
    } else {
      for (final v in variantesPractica) {
        final tipo = contenido.tipo(v.exerciseTypeId);
        final bloque = bloqueRespuesta(v, tipo);
        if (soloVoz && !bloquesVoz.contains(bloque)) {
          excluidosPorVoz++;
          continue;
        }
        _cola.add(EjercicioPreparado(variante: v, tipo: tipo, bloque: bloque, origen: OrigenEjercicio.practica));
      }
    }
    total = _cola.length + reanudados + (modo == SessionMode.review ? fichasRepaso.length : 0);
    _avanzar();
  }

  /// Reconstruye los resultados de la sesión que se reanuda a partir de sus
  /// intentos guardados, para que el resumen cuente la lección entera.
  void _restaurarPrevios() {
    final previa = this.previa;
    if (previa == null || leccion == null) return;
    final slots = [...leccion!.slots]..sort((a, b) => a.position.compareTo(b.position));
    var i = 0;
    for (final a in previa.intentos) {
      if (a.lessonId != leccion!.id) continue;
      final v = contenido.variante(a.variantId);
      if (v == null) {
        if (a.attemptNumber == 1) i++;
        continue;
      }
      final tipo = contenido.tipo(v.exerciseTypeId);
      final segundo = a.attemptNumber != 1;
      final indice = segundo ? i - 1 : i;
      final e = EjercicioPreparado(
        variante: v,
        tipo: tipo,
        bloque: bloqueRespuesta(v, tipo),
        origen: segundo ? OrigenEjercicio.segundoIntento : OrigenEjercicio.leccion,
        slot: indice >= 0 && indice < slots.length ? slots[indice] : null,
        indiceSlot: indice,
      );
      final spec = v.answer;
      resultados.add(ResultadoEjercicio(
        ejercicio: e,
        verdict: a.verdict,
        respuestaMs: a.responseMs,
        puntos: a.points,
        correcta: spec != null ? displayQty(spec.value, spec.unit) : (v.options?.where((o) => o.correct).firstOrNull?.label ?? ''),
        valor: a.answerValue,
        unidad: a.answerUnit,
        errorCode: a.errorCode,
        critico: a.critical,
        payload: a.answerPayload,
        intento: a,
      ));
      _vistas.add(v.id);
      if (!segundo) i++;
    }
    reanudados = i;
    cerrados = i;
  }

  EjercicioPreparado? _ejercicioDeFicha(FichaRepaso f, OrigenEjercicio origen) {
    final candidatas = contenido.variantes(f.itemKey, f.nivel).where((v) => motivoDefecto(v, contenido.tipo(v.exerciseTypeId)) == null).toList();
    final id = elegirVarianteRepaso(f, candidatas.map((v) => v.id).toList());
    if (id == null) return null;
    final v = candidatas.firstWhere((x) => x.id == id);
    final tipo = contenido.tipo(v.exerciseTypeId);
    final bloque = bloqueRespuesta(v, tipo);
    if (soloVoz && !bloquesVoz.contains(bloque)) return null;
    return EjercicioPreparado(variante: v, tipo: tipo, bloque: bloque, origen: origen, ficha: f);
  }

  /// Elige la variante del ejercicio de lección según la dificultad adaptativa.
  EjercicioPreparado _resolverNivel(EjercicioPreparado e) {
    if (e.origen != OrigenEjercicio.leccion || e.slot == null) return e;
    final niveles = contenido.niveles(e.itemKey);
    if (niveles.isEmpty) return e;
    final base = e.slot!.difficulty;
    final objetivo = esReto ? base : (base + _desplazamiento).clamp(niveles.first, niveles.last);
    final nivel = niveles.reduce((a, b) => (a - objetivo).abs() <= (b - objetivo).abs() ? a : b);
    final candidatas = contenido.variantes(e.itemKey, nivel).where((v) => !_vistas.contains(v.id)).toList();
    final todas = candidatas.isEmpty ? contenido.variantes(e.itemKey, nivel) : candidatas;
    if (todas.isEmpty) return e;
    final v = todas[azar.nextInt(todas.length)];
    final apoyo = e.planteamientoVisible || _apoyoSiguiente;
    return EjercicioPreparado(
      variante: v,
      tipo: contenido.tipo(v.exerciseTypeId),
      bloque: e.bloque,
      origen: e.origen,
      slot: e.slot,
      indiceSlot: e.indiceSlot,
      planteamientoVisible: apoyo,
    );
  }

  void _avanzar() {
    while (true) {
      EjercicioPreparado? siguiente;
      if (_cola.isNotEmpty) {
        siguiente = _resolverNivel(_cola.removeAt(0));
      } else if (_colaRepaso != null && !_colaRepaso!.terminada) {
        final f = _fichasPorClave[_colaRepaso!.actual!]!;
        siguiente = _ejercicioDeFicha(f, OrigenEjercicio.repaso);
        if (siguiente == null) {
          saltadas.add(VarianteSaltada(f.clave, 'Sin variantes vigentes'));
          _colaRepaso!.responder(acierto: true);
          continue;
        }
      }
      if (siguiente == null) {
        actual = null;
        fase = FaseSesion.terminada;
        return;
      }
      final motivo = motivoDefecto(siguiente.variante, siguiente.tipo);
      if (motivo != null) {
        // Variante defectuosa: se salta, se registra y se sigue.
        saltadas.add(VarianteSaltada(siguiente.variante.id, motivo));
        alEvento?.call('variant_skipped', {'variantId': siguiente.variante.id, 'reason': motivo, 'sessionId': sessionId});
        if (siguiente.origen == OrigenEjercicio.repaso) _colaRepaso?.responder(acierto: true);
        if (siguiente.origen != OrigenEjercicio.repaso) total = max(0, total - 1);
        continue;
      }
      actual = siguiente;
      _apoyoSiguiente = false;
      fase = FaseSesion.ejercicio;
      presentar();
      return;
    }
  }

  // ---- Tiempo --------------------------------------------------------------

  /// Marca el momento en que el enunciado aparece en pantalla.
  void presentar() {
    _inicioEjercicioMs = relojMs();
    _pausadoEnEjercicioMs = 0;
    if (actual != null) _vistas.add(actual!.variante.id);
  }

  /// La app pasa a segundo plano o el usuario pausa: el reloj se detiene.
  void pausar() {
    if (_pausado) return;
    _pausado = true;
    _pausaDesdeMs = relojMs();
  }

  void reanudar() {
    if (!_pausado) return;
    final d = relojMs() - (_pausaDesdeMs ?? relojMs());
    _pausado = false;
    _pausaDesdeMs = null;
    _pausadoTotalMs += d;
    if (fase == FaseSesion.ejercicio) _pausadoEnEjercicioMs += d;
  }

  int _tiempoRespuesta() {
    var pausaEnCurso = 0;
    if (_pausado && _pausaDesdeMs != null) pausaEnCurso = relojMs() - _pausaDesdeMs!;
    return max(0, relojMs() - _inicioEjercicioMs - _pausadoEnEjercicioMs - pausaEnCurso);
  }

  // ---- Respuestas ----------------------------------------------------------

  /// T1: cifra escrita con el teclado propio (coma decimal) y unidad elegida
  /// si el nivel la pide.
  ResultadoEjercicio responderNumerico(String raw, {String? unidad, int pistas = 0}) {
    final e = _exigirEjercicio();
    final spec = e.variante.answer!;
    final g = grade(spec, e.variante.predictedErrors, GradeInput(raw, unit: unidad));
    return _cerrar(
      e,
      verdict: g.verdict,
      correcta: g.correctDisplay,
      valor: g.value,
      unidad: g.unit ?? spec.unit,
      nota: g.note,
      errorCode: g.errorCode,
      diagnostico: g.diagnosis,
      critico: g.critical,
      pasoDesvio: g.deviationStep,
      pistas: pistas,
    );
  }

  /// T2 y T6: una opción.
  ResultadoEjercicio responderOpcion(String opcionId, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final opciones = e.variante.options!;
    final g = gradeChoice(opciones, opcionId);
    final elegida = opciones.where((o) => o.id == opcionId).firstOrNull;
    final buena = opciones.firstWhere((o) => o.correct);
    PredictedError? previsto;
    if (elegida?.value != null) {
      previsto = e.variante.predictedErrors.where((p) => p.value == elegida!.value && p.unit == elegida.unit).firstOrNull;
    }
    return _cerrar(
      e,
      verdict: g.verdict,
      correcta: buena.label,
      valor: elegida?.value,
      unidad: elegida?.unit,
      errorCode: g.errorCode,
      diagnostico: g.diagnosis,
      critico: g.critical,
      pasoDesvio: previsto?.deviationStep,
      payload: {'optionId': opcionId},
      pistas: pistas,
    );
  }

  /// T3: orden de los pasos (ids), válido si coincide con cualquiera de los
  /// órdenes declarados.
  ResultadoEjercicio responderOrden(List<String> orden, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final ok = gradeOrder(e.variante.validOrders!, orden);
    final items = {for (final i in e.variante.orderItems!) i.id: i.text};
    final correcta = e.variante.validOrders!.first.map((id) => items[id] ?? id).toList();
    return _cerrar(
      e,
      verdict: ok ? Verdict.correct : Verdict.incorrect,
      correcta: correcta.asMap().entries.map((x) => '${x.key + 1}. ${x.value}').join('\n'),
      errorCode: ok ? null : 'E4',
      diagnostico: ok ? null : 'El orden de los pasos no es correcto',
      payload: {'order': orden},
      pistas: pistas,
    );
  }

  /// T7: serie de conversiones con 60 segundos en total. Las no contestadas
  /// cuentan como falladas.
  ResultadoEjercicio responderSerie(List<String?> respuestas) {
    final e = _exigirEjercicio();
    final serie = e.variante.series!;
    final detalle = <bool>[];
    for (var i = 0; i < serie.length; i++) {
      final r = i < respuestas.length ? respuestas[i] : null;
      if (r == null || r.trim().isEmpty) {
        detalle.add(false);
        continue;
      }
      final g = grade(serie[i].answer, const [], GradeInput(r));
      detalle.add(isCorrectVerdict(g.verdict));
    }
    final bien = detalle.where((x) => x).length;
    final ok = serie.isNotEmpty && bien / serie.length >= umbralSerie;
    return _cerrar(
      e,
      verdict: ok ? Verdict.correct : Verdict.incorrect,
      correcta: '${serie.length} de ${serie.length}',
      valor: '$bien',
      diagnostico: ok ? null : '$bien de ${serie.length} conversiones bien',
      payload: {'answers': respuestas},
      detalleSerie: detalle,
    );
  }

  /// Corrige una sola conversión de la serie (para la marca en vivo).
  bool corregirConversion(int indice, String raw) {
    final e = _exigirEjercicio();
    final item = e.variante.series![indice];
    return isCorrectVerdict(grade(item.answer, const [], GradeInput(raw)).verdict);
  }

  // ---- Tipos de la fase 2 -------------------------------------------------

  /// Operación con los huecos rellenos (por defecto, con las fichas correctas).
  static String operacionResuelta(GapFill g, [Map<String, String>? colocadas]) =>
      g.template.replaceAllMapped(RegExp(r'\{(g\d+)\}'), (m) => (colocadas ?? g.gapAnswers)[m.group(1)!] ?? '…');

  /// T4: fichas colocadas por hueco (`g1` → ficha). Se aceptan las posiciones
  /// intercambiables declaradas; sobran fichas.
  ResultadoEjercicio responderHuecos(Map<String, String> colocadas, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final g = e.variante.gapFill!;
    final r = gradeGapFill(g, colocadas);
    return _cerrar(
      e,
      verdict: r.correct ? Verdict.correct : Verdict.incorrect,
      correcta: operacionResuelta(g),
      valor: operacionResuelta(g, colocadas),
      diagnostico: r.correct ? null : (r.wrongGaps.length == 1 ? 'Un hueco no es correcto' : '${r.wrongGaps.length} huecos no son correctos'),
      payload: {'placed': Map<String, String>.of(colocadas), 'wrongGaps': r.wrongGaps},
      pistas: pistas,
    );
  }

  /// T5: paso señalado como erróneo, o null para «No hay ningún error».
  ResultadoEjercicio responderPaso(int? pasoN, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final pasos = e.variante.worked!;
    final ok = gradeWorkedStep(pasos, pasoN);
    final malo = pasos.where((w) => !w.correct).firstOrNull;
    return _cerrar(
      e,
      verdict: ok ? Verdict.correct : Verdict.incorrect,
      correcta: malo == null ? 'No hay ningún error' : 'Paso ${malo.n}: ${malo.correction ?? malo.text}',
      valor: pasoN == null ? null : '$pasoN',
      diagnostico: ok ? null : (malo == null ? 'Todos los pasos son correctos' : 'El error está en el paso ${malo.n}'),
      pasoDesvio: malo?.n,
      payload: {'stepN': pasoN},
      pistas: pistas,
    );
  }

  /// T10: corrige un par por separado (respuesta inmediata al unirlo).
  bool corregirPar(String izquierda, String derecha) {
    final e = _exigirEjercicio();
    return e.variante.pairs!.any((p) => p.left == izquierda && p.right == derecha);
  }

  /// T10: el ejercicio termina cuando todos los elementos están unidos.
  ResultadoEjercicio responderPares(Map<String, String> pares, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final todos = e.variante.pairs!;
    final r = gradePairs(todos, pares);
    final bien = todos.length - r.wrongLefts.length;
    return _cerrar(
      e,
      verdict: r.correct ? Verdict.correct : Verdict.incorrect,
      correcta: todos.map((p) => '${p.left} = ${p.right}').join('\n'),
      valor: '$bien',
      diagnostico: r.correct ? null : '$bien de ${todos.length} parejas bien',
      payload: {'pairs': Map<String, String>.of(pares), 'wrongLefts': r.wrongLefts},
      pistas: pistas,
    );
  }

  /// T8: corrige una parte del caso encadenado. Si falla, la siguiente parte
  /// continúa con el valor correcto de esta.
  GradeResult corregirParte(int indice, String raw, {String? unidad}) {
    final e = _exigirEjercicio();
    final parte = e.variante.chain![indice];
    return grade(parte.answer, parte.predictedErrors, GradeInput(raw, unit: unidad));
  }

  /// T8: respuestas de todas las partes. Correcto solo si todas lo son; cada
  /// parte queda corregida por separado en `answerPayload.parts`.
  ResultadoEjercicio responderCadena(List<String?> respuestas, {int pistas = 0}) {
    final e = _exigirEjercicio();
    final partes = e.variante.chain!;
    final detalle = <Map<String, dynamic>>[];
    GradeResult? primerFallo;
    int? primerFalloN;
    var critico = false;
    for (var i = 0; i < partes.length; i++) {
      final raw = i < respuestas.length ? respuestas[i] : null;
      final g = (raw == null || raw.trim().isEmpty) ? null : grade(partes[i].answer, partes[i].predictedErrors, GradeInput(raw));
      final ok = g != null && isCorrectVerdict(g.verdict);
      if (!ok && primerFalloN == null) {
        primerFallo = g;
        primerFalloN = i + 1;
      }
      if (g?.critical == true) critico = true;
      detalle.add({
        'value': g?.value,
        'verdict': g == null ? 'skipped' : verdictWire(g.verdict),
        'errorCode': g?.errorCode,
        'correct': displayQty(partes[i].answer.value, partes[i].answer.unit),
      });
    }
    final bien = detalle.where((d) => d['verdict'] == 'correct' || d['verdict'] == 'correct_note').length;
    final ok = bien == partes.length;
    final ultima = partes.last.answer;
    return _cerrar(
      e,
      verdict: ok ? Verdict.correct : Verdict.incorrect,
      correcta: displayQty(ultima.value, ultima.unit),
      valor: detalle.last['value'] as String?,
      unidad: ultima.unit,
      errorCode: ok ? null : primerFallo?.errorCode,
      diagnostico: ok ? null : (primerFallo?.diagnosis ?? '$bien de ${partes.length} partes bien'),
      critico: critico,
      pasoDesvio: ok ? null : primerFalloN,
      payload: {'parts': detalle},
      pistas: pistas,
    );
  }

  /// «No lo sé»: resolución guiada sin diagnóstico; cuenta como no acertado.
  ResultadoEjercicio noLoSe() {
    final e = _exigirEjercicio();
    final v = e.variante;
    final a = v.answer;
    final buena = v.options?.where((o) => o.correct).firstOrNull;
    final malo = v.worked?.where((w) => !w.correct).firstOrNull;
    final correcta = switch (e.bloque) {
      'fill_gaps' => operacionResuelta(v.gapFill!),
      'step_pick' => malo == null ? 'No hay ningún error' : 'Paso ${malo.n}: ${malo.correction ?? malo.text}',
      'matching' => v.pairs!.map((p) => '${p.left} = ${p.right}').join('\n'),
      'chain' => displayQty(v.chain!.last.answer.value, v.chain!.last.answer.unit),
      _ => a != null ? displayQty(a.value, a.unit) : (buena?.label ?? ''),
    };
    return _cerrar(e, verdict: Verdict.dontKnow, correcta: correcta);
  }

  EjercicioPreparado _exigirEjercicio() {
    if (fase != FaseSesion.ejercicio || actual == null) throw StateError('No hay ejercicio en curso');
    return actual!;
  }

  ResultadoEjercicio _cerrar(
    EjercicioPreparado e, {
    required Verdict verdict,
    required String correcta,
    String? valor,
    String? unidad,
    String? nota,
    String? errorCode,
    String? diagnostico,
    bool critico = false,
    int? pasoDesvio,
    Object? payload,
    List<bool>? detalleSerie,
    int pistas = 0,
  }) {
    final ms = _tiempoRespuesta();
    final acierto = isCorrectVerdict(verdict);
    final puntos = acierto && e.intentoNumero == 1 ? puntosPorAcierto : 0;
    final modoIntento = switch (e.origen) {
      OrigenEjercicio.calentamiento => SessionMode.warmup,
      OrigenEjercicio.repaso => SessionMode.review,
      _ => modo,
    };
    final a = Attempt(
      id: nuevoId(),
      sessionId: sessionId,
      deviceId: deviceId,
      mode: modoIntento,
      lessonId: e.origen == OrigenEjercicio.leccion || e.origen == OrigenEjercicio.segundoIntento ? leccion?.id : null,
      templateId: e.variante.templateId,
      questionId: e.variante.questionId,
      variantId: e.variante.id,
      skillId: e.variante.skillId,
      exerciseTypeId: e.variante.exerciseTypeId,
      level: e.variante.level,
      attemptNumber: e.intentoNumero,
      answerValue: valor,
      answerUnit: unidad,
      answerPayload: payload,
      verdict: verdict,
      errorCode: verdict == Verdict.dontKnow ? null : errorCode,
      critical: critico,
      hintsUsed: pistas,
      responseMs: ms,
      targetMs: e.variante.targetTimeS * 1000,
      inputMode: inputMode,
      points: puntos,
      contentVersion: contenido.version,
      deviceTime: ahora(),
    );
    final r = ResultadoEjercicio(
      ejercicio: e,
      verdict: verdict,
      respuestaMs: ms,
      puntos: puntos,
      correcta: correcta,
      valor: valor,
      unidad: unidad,
      nota: nota,
      errorCode: verdict == Verdict.dontKnow ? null : errorCode,
      diagnostico: verdict == Verdict.dontKnow ? null : diagnostico,
      critico: critico,
      pasoDesvio: verdict == Verdict.dontKnow ? null : pasoDesvio,
      payload: payload,
      detalleSerie: detalleSerie,
      intento: a,
    );
    resultados.add(r);
    ultimoResultado = r;
    alRegistrar?.call(a);
    _actualizarAdaptativo(r);
    if (e.origen == OrigenEjercicio.repaso) _colaRepaso?.responder(acierto: acierto);
    fase = FaseSesion.correccion;
    return r;
  }

  void _actualizarAdaptativo(ResultadoEjercicio r) {
    if (r.ejercicio.origen != OrigenEjercicio.leccion || esReto) return;
    final dentroDeTiempo = r.respuestaMs <= r.ejercicio.variante.targetTimeS * 1000;
    if (r.acierto) {
      _fallosSeguidos = 0;
      _aciertosSeguidos = dentroDeTiempo ? _aciertosSeguidos + 1 : 0;
      if (_aciertosSeguidos >= 3) {
        _desplazamiento++;
        _aciertosSeguidos = 0;
      }
    } else {
      _aciertosSeguidos = 0;
      _fallosSeguidos++;
      if (_fallosSeguidos >= 2) {
        _desplazamiento--;
        _fallosSeguidos = 0;
        _apoyoSiguiente = true;
      }
    }
  }

  // ---- Tras la corrección --------------------------------------------------

  /// Se ofrece «Probar con otros números» tras un fallo, salvo en el reto, el
  /// repaso y la prueba de nivel, y nunca dos veces seguidas.
  bool get segundoIntentoDisponible {
    final r = ultimoResultado;
    if (fase != FaseSesion.correccion || r == null) return false;
    if (r.acierto || r.ejercicio.intentoNumero == 2) return false;
    if (esReto || modo == SessionMode.placement || r.ejercicio.origen == OrigenEjercicio.repaso) return false;
    if (r.ejercicio.bloque == 'conversion_series' || r.ejercicio.bloque == 'ordering') {
      return _otraVariante(r.ejercicio) != null;
    }
    return _otraVariante(r.ejercicio) != null;
  }

  Variant? _otraVariante(EjercicioPreparado e) {
    final candidatas = contenido
        .variantes(e.itemKey, e.nivel)
        .where((v) => v.id != e.variante.id && !_vistas.contains(v.id) && motivoDefecto(v, contenido.tipo(v.exerciseTypeId)) == null)
        .toList();
    if (candidatas.isEmpty) return null;
    return candidatas[azar.nextInt(candidatas.length)];
  }

  /// Segundo intento con otra variante de la misma plantilla y nivel. No da
  /// puntos y no muestra pausa promocional antes (house-ads).
  void iniciarSegundoIntento() {
    final r = ultimoResultado!;
    final v = _otraVariante(r.ejercicio);
    if (v == null) return;
    actual = EjercicioPreparado(
      variante: v,
      tipo: contenido.tipo(v.exerciseTypeId),
      bloque: r.ejercicio.bloque,
      origen: OrigenEjercicio.segundoIntento,
      slot: r.ejercicio.slot,
      indiceSlot: r.ejercicio.indiceSlot,
      planteamientoVisible: r.ejercicio.planteamientoVisible,
    );
    fase = FaseSesion.ejercicio;
    presentar();
  }

  /// ¿Toca pausa promocional al cerrar la corrección actual?
  bool get tocaPausa => PoliticaPausa.debeMostrar(
        sinAnuncios: sinAnuncios,
        modo: modo,
        esPrimeraLeccion: esPrimeraLeccion,
        enContrarrelojEntreEjercicios: true,
        contadorEjercicios: cerrados + 1,
        frecuencia: frecuenciaAnuncios,
      );

  /// El usuario cierra la corrección («Continuar»). Si toca, se pasa a la
  /// pausa promocional; si no, al ejercicio siguiente o al final.
  void continuar() {
    if (fase != FaseSesion.correccion) return;
    final pausa = tocaPausa;
    cerrados++;
    if (pausa) {
      fase = FaseSesion.pausaPromocional;
      _anuncioDesdeMs = relojMs();
      return;
    }
    _avanzar();
  }

  /// La pausa promocional se cierra; su tiempo no cuenta como práctica.
  void cerrarPausa() {
    if (fase != FaseSesion.pausaPromocional) return;
    _anuncioMs += relojMs() - (_anuncioDesdeMs ?? relojMs());
    _anuncioDesdeMs = null;
    _avanzar();
  }

  /// ¿La pausa actual es la última de la lección (antes del resumen)?
  bool get ultimaPausa => _cola.isEmpty && (_colaRepaso == null || _colaRepaso!.terminada);

  // ---- Cierre --------------------------------------------------------------

  List<ResultadoEjercicio> get primerosIntentos =>
      resultados.where((r) => r.ejercicio.intentoNumero == 1 && r.ejercicio.origen != OrigenEjercicio.calentamiento).toList();

  /// Reto superado: 10 ejercicios, 9 aciertos o más y ningún error crítico.
  bool get retoSuperado {
    final p = primerosIntentos;
    return esReto && p.length >= 10 && p.where((r) => r.acierto).length >= 9 && p.every((r) => !r.critico);
  }

  /// Registro de la sesión. [completada] es false si el usuario sale antes.
  SessionRecord registro({required bool completada}) {
    final p = primerosIntentos;
    final aciertos = p.where((r) => r.acierto).length;
    final fin = ahora();
    final duracion = relojMs() - _inicioSesionMs;
    final practica = max(0, duracion - _pausadoTotalMs - _anuncioMs);
    final unitId = leccion?.unitId;
    return SessionRecord(
      id: sessionId,
      deviceId: deviceId,
      mode: esReto ? SessionMode.challenge : modo,
      lessonId: leccion?.id,
      skillId: variantesPractica.firstOrNull?.skillId,
      startedAt: _inicioSesion,
      endedAt: fin,
      completed: completada,
      practiceMs: practica,
      adMs: _anuncioMs,
      inputMode: inputMode,
      contentVersion: contenido.version,
      summary: SessionSummary(
        correct: aciertos,
        total: p.length,
        errors: p.length - aciertos,
        accuracy: p.isEmpty ? 0 : aciertos / p.length,
        avgMs: p.isEmpty ? null : p.map((r) => r.respuestaMs).reduce((a, b) => a + b) ~/ p.length,
        passed: esReto ? retoSuperado : null,
        convalidatedUnitIds: esReto && retoSuperado && unitId != null ? [unitId] : null,
      ),
    );
  }

  /// Fallos de la lección para la pantalla de fin y el repaso.
  List<ResultadoEjercicio> get fallos => primerosIntentos.where((r) => !r.acierto).toList();

  int get puntosGanados => resultados.fold(0, (s, r) => s + r.puntos);

  int get tiempoAnunciosMs => _anuncioMs;

  int get tiempoMedioMs {
    final p = primerosIntentos;
    return p.isEmpty ? 0 : p.map((r) => r.respuestaMs).reduce((a, b) => a + b) ~/ p.length;
  }

  int get tiempoObjetivoMedioMs {
    final p = primerosIntentos;
    return p.isEmpty ? 0 : p.map((r) => r.ejercicio.variante.targetTimeS * 1000).reduce((a, b) => a + b) ~/ p.length;
  }
}
