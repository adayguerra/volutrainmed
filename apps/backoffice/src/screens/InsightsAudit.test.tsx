import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';
import type { ItemStats } from './Analytics';

function stat(id: string, title: string, acc: number | null, responses: number, over: Partial<ItemStats> = {}): ItemStats {
  return {
    itemId: id, kind: 'template', title, sectorId: 'anestesia', exerciseTypeId: 'T1', responses, firstAttemptAccuracy: acc, medianMs: 40000, targetMs: 30000, timeRatio: 1.3,
    dontKnowPct: 5, critical: 2, unclassifiedPct: 10, topError: { value: '0.08', unit: 'ml/h', code: 'E1', count: 12 }, reports: 0, insufficient: responses < 50, alerts: [], ...over,
  };
}

const STATS = [stat('tpl-hep', 'Heparina sódica · bolo', 88, 880), stat('tpl-nora', 'Noradrenalina en ml/h', 34, 1284, { alerts: ['Acierto al primer intento del 34 %'] }), stat('tpl-conv', 'Conversiones mg ↔ µg', 99, 6420, { exerciseTypeId: 'T7' }), stat('tpl-melox', 'Meloxicam SC en perro', 70, 12)];

function analyticsList({ query }: Call) {
  const key = (query.get('sort') ?? 'firstAttemptAccuracy') as keyof ItemStats;
  const dir = query.get('dir') === 'desc' ? -1 : 1;
  const items = [...STATS].sort((a, b) => {
    const x = a[key] as number | null; const y = b[key] as number | null;
    if (x === null) return 1; if (y === null) return -1; return (x - y) * dir;
  });
  return { items };
}

describe('B21–B22 · analítica de contenido', () => {
  it('Preguntas con más fallos: al ordenar por acierto ascendente ve primero las plantillas con más fallos', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/analytics/items': analyticsList });
    renderApp('/analitica', 'content_admin');
    await screen.findByRole('table', { name: 'Analítica por elemento' });
    // Primero por respuestas y después por acierto ascendente.
    await user.click(screen.getByRole('button', { name: /^Respuestas/ }));
    await user.click(screen.getByRole('button', { name: /^Acierto 1\.er intento/ }));
    await waitFor(() => expect(api.last('GET', '/v1/admin/analytics/items')!.query.get('dir')).toBe('asc'));
    expect(api.last('GET', '/v1/admin/analytics/items')!.query.get('sort')).toBe('firstAttemptAccuracy');
    const rows = await screen.findAllByTestId('fila-analitica');
    await waitFor(() => expect(rows[0]).toHaveTextContent('Noradrenalina en ml/h'));
    const titles = screen.getAllByTestId('fila-analitica').map((r) => within(r).getAllByRole('cell')[0]!.textContent);
    expect(titles.slice(0, 3)).toEqual(['Noradrenalina en ml/h', 'Meloxicam SC en perro', 'Heparina sódica · bolo']);
    expect(screen.getByRole('columnheader', { name: /Acierto 1\.er intento/ })).toHaveAttribute('aria-sort', 'ascending');
  });

  it('Datos insuficientes: con menos de 50 respuestas su analítica indica «Datos insuficientes»', async () => {
    mockApi({
      'GET /v1/admin/analytics/items': analyticsList,
      'GET /v1/admin/analytics/items/tpl-melox': { stat: STATS[3], wrongAnswers: [], byLevel: [], byInput: [], byVariant: [], lowVariants: [], timeDistribution: [], byVersion: [], summary: 'Datos insuficientes: menos de 50 respuestas' },
    });
    const { unmount } = renderApp('/analitica', 'analyst');
    const row = (await screen.findAllByTestId('fila-analitica')).find((r) => r.textContent?.includes('Meloxicam'))!;
    expect(within(row).getByText((_, el) => el?.getAttribute('data-col') === 'acierto')).toHaveTextContent('Datos insuficientes');
    unmount();
    renderApp('/analitica/tpl-melox', 'analyst');
    expect(await screen.findByText('Datos insuficientes')).toBeInTheDocument();
    expect(screen.getByText(/12 respuestas de las 50 necesarias/)).toBeInTheDocument();
  });

  it('Error frecuente sin clasificar: el administrador puede añadirla como error previsible desde la ficha de analítica', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'GET /v1/admin/analytics/items/tpl-nora': {
        stat: STATS[1], summary: 'Acierto al primer intento del 34 % en 1284 respuestas',
        wrongAnswers: [{ value: '0.08', unit: 'ml/h', code: 'E1', n: 380 }, { value: '0.8', unit: 'ml/h', code: null, n: 90 }, { value: '480', unit: 'ml/h', code: 'E4', n: 70 }],
        byLevel: [{ level: 1, n: 200, acc: 92 }], byInput: [{ input_mode: 'touch', n: 1000, acc: 33 }], byVariant: [], lowVariants: [], timeDistribution: [{ b: 3, n: 40 }], byVersion: [{ content_version: '2026.11.3', n: 702, acc: 29 }],
      },
      'POST /v1/admin/analytics/items/tpl-nora/promote-error': { itemId: 'tpl-nora', version: 5 },
    });
    renderApp('/analitica/tpl-nora', 'content_admin');
    const table = await screen.findByRole('table', { name: 'Respuestas erróneas más dadas' });
    const unclassified = within(table).getByRole('row', { name: /Sin clasificar/ });
    expect(within(table).getAllByRole('button', { name: 'Añadir como error previsible' })).toHaveLength(1);
    await user.click(within(unclassified).getByRole('button', { name: 'Añadir como error previsible' }));
    const dialog = screen.getByRole('dialog', { name: 'Añadir como error previsible' });
    await user.selectOptions(within(dialog).getByLabelText('Tipo de error'), 'E1');
    await user.type(within(dialog).getByLabelText('Diagnóstico en una frase'), 'Has dejado el ritmo en minutos: falta pasar a horas');
    await user.type(within(dialog).getByLabelText('Fórmula del error'), 'respuesta ÷ 6');
    await user.click(within(dialog).getByRole('button', { name: 'Añadir' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/analytics/items/tpl-nora/promote-error')!.body).toEqual({ value: '0.8', unit: 'ml/h', code: 'E1', message: 'Has dejado el ritmo en minutos: falta pasar a horas', formula: 'respuesta ÷ 6' }));
    expect(await screen.findByText(/Creada la versión 5 en borrador con el nuevo error previsible/)).toBeInTheDocument();
  });

  it('el analista consulta la ficha sin poder promover errores', async () => {
    mockApi({ 'GET /v1/admin/analytics/items/tpl-nora': { stat: STATS[1], summary: 'x', wrongAnswers: [{ value: '0.8', unit: 'ml/h', code: null, n: 90 }], byLevel: [], byInput: [], byVariant: [], lowVariants: [], timeDistribution: [], byVersion: [] } });
    renderApp('/analitica/tpl-nora', 'analyst');
    await screen.findByRole('table', { name: 'Respuestas erróneas más dadas' });
    expect(screen.queryByRole('button', { name: 'Añadir como error previsible' })).not.toBeInTheDocument();
  });
});

const VARIANT = {
  id: 'tpl-nora.v4.118', templateId: 'tpl-nora', questionId: null, templateVersion: 4, level: 3, exerciseTypeId: 'T1', exerciseTypeVersion: 1, skillId: 'H9', sectorId: 'anestesia',
  statement: [{ t: 'text', v: 'Paciente simulado de ' }, { t: 'qty', value: '80', unit: 'kg' }, { t: 'text', v: '. Noradrenalina a ' }, { t: 'qty', value: '0.1', unit: 'µg/kg/min' }, { t: 'text', v: '.' }],
  question: '¿A cuántos ml/h?', tts: '', targetTimeS: 45, answer: { value: '4.8', unit: 'ml/h', unitFixed: true, unitChoices: ['ml/h'], equivalents: [], rounding: { mode: 'decimals', places: 1 }, tolerance: { kind: 'exact' } },
  predictedErrors: [{ value: '0.08', unit: 'ml/h', code: 'E1', message: 'Faltan los 60 minutos' }], steps: [], plausibility: '',
};
const MODELS = {
  patient: 'Gracias por escribirnos. VolutrainMed es un entrenador formativo con casos simulados: no respondemos consultas sobre pacientes ni tratamientos. Para un caso real, consulta a los profesionales y protocolos de tu centro.',
  fixed: 'Gracias por avisarnos. Hemos revisado el ejercicio y lo hemos corregido.', explanation: 'Gracias por tu pregunta.', received: 'Gracias por tu mensaje. Lo estamos revisando y te responderemos lo antes posible.',
};
function inquiry(over: Record<string, unknown> = {}) {
  return { id: 'iq-1', reference: 'VM-2611-0042', user_id: 'u-1', type: 'exercise_error', message: 'La explicación dice 100 µg/ml, pero el enunciado da la dilución en mg.', reply_email: null, status: 'in_review', assignee_id: null, reply: null, linked_item_id: null, is_patient_query: false, created_at: '2026-11-17T18:04:00Z', answered_at: null, exercise: { variantId: 'tpl-nora.v4.118', templateId: 'tpl-nora', questionId: null, answerValue: '0.08', answerUnit: 'ml/h' }, ...over };
}

describe('B25 · consultas de usuarios', () => {
  it('Aviso de error en un ejercicio: su ficha muestra la variante exacta y la respuesta que dio el usuario', async () => {
    const user = userEvent.setup();
    mockApi({ 'GET /v1/admin/inquiries': { items: [inquiry()], models: MODELS }, 'GET /v1/admin/inquiries/iq-1': { inquiry: inquiry(), variant: VARIANT, models: MODELS, suggestedModel: null } });
    renderApp('/consultas', 'content_admin');
    await user.click(await screen.findByRole('button', { name: /Error en un ejercicio/ }));
    const v = await screen.findByRole('region', { name: 'Variante exacta' });
    expect(v).toHaveTextContent('tpl-nora.v4.118');
    expect(v).toHaveTextContent('Paciente simulado de 80 kg. Noradrenalina a 0,1 µg/kg/min. ¿A cuántos ml/h?');
    expect(v).toHaveTextContent('Respuesta correcta: 4,8 ml/h');
    expect(within(v).getByTestId('respuesta-dada')).toHaveTextContent('Respuesta dada: 0,08 ml/h · E1');
  });

  it('Conversión en corrección: se crea un borrador de la plantilla enlazado con la consulta', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/inquiries': { items: [inquiry()], models: MODELS }, 'GET /v1/admin/inquiries/iq-1': { inquiry: inquiry(), variant: VARIANT, models: MODELS, suggestedModel: null }, 'POST /v1/admin/inquiries/iq-1/convert': { itemId: 'tpl-nora', version: 5 } });
    renderApp('/consultas', 'content_admin');
    await user.click(await screen.findByRole('button', { name: /Error en un ejercicio/ }));
    await user.click(await screen.findByRole('button', { name: 'Convertir en corrección de contenido' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/inquiries/iq-1/convert')).toBeTruthy());
    const note = await screen.findByText(/Creado el borrador v5 de la plantilla, enlazado con la consulta VM-2611-0042/);
    expect(within(note.closest('.notice') as HTMLElement).getByRole('link', { name: 'Abrir el borrador' })).toHaveAttribute('href', '/plantillas/tpl-nora');
  });

  it('Consulta sobre un paciente: se responde con la respuesta modelo que la declina', async () => {
    const user = userEvent.setup();
    const q = inquiry({ id: 'iq-2', reference: 'VM-2611-0050', type: 'other', is_patient_query: true, message: '¿Cuánta adrenalina le pongo a mi paciente de 70 kg?', exercise: null });
    const api = mockApi({ 'GET /v1/admin/inquiries': { items: [q], models: MODELS }, 'GET /v1/admin/inquiries/iq-2': { inquiry: q, variant: null, models: MODELS, suggestedModel: 'patient' }, 'POST /v1/admin/inquiries/iq-2/reply': { ok: true } });
    renderApp('/consultas', 'support');
    await user.click(await screen.findByRole('button', { name: /paciente/ }));
    expect(await screen.findByText(/Consulta sobre un paciente real: se responde con la respuesta modelo que la declina/)).toBeInTheDocument();
    expect(screen.getByLabelText('Respuesta modelo')).toHaveValue('patient');
    expect(screen.getByLabelText('Texto de la respuesta')).toHaveValue(MODELS.patient);
    await user.click(screen.getByRole('button', { name: 'Responder' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/inquiries/iq-2/reply')!.body).toEqual({ template: 'patient' }));
  });

  it('retira el ejercicio desde la consulta con el motivo ya rellenado', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/inquiries': { items: [inquiry()], models: MODELS }, 'GET /v1/admin/inquiries/iq-1': { inquiry: inquiry(), variant: VARIANT, models: MODELS, suggestedModel: null }, 'POST /v1/admin/inquiries/iq-1/withdraw-exercise': { revocation: { id: 1 } } });
    renderApp('/consultas', 'content_admin');
    await user.click(await screen.findByRole('button', { name: /Error en un ejercicio/ }));
    await user.click(await screen.findByRole('button', { name: 'Retirar el ejercicio ahora' }));
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByLabelText('Motivo (obligatorio)')).toHaveValue('Retirado desde la consulta VM-2611-0042');
    await user.click(within(dialog).getByRole('button', { name: 'Retirar ahora' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/inquiries/iq-1/withdraw-exercise')!.body).toEqual({ reason: 'Retirado desde la consulta VM-2611-0042' }));
    expect(await screen.findByText('Retirada aplicada: las apps dejan de presentarlo en cuanto tienen conexión.')).toBeInTheDocument();
  });
});

describe('B27 · registro de auditoría', () => {
  const rows = [
    { id: 42, actor_id: 'a1', actor_name: 'Lucía Martín', actor_role: 'author', action: 'item.update', entity: 'template', entity_id: 'tpl-melox', before: { name: 'Meloxicam', formula: 'dosis × peso' }, after: { name: 'Meloxicam', formula: 'dosis × peso ÷ concentración' }, reason: null, at: '2026-11-16T19:21:00' },
    { id: 41, actor_id: 'a2', actor_name: 'María Ortega', actor_role: 'content_admin', action: 'release.rollback', entity: 'release', entity_id: 'r-3', before: { number: '2026.11.3' }, after: { number: '2026.11.2' }, reason: 'Error en la explicación', at: '2026-11-15T12:15:00' },
  ];

  it('Cambio de una fórmula: el registro guarda el autor, la fecha, la fórmula anterior y la nueva', async () => {
    mockApi({ 'GET /v1/admin/audit': { items: rows } });
    renderApp('/auditoria', 'content_admin');
    const entry = (await screen.findAllByTestId('entrada-auditoria'))[0]!;
    expect(entry).toHaveTextContent('16 nov 2026, 19:21');
    expect(entry).toHaveTextContent('Lucía Martín');
    expect(entry).toHaveTextContent('Editó');
    expect(entry).toHaveTextContent('− formula: dosis × peso');
    expect(entry).toHaveTextContent('+ formula: dosis × peso ÷ concentración');
    expect(entry).not.toHaveTextContent('name:');
  });

  it('Intento de alteración: ni la superadministración puede modificar o borrar una entrada del registro', async () => {
    const api = mockApi({ 'GET /v1/admin/audit': { items: rows } });
    renderApp('/auditoria', 'superadmin');
    const table = await screen.findByRole('table', { name: 'Registro de auditoría' });
    expect(screen.getByText(/Registro inalterable: nadie, tampoco la superadministración, puede modificar ni borrar sus entradas/)).toBeInTheDocument();
    for (const entry of within(table).getAllByTestId('entrada-auditoria')) {
      expect(within(entry).queryByRole('button')).not.toBeInTheDocument();
      expect(within(entry).queryByRole('textbox')).not.toBeInTheDocument();
    }
    expect(screen.queryByRole('button', { name: /Borrar|Eliminar|Editar/ })).not.toBeInTheDocument();
    expect(api.calls.every((c) => c.method === 'GET')).toBe(true);
  });
});
