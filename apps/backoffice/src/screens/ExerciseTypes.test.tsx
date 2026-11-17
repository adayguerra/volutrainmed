import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import type { ExerciseType } from '@vtm/contracts';
import { mockApi, renderApp } from '../test/helpers';

const T1: ExerciseType = { id: 'T1', version: 1, name: 'Respuesta numérica con unidad', description: '', steps: [{ presentation: ['statement', 'highlighted_data'], response: 'numeric_unit', grading: 'numeric_tolerance' }], behaviour: ['hints'], voiceCompatible: true, minAppVersion: '1.0.0' };
const row = (t: ExerciseType, publishedUsage = 0, state = 'published') => ({ id: t.id, version: t.version, state, data: t, usage: publishedUsage, publishedUsage });

describe('B12 · creador de tipos de ejercicio', () => {
  it('Tipo de dos pasos: queda disponible para crear preguntas y plantillas', async () => {
    const user = userEvent.setup();
    let created: ExerciseType | null = null;
    const api = mockApi({
      'GET /v1/admin/exercise-types': () => ({ items: created ? [row(T1), row({ ...created, id: 'T4' }, 0, 'draft')] : [row(T1)] }),
      'GET /v1/admin/releases/compat': { total: 50, compatible: 48, pct: 96 },
      'POST /v1/admin/exercise-types': ({ body }) => { created = body; return { item: { id: 'T4', version: 1 }, compatibility: { pct: 96 } }; },
      'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] },
      'GET /v1/admin/items': { items: [] },
    });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo tipo' }));
    await user.type(screen.getByLabelText('Identificador'), 'T4');
    await user.type(screen.getByLabelText('Nombre del tipo'), 'Estimar y después calcular');
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 1'), 'single_choice');
    await user.click(screen.getByRole('button', { name: 'Añadir paso' }));
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 2'), 'numeric_unit');
    await user.click(screen.getByRole('button', { name: 'Crear tipo' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/exercise-types')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/exercise-types')!.body.steps).toEqual([
      { presentation: ['statement'], response: 'single_choice', grading: 'exact_match' },
      { presentation: ['highlighted_data'], response: 'numeric_unit', grading: 'numeric_tolerance' },
    ]);
    expect(await screen.findByText('Tipo creado: ya está disponible para crear preguntas y plantillas')).toBeInTheDocument();
    // Aparece en el editor de preguntas como tipo elegible.
    renderApp('/preguntas/nueva', 'content_admin');
    const select = (await screen.findAllByLabelText('Tipo de ejercicio')).at(-1)!;
    await waitFor(() => expect(within(select).getByRole('option', { name: 'T4 · Estimar y después calcular' })).toBeInTheDocument());
  });

  it('Paso sin bloque de respuesta: no permite guardar el tipo e indica el paso incompleto', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/exercise-types': { items: [] }, 'GET /v1/admin/releases/compat': { total: 0, compatible: 0, pct: 100 } });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo tipo' }));
    await user.type(screen.getByLabelText('Nombre del tipo'), 'Incompleto');
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 1'), 'numeric_unit');
    await user.click(screen.getByRole('button', { name: 'Añadir paso' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Paso 2: falta el bloque de respuesta');
    const save = screen.getByRole('button', { name: 'Crear tipo' });
    expect(save).toBeDisabled();
    await user.click(save);
    expect(api.calls.some((c) => c.method === 'POST')).toBe(false);
  });

  it('Bloques sin arrastrar: añadir y ordenar con los botones da el mismo resultado que arrastrar', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'GET /v1/admin/exercise-types': { items: [] }, 'GET /v1/admin/releases/compat': { total: 0, compatible: 0, pct: 100 },
      'POST /v1/admin/exercise-types': { item: { id: 'T5', version: 1 } },
    });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo tipo' }));
    await user.type(screen.getByLabelText('Nombre del tipo'), 'Detectar el error');
    // Paso 1: se añaden bloques desde la paleta y se reordenan con botones.
    await user.click(screen.getByRole('button', { name: 'Cálculo resuelto' }));
    await user.click(screen.getByRole('button', { name: 'Mover antes Cálculo resuelto en el paso 1' }));
    await user.click(screen.getByRole('button', { name: 'Señalar un paso' }));
    // Paso 2 y cambio de orden de los pasos con «subir».
    await user.click(screen.getByRole('button', { name: 'Añadir paso' }));
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 2'), 'yes_no');
    await user.click(screen.getByRole('button', { name: 'Subir el paso 2' }));
    expect(within(screen.getByRole('list', { name: 'Presentación del paso 2' })).getAllByRole('listitem').map((li) => li.getAttribute('data-block'))).toEqual(['Cálculo resuelto', 'Enunciado']);
    await user.click(screen.getByRole('button', { name: 'Crear tipo' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/exercise-types')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/exercise-types')!.body.steps).toEqual([
      { presentation: ['highlighted_data'], response: 'yes_no', grading: 'exact_match' },
      { presentation: ['worked_calculation', 'statement'], response: 'step_pick', grading: 'exact_match' },
    ]);
  });

  it('Tipo con un bloque de ordenar: figura como no compatible con voz y sus ejercicios no entran en sesiones manos libres', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/exercise-types': { items: [] }, 'GET /v1/admin/releases/compat': { total: 0, compatible: 0, pct: 100 }, 'POST /v1/admin/exercise-types': { item: { id: 'T9', version: 1 } } });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo tipo' }));
    await user.type(screen.getByLabelText('Nombre del tipo'), 'Ordenar y calcular');
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 1'), 'numeric_unit');
    expect(screen.getByText(/Compatible con voz: todos los bloques de respuesta lo son/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Añadir paso' }));
    await user.selectOptions(screen.getByLabelText('Respuesta del paso 2'), 'ordering');
    expect(screen.getByText(/No compatible con voz: Ordenar\. Sus ejercicios no entran en las sesiones manos libres/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Crear tipo' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/exercise-types')!.body.voiceCompatible).toBe(false));
  });

  it('Cambio en un tipo en uso: se crea una versión nueva del tipo y las 40 preguntas siguen usando la anterior', async () => {
    const user = userEvent.setup();
    const T2: ExerciseType = { id: 'T2', version: 1, name: 'Selección única', description: '', steps: [{ presentation: ['statement'], response: 'single_choice', grading: 'exact_match' }], behaviour: ['hints'], voiceCompatible: true, minAppVersion: '1.0.0' };
    const api = mockApi({
      'GET /v1/admin/exercise-types': { items: [row(T2, 40)] }, 'GET /v1/admin/releases/compat': { total: 10, compatible: 10, pct: 100 },
      'PUT /v1/admin/exercise-types/T2': { item: { id: 'T2', version: 2 } },
    });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'T2' }));
    expect(screen.getByText(/40 preguntas o plantillas publicadas\. Al guardar se crea la versión 2 y el contenido publicado sigue usando la versión 1/)).toBeInTheDocument();
    await user.clear(screen.getByLabelText('Nombre del tipo'));
    await user.type(screen.getByLabelText('Nombre del tipo'), 'Selección única con pista');
    await user.click(screen.getByRole('button', { name: 'Guardar tipo' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/exercise-types/T2')).toBeTruthy());
    expect(await screen.findByText('Creada la versión 2 del tipo; el contenido publicado sigue con la versión 1')).toBeInTheDocument();
  });

  it('muestra el porcentaje de dispositivos que admite la versión mínima del tipo', async () => {
    const user = userEvent.setup();
    mockApi({ 'GET /v1/admin/exercise-types': { items: [] }, 'GET /v1/admin/releases/compat': ({ query }) => (query.get('minAppVersion') === '1.3.0' ? { total: 100, compatible: 78, pct: 78 } : { total: 100, compatible: 100, pct: 100 }) });
    renderApp('/tipos', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo tipo' }));
    await user.clear(screen.getByLabelText('Versión mínima de la app'));
    await user.type(screen.getByLabelText('Versión mínima de la app'), '1.3.0');
    await waitFor(() => expect(screen.getByTestId('compat')).toHaveTextContent('La admite el 78 % de los dispositivos activos (78 de 100)'));
  });
});
