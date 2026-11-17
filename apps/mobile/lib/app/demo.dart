import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/domain/ids.dart';
import '../core/domain/learning_models.dart';
import 'dependencias.dart';
import 'estado/ajustes.dart';
import 'estado/estado_app.dart';

/// Modo de demostración para capturas (solo en depuración y con
/// `--dart-define=VTM_DEMO=1`): siembra un perfil local con el alta hecha y
/// unos días de práctica sobre el contenido incluido. `VTM_RUTA` abre una
/// pantalla concreta y `VTM_TEMA=oscuro` fuerza el tema oscuro.
const _demo = String.fromEnvironment('VTM_DEMO');
const modoDemo = _demo == '1' || _demo == 'true';
const rutaDemo = String.fromEnvironment('VTM_RUTA');
const temaDemo = String.fromEnvironment('VTM_TEMA');

Future<void> sembrarDemo(Dependencias deps) async {
  if (!kDebugMode || !modoDemo) return;
  final ajustes = Ajustes(tema: temaDemo == 'oscuro' ? ThemeMode.dark : ThemeMode.light);
  await deps.claves.escribirJson(claveAjustes, ajustes.toJson());
  if (await deps.claves.leer(claveUsuario) != null) return;
  final ahora = deps.reloj.ahora();
  final usuario = EstadoUsuario(
    deviceId: 'demo-${nuevoId()}',
    altaCompletada: true,
    primeraLeccionAt: ahora.subtract(const Duration(days: 9)),
    notificacionesOfrecidas: true,
    perfil: UserProfile(
      id: 'local-demo',
      alias: 'BuretaClara24',
      sectorId: 'enfermeria',
      itineraryId: 'it-fundamentos',
      declaredLevel: 'afianzar',
      goal: const Goal.daily(10),
      disclaimerAcceptedAt: ahora.subtract(const Duration(days: 10)),
      createdAt: ahora.subtract(const Duration(days: 10)),
    ),
  );
  await deps.claves.escribirJson(claveUsuario, usuario.toJson());

  // Unos días de práctica con variantes reales: unidad 1 superada y unidad 2
  // a medias, con algunos fallos que van al repaso.
  final contenido = await deps.repositorio.cargar();
  final it = contenido.fundamentos;
  if (it == null) return;
  final lecciones = it.lessons.where((l) => l.unitId == 'u-f-1' || (l.unitId == 'u-f-2' && l.order <= 2)).toList()
    ..sort((a, b) => a.unitId == b.unitId ? a.order.compareTo(b.order) : a.unitId.compareTo(b.unitId));
  final intentos = <Attempt>[];
  final sesiones = <SessionRecord>[];
  for (var i = 0; i < lecciones.length; i++) {
    final l = lecciones[i];
    final inicio = ahora.subtract(Duration(days: lecciones.length - i, hours: 2));
    final sid = nuevoId();
    var aciertos = 0;
    var t = inicio;
    for (final (j, s) in l.slots.indexed) {
      final vs = contenido.variantes(s.templateId ?? s.questionId ?? '', s.difficulty);
      if (vs.isEmpty) continue;
      final v = vs[(i + j) % vs.length];
      final ok = (i + j) % 7 != 3;
      if (ok) aciertos++;
      t = t.add(const Duration(seconds: 25));
      intentos.add(Attempt(
        id: nuevoId(),
        sessionId: sid,
        deviceId: usuario.deviceId,
        mode: l.kind.name == 'challenge' ? SessionMode.challenge : SessionMode.lesson,
        lessonId: l.id,
        templateId: v.templateId,
        questionId: v.questionId,
        variantId: v.id,
        skillId: v.skillId,
        exerciseTypeId: v.exerciseTypeId,
        level: v.level,
        answerValue: v.answer?.value,
        answerUnit: v.answer?.unit,
        verdict: ok ? Verdict.correct : Verdict.incorrect,
        errorCode: ok ? null : 'E2',
        critical: !ok && j.isEven,
        responseMs: 12000 + 1000 * (j % 5),
        targetMs: v.targetTimeS * 1000,
        points: ok ? 10 : 0,
        contentVersion: contenido.version,
        deviceTime: t,
      ));
    }
    final total = l.slots.length;
    sesiones.add(SessionRecord(
      id: sid,
      deviceId: usuario.deviceId,
      mode: l.kind.name == 'challenge' ? SessionMode.challenge : SessionMode.lesson,
      lessonId: l.id,
      startedAt: inicio,
      endedAt: t,
      completed: true,
      practiceMs: t.difference(inicio).inMilliseconds + 120000,
      contentVersion: contenido.version,
      summary: SessionSummary(
        correct: aciertos,
        total: total,
        errors: total - aciertos,
        accuracy: total == 0 ? 0 : aciertos / total,
        passed: l.kind.name == 'challenge' ? true : null,
        convalidatedUnitIds: l.kind.name == 'challenge' ? [l.unitId] : null,
      ),
    ));
  }
  await deps.aprendizaje.fusionar(intentos, sesiones);
}
