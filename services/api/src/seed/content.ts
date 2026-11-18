/**
 * Contenido semilla de VolutrainMed: Fundamentos, Anestesia y reanimación y
 * Veterinaria de pequeños animales (supuesto S2 de la definición funcional).
 *
 * TODO EL CONTENIDO ES DE DEMOSTRACIÓN Y ESTÁ PENDIENTE DE VALIDACIÓN POR UN
 * PROFESIONAL ANTES DE PUBLICARSE PARA USUARIOS REALES. Las pautas aparecen en
 * el enunciado como dato del caso simulado; no son recomendaciones de dosis.
 *
 * La semilla crea los elementos como si los hubiera escrito la autora de
 * demostración y los valida un revisor de demostración distinto (cuatro ojos).
 */
import type { Achievement, AdCampaign, AdParams, ExerciseType, ItinerarySummary, LeagueConfig, LessonKind, Sector, Skill, SkillCode, Unit } from '@vtm/contracts';
import type { LevelDef, QuestionDefinition, TemplateDefinition } from '@vtm/engine';

// ---------------------------------------------------------------------------
// Catálogos fijos
// ---------------------------------------------------------------------------

export const SKILLS: Skill[] = [
  { id: 'H1', name: 'Conversión de unidades de masa, volumen y tiempo' },
  { id: 'H2', name: 'Concentraciones: mg/ml, porcentaje, razones 1:N y UI/ml' },
  { id: 'H3', name: 'Dosis por peso (mg/kg, µg/kg, UI/kg)' },
  { id: 'H4', name: 'Volumen a cargar según la concentración' },
  { id: 'H5', name: 'Dosis diaria repartida en tomas' },
  { id: 'H6', name: 'Reconstitución y dilución' },
  { id: 'H7', name: 'Ritmo de perfusión en ml/h' },
  { id: 'H8', name: 'Goteo en gotas/min' },
  { id: 'H9', name: 'Perfusión por peso y tiempo (µg/kg/min y ml/h)' },
  { id: 'H10', name: 'Dosis máxima y comprobación de límites' },
  { id: 'H11', name: 'Redondeo según el instrumento de medida' },
  { id: 'H12', name: 'Estimación y plausibilidad del resultado' },
];

export const ITINERARIES: ItinerarySummary[] = [
  { id: 'it-fundamentos', sectorId: 'comun', name: 'Fundamentos', description: 'Conversiones, concentraciones, volumen a cargar, redondeo y estimación. Común a todos los sectores.', recommendedLevel: 'cero', order: 0, isFoundations: true },
  { id: 'it-anestesia', sectorId: 'anestesia', name: 'Anestesia y reanimación', description: 'Diluciones, dosis por peso, perfusiones en µg/kg/min y dosis máximas de anestésicos locales.', recommendedLevel: 'afianzar', order: 1, isFoundations: false },
  { id: 'it-vet-pequenos', sectorId: 'veterinaria', name: 'Anestesia y clínica de pequeños animales', description: 'Dosis por especie y peso, volúmenes pequeños, infusiones continuas y fluidoterapia.', recommendedLevel: 'afianzar', order: 2, isFoundations: false },
];

export const SECTORS: Sector[] = [
  { id: 'enfermeria', code: 'ENF', name: 'Enfermería', description: 'Planta, críticos y estudiantes de grado', icon: 'medical_services', typicalCalcs: 'ml/h, gotas/min, diluciones, UI de insulina y heparina', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos'], order: 0 },
  { id: 'medicina', code: 'MED', name: 'Medicina', description: 'Estudiantes y residentes', icon: 'stethoscope', typicalCalcs: 'mg/kg, dosis máximas, perfusiones y conversiones', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos', 'it-anestesia'], order: 1 },
  { id: 'anestesia', code: 'ANE', name: 'Anestesia y reanimación', description: 'Residentes, adjuntos y enfermería de anestesia', icon: 'vital_signs', typicalCalcs: 'µg/kg/min, vasoactivos, dosis máxima de anestésico local, %', defaultItineraryId: 'it-anestesia', itineraryIds: ['it-fundamentos', 'it-anestesia'], order: 2 },
  { id: 'emergencias', code: 'EME', name: 'Emergencias', description: 'TES, enfermería y medicina de urgencias', icon: 'emergency', typicalCalcs: 'Adrenalina 1:1000 y 1:10 000, dosis pediátricas por peso', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos', 'it-anestesia'], order: 3 },
  { id: 'farmacia', code: 'FAR', name: 'Farmacia', description: 'Estudiantes, farmacia hospitalaria y técnicos', icon: 'medication', typicalCalcs: 'Reconstitución, porcentajes, proporciones y concentración final', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos'], order: 4 },
  { id: 'pediatria', code: 'PED', name: 'Pediatría', description: 'Residentes y enfermería pediátrica', icon: 'child_care', typicalCalcs: 'mg/kg/día en tomas, suspensiones en mg/5 ml, dosis máxima', defaultItineraryId: 'it-fundamentos', itineraryIds: ['it-fundamentos'], order: 5, doubleReview: true },
  { id: 'veterinaria', code: 'VET', name: 'Veterinaria', description: 'Estudiantes, clínicos y auxiliares', icon: 'pets', typicalCalcs: 'mg/kg por especie, volúmenes muy pequeños, infusiones continuas', defaultItineraryId: 'it-vet-pequenos', itineraryIds: ['it-fundamentos', 'it-vet-pequenos'], order: 6 },
];

export const EXERCISE_TYPES: ExerciseType[] = [
  { id: 'T1', version: 1, name: 'Respuesta numérica con unidad', description: 'Caso simulado con pauta; una respuesta con unidad', steps: [{ presentation: ['statement', 'highlighted_data'], response: 'numeric_unit', grading: 'numeric_tolerance' }], behaviour: ['hints', 'scoring', 'second_try'], voiceCompatible: true, minAppVersion: '1.0.0' },
  { id: 'T2', version: 1, name: 'Selección única', description: 'Elegir entre 3 o 4 opciones diagnósticas', steps: [{ presentation: ['statement', 'highlighted_data'], response: 'single_choice', grading: 'exact_match' }], behaviour: ['hints', 'scoring', 'second_try'], voiceCompatible: true, minAppVersion: '1.0.0' },
  { id: 'T3', version: 1, name: 'Ordenar pasos', description: 'Poner en orden los pasos de un cálculo', steps: [{ presentation: ['statement', 'step_list'], response: 'ordering', grading: 'order_equivalences' }], behaviour: ['hints', 'scoring'], voiceCompatible: false, minAppVersion: '1.0.0' },
  { id: 'T6', version: 1, name: 'Estimación rápida', description: 'Elegir la franja del resultado sin calcularlo con exactitud', steps: [{ presentation: ['statement', 'highlighted_data', 'timer'], response: 'range_choice', grading: 'exact_match' }], behaviour: ['time_limit', 'scoring'], voiceCompatible: true, minAppVersion: '1.0.0', timeLimitS: 15 },
  { id: 'T7', version: 1, name: 'Conversión relámpago', description: 'Diez conversiones seguidas en 60 segundos', steps: [{ presentation: ['statement', 'timer'], response: 'conversion_series', grading: 'numeric_tolerance' }], behaviour: ['time_limit', 'scoring'], voiceCompatible: true, minAppVersion: '1.0.0', timeLimitS: 60 },
];

export const ACHIEVEMENTS: Achievement[] = [
  { id: 'ach-first-lesson', name: 'Primera lección', description: 'Has completado tu primera lección', category: 'constancia', icon: 'flag', condition: { metric: 'lessons_completed', op: '>=', value: 1, scope: 'global' }, secret: false, retroactive: true },
  { id: 'ach-streak-7', name: 'Siete días', description: 'Siete días de racha con la meta cumplida', category: 'constancia', icon: 'local_fire_department', condition: { metric: 'streak_days', op: '>=', value: 7, scope: 'global' }, secret: false, retroactive: true },
  { id: 'ach-first-unit-mastered', name: 'Primera unidad dominada', description: 'Todas las habilidades de una unidad en estado dominada', category: 'dominio', icon: 'workspace_premium', condition: { metric: 'units_mastered', op: '>=', value: 1, scope: 'global' }, secret: false, retroactive: true },
  { id: 'ach-first-handsfree', name: 'Manos libres', description: 'Primera sesión manos libres completada', category: 'agilidad', icon: 'headset_mic', condition: { metric: 'handsfree_sessions', op: '>=', value: 1, scope: 'global' }, secret: false, retroactive: true },
  { id: 'ach-100-no-critical', name: 'Cien sin error crítico', description: 'Cien ejercicios seguidos sin error crítico', category: 'precision', icon: 'verified', condition: { metric: 'no_critical_exercises', op: '>=', value: 100, scope: 'global' }, secret: false, retroactive: true },
];

export const LEAGUE_CONFIG: LeagueConfig = {
  groupSize: 30, divisions: ['Bronce', 'Plata', 'Oro', 'Platino', 'Titanio'], promote: 7, relegate: 5,
  pointsPerCorrect: 10, timetrialBonus: 20, dailyCap: 300, weekStartsOn: 1, groupBySector: true, minHumanMs: 500,
};

export const AD_PARAMS: AdParams = { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 };

/** Campaña de lanzamiento: los doce anuncios de house-ads-catalog.md. */
export const LAUNCH_CAMPAIGN: AdCampaign = {
  id: 'camp-lanzamiento', name: 'Campaña de lanzamiento', sectorIds: null, startsAt: null, endsAt: null,
  creatives: [
    { id: 'PA-01', kind: 'fallback', context: 'always', weight: 3, dailyCap: null, headline: 'Entrena sin pausas', body: 'Con Premium pasas de un ejercicio al siguiente sin anuncios.', cta: 'Quitar anuncios', ctaAction: 'paywall', voiceSpot: 'Con Premium, entrenas sin estas pausas.', illustration: 'continuous_scale' },
    { id: 'PA-02', kind: 'generic', context: 'wait_gt0_in_lesson', weight: 2, dailyCap: 4, headline: '{espera_s} s × {ejercicios} ejercicios = {total_s} s', body: 'Es lo que duran las pausas de esta lección. Con Premium son tiempo de práctica.', cta: 'Quitar anuncios', ctaAction: 'paywall', voiceSpot: 'Estas pausas suman {total_s} segundos por lección. Premium las quita.', illustration: 'operation_step' },
    { id: 'PA-03', kind: 'generic', context: 'trial_available', weight: 3, dailyCap: 6, headline: '7 días de Premium, gratis', body: 'Sin anuncios y con manos libres sin límite. Cancela cuando quieras.', cta: 'Probar gratis', ctaAction: 'trial', voiceSpot: 'Prueba Premium siete días gratis, sin anuncios.', illustration: 'seven_divisions' },
    { id: 'PA-04', kind: 'contextual', context: 'handsfree_limit_or_after_handsfree', weight: 3, dailyCap: 3, headline: 'Sigue con las manos ocupadas', body: 'Manos libres sin límite diario. Tu voz se procesa en el dispositivo.', cta: 'Ver Premium', ctaAction: 'paywall', voiceSpot: 'Con Premium, manos libres sin límite diario.', illustration: 'headset_halo' },
    { id: 'PA-05', kind: 'contextual', context: 'streak_gte_3', weight: 3, dailyCap: 2, headline: 'Llevas {dias} días seguidos', body: 'Mantén el ritmo sin interrupciones entre ejercicios.', cta: 'Quitar anuncios', ctaAction: 'paywall', voiceSpot: 'Llevas {dias} días seguidos. Con Premium, sin pausas.', illustration: 'streak_meniscus' },
    { id: 'PA-06', kind: 'generic', context: 'prices_fresh_7d', weight: 2, dailyCap: 3, headline: 'Premium por {equivalente_mes} € al mes', body: 'Con el plan anual pagas un {ahorro_pct} % menos que mes a mes.', cta: 'Ver planes', ctaAction: 'paywall', voiceSpot: 'El plan anual de Premium sale a {equivalente_mes} euros al mes.', illustration: 'two_bars' },
    { id: 'PA-07', kind: 'contextual', context: 'after_unit_completed', weight: 2, dailyCap: 2, headline: 'Un sector hoy, otro mañana', body: 'Premium abre todos los itinerarios: anestesia, urgencias, pediatría, veterinaria.', cta: 'Ver Premium', ctaAction: 'paywall', voiceSpot: 'Premium abre todos los itinerarios.', illustration: 'branching_path' },
    { id: 'PA-08', kind: 'contextual', context: 'last_pause_lesson_with_errors', weight: 2, dailyCap: 2, headline: '¿Dónde se te va el tiempo?', body: 'Premium muestra tu evolución por habilidad y tus errores más frecuentes.', cta: 'Ver Premium', ctaAction: 'paywall', voiceSpot: 'Premium muestra tus errores más frecuentes por habilidad.', illustration: 'rising_line' },
    { id: 'PA-09', kind: 'generic', context: 'always', weight: 1, dailyCap: 2, headline: 'Cada ejercicio lo revisa un profesional', body: 'Tu suscripción financia la validación experta del contenido.', cta: 'Apoyar con Premium', ctaAction: 'paywall', voiceSpot: 'Tu suscripción financia la revisión experta del contenido.', illustration: 'validation_seal' },
    { id: 'PA-10', kind: 'contextual', context: 'last_pause_lesson_perfect', weight: 3, dailyCap: 2, headline: '{aciertos} de {ejercicios}', body: 'Buen ritmo. Con Premium, además, sin pausas entre ejercicios.', cta: 'Probar gratis', ctaAlt: 'Quitar anuncios', ctaAction: 'trial_or_paywall', voiceSpot: '{aciertos} de {ejercicios}. Con Premium, sin pausas.', illustration: 'full_meniscus' },
    { id: 'PA-11', kind: 'contextual', context: 'after_timetrial', weight: 3, dailyCap: 3, headline: 'Tu ritmo, sin cortes', body: 'En las lecciones, Premium te lleva de un ejercicio al siguiente sin anuncios.', cta: 'Quitar anuncios', ctaAction: 'paywall', voiceSpot: null, illustration: 'continuous_bar' },
    { id: 'PA-12', kind: 'generic', context: 'orgs_enabled', weight: 1, dailyCap: 1, headline: '¿Tu facultad o tu hospital usa VolutrainMed?', body: 'Con un código de organización entrenas sin anuncios y sin pagar tú.', cta: 'Tengo un código', ctaAction: 'org_code', voiceSpot: 'Con un código de tu organización, entrenas sin anuncios.', illustration: 'building_access' },
  ],
};

// ---------------------------------------------------------------------------
// Ayudas para escribir plantillas
// ---------------------------------------------------------------------------

type Ov = LevelDef['overrides'];

function levels(base: number, ov: Partial<Record<1 | 2 | 3 | 4 | 5, Ov>> = {}): LevelDef[] {
  return ([1, 2, 3, 4, 5] as const).map((l) => ({ level: l, unitFixed: l <= 3, targetTimeS: base + (l - 1) * 5, overrides: ov[l] }));
}

const SEED_VARIANTS = 40; // 300 por defecto en el editor; la semilla usa 40 para paquetes ligeros.

function tpl(t: Omit<TemplateDefinition, 'version' | 'variantsPerLevel' | 'equivalents' | 'tolerance' | 'constraints' | 'demo'> & Partial<Pick<TemplateDefinition, 'equivalents' | 'tolerance' | 'constraints'>>): TemplateDefinition {
  return {
    version: 1, variantsPerLevel: SEED_VARIANTS, equivalents: [], tolerance: { kind: 'exact' }, constraints: { conditions: [] }, demo: true,
    ...t,
  };
}

const E2_UP = (step = 2) => ({ formula: 'respuesta × 10', unit: '', code: 'E2' as const, message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: step });
const E2_DOWN = (step = 2) => ({ formula: 'respuesta ÷ 10', unit: '', code: 'E2' as const, message: 'Tu respuesta es diez veces menor. Revisa la coma', deviationStep: step });

function withUnit<T extends { unit: string }>(e: T, unit: string): T { return { ...e, unit }; }

// ---------------------------------------------------------------------------
// Fundamentos (H1, H2, H4, H11, H12)
// ---------------------------------------------------------------------------

const F: TemplateDefinition[] = [
  tpl({
    id: 'tpl-f-mg-ug', name: 'Miligramos a microgramos', sectorId: 'comun', skillId: 'H1', exerciseTypeId: 'T1',
    variables: [{ name: 'x', label: 'Cantidad', kind: 'decimal', unit: 'mg', min: '0.01', max: '5', step: '0.01', show: true }],
    statement: 'Tienes {x}.', question: '¿Cuántos microgramos son?', formula: 'x', answerUnit: 'µg', unitChoices: ['µg', 'mg', 'g'],
    rounding: { mode: 'none' }, constraints: { conditions: [] },
    predictedErrors: [withUnit(E2_UP(1), 'µg'), withUnit(E2_DOWN(1), 'µg'), { formula: 'respuesta ÷ 1000000', unit: 'µg', code: 'E3', message: 'Has dividido entre 1000 en lugar de multiplicar', deviationStep: 1 }],
    steps: [{ text: 'De mg a µg se multiplica por 1000', formula: 'x', unit: 'µg', operation: '{x} × 1000 µg/mg', cancelled: ['mg'] }],
    plausibility: 'El microgramo es mil veces menor que el miligramo: la cifra en µg debe ser mayor. {respuesta} tiene sentido.',
    approach: 'mg × 1000 = µg', hint: '1 mg = 1000 µg',
    levels: levels(15, { 1: { x: { min: '1', max: '5', step: '1' } }, 2: { x: { min: '0.1', max: '5', step: '0.1' } }, 4: { x: { min: '0.005', max: '2', step: '0.005' } }, 5: { x: { min: '0.001', max: '0.5', step: '0.001' } } }),
  }),
  tpl({
    id: 'tpl-f-g-mg', name: 'Gramos a miligramos', sectorId: 'comun', skillId: 'H1', exerciseTypeId: 'T2',
    variables: [{ name: 'x', label: 'Cantidad', kind: 'decimal', unit: 'g', min: '0.1', max: '3', step: '0.05', show: true }],
    statement: 'Tienes {x}.', question: '¿A cuántos miligramos equivale?', formula: 'x', answerUnit: 'mg', unitChoices: ['mg'],
    rounding: { mode: 'none' },
    predictedErrors: [withUnit(E2_UP(1), 'mg'), withUnit(E2_DOWN(1), 'mg'), { formula: 'respuesta ÷ 1000000', unit: 'mg', code: 'E3', message: 'Has dividido entre 1000 en lugar de multiplicar', deviationStep: 1 }],
    steps: [{ text: 'De g a mg se multiplica por 1000', formula: 'x', unit: 'mg', operation: '{x} × 1000 mg/g', cancelled: ['g'] }],
    plausibility: '{respuesta}: el miligramo es mil veces menor que el gramo, así que la cifra crece. Tiene sentido.',
    levels: levels(15, { 1: { x: { min: '1', max: '3', step: '1' } } }),
  }),
  tpl({
    id: 'tpl-f-min-h', name: 'Minutos a horas', sectorId: 'comun', skillId: 'H1', exerciseTypeId: 'T1',
    variables: [{ name: 'x', label: 'Tiempo', kind: 'int', unit: 'min', min: '30', max: '300', step: '15', show: true }],
    statement: 'Una perfusión dura {x}.', question: '¿Cuántas horas son?', formula: 'x', answerUnit: 'h', unitChoices: ['h', 'min'],
    rounding: { mode: 'decimals', places: 2 },
    predictedErrors: [{ formula: 'respuesta × 3600', unit: 'h', code: 'E3', message: 'Has multiplicado por 60 en lugar de dividir', deviationStep: 1 }, { formula: 'respuesta × 100 ÷ 60', unit: 'h', code: 'E0', message: 'Una hora tiene 60 minutos, no 100', deviationStep: 1 }],
    steps: [{ text: 'De minutos a horas se divide entre 60', formula: 'x', unit: 'h', operation: '{x} ÷ 60 min/h', cancelled: ['min'] }],
    plausibility: '{respuesta}: menos horas que minutos. Tiene sentido.',
    approach: 'min ÷ 60 = h', hint: '1 h = 60 min',
    levels: levels(15, { 1: { x: { min: '60', max: '300', step: '60' } }, 2: { x: { min: '30', max: '300', step: '30' } } }),
  }),
  tpl({
    id: 'tpl-f-pct-mgml', name: 'Porcentaje a mg/ml', sectorId: 'comun', skillId: 'H2', exerciseTypeId: 'T1',
    variables: [{ name: 'p', label: 'Concentración', kind: 'list', unit: '%', values: ['0.5', '0.9', '1', '2', '5', '10', '20'], show: true }],
    statement: 'Una solución está al {p}.', question: '¿Cuántos mg/ml contiene?', formula: 'p', answerUnit: 'mg/ml', unitChoices: ['mg/ml', 'g/ml', 'µg/ml'],
    rounding: { mode: 'none' },
    predictedErrors: [withUnit(E2_DOWN(2), 'mg/ml'), withUnit(E2_UP(2), 'mg/ml')],
    steps: [
      { text: 'Un porcentaje m/v son gramos en 100 ml', formula: 'p × 100[ml]', unit: 'g', operation: '{p} = gramos en 100 ml', cancelled: [] },
      { text: 'Se pasa a mg/ml', formula: 'p', unit: 'mg/ml', operation: '{paso1} ÷ 100 ml × 1000 mg/g', cancelled: ['g'] },
    ],
    plausibility: 'Regla rápida: el porcentaje por 10 da los mg/ml. {respuesta} tiene sentido.',
    approach: '% × 10 = mg/ml', hint: '1 % = 1 g en 100 ml = 10 mg/ml',
    levels: levels(20, { 1: { p: { values: ['1', '2', '10'] } } }),
  }),
  tpl({
    id: 'tpl-f-ratio', name: 'Razón 1:N a mg/ml', sectorId: 'comun', skillId: 'H2', exerciseTypeId: 'T2',
    variables: [{ name: 'n', label: 'Razón', kind: 'list', unit: '', values: ['1000', '10000', '200000'], show: true }],
    statement: 'Adrenalina en dilución 1:{n}.', question: '¿Qué concentración tiene, en mg/ml?', formula: '1[g/ml] ÷ n', answerUnit: 'mg/ml', unitChoices: ['mg/ml'],
    rounding: { mode: 'none' },
    predictedErrors: [withUnit(E2_UP(3), 'mg/ml'), withUnit(E2_DOWN(3), 'mg/ml'), { formula: 'respuesta ÷ 1000', unit: 'mg/ml', code: 'E1', message: 'Falta pasar de gramos a miligramos', deviationStep: 2 }],
    steps: [
      { text: '1:N significa 1 g en N ml', formula: '1[g]', unit: 'g', operation: '1 g en {n} ml', cancelled: [] },
      { text: '1 g = 1000 mg', formula: '1[g]', unit: 'mg', operation: '1 g × 1000 mg/g', cancelled: ['g'] },
      { text: 'Concentración', formula: '1[g/ml] ÷ n', unit: 'mg/ml', operation: '{paso2} ÷ {n} ml', cancelled: [] },
    ],
    plausibility: '1:1000 es 1 mg/ml; cuanto mayor es N, menor es la concentración. {respuesta} tiene sentido.',
    levels: levels(20),
  }),
  tpl({
    id: 'tpl-f-mg-in-ml', name: 'Concentración de una mezcla', sectorId: 'comun', skillId: 'H2', exerciseTypeId: 'T1',
    variables: [
      { name: 'm', label: 'Cantidad', kind: 'int', unit: 'mg', min: '10', max: '1000', step: '10', show: true },
      { name: 'v', label: 'Volumen', kind: 'list', unit: 'ml', values: ['5', '10', '20', '50', '100'], show: true },
    ],
    statement: 'Diluyes {m} hasta un volumen final de {v}.', question: '¿Qué concentración tiene la mezcla?', formula: 'm ÷ v', answerUnit: 'mg/ml', unitChoices: ['mg/ml', 'µg/ml'],
    equivalents: [{ unit: 'µg/ml', factor: '1000' }], rounding: { mode: 'decimals', places: 2 },
    // Evita la colisión con el error de invertir la división (cuando el resultado es 1 mg/ml).
    constraints: { resultMin: '0.1', conditions: ['m ÷ v != 1[mg/ml]'] },
    predictedErrors: [{ formula: '1[mg] × 1[mg] ÷ 1[ml] ÷ 1[ml] ÷ respuesta', unit: 'mg/ml', code: 'E3', message: 'Has dividido el volumen entre la cantidad: es al revés', deviationStep: 1 }, withUnit(E2_UP(1), 'mg/ml')],
    steps: [{ text: 'Concentración = cantidad ÷ volumen', formula: 'm ÷ v', unit: 'mg/ml', operation: '{m} ÷ {v}', cancelled: [] }],
    plausibility: '{respuesta}: mg divididos entre ml. Tiene sentido.',
    approach: 'mg ÷ ml = mg/ml',
    levels: levels(20, { 1: { m: { min: '100', max: '1000', step: '100' }, v: { values: ['10', '100'] } } }),
  }),
  tpl({
    id: 'tpl-f-vol-conc', name: 'Volumen a cargar', sectorId: 'comun', skillId: 'H4', exerciseTypeId: 'T1',
    variables: [
      { name: 'caso', label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [{ name: 'farmaco', unit: '' }, { name: 'conc', unit: 'mg/ml' }], rows: [
        { farmaco: 'ketamina', conc: '50' }, { farmaco: 'midazolam', conc: '5' }, { farmaco: 'furosemida', conc: '10' }, { farmaco: 'ondansetrón', conc: '2' },
      ] },
      { name: 'dosis', label: 'Dosis', kind: 'decimal', unit: 'mg', min: '1', max: '100', step: '0.5', show: true },
    ],
    statement: 'Necesitas {dosis} de {caso.farmaco}. Presentación: {caso.conc}.', question: '¿Qué volumen cargas?', formula: 'dosis ÷ caso.conc', answerUnit: 'ml', unitChoices: ['ml', 'mg', 'µg'],
    rounding: { mode: 'syringe_auto' }, constraints: { resultMin: '0.1', resultMax: '20', conditions: [] },
    predictedErrors: [withUnit(E2_UP(1), 'ml'), withUnit(E2_DOWN(1), 'ml'), { formula: 'dosis × caso.conc ÷ 1[mg·mg/ml] × 1[ml]', unit: 'ml', code: 'E3', message: 'Has multiplicado por la concentración en lugar de dividir', deviationStep: 1 }],
    steps: [{ text: 'Volumen = dosis ÷ concentración', formula: 'dosis ÷ caso.conc', unit: 'ml', operation: '{dosis} ÷ {caso.conc}', cancelled: ['mg'] }],
    plausibility: '{respuesta}: mg entre mg/ml da ml. Tiene sentido.',
    approach: 'Volumen (ml) = dosis (mg) ÷ concentración (mg/ml)',
    levels: levels(25, { 1: { dosis: { min: '10', max: '100', step: '10' } } }),
  }),
  tpl({
    id: 'tpl-f-pct-vol', name: 'Volumen con concentración en %', sectorId: 'comun', skillId: 'H4', exerciseTypeId: 'T1',
    variables: [
      { name: 'mg', label: 'Cantidad', kind: 'int', unit: 'mg', min: '20', max: '200', step: '10', show: true },
      { name: 'p', label: 'Concentración', kind: 'list', unit: '%', values: ['1', '2'], show: true },
    ],
    statement: 'Necesitas {mg} de lidocaína. Presentación al {p}.', question: '¿Qué volumen cargas?', formula: 'mg ÷ p', answerUnit: 'ml', unitChoices: ['ml', 'mg'],
    rounding: { mode: 'syringe_auto' }, constraints: { resultMin: '0.5', resultMax: '20', conditions: [] },
    predictedErrors: [{ formula: 'respuesta × 10', unit: 'ml', code: 'E2', message: 'Olvidas que 1 % son 10 mg/ml: sale diez veces mayor', deviationStep: 1 }],
    steps: [
      { text: 'Pasa el porcentaje a mg/ml', formula: 'p', unit: 'mg/ml', operation: '{p} × 10', cancelled: [] },
      { text: 'Volumen', formula: 'mg ÷ paso1', unit: 'ml', operation: '{mg} ÷ {paso1}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} cabe en una jeringa habitual. Tiene sentido.',
    levels: levels(25),
  }),
  tpl({
    id: 'tpl-f-syringe', name: 'Redondeo según la jeringa', sectorId: 'comun', skillId: 'H11', exerciseTypeId: 'T1',
    variables: [
      { name: 'dosis', label: 'Dosis', kind: 'decimal', unit: 'mg', min: '0.05', max: '2', step: '0.01', show: true },
      { name: 'conc', label: 'Concentración', kind: 'list', unit: 'mg/ml', values: ['0.3', '0.5', '1', '2', '3'], show: true },
    ],
    statement: 'Necesitas {dosis} de un fármaco con presentación de {conc}.', question: '¿Qué volumen mides?', formula: 'dosis ÷ conc', answerUnit: 'ml', unitChoices: ['ml'],
    rounding: { mode: 'syringe_auto' }, constraints: { resultMin: '0.05', resultMax: '9', conditions: [] },
    predictedErrors: [withUnit(E2_UP(1), 'ml')],
    steps: [{ text: 'Volumen y redondeo a la división de la jeringa', formula: 'dosis ÷ conc', unit: 'ml', operation: '{dosis} ÷ {conc}', cancelled: ['mg'] }],
    plausibility: 'Se redondea a la división que la jeringa permite medir: {respuesta}.',
    levels: levels(25),
  }),
  tpl({
    id: 'tpl-f-estimate', name: 'Estimación del volumen', sectorId: 'comun', skillId: 'H12', exerciseTypeId: 'T6',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      { name: 'caso', label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [{ name: 'farmaco', unit: '' }, { name: 'dosis', unit: 'mg/kg' }, { name: 'conc', unit: 'mg/ml' }], rows: [
        { farmaco: 'atropina', dosis: '0.02', conc: '1' }, { farmaco: 'midazolam', dosis: '0.1', conc: '5' }, { farmaco: 'paracetamol', dosis: '15', conc: '10' },
      ] },
    ],
    statement: 'Niño simulado de {peso}. Pauta: {caso.farmaco} {caso.dosis}. Presentación: {caso.conc}.', question: '¿En qué franja está el volumen?', formula: 'caso.dosis × peso ÷ caso.conc', answerUnit: 'ml', unitChoices: ['ml'],
    rounding: { mode: 'decimals', places: 2 },
    bands: [{ label: 'Menos de 0,1 ml', max: '0.1' }, { label: 'Entre 0,1 y 1 ml', min: '0.1', max: '1' }, { label: 'Entre 1 y 10 ml', min: '1', max: '10' }, { label: 'Más de 10 ml', min: '10' }],
    predictedErrors: [],
    steps: [
      { text: 'Dosis', formula: 'caso.dosis × peso', unit: 'mg', operation: '{caso.dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Volumen', formula: 'paso1 ÷ caso.conc', unit: 'ml', operation: '{paso1} ÷ {caso.conc}', cancelled: ['mg'] },
    ],
    plausibility: 'Antes de calcular con exactitud, comprueba el orden de magnitud: {respuesta}.',
    levels: levels(12),
  }),
];

// ---------------------------------------------------------------------------
// Anestesia y reanimación (H2, H3, H4, H6, H7, H9, H10)
// ---------------------------------------------------------------------------

const A: TemplateDefinition[] = [
  tpl({
    id: 'tpl-a-dilucion', name: 'Dilución de efedrina', sectorId: 'anestesia', skillId: 'H6', exerciseTypeId: 'T1',
    variables: [
      { name: 'masa', label: 'Ampolla', kind: 'list', unit: 'mg', values: ['25', '50'], show: true },
      { name: 'vol', label: 'Volumen final', kind: 'list', unit: 'ml', values: ['5', '10', '20'], show: true },
      { name: 'dosis', label: 'Dosis', kind: 'int', unit: 'mg', min: '3', max: '15', step: '1', show: true },
    ],
    statement: 'Diluyes una ampolla de efedrina de {masa} hasta {vol}.', question: '¿Qué volumen contiene {dosis}?', formula: 'dosis ÷ (masa ÷ vol)', answerUnit: 'ml', unitChoices: ['ml', 'mg'],
    rounding: { mode: 'decimals', places: 1 }, constraints: { resultMin: '0.2', resultMax: '20', conditions: [] },
    predictedErrors: [{ formula: 'masa ÷ vol', unit: 'mg/ml', code: 'E4', message: 'Has calculado la concentración: falta el volumen', deviationStep: 2 }, withUnit(E2_UP(2), 'ml')],
    steps: [
      { text: 'Concentración de la dilución', formula: 'masa ÷ vol', unit: 'mg/ml', operation: '{masa} ÷ {vol}', cancelled: [] },
      { text: 'Volumen para la dosis', formula: 'dosis ÷ paso1', unit: 'ml', operation: '{dosis} ÷ {paso1}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta}, menos que el volumen total. Tiene sentido.',
    approach: 'Concentración = masa ÷ volumen; volumen = dosis ÷ concentración',
    levels: levels(30),
  }),
  tpl({
    id: 'tpl-a-fentanilo', name: 'Bolo por peso en µg/kg', sectorId: 'anestesia', skillId: 'H3', exerciseTypeId: 'T1',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '45', max: '110', step: '1', show: true },
      { name: 'dosis', label: 'Pauta', kind: 'list', unit: 'µg/kg', values: ['1', '1.5', '2', '3'], show: true },
      { name: 'conc', label: 'Presentación', kind: 'list', unit: 'µg/ml', values: ['50'], show: true },
    ],
    statement: 'Paciente simulado de {peso}. Pauta: fentanilo {dosis}. Presentación: {conc}.', question: '¿Qué volumen cargas?', formula: 'dosis × peso ÷ conc', answerUnit: 'ml', unitChoices: ['ml', 'µg', 'mg'],
    rounding: { mode: 'decimals', places: 1 }, constraints: { resultMax: '10', conditions: [] },
    predictedErrors: [{ formula: 'dosis × peso', unit: 'µg', code: 'E4', message: 'Has dado la dosis en µg: falta el volumen', deviationStep: 2 }, withUnit(E2_UP(2), 'ml')],
    steps: [
      { text: 'Dosis', formula: 'dosis × peso', unit: 'µg', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Volumen', formula: 'paso1 ÷ conc', unit: 'ml', operation: '{paso1} ÷ {conc}', cancelled: ['µg'] },
    ],
    plausibility: '{respuesta} en una jeringa de 5 o 10 ml. Tiene sentido.',
    levels: levels(30, { 1: { peso: { min: '50', max: '100', multipleOf: '10' }, dosis: { values: ['1', '2'] } } }),
  }),
  tpl({
    id: 'tpl-a-noradrenalina', name: 'Perfusión de noradrenalina', sectorId: 'anestesia', skillId: 'H9', exerciseTypeId: 'T1',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '50', max: '100', step: '1', show: true },
      { name: 'dosis', label: 'Pauta', kind: 'list', unit: 'µg/kg/min', values: ['0.05', '0.1', '0.15', '0.2'], show: true },
      { name: 'caso', label: 'Dilución', kind: 'case_table', unit: '', show: true, columns: [{ name: 'masa', unit: 'mg' }, { name: 'vol', unit: 'ml' }], rows: [{ masa: '10', vol: '100' }, { masa: '4', vol: '50' }, { masa: '8', vol: '100' }] },
    ],
    statement: 'Paciente simulado de {peso}. Pauta: noradrenalina a {dosis}. Dilución: {caso.masa} en {caso.vol}.', question: '¿A qué ritmo programas la bomba?',
    formula: 'dosis × peso × 60[min/h] ÷ (caso.masa ÷ caso.vol)', answerUnit: 'ml/h', unitChoices: ['ml/h', 'µg/min', 'ml/min'],
    rounding: { mode: 'decimals', places: 1 }, constraints: { resultMin: '1', resultMax: '40', conditions: [] },
    predictedErrors: [
      { formula: 'respuesta ÷ 60', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas', deviationStep: 3 },
      { formula: 'respuesta × 1000', unit: 'ml/h', code: 'E1', message: 'No has pasado los mg de la dilución a µg', deviationStep: 1 },
    ],
    steps: [
      { text: 'Concentración', formula: 'caso.masa ÷ caso.vol', unit: 'µg/ml', operation: '{caso.masa} ÷ {caso.vol}', cancelled: [] },
      { text: 'Dosis por minuto', formula: 'dosis × peso', unit: 'µg/min', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Dosis por hora', formula: 'dosis × peso × 60[min/h]', unit: 'µg/h', operation: '{paso2} × 60 min/h', cancelled: ['min'] },
      { text: 'Ritmo', formula: 'paso3 ÷ paso1', unit: 'ml/h', operation: '{paso3} ÷ {paso1}', cancelled: ['µg'] },
    ],
    plausibility: '{respuesta} es un ritmo programable en una bomba. Tiene sentido.',
    approach: 'ml/h = µg/kg/min × kg × 60 ÷ µg/ml',
    levels: levels(45, { 1: { peso: { min: '50', max: '100', multipleOf: '10' }, dosis: { values: ['0.1'] } } }),
  }),
  tpl({
    id: 'tpl-a-bupi-max', name: 'Volumen máximo de bupivacaína', sectorId: 'anestesia', skillId: 'H10', exerciseTypeId: 'T1',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '45', max: '100', step: '1', show: true },
      { name: 'max', label: 'Máximo del caso', kind: 'list', unit: 'mg/kg', values: ['2'], show: true },
      { name: 'p', label: 'Concentración', kind: 'list', unit: '%', values: ['0.25', '0.5'], show: true },
    ],
    statement: 'El protocolo del caso fija un máximo de {max} de bupivacaína. Paciente simulado de {peso}. Presentación al {p}.', question: '¿Volumen máximo?',
    formula: 'max × peso ÷ p', answerUnit: 'ml', unitChoices: ['ml', 'mg'], rounding: { mode: 'decimals', places: 1 },
    predictedErrors: [{ formula: 'max × peso', unit: 'mg', code: 'E4', message: 'Has dado los mg máximos: falta el volumen', deviationStep: 3 }, { formula: 'respuesta × 10', unit: 'ml', code: 'E2', message: 'Olvidas que 0,5 % son 5 mg/ml', deviationStep: 2 }],
    steps: [
      { text: 'Dosis máxima', formula: 'max × peso', unit: 'mg', operation: '{max} × {peso}', cancelled: ['kg'] },
      { text: 'Concentración', formula: 'p', unit: 'mg/ml', operation: '{p} × 10', cancelled: [] },
      { text: 'Volumen máximo', formula: 'paso1 ÷ paso2', unit: 'ml', operation: '{paso1} ÷ {paso2}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} como límite del caso simulado. Tiene sentido.',
    levels: levels(35, { 1: { peso: { min: '50', max: '100', multipleOf: '10' }, p: { values: ['0.5'] } } }),
  }),
  tpl({
    id: 'tpl-a-paracetamol-max', name: 'Dosis máxima por dosis', sectorId: 'anestesia', skillId: 'H10', exerciseTypeId: 'T1',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '40', max: '110', step: '1', show: true },
      { name: 'dosis', label: 'Pauta', kind: 'list', unit: 'mg/kg', values: ['15'], show: true },
      { name: 'max', label: 'Máximo', kind: 'list', unit: 'g', values: ['1'], show: true },
      { name: 'conc', label: 'Presentación', kind: 'list', unit: 'mg/ml', values: ['10'], show: true },
    ],
    statement: 'Paciente simulado de {peso}. Pauta: paracetamol intravenoso {dosis}, máximo {max} por dosis. Presentación: {conc}.', question: '¿Qué volumen administras en el caso?',
    formula: 'mínimo(dosis × peso; max) ÷ conc', answerUnit: 'ml', unitChoices: ['ml', 'mg'], rounding: { mode: 'decimals', places: 1 },
    constraints: { conditions: ['dosis × peso > max'] },
    predictedErrors: [{ formula: 'dosis × peso ÷ conc', unit: 'ml', code: 'E6', message: 'Has superado el máximo indicado en el enunciado', deviationStep: 2 }],
    steps: [
      { text: 'Dosis por peso', formula: 'dosis × peso', unit: 'mg', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Se aplica el máximo del enunciado', formula: 'mínimo(dosis × peso; max)', unit: 'mg', operation: 'mínimo({paso1}; {max})', cancelled: [] },
      { text: 'Volumen', formula: 'paso2 ÷ conc', unit: 'ml', operation: '{paso2} ÷ {conc}', cancelled: ['mg'] },
    ],
    plausibility: 'El máximo del caso limita la dosis: {respuesta}.',
    levels: levels(40),
  }),
  tpl({
    id: 'tpl-a-ritmo', name: 'Ritmo de perfusión en ml/h', sectorId: 'anestesia', skillId: 'H7', exerciseTypeId: 'T1',
    variables: [
      { name: 'dosis', label: 'Dosis por hora', kind: 'int', unit: 'mg/h', min: '1', max: '20', step: '1', show: true },
      { name: 'masa', label: 'Masa', kind: 'list', unit: 'mg', values: ['50', '100', '250'], show: true },
      { name: 'vol', label: 'Volumen', kind: 'list', unit: 'ml', values: ['50', '100'], show: true },
    ],
    statement: 'Perfusión de {masa} en {vol}. Pauta del caso: {dosis}.', question: '¿A cuántos ml/h programas la bomba?', formula: 'dosis ÷ (masa ÷ vol)', answerUnit: 'ml/h', unitChoices: ['ml/h'],
    rounding: { mode: 'decimals', places: 1 },
    // Evita la colisión entre el ritmo y la concentración (error de paso omitido).
    constraints: { resultMin: '0.5', resultMax: '100', conditions: ['dosis × vol ÷ masa ÷ 1[ml/h] != masa ÷ vol ÷ 1[mg/ml]'] },
    predictedErrors: [withUnit(E2_UP(2), 'ml/h'), { formula: 'masa ÷ vol', unit: 'mg/ml', code: 'E4', message: 'Has calculado la concentración: falta el ritmo', deviationStep: 2 }],
    steps: [
      { text: 'Concentración', formula: 'masa ÷ vol', unit: 'mg/ml', operation: '{masa} ÷ {vol}', cancelled: [] },
      { text: 'Ritmo', formula: 'dosis ÷ paso1', unit: 'ml/h', operation: '{dosis} ÷ {paso1}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} es un ritmo de bomba habitual. Tiene sentido.',
    levels: levels(30),
  }),
];

// ---------------------------------------------------------------------------
// Veterinaria de pequeños animales (H3, H4, H5, H7, H8, H9, H11)
// ---------------------------------------------------------------------------

const V: TemplateDefinition[] = [
  tpl({
    id: 'tpl-v-meloxicam', name: 'Meloxicam subcutáneo en perro', sectorId: 'veterinaria', skillId: 'H4', exerciseTypeId: 'T1', species: 'perro',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      { name: 'caso', label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [{ name: 'farmaco', unit: '' }, { name: 'dosis', unit: 'mg/kg' }, { name: 'conc', unit: 'mg/ml' }], rows: [{ farmaco: 'meloxicam', dosis: '0.2', conc: '5' }] },
    ],
    statement: 'Caso simulado: perro de {peso}. Pauta: {caso.farmaco} {caso.dosis} por vía subcutánea. Presentación: {caso.conc}.', question: '¿Qué volumen cargas?',
    formula: 'caso.dosis × peso ÷ caso.conc', answerUnit: 'ml', unitChoices: ['ml', 'mg', 'µg'], rounding: { mode: 'decimals', places: 2 },
    constraints: { resultMin: '0.1', resultMax: '3', conditions: [] },
    predictedErrors: [
      { formula: 'respuesta × 10', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma', deviationStep: 2 },
      { formula: 'caso.dosis × peso', unit: 'mg', code: 'E4', message: 'Has dado la dosis en mg: falta calcular el volumen', deviationStep: 2 },
      { formula: 'caso.dosis × peso × caso.conc ÷ 1[mg/ml] ÷ 1[mg] × 1[ml]', unit: 'ml', code: 'E3', message: 'Has multiplicado por la concentración en lugar de dividir', deviationStep: 2 },
    ],
    steps: [
      { text: 'Dosis', formula: 'caso.dosis × peso', unit: 'mg', operation: '{caso.dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Volumen', formula: 'paso1 ÷ caso.conc', unit: 'ml', operation: '{paso1} ÷ {caso.conc}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} en una jeringa de 1 ml. Tiene sentido.',
    approach: 'Volumen (ml) = dosis (mg/kg) × peso (kg) ÷ concentración (mg/ml)',
    levels: levels(30, { 1: { peso: { min: '10', max: '40', multipleOf: '10' } } }),
  }),
  tpl({
    id: 'tpl-v-buprenorfina', name: 'Buprenorfina en gato', sectorId: 'veterinaria', skillId: 'H11', exerciseTypeId: 'T1', species: 'gato',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'decimal', unit: 'kg', min: '2', max: '7', step: '0.1', show: true },
      { name: 'dosis', label: 'Pauta', kind: 'list', unit: 'mg/kg', values: ['0.01', '0.02'], show: true },
      { name: 'conc', label: 'Presentación', kind: 'list', unit: 'mg/ml', values: ['0.3'], show: true },
    ],
    statement: 'Caso simulado: gato de {peso}. Pauta: buprenorfina {dosis}. Presentación: {conc}.', question: '¿Qué volumen mides?',
    formula: 'dosis × peso ÷ conc', answerUnit: 'ml', unitChoices: ['ml', 'mg'], rounding: { mode: 'instrument', step: '0.01', instrument: 'jeringa de 1 ml' },
    constraints: { resultMax: '1', conditions: [] },
    predictedErrors: [{ formula: 'dosis × peso', unit: 'mg', code: 'E4', message: 'Has dado la dosis en mg: falta el volumen', deviationStep: 2 }, withUnit(E2_UP(2), 'ml')],
    steps: [
      { text: 'Dosis', formula: 'dosis × peso', unit: 'mg', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Volumen redondeado a la división de 0,01 ml', formula: 'paso1 ÷ conc', unit: 'ml', operation: '{paso1} ÷ {conc}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} en una jeringa de 1 ml. Tiene sentido.',
    levels: levels(30, { 1: { peso: { min: '3', max: '6', step: '1' }, dosis: { values: ['0.02'] } } }),
  }),
  tpl({
    id: 'tpl-v-lidocaina-cri', name: 'Infusión continua de lidocaína en perro', sectorId: 'veterinaria', skillId: 'H9', exerciseTypeId: 'T1', species: 'perro',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      { name: 'dosis', label: 'Pauta', kind: 'list', unit: 'µg/kg/min', values: ['25', '50'], show: true },
      { name: 'p', label: 'Presentación', kind: 'list', unit: '%', values: ['2'], show: true },
    ],
    statement: 'Caso simulado: perro de {peso}. Pauta: lidocaína en infusión continua a {dosis}. Presentación al {p}, sin diluir.', question: '¿Ritmo en ml/h?',
    formula: 'dosis × peso × 60[min/h] ÷ p', answerUnit: 'ml/h', unitChoices: ['ml/h', 'mg/h'], rounding: { mode: 'decimals', places: 1 },
    predictedErrors: [{ formula: 'respuesta ÷ 60', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas', deviationStep: 3 }, { formula: 'respuesta × 1000', unit: 'ml/h', code: 'E1', message: 'No has pasado los µg a mg', deviationStep: 2 }],
    steps: [
      { text: 'Dosis por minuto', formula: 'dosis × peso', unit: 'mg/min', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Dosis por hora', formula: 'paso1 × 60[min/h]', unit: 'mg/h', operation: '{paso1} × 60 min/h', cancelled: ['min'] },
      { text: 'Concentración', formula: 'p', unit: 'mg/ml', operation: '{p} × 10', cancelled: [] },
      { text: 'Ritmo', formula: 'paso2 ÷ paso3', unit: 'ml/h', operation: '{paso2} ÷ {paso3}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta}: un ritmo pequeño, coherente sin diluir. Tiene sentido.',
    levels: levels(45, { 1: { peso: { min: '10', max: '40', multipleOf: '10' }, dosis: { values: ['50'] } } }),
  }),
  tpl({
    id: 'tpl-v-diaria', name: 'Dosis diaria repartida', sectorId: 'veterinaria', skillId: 'H5', exerciseTypeId: 'T1', species: 'perro',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      { name: 'dosis', label: 'Pauta diaria', kind: 'list', unit: 'mg/kg/día', values: ['20', '25', '30'], show: true },
      { name: 'tomas', label: 'Tomas al día', kind: 'list', unit: 'tomas/día', values: ['2', '3'], show: true },
    ],
    statement: 'Caso simulado: perro de {peso}. Pauta: {dosis} repartidos en {tomas}.', question: '¿Cuántos mg por toma?',
    formula: 'dosis × peso ÷ tomas', answerUnit: 'mg/toma', unitChoices: ['mg/toma'], rounding: { mode: 'decimals', places: 1 },
    predictedErrors: [{ formula: 'dosis × peso × 1[tomas] ÷ 1[tomas]', unit: 'mg/día', code: 'E4', message: 'Has dado la dosis diaria: falta repartirla en tomas', deviationStep: 2 }],
    steps: [
      { text: 'Dosis diaria', formula: 'dosis × peso', unit: 'mg/día', operation: '{dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Dosis por toma', formula: 'paso1 ÷ tomas', unit: 'mg/toma', operation: '{paso1} ÷ {tomas}', cancelled: ['día'] },
    ],
    plausibility: '{respuesta}: menos que la dosis diaria. Tiene sentido.',
    levels: levels(30),
  }),
  tpl({
    id: 'tpl-v-goteo', name: 'Goteo de fluidoterapia', sectorId: 'veterinaria', skillId: 'H8', exerciseTypeId: 'T1',
    variables: [
      { name: 'vol', label: 'Volumen', kind: 'list', unit: 'ml', values: ['250', '500', '1000'], show: true },
      { name: 't', label: 'Tiempo', kind: 'list', unit: 'h', values: ['2', '4', '6', '8', '12'], show: true },
      { name: 'sist', label: 'Sistema', kind: 'list', unit: 'gotas/ml', values: ['20', '60'], show: true },
    ],
    statement: 'Hay que administrar {vol} en {t} con un sistema de {sist}.', question: '¿A cuántas gotas por minuto?',
    formula: 'vol × sist ÷ t', answerUnit: 'gotas/min', unitChoices: ['gotas/min'], rounding: { mode: 'integer', label: 'gota entera' },
    constraints: { resultMin: '5', resultMax: '250', conditions: [] },
    predictedErrors: [{ formula: 'respuesta × 60', unit: 'gotas/min', code: 'E1', message: 'Has usado horas en lugar de minutos', deviationStep: 2 }],
    steps: [
      { text: 'Gotas totales', formula: 'vol × sist', unit: 'gotas', operation: '{vol} × {sist}', cancelled: ['ml'] },
      { text: 'Minutos', formula: 't', unit: 'min', operation: '{t} × 60 min/h', cancelled: ['h'] },
      { text: 'Ritmo', formula: 'paso1 ÷ paso2', unit: 'gotas/min', operation: '{paso1} ÷ {paso2}', cancelled: [] },
    ],
    plausibility: '{respuesta} es un goteo que se puede contar. Tiene sentido.',
    levels: levels(35),
  }),
  tpl({
    id: 'tpl-v-fluidos', name: 'Mantenimiento en ml/h', sectorId: 'veterinaria', skillId: 'H7', exerciseTypeId: 'T1', species: 'perro',
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '3', max: '40', step: '1', show: true },
      { name: 'ritmo', label: 'Pauta', kind: 'list', unit: 'ml/kg/día', values: ['50', '60'], show: true },
    ],
    statement: 'Caso simulado: perro de {peso}. Pauta de mantenimiento: {ritmo}.', question: '¿A cuántos ml/h programas la bomba?',
    formula: 'ritmo × peso', answerUnit: 'ml/h', unitChoices: ['ml/h', 'ml/día'], rounding: { mode: 'decimals', places: 1 },
    predictedErrors: [{ formula: 'respuesta × 24', unit: 'ml/h', code: 'E1', message: 'Has dado el volumen diario: falta dividir entre 24 h', deviationStep: 2 }],
    steps: [
      { text: 'Volumen diario', formula: 'ritmo × peso', unit: 'ml/día', operation: '{ritmo} × {peso}', cancelled: ['kg'] },
      { text: 'Ritmo por hora', formula: 'paso1', unit: 'ml/h', operation: '{paso1} ÷ 24 h/día', cancelled: ['día'] },
    ],
    plausibility: '{respuesta}: un ritmo horario mucho menor que el diario. Tiene sentido.',
    levels: levels(30),
  }),
];

export const TEMPLATES: TemplateDefinition[] = [...F, ...A, ...V];

// ---------------------------------------------------------------------------
// Preguntas fijas
// ---------------------------------------------------------------------------

const step = (n: number, text: string, operation: string, value: string, unit: string, cancelled: string[] = []) => ({ n, text, operation, result: { value, unit }, cancelled });

export const QUESTIONS: QuestionDefinition[] = [
  {
    id: 'q-f-t7-masa', version: 1, name: 'Conversión relámpago: masa y tiempo', exerciseTypeId: 'T7', sectorId: 'comun', skillId: 'H1', level: 2, targetTimeS: 60,
    statement: 'Diez conversiones en 60 segundos.', question: 'Escribe cada resultado en la unidad indicada.',
    series: [
      { prompt: '0,25 mg en µg', value: '250', unit: 'µg' }, { prompt: '1,5 g en mg', value: '1500', unit: 'mg' }, { prompt: '90 min en h', value: '1.5', unit: 'h' },
      { prompt: '500 µg en mg', value: '0.5', unit: 'mg' }, { prompt: '2 h en min', value: '120', unit: 'min' }, { prompt: '0,1 g en mg', value: '100', unit: 'mg' },
      { prompt: '45 min en h', value: '0.75', unit: 'h' }, { prompt: '2,5 mg en µg', value: '2500', unit: 'µg' }, { prompt: '250 mg en g', value: '0.25', unit: 'g' }, { prompt: '1 l en ml', value: '1000', unit: 'ml' },
    ],
    steps: [step(1, 'mg × 1000 = µg; g × 1000 = mg; min ÷ 60 = h', 'Multiplica o divide por 1000 o por 60', '1000', '')], plausibility: 'Cada conversión cambia la cifra, no la cantidad.',
  },
  {
    id: 'q-f-t7-conc', version: 1, name: 'Conversión relámpago: concentraciones', exerciseTypeId: 'T7', sectorId: 'comun', skillId: 'H2', level: 3, targetTimeS: 60,
    statement: 'Diez conversiones en 60 segundos.', question: 'Escribe cada concentración en mg/ml.',
    series: [
      { prompt: '2 % en mg/ml', value: '20', unit: 'mg/ml' }, { prompt: '0,9 % en mg/ml', value: '9', unit: 'mg/ml' }, { prompt: '1:1000 en mg/ml', value: '1', unit: 'mg/ml' },
      { prompt: '1 % en mg/ml', value: '10', unit: 'mg/ml' }, { prompt: '1:10 000 en mg/ml', value: '0.1', unit: 'mg/ml' }, { prompt: '0,5 % en mg/ml', value: '5', unit: 'mg/ml' },
      { prompt: '5 % en mg/ml', value: '50', unit: 'mg/ml' }, { prompt: '10 % en mg/ml', value: '100', unit: 'mg/ml' }, { prompt: '0,25 % en mg/ml', value: '2.5', unit: 'mg/ml' }, { prompt: '20 % en mg/ml', value: '200', unit: 'mg/ml' },
    ],
    steps: [step(1, '% × 10 = mg/ml; 1:1000 = 1 mg/ml', '1 % = 1 g en 100 ml = 10 mg/ml', '10', 'mg/ml')], plausibility: 'Porcentaje por 10 da mg/ml.',
  },
  {
    id: 'q-a-t3-perfusion', version: 1, name: 'Orden: µg/kg/min a ml/h', exerciseTypeId: 'T3', sectorId: 'anestesia', skillId: 'H9', level: 2, targetTimeS: 40,
    statement: 'Pauta en µg/kg/min y dilución conocida.', question: 'Ordena los pasos para convertir la pauta en un ritmo en ml/h.',
    orderItems: [
      { id: 's1', text: 'Multiplicar la dosis por el peso', producesUnit: 'µg/min' },
      { id: 's2', text: 'Multiplicar por 60', producesUnit: 'µg/h' },
      { id: 's3', text: 'Expresar la concentración de la dilución en µg/ml', producesUnit: 'µg/ml' },
      { id: 's4', text: 'Dividir la dosis por hora entre la concentración', producesUnit: 'ml/h' },
    ],
    validOrders: [['s1', 's2', 's3', 's4'], ['s1', 's3', 's2', 's4'], ['s3', 's1', 's2', 's4']],
    steps: [step(1, 'Dosis × peso', 'µg/kg/min × kg = µg/min', '1', 'µg/min', ['kg']), step(2, '× 60', 'µg/min × 60 min/h = µg/h', '60', 'µg/h', ['min']), step(3, 'Concentración', 'mg ÷ ml → µg/ml', '1', 'µg/ml'), step(4, 'Ritmo', 'µg/h ÷ µg/ml = ml/h', '1', 'ml/h', ['µg'])],
    plausibility: 'El paso de la concentración puede ir en cualquier posición antes del último.',
  },
  {
    id: 'q-v-t3-volumen', version: 1, name: 'Orden: volumen por peso', exerciseTypeId: 'T3', sectorId: 'veterinaria', skillId: 'H4', level: 2, targetTimeS: 30,
    statement: 'Pauta en mg/kg y presentación en mg/ml.', question: 'Ordena los pasos para calcular el volumen a cargar.',
    orderItems: [
      { id: 's1', text: 'Leer el peso del caso simulado', producesUnit: 'kg' },
      { id: 's2', text: 'Multiplicar la pauta por el peso', producesUnit: 'mg' },
      { id: 's3', text: 'Dividir la dosis entre la concentración', producesUnit: 'ml' },
      { id: 's4', text: 'Redondear a la división de la jeringa', producesUnit: 'ml' },
    ],
    validOrders: [['s1', 's2', 's3', 's4']],
    steps: [step(1, 'Peso', 'kg del caso', '1', 'kg'), step(2, 'Dosis', 'mg/kg × kg = mg', '1', 'mg', ['kg']), step(3, 'Volumen', 'mg ÷ mg/ml = ml', '1', 'ml', ['mg']), step(4, 'Redondeo', 'A la división de la jeringa', '1', 'ml')],
    plausibility: 'Primero la dosis, después el volumen y por último el redondeo.',
  },
  {
    id: 'q-f-t2-jeringa', version: 1, name: '¿Qué jeringa?', exerciseTypeId: 'T2', sectorId: 'comun', skillId: 'H11', level: 2, targetTimeS: 20,
    statement: 'Hay que medir 0,27 ml.', question: '¿Qué jeringa permite medirlo con precisión?',
    options: [
      { label: 'Jeringa de 1 ml (divisiones de 0,01 ml)', correct: true },
      { label: 'Jeringa de 5 ml (divisiones de 0,2 ml)', correct: false, errorCode: 'E7', message: 'Con divisiones de 0,2 ml no se puede medir 0,27 ml' },
      { label: 'Jeringa de 20 ml (divisiones de 1 ml)', correct: false, errorCode: 'E7', message: 'La división de 1 ml es demasiado gruesa' },
    ],
    steps: [step(1, 'Precisión necesaria', '0,27 ml exige divisiones de 0,01 ml', '0.01', 'ml')], plausibility: 'Volúmenes menores de 1 ml se miden con jeringa de 1 ml.',
  },
];

// ---------------------------------------------------------------------------
// Estructura: unidades y lecciones de cada itinerario
// ---------------------------------------------------------------------------

export interface UnitSeed {
  unit: Omit<Unit, 'order' | 'itineraryId' | 'prerequisiteUnitId'>;
  templates: string[];
  questions?: string[];
}

export const STRUCTURE: Record<string, UnitSeed[]> = {
  'it-fundamentos': [
    { unit: { id: 'u-f-1', name: 'Conversión de unidades', description: 'Masa, volumen y tiempo', skills: ['H1'], guide: { equivalences: ['1 g = 1000 mg', '1 mg = 1000 µg', '1 l = 1000 ml', '1 h = 60 min'], example: { statement: 'Tienes 0,25 mg. ¿Cuántos microgramos son?', steps: ['0,25 mg × 1000 µg/mg = 250 µg'], answer: '250 µg' } } }, templates: ['tpl-f-mg-ug', 'tpl-f-g-mg', 'tpl-f-min-h'], questions: ['q-f-t7-masa'] },
    { unit: { id: 'u-f-2', name: 'Concentraciones', description: 'mg/ml, porcentaje y razones 1:N', skills: ['H2'], guide: { equivalences: ['1 % = 1 g en 100 ml = 10 mg/ml', '1:1000 = 1 mg/ml', '1:10 000 = 0,1 mg/ml'], example: { statement: 'Una solución al 2 %. ¿Cuántos mg/ml?', steps: ['2 % = 2 g en 100 ml', '2000 mg ÷ 100 ml = 20 mg/ml'], answer: '20 mg/ml' } } }, templates: ['tpl-f-pct-mgml', 'tpl-f-ratio', 'tpl-f-mg-in-ml'], questions: ['q-f-t7-conc'] },
    { unit: { id: 'u-f-3', name: 'Volumen a cargar', description: 'De la dosis al volumen', skills: ['H4'], guide: { equivalences: ['Volumen (ml) = dosis (mg) ÷ concentración (mg/ml)'], example: { statement: 'Necesitas 60 mg de lidocaína al 2 %.', steps: ['2 % = 20 mg/ml', '60 mg ÷ 20 mg/ml = 3 ml'], answer: '3 ml' } } }, templates: ['tpl-f-vol-conc', 'tpl-f-pct-vol'] },
    { unit: { id: 'u-f-4', name: 'Redondeo según el instrumento', description: 'Jeringas, bombas y goteros', skills: ['H11'], guide: { equivalences: ['Jeringa de 1 ml: 0,01 ml', 'Jeringa de 3 ml: 0,1 ml', 'Jeringa de 10 ml: 0,2 ml', 'Bomba: 0,1 ml/h', 'Goteo: gota entera'], example: { statement: '0,2667 ml en jeringa de 1 ml', steps: ['Se redondea a la centésima: 0,27 ml'], answer: '0,27 ml' } } }, templates: ['tpl-f-syringe'], questions: ['q-f-t2-jeringa'] },
    { unit: { id: 'u-f-5', name: 'Estimación y plausibilidad', description: 'Orden de magnitud antes de dar una cifra por buena', skills: ['H12'], guide: { equivalences: ['Compara con el volumen de la jeringa', 'Un factor de diez cambia la franja'], example: { statement: 'Niño simulado de 15 kg, atropina 0,02 mg/kg, 1 mg/ml', steps: ['0,3 mg ÷ 1 mg/ml = 0,3 ml', 'Franja: entre 0,1 y 1 ml'], answer: 'Entre 0,1 y 1 ml' } } }, templates: ['tpl-f-estimate', 'tpl-f-vol-conc'] },
  ],
  'it-anestesia': [
    { unit: { id: 'u-a-1', name: 'Diluciones', description: 'Concentración final y volumen para una dosis', skills: ['H6'], guide: { equivalences: ['Concentración = masa ÷ volumen final'], example: { statement: 'Efedrina 50 mg hasta 10 ml; ¿volumen para 10 mg?', steps: ['50 mg ÷ 10 ml = 5 mg/ml', '10 mg ÷ 5 mg/ml = 2 ml'], answer: '2 ml' } } }, templates: ['tpl-a-dilucion', 'tpl-f-pct-vol'] },
    { unit: { id: 'u-a-2', name: 'Dosis por peso', description: 'Bolos en µg/kg y mg/kg', skills: ['H3', 'H4'], guide: { equivalences: ['Dosis = pauta × peso', 'Volumen = dosis ÷ concentración'], example: { statement: 'Paciente simulado de 70 kg, 2 µg/kg, 50 µg/ml', steps: ['2 × 70 = 140 µg', '140 ÷ 50 = 2,8 ml'], answer: '2,8 ml' } } }, templates: ['tpl-a-fentanilo'] },
    { unit: { id: 'u-a-3', name: 'Perfusiones en µg/kg/min', description: 'De la pauta al ritmo de la bomba', skills: ['H9'], guide: { equivalences: ['ml/h = µg/kg/min × kg × 60 ÷ µg/ml'], example: { statement: '80 kg, noradrenalina 0,1 µg/kg/min, 10 mg en 100 ml', steps: ['100 µg/ml', '8 µg/min', '480 µg/h', '4,8 ml/h'], answer: '4,8 ml/h' } } }, templates: ['tpl-a-noradrenalina'], questions: ['q-a-t3-perfusion'] },
    { unit: { id: 'u-a-4', name: 'Dosis máximas', description: 'Límites del caso y anestésicos locales', skills: ['H10'], guide: { equivalences: ['Dosis aplicada = mínimo(dosis calculada; máximo del enunciado)'], example: { statement: '70 kg, 15 mg/kg, máx. 1 g, 10 mg/ml', steps: ['1050 mg > 1000 mg', '1000 mg ÷ 10 mg/ml = 100 ml'], answer: '100 ml' } } }, templates: ['tpl-a-bupi-max', 'tpl-a-paracetamol-max'] },
    { unit: { id: 'u-a-5', name: 'Ritmo de perfusión', description: 'mg/h a ml/h', skills: ['H7'], guide: { equivalences: ['ml/h = mg/h ÷ mg/ml'], example: { statement: '100 mg en 50 ml a 4 mg/h', steps: ['2 mg/ml', '4 ÷ 2 = 2 ml/h'], answer: '2 ml/h' } } }, templates: ['tpl-a-ritmo'] },
  ],
  'it-vet-pequenos': [
    { unit: { id: 'u-v-1', name: 'Dosis por peso y volumen', description: 'mg/kg por especie', skills: ['H3', 'H4'], guide: { equivalences: ['Volumen = mg/kg × kg ÷ mg/ml'], example: { statement: 'Perro de 24 kg, meloxicam 0,2 mg/kg, 5 mg/ml', steps: ['4,8 mg', '0,96 ml'], answer: '0,96 ml' } } }, templates: ['tpl-v-meloxicam'], questions: ['q-v-t3-volumen'] },
    { unit: { id: 'u-v-2', name: 'Volúmenes pequeños', description: 'Gatos y jeringa de 1 ml', skills: ['H11'], guide: { equivalences: ['Jeringa de 1 ml: divisiones de 0,01 ml'], example: { statement: 'Gato de 4 kg, buprenorfina 0,02 mg/kg, 0,3 mg/ml', steps: ['0,08 mg', '0,2667 ml → 0,27 ml'], answer: '0,27 ml' } } }, templates: ['tpl-v-buprenorfina'] },
    { unit: { id: 'u-v-3', name: 'Infusión continua', description: 'µg/kg/min a ml/h', skills: ['H9'], guide: { equivalences: ['ml/h = µg/kg/min × kg × 60 ÷ µg/ml'], example: { statement: 'Perro de 20 kg, lidocaína 50 µg/kg/min, 2 %', steps: ['1 mg/min', '60 mg/h', '20 mg/ml', '3 ml/h'], answer: '3 ml/h' } } }, templates: ['tpl-v-lidocaina-cri'] },
    { unit: { id: 'u-v-4', name: 'Dosis diaria repartida', description: 'mg/kg/día en tomas', skills: ['H5'], guide: { equivalences: ['Dosis por toma = mg/kg/día × kg ÷ tomas'], example: { statement: 'Perro de 20 kg, 25 mg/kg/día en 2 tomas', steps: ['500 mg/día', '250 mg por toma'], answer: '250 mg' } } }, templates: ['tpl-v-diaria'] },
    { unit: { id: 'u-v-5', name: 'Fluidoterapia', description: 'ml/kg/día, ml/h y gotas/min', skills: ['H7', 'H8'], guide: { equivalences: ['gotas/min = ml × gotas/ml ÷ min'], example: { statement: '1000 ml en 8 h con 20 gotas/ml', steps: ['20 000 gotas', '480 min', '41,67 → 42 gotas/min'], answer: '42 gotas/min' } } }, templates: ['tpl-v-fluidos', 'tpl-v-goteo'] },
  ],
};

export const LESSON_TITLES: Record<LessonKind, string> = {
  guided: 'Concepto guiado', supported: 'Práctica con apoyos', free: 'Práctica libre', mixed: 'Mixta', challenge: 'Reto de unidad',
};

export const LESSON_SIZE: Record<LessonKind, number> = { guided: 8, supported: 8, free: 10, mixed: 10, challenge: 10 };
export const LESSON_LEVELS: Record<LessonKind, (1 | 2 | 3 | 4 | 5)[]> = {
  guided: [1, 1, 2, 2], supported: [2, 2, 3], free: [3, 3, 3, 4], mixed: [3, 4], challenge: [3, 4, 4],
};

export function skillOfTemplate(id: string): SkillCode {
  return (TEMPLATES.find((t) => t.id === id)?.skillId ?? QUESTIONS.find((q) => q.id === id)?.skillId ?? 'H1') as SkillCode;
}

// ---------------------------------------------------------------------------
// Catálogos de unidades, instrumentos y voz (editables desde el back office)
// ---------------------------------------------------------------------------

import type { Instrument, MeasureUnit, VoiceLexicon } from '@vtm/contracts';

export const MEASURE_UNITS: MeasureUnit[] = [
  { symbol: 'g', name: 'gramo', readingSingular: 'gramo', readingPlural: 'gramos', gender: 'm', spokenForms: ['gramos', 'gramo'], magnitude: 'masa', factor: '1' },
  { symbol: 'mg', name: 'miligramo', readingSingular: 'miligramo', readingPlural: 'miligramos', gender: 'm', spokenForms: ['miligramos', 'miligramo'], magnitude: 'masa', factor: '0.001' },
  { symbol: 'µg', name: 'microgramo', readingSingular: 'microgramo', readingPlural: 'microgramos', gender: 'm', spokenForms: ['microgramos', 'microgramo'], magnitude: 'masa', factor: '0.000001' },
  { symbol: 'kg', name: 'kilogramo', readingSingular: 'kilo', readingPlural: 'kilos', gender: 'm', spokenForms: ['kilos', 'kilo', 'kilogramos'], magnitude: 'masa', factor: '1000' },
  { symbol: 'ml', name: 'mililitro', readingSingular: 'mililitro', readingPlural: 'mililitros', gender: 'm', spokenForms: ['mililitros', 'mililitro', 'eme ele', 'ce ce', 'centímetros cúbicos'], magnitude: 'volumen', factor: '1' },
  { symbol: 'l', name: 'litro', readingSingular: 'litro', readingPlural: 'litros', gender: 'm', spokenForms: ['litros', 'litro'], magnitude: 'volumen', factor: '1000' },
  { symbol: 'min', name: 'minuto', readingSingular: 'minuto', readingPlural: 'minutos', gender: 'm', spokenForms: ['minutos', 'minuto'], magnitude: 'tiempo', factor: '60' },
  { symbol: 'h', name: 'hora', readingSingular: 'hora', readingPlural: 'horas', gender: 'f', spokenForms: ['horas', 'hora'], magnitude: 'tiempo', factor: '3600' },
  { symbol: 'gotas', name: 'gota', readingSingular: 'gota', readingPlural: 'gotas', gender: 'f', spokenForms: ['gotas', 'gota'], magnitude: 'gotas', factor: '1' },
  { symbol: 'UI', name: 'unidad internacional', readingSingular: 'unidad', readingPlural: 'unidades internacionales', gender: 'f', spokenForms: ['unidades internacionales', 'unidades', 'unidad'], magnitude: 'UI', factor: '1' },
  { symbol: '%', name: 'por ciento (m/v)', readingSingular: 'por ciento', readingPlural: 'por ciento', gender: 'm', spokenForms: ['por ciento'], magnitude: 'concentración', factor: '0.01' },
];

export const INSTRUMENTS: Instrument[] = [
  { id: 'jer-1', name: 'Jeringa de 1 ml', capacityMl: '1', step: '0.01', unit: 'ml' },
  { id: 'jer-3', name: 'Jeringa de 2 o 3 ml', capacityMl: '3', step: '0.1', unit: 'ml' },
  { id: 'jer-10', name: 'Jeringa de 5 o 10 ml', capacityMl: '10', step: '0.2', unit: 'ml' },
  { id: 'jer-50', name: 'Jeringa de 20 o 50 ml', capacityMl: '50', step: '1', unit: 'ml' },
  { id: 'bomba', name: 'Bomba de perfusión', step: '0.1', unit: 'ml/h' },
  { id: 'goteo', name: 'Sistema de goteo', step: '1', unit: 'gotas/min' },
];

export const VOICE_LEXICON: VoiceLexicon = {
  confusions: [{ from: 'como', to: 'coma' }, { from: 'toma', to: 'coma' }, { from: 'cerro', to: 'cero' }, { from: 'tos', to: 'dos' }],
  commands: [
    { command: 'repite', synonyms: ['repite', 'otra vez', 'repítelo'] },
    { command: 'repite_datos', synonyms: ['repite los datos', 'los datos'] },
    { command: 'siguiente', synonyms: ['siguiente', 'continuar'] },
    { command: 'no_lo_se', synonyms: ['no lo sé', 'ni idea'] },
    { command: 'pausa', synonyms: ['pausa', 'espera', 'un momento'] },
    { command: 'continua', synonyms: ['continúa', 'sigue'] },
    { command: 'si', synonyms: ['sí', 'correcto', 'eso es', 'vale'] },
    { command: 'no', synonyms: ['no', 'incorrecto', 'corrige'] },
    { command: 'explica', synonyms: ['explica', 'cómo se hace'] },
    { command: 'salta', synonyms: ['salta'] },
    { command: 'mas_despacio', synonyms: ['más despacio'] },
    { command: 'mas_rapido', synonyms: ['más rápido'] },
    { command: 'cifra_a_cifra', synonyms: ['cifra a cifra'] },
    { command: 'teclado', synonyms: ['teclado', 'escribir'] },
    { command: 'salir', synonyms: ['salir', 'terminar'] },
    { command: 'mas_informacion', synonyms: ['más información'] },
  ],
  sectorSynonyms: [{ sectorId: 'anestesia', spoken: 'gammas', unit: 'µg', enabledByDefault: false }],
};
