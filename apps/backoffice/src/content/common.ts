/** Catálogos y ayudas compartidas por los editores de contenido. */
import { ERROR_LABELS, type ErrorCode, type SkillCode } from '@vtm/contracts';
import type { Api } from '../api/client';
import type { Item, TreeNode } from '../api/types';

export const SKILLS: { id: SkillCode; name: string }[] = [
  { id: 'H1', name: 'Conversión de unidades' }, { id: 'H2', name: 'Concentraciones' }, { id: 'H3', name: 'Dosis por peso' },
  { id: 'H4', name: 'Volumen a cargar' }, { id: 'H5', name: 'Dosis diaria en tomas' }, { id: 'H6', name: 'Reconstitución y dilución' },
  { id: 'H7', name: 'Ritmo en ml/h' }, { id: 'H8', name: 'Goteo en gotas/min' }, { id: 'H9', name: 'Perfusión por peso' },
  { id: 'H10', name: 'Dosis máxima' }, { id: 'H11', name: 'Redondeo al instrumento' }, { id: 'H12', name: 'Estimación y plausibilidad' },
];

export const ERROR_CODES = Object.keys(ERROR_LABELS) as ErrorCode[];
export const errorLabel = (c: string | null | undefined) => (c ? `${c} · ${ERROR_LABELS[c as ErrorCode] ?? c}` : '—');

export const DEFAULT_SECTORS = [
  { id: 'comun', name: 'Común (fundamentos)' }, { id: 'enfermeria', name: 'Enfermería' }, { id: 'medicina', name: 'Medicina' },
  { id: 'anestesia', name: 'Anestesia y reanimación' }, { id: 'emergencias', name: 'Emergencias' }, { id: 'farmacia', name: 'Farmacia' },
  { id: 'pediatria', name: 'Pediatría' }, { id: 'veterinaria', name: 'Veterinaria' },
];

export const BUILTIN_TYPES = [
  { id: 'T1', name: 'Respuesta numérica con unidad' }, { id: 'T2', name: 'Selección única' }, { id: 'T3', name: 'Ordenar pasos' },
  { id: 'T6', name: 'Estimación rápida' }, { id: 'T7', name: 'Conversión relámpago' },
];

export function sectorName(id: string | null | undefined, sectors = DEFAULT_SECTORS): string {
  if (!id) return '—';
  return sectors.find((s) => s.id === id)?.name ?? id;
}

/** Sectores del árbol de estructura (con «común» siempre disponible). */
export async function loadSectors(api: Api): Promise<{ id: string; name: string }[]> {
  try {
    const t = await api.get<{ tree: TreeNode[] }>('/v1/admin/structure');
    const list = t.tree.map((s) => ({ id: s.id, name: s.title }));
    return list.some((s) => s.id === 'comun') ? list : [{ id: 'comun', name: 'Común (fundamentos)' }, ...list];
  } catch {
    return DEFAULT_SECTORS;
  }
}

/** Habilidades del catálogo (no retiradas); si no hay catálogo, la lista de serie. */
export async function loadSkills(api: Api): Promise<{ id: string; name: string }[]> {
  try {
    const r = await api.get<{ items: Item<{ code?: string; name?: string }>[] }>('/v1/admin/items', { kind: 'catalog_skill' });
    const list = r.items.filter((i) => i.kind === 'catalog_skill' && i.data.code && i.data.name).map((i) => ({ id: String(i.data.code), name: String(i.data.name) }))
      .sort((a, b) => Number(a.id.slice(1)) - Number(b.id.slice(1)));
    return list.length ? list : SKILLS;
  } catch {
    return SKILLS;
  }
}

/** Especies del catálogo (no retiradas). */
export async function loadSpecies(api: Api): Promise<string[]> {
  try {
    const r = await api.get<{ items: Item<{ name?: string }>[] }>('/v1/admin/items', { kind: 'catalog_species' });
    return r.items.filter((i) => i.kind === 'catalog_species' && i.data.name).map((i) => String(i.data.name)).sort((a, b) => a.localeCompare(b, 'es'));
  } catch {
    return [];
  }
}

export async function loadTypes(api: Api): Promise<{ id: string; name: string; voiceCompatible?: boolean }[]> {
  try {
    const r = await api.get<{ items: { id: string; data: { name: string; voiceCompatible?: boolean } }[] }>('/v1/admin/exercise-types');
    return r.items.length ? r.items.map((t) => ({ id: t.id, name: t.data.name, voiceCompatible: t.data.voiceCompatible })) : BUILTIN_TYPES;
  } catch {
    return BUILTIN_TYPES;
  }
}

export function isExpired(i: Pick<Item, 'validatedUntil' | 'state'>): boolean {
  return Boolean(i.validatedUntil && new Date(i.validatedUntil).getTime() < Date.now());
}

export function download(filename: string, content: string, type = 'text/csv;charset=utf-8') {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
