import { fireEvent, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';

function unit(id: string, title: string, order: number) {
  return { id, version: 1, kind: 'unit', state: 'published', sectorId: 'anestesia', parentId: 'it-a', order, title, data: { name: title }, authorId: null, fingerprint: 'x', validations: 1, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null, children: [] };
}

function serve() {
  let order = ['u-1', 'u-2', 'u-3'];
  const titles: Record<string, string> = { 'u-1': 'Diluciones', 'u-2': 'Dosis por peso', 'u-3': 'Perfusiones' };
  const api = mockApi({
    'GET /v1/admin/structure': () => ({
      tree: [{ ...unit('anestesia', 'Anestesia', 1), kind: 'sector', parentId: null, children: [{ ...unit('it-a', 'Itinerario de anestesia', 1), kind: 'itinerary', parentId: 'anestesia', children: order.map((id, i) => unit(id, titles[id]!, i + 1)) }, { ...unit('it-b', 'Otro itinerario', 2), kind: 'itinerary', parentId: 'anestesia' }] }],
      itinerariesWithoutSector: [],
    }),
    'GET /v1/admin/items': { items: [] },
    'POST /v1/admin/structure/unit/:id/move': ({ path, body }) => {
      const id = path.split('/')[5]!;
      const i = order.indexOf(id); const j = body.direction === 'up' ? i - 1 : i + 1;
      if (j >= 0 && j < order.length) { const next = [...order]; [next[i], next[j]] = [next[j]!, next[i]!]; order = next; }
      return { ok: true };
    },
  });
  return { api, order: () => order };
}

describe('B04 · reordenación por arrastre y con el teclado', () => {
  it('arrastrar una unidad sobre otra del mismo itinerario la lleva a esa posición', async () => {
    const { api, order } = serve();
    renderApp('/estructura', 'content_admin');
    const source = await screen.findByTestId('nodo-u-3');
    expect(source).toHaveAttribute('draggable', 'true');
    fireEvent.dragStart(source);
    fireEvent.dragOver(screen.getByTestId('nodo-u-1'));
    expect(screen.getByTestId('nodo-u-1')).toHaveClass('drop');
    fireEvent.drop(screen.getByTestId('nodo-u-1'));
    await waitFor(() => expect(api.calls.filter((c) => c.path === '/v1/admin/structure/unit/u-3/move').map((c) => c.body.direction)).toEqual(['up', 'up']));
    expect(order()).toEqual(['u-3', 'u-1', 'u-2']);
    expect(await screen.findByRole('button', { name: 'Unidad 1 · Perfusiones' })).toBeInTheDocument();
    expect(await screen.findByText('Perfusiones sube 2 posiciones')).toBeInTheDocument();
  });

  it('no admite soltar sobre un nodo de otro nivel o de otro padre', async () => {
    const { api } = serve();
    renderApp('/estructura', 'content_admin');
    fireEvent.dragStart(await screen.findByTestId('nodo-u-1'));
    const other = screen.getByTestId('nodo-it-b');
    fireEvent.dragOver(other);
    expect(other).not.toHaveClass('drop');
    fireEvent.drop(other);
    expect(api.calls.some((c) => c.method === 'POST')).toBe(false);
  });

  it('con el teclado, Alt + flecha mueve el nodo enfocado', async () => {
    const user = userEvent.setup();
    const { api, order } = serve();
    renderApp('/estructura', 'content_admin');
    const name = await screen.findByRole('button', { name: 'Unidad 1 · Diluciones' });
    expect(name).toHaveAttribute('aria-keyshortcuts', 'Alt+ArrowUp Alt+ArrowDown');
    name.focus();
    await user.keyboard('{Alt>}{ArrowDown}{/Alt}');
    await waitFor(() => expect(api.last('POST', '/v1/admin/structure/unit/u-1/move')!.body).toEqual({ direction: 'down' }));
    expect(order()).toEqual(['u-2', 'u-1', 'u-3']);
    // En el primer puesto, subir no hace nada.
    const first = await screen.findByRole('button', { name: 'Unidad 1 · Dosis por peso' });
    first.focus();
    await user.keyboard('{Alt>}{ArrowUp}{/Alt}');
    expect(api.calls.filter((c) => c.method === 'POST')).toHaveLength(1);
  });

  it('quien no gestiona la estructura no puede arrastrar', async () => {
    serve();
    renderApp('/estructura', 'reviewer');
    expect(await screen.findByTestId('nodo-u-1')).toHaveAttribute('draggable', 'false');
  });
});
