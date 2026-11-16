/**
 * Comprobaciones automáticas de texto.
 *
 * - Comunicación sin uso clínico (formative-boundary): la revisión rechaza
 *   textos como «úsalo en tu guardia».
 * - Anuncios propios (house-ads): términos vetados, longitudes, variables
 *   válidas y duración de la cuña.
 * - Preguntas fijas: cantidades sin unidad.
 */

const CLINICAL_USE_PATTERNS: RegExp[] = [
  /\b[úu]sal[oa] en tu guardia\b/i,
  /\ben tu guardia\b/i,
  /\bcalcula la dosis de tu paciente\b/i,
  /\btu paciente\b/i,
  /\bpacientes? reales?\b(?![^.]*\bno\b)/i,
  /\bdurante la atenci[óo]n\b/i,
  /\ben (el|la) (quir[óo]fano|cabecera|cabina)\b/i,
  /\bpara administrar\b/i,
  /\bpauta prescrita\b/i,
  /\bprescribe\b/i,
];

/** Devuelve el fragmento que sugiere uso clínico, o null. El aviso formativo está permitido. */
export function findClinicalUseText(text: string): string | null {
  if (!text) return null;
  const allowed = /no lo uses para calcular dosis de pacientes reales|no lo uses con pacientes reales|no respondemos consultas sobre pacientes/i;
  const cleaned = text.replace(allowed, '');
  for (const re of CLINICAL_USE_PATTERNS) {
    const m = cleaned.match(re);
    if (m) return m[0];
  }
  return null;
}

/** Términos vetados en titular, texto y cuña de los anuncios (catálogo de anuncios). */
export const AD_BANNED_TERMS = [
  'paciente', 'guardia', 'salva', 'evita errores', 'última oportunidad', 'ultima oportunidad',
  'solo hoy', 'sólo hoy', 'no te lo pierdas', 'te echamos de menos',
];

export const AD_VARIABLES = ['espera_s', 'ejercicios', 'total_s', 'aciertos', 'dias', 'equivalente_mes', 'ahorro_pct'] as const;
export type AdVariable = (typeof AD_VARIABLES)[number];

/** Valor más largo de cada variable, para comprobar longitudes con las variables resueltas. */
export const AD_VARIABLE_LONGEST: Record<AdVariable, string> = {
  espera_s: '5', ejercicios: '12', total_s: '60', aciertos: '12', dias: '365', equivalente_mes: '99,99', ahorro_pct: '99',
};

export interface AdCheckIssue { field: 'headline' | 'body' | 'voiceSpot' | 'cta'; message: string }

export function wordCount(s: string): number {
  return s.trim().split(/\s+/).filter(Boolean).length;
}

/** Duración estimada de una cuña con la voz por defecto a velocidad 1,0 (3 palabras por segundo). */
export function estimateSpotSeconds(spot: string): number {
  const resolved = resolveAdText(spot, AD_VARIABLE_LONGEST);
  return Math.round((wordCount(resolved) / 3) * 10) / 10;
}

export function resolveAdText(text: string, vars: Partial<Record<AdVariable, string>>): string {
  return text.replace(/\{([a-z_]+)\}/g, (m, k: string) => (k in vars ? String(vars[k as AdVariable]) : m));
}

export function checkAdCreative(c: { headline: string; body: string; cta: string; voiceSpot: string | null }): AdCheckIssue[] {
  const issues: AdCheckIssue[] = [];
  const fields: [AdCheckIssue['field'], string][] = [['headline', c.headline], ['body', c.body], ['cta', c.cta]];
  if (c.voiceSpot) fields.push(['voiceSpot', c.voiceSpot]);
  for (const [f, text] of fields) {
    for (const m of text.matchAll(/\{([a-z_]+)\}/g)) {
      if (!AD_VARIABLES.includes(m[1] as AdVariable)) issues.push({ field: f, message: `Variable no válida: {${m[1]}}` });
    }
    const low = text.toLowerCase();
    for (const term of AD_BANNED_TERMS) if (low.includes(term)) issues.push({ field: f, message: `Término vetado: «${term}»` });
    if (/!!|¡¡/.test(text)) issues.push({ field: f, message: 'Sin signos de exclamación dobles' });
    const clin = findClinicalUseText(text);
    if (clin) issues.push({ field: f, message: `Alusión a uso clínico: «${clin}»` });
  }
  const h = resolveAdText(c.headline, AD_VARIABLE_LONGEST);
  if (h.length > 44) issues.push({ field: 'headline', message: `El titular tiene ${h.length} caracteres con las variables resueltas (máximo 44)` });
  const b = resolveAdText(c.body, AD_VARIABLE_LONGEST);
  if (b.length > 90) issues.push({ field: 'body', message: `El texto tiene ${b.length} caracteres con las variables resueltas (máximo 90)` });
  if (c.voiceSpot) {
    const s = estimateSpotSeconds(c.voiceSpot);
    if (s > 4) issues.push({ field: 'voiceSpot', message: `La cuña dura unos ${String(s).replace('.', ',')} s (máximo 4 s)` });
  }
  // Toda cifra procede de una variable: no se admiten cifras escritas a mano salvo «7 días» de la prueba.
  for (const [f, text] of fields) {
    const bare = text.replace(/\{[a-z_]+\}/g, '').match(/\d+(?:[.,]\d+)?/g) ?? [];
    for (const n of bare) if (n !== '7') issues.push({ field: f, message: `Cifra escrita a mano: ${n}. Usa una variable` });
  }
  return issues;
}

const UNIT_AFTER = /^\s?(µg|mcg|mg|ng|kg|g|ml|µl|l|UI|gotas|gota|min|h|s|días?|tomas?|%|horas?|minutos?|años?|semanas?|veces|ampollas?|viales?|comprimidos?|kilos?)\b/u;

/**
 * Cantidades sin unidad en un enunciado («Pauta: 0,2»). Se ignoran razones (1:10 000),
 * ordinales y números seguidos de palabras como «kg» o «gotas».
 */
export function findQuantitiesWithoutUnit(text: string): string[] {
  const out: string[] = [];
  const re = /(?<![\d:, ]|\d[  ])(\d{1,3}(?:[  ]\d{3})+(?:,\d+)?|\d+(?:[.,]\d+)?)(?![\d:])/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text))) {
    const after = text.slice(re.lastIndex);
    const before = text.slice(0, m.index);
    if (/:\s?$/.test(before) && /^\s?\d/.test(after)) continue;
    if (/\d:$/.test(before)) continue;
    if (/^:\d/.test(after)) continue;
    if (UNIT_AFTER.test(after)) continue;
    if (/(unidad|lección|paso|nivel|ejercicio|opción)\s$/i.test(before)) continue;
    if (/^\s?(en|de)\s\d/.test(after)) continue;
    out.push(m[1]!);
  }
  return out;
}
