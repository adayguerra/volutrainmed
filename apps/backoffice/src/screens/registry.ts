/** Registro de pantallas por ruta y sección (la guarda de permisos usa la sección). Cada pantalla se carga bajo demanda. */
import { lazy, type ComponentType } from 'react';
import type { Section } from '../auth/permissions';

const Structure = lazy(() => import('./Structure').then((m) => ({ default: m.Structure })));
const Library = lazy(() => import('./Library').then((m) => ({ default: m.Library })));
const TemplateEditor = lazy(() => import('./template/TemplateEditor').then((m) => ({ default: m.TemplateEditor })));
const QuestionEditor = lazy(() => import('./QuestionEditor').then((m) => ({ default: m.QuestionEditor })));
const Preview = lazy(() => import('./Preview').then((m) => ({ default: m.Preview })));
const ExerciseTypes = lazy(() => import('./ExerciseTypes').then((m) => ({ default: m.ExerciseTypes })));
const Import = lazy(() => import('./Import').then((m) => ({ default: m.Import })));
const ReviewInbox = lazy(() => import('./Review').then((m) => ({ default: m.ReviewInbox })));
const ReviewSheet = lazy(() => import('./Review').then((m) => ({ default: m.ReviewSheet })));
const Publishing = lazy(() => import('./Publishing').then((m) => ({ default: m.Publishing })));
const Accounts = lazy(() => import('./People').then((m) => ({ default: m.Accounts })));
const UserDetail = lazy(() => import('./People').then((m) => ({ default: m.UserDetail })));
const Users = lazy(() => import('./People').then((m) => ({ default: m.Users })));
const Organizations = lazy(() => import('./Organizations').then((m) => ({ default: m.Organizations })));
const Analytics = lazy(() => import('./Analytics').then((m) => ({ default: m.Analytics })));
const AnalyticsItem = lazy(() => import('./Analytics').then((m) => ({ default: m.AnalyticsItem })));
const Inquiries = lazy(() => import('./Inquiries').then((m) => ({ default: m.Inquiries })));
const Audit = lazy(() => import('./Audit').then((m) => ({ default: m.Audit })));
const Achievements = lazy(() => import('./Gamification').then((m) => ({ default: m.Achievements })));
const Leagues = lazy(() => import('./Gamification').then((m) => ({ default: m.Leagues })));
const Catalogs = lazy(() => import('./Catalogs').then((m) => ({ default: m.Catalogs })));

export interface ScreenDef { path: string; section: Section; component: ComponentType }

export const screens: ScreenDef[] = [
  { path: '/estructura', section: 'estructura', component: Structure },
  { path: '/biblioteca', section: 'biblioteca', component: Library },
  { path: '/plantillas/nueva', section: 'biblioteca', component: TemplateEditor },
  { path: '/plantillas/:id', section: 'biblioteca', component: TemplateEditor },
  { path: '/preguntas/nueva', section: 'biblioteca', component: QuestionEditor },
  { path: '/preguntas/:id', section: 'biblioteca', component: QuestionEditor },
  { path: '/vista-previa/:id', section: 'biblioteca', component: Preview },
  { path: '/tipos', section: 'tipos', component: ExerciseTypes },
  { path: '/importar', section: 'importacion', component: Import },
  { path: '/revision', section: 'revision', component: ReviewInbox },
  { path: '/revision/:itemId', section: 'revision', component: ReviewSheet },
  { path: '/publicacion', section: 'publicacion', component: Publishing },
  { path: '/usuarios', section: 'usuarios', component: Users },
  { path: '/usuarios/:id', section: 'usuarios', component: UserDetail },
  { path: '/cuentas', section: 'cuentas', component: Accounts },
  { path: '/organizaciones', section: 'organizaciones', component: Organizations },
  { path: '/analitica', section: 'analitica', component: Analytics },
  { path: '/analitica/:id', section: 'analitica', component: AnalyticsItem },
  { path: '/consultas', section: 'consultas', component: Inquiries },
  { path: '/auditoria', section: 'auditoria', component: Audit },
  { path: '/logros', section: 'logros', component: Achievements },
  { path: '/ligas', section: 'ligas', component: Leagues },
  { path: '/catalogos', section: 'catalogos', component: Catalogs },
];
