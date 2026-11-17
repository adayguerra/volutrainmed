/**
 * Mapa único de permisos por rol (backoffice-administration · Roles y permisos).
 * Se deriva de las listas `requireBo([...])` de services/api/src/routes/admin-*.ts:
 * la base de datos y la API aplican los permisos y la interfaz solo muestra lo
 * que cada rol puede usar. Lo usan la barra lateral y la guarda de rutas.
 */
import type { Role } from '../api/types';

export type Section =
  | 'panel' | 'estructura' | 'biblioteca' | 'revision' | 'importacion' | 'tipos' | 'publicacion'
  | 'usuarios' | 'cuentas' | 'organizaciones' | 'consultas' | 'logros' | 'ligas'
  | 'analitica' | 'catalogos' | 'auditoria';

export const SECTION_ROLES: Record<Section, Role[]> = {
  panel: ['superadmin', 'content_admin', 'author', 'reviewer', 'org_admin', 'analyst', 'support'],
  estructura: ['superadmin', 'content_admin', 'author', 'reviewer'],
  biblioteca: ['superadmin', 'content_admin', 'author', 'reviewer', 'analyst'],
  revision: ['superadmin', 'content_admin', 'author', 'reviewer'],
  importacion: ['superadmin', 'content_admin', 'author'],
  tipos: ['superadmin', 'content_admin', 'author', 'reviewer', 'analyst'],
  publicacion: ['superadmin', 'content_admin'],
  usuarios: ['superadmin', 'support', 'org_admin'],
  cuentas: ['superadmin'],
  organizaciones: ['superadmin', 'support', 'org_admin'],
  consultas: ['superadmin', 'content_admin', 'support', 'author', 'reviewer'],
  logros: ['superadmin', 'content_admin'],
  ligas: ['superadmin', 'content_admin', 'analyst'],
  analitica: ['superadmin', 'content_admin', 'analyst', 'author', 'reviewer'],
  catalogos: ['superadmin', 'content_admin'],
  auditoria: ['superadmin', 'content_admin'],
};

export function canAccess(role: Role | undefined | null, section: Section): boolean {
  return Boolean(role && SECTION_ROLES[section].includes(role));
}

/** Acciones concretas que la interfaz muestra u oculta (la API las vuelve a comprobar). */
export const ACTION_ROLES = {
  createContent: ['superadmin', 'content_admin', 'author'],
  editStructure: ['superadmin', 'content_admin'],
  retire: ['superadmin', 'content_admin'],
  decideReview: ['reviewer'],
  comment: ['superadmin', 'content_admin', 'author', 'reviewer'],
  editTypes: ['superadmin', 'content_admin'],
  supportActions: ['superadmin', 'support'],
  createOrg: ['superadmin'],
  editOrg: ['superadmin'],
  manageGroups: ['superadmin', 'org_admin'],
  convertInquiry: ['superadmin', 'content_admin'],
  promoteError: ['superadmin', 'content_admin'],
  leagueConfig: ['superadmin', 'content_admin'],
} satisfies Record<string, Role[]>;

export type Action = keyof typeof ACTION_ROLES;

export function can(role: Role | undefined | null, action: Action): boolean {
  return Boolean(role && (ACTION_ROLES[action] as Role[]).includes(role));
}

export interface NavEntry { section: Section; to: string; label: string; icon: string; group: string | null; badge?: 'reviews' | 'inquiries' }

export const NAV: NavEntry[] = [
  { section: 'panel', to: '/', label: 'Panel de control', icon: 'home', group: null },
  { section: 'estructura', to: '/estructura', label: 'Estructura', icon: 'account_tree', group: 'Contenido' },
  { section: 'biblioteca', to: '/biblioteca', label: 'Biblioteca', icon: 'stacks', group: 'Contenido' },
  { section: 'revision', to: '/revision', label: 'Revisión', icon: 'visibility', group: 'Contenido', badge: 'reviews' },
  { section: 'importacion', to: '/importar', label: 'Importación', icon: 'upload', group: 'Contenido' },
  { section: 'tipos', to: '/tipos', label: 'Tipos de ejercicio', icon: 'grid_view', group: 'Contenido' },
  { section: 'publicacion', to: '/publicacion', label: 'Publicación', icon: 'deployed_code', group: 'Contenido' },
  { section: 'usuarios', to: '/usuarios', label: 'Usuarios', icon: 'group', group: 'Personas' },
  { section: 'cuentas', to: '/cuentas', label: 'Cuentas y roles', icon: 'badge', group: 'Personas' },
  { section: 'organizaciones', to: '/organizaciones', label: 'Organizaciones', icon: 'apartment', group: 'Personas' },
  { section: 'consultas', to: '/consultas', label: 'Consultas', icon: 'chat_bubble', group: 'Personas', badge: 'inquiries' },
  { section: 'logros', to: '/logros', label: 'Logros', icon: 'trophy', group: 'Personas' },
  { section: 'ligas', to: '/ligas', label: 'Ligas', icon: 'leaderboard', group: 'Personas' },
  { section: 'analitica', to: '/analitica', label: 'Analítica de contenido', icon: 'bar_chart', group: 'Análisis' },
  { section: 'catalogos', to: '/catalogos', label: 'Catálogos y anuncios', icon: 'tune', group: 'Sistema' },
  { section: 'auditoria', to: '/auditoria', label: 'Auditoría', icon: 'history', group: 'Sistema' },
];

export function navFor(role: Role | undefined | null): NavEntry[] {
  return NAV.filter((n) => canAccess(role, n.section));
}
