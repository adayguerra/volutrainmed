import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';

describe('B16 · ficha de revisión de elementos que no son ejercicios', () => {
  it('muestra el contenido de una unidad, sus cambios frente a la versión anterior y enlaza con la estructura', async () => {
    const unit = { id: 'u-f-1', version: 3, kind: 'unit', state: 'in_review', sectorId: null, parentId: 'it-fundamentos', order: 1, title: 'Conversiones', data: { id: 'u-f-1', name: 'Conversiones', skills: ['H1'], templateIds: ['tpl-f-mg-ug', 'tpl-nueva'] }, authorId: 'acc-content_admin', fingerprint: 'f3', validations: 0, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null };
    const api = mockApi({
      'GET /v1/admin/reviews/u-f-1': { item: unit, authorName: 'María Ortega', sample: [], extremes: [], comments: [], reviews: [], changesDuringReview: [], checklist: [{ key: 'pauta_plausible', label: 'Pauta plausible' }], requiredValidations: 1, canValidate: true, canComment: true, reasonCannotValidate: null },
      'GET /v1/admin/items/u-f-1/diff': { from: 2, to: 3, changes: [{ path: 'templateIds', before: ['tpl-f-mg-ug'], after: ['tpl-f-mg-ug', 'tpl-nueva'] }] },
    });
    renderApp('/revision/u-f-1', 'reviewer');
    const content = await screen.findByLabelText('Contenido del elemento');
    expect(content).toHaveTextContent('Conversiones');
    expect(content).toHaveTextContent('tpl-nueva');
    const changes = await screen.findByRole('region', { name: 'Cambios frente a la versión anterior' });
    expect(changes).toHaveTextContent('templateIds');
    expect(api.last('GET', '/v1/admin/items/u-f-1/diff')!.query.get('from')).toBe('2');
    expect(screen.queryByRole('table', { name: 'Variantes de muestra' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Abrir en el editor/ })).toHaveAttribute('href', '/estructura');
  });
});

describe('B26 · campañas de anuncios propios', () => {
  it('crea una campaña con segmento por sector y vigencia, en borrador', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'GET /v1/admin/items': ({ query }: Call) => ({ items: [] as unknown[], kind: query.get('kind') }),
      'GET /v1/admin/ads/params': { params: { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 } },
      'GET /v1/admin/ads/performance': { items: [] },
      'POST /v1/admin/items': { item: { id: 'camp-vet', version: 1, state: 'draft' } },
    });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Anuncios propios' }));
    await user.click(await screen.findByRole('button', { name: 'Nueva campaña' }));
    const dialog = screen.getByRole('dialog', { name: 'Nueva campaña' });
    await user.type(within(dialog).getByLabelText('Nombre de la campaña'), 'Veterinaria de invierno');
    await user.click(within(dialog).getByLabelText('Veterinaria'));
    await user.type(within(dialog).getByLabelText('Inicio de la vigencia'), '2026-12-01');
    await user.type(within(dialog).getByLabelText('Fin de la vigencia'), '2027-02-28');
    await user.click(within(dialog).getByRole('button', { name: 'Guardar campaña' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')!.body).toEqual({ kind: 'ad_campaign', data: { name: 'Veterinaria de invierno', sectorIds: ['veterinaria'], startsAt: '2026-12-01', endsAt: '2027-02-28' } }));
  });

  it('el anuncio elige el contexto en que se muestra', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'GET /v1/admin/items': { items: [] }, 'GET /v1/admin/ads/params': { params: { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 } }, 'GET /v1/admin/ads/performance': { items: [] },
      'POST /v1/admin/items': { item: { id: 'ad-x', version: 1, state: 'draft' } },
    });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Anuncios propios' }));
    await user.click(await screen.findByRole('button', { name: 'Nuevo anuncio' }));
    await user.type(screen.getByLabelText('Titular'), 'Entrena sin pausas');
    await user.type(screen.getByLabelText('Texto'), 'Con Premium pasas al siguiente ejercicio sin anuncios.');
    await user.selectOptions(screen.getByLabelText('Contexto en que se muestra'), 'after_unit_completed');
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Guardar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')!.body.data).toMatchObject({ kind: 'generic', context: 'after_unit_completed', headline: 'Entrena sin pausas' }));
  });
});
