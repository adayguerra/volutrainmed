/** Formas de las respuestas de /v1/admin (ver services/api/src/routes/admin-*.ts). */

export type Role = 'superadmin' | 'content_admin' | 'author' | 'reviewer' | 'org_admin' | 'analyst' | 'support';

export const ROLE_LABELS: Record<Role, string> = {
  superadmin: 'Superadministración', content_admin: 'Administración de contenido', author: 'Autoría', reviewer: 'Revisión experta',
  org_admin: 'Administración de organización', analyst: 'Análisis', support: 'Soporte',
};

export interface Account {
  id: string; email: string; name: string; role: Role; roleLabel: string; sectors: string[]; accreditation: string | null;
  orgId: string | null; active: boolean; mfaEnabled: boolean;
}

export interface LoginResponse { challenge: string; mfaSetupRequired: boolean; otpauthUrl?: string; secret?: string }
export interface MfaResponse { token: string; account: Account; recoveryCodes?: string[] }

export type ItemState = 'draft' | 'in_review' | 'changes_requested' | 'validated' | 'published' | 'retired';

export const STATE_LABELS: Record<string, string> = {
  draft: 'Borrador', in_review: 'En revisión', changes_requested: 'Cambios solicitados', validated: 'Validado', published: 'Publicado', retired: 'Retirado',
};

export type Kind =
  | 'sector' | 'itinerary' | 'unit' | 'lesson' | 'template' | 'question' | 'exercise_type'
  | 'catalog_unit' | 'catalog_instrument' | 'voice_lexicon' | 'ad_creative' | 'ad_campaign' | 'achievement' | 'catalog_skill' | 'catalog_species';

export const KIND_LABELS: Record<Kind, string> = {
  sector: 'Sector', itinerary: 'Itinerario', unit: 'Unidad', lesson: 'Lección', template: 'Plantilla', question: 'Pregunta', exercise_type: 'Tipo de ejercicio',
  catalog_unit: 'Catálogo · unidad', catalog_instrument: 'Catálogo · instrumento', voice_lexicon: 'Catálogo · voz', ad_creative: 'Anuncio propio', ad_campaign: 'Campaña', achievement: 'Logro', catalog_skill: 'Catálogo · habilidad', catalog_species: 'Catálogo · especie',
};

export interface Item<D = Record<string, unknown>> {
  id: string; version: number; kind: Kind; state: ItemState; sectorId: string | null; parentId: string | null; order: number; title: string;
  data: D; authorId: string | null; fingerprint: string; validations: number; validatedUntil: string | null; updatedAt: string; createdAt: string;
  linkedInquiry: string | null; authorName?: string | null; canEdit?: boolean;
}

export interface Review {
  id: string; item_id: string; item_version: number; reviewer_id: string; reviewer_name: string; decision: 'validate' | 'request_changes' | 'reject';
  checklist: Record<string, boolean>; comment: string | null; accreditation: string | null; fingerprint: string; expires_at: string | null; created_at: string;
}

export interface ReviewComment { id: string; item_id: string; item_version: number; author_id: string; author_name: string; anchor: string | null; body: string; created_at: string }

export interface ItemDetail<D = Record<string, unknown>> {
  item: Item<D>; versions: Item<D>[]; reviews: Review[]; comments: ReviewComment[]; canEdit: boolean; canValidate: boolean;
}

export interface TreeNode extends Item {
  children: TreeNode[];
  coverage?: { lessons: number; templates: number; validatedTemplates: number };
}

export interface Release {
  id: string; number: string; state: 'preparing' | 'testing' | 'published' | 'superseded' | 'rolled_back'; notes: string | null; rolloutPct: number | null;
  minAppVersion: string; items: { id: string; version: number; kind: string; title: string }[]; diff: ReleaseDiff | null; checks: Check[] | null;
  testCode: string | null; createdAt: string; publishedAt: string | null; rolledBackReason: string | null;
}

export interface DiffEntry { id: string; version: number; kind?: string; title?: string; reason?: string }
export interface ReleaseDiff { added: DiffEntry[]; changed: DiffEntry[]; retired: DiffEntry[]; excluded: DiffEntry[] }
export interface Check { id: string; label: string; ok: boolean; detail: string; itemId?: string; items?: string[] }

export interface ApiErrorBody { error: { code: string; message: string } }
