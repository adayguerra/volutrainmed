/** Ensambla la entrada del constructor de paquetes a partir de la semilla. */
import type { BuildInput, UnitInput } from '../publish/build.js';
import {
  ACHIEVEMENTS, AD_PARAMS, EXERCISE_TYPES, INSTRUMENTS, ITINERARIES, LAUNCH_CAMPAIGN, LEAGUE_CONFIG, MEASURE_UNITS,
  QUESTIONS, SECTORS, SKILLS, STRUCTURE, TEMPLATES, VOICE_LEXICON,
} from './content.js';

export function seedUnits(): UnitInput[] {
  const out: UnitInput[] = [];
  for (const [itineraryId, units] of Object.entries(STRUCTURE)) {
    units.forEach((u, i) => {
      out.push({
        ...u.unit, itineraryId, order: i + 1, prerequisiteUnitId: i === 0 ? null : units[i - 1]!.unit.id,
        templateIds: u.templates, questionIds: u.questions ?? [],
      });
    });
  }
  return out;
}

export function seedBuildInput(contentVersion = '2026.11.1', variantsPerLevel?: number): BuildInput {
  return {
    contentVersion, minAppVersion: '1.0.0', sectors: SECTORS, itineraries: ITINERARIES, skills: SKILLS, exerciseTypes: EXERCISE_TYPES,
    units: seedUnits(), lessons: [], templates: TEMPLATES, questions: QUESTIONS, measureUnits: MEASURE_UNITS, instruments: INSTRUMENTS,
    voiceLexicon: VOICE_LEXICON, achievements: ACHIEVEMENTS, league: LEAGUE_CONFIG, adParams: AD_PARAMS, campaigns: [LAUNCH_CAMPAIGN],
    freePlan: { handsfreeDailyMinutes: 5, freeUnitsPerItinerary: 99 }, orgsEnabled: false, variantsPerLevel,
  };
}
