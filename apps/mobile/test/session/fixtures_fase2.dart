import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';

/// Contenido de prueba de los tipos de la fase 2 (add-growth-features):
/// completar el planteamiento (T4), detectar el error (T5), caso encadenado
/// (T8) y emparejar (T10). El contenido publicado aún no trae variantes de
/// estos tipos: se definen aquí con el creador de tipos (pasos y bloques).

ExerciseType _tipo(String id, String nombre, String bloque, String regla, {bool voz = false}) => ExerciseType(
      id: id,
      version: 1,
      name: nombre,
      description: nombre,
      steps: [ExerciseTypeStep(presentation: const ['statement'], response: bloque, grading: regla)],
      behaviour: const ['scoring', 'second_try'],
      voiceCompatible: voz,
      minAppVersion: '1.0.0',
    );

final tiposFase2 = [
  _tipo('T4', 'Completar el planteamiento', 'fill_gaps', 'order_equivalences'),
  _tipo('T5', 'Detectar el error', 'step_pick', 'exact_match', voz: true),
  _tipo('T8', 'Caso encadenado', 'numeric_unit', 'numeric_tolerance'),
  _tipo('T10', 'Emparejar', 'matching', 'pair_set'),
];

StatementSegment _t(String v) => StatementSegment.text(v);
StatementSegment _q(String v, String u) => StatementSegment.qty(v, u);

AnswerSpec _resp(String v, String u) => AnswerSpec(value: v, unit: u, unitChoices: [u]);

Variant _v(String id, String item, String tipo, {required List<StatementSegment> statement, required String question, GapFill? gapFill, List<WorkedStep>? worked, List<ChainPart>? chain, List<MatchPair>? pairs, String skill = 'H3'}) => Variant(
      id: id,
      templateId: item,
      questionId: null,
      templateVersion: 1,
      level: 2,
      exerciseTypeId: tipo,
      exerciseTypeVersion: 1,
      skillId: skill,
      sectorId: 'comun',
      statement: statement,
      question: question,
      tts: question,
      targetTimeS: 60,
      gapFill: gapFill,
      worked: worked,
      chain: chain,
      pairs: pairs,
      plausibility: 'Tiene sentido.',
    );

/// T4: volumen por peso con huecos; g1 y g2 son intercambiables (el producto
/// conmuta) y sobran dos fichas.
Variant t4(String sufijo, {String peso = '24', String vol = '0,96'}) => _v(
      'tpl-t4.v1.L2.$sufijo',
      'tpl-t4',
      'T4',
      statement: [_t('Perro simulado de '), _q(peso.replaceAll(',', '.'), 'kg'), _t('. Pauta: meloxicam '), _q('0.2', 'mg/kg'), _t('. Presentación: '), _q('5', 'mg/ml'), _t('.')],
      question: 'Completa el planteamiento del volumen.',
      gapFill: GapFill(
        template: '{g1} mg/kg × {g2} kg ÷ {g3} mg/ml = $vol ml',
        tiles: ['0,2', peso, '5', '2,4', '50'],
        gapAnswers: {'g1': '0,2', 'g2': peso, 'g3': '5'},
        interchangeable: const [
          ['g1', 'g2'],
        ],
      ),
    );

/// T5: el paso 2 olvida pasar de minutos a horas.
Variant t5(String sufijo) => _v(
      'tpl-t5.v1.L2.$sufijo',
      'tpl-t5',
      'T5',
      skill: 'H9',
      statement: [_t('Paciente simulado de '), _q('80', 'kg'), _t('. Pauta: noradrenalina a '), _q('0.1', 'µg/kg/min'), _t('. Dilución de '), _q('100', 'µg/ml'), _t('.')],
      question: '¿En qué paso está el error?',
      worked: const [
        WorkedStep(n: 1, text: '0,1 µg/kg/min × 80 kg = 8 µg/min', correct: true),
        WorkedStep(n: 2, text: '8 µg/min ÷ 100 µg/ml = 0,08 ml/h', correct: false, correction: 'Falta multiplicar por 60: 8 µg/min × 60 = 480 µg/h'),
        WorkedStep(n: 3, text: 'Resultado: 0,08 ml/h', correct: false, correction: 'Con 480 µg/h ÷ 100 µg/ml = 4,8 ml/h'),
      ],
    );

/// T8: perfusión en tres partes encadenadas.
Variant t8(String sufijo) => _v(
      'tpl-t8.v1.L2.$sufijo',
      'tpl-t8',
      'T8',
      skill: 'H9',
      statement: [_t('Paciente simulado de '), _q('80', 'kg'), _t('. Pauta: noradrenalina a '), _q('0.1', 'µg/kg/min'), _t('. Dilución de '), _q('100', 'µg/ml'), _t('.')],
      question: 'Resuelve el caso paso a paso.',
      chain: [
        ChainPart(prompt: '¿Cuántos µg por minuto?', tts: '', answer: _resp('8', 'µg/min'), predictedErrors: const []),
        ChainPart(
          prompt: 'Con esa dosis, ¿cuántos µg por hora?',
          tts: '',
          answer: _resp('480', 'µg/h'),
          predictedErrors: const [PredictedError(value: '8', unit: 'µg/h', code: 'E4', message: 'Falta multiplicar por 60')],
        ),
        ChainPart(
          prompt: 'Con la dosis por hora, ¿a cuántos ml/h?',
          tts: '',
          answer: _resp('4.8', 'ml/h'),
          predictedErrors: const [PredictedError(value: '0.08', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas.')],
        ),
      ],
    );

/// T10: equivalencias de unidades.
Variant t10(String sufijo) => _v(
      'tpl-t10.v1.L2.$sufijo',
      'tpl-t10',
      'T10',
      skill: 'H1',
      statement: [_t('Une cada cantidad con su equivalente.')],
      question: '',
      pairs: const [MatchPair('1 mg', '1000 µg'), MatchPair('1 g', '1000 mg'), MatchPair('1 h', '60 min'), MatchPair('1 %', '10 mg/ml')],
    );

Lesson _leccion(String id, String item) => Lesson(
      id: id,
      unitId: 'u-f2-1',
      order: 1,
      kind: LessonKind.free,
      title: 'Fase 2',
      estimatedMinutes: 4,
      slots: [LessonSlot(position: 1, templateId: item, difficulty: 2, skillId: 'H3')],
    );

/// Contenido incluido más los tipos y el itinerario `it-prueba-fase2`.
ContenidoCargado contenidoFase2(ContenidoCargado base) {
  final g = base.global;
  final global = GlobalPackage(
    contentVersion: g.contentVersion,
    minAppVersion: g.minAppVersion,
    sectors: g.sectors,
    itineraries: g.itineraries,
    skills: g.skills,
    exerciseTypes: [...g.exerciseTypes, ...tiposFase2],
    units: g.units,
    instruments: g.instruments,
    voiceLexicon: g.voiceLexicon,
    achievements: g.achievements,
    league: g.league,
    adParams: g.adParams,
    campaigns: g.campaigns,
    freePlan: g.freePlan,
    orgsEnabled: g.orgsEnabled,
  );
  const resumen = ItinerarySummary(
    id: 'it-prueba-fase2',
    sectorId: 'comun',
    name: 'Prueba de fase 2',
    description: '',
    recommendedLevel: 'afianzar',
    order: 98,
    isFoundations: false,
  );
  final it = ItineraryPackage(
    contentVersion: base.version,
    minAppVersion: '1.0.0',
    itinerary: resumen,
    units: const [],
    lessons: [
      _leccion('l-t4', 'tpl-t4'),
      _leccion('l-t5', 'tpl-t5'),
      _leccion('l-t8', 'tpl-t8'),
      _leccion('l-t10', 'tpl-t10'),
      Lesson(
        id: 'l-fase2-mezcla',
        unitId: 'u-f2-1',
        order: 2,
        kind: LessonKind.free,
        title: 'Mezcla',
        estimatedMinutes: 4,
        slots: [
          const LessonSlot(position: 1, templateId: 'tpl-t4', difficulty: 2, skillId: 'H3'),
          const LessonSlot(position: 2, templateId: 'tpl-f-mg-ug', difficulty: 1, skillId: 'H1'),
          const LessonSlot(position: 3, templateId: 'tpl-t10', difficulty: 2, skillId: 'H1'),
        ],
      ),
    ],
    templates: const [],
    variants: [t4('a'), t4('b', peso: '30', vol: '1,2'), t5('a'), t5('b'), t8('a'), t8('b'), t10('a'), t10('b')],
    placement: const [],
  );
  return ContenidoCargado(global: global, itinerarios: {...base.itinerarios, it.itinerary.id: it}, revocaciones: base.revocaciones);
}
