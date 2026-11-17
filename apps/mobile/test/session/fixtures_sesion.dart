import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

/// Contenido de prueba de la sesión: el contenido incluido más un itinerario
/// con variantes controladas (perfusión, redondeo por instrumento, unidad a
/// elegir, selección única, ordenar pasos, estimación y dosis máxima).

StatementSegment _t(String v) => StatementSegment.text(v);
StatementSegment _q(String v, String u) => StatementSegment.qty(v, u);

Variant _var({
  required String id,
  String? templateId,
  String? questionId,
  required int level,
  String tipo = 'T1',
  String skill = 'H9',
  required List<StatementSegment> statement,
  required String question,
  AnswerSpec? answer,
  List<PredictedError> predicted = const [],
  List<ExplanationStep> steps = const [],
  String plausibility = '',
  List<ChoiceOption>? options,
  List<OrderItem>? orderItems,
  List<List<String>>? validOrders,
  String? approach,
  String? hint,
  int target = 45,
}) =>
    Variant(
      id: id,
      templateId: templateId,
      questionId: questionId,
      templateVersion: 1,
      level: level,
      exerciseTypeId: tipo,
      exerciseTypeVersion: 1,
      skillId: skill,
      sectorId: 'comun',
      statement: statement,
      question: question,
      tts: question,
      approach: approach,
      hint: hint,
      targetTimeS: target,
      answer: answer,
      predictedErrors: predicted,
      steps: steps,
      plausibility: plausibility,
      options: options,
      orderItems: orderItems,
      validOrders: validOrders,
    );

ExplanationStep _paso(int n, String texto, String op, String v, String u, List<String> cancelan, [String? leido]) =>
    ExplanationStep(n: n, text: texto, operation: op, result: Quantity(v, u), cancelled: cancelan, cancelledSpoken: leido);

/// Perfusión de noradrenalina (answer-grading, «Explicación de una perfusión»).
final varNora1 = _var(
  id: 'tpl-nora.v1.L3.a',
  templateId: 'tpl-nora',
  level: 3,
  statement: [
    _t('Paciente simulado de '),
    _q('80', 'kg'),
    _t('. Pauta: noradrenalina a '),
    _q('0.1', 'µg/kg/min'),
    _t('. Dilución de '),
    _q('100', 'µg/ml'),
    _t('.'),
  ],
  question: '¿A cuántos mililitros por hora? Redondea a la décima.',
  answer: const AnswerSpec(value: '4.8', unit: 'ml/h', unitChoices: ['ml/h'], rounding: RoundDecimals(1), unrounded: '4.8'),
  predicted: const [
    PredictedError(value: '0.08', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas.', deviationStep: 2),
    PredictedError(value: '48', unit: 'ml/h', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: 3),
  ],
  steps: [
    _paso(1, 'Dosis por minuto', '0,1 µg/kg/min × 80 kg', '8', 'µg/min', ['kg'], 'kilos se cancelan'),
    _paso(2, 'Dosis por hora', '8 µg/min × 60 min/h', '480', 'µg/h', ['min'], 'minutos se cancelan'),
    _paso(3, 'Ritmo', '480 µg/h ÷ 100 µg/ml', '4.8', 'ml/h', ['µg'], 'microgramos se cancelan'),
  ],
  plausibility: '4,8 ml/h en una bomba de perfusión. Tiene sentido.',
  approach: 'µg/kg/min × kg × 60 ÷ µg/ml = ml/h',
  hint: 'Primero calcula los µg por minuto.',
);

final varNora2 = _var(
  id: 'tpl-nora.v1.L3.b',
  templateId: 'tpl-nora',
  level: 3,
  statement: [
    _t('Paciente simulado de '),
    _q('70', 'kg'),
    _t('. Pauta: noradrenalina a '),
    _q('0.05', 'µg/kg/min'),
    _t('. Dilución de '),
    _q('80', 'µg/ml'),
    _t('.'),
  ],
  question: '¿A cuántos mililitros por hora? Redondea a la décima.',
  answer: const AnswerSpec(value: '2.6', unit: 'ml/h', unitChoices: ['ml/h'], rounding: RoundDecimals(1), unrounded: '2.625'),
  steps: [
    _paso(1, 'Dosis por minuto', '0,05 µg/kg/min × 70 kg', '3.5', 'µg/min', ['kg']),
    _paso(2, 'Dosis por hora', '3,5 µg/min × 60 min/h', '210', 'µg/h', ['min']),
    _paso(3, 'Ritmo', '210 µg/h ÷ 80 µg/ml', '2.625', 'ml/h', ['µg']),
  ],
  plausibility: '2,6 ml/h. Tiene sentido.',
);

/// Volumen por peso con dosis intermedia 4,8 mg (factor diez y paso omitido).
final varVol1 = _var(
  id: 'tpl-vol.v1.L2.a',
  templateId: 'tpl-vol',
  level: 2,
  skill: 'H3',
  statement: [_t('Perro simulado de '), _q('24', 'kg'), _t('. Pauta: meloxicam '), _q('0.2', 'mg/kg'), _t('. Presentación: '), _q('5', 'mg/ml'), _t('.')],
  question: '¿Qué volumen cargas?',
  answer: const AnswerSpec(value: '0.96', unit: 'ml', unitChoices: ['ml'], unrounded: '0.96'),
  predicted: const [
    PredictedError(value: '9.6', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: 2),
    PredictedError(value: '4.8', unit: 'ml', code: 'E4', message: 'Has dado la dosis en mg; falta calcular el volumen.', deviationStep: 2),
  ],
  steps: [
    _paso(1, 'Dosis', '0,2 mg/kg × 24 kg', '4.8', 'mg', ['kg']),
    _paso(2, 'Volumen', '4,8 mg ÷ 5 mg/ml', '0.96', 'ml', ['mg']),
  ],
  plausibility: 'Menos de 1 ml para un perro mediano. Tiene sentido.',
  target: 30,
);

final varVol2 = _var(
  id: 'tpl-vol.v1.L2.b',
  templateId: 'tpl-vol',
  level: 2,
  skill: 'H3',
  statement: [_t('Perro simulado de '), _q('30', 'kg'), _t('. Pauta: meloxicam '), _q('0.2', 'mg/kg'), _t('. Presentación: '), _q('5', 'mg/ml'), _t('.')],
  question: '¿Qué volumen cargas?',
  answer: const AnswerSpec(value: '1.2', unit: 'ml', unitChoices: ['ml'], unrounded: '1.2'),
  steps: [
    _paso(1, 'Dosis', '0,2 mg/kg × 30 kg', '6', 'mg', ['kg']),
    _paso(2, 'Volumen', '6 mg ÷ 5 mg/ml', '1.2', 'ml', ['mg']),
  ],
  plausibility: 'Tiene sentido.',
  target: 30,
);

/// Redondeo por jeringa de 1 ml (0,2667 → 0,27 ml).
final varBupre = _var(
  id: 'tpl-bupre.v1.L2.a',
  templateId: 'tpl-bupre',
  level: 2,
  skill: 'H4',
  statement: [_t('Gato simulado de '), _q('4', 'kg'), _t('. Pauta: buprenorfina '), _q('0.02', 'mg/kg'), _t('. Presentación: '), _q('0.3', 'mg/ml'), _t('. Jeringa de 1 ml: redondea a la centésima.')],
  question: '¿Qué volumen cargas?',
  answer: const AnswerSpec(value: '0.27', unit: 'ml', unitChoices: ['ml'], rounding: RoundDecimals(2), unrounded: '0.2667'),
  steps: [
    _paso(1, 'Dosis', '0,02 mg/kg × 4 kg', '0.08', 'mg', ['kg']),
    _paso(2, 'Volumen', '0,08 mg ÷ 0,3 mg/ml', '0.2667', 'ml', ['mg']),
  ],
  plausibility: 'Un volumen pequeño para un gato. Tiene sentido.',
);

/// Nivel 4: la unidad se elige.
final varLido = _var(
  id: 'tpl-lido.v1.L4.a',
  templateId: 'tpl-lido',
  level: 4,
  statement: [_t('Perro simulado de '), _q('20', 'kg'), _t('. Pauta: lidocaína a '), _q('50', 'µg/kg/min'), _t('. Presentación al '), _q('2', '%'), _t('.')],
  question: '¿Ritmo sin diluir?',
  answer: const AnswerSpec(value: '3', unit: 'ml/h', unitFixed: false, unitChoices: ['ml/h', 'ml/min', 'mg/h']),
  steps: [_paso(1, 'Ritmo', '50 µg/kg/min × 20 kg × 60 ÷ 20 mg/ml', '3', 'ml/h', ['kg', 'min', 'mg'])],
  plausibility: 'Tiene sentido.',
);

/// Dosis máxima como dato del enunciado.
final varMax = _var(
  id: 'tpl-max.v1.L3.a',
  templateId: 'tpl-max',
  level: 3,
  skill: 'H5',
  statement: [
    _t('Paciente simulado de '),
    _q('70', 'kg'),
    _t('. Pauta: paracetamol intravenoso '),
    _q('15', 'mg/kg'),
    _t(', máximo '),
    _q('1', 'g'),
    _t(' por dosis. Presentación: '),
    _q('10', 'mg/ml'),
    _t('.'),
  ],
  question: '¿Qué volumen administras?',
  answer: const AnswerSpec(value: '100', unit: 'ml', unitChoices: ['ml']),
  predicted: const [PredictedError(value: '105', unit: 'ml', code: 'E6', message: 'No has aplicado el máximo de 1 g por dosis.', deviationStep: 2)],
  steps: [
    _paso(1, 'Dosis por peso', '15 mg/kg × 70 kg', '1050', 'mg', ['kg']),
    _paso(2, 'Límite', 'mín(1050 mg, 1000 mg)', '1000', 'mg', []),
    _paso(3, 'Volumen', '1000 mg ÷ 10 mg/ml', '100', 'ml', ['mg']),
  ],
  plausibility: 'Una ampolla de 100 ml. Tiene sentido.',
);

final varAdre = _var(
  id: 'q-adre.v1',
  questionId: 'q-adre',
  level: 2,
  tipo: 'T2',
  skill: 'H2',
  statement: [_t('Adrenalina '), _t('1:10 000'), _t('.')],
  question: '¿Qué concentración tiene?',
  options: const [
    ChoiceOption(id: 'a', label: '1 mg/ml', value: '1', unit: 'mg/ml', correct: false, errorCode: 'E2', message: 'Esa es la concentración 1:1000.'),
    ChoiceOption(id: 'b', label: '0,1 mg/ml', value: '0.1', unit: 'mg/ml', correct: true),
    ChoiceOption(id: 'c', label: '0,01 mg/ml', value: '0.01', unit: 'mg/ml', correct: false, errorCode: 'E2', message: 'Diez veces menor.'),
    ChoiceOption(id: 'd', label: '10 mg/ml', value: '10', unit: 'mg/ml', correct: false, errorCode: 'E2', message: 'Cien veces mayor.'),
  ],
  steps: [_paso(1, 'Proporción', '1 g en 10 000 ml', '0.1', 'mg/ml', [])],
  plausibility: 'Tiene sentido.',
  target: 20,
);

final varOrden = _var(
  id: 'q-orden.v1',
  questionId: 'q-orden',
  level: 2,
  tipo: 'T3',
  statement: [_t('Ordena los pasos para convertir una pauta en µg/kg/min en un ritmo en ml/h.')],
  question: '',
  orderItems: const [
    OrderItem(id: 'a', text: 'Multiplicar la dosis por el peso → µg/min'),
    OrderItem(id: 'b', text: 'Multiplicar por 60 → µg/h'),
    OrderItem(id: 'c', text: 'Expresar la concentración de la dilución → µg/ml'),
    OrderItem(id: 'd', text: 'Dividir la dosis por hora entre la concentración → ml/h'),
  ],
  validOrders: const [
    ['a', 'b', 'c', 'd'],
    ['c', 'a', 'b', 'd'],
  ],
  steps: [_paso(1, 'Orden', 'peso → hora → concentración', '1', '', [])],
  plausibility: 'Cada paso usa el resultado del anterior.',
);

final varEstima = _var(
  id: 'q-estima.v1',
  questionId: 'q-estima',
  level: 2,
  tipo: 'T6',
  skill: 'H12',
  statement: [_t('Niño simulado de '), _q('15', 'kg'), _t('. Pauta: atropina '), _q('0.02', 'mg/kg'), _t('. Ampolla de '), _q('1', 'mg/ml'), _t('.')],
  question: '¿En qué franja está el volumen?',
  options: const [
    ChoiceOption(id: 'a', label: 'Menos de 0,1 ml', correct: false, errorCode: 'E2'),
    ChoiceOption(id: 'b', label: 'Entre 0,1 y 1 ml', correct: true),
    ChoiceOption(id: 'c', label: 'Entre 1 y 10 ml', correct: false, errorCode: 'E2'),
    ChoiceOption(id: 'd', label: 'Más de 10 ml', correct: false, errorCode: 'E2'),
  ],
  steps: [_paso(1, 'Volumen', '0,02 mg/kg × 15 kg ÷ 1 mg/ml', '0.3', 'ml', ['kg', 'mg'])],
  plausibility: '0,3 ml: entre 0,1 y 1 ml.',
  target: 12,
);

Lesson _leccion(String id, List<(String, int, String, bool)> slots) => Lesson(
      id: id,
      unitId: 'u-p-1',
      order: 1,
      kind: LessonKind.free,
      title: 'Prueba',
      estimatedMinutes: 4,
      slots: [
        for (final (i, s) in slots.indexed)
          LessonSlot(position: i + 1, templateId: s.$4 ? s.$1 : null, questionId: s.$4 ? null : s.$1, difficulty: s.$2, skillId: s.$3),
      ],
    );

final leccionesFixture = [
  _leccion('l-nora', [('tpl-nora', 3, 'H9', true)]),
  _leccion('l-vol', [('tpl-vol', 2, 'H3', true)]),
  _leccion('l-bupre', [('tpl-bupre', 2, 'H4', true)]),
  _leccion('l-lido', [('tpl-lido', 4, 'H9', true)]),
  _leccion('l-max', [('tpl-max', 3, 'H5', true)]),
  _leccion('l-t2', [('q-adre', 2, 'H2', false)]),
  _leccion('l-t3', [('q-orden', 2, 'H9', false)]),
  _leccion('l-t6', [('q-estima', 2, 'H12', false)]),
  _leccion('l-t7', [('q-f-t7-masa', 2, 'H1', false)]),
  _leccion('l-h1', [('tpl-f-mg-ug', 1, 'H1', true)]),
  _leccion('l-dos', [('tpl-vol', 2, 'H3', true), ('tpl-nora', 3, 'H9', true)]),
];

/// Contenido incluido más el itinerario de prueba `it-prueba-sesion`.
ContenidoCargado contenidoSesion(ContenidoCargado base) {
  const resumen = ItinerarySummary(
    id: 'it-prueba-sesion',
    sectorId: 'comun',
    name: 'Prueba de sesión',
    description: '',
    recommendedLevel: 'afianzar',
    order: 99,
    isFoundations: false,
  );
  final it = ItineraryPackage(
    contentVersion: base.version,
    minAppVersion: '1.0.0',
    itinerary: resumen,
    units: const [],
    lessons: leccionesFixture,
    templates: const [],
    variants: [varNora1, varNora2, varVol1, varVol2, varBupre, varLido, varMax, varAdre, varOrden, varEstima],
    placement: const [],
  );
  return ContenidoCargado(global: base.global, itinerarios: {...base.itinerarios, it.itinerary.id: it}, revocaciones: base.revocaciones);
}

/// Premium activo validado hoy (sin pausas promocionales).
Entitlements premiumActivo(DateTime ahora) => Entitlements(
      premium: true,
      noAds: true,
      source: 'store',
      plan: 'annual',
      status: 'active',
      expiresAt: ahora.add(const Duration(days: 300)),
      renewsAt: ahora.add(const Duration(days: 300)),
      trialUsed: true,
      validatedAt: ahora,
    );

/// La misma variante sin respuesta (no se puede mostrar).
Variant sinRespuesta(Variant v) => Variant(
      id: v.id,
      templateId: v.templateId,
      questionId: v.questionId,
      templateVersion: v.templateVersion,
      level: v.level,
      exerciseTypeId: v.exerciseTypeId,
      exerciseTypeVersion: v.exerciseTypeVersion,
      skillId: v.skillId,
      sectorId: v.sectorId,
      statement: v.statement,
      question: v.question,
      tts: v.tts,
      targetTimeS: v.targetTimeS,
    );

/// Sustituye las variantes del itinerario de prueba.
ContenidoCargado conVariantes(ContenidoCargado base, List<Variant> variantes) {
  final it = base.itinerarios['it-prueba-sesion']!;
  final nuevo = ItineraryPackage(
    contentVersion: it.contentVersion,
    minAppVersion: it.minAppVersion,
    itinerary: it.itinerary,
    units: it.units,
    lessons: it.lessons,
    templates: it.templates,
    variants: variantes,
    placement: it.placement,
  );
  return ContenidoCargado(global: base.global, itinerarios: {...base.itinerarios, it.itinerary.id: nuevo}, revocaciones: base.revocaciones);
}
