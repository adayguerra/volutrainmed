import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';

const base = { version: 1, state: 'published', sectorId: null, parentId: null, order: 1, title: '', authorId: null, fingerprint: 'f', validations: 1, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null };
const SKILLS = [{ ...base, id: 'cs-h2', kind: 'catalog_skill', data: { code: 'H2', name: 'Concentraciones' } }, { ...base, id: 'cs-h1', kind: 'catalog_skill', data: { code: 'H1', name: 'Conversión de unidades' } }];
const SPECIES = [{ ...base, id: 'sp-perro', kind: 'catalog_species', data: { name: 'Perro', sectorId: 'veterinaria' } }, { ...base, id: 'sp-gato', kind: 'catalog_species', data: { name: 'Gato', sectorId: 'veterinaria' } }];
const LEX = { ...base, id: 'voice-lexicon-es', kind: 'voice_lexicon', data: {
  name: 'Léxico', confusions: [{ from: 'como', to: 'coma' }, { from: 'toma', to: 'coma' }], commands: [{ command: 'repite', synonyms: ['repite', 'otra vez'] }, { command: 'siguiente', synonyms: ['siguiente'] }],
  sectorSynonyms: [{ spoken: 'gammas', unit: 'µg', sectorId: 'anestesia', enabledByDefault: false }, { spoken: 'ce ce', unit: 'ml', sectorId: 'veterinaria', enabledByDefault: true }],
} };

function items({ query }: Call) {
  const k = query.get('kind');
  return { items: k === 'catalog_skill' ? SKILLS : k === 'catalog_species' ? SPECIES : k === 'voice_lexicon' ? [LEX] : [] };
}

describe('B26 · catálogos de habilidades y especies', () => {
  it('lista las habilidades por código y crea una nueva en borrador, con el código validado', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/items': items, 'POST /v1/admin/items': { item: { id: 'cs-h13', version: 1, state: 'draft' } } });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Habilidades' }));
    const table = await screen.findByRole('table', { name: 'Habilidades' });
    expect(within(table).getAllByRole('row').slice(1).map((r) => within(r).getAllByRole('cell')[0]!.textContent)).toEqual(['H1', 'H2']);
    await user.click(screen.getByRole('button', { name: 'Nueva habilidad' }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByLabelText('Código (H1, H2…)'), 'h2');
    await user.type(within(dialog).getByLabelText('Nombre'), 'Mezclas de dos fármacos');
    expect(within(dialog).getByRole('alert')).toHaveTextContent('Ya existe una habilidad con ese código');
    expect(within(dialog).getByRole('button', { name: 'Guardar' })).toBeDisabled();
    await user.clear(within(dialog).getByLabelText('Código (H1, H2…)'));
    await user.type(within(dialog).getByLabelText('Código (H1, H2…)'), 'H13');
    await user.click(within(dialog).getByRole('button', { name: 'Guardar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')!.body).toEqual({ kind: 'catalog_skill', data: { code: 'H13', name: 'Mezclas de dos fármacos', description: '' } }));
    expect(await screen.findByText(/Creado en borrador\. El cambio queda en borrador hasta su revisión/)).toBeInTheDocument();
  });

  it('retira una especie con motivo (nada se borra) y crea otra', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/items': items, 'POST /v1/admin/items/sp-gato/retire': { item: {} }, 'POST /v1/admin/items': { item: { id: 'sp-conejo', version: 1, state: 'draft' } } });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Especies' }));
    const row = await screen.findByRole('row', { name: /Gato/ });
    await user.click(within(row).getByRole('button', { name: 'Retirar' }));
    await user.type(screen.getByLabelText('Motivo (obligatorio)'), 'Duplicada');
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Retirar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items/sp-gato/retire')!.body).toEqual({ reason: 'Duplicada' }));
    await user.click(screen.getByRole('button', { name: 'Nueva especie' }));
    await user.type(within(screen.getByRole('dialog')).getByLabelText('Nombre'), 'Conejo');
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Guardar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')!.body).toEqual({ kind: 'catalog_species', data: { name: 'Conejo', sectorId: 'veterinaria' } }));
  });

  it('el editor de plantillas ofrece las habilidades y las especies del catálogo', async () => {
    const user = userEvent.setup();
    mockApi({ 'GET /v1/admin/items': items, 'GET /v1/admin/structure': { tree: [{ id: 'veterinaria', title: 'Veterinaria', children: [] }], itinerariesWithoutSector: [] }, 'GET /v1/admin/exercise-types': { items: [] } });
    renderApp('/plantillas/nueva', 'author');
    const skill = await screen.findByLabelText('Habilidad');
    await waitFor(() => expect(within(skill).getAllByRole('option').map((o) => o.textContent)).toEqual(['H1 · Conversión de unidades', 'H2 · Concentraciones']));
    await user.selectOptions(screen.getByLabelText('Sector'), 'veterinaria');
    const species = await screen.findByLabelText('Especie');
    expect(within(species).getAllByRole('option').map((o) => o.textContent)).toEqual(['Sin especie', 'Gato', 'Perro']);
    await user.selectOptions(species, 'perro');
    expect(species).toHaveValue('perro');
  });
});

describe('B26 · léxico de voz editable', () => {
  function serve() {
    let data = LEX.data;
    const api = mockApi({
      'GET /v1/admin/items': (c: Call) => (c.query.get('kind') === 'voice_lexicon' ? { items: [{ ...LEX, data }] } : items(c)),
      'PUT /v1/admin/items/voice-lexicon-es': ({ body }: Call) => { data = body.data; return { item: { id: 'voice-lexicon-es', version: 2, state: 'draft' } }; },
    });
    return api;
  }

  it('quita un sinónimo de sector y una confusión, en una versión nueva en borrador', async () => {
    const user = userEvent.setup();
    const api = serve();
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: /Voz/ }));
    await user.click(await screen.findByRole('button', { name: 'Quitar la forma hablada «ce ce»' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')!.body.data.sectorSynonyms).toEqual([{ spoken: 'gammas', unit: 'µg', sectorId: 'anestesia', enabledByDefault: false }]));
    await waitFor(() => expect(screen.queryByRole('row', { name: /ce ce/ })).not.toBeInTheDocument());
    await user.click(screen.getByRole('button', { name: 'Quitar la confusión «toma»' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')!.body.data.confusions).toEqual([{ from: 'como', to: 'coma' }]));
    expect(await screen.findByRole('list', { name: 'Léxico de confusiones' })).not.toHaveTextContent('toma');
  });

  it('edita las formas habladas de un comando y no deja un comando sin formas', async () => {
    const user = userEvent.setup();
    const api = serve();
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: /Voz/ }));
    const input = await screen.findByLabelText('Formas habladas del comando siguiente');
    await user.clear(input);
    await user.type(input, 'siguiente, Continúa , pasa');
    await user.tab();
    await waitFor(() => expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')!.body.data.commands).toEqual([{ command: 'repite', synonyms: ['repite', 'otra vez'] }, { command: 'siguiente', synonyms: ['siguiente', 'continúa', 'pasa'] }]));
    const calls = api.calls.filter((c) => c.method === 'PUT').length;
    const repite = screen.getByLabelText('Formas habladas del comando repite');
    await user.clear(repite);
    await user.tab();
    expect(repite).toHaveValue('repite, otra vez');
    expect(api.calls.filter((c) => c.method === 'PUT')).toHaveLength(calls);
  });

  it('activa por defecto un sinónimo de sector', async () => {
    const user = userEvent.setup();
    const api = serve();
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: /Voz/ }));
    await user.click(await screen.findByLabelText('«gammas» activado por defecto'));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')!.body.data.sectorSynonyms[0]).toMatchObject({ spoken: 'gammas', enabledByDefault: true }));
  });
});

describe('B24 · cierre de semana de las ligas', () => {
  const routes = {
    'GET /v1/admin/leagues/config': { current: { groupSize: 30, divisions: ['Bronce', 'Plata'], promote: 7, relegate: 5, pointsPerCorrect: 10, timetrialBonus: 20, dailyCap: 300, weekStartsOn: 1, groupBySector: true, minHumanMs: 500 }, scheduled: null },
    'GET /v1/admin/leagues/week': { week: '2026-11-16', groups: [] },
    'GET /v1/admin/leagues/flagged': { items: [] },
    'POST /v1/admin/leagues/close-week': { week: '2026-11-09', groups: [{ groupId: 'g1', promoted: 7, relegated: 5 }, { groupId: 'g2', promoted: 7, relegated: 0 }] },
  };
  it('la superadministración cierra la semana anterior y ve los ascensos y descensos aplicados', async () => {
    const user = userEvent.setup();
    const api = mockApi(routes);
    renderApp('/ligas', 'superadmin');
    await user.click(await screen.findByRole('button', { name: 'Cerrar la semana anterior' }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'Cerrar la semana' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/leagues/close-week')).toBeTruthy());
    expect(await screen.findByText('Semana del 9 nov 2026 cerrada: 2 grupos, 14 ascensos y 5 descensos.')).toBeInTheDocument();
  });
  it('la administración de contenido no puede cerrar la semana', async () => {
    mockApi(routes);
    renderApp('/ligas', 'content_admin');
    expect(await screen.findByLabelText('Tope diario')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Cerrar la semana anterior' })).not.toBeInTheDocument();
  });
});
