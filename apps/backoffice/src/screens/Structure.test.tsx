import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';

function node(kind: string, id: string, title: string, data: Record<string, unknown> = {}, children: unknown[] = [], state = 'published', order = 1) {
  return { id, version: 1, kind, state, sectorId: 'anestesia', parentId: null, order, title, data: { name: title, ...data }, authorId: null, fingerprint: 'x', validations: 1, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null, children };
}

function treeWith(units: unknown[]) {
  return { tree: [node('sector', 'anestesia', 'Anestesia y reanimación', {}, [node('itinerary', 'it-anestesia', 'Perfusiones y diluciones', {}, units)])], itinerariesWithoutSector: [] };
}

describe('B04 · estructura del contenido', () => {
  it('Nueva unidad: aparece en el árbol en estado borrador', async () => {
    const user = userEvent.setup();
    let created = false;
    const base = [node('unit', 'u-1', 'Dosis por peso', { skills: ['H3'] }, [], 'published', 1)];
    const api = mockApi({
      'GET /v1/admin/structure': () => treeWith(created ? [...base, node('unit', 'u-nueva', 'Perfusiones', { skills: ['H7', 'H9'] }, [], 'draft', 2)] : base),
      'GET /v1/admin/items': { items: [] },
      'POST /v1/admin/structure/unit': () => { created = true; return { item: node('unit', 'u-nueva', 'Perfusiones', { skills: ['H7', 'H9'] }, [], 'draft', 2) }; },
    });
    renderApp('/estructura', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Perfusiones y diluciones' }));
    await user.click(screen.getByRole('button', { name: 'Nueva unidad' }));
    const dialog = screen.getByRole('dialog', { name: /Nueva unidad en Perfusiones y diluciones/ });
    await user.type(within(dialog).getByLabelText('Nombre'), 'Perfusiones');
    await user.click(within(dialog).getByLabelText(/^H7 ·/));
    await user.click(within(dialog).getByLabelText(/^H9 ·/));
    await user.click(within(dialog).getByRole('button', { name: 'Crear' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/structure/unit')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/structure/unit')!.body).toMatchObject({ name: 'Perfusiones', itineraryId: 'it-anestesia', skills: ['H7', 'H9'] });
    const tree = await screen.findByRole('list', { name: 'Árbol de contenido' });
    const newNode = await within(tree).findByRole('button', { name: /Unidad 2 · Perfusiones/ });
    expect(newNode).toHaveTextContent('Borrador');
  });

  it('Lección sin ejercicios: el back office lo impide e indica qué falta', async () => {
    const user = userEvent.setup();
    const lesson = node('lesson', 'l-3', 'Práctica libre', { title: 'Práctica libre', kind: 'free', rule: 'slots', slots: [], unitId: 'u-1' }, [], 'draft');
    const api = mockApi({
      'GET /v1/admin/structure': treeWith([node('unit', 'u-1', 'Dosis por peso', { skills: ['H3'] }, [lesson])]),
      'GET /v1/admin/items': { items: [] },
    });
    renderApp('/estructura', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Desplegar Dosis por peso' }));
    await user.click(await screen.findByRole('button', { name: /L1 · Práctica libre/ }));
    await user.click(screen.getByRole('button', { name: 'Enviar a revisión' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('La lección no tiene ejercicios asignados: añade huecos o usa la regla automática por habilidad');
    expect(api.calls.some((c) => c.path.endsWith('/submit'))).toBe(false);
  });

  it('Reordenar sin arrastrar: la unidad cambia de posición en el itinerario con «subir» y «bajar»', async () => {
    const user = userEvent.setup();
    let swapped = false;
    const a = node('unit', 'u-1', 'Diluciones', {}, [], 'published', 1);
    const b = node('unit', 'u-2', 'Dosis por peso', {}, [], 'published', 2);
    const api = mockApi({
      'GET /v1/admin/structure': () => treeWith(swapped ? [{ ...b, order: 1 }, { ...a, order: 2 }] : [a, b]),
      'GET /v1/admin/items': { items: [] },
      'POST /v1/admin/structure/unit/u-2/move': () => { swapped = true; return { ok: true }; },
    });
    renderApp('/estructura', 'content_admin');
    expect(await screen.findByRole('button', { name: 'Unidad 2 · Dosis por peso' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Subir Diluciones' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Subir Dosis por peso' }));
    expect(api.last('POST', '/v1/admin/structure/unit/u-2/move')!.body).toEqual({ direction: 'up' });
    expect(await screen.findByRole('button', { name: 'Unidad 1 · Dosis por peso' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Unidad 2 · Diluciones' })).toBeInTheDocument();
  });

  it('el revisor consulta la estructura sin botones de edición', async () => {
    mockApi({ 'GET /v1/admin/structure': treeWith([node('unit', 'u-1', 'Diluciones')]), 'GET /v1/admin/items': { items: [] } });
    renderApp('/estructura', 'reviewer');
    expect(await screen.findByText(/Solo la administración de contenido crea, ordena y retira nodos/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Subir Diluciones' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Nuevo sector' })).not.toBeInTheDocument();
  });
});
