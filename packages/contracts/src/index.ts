/**
 * Contratos compartidos de VolutrainMed.
 *
 * Fuente canónica de los formatos que cruzan entre servidor, back office y app:
 *  - Paquete de contenido firmado (por itinerario) y paquete global.
 *  - Manifiesto de contenido y lista de retirada.
 *  - Intentos, sesiones y eventos que suben desde el dispositivo.
 *  - Campañas de anuncios propios y parámetros de la pausa promocional.
 *
 * Convenciones:
 *  - Toda cifra viaja como cadena decimal con punto ("0.96"), nunca como número
 *    binario. La app la muestra con coma ("0,96").
 *  - El dispositivo no calcula fórmulas (diseño D2): recibe variantes resueltas.
 *  - Identificadores de intentos y sesiones: UUID v7 creados en el dispositivo.
 */

export const PACKAGE_FORMAT = 1 as const;

/** Cadena decimal canónica: sin ceros finales, con cero inicial, punto decimal. */
export type DecimalString = string;

// ---------------------------------------------------------------------------
// Catálogos y estructura
// ---------------------------------------------------------------------------

export type SkillCode =
  | 'H1' | 'H2' | 'H3' | 'H4' | 'H5' | 'H6'
  | 'H7' | 'H8' | 'H9' | 'H10' | 'H11' | 'H12';

export interface Skill {
  id: SkillCode;
  name: string;
  description?: string;
}

export interface Sector {
  id: string;
  code: string;
  name: string;
  description: string;
  icon: string;
  typicalCalcs: string;
  defaultItineraryId: string | null;
  itineraryIds: string[];
  /** Sectores que exigen dos revisores (p. ej. pediatría). */
  doubleReview?: boolean;
  order: number;
}

export interface ItinerarySummary {
  id: string;
  sectorId: string;
  name: string;
  description: string;
  recommendedLevel: 'cero' | 'afianzar' | 'agilidad';
  order: number;
  /** Fundamentos va incluido en la app y es gratuito. */
  isFoundations: boolean;
}

export type LessonKind = 'guided' | 'supported' | 'free' | 'mixed' | 'challenge';

export const LESSON_KIND_ORDER: LessonKind[] = ['guided', 'supported', 'free', 'mixed', 'challenge'];

export interface UnitGuide {
  equivalences: string[];
  example: { statement: string; steps: string[]; answer: string };
}

export interface Unit {
  id: string;
  itineraryId: string;
  order: number;
  name: string;
  description: string;
  skills: SkillCode[];
  prerequisiteUnitId: string | null;
  guide: UnitGuide;
}

export interface LessonSlot {
  position: number;
  /** Plantilla o pregunta fija. */
  templateId?: string;
  questionId?: string;
  difficulty: 1 | 2 | 3 | 4 | 5;
  skillId: SkillCode;
}

export interface Lesson {
  id: string;
  unitId: string;
  order: number;
  kind: LessonKind;
  title: string;
  estimatedMinutes: number;
  slots: LessonSlot[];
}

// ---------------------------------------------------------------------------
// Tipos de ejercicio por bloques (intérprete genérico, diseño D9)
// ---------------------------------------------------------------------------

export type PresentationBlock =
  | 'statement' | 'highlighted_data' | 'image' | 'operation_with_gaps'
  | 'step_list' | 'worked_calculation' | 'timer';

export type ResponseBlock =
  | 'numeric_unit' | 'single_choice' | 'multiple_choice' | 'ordering'
  | 'matching' | 'fill_gaps' | 'yes_no' | 'range_choice' | 'conversion_series'
  | 'step_pick';

export type GradingRule = 'numeric_tolerance' | 'exact_match' | 'order_equivalences' | 'pair_set';

export type BehaviourBlock = 'hints' | 'time_limit' | 'scoring' | 'second_try';

/** Bloques que el intérprete de esta versión de la app sabe dibujar. */
export const VOICE_COMPATIBLE_RESPONSES: ResponseBlock[] = [
  'numeric_unit', 'single_choice', 'range_choice', 'conversion_series', 'yes_no', 'step_pick',
];

export interface ExerciseTypeStep {
  presentation: PresentationBlock[];
  response: ResponseBlock;
  grading: GradingRule;
}

export interface ExerciseType {
  id: string; // T1, T2... o identificador de tipo creado con el creador
  version: number;
  name: string;
  description: string;
  steps: ExerciseTypeStep[];
  behaviour: BehaviourBlock[];
  voiceCompatible: boolean;
  minAppVersion: string;
  /** Límite de tiempo en segundos, si el tipo lo declara (T6: 15, T7: 60). */
  timeLimitS?: number;
}

// ---------------------------------------------------------------------------
// Variantes resueltas
// ---------------------------------------------------------------------------

export type ErrorCode = 'E0' | 'E1' | 'E2' | 'E3' | 'E4' | 'E5' | 'E6' | 'E7';

export const ERROR_LABELS: Record<ErrorCode, string> = {
  E0: 'Sin clasificar',
  E1: 'Unidad',
  E2: 'Orden de magnitud',
  E3: 'Operación invertida',
  E4: 'Paso omitido',
  E5: 'Dato equivocado',
  E6: 'Límite no aplicado',
  E7: 'Redondeo',
};

/** Errores críticos por definición (además de la desviación de factor 5). */
export const CRITICAL_CODES: ErrorCode[] = ['E1', 'E2', 'E6'];

export type Rounding =
  | { mode: 'none' }
  | { mode: 'decimals'; places: number }
  | { mode: 'instrument'; step: DecimalString; instrument: string }
  | { mode: 'integer'; label?: string };

export type Tolerance =
  | { kind: 'exact' }
  | { kind: 'abs'; value: DecimalString }
  | { kind: 'rel'; percent: DecimalString };

export interface Quantity {
  value: DecimalString;
  unit: string;
}

export interface AnswerSpec {
  value: DecimalString;
  unit: string;
  /** Unidad fija como sufijo (niveles 1 a 3) o a elegir (niveles 4 y 5). */
  unitFixed: boolean;
  unitChoices: string[];
  /** Unidades equivalentes aceptadas: valor en esa unidad = valor × factor. */
  equivalents: { unit: string; factor: DecimalString }[];
  rounding: Rounding;
  tolerance: Tolerance;
  /** Valor sin redondear, para la nota «Se redondea a …». */
  unrounded?: DecimalString;
}

export interface PredictedError {
  value: DecimalString;
  unit: string;
  code: ErrorCode;
  message: string;
  /** Paso en el que se desvía quien comete este error (para marcarlo). */
  deviationStep?: number;
}

export interface ExplanationStep {
  n: number;
  text: string;
  operation: string;
  result: Quantity;
  cancelled: string[];
  /** Equivalente textual de la cancelación para lector de pantalla. */
  cancelledSpoken?: string;
}

export type StatementSegment =
  | { t: 'text'; v: string }
  | { t: 'qty'; value: DecimalString; unit: string; key?: string };

export interface ChoiceOption {
  id: string;
  label: string;
  value?: DecimalString;
  unit?: string;
  correct: boolean;
  errorCode?: ErrorCode;
  message?: string;
}

export interface OrderItem {
  id: string;
  text: string;
  producesUnit?: string;
}

export interface ConversionItem {
  prompt: string;
  tts: string;
  answer: AnswerSpec;
}

export interface ChainPart {
  prompt: string;
  tts: string;
  answer: AnswerSpec;
  predictedErrors: PredictedError[];
}

export interface WorkedStep {
  n: number;
  text: string;
  correct: boolean;
  correction?: string;
}

export interface MatchPair {
  left: string;
  right: string;
}

export interface Variant {
  id: string;
  templateId: string | null;
  questionId: string | null;
  templateVersion: number;
  level: 1 | 2 | 3 | 4 | 5;
  exerciseTypeId: string;
  exerciseTypeVersion: number;
  skillId: SkillCode;
  sectorId: string;
  species?: string;
  statement: StatementSegment[];
  /** Pregunta, separada de los datos (la voz la dice al final). */
  question: string;
  tts: string;
  approach?: string;
  hint?: string;
  targetTimeS: number;
  answer?: AnswerSpec;
  predictedErrors: PredictedError[];
  steps: ExplanationStep[];
  plausibility: string;
  options?: ChoiceOption[];
  orderItems?: OrderItem[];
  validOrders?: string[][];
  series?: ConversionItem[];
  chain?: ChainPart[];
  worked?: WorkedStep[];
  pairs?: MatchPair[];
  /** Marca de contenido de demostración pendiente de validación profesional. */
  demo?: boolean;
}

export interface TemplateSummary {
  id: string;
  version: number;
  name: string;
  skillId: SkillCode;
  sectorId: string;
  exerciseTypeId: string;
  species?: string;
  targetTimeS: Record<string, number>;
  variantsByLevel: Record<string, string[]>;
}

export interface PlacementItem {
  unitId: string;
  variantIds: string[];
}

export interface ItineraryPackage {
  format: typeof PACKAGE_FORMAT;
  contentVersion: string;
  minAppVersion: string;
  itinerary: ItinerarySummary;
  units: Unit[];
  lessons: Lesson[];
  templates: TemplateSummary[];
  variants: Variant[];
  placement: PlacementItem[];
}

// ---------------------------------------------------------------------------
// Catálogos de unidades y voz
// ---------------------------------------------------------------------------

export interface MeasureUnit {
  symbol: string;
  name: string;
  /** Lectura en singular y plural: «miligramo» / «miligramos». */
  readingSingular: string;
  readingPlural: string;
  gender: 'm' | 'f';
  spokenForms: string[];
  magnitude: string;
  /** Factor a la unidad base de su magnitud (mg → g: 0.001). */
  factor: DecimalString;
}

export interface Instrument {
  id: string;
  name: string;
  capacityMl?: DecimalString;
  step: DecimalString;
  unit: string;
}

export interface VoiceLexicon {
  confusions: { from: string; to: string }[];
  commands: { command: VoiceCommand; synonyms: string[] }[];
  sectorSynonyms: { sectorId: string | null; spoken: string; unit: string; enabledByDefault: boolean }[];
}

export type VoiceCommand =
  | 'repite' | 'repite_datos' | 'siguiente' | 'no_lo_se' | 'pausa' | 'continua'
  | 'si' | 'no' | 'explica' | 'salta' | 'mas_despacio' | 'mas_rapido'
  | 'cifra_a_cifra' | 'teclado' | 'salir' | 'mas_informacion';

// ---------------------------------------------------------------------------
// Gamificación
// ---------------------------------------------------------------------------

export type AchievementMetric =
  | 'streak_days' | 'correct_in_row' | 'skills_mastered' | 'handsfree_sessions'
  | 'valid_timetrial' | 'no_critical_exercises' | 'lessons_completed' | 'units_mastered';

export interface Achievement {
  id: string;
  name: string;
  description: string;
  category: 'constancia' | 'precision' | 'agilidad' | 'dominio';
  icon: string;
  condition: { metric: AchievementMetric; op: '>=' | '>' | '=='; value: number; scope: 'global' | 'skill' | 'sector' };
  secret: boolean;
  retroactive: boolean;
  validFrom?: string | null;
  validTo?: string | null;
}

export interface LeagueConfig {
  groupSize: number;
  divisions: string[];
  promote: number;
  relegate: number;
  pointsPerCorrect: number;
  timetrialBonus: number;
  dailyCap: number;
  weekStartsOn: 1;
  groupBySector: boolean;
  minHumanMs: number;
}

// ---------------------------------------------------------------------------
// Anuncios propios (cambio add-house-ads-and-premium)
// ---------------------------------------------------------------------------

export type AdContext =
  | 'always'
  | 'wait_gt0_in_lesson'
  | 'trial_available'
  | 'handsfree_limit_or_after_handsfree'
  | 'streak_gte_3'
  | 'prices_fresh_7d'
  | 'after_unit_completed'
  | 'last_pause_lesson_with_errors'
  | 'last_pause_lesson_perfect'
  | 'after_timetrial'
  | 'orgs_enabled';

export type AdCtaAction = 'paywall' | 'trial' | 'trial_or_paywall' | 'org_code';

export interface AdCreative {
  id: string; // PA-01…
  kind: 'fallback' | 'generic' | 'contextual';
  context: AdContext;
  weight: number;
  dailyCap: number | null;
  headline: string;
  body: string;
  cta: string;
  ctaAlt?: string;
  ctaAction: AdCtaAction;
  voiceSpot: string | null;
  illustration: string;
}

export interface AdCampaign {
  id: string;
  name: string;
  sectorIds: string[] | null;
  startsAt: string | null;
  endsAt: string | null;
  creatives: AdCreative[];
}

export interface AdParams {
  waitS: number; // 0..5, 3 por defecto
  frequencyTouch: number; // 1 = cada ejercicio
  frequencyVoice: number;
  defaultDailyCap: number; // 6
}

export interface FreePlanRules {
  handsfreeDailyMinutes: number;
  freeUnitsPerItinerary: number;
}

export interface GlobalPackage {
  format: typeof PACKAGE_FORMAT;
  contentVersion: string;
  minAppVersion: string;
  sectors: Sector[];
  itineraries: ItinerarySummary[];
  skills: Skill[];
  exerciseTypes: ExerciseType[];
  units: MeasureUnit[];
  instruments: Instrument[];
  voiceLexicon: VoiceLexicon;
  achievements: Achievement[];
  league: LeagueConfig;
  ads: { params: AdParams; campaigns: AdCampaign[] };
  freePlan: FreePlanRules;
  orgsEnabled: boolean;
}

// ---------------------------------------------------------------------------
// Manifiesto y retirada
// ---------------------------------------------------------------------------

export interface SignedFile {
  id: string;
  version: string;
  url: string;
  sha256: string;
  /** Ed25519 (base64) sobre la cadena `${id}|${version}|${sha256}`. */
  signature: string;
  size: number;
  minAppVersion: string;
}

export interface Revocations {
  version: number;
  templateIds: string[];
  questionIds: string[];
  variantIds: string[];
}

export interface ContentManifest {
  contentVersion: string;
  releaseId: string;
  rolloutBucket: number;
  publicKeyId: string;
  global: SignedFile;
  packages: (SignedFile & { itineraryId: string })[];
  revocations: Revocations;
  /** Contenido más reciente que exige una app superior a la instalada. */
  newerRequiresAppVersion?: string | null;
  testPackage?: boolean;
}

export function signaturePayload(f: Pick<SignedFile, 'id' | 'version' | 'sha256'>): string {
  return `${f.id}|${f.version}|${f.sha256}`;
}

// ---------------------------------------------------------------------------
// Aprendizaje: intentos, sesiones y eventos (suben del dispositivo)
// ---------------------------------------------------------------------------

export type SessionMode =
  | 'lesson' | 'challenge' | 'review' | 'warmup' | 'placement'
  | 'timetrial' | 'timetrial_untimed' | 'handsfree' | 'practice';

export type Verdict = 'correct' | 'correct_note' | 'incorrect' | 'dont_know' | 'skipped';

export type InputMode = 'touch' | 'keyboard' | 'voice';

export interface Attempt {
  id: string;
  sessionId: string;
  deviceId: string;
  mode: SessionMode;
  lessonId: string | null;
  templateId: string | null;
  questionId: string | null;
  variantId: string;
  skillId: SkillCode;
  exerciseTypeId: string;
  level: number;
  /** 1 = primer intento; 2 = segundo intento con otra variante (no puntúa). */
  attemptNumber: 1 | 2;
  answerValue: DecimalString | null;
  answerUnit: string | null;
  answerPayload?: unknown;
  verdict: Verdict;
  errorCode: ErrorCode | null;
  critical: boolean;
  hintsUsed: number;
  responseMs: number;
  targetMs: number;
  inputMode: InputMode;
  voiceMetrics?: { asrMs: number; confidence: number; recognitionFailures: number } | null;
  points: number;
  contentVersion: string;
  deviceTime: string;
}

export interface SessionRecord {
  id: string;
  deviceId: string;
  mode: SessionMode;
  lessonId: string | null;
  skillId: string | null;
  startedAt: string;
  endedAt: string;
  completed: boolean;
  /** Tiempo de práctica activo, sin pausas, sin pausas promocionales. */
  practiceMs: number;
  adMs: number;
  inputMode: InputMode;
  contentVersion: string;
  summary?: {
    correct: number;
    total: number;
    errors: number;
    accuracy: number;
    valid?: boolean;
    cancelled?: boolean;
    avgMs?: number;
  };
}

export interface AnalyticsEvent {
  id: string;
  name: string;
  at: string;
  props: Record<string, unknown>;
}

export interface SyncPushRequest {
  deviceId: string;
  appVersion: string;
  attempts: Attempt[];
  sessions: SessionRecord[];
  events: AnalyticsEvent[];
}

export interface SyncPushResponse {
  accepted: { attempts: number; sessions: number; events: number };
  duplicates: { attempts: number; sessions: number; events: number };
  serverTime: string;
}

export interface SyncPullResponse {
  attempts: Attempt[];
  sessions: SessionRecord[];
  cursor: string;
  hasMore: boolean;
}

// ---------------------------------------------------------------------------
// Cuenta, suscripción y organizaciones
// ---------------------------------------------------------------------------

export type DeclaredLevel = 'cero' | 'afianzar' | 'agilidad';

export interface Goal {
  kind: 'daily' | 'weekly';
  minutes?: 5 | 10 | 15;
  days?: number;
}

export interface UserProfile {
  id: string;
  email: string | null;
  alias: string;
  sectorId: string | null;
  itineraryId: string | null;
  declaredLevel: DeclaredLevel | null;
  goal: Goal | null;
  disclaimerAcceptedAt: string | null;
  leaguesOptIn: boolean;
  createdAt: string;
}

export type EntitlementSource = 'store' | 'organization' | 'support_grant' | 'none';

export interface Entitlements {
  premium: boolean;
  noAds: boolean;
  source: EntitlementSource;
  plan: 'monthly' | 'annual' | 'trial' | 'organization' | 'grant' | null;
  status: 'active' | 'cancelled' | 'expired' | 'none';
  expiresAt: string | null;
  renewsAt: string | null;
  trialUsed: boolean;
  trialEndsAt: string | null;
  validatedAt: string;
  organization?: { id: string; name: string; nominal: boolean } | null;
}

export interface StoreProduct {
  id: 'vtm_premium_monthly' | 'vtm_premium_annual';
  plan: 'monthly' | 'annual';
  price: DecimalString;
  currency: 'EUR';
  period: 'P1M' | 'P1Y';
  trialDays: number;
}

export type InquiryType = 'exercise_error' | 'explanation_doubt' | 'technical' | 'content_suggestion' | 'other';

export interface InquiryInput {
  id: string;
  type: InquiryType;
  message: string;
  replyEmail: string | null;
  exercise?: { variantId: string; templateId: string | null; questionId: string | null; answerValue: string | null; answerUnit: string | null } | null;
  createdAt: string;
}

export const DISCLAIMER_TEXT = 'VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.';
export const NO_PATIENT_QUERIES_TEXT = 'No respondemos consultas sobre pacientes ni tratamientos';
