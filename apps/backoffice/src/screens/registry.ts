/** Registro de pantallas por ruta y sección (la guarda de permisos usa la sección). */
import type { ComponentType } from 'react';
import type { Section } from '../auth/permissions';

export interface ScreenDef { path: string; section: Section; component: ComponentType }

export const screens: ScreenDef[] = [];
