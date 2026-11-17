import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';

const ACH = { id: 'ach-streak-7', version: 1, kind: 'achievement', state: 'published', sectorId: null, parentId: null, order: 1, title: 'Siete días', data: { name: 'Siete días', description: 'Siete días de racha', category: 'constancia', icon: 'local_fire_department', condition: { metric: 'streak_days', op: '>=', value: 7, scope: 'global' }, secret: false, retroactive: true }, authorId: null, fingerprint: 'f', validations: 1, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null };

/** Evalúa la condición como la API (evaluateCondition) con métricas de ejemplo. */
function testLike({ body }: Call) {
  const v = (body.sample ?? { streak_days: 12 })[body.condition.metric] ?? 0;
  const ok = body.condition.op === '>=' ? v >= body.condition.value : body.condition.op === '>' ? v > body.condition.value : v === body.condition.value;
  return { obtains: ok, value: v, message: ok ? `Lo obtendría: ${v} ${body.condition.op} ${body.condition.value}` : `No lo obtendría: tiene ${v} y la condición pide ${body.condition.op} ${body.condition.value}` };
}

describe('B23 · logros', () => {
  it('Prueba de la condición: con un usuario de ejemplo de 12 días de racha indica que no obtendría el logro', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/items': { items: [ACH] }, 'POST /v1/admin/achievements/test': testLike, 'POST /v1/admin/items': { item: { ...ACH, id: 'ach-30', state: 'draft' } } });
    renderApp('/logros', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Nuevo logro' }));
    await user.type(screen.getByLabelText('Nombre'), '30 días de racha');
    await user.selectOptions(screen.getByLabelText('Métrica'), 'streak_days');
    await user.selectOptions(screen.getByLabelText('Operador'), '>=');
    await user.clear(screen.getByLabelText('Valor'));
    await user.type(screen.getByLabelText('Valor'), '30');
    await user.type(screen.getByLabelText('Usuario de ejemplo (identificador)'), 'usuario-42');
    await user.click(screen.getByRole('button', { name: 'Probar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/achievements/test')!.body).toEqual({ condition: { metric: 'streak_days', op: '>=', value: 30, scope: 'global' }, userId: 'usuario-42' }));
    expect(await screen.findByText('No lo obtendría: tiene 12 y la condición pide >= 30')).toBeInTheDocument();
    // Y se guarda sin código, en borrador.
    await user.click(screen.getByRole('button', { name: 'Guardar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')!.body).toMatchObject({ kind: 'achievement', data: { name: '30 días de racha', condition: { metric: 'streak_days', op: '>=', value: 30, scope: 'global' } } }));
    expect(await screen.findByText(/Logro creado en borrador: tras su revisión llega a las apps con la siguiente publicación/)).toBeInTheDocument();
  });
});

describe('B24 · ligas', () => {
  it('Cambio del tope diario: cambiado un miércoles, el nuevo tope se aplica desde el lunes siguiente', async () => {
    const user = userEvent.setup();
    const current = { groupSize: 30, divisions: ['Bronce', 'Plata', 'Oro'], promote: 7, relegate: 5, pointsPerCorrect: 10, timetrialBonus: 20, dailyCap: 300, weekStartsOn: 1, groupBySector: true, minHumanMs: 500 };
    let scheduled: unknown = null;
    const api = mockApi({
      'GET /v1/admin/leagues/config': () => ({ current, scheduled }),
      'PUT /v1/admin/leagues/config': ({ body }: Call) => { scheduled = { value: body, effective_from: '2026-11-23T00:00:00Z' }; return { scheduledFrom: '2026-11-23T00:00:00.000Z', message: 'El cambio se aplica desde el lunes 2026-11-23' }; },
      'GET /v1/admin/leagues/week': { week: '2026-11-16', groups: [{ id: 'g', division: 1, sector_id: 'enfermeria', members: 30, points: 2400 }] },
      'GET /v1/admin/leagues/flagged': { items: [] },
    });
    renderApp('/ligas', 'content_admin');
    const cap = await screen.findByLabelText('Tope diario');
    await user.clear(cap);
    await user.type(cap, '250');
    await user.click(screen.getByRole('button', { name: 'Programar cambios' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/leagues/config')!.body.dailyCap).toBe(250));
    expect(await screen.findByText(/El cambio se aplica desde el lunes 2026-11-23\. La semana en curso sigue con el tope actual de 300 puntos/)).toBeInTheDocument();
    expect(await screen.findByText(/entran en vigor al empezar la semana siguiente: lunes 23 nov 2026/)).toBeInTheDocument();
  });
});

const LEX = { id: 'voice-lexicon-es', version: 1, kind: 'voice_lexicon', state: 'published', sectorId: null, parentId: null, order: 1, title: 'Léxico de voz (es-ES)', authorId: null, fingerprint: 'f', validations: 1, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null,
  data: { name: 'Léxico de voz (es-ES)', confusions: [{ from: 'como', to: 'coma' }], commands: [{ command: 'repite', synonyms: ['repite', 'otra vez'] }], sectorSynonyms: [] as { spoken: string; unit: string; sectorId: string; enabledByDefault?: boolean }[] } };

describe('B26 · catálogos de unidades y voz', () => {
  it('Nueva forma hablada: «gammas» para microgramos en anestesia queda en borrador hasta su revisión y llega con la siguiente publicación', async () => {
    const user = userEvent.setup();
    let saved: typeof LEX | null = null;
    const api = mockApi({
      'GET /v1/admin/items': ({ query }: Call) => ({ items: query.get('kind') === 'voice_lexicon' ? [saved ?? LEX] : [] }),
      'PUT /v1/admin/items/voice-lexicon-es': ({ body }: Call) => { saved = { ...LEX, version: 2, state: 'draft', data: body.data }; return { item: saved }; },
    });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: /Voz/ }));
    await user.type(await screen.findByLabelText('Nueva forma hablada'), 'gammas');
    await user.clear(screen.getByLabelText('Unidad'));
    await user.type(screen.getByLabelText('Unidad'), 'µg');
    await user.selectOptions(screen.getByLabelText('Sector del sinónimo'), 'anestesia');
    await user.click(screen.getByRole('button', { name: 'Añadir forma hablada' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')).toBeTruthy());
    expect(api.last('PUT', '/v1/admin/items/voice-lexicon-es')!.body.data.sectorSynonyms).toEqual([{ spoken: 'gammas', unit: 'µg', sectorId: 'anestesia', enabledByDefault: false }]);
    expect(await screen.findByText('Creada la versión 2 en borrador. El cambio queda en borrador hasta su revisión y llega a las apps con la siguiente publicación.')).toBeInTheDocument();
    const table = await screen.findByRole('table', { name: 'Sinónimos por sector' });
    await waitFor(() => expect(within(table).getByRole('row', { name: /gammas/ })).toHaveTextContent('Anestesia y reanimación'));
    expect(screen.getAllByText('Borrador').length).toBeGreaterThan(0);
  });

  it('Prueba de interpretación: «doscientas gammas» se interpreta como 200 µg', async () => {
    const user = userEvent.setup();
    const lex = { ...LEX, data: { ...LEX.data, sectorSynonyms: [{ spoken: 'gammas', unit: 'µg', sectorId: 'anestesia', enabledByDefault: false }] } };
    const api = mockApi({ 'GET /v1/admin/items': ({ query }: Call) => ({ items: query.get('kind') === 'voice_lexicon' ? [lex] : [] }), 'POST /v1/admin/engine/parse-spoken': { kind: 'number', value: '200', unit: 'µg' } });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: /Voz/ }));
    await user.type(await screen.findByLabelText('Escribe lo que diría el usuario'), 'doscientas gammas');
    await user.click(screen.getByRole('button', { name: 'Interpretar' }));
    expect(screen.getByTestId('interpretacion-catalogo')).toHaveTextContent('200 µg');
    expect(screen.getByText(/«gammas» → «microgramos»/)).toBeInTheDocument();
    await waitFor(() => expect(api.last('POST', '/v1/admin/engine/parse-spoken')).toBeTruthy());
  });

  it('Texto con alusión clínica: un anuncio que menciona pacientes o guardias no se puede guardar ni enviar a revisión', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/items': { items: [] }, 'GET /v1/admin/ads/params': { params: { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 } }, 'GET /v1/admin/ads/performance': { items: [] } });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Anuncios propios' }));
    await user.click(await screen.findByRole('button', { name: 'Nuevo anuncio' }));
    await user.type(screen.getByLabelText('Titular'), 'Entrena sin pausas');
    await user.type(screen.getByLabelText('Texto'), 'Úsalo en tu guardia con tus pacientes.');
    const checks = screen.getByRole('region', { name: 'Comprobaciones del anuncio' });
    expect(checks).toHaveTextContent('Término vetado: «paciente»');
    expect(checks).toHaveTextContent('Alusión a uso clínico: «en tu guardia»');
    expect(within(screen.getByRole('dialog')).getByRole('button', { name: 'Guardar' })).toBeDisabled();
    expect(api.calls.some((c) => c.method === 'POST' && c.path === '/v1/admin/items')).toBe(false);
  });

  it('la espera de los anuncios se cambia y llega con la siguiente publicación', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/items': { items: [] }, 'GET /v1/admin/ads/params': { params: { waitS: 3, frequencyTouch: 1, frequencyVoice: 1, defaultDailyCap: 6 } }, 'GET /v1/admin/ads/performance': { items: [] }, 'PUT /v1/admin/ads/params': { params: {}, note: 'Los cambios llegan a las apps con la siguiente publicación de contenido' } });
    renderApp('/catalogos', 'content_admin');
    await user.click(await screen.findByRole('tab', { name: 'Anuncios propios' }));
    const wait = await screen.findByLabelText('Espera antes de continuar (0–5 s)');
    await user.clear(wait);
    await user.type(wait, '2');
    await user.click(screen.getByRole('button', { name: 'Guardar espera y frecuencia' }));
    await waitFor(() => expect(api.last('PUT', '/v1/admin/ads/params')!.body.waitS).toBe(2));
    expect(await screen.findByText('Guardado. Los cambios llegan a las apps con la siguiente publicación de contenido')).toBeInTheDocument();
  });
});
