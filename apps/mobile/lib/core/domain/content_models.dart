/// Modelos del paquete de contenido firmado (espejo de `packages/contracts`).
///
/// Dominio puro Dart: sin dependencias de Flutter. Las cifras viajan como
/// cadenas decimales con punto ("0.96") y nunca se convierten a `double`.
/// Los constructores `fromJson` son tolerantes: los campos opcionales que un
/// tipo de ejercicio no usa (p. ej. `answer` en T3 o T7) pueden faltar.
library;

typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? v, T Function(Json) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

List<String> _strings(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];

String _s(Object? v, [String d = '']) => v == null ? d : '$v';

int _i(Object? v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? d);

bool _b(Object? v, [bool d = false]) => v is bool ? v : d;

// ---------------------------------------------------------------------------
// Catálogos y estructura
// ---------------------------------------------------------------------------

class Skill {
  const Skill({required this.id, required this.name, this.description});
  final String id;
  final String name;
  final String? description;
  factory Skill.fromJson(Json j) => Skill(id: _s(j['id']), name: _s(j['name']), description: j['description'] as String?);
}

class Sector {
  const Sector({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.icon,
    required this.typicalCalcs,
    required this.defaultItineraryId,
    required this.itineraryIds,
    required this.order,
  });
  final String id;
  final String code;
  final String name;
  final String description;
  final String icon;
  final String typicalCalcs;
  final String? defaultItineraryId;
  final List<String> itineraryIds;
  final int order;
  factory Sector.fromJson(Json j) => Sector(
        id: _s(j['id']),
        code: _s(j['code']),
        name: _s(j['name']),
        description: _s(j['description']),
        icon: _s(j['icon']),
        typicalCalcs: _s(j['typicalCalcs']),
        defaultItineraryId: j['defaultItineraryId'] as String?,
        itineraryIds: _strings(j['itineraryIds']),
        order: _i(j['order']),
      );
}

class ItinerarySummary {
  const ItinerarySummary({
    required this.id,
    required this.sectorId,
    required this.name,
    required this.description,
    required this.recommendedLevel,
    required this.order,
    required this.isFoundations,
  });
  final String id;
  final String sectorId;
  final String name;
  final String description;
  final String recommendedLevel;
  final int order;
  final bool isFoundations;
  factory ItinerarySummary.fromJson(Json j) => ItinerarySummary(
        id: _s(j['id']),
        sectorId: _s(j['sectorId']),
        name: _s(j['name']),
        description: _s(j['description']),
        recommendedLevel: _s(j['recommendedLevel'], 'cero'),
        order: _i(j['order']),
        isFoundations: _b(j['isFoundations']),
      );
}

enum LessonKind { guided, supported, free, mixed, challenge }

LessonKind lessonKindFrom(String s) =>
    LessonKind.values.firstWhere((k) => k.name == s, orElse: () => LessonKind.free);

const lessonKindLabel = {
  LessonKind.guided: 'Concepto guiado',
  LessonKind.supported: 'Práctica con apoyos',
  LessonKind.free: 'Práctica libre',
  LessonKind.mixed: 'Mixta',
  LessonKind.challenge: 'Reto de unidad',
};

class UnitGuide {
  const UnitGuide({required this.equivalences, required this.exampleStatement, required this.exampleSteps, required this.exampleAnswer});
  final List<String> equivalences;
  final String exampleStatement;
  final List<String> exampleSteps;
  final String exampleAnswer;
  factory UnitGuide.fromJson(Json? j) {
    final ex = (j?['example'] as Map?)?.cast<String, dynamic>() ?? const {};
    return UnitGuide(
      equivalences: _strings(j?['equivalences']),
      exampleStatement: _s(ex['statement']),
      exampleSteps: _strings(ex['steps']),
      exampleAnswer: _s(ex['answer']),
    );
  }
}

class Unit {
  const Unit({
    required this.id,
    required this.itineraryId,
    required this.order,
    required this.name,
    required this.description,
    required this.skills,
    required this.prerequisiteUnitId,
    required this.guide,
  });
  final String id;
  final String itineraryId;
  final int order;
  final String name;
  final String description;
  final List<String> skills;
  final String? prerequisiteUnitId;
  final UnitGuide guide;
  factory Unit.fromJson(Json j) => Unit(
        id: _s(j['id']),
        itineraryId: _s(j['itineraryId']),
        order: _i(j['order']),
        name: _s(j['name']),
        description: _s(j['description']),
        skills: _strings(j['skills']),
        prerequisiteUnitId: j['prerequisiteUnitId'] as String?,
        guide: UnitGuide.fromJson((j['guide'] as Map?)?.cast<String, dynamic>()),
      );
}

class LessonSlot {
  const LessonSlot({required this.position, this.templateId, this.questionId, required this.difficulty, required this.skillId});
  final int position;
  final String? templateId;
  final String? questionId;
  final int difficulty;
  final String skillId;
  factory LessonSlot.fromJson(Json j) => LessonSlot(
        position: _i(j['position']),
        templateId: j['templateId'] as String?,
        questionId: j['questionId'] as String?,
        difficulty: _i(j['difficulty'], 1).clamp(1, 5),
        skillId: _s(j['skillId']),
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.unitId,
    required this.order,
    required this.kind,
    required this.title,
    required this.estimatedMinutes,
    required this.slots,
  });
  final String id;
  final String unitId;
  final int order;
  final LessonKind kind;
  final String title;
  final int estimatedMinutes;
  final List<LessonSlot> slots;
  factory Lesson.fromJson(Json j) => Lesson(
        id: _s(j['id']),
        unitId: _s(j['unitId']),
        order: _i(j['order']),
        kind: lessonKindFrom(_s(j['kind'])),
        title: _s(j['title']),
        estimatedMinutes: _i(j['estimatedMinutes'], 4),
        slots: _list(j['slots'], LessonSlot.fromJson)..sort((a, b) => a.position.compareTo(b.position)),
      );
}

// ---------------------------------------------------------------------------
// Tipos de ejercicio por bloques (intérprete genérico, diseño D9)
// ---------------------------------------------------------------------------

class ExerciseTypeStep {
  const ExerciseTypeStep({required this.presentation, required this.response, required this.grading});
  final List<String> presentation;
  final String response;
  final String grading;
  factory ExerciseTypeStep.fromJson(Json j) => ExerciseTypeStep(
        presentation: _strings(j['presentation']),
        response: _s(j['response']),
        grading: _s(j['grading']),
      );
}

class ExerciseType {
  const ExerciseType({
    required this.id,
    required this.version,
    required this.name,
    required this.description,
    required this.steps,
    required this.behaviour,
    required this.voiceCompatible,
    required this.minAppVersion,
    this.timeLimitS,
  });
  final String id;
  final int version;
  final String name;
  final String description;
  final List<ExerciseTypeStep> steps;
  final List<String> behaviour;
  final bool voiceCompatible;
  final String minAppVersion;
  final int? timeLimitS;
  factory ExerciseType.fromJson(Json j) => ExerciseType(
        id: _s(j['id']),
        version: _i(j['version'], 1),
        name: _s(j['name']),
        description: _s(j['description']),
        steps: _list(j['steps'], ExerciseTypeStep.fromJson),
        behaviour: _strings(j['behaviour']),
        voiceCompatible: _b(j['voiceCompatible']),
        minAppVersion: _s(j['minAppVersion'], '1.0.0'),
        timeLimitS: j['timeLimitS'] == null ? null : _i(j['timeLimitS']),
      );
}

// ---------------------------------------------------------------------------
// Variantes resueltas
// ---------------------------------------------------------------------------

const errorLabels = {
  'E0': 'Sin clasificar',
  'E1': 'Unidad',
  'E2': 'Orden de magnitud',
  'E3': 'Operación invertida',
  'E4': 'Paso omitido',
  'E5': 'Dato equivocado',
  'E6': 'Límite no aplicado',
  'E7': 'Redondeo',
};

const criticalCodes = {'E1', 'E2', 'E6'};

sealed class Rounding {
  const Rounding();
  factory Rounding.fromJson(Json? j) {
    switch (j?['mode']) {
      case 'decimals':
        return RoundDecimals(_i(j!['places']));
      case 'instrument':
        return RoundInstrument(_s(j!['step'], '1'), _s(j['instrument']));
      case 'integer':
        return RoundInteger(j!['label'] as String?);
      default:
        return const RoundNone();
    }
  }
}

class RoundNone extends Rounding {
  const RoundNone();
}

class RoundDecimals extends Rounding {
  const RoundDecimals(this.places);
  final int places;
}

class RoundInstrument extends Rounding {
  const RoundInstrument(this.step, this.instrument);
  final String step;
  final String instrument;
}

class RoundInteger extends Rounding {
  const RoundInteger([this.label]);
  final String? label;
}

sealed class Tolerance {
  const Tolerance();
  factory Tolerance.fromJson(Json? j) {
    switch (j?['kind']) {
      case 'abs':
        return TolAbs(_s(j!['value'], '0'));
      case 'rel':
        return TolRel(_s(j!['percent'], '0'));
      default:
        return const TolExact();
    }
  }
}

class TolExact extends Tolerance {
  const TolExact();
}

class TolAbs extends Tolerance {
  const TolAbs(this.value);
  final String value;
}

class TolRel extends Tolerance {
  const TolRel(this.percent);
  final String percent;
}

class Quantity {
  const Quantity(this.value, this.unit);
  final String value;
  final String unit;
  factory Quantity.fromJson(Json? j) => Quantity(_s(j?['value'], '0'), _s(j?['unit']));
}

class UnitEquivalent {
  const UnitEquivalent(this.unit, this.factor);
  final String unit;
  final String factor;
}

class AnswerSpec {
  const AnswerSpec({
    required this.value,
    required this.unit,
    this.unitFixed = true,
    this.unitChoices = const [],
    this.equivalents = const [],
    this.rounding = const RoundNone(),
    this.tolerance = const TolExact(),
    this.unrounded,
  });
  final String value;
  final String unit;
  final bool unitFixed;
  final List<String> unitChoices;
  final List<UnitEquivalent> equivalents;
  final Rounding rounding;
  final Tolerance tolerance;
  final String? unrounded;
  factory AnswerSpec.fromJson(Json j) => AnswerSpec(
        value: _s(j['value'], '0'),
        unit: _s(j['unit']),
        unitFixed: _b(j['unitFixed'], true),
        unitChoices: _strings(j['unitChoices']),
        equivalents: _list(j['equivalents'], (e) => UnitEquivalent(_s(e['unit']), _s(e['factor'], '1'))),
        rounding: Rounding.fromJson((j['rounding'] as Map?)?.cast<String, dynamic>()),
        tolerance: Tolerance.fromJson((j['tolerance'] as Map?)?.cast<String, dynamic>()),
        unrounded: j['unrounded'] as String?,
      );
}

class PredictedError {
  const PredictedError({required this.value, required this.unit, required this.code, required this.message, this.deviationStep});
  final String value;
  final String unit;
  final String code;
  final String message;
  final int? deviationStep;
  factory PredictedError.fromJson(Json j) => PredictedError(
        value: _s(j['value'], '0'),
        unit: _s(j['unit']),
        code: _s(j['code'], 'E0'),
        message: _s(j['message']),
        deviationStep: j['deviationStep'] == null ? null : _i(j['deviationStep']),
      );
}

class ExplanationStep {
  const ExplanationStep({required this.n, required this.text, required this.operation, required this.result, required this.cancelled, this.cancelledSpoken});
  final int n;
  final String text;
  final String operation;
  final Quantity result;
  final List<String> cancelled;
  final String? cancelledSpoken;
  factory ExplanationStep.fromJson(Json j) => ExplanationStep(
        n: _i(j['n']),
        text: _s(j['text']),
        operation: _s(j['operation']),
        result: Quantity.fromJson((j['result'] as Map?)?.cast<String, dynamic>()),
        cancelled: _strings(j['cancelled']),
        cancelledSpoken: j['cancelledSpoken'] as String?,
      );
}

/// Segmento del enunciado: texto o cantidad resaltada.
class StatementSegment {
  const StatementSegment.text(this.text)
      : value = null,
        unit = null,
        key = null;
  const StatementSegment.qty(String this.value, String this.unit, [this.key]) : text = null;
  final String? text;
  final String? value;
  final String? unit;
  final String? key;
  bool get isQty => value != null;
  factory StatementSegment.fromJson(Json j) => j['t'] == 'qty'
      ? StatementSegment.qty(_s(j['value'], '0'), _s(j['unit']), j['key'] as String?)
      : StatementSegment.text(_s(j['v']));
}

class ChoiceOption {
  const ChoiceOption({required this.id, required this.label, this.value, this.unit, required this.correct, this.errorCode, this.message});
  final String id;
  final String label;
  final String? value;
  final String? unit;
  final bool correct;
  final String? errorCode;
  final String? message;
  factory ChoiceOption.fromJson(Json j) => ChoiceOption(
        id: _s(j['id']),
        label: _s(j['label']),
        value: j['value'] as String?,
        unit: j['unit'] as String?,
        correct: _b(j['correct']),
        errorCode: j['errorCode'] as String?,
        message: j['message'] as String?,
      );
}

class OrderItem {
  const OrderItem({required this.id, required this.text, this.producesUnit});
  final String id;
  final String text;
  final String? producesUnit;
  factory OrderItem.fromJson(Json j) => OrderItem(id: _s(j['id']), text: _s(j['text']), producesUnit: j['producesUnit'] as String?);
}

class ConversionItem {
  const ConversionItem({required this.prompt, required this.tts, required this.answer});
  final String prompt;
  final String tts;
  final AnswerSpec answer;
  factory ConversionItem.fromJson(Json j) => ConversionItem(
        prompt: _s(j['prompt']),
        tts: _s(j['tts']),
        answer: AnswerSpec.fromJson((j['answer'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

class ChainPart {
  const ChainPart({required this.prompt, required this.tts, required this.answer, required this.predictedErrors});
  final String prompt;
  final String tts;
  final AnswerSpec answer;
  final List<PredictedError> predictedErrors;
  factory ChainPart.fromJson(Json j) => ChainPart(
        prompt: _s(j['prompt']),
        tts: _s(j['tts']),
        answer: AnswerSpec.fromJson((j['answer'] as Map?)?.cast<String, dynamic>() ?? const {}),
        predictedErrors: _list(j['predictedErrors'], PredictedError.fromJson),
      );
}

class WorkedStep {
  const WorkedStep({required this.n, required this.text, required this.correct, this.correction});
  final int n;
  final String text;
  final bool correct;
  final String? correction;
  factory WorkedStep.fromJson(Json j) =>
      WorkedStep(n: _i(j['n']), text: _s(j['text']), correct: _b(j['correct'], true), correction: j['correction'] as String?);
}

class MatchPair {
  const MatchPair(this.left, this.right);
  final String left;
  final String right;
  factory MatchPair.fromJson(Json j) => MatchPair(_s(j['left']), _s(j['right']));
}

/// Datos de un ejercicio T4 (completar el planteamiento).
///
/// El contrato no define aún la forma de los huecos. Decisión de la app
/// (anotada en el README): `gaps` es la operación con huecos `{g1}`, `{g2}`…,
/// `tiles` las fichas disponibles (sobran algunas) y `gapAnswers` la ficha
/// correcta de cada hueco; `interchangeable` agrupa huecos intercambiables.
class GapFill {
  const GapFill({required this.template, required this.tiles, required this.gapAnswers, this.interchangeable = const []});
  final String template;
  final List<String> tiles;
  final Map<String, String> gapAnswers;
  final List<List<String>> interchangeable;
  factory GapFill.fromJson(Json j) => GapFill(
        template: _s(j['template']),
        tiles: _strings(j['tiles']),
        gapAnswers: ((j['gapAnswers'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
        interchangeable: (j['interchangeable'] is List)
            ? (j['interchangeable'] as List).map((e) => _strings(e)).toList()
            : const [],
      );
  List<String> get gapIds {
    final re = RegExp(r'\{(g\d+)\}');
    return re.allMatches(template).map((m) => m.group(1)!).toList();
  }
}

class Variant {
  const Variant({
    required this.id,
    required this.templateId,
    required this.questionId,
    required this.templateVersion,
    required this.level,
    required this.exerciseTypeId,
    required this.exerciseTypeVersion,
    required this.skillId,
    required this.sectorId,
    this.species,
    required this.statement,
    required this.question,
    required this.tts,
    this.approach,
    this.hint,
    required this.targetTimeS,
    this.answer,
    this.predictedErrors = const [],
    this.steps = const [],
    this.plausibility = '',
    this.options,
    this.orderItems,
    this.validOrders,
    this.series,
    this.chain,
    this.worked,
    this.pairs,
    this.gapFill,
    this.demo = false,
  });
  final String id;
  final String? templateId;
  final String? questionId;
  final int templateVersion;
  final int level;
  final String exerciseTypeId;
  final int exerciseTypeVersion;
  final String skillId;
  final String sectorId;
  final String? species;
  final List<StatementSegment> statement;
  final String question;
  final String tts;
  final String? approach;
  final String? hint;
  final int targetTimeS;
  final AnswerSpec? answer;
  final List<PredictedError> predictedErrors;
  final List<ExplanationStep> steps;
  final String plausibility;
  final List<ChoiceOption>? options;
  final List<OrderItem>? orderItems;
  final List<List<String>>? validOrders;
  final List<ConversionItem>? series;
  final List<ChainPart>? chain;
  final List<WorkedStep>? worked;
  final List<MatchPair>? pairs;
  final GapFill? gapFill;
  final bool demo;

  /// Clave de la ficha de repaso: plantilla (o pregunta) en un nivel.
  String get cardKey => '${templateId ?? questionId ?? id}@$level';
  String get itemKey => templateId ?? questionId ?? id;

  factory Variant.fromJson(Json j) => Variant(
        id: _s(j['id']),
        templateId: j['templateId'] as String?,
        questionId: j['questionId'] as String?,
        templateVersion: _i(j['templateVersion'], 1),
        level: _i(j['level'], 1).clamp(1, 5),
        exerciseTypeId: _s(j['exerciseTypeId'], 'T1'),
        exerciseTypeVersion: _i(j['exerciseTypeVersion'], 1),
        skillId: _s(j['skillId']),
        sectorId: _s(j['sectorId']),
        species: j['species'] as String?,
        statement: _list(j['statement'], StatementSegment.fromJson),
        question: _s(j['question']),
        tts: _s(j['tts']),
        approach: j['approach'] as String?,
        hint: j['hint'] as String?,
        targetTimeS: _i(j['targetTimeS'], 30),
        answer: j['answer'] is Map ? AnswerSpec.fromJson((j['answer'] as Map).cast<String, dynamic>()) : null,
        predictedErrors: _list(j['predictedErrors'], PredictedError.fromJson),
        steps: _list(j['steps'], ExplanationStep.fromJson),
        plausibility: _s(j['plausibility']),
        options: j['options'] is List ? _list(j['options'], ChoiceOption.fromJson) : null,
        orderItems: j['orderItems'] is List ? _list(j['orderItems'], OrderItem.fromJson) : null,
        validOrders: j['validOrders'] is List ? (j['validOrders'] as List).map(_strings).toList() : null,
        series: j['series'] is List ? _list(j['series'], ConversionItem.fromJson) : null,
        chain: j['chain'] is List ? _list(j['chain'], ChainPart.fromJson) : null,
        worked: j['worked'] is List ? _list(j['worked'], WorkedStep.fromJson) : null,
        pairs: j['pairs'] is List ? _list(j['pairs'], MatchPair.fromJson) : null,
        gapFill: j['gapFill'] is Map ? GapFill.fromJson((j['gapFill'] as Map).cast<String, dynamic>()) : null,
        demo: _b(j['demo']),
      );

  /// Texto plano del enunciado (las cantidades se escriben con coma).
  String statementText(String Function(String value, String unit) fmt) =>
      statement.map((s) => s.isQty ? fmt(s.value!, s.unit!) : s.text!).join();
}

class TemplateSummary {
  const TemplateSummary({
    required this.id,
    required this.version,
    required this.name,
    required this.skillId,
    required this.sectorId,
    required this.exerciseTypeId,
    this.species,
    required this.targetTimeS,
    required this.variantsByLevel,
  });
  final String id;
  final int version;
  final String name;
  final String skillId;
  final String sectorId;
  final String exerciseTypeId;
  final String? species;
  final Map<int, int> targetTimeS;
  final Map<int, List<String>> variantsByLevel;
  factory TemplateSummary.fromJson(Json j) => TemplateSummary(
        id: _s(j['id']),
        version: _i(j['version'], 1),
        name: _s(j['name']),
        skillId: _s(j['skillId']),
        sectorId: _s(j['sectorId']),
        exerciseTypeId: _s(j['exerciseTypeId'], 'T1'),
        species: j['species'] as String?,
        targetTimeS: ((j['targetTimeS'] as Map?) ?? const {}).map((k, v) => MapEntry(_i(k), _i(v))),
        variantsByLevel: ((j['variantsByLevel'] as Map?) ?? const {}).map((k, v) => MapEntry(_i(k), _strings(v))),
      );
}

class PlacementItem {
  const PlacementItem(this.unitId, this.variantIds);
  final String unitId;
  final List<String> variantIds;
  factory PlacementItem.fromJson(Json j) => PlacementItem(_s(j['unitId']), _strings(j['variantIds']));
}

class ItineraryPackage {
  const ItineraryPackage({
    required this.contentVersion,
    required this.minAppVersion,
    required this.itinerary,
    required this.units,
    required this.lessons,
    required this.templates,
    required this.variants,
    required this.placement,
  });
  final String contentVersion;
  final String minAppVersion;
  final ItinerarySummary itinerary;
  final List<Unit> units;
  final List<Lesson> lessons;
  final List<TemplateSummary> templates;
  final List<Variant> variants;
  final List<PlacementItem> placement;

  factory ItineraryPackage.fromJson(Json j) => ItineraryPackage(
        contentVersion: _s(j['contentVersion']),
        minAppVersion: _s(j['minAppVersion'], '1.0.0'),
        itinerary: ItinerarySummary.fromJson((j['itinerary'] as Map).cast<String, dynamic>()),
        units: _list(j['units'], Unit.fromJson)..sort((a, b) => a.order.compareTo(b.order)),
        lessons: _list(j['lessons'], Lesson.fromJson),
        templates: _list(j['templates'], TemplateSummary.fromJson),
        variants: _list(j['variants'], Variant.fromJson),
        placement: _list(j['placement'], PlacementItem.fromJson),
      );
}

// ---------------------------------------------------------------------------
// Voz, gamificación, anuncios y plan gratuito (paquete global)
// ---------------------------------------------------------------------------

class MeasureUnit {
  const MeasureUnit({required this.symbol, required this.readingSingular, required this.readingPlural, required this.gender, required this.spokenForms});
  final String symbol;
  final String readingSingular;
  final String readingPlural;
  final String gender;
  final List<String> spokenForms;
  factory MeasureUnit.fromJson(Json j) => MeasureUnit(
        symbol: _s(j['symbol']),
        readingSingular: _s(j['readingSingular']),
        readingPlural: _s(j['readingPlural']),
        gender: _s(j['gender'], 'm'),
        spokenForms: _strings(j['spokenForms']),
      );
}

class Instrument {
  const Instrument({required this.id, required this.name, required this.step, required this.unit});
  final String id;
  final String name;
  final String step;
  final String unit;
  factory Instrument.fromJson(Json j) => Instrument(id: _s(j['id']), name: _s(j['name']), step: _s(j['step'], '1'), unit: _s(j['unit']));
}

class SectorSynonym {
  const SectorSynonym({required this.sectorId, required this.spoken, required this.unit, required this.enabledByDefault});
  final String? sectorId;
  final String spoken;
  final String unit;
  final bool enabledByDefault;
}

class VoiceLexicon {
  const VoiceLexicon({this.confusions = const {}, this.commands = const {}, this.sectorSynonyms = const []});
  final Map<String, String> confusions;
  final Map<String, List<String>> commands;
  final List<SectorSynonym> sectorSynonyms;
  factory VoiceLexicon.fromJson(Json? j) => VoiceLexicon(
        confusions: {for (final c in (j?['confusions'] as List? ?? const [])) _s((c as Map)['from']): _s(c['to'])},
        commands: {for (final c in (j?['commands'] as List? ?? const [])) _s((c as Map)['command']): _strings(c['synonyms'])},
        sectorSynonyms: [
          for (final s in (j?['sectorSynonyms'] as List? ?? const []))
            SectorSynonym(
              sectorId: (s as Map)['sectorId'] as String?,
              spoken: _s(s['spoken']),
              unit: _s(s['unit']),
              enabledByDefault: _b(s['enabledByDefault']),
            ),
        ],
      );
}

class AchievementCondition {
  const AchievementCondition({required this.metric, required this.op, required this.value, required this.scope});
  final String metric;
  final String op;
  final int value;
  final String scope;
  bool evaluate(int actual) => switch (op) {
        '>' => actual > value,
        '==' => actual == value,
        _ => actual >= value,
      };
}

class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    required this.condition,
    this.secret = false,
    this.validFrom,
    this.validTo,
  });
  final String id;
  final String name;
  final String description;
  final String category;
  final String icon;
  final AchievementCondition condition;
  final bool secret;
  final String? validFrom;
  final String? validTo;
  factory Achievement.fromJson(Json j) {
    final c = (j['condition'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Achievement(
      id: _s(j['id']),
      name: _s(j['name']),
      description: _s(j['description']),
      category: _s(j['category'], 'constancia'),
      icon: _s(j['icon'], 'flag'),
      condition: AchievementCondition(metric: _s(c['metric']), op: _s(c['op'], '>='), value: _i(c['value']), scope: _s(c['scope'], 'global')),
      secret: _b(j['secret']),
      validFrom: j['validFrom'] as String?,
      validTo: j['validTo'] as String?,
    );
  }
}

class LeagueConfig {
  const LeagueConfig({
    this.groupSize = 30,
    this.divisions = const ['Bronce', 'Plata', 'Oro', 'Platino', 'Titanio'],
    this.promote = 7,
    this.relegate = 5,
    this.pointsPerCorrect = 10,
    this.timetrialBonus = 20,
    this.dailyCap = 300,
    this.minHumanMs = 500,
  });
  final int groupSize;
  final List<String> divisions;
  final int promote;
  final int relegate;
  final int pointsPerCorrect;
  final int timetrialBonus;
  final int dailyCap;
  final int minHumanMs;
  factory LeagueConfig.fromJson(Json? j) => j == null
      ? const LeagueConfig()
      : LeagueConfig(
          groupSize: _i(j['groupSize'], 30),
          divisions: _strings(j['divisions']).isEmpty ? const LeagueConfig().divisions : _strings(j['divisions']),
          promote: _i(j['promote'], 7),
          relegate: _i(j['relegate'], 5),
          pointsPerCorrect: _i(j['pointsPerCorrect'], 10),
          timetrialBonus: _i(j['timetrialBonus'], 20),
          dailyCap: _i(j['dailyCap'], 300),
          minHumanMs: _i(j['minHumanMs'], 500),
        );
}

class AdCreative {
  const AdCreative({
    required this.id,
    required this.kind,
    required this.context,
    required this.weight,
    required this.dailyCap,
    required this.headline,
    required this.body,
    required this.cta,
    this.ctaAlt,
    required this.ctaAction,
    this.voiceSpot,
    required this.illustration,
    this.campaignId = '',
  });
  final String id;
  final String kind;
  final String context;
  final int weight;
  final int? dailyCap;
  final String headline;
  final String body;
  final String cta;
  final String? ctaAlt;
  final String ctaAction;
  final String? voiceSpot;
  final String illustration;
  final String campaignId;
  factory AdCreative.fromJson(Json j, String campaignId) => AdCreative(
        id: _s(j['id']),
        kind: _s(j['kind'], 'generic'),
        context: _s(j['context'], 'always'),
        weight: _i(j['weight'], 1),
        dailyCap: j['dailyCap'] == null ? null : _i(j['dailyCap']),
        headline: _s(j['headline']),
        body: _s(j['body']),
        cta: _s(j['cta']),
        ctaAlt: j['ctaAlt'] as String?,
        ctaAction: _s(j['ctaAction'], 'paywall'),
        voiceSpot: j['voiceSpot'] as String?,
        illustration: _s(j['illustration']),
        campaignId: campaignId,
      );
}

class AdCampaign {
  const AdCampaign({required this.id, required this.name, this.sectorIds, this.startsAt, this.endsAt, required this.creatives});
  final String id;
  final String name;
  final List<String>? sectorIds;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<AdCreative> creatives;
  factory AdCampaign.fromJson(Json j) {
    final id = _s(j['id']);
    return AdCampaign(
      id: id,
      name: _s(j['name']),
      sectorIds: j['sectorIds'] is List ? _strings(j['sectorIds']) : null,
      startsAt: j['startsAt'] == null ? null : DateTime.tryParse('${j['startsAt']}'),
      endsAt: j['endsAt'] == null ? null : DateTime.tryParse('${j['endsAt']}'),
      creatives: _list(j['creatives'], (c) => AdCreative.fromJson(c, id)),
    );
  }
}

class AdParams {
  const AdParams({this.waitS = 3, this.frequencyTouch = 1, this.frequencyVoice = 1, this.defaultDailyCap = 6});
  final int waitS;
  final int frequencyTouch;
  final int frequencyVoice;
  final int defaultDailyCap;
  factory AdParams.fromJson(Json? j) => AdParams(
        waitS: _i(j?['waitS'], 3).clamp(0, 5),
        frequencyTouch: _i(j?['frequencyTouch'], 1).clamp(1, 100),
        frequencyVoice: _i(j?['frequencyVoice'], 1).clamp(1, 100),
        defaultDailyCap: _i(j?['defaultDailyCap'], 6),
      );
}

class FreePlanRules {
  const FreePlanRules({this.handsfreeDailyMinutes = 5, this.freeUnitsPerItinerary = 2});
  final int handsfreeDailyMinutes;
  final int freeUnitsPerItinerary;
}

class GlobalPackage {
  const GlobalPackage({
    required this.contentVersion,
    required this.minAppVersion,
    required this.sectors,
    required this.itineraries,
    required this.skills,
    required this.exerciseTypes,
    required this.units,
    required this.instruments,
    required this.voiceLexicon,
    required this.achievements,
    required this.league,
    required this.adParams,
    required this.campaigns,
    required this.freePlan,
    required this.orgsEnabled,
  });
  final String contentVersion;
  final String minAppVersion;
  final List<Sector> sectors;
  final List<ItinerarySummary> itineraries;
  final List<Skill> skills;
  final List<ExerciseType> exerciseTypes;
  final List<MeasureUnit> units;
  final List<Instrument> instruments;
  final VoiceLexicon voiceLexicon;
  final List<Achievement> achievements;
  final LeagueConfig league;
  final AdParams adParams;
  final List<AdCampaign> campaigns;
  final FreePlanRules freePlan;
  final bool orgsEnabled;

  factory GlobalPackage.fromJson(Json j) {
    final ads = (j['ads'] as Map?)?.cast<String, dynamic>();
    final fp = (j['freePlan'] as Map?)?.cast<String, dynamic>();
    return GlobalPackage(
      contentVersion: _s(j['contentVersion']),
      minAppVersion: _s(j['minAppVersion'], '1.0.0'),
      sectors: _list(j['sectors'], Sector.fromJson)..sort((a, b) => a.order.compareTo(b.order)),
      itineraries: _list(j['itineraries'], ItinerarySummary.fromJson),
      skills: _list(j['skills'], Skill.fromJson),
      exerciseTypes: _list(j['exerciseTypes'], ExerciseType.fromJson),
      units: _list(j['units'], MeasureUnit.fromJson),
      instruments: _list(j['instruments'], Instrument.fromJson),
      voiceLexicon: VoiceLexicon.fromJson((j['voiceLexicon'] as Map?)?.cast<String, dynamic>()),
      achievements: _list(j['achievements'], Achievement.fromJson),
      league: LeagueConfig.fromJson((j['league'] as Map?)?.cast<String, dynamic>()),
      adParams: AdParams.fromJson((ads?['params'] as Map?)?.cast<String, dynamic>()),
      campaigns: _list(ads?['campaigns'], AdCampaign.fromJson),
      freePlan: FreePlanRules(
        handsfreeDailyMinutes: _i(fp?['handsfreeDailyMinutes'], 5),
        freeUnitsPerItinerary: _i(fp?['freeUnitsPerItinerary'], 2),
      ),
      orgsEnabled: _b(j['orgsEnabled']),
    );
  }

  String skillName(String id) => skills.firstWhere((s) => s.id == id, orElse: () => Skill(id: id, name: id)).name;
  ExerciseType? type(String id) {
    for (final t in exerciseTypes) {
      if (t.id == id) return t;
    }
    return null;
  }
}
