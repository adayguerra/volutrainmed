/// Modelos de aprendizaje que suben del dispositivo (espejo de
/// `packages/contracts`): intentos, sesiones, eventos, perfil y derechos.
///
/// El intento es la fuente de verdad (diseño D5): solo se añaden. Fichas de
/// repaso, estados de habilidad, rachas y progreso son proyecciones.
library;

typedef Json = Map<String, dynamic>;

enum SessionMode { lesson, challenge, review, warmup, placement, timetrial, timetrialUntimed, handsfree, practice }

const _modeWire = {
  SessionMode.lesson: 'lesson',
  SessionMode.challenge: 'challenge',
  SessionMode.review: 'review',
  SessionMode.warmup: 'warmup',
  SessionMode.placement: 'placement',
  SessionMode.timetrial: 'timetrial',
  SessionMode.timetrialUntimed: 'timetrial_untimed',
  SessionMode.handsfree: 'handsfree',
  SessionMode.practice: 'practice',
};

String sessionModeWire(SessionMode m) => _modeWire[m]!;
SessionMode sessionModeFrom(String s) =>
    _modeWire.entries.firstWhere((e) => e.value == s, orElse: () => const MapEntry(SessionMode.practice, 'practice')).key;

enum Verdict { correct, correctNote, incorrect, dontKnow, skipped }

const _verdictWire = {
  Verdict.correct: 'correct',
  Verdict.correctNote: 'correct_note',
  Verdict.incorrect: 'incorrect',
  Verdict.dontKnow: 'dont_know',
  Verdict.skipped: 'skipped',
};

String verdictWire(Verdict v) => _verdictWire[v]!;
Verdict verdictFrom(String s) =>
    _verdictWire.entries.firstWhere((e) => e.value == s, orElse: () => const MapEntry(Verdict.incorrect, 'incorrect')).key;

/// Correcta o correcta con observación.
bool isCorrectVerdict(Verdict v) => v == Verdict.correct || v == Verdict.correctNote;

enum InputMode { touch, keyboard, voice }

InputMode inputModeFrom(String s) => InputMode.values.firstWhere((m) => m.name == s, orElse: () => InputMode.touch);

class VoiceMetrics {
  const VoiceMetrics({required this.asrMs, required this.confidence, required this.recognitionFailures});
  final int asrMs;
  final double confidence;
  final int recognitionFailures;
  Json toJson() => {'asrMs': asrMs, 'confidence': confidence, 'recognitionFailures': recognitionFailures};
  factory VoiceMetrics.fromJson(Json j) => VoiceMetrics(
        asrMs: (j['asrMs'] as num?)?.toInt() ?? 0,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
        recognitionFailures: (j['recognitionFailures'] as num?)?.toInt() ?? 0,
      );
}

class Attempt {
  const Attempt({
    required this.id,
    required this.sessionId,
    required this.deviceId,
    required this.mode,
    this.lessonId,
    this.templateId,
    this.questionId,
    required this.variantId,
    required this.skillId,
    required this.exerciseTypeId,
    required this.level,
    this.attemptNumber = 1,
    this.answerValue,
    this.answerUnit,
    this.answerPayload,
    required this.verdict,
    this.errorCode,
    this.critical = false,
    this.hintsUsed = 0,
    required this.responseMs,
    required this.targetMs,
    this.inputMode = InputMode.touch,
    this.voiceMetrics,
    this.points = 0,
    required this.contentVersion,
    required this.deviceTime,
  });

  final String id;
  final String sessionId;
  final String deviceId;
  final SessionMode mode;
  final String? lessonId;
  final String? templateId;
  final String? questionId;
  final String variantId;
  final String skillId;
  final String exerciseTypeId;
  final int level;

  /// 1 = primer intento; 2 = segundo intento con otra variante (no puntúa).
  final int attemptNumber;
  final String? answerValue;
  final String? answerUnit;
  final Object? answerPayload;
  final Verdict verdict;
  final String? errorCode;
  final bool critical;
  final int hintsUsed;

  /// Tiempo activo desde la presentación hasta el envío, sin pausas ni anuncios.
  final int responseMs;
  final int targetMs;
  final InputMode inputMode;
  final VoiceMetrics? voiceMetrics;
  final int points;
  final String contentVersion;
  final DateTime deviceTime;

  bool get correct => isCorrectVerdict(verdict);

  /// Clave de la ficha de repaso: plantilla (o pregunta) en su nivel.
  String get cardKey => '${templateId ?? questionId ?? variantId}@$level';

  Json toJson() => {
        'id': id,
        'sessionId': sessionId,
        'deviceId': deviceId,
        'mode': sessionModeWire(mode),
        'lessonId': lessonId,
        'templateId': templateId,
        'questionId': questionId,
        'variantId': variantId,
        'skillId': skillId,
        'exerciseTypeId': exerciseTypeId,
        'level': level,
        'attemptNumber': attemptNumber,
        'answerValue': answerValue,
        'answerUnit': answerUnit,
        if (answerPayload != null) 'answerPayload': answerPayload,
        'verdict': verdictWire(verdict),
        'errorCode': errorCode,
        'critical': critical,
        'hintsUsed': hintsUsed,
        'responseMs': responseMs,
        'targetMs': targetMs,
        'inputMode': inputMode.name,
        'voiceMetrics': voiceMetrics?.toJson(),
        'points': points,
        'contentVersion': contentVersion,
        'deviceTime': deviceTime.toUtc().toIso8601String(),
      };

  factory Attempt.fromJson(Json j) => Attempt(
        id: '${j['id']}',
        sessionId: '${j['sessionId']}',
        deviceId: '${j['deviceId'] ?? ''}',
        mode: sessionModeFrom('${j['mode']}'),
        lessonId: j['lessonId'] as String?,
        templateId: j['templateId'] as String?,
        questionId: j['questionId'] as String?,
        variantId: '${j['variantId']}',
        skillId: '${j['skillId']}',
        exerciseTypeId: '${j['exerciseTypeId'] ?? 'T1'}',
        level: (j['level'] as num?)?.toInt() ?? 1,
        attemptNumber: (j['attemptNumber'] as num?)?.toInt() ?? 1,
        answerValue: j['answerValue'] as String?,
        answerUnit: j['answerUnit'] as String?,
        answerPayload: j['answerPayload'],
        verdict: verdictFrom('${j['verdict']}'),
        errorCode: j['errorCode'] as String?,
        critical: j['critical'] == true,
        hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
        responseMs: (j['responseMs'] as num?)?.toInt() ?? 0,
        targetMs: (j['targetMs'] as num?)?.toInt() ?? 30000,
        inputMode: inputModeFrom('${j['inputMode'] ?? 'touch'}'),
        voiceMetrics: j['voiceMetrics'] is Map ? VoiceMetrics.fromJson((j['voiceMetrics'] as Map).cast<String, dynamic>()) : null,
        points: (j['points'] as num?)?.toInt() ?? 0,
        contentVersion: '${j['contentVersion'] ?? ''}',
        deviceTime: DateTime.parse('${j['deviceTime']}'),
      );
}

class SessionSummary {
  const SessionSummary({
    required this.correct,
    required this.total,
    required this.errors,
    required this.accuracy,
    this.valid,
    this.cancelled,
    this.avgMs,
    this.passed,
    this.convalidatedUnitIds,
    this.entryUnitId,
  });
  final int correct;
  final int total;
  final int errors;
  final double accuracy;
  final bool? valid;
  final bool? cancelled;
  final int? avgMs;

  /// Reto de unidad superado (9 de 10 sin críticos). Extensión de la app.
  final bool? passed;

  /// Unidades convalidadas por la prueba de nivel o por el reto. Se derivan de
  /// lo sincronizado para que un dispositivo nuevo las recupere.
  final List<String>? convalidatedUnitIds;
  final String? entryUnitId;

  Json toJson() => {
        'correct': correct,
        'total': total,
        'errors': errors,
        'accuracy': accuracy,
        if (valid != null) 'valid': valid,
        if (cancelled != null) 'cancelled': cancelled,
        if (avgMs != null) 'avgMs': avgMs,
        if (passed != null) 'passed': passed,
        if (convalidatedUnitIds != null) 'convalidatedUnitIds': convalidatedUnitIds,
        if (entryUnitId != null) 'entryUnitId': entryUnitId,
      };

  factory SessionSummary.fromJson(Json j) => SessionSummary(
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] as num?)?.toInt() ?? 0,
        accuracy: (j['accuracy'] as num?)?.toDouble() ?? 0,
        valid: j['valid'] as bool?,
        cancelled: j['cancelled'] as bool?,
        avgMs: (j['avgMs'] as num?)?.toInt(),
        passed: j['passed'] as bool?,
        convalidatedUnitIds: (j['convalidatedUnitIds'] as List?)?.map((e) => '$e').toList(),
        entryUnitId: j['entryUnitId'] as String?,
      );
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.deviceId,
    required this.mode,
    this.lessonId,
    this.skillId,
    required this.startedAt,
    required this.endedAt,
    required this.completed,
    required this.practiceMs,
    this.adMs = 0,
    this.inputMode = InputMode.touch,
    required this.contentVersion,
    this.summary,
  });
  final String id;
  final String deviceId;
  final SessionMode mode;
  final String? lessonId;
  final String? skillId;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool completed;

  /// Tiempo de práctica activo, sin pausas ni pausas promocionales (D7).
  final int practiceMs;
  final int adMs;
  final InputMode inputMode;
  final String contentVersion;
  final SessionSummary? summary;

  Json toJson() => {
        'id': id,
        'deviceId': deviceId,
        'mode': sessionModeWire(mode),
        'lessonId': lessonId,
        'skillId': skillId,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'completed': completed,
        'practiceMs': practiceMs,
        'adMs': adMs,
        'inputMode': inputMode.name,
        'contentVersion': contentVersion,
        if (summary != null) 'summary': summary!.toJson(),
      };

  factory SessionRecord.fromJson(Json j) => SessionRecord(
        id: '${j['id']}',
        deviceId: '${j['deviceId'] ?? ''}',
        mode: sessionModeFrom('${j['mode']}'),
        lessonId: j['lessonId'] as String?,
        skillId: j['skillId'] as String?,
        startedAt: DateTime.parse('${j['startedAt']}'),
        endedAt: DateTime.parse('${j['endedAt']}'),
        completed: j['completed'] == true,
        practiceMs: (j['practiceMs'] as num?)?.toInt() ?? 0,
        adMs: (j['adMs'] as num?)?.toInt() ?? 0,
        inputMode: inputModeFrom('${j['inputMode'] ?? 'touch'}'),
        contentVersion: '${j['contentVersion'] ?? ''}',
        summary: j['summary'] is Map ? SessionSummary.fromJson((j['summary'] as Map).cast<String, dynamic>()) : null,
      );
}

class AnalyticsEvent {
  const AnalyticsEvent({required this.id, required this.name, required this.at, this.props = const {}});
  final String id;
  final String name;
  final DateTime at;
  final Map<String, Object?> props;
  Json toJson() => {'id': id, 'name': name, 'at': at.toUtc().toIso8601String(), 'props': props};
  factory AnalyticsEvent.fromJson(Json j) => AnalyticsEvent(
        id: '${j['id']}',
        name: '${j['name']}',
        at: DateTime.parse('${j['at']}'),
        props: ((j['props'] as Map?) ?? const {}).cast<String, Object?>(),
      );
}

// ---------------------------------------------------------------------------
// Perfil, meta y derechos
// ---------------------------------------------------------------------------

enum GoalKind { daily, weekly }

class Goal {
  const Goal.daily(int this.minutes)
      : kind = GoalKind.daily,
        days = null;
  const Goal.weekly(int this.days)
      : kind = GoalKind.weekly,
        minutes = null;
  final GoalKind kind;
  final int? minutes;
  final int? days;
  Json toJson() => {'kind': kind.name, if (minutes != null) 'minutes': minutes, if (days != null) 'days': days};
  factory Goal.fromJson(Json j) => j['kind'] == 'weekly'
      ? Goal.weekly((j['days'] as num?)?.toInt() ?? 4)
      : Goal.daily((j['minutes'] as num?)?.toInt() ?? 5);
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.email,
    required this.alias,
    this.sectorId,
    this.itineraryId,
    this.declaredLevel,
    this.goal,
    this.disclaimerAcceptedAt,
    this.leaguesOptIn = true,
    required this.createdAt,
  });
  final String id;
  final String? email;
  final String alias;
  final String? sectorId;
  final String? itineraryId;
  final String? declaredLevel;
  final Goal? goal;
  final DateTime? disclaimerAcceptedAt;
  final bool leaguesOptIn;
  final DateTime createdAt;

  UserProfile copyWith({
    String? id,
    String? email,
    String? alias,
    String? sectorId,
    String? itineraryId,
    String? declaredLevel,
    Goal? goal,
    DateTime? disclaimerAcceptedAt,
    bool? leaguesOptIn,
  }) =>
      UserProfile(
        id: id ?? this.id,
        email: email ?? this.email,
        alias: alias ?? this.alias,
        sectorId: sectorId ?? this.sectorId,
        itineraryId: itineraryId ?? this.itineraryId,
        declaredLevel: declaredLevel ?? this.declaredLevel,
        goal: goal ?? this.goal,
        disclaimerAcceptedAt: disclaimerAcceptedAt ?? this.disclaimerAcceptedAt,
        leaguesOptIn: leaguesOptIn ?? this.leaguesOptIn,
        createdAt: createdAt,
      );

  Json toJson() => {
        'id': id,
        'email': email,
        'alias': alias,
        'sectorId': sectorId,
        'itineraryId': itineraryId,
        'declaredLevel': declaredLevel,
        'goal': goal?.toJson(),
        'disclaimerAcceptedAt': disclaimerAcceptedAt?.toUtc().toIso8601String(),
        'leaguesOptIn': leaguesOptIn,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory UserProfile.fromJson(Json j) => UserProfile(
        id: '${j['id']}',
        email: j['email'] as String?,
        alias: '${j['alias'] ?? ''}',
        sectorId: j['sectorId'] as String?,
        itineraryId: j['itineraryId'] as String?,
        declaredLevel: j['declaredLevel'] as String?,
        goal: j['goal'] is Map ? Goal.fromJson((j['goal'] as Map).cast<String, dynamic>()) : null,
        disclaimerAcceptedAt: j['disclaimerAcceptedAt'] == null ? null : DateTime.tryParse('${j['disclaimerAcceptedAt']}'),
        leaguesOptIn: j['leaguesOptIn'] != false,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now().toUtc(),
      );
}

class OrganizationRef {
  const OrganizationRef({required this.id, required this.name, required this.nominal});
  final String id;
  final String name;
  final bool nominal;
  Json toJson() => {'id': id, 'name': name, 'nominal': nominal};
  factory OrganizationRef.fromJson(Json j) => OrganizationRef(id: '${j['id']}', name: '${j['name']}', nominal: j['nominal'] == true);
}

class Entitlements {
  const Entitlements({
    this.premium = false,
    this.noAds = false,
    this.source = 'none',
    this.plan,
    this.status = 'none',
    this.expiresAt,
    this.renewsAt,
    this.trialUsed = false,
    this.trialEndsAt,
    required this.validatedAt,
    this.organization,
  });
  final bool premium;
  final bool noAds;
  final String source;
  final String? plan;
  final String status;
  final DateTime? expiresAt;
  final DateTime? renewsAt;
  final bool trialUsed;
  final DateTime? trialEndsAt;
  final DateTime validatedAt;
  final OrganizationRef? organization;

  static Entitlements none(DateTime at) => Entitlements(validatedAt: at);

  Json toJson() => {
        'premium': premium,
        'noAds': noAds,
        'source': source,
        'plan': plan,
        'status': status,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'renewsAt': renewsAt?.toUtc().toIso8601String(),
        'trialUsed': trialUsed,
        'trialEndsAt': trialEndsAt?.toUtc().toIso8601String(),
        'validatedAt': validatedAt.toUtc().toIso8601String(),
        'organization': organization?.toJson(),
      };

  factory Entitlements.fromJson(Json j) => Entitlements(
        premium: j['premium'] == true,
        noAds: j['noAds'] == true,
        source: '${j['source'] ?? 'none'}',
        plan: j['plan'] as String?,
        status: '${j['status'] ?? 'none'}',
        expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse('${j['expiresAt']}'),
        renewsAt: j['renewsAt'] == null ? null : DateTime.tryParse('${j['renewsAt']}'),
        trialUsed: j['trialUsed'] == true,
        trialEndsAt: j['trialEndsAt'] == null ? null : DateTime.tryParse('${j['trialEndsAt']}'),
        validatedAt: DateTime.tryParse('${j['validatedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        organization: j['organization'] is Map ? OrganizationRef.fromJson((j['organization'] as Map).cast<String, dynamic>()) : null,
      );
}

class StoreProduct {
  const StoreProduct({required this.id, required this.plan, required this.price, required this.currency, required this.period, required this.trialDays});
  final String id;
  final String plan;
  final String price;
  final String currency;
  final String period;
  final int trialDays;
  factory StoreProduct.fromJson(Json j) => StoreProduct(
        id: '${j['id']}',
        plan: '${j['plan']}',
        price: '${j['price']}',
        currency: '${j['currency'] ?? 'EUR'}',
        period: '${j['period']}',
        trialDays: (j['trialDays'] as num?)?.toInt() ?? 0,
      );
  Json toJson() => {'id': id, 'plan': plan, 'price': price, 'currency': currency, 'period': period, 'trialDays': trialDays};
}

const disclaimerText = 'VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.';
const noPatientQueriesText = 'No respondemos consultas sobre pacientes ni tratamientos';
