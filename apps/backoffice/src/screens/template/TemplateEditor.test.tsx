import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import type { TemplateDefinition } from '@vtm/engine';
import { defaultLevels } from '../../content/template';
import { mockApi, renderApp } from '../../test/helpers';
import type { Role } from '../../api/types';

const ROWS = [
  { farmaco: 'Meloxicam', dosis: '0.2', conc: '5', especie: 'Perro' },
  { farmaco: 'Meloxicam', dosis: '0.1', conc: '5', especie: 'Perro' },
  { farmaco: 'Meloxicam', dosis: '0.3', conc: '1.5', especie: 'Gato' },
];

function tpl(over: Partial<TemplateDefinition> = {}): TemplateDefinition {
  return {
    id: 'tpl-melox', version: 1, name: 'Meloxicam SC · volumen', sectorId: 'veterinaria', skillId: 'H4', exerciseTypeId: 'T1', species: null,
    variables: [
      { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      { name: 'caso', label: 'Caso', kind: 'case_table', unit: '', show: true, columns: [{ name: 'farmaco', unit: '' }, { name: 'dosis', unit: 'mg/kg' }, { name: 'conc', unit: 'mg/ml' }, { name: 'especie', unit: '' }], rows: [ROWS[0]!] },
    ],
    statement: 'Un animal de {peso}. Pauta: {caso.farmaco} a {caso.dosis}. Presentación: {caso.conc}.', question: '¿Qué volumen cargas?', tts: null,
    formula: 'caso.dosis × peso ÷ caso.conc', answerUnit: 'ml', unitChoices: ['ml'], equivalents: [], rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' },
    constraints: { conditions: [] }, predictedErrors: [],
    steps: [
      { text: 'Dosis total', formula: 'caso.dosis × peso', unit: 'mg', operation: '{caso.dosis} × {peso}', cancelled: ['kg'] },
      { text: 'Volumen', formula: 'caso.dosis × peso ÷ caso.conc', unit: 'ml', operation: '{paso1} ÷ {caso.conc}', cancelled: ['mg'] },
    ],
    plausibility: '{respuesta} cabe en una jeringa pequeña.', levels: defaultLevels(), variantsPerLevel: 20, ...over,
  };
}

function item(def: TemplateDefinition, over: Record<string, unknown> = {}) {
  const it = { id: def.id, version: 1, kind: 'template', state: 'draft', sectorId: def.sectorId, parentId: null, order: 1, title: def.name, data: def, authorId: 'acc-author', fingerprint: 'f1', validations: 0, validatedUntil: null, updatedAt: '2026-11-16T10:00:00Z', createdAt: '2026-11-16T10:00:00Z', linkedInquiry: null, ...over };
  return it;
}

function serve(def: TemplateDefinition, opts: { canEdit?: boolean; state?: string; extra?: Record<string, object> } = {}) {
  const it = item(def, { state: opts.state ?? 'draft' });
  return mockApi({
    [`GET /v1/admin/items/${def.id}`]: { item: it, versions: [it], reviews: [], comments: [], canEdit: opts.canEdit ?? true, canValidate: false },
    'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] },
    'GET /v1/admin/exercise-types': { items: [] },
    ...(opts.extra ?? {}),
  });
}

const num = (s: string) => Number(s.replace(/[^\d,.-]/g, '').replace(',', '.'));

async function generate(user: ReturnType<typeof userEvent.setup>) {
  await user.click(await screen.findByRole('button', { name: 'Generar 20 variantes de muestra' }));
  return screen.getAllByTestId('variant-row');
}

function open(role: Role = 'author', id = 'tpl-melox') {
  renderApp(`/plantillas/${id}`, role);
}

describe('B06–B09 · editor de plantillas', () => {
  it('Plantilla de dosis por peso: obtiene 20 variantes con su enunciado, su respuesta en ml y sus pasos resueltos', async () => {
    const user = userEvent.setup();
    serve(tpl());
    open();
    const rows = await generate(user);
    expect(rows).toHaveLength(20);
    for (const r of rows) {
      const peso = num(within(r).getByText((_, el) => el?.getAttribute('data-col') === 'peso').textContent!);
      expect(peso).toBeGreaterThanOrEqual(5);
      expect(peso).toBeLessThanOrEqual(40);
      const answer = within(r).getByText((_, el) => el?.getAttribute('data-col') === 'respuesta').textContent!;
      expect(answer).toMatch(/ ml$/);
      // 0,2 mg/kg × peso ÷ 5 mg/ml
      expect(num(answer)).toBeCloseTo(Math.round(((0.2 * peso) / 5) * 100) / 100, 5);
      expect(within(r).getByText(/Un animal de/, { selector: 'p' })).toBeInTheDocument();
      const steps = within(r).getAllByRole('listitem');
      expect(steps).toHaveLength(2);
      expect(steps[0]).toHaveTextContent(/Dosis total: .* mg$/);
      expect(steps[1]).toHaveTextContent(/Volumen: .* ml$/);
    }
  });

  it('Tabla de casos: cada variante usa una fila completa, sin mezclar valores de filas distintas', async () => {
    const user = userEvent.setup();
    const def = tpl({ variables: [tpl().variables[0]!, { ...tpl().variables[1]!, rows: ROWS }] });
    serve(def);
    open();
    const rows = await generate(user);
    const allowed = new Set(ROWS.map((r) => `${r.dosis.replace('.', ',')} mg/kg|${r.conc.replace('.', ',')} mg/ml|${r.especie}`));
    const seen = new Set<string>();
    for (const r of rows) {
      const cell = (c: string) => within(r).getByText((_, el) => el?.getAttribute('data-col') === c).textContent!;
      const key = `${cell('caso.dosis')}|${cell('caso.conc')}|${cell('caso.especie')}`;
      expect(allowed.has(key)).toBe(true);
      seen.add(key);
    }
    expect(seen.size).toBeGreaterThan(1);
  });

  it('Unidades coherentes: el editor indica que la fórmula produce ml', async () => {
    const user = userEvent.setup();
    serve(tpl({
      formula: '',
      variables: [
        { name: 'dosis', label: 'Pauta', kind: 'decimal', unit: 'mg/kg', min: '0.1', max: '0.5', step: '0.1', show: true },
        { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
        { name: 'conc', label: 'Presentación', kind: 'list', unit: 'mg/ml', values: ['5'], show: true },
      ],
    }));
    open();
    await user.click(await screen.findByRole('tab', { name: /Fórmula y respuesta/ }));
    await user.type(screen.getByLabelText('Fórmula'), 'dosis × peso ÷ conc');
    expect(await screen.findByText(/La fórmula produce ml/)).toBeInTheDocument();
    expect(screen.getByText('Las unidades cuadran.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Guardar' })).toBeEnabled();
  });

  it('Unidades incoherentes: indica «El resultado sale en mg, no en ml» y no permite guardar la fórmula', async () => {
    const user = userEvent.setup();
    const api = serve(tpl({
      formula: '',
      variables: [
        { name: 'dosis', label: 'Pauta', kind: 'decimal', unit: 'mg/kg', min: '0.1', max: '0.5', step: '0.1', show: true },
        { name: 'peso', label: 'Peso', kind: 'int', unit: 'kg', min: '5', max: '40', step: '1', show: true },
      ],
    }));
    open();
    await user.click(await screen.findByRole('tab', { name: /Fórmula y respuesta/ }));
    await user.type(screen.getByLabelText('Fórmula'), 'dosis × peso');
    expect(await screen.findByText('El resultado sale en mg, no en ml', { selector: 'strong' })).toBeInTheDocument();
    const save = screen.getByRole('button', { name: 'Guardar' });
    expect(save).toBeDisabled();
    await user.click(save);
    expect(api.calls.some((c) => c.method === 'PUT')).toBe(false);
  });

  it('Resultado fuera de rango: ninguna variante tiene una respuesta fuera de ese rango', async () => {
    const user = userEvent.setup();
    // Con 1 mg/ml y pesos de 5 a 40 kg, sin restricción saldrían respuestas de hasta 8 ml.
    serve(tpl({ variables: [tpl().variables[0]!, { ...tpl().variables[1]!, rows: [{ farmaco: 'Meloxicam', dosis: '0.2', conc: '1', especie: 'Perro' }] }], constraints: { resultMin: '0.1', resultMax: '3', conditions: [] } }));
    open();
    const rows = await generate(user);
    expect(rows.length).toBeGreaterThan(0);
    for (const r of rows) {
      const v = num(within(r).getByText((_, el) => el?.getAttribute('data-col') === 'respuesta').textContent!);
      expect(v).toBeGreaterThanOrEqual(0.1);
      expect(v).toBeLessThanOrEqual(3);
    }
  });

  it('Error previsible de factor diez: cada variante incluye ese valor erróneo asociado a su diagnóstico', async () => {
    const user = userEvent.setup();
    serve(tpl());
    open();
    await user.click(await screen.findByRole('tab', { name: /Restricciones y errores previsibles/ }));
    await user.click(screen.getByRole('button', { name: 'E2 · ×10' }));
    const table = screen.getByRole('table', { name: 'Errores previsibles' });
    expect(within(table).getByLabelText('Fórmula del error 1')).toHaveValue('respuesta × 10');
    expect(within(table).getByLabelText('Código del error 1')).toHaveValue('E2');
    const rows = await generate(user);
    for (const r of rows) {
      const answer = num(within(r).getByText((_, el) => el?.getAttribute('data-col') === 'respuesta').textContent!);
      const errs = within(r).getByText((_, el) => el?.getAttribute('data-col') === 'errores');
      expect(errs).toHaveTextContent('E2 · Tu respuesta es diez veces mayor. Revisa la coma');
      expect(num(errs.textContent!.split(' · ')[0]!)).toBeCloseTo(answer * 10, 5);
    }
  });

  it('Colisión detectada: el informe la señala y la plantilla no puede enviarse a revisión hasta resolverla', async () => {
    const user = userEvent.setup();
    serve(tpl({ predictedErrors: [{ formula: 'caso.dosis × peso ÷ caso.conc', unit: 'ml', code: 'E3', message: 'Error que coincide con la respuesta' }] }));
    open();
    const submit = await screen.findByRole('button', { name: 'Enviar a revisión' });
    expect(submit).toBeEnabled();
    await user.click(screen.getByRole('button', { name: 'Prueba masiva (1000)' }));
    const report = await screen.findByRole('region', { name: 'Informe de la prueba masiva' });
    expect(within(report).getByText(/colisiones entre la respuesta correcta y una errónea previsible/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Enviar a revisión' })).toBeDisabled();
  });

  it('Variantes insuficientes: indica cuántas cumplen las restricciones y sugiere ampliar los rangos', async () => {
    const user = userEvent.setup();
    serve(tpl({ variables: [{ name: 'peso', label: 'Peso', kind: 'list', unit: 'kg', values: ['10', '20', '30'], show: true }, tpl().variables[1]!], variantsPerLevel: 20 }));
    open();
    await user.click(await screen.findByRole('button', { name: 'Prueba masiva (1000)' }));
    const report = await screen.findByRole('region', { name: 'Informe de la prueba masiva' });
    expect(within(report).getByText('Variantes insuficientes.')).toBeInTheDocument();
    expect(within(report).getByText(/Nivel 1: 3 de 20 cumplen las restricciones/)).toBeInTheDocument();
    expect(within(report).getByText(/Amplía los rangos/)).toBeInTheDocument();
  });

  it('Nivel con números limpios: todas las variantes de nivel 1 usan un peso múltiplo de 10', async () => {
    const user = userEvent.setup();
    serve(tpl());
    open();
    await user.click(await screen.findByRole('tab', { name: /Explicación y niveles/ }));
    await user.type(screen.getByLabelText('Nivel 1 · múltiplo de para peso'), '10');
    await user.selectOptions(screen.getByLabelText('Nivel de la muestra'), '1');
    const rows = await generate(user);
    expect(rows.length).toBeGreaterThan(0);
    for (const r of rows) {
      expect(within(r).getAllByRole('cell')[0]).toHaveTextContent('1');
      const peso = num(within(r).getByText((_, el) => el?.getAttribute('data-col') === 'peso').textContent!);
      expect(peso % 10).toBe(0);
    }
  });

  it('Plantilla sin pasos: el back office impide enviarla a revisión', async () => {
    const user = userEvent.setup();
    const api = serve(tpl({ steps: [] }));
    open();
    const submit = await screen.findByRole('button', { name: 'Enviar a revisión' });
    expect(submit).toBeDisabled();
    expect(screen.getByRole('list', { name: 'Comprobaciones de la plantilla' })).toHaveTextContent('La plantilla necesita los pasos de su explicación');
    await user.click(submit);
    expect(api.calls.some((c) => c.path.endsWith('/submit'))).toBe(false);
  });

  it('envía a revisión una plantilla completa', async () => {
    const user = userEvent.setup();
    const api = serve(tpl(), { extra: { 'POST /v1/admin/items/tpl-melox/submit': { item: item(tpl(), { state: 'in_review' }) } } });
    open();
    await user.click(await screen.findByRole('button', { name: 'Enviar a revisión' }));
    await waitFor(() => expect(api.calls.some((c) => c.method === 'POST' && c.path === '/v1/admin/items/tpl-melox/submit')).toBe(true));
  });

  it('Autor: abre una plantilla creada por otro autor, puede verla y no puede modificarla', async () => {
    serve(tpl(), { canEdit: false });
    open('author');
    expect(await screen.findByText(/esta plantilla es de otra persona; puedes verla, no modificarla/)).toBeInTheDocument();
    expect(screen.getByLabelText('Nombre de la plantilla')).toHaveValue('Meloxicam SC · volumen');
    expect(screen.getByLabelText('Nombre de la plantilla')).toBeDisabled();
    expect(screen.queryByRole('button', { name: 'Guardar' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Enviar a revisión' })).not.toBeInTheDocument();
  });

  it('Analista: abre una plantilla, puede consultar su analítica y no puede editarla', async () => {
    serve(tpl(), { canEdit: false });
    open('analyst');
    expect(await screen.findByRole('link', { name: 'Ver analítica' })).toHaveAttribute('href', '/analitica/tpl-melox');
    expect(screen.getByLabelText('Nombre de la plantilla')).toBeDisabled();
    expect(screen.queryByRole('button', { name: 'Guardar' })).not.toBeInTheDocument();
    expect(screen.getByText(/puedes consultar la plantilla y su analítica, no editarla/)).toBeInTheDocument();
  });

  it('Edición de un contenido publicado: se crea una versión nueva en borrador y la versión publicada sigue llegando a los usuarios', async () => {
    const user = userEvent.setup();
    const def = tpl();
    const v1 = item(def, { state: 'published' });
    const v2 = item({ ...def, name: 'Meloxicam SC · volumen (revisada)' }, { state: 'draft', version: 2 });
    let saved = false;
    const api = mockApi({
      'GET /v1/admin/items/tpl-melox': () => (saved
        ? { item: v2, versions: [v2, v1], reviews: [], comments: [], canEdit: true, canValidate: false }
        : { item: v1, versions: [v1], reviews: [], comments: [], canEdit: true, canValidate: false }),
      'PUT /v1/admin/items/tpl-melox': () => { saved = true; return { item: v2 }; },
      'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] },
      'GET /v1/admin/exercise-types': { items: [] },
    });
    open('author');
    expect(await screen.findByText(/Al guardar se crea la versión 2 en borrador y la versión 1 publicada sigue llegando a los usuarios/)).toBeInTheDocument();
    await user.type(screen.getByLabelText('Nombre de la plantilla'), ' (revisada)');
    await user.click(screen.getByRole('button', { name: 'Guardar' }));
    expect(await screen.findByText('Creada la versión 2 en borrador. La versión 1 publicada sigue llegando a los usuarios')).toBeInTheDocument();
    expect(api.last('PUT', '/v1/admin/items/tpl-melox')!.body.data.name).toBe('Meloxicam SC · volumen (revisada)');
    const versions = await screen.findByRole('list', { name: 'Versiones de la plantilla' });
    await waitFor(() => expect(within(versions).getAllByRole('listitem')).toHaveLength(2));
    expect(within(versions).getAllByRole('listitem')[0]).toHaveTextContent('v2Borrador');
    expect(within(versions).getAllByRole('listitem')[1]).toHaveTextContent('v1Publicado');
  });

  it('crea una plantilla nueva sin identificador y abre su ficha', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'POST /v1/admin/items': { item: { id: 'tpl-nueva-ab12' } },
      'GET /v1/admin/items/tpl-nueva-ab12': { item: item({ ...tpl(), id: 'tpl-nueva-ab12', name: 'Nueva' }), versions: [], reviews: [], comments: [], canEdit: true, canValidate: false },
      'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] },
      'GET /v1/admin/exercise-types': { items: [] },
    });
    renderApp('/plantillas/nueva', 'author');
    await user.type(await screen.findByLabelText('Nombre de la plantilla'), 'Nueva');
    await user.click(screen.getByRole('button', { name: 'Guardar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/items')!.body).toMatchObject({ kind: 'template', data: { name: 'Nueva' } });
    expect(api.last('POST', '/v1/admin/items')!.body.data.id).toBeUndefined();
  });
});
