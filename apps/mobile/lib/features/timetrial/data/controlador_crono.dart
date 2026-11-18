import 'dart:math';

import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/learning_models.dart';
import '../../grading/domain/grading.dart';
import '../../session/domain/motor_sesion.dart';
import '../domain/timetrial.dart';

/// Bloques que entran en el contrarreloj: respuesta numérica y opciones. Las
/// series T7 y la ordenación no caben en un esprint de respuestas sueltas.
const bloquesCrono = {'numeric_unit', 'single_choice', 'range_choice'};

/// Ejercicios de la serie sin cuenta atrás.
const ejerciciosSerieSinLimite = 10;

/// Mejor marca válida (aciertos) de una habilidad, a partir de las sesiones
/// de contrarreloj sincronizadas o guardadas en el dispositivo.
int? mejorMarcaValida(Iterable<SessionRecord> sesiones, String skillId) {
  int? mejor;
  for (final s in sesiones) {
    if (s.mode != SessionMode.timetrial || s.skillId != skillId || !s.completed) continue;
    final r = s.summary;
    if (r == null || r.valid != true || r.cancelled == true) continue;
    if (mejor == null || r.correct > mejor) mejor = r.correct;
  }
  return mejor;
}

/// Precisión de la mejor marca válida (para la pantalla de selección).
SessionRecord? sesionMejorMarca(Iterable<SessionRecord> sesiones, String skillId) {
  SessionRecord? mejor;
  for (final s in sesiones) {
    if (s.mode != SessionMode.timetrial || s.skillId != skillId || !s.completed) continue;
    final r = s.summary;
    if (r == null || r.valid != true || r.cancelled == true) continue;
    if (mejor == null || r.correct > mejor.summary!.correct) mejor = s;
  }
  return mejor;
}

/// Variantes de una habilidad aptas para el contrarreloj, barajadas.
List<Variant> variantesCrono(ContenidoCargado c, String skillId, Random azar) {
  final out = <Variant>[];
  for (final it in c.itinerarios.values) {
    for (final v in it.variants) {
      if (v.skillId != skillId || c.revocaciones.retirada(v)) continue;
      final tipo = c.tipo(v.exerciseTypeId);
      final bloque = tipo?.steps.firstOrNull?.response;
      if (!bloquesCrono.contains(bloque)) continue;
      if (motivoDefecto(v, tipo) != null) continue;
      out.add(v);
    }
  }
  out.shuffle(azar);
  return out;
}

/// Fallo mostrado durante 1,2 s con la respuesta correcta.
class FalloCrono {
  const FalloCrono({required this.variante, required this.correcta, required this.respuesta});
  final Variant variante;
  final String correcta;
  final String respuesta;
}

/// Controla un esprint (o una serie sin cuenta atrás): presenta ejercicios de
/// una sola habilidad, corrige, registra intentos en modo contrarreloj (los
/// fallos pasan al repaso por proyección) y produce la marca.
class ControladorCrono {
  ControladorCrono({
    required this.contenido,
    required this.skillId,
    required this.deviceId,
    required this.relojMs,
    required this.ahora,
    required this.sinCuentaAtras,
    required this.variantes,
    this.mejorMarca,
    this.alRegistrar,
  });

  final ContenidoCargado contenido;
  final String skillId;
  final String deviceId;
  final int Function() relojMs;
  final DateTime Function() ahora;
  final bool sinCuentaAtras;
  final List<Variant> variantes;
  final int? mejorMarca;
  final void Function(Attempt a)? alRegistrar;

  final String sessionId = nuevoId();
  late final DateTime _inicio;
  late final int _inicioMs;
  Esprint? esprint;
  SerieSinLimite? serie;
  int _indice = 0;
  int _presentadoMs = 0;
  final List<FalloCrono> fallos = [];
  final List<Attempt> intentos = [];

  /// Fallo que se está mostrando (1,2 s) antes del ejercicio siguiente.
  FalloCrono? mostrando;

  SessionMode get modo => sinCuentaAtras ? SessionMode.timetrialUntimed : SessionMode.timetrial;

  void empezar() {
    _inicio = ahora();
    _inicioMs = relojMs();
    _presentadoMs = _inicioMs;
    if (sinCuentaAtras) {
      serie = SerieSinLimite(ejercicios: min(ejerciciosSerieSinLimite, max(1, variantes.length)), inicioMs: _inicioMs);
    } else {
      esprint = Esprint(inicioMs: _inicioMs, mejorMarcaValida: mejorMarca);
    }
  }

  Variant get actual => variantes[_indice % variantes.length];

  String get bloque => contenido.tipo(actual.exerciseTypeId)?.steps.firstOrNull?.response ?? 'numeric_unit';

  int restanteMs() => esprint?.restanteMs(relojMs()) ?? 0;

  bool get terminado => esprint != null ? esprint!.terminado(relojMs()) : serie!.terminada;

  bool get anulado => esprint?.anulado ?? serie!.resultado().anulado;

  int get aciertos => esprint?.aciertos ?? serie!.resultado().aciertos;

  double get multiplicador => esprint?.multiplicador ?? 1;

  int get respondidos => esprint != null ? esprint!.aciertos + esprint!.fallos : serie!.respondidos;

  /// Respuesta numérica con coma decimal.
  bool responderNumerico(String raw) {
    final v = actual;
    final g = grade(v.answer!, v.predictedErrors, GradeInput(raw, unit: v.answer!.unit));
    return _registrar(
      correcto: isCorrectVerdict(g.verdict),
      verdict: g.verdict,
      valor: g.value,
      unidad: g.unit ?? v.answer!.unit,
      errorCode: g.errorCode,
      critico: g.critical,
      correcta: g.correctDisplay,
      respuesta: raw.isEmpty ? '—' : formatQty(raw.replaceAll(',', '.'), v.answer!.unit),
    );
  }

  bool responderOpcion(String id) {
    final v = actual;
    final g = gradeChoice(v.options!, id);
    final elegida = v.options!.where((o) => o.id == id).firstOrNull;
    return _registrar(
      correcto: isCorrectVerdict(g.verdict),
      verdict: g.verdict,
      valor: elegida?.value,
      unidad: elegida?.unit,
      errorCode: g.errorCode,
      critico: g.critical,
      correcta: v.options!.firstWhere((o) => o.correct).label,
      respuesta: elegida?.label ?? '—',
      payload: {'optionId': id},
    );
  }

  bool _registrar({
    required bool correcto,
    required Verdict verdict,
    required String correcta,
    required String respuesta,
    String? valor,
    String? unidad,
    String? errorCode,
    bool critico = false,
    Object? payload,
  }) {
    final ms = relojMs();
    final ok = esprint != null ? esprint!.responder(correcto: correcto, ahoraMs: ms) : serie!.responder(correcto: correcto, ahoraMs: ms);
    if (!ok) return false;
    final v = actual;
    final a = Attempt(
      id: nuevoId(),
      sessionId: sessionId,
      deviceId: deviceId,
      mode: modo,
      templateId: v.templateId,
      questionId: v.questionId,
      variantId: v.id,
      skillId: v.skillId,
      exerciseTypeId: v.exerciseTypeId,
      level: v.level,
      answerValue: valor,
      answerUnit: unidad,
      answerPayload: payload,
      verdict: verdict,
      errorCode: errorCode,
      critical: critico,
      responseMs: max(0, ms - _presentadoMs),
      targetMs: v.targetTimeS * 1000,
      points: correcto ? (esprint == null ? 0 : puntosPorAcierto) : 0,
      contentVersion: contenido.version,
      deviceTime: ahora(),
    );
    intentos.add(a);
    alRegistrar?.call(a);
    if (correcto) {
      _siguiente();
    } else {
      final f = FalloCrono(variante: v, correcta: correcta, respuesta: respuesta);
      fallos.add(f);
      mostrando = f;
    }
    return true;
  }

  /// Tras mostrar la respuesta correcta 1,2 s, se presenta el siguiente.
  void cerrarFallo() {
    if (mostrando == null) return;
    mostrando = null;
    _siguiente();
  }

  void _siguiente() {
    _indice++;
    _presentadoMs = relojMs();
    esprint?.presentarSiguiente(_presentadoMs);
    serie?.presentarSiguiente(_presentadoMs);
  }

  /// La app pasa a segundo plano: el esprint se anula y no hay marca.
  void interrumpir() {
    esprint?.interrumpir();
    serie?.interrumpir();
  }

  ResultadoContrarreloj resultado() => esprint?.resultado() ?? serie!.resultado();

  /// Registro de la sesión con la marca (válida con precisión ≥ 90 %).
  SessionRecord registro() {
    final r = resultado();
    final duracion = relojMs() - _inicioMs;
    return SessionRecord(
      id: sessionId,
      deviceId: deviceId,
      mode: modo,
      skillId: skillId,
      startedAt: _inicio,
      endedAt: ahora(),
      completed: !r.anulado,
      practiceMs: max(0, duracion),
      contentVersion: contenido.version,
      summary: SessionSummary(
        correct: r.aciertos,
        total: r.total,
        errors: r.fallos,
        accuracy: r.total == 0 ? 0 : r.aciertos / r.total,
        valid: !sinCuentaAtras && r.valida,
        cancelled: r.anulado,
        avgMs: r.tiempoMedioMs,
      ),
    );
  }
}
