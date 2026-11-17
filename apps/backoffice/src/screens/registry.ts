/** Registro de pantallas por ruta y sección (la guarda de permisos usa la sección). */
import type { ComponentType } from 'react';
import type { Section } from '../auth/permissions';
import { Structure } from './Structure';
import { Library } from './Library';
import { TemplateEditor } from './template/TemplateEditor';

export interface ScreenDef { path: string; section: Section; component: ComponentType }

export const screens: ScreenDef[] = [
  { path: '/estructura', section: 'estructura', component: Structure },
  { path: '/biblioteca', section: 'biblioteca', component: Library },
  { path: '/plantillas/nueva', section: 'biblioteca', component: TemplateEditor },
  { path: '/plantillas/:id', section: 'biblioteca', component: TemplateEditor },
];
