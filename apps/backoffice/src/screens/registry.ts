/** Registro de pantallas por ruta y sección (la guarda de permisos usa la sección). */
import type { ComponentType } from 'react';
import type { Section } from '../auth/permissions';
import { Structure } from './Structure';
import { Library } from './Library';
import { TemplateEditor } from './template/TemplateEditor';
import { QuestionEditor } from './QuestionEditor';
import { Preview } from './Preview';
import { ExerciseTypes } from './ExerciseTypes';
import { Import } from './Import';
import { ReviewInbox, ReviewSheet } from './Review';
import { Publishing } from './Publishing';
import { Accounts, UserDetail, Users } from './People';
import { Organizations } from './Organizations';
import { Analytics, AnalyticsItem } from './Analytics';
import { Inquiries } from './Inquiries';
import { Audit } from './Audit';

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
];
