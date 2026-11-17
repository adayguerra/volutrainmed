import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';

const q = (state: string, version = 2) => ({
  id: 'q-adr', version, kind: 'question', state, sectorId: 'emergencias', parentId: null, order: 1, title: 'Adrenalina 1:10 000 · concentración',
  data: { exerciseTypeId: 'T2', skillId: 'H2' }, authorId: 'a', fingerprint: 'f', validations: 1, validatedUntil: null, updatedAt: new Date().toISOString(), createdAt: '', linkedInquiry: null, authorName: 'A. Gil',
});

describe('B05 · biblioteca', () => {
  it('Retirar una pregunta: deja de publicarse y permanece consultable en el archivo con su historial', async () => {
    const user = userEvent.setup();
    let retired = false;
    const api = mockApi({
      'GET /v1/admin/items': ({ query }) => {
        if (query.get('state') === 'retired') return { items: retired ? [q('retired')] : [] };
        return { items: retired ? [] : [q('published')] };
      },
      'POST /v1/admin/items/q-adr/retire': () => { retired = true; return { item: q('retired') }; },
      'GET /v1/admin/items/q-adr': () => ({ item: q('retired'), versions: [q('retired', 2), q('published', 1)], reviews: [{ id: 'r1', item_version: 1, decision: 'validate', reviewer_name: 'Dra. León', comment: null, created_at: '2026-10-01T10:00:00Z' }], comments: [], canEdit: true, canValidate: false }),
    });
    renderApp('/biblioteca', 'content_admin');
    const row = await screen.findByRole('row', { name: /Adrenalina 1:10 000/ });
    expect(row).toHaveTextContent('Publicado');
    await user.click(within(row).getByRole('button', { name: 'Retirar' }));
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByRole('button', { name: 'Retirar' })).toBeDisabled();
    await user.type(within(dialog).getByLabelText('Motivo (obligatorio)'), 'Concentración mal expresada');
    await user.click(within(dialog).getByRole('button', { name: 'Retirar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items/q-adr/retire')!.body).toEqual({ reason: 'Concentración mal expresada' }));
    // Deja de aparecer en la biblioteca activa…
    await waitFor(() => expect(screen.queryByRole('row', { name: /Adrenalina 1:10 000/ })).not.toBeInTheDocument());
    // …y sigue en el archivo, con su historial de versiones y revisiones.
    await user.click(screen.getByRole('button', { name: 'Ver archivo' }));
    const archived = await screen.findByRole('row', { name: /Adrenalina 1:10 000/ });
    expect(archived).toHaveTextContent('Retirado');
    await user.click(within(archived).getByRole('button', { name: 'Historial' }));
    const versions = await screen.findByRole('list', { name: 'Versiones' });
    expect(within(versions).getAllByRole('listitem').map((li) => li.textContent)).toEqual([expect.stringContaining('v2Retirado'), expect.stringContaining('v1Publicado')]);
    expect(screen.getByRole('list', { name: 'Revisiones' })).toHaveTextContent('Validado por Dra. León');
  });

  it('el autor no ve la acción de retirar y puede crear contenido', async () => {
    mockApi({ 'GET /v1/admin/items': { items: [q('draft')] } });
    renderApp('/biblioteca', 'author');
    const row = await screen.findByRole('row', { name: /Adrenalina/ });
    expect(within(row).queryByRole('button', { name: 'Retirar' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Nueva plantilla/ })).toHaveAttribute('href', '/plantillas/nueva');
  });
});
