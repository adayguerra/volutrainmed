import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { QuestionDefinition } from '@vtm/engine';
import { mockApi, renderApp } from '../test/helpers';

const base = { 'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] }, 'GET /v1/admin/exercise-types': { items: [] } };

function qItem(data: Partial<QuestionDefinition>, state = 'draft', id = 'q-1') {
  const def: QuestionDefinition = {
    id, version: 1, name: 'Pregunta', exerciseTypeId: 'T1', sectorId: 'comun', skillId: 'H4', level: 2, targetTimeS: 20,
    statement: 'Paciente simulado de 80 kg. Necesitas 4,8 mg de un fármaco con una presentación de 5 mg/ml.', question: '¿Qué volumen cargas?', tts: null,
    answer: { value: '0.96', unit: 'ml', unitFixed: true, unitChoices: ['ml'], equivalents: [], rounding: { mode: 'decimals', places: 2 }, tolerance: { kind: 'exact' } },
    predictedErrors: [{ value: '9.6', unit: 'ml', code: 'E2', message: 'Tu respuesta es diez veces mayor. Revisa la coma' }],
    steps: [{ n: 1, text: 'Volumen = dosis ÷ concentración', operation: '4,8 mg ÷ 5 mg/ml', result: { value: '0.96', unit: 'ml' }, cancelled: ['mg'] }],
    plausibility: 'Menos de 1 ml: cabe en una jeringa de 1 ml.', ...data,
  };
  const item = { id, version: 1, kind: 'question', state, sectorId: 'comun', parentId: null, order: 1, title: def.name, data: def, authorId: 'acc-author', fingerprint: 'f', validations: 0, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null };
  return { item, versions: [item], reviews: [], comments: [], canEdit: true, canValidate: false };
}

describe('B10 · editor de preguntas', () => {
  it('Pregunta de selección única: queda en borrador y puede enviarse a revisión', async () => {
    const user = userEvent.setup();
    let saved: Partial<QuestionDefinition> | null = null;
    const api = mockApi({
      ...base,
      'GET /v1/admin/items': { items: [] },
      'POST /v1/admin/items': ({ body }) => { saved = body.data; return { item: { id: 'q-adr-1234' } }; },
      'GET /v1/admin/items/q-adr-1234': () => qItem({ ...saved!, id: 'q-adr-1234' }, 'draft', 'q-adr-1234'),
    });
    renderApp('/preguntas/nueva', 'author');
    expect(await screen.findByLabelText('Tipo de ejercicio')).toHaveValue('T2');
    await user.type(screen.getByLabelText('Enunciado'), 'Una ampolla de adrenalina contiene 1 mg en 10 ml.');
    await user.type(screen.getByLabelText('Pregunta'), '¿Qué concentración tiene?');
    await user.click(screen.getByRole('button', { name: 'Añadir opción' }));
    const labels = ['0,1 mg/ml', '1 mg/ml', '0,01 mg/ml', '10 mg/ml'];
    for (const [i, l] of labels.entries()) await user.type(screen.getByLabelText(`Opción ${'ABCD'[i]}`), l);
    for (const L of ['B', 'C', 'D']) await user.selectOptions(screen.getByLabelText(`Tipo de error de la opción ${L}`), 'E2');
    await user.click(screen.getByRole('button', { name: 'Añadir paso de la explicación' }));
    await user.type(screen.getByLabelText('Texto del paso 1'), '1 mg ÷ 10 ml');
    expect(within(screen.getByRole('list', { name: 'Comprobaciones al enviar' })).getAllByRole('listitem').every((li) => li.className.includes('c-success'))).toBe(true);
    await user.click(screen.getByRole('button', { name: 'Guardar borrador' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/items')).toBeTruthy());
    const body = api.last('POST', '/v1/admin/items')!.body;
    expect(body.kind).toBe('question');
    expect(body.data.options).toEqual([
      { label: '0,1 mg/ml', correct: true },
      { label: '1 mg/ml', correct: false, errorCode: 'E2' },
      { label: '0,01 mg/ml', correct: false, errorCode: 'E2' },
      { label: '10 mg/ml', correct: false, errorCode: 'E2' },
    ]);
    // Queda en borrador y la acción de enviar a revisión está disponible.
    await waitFor(() => expect(screen.getByRole('button', { name: 'Enviar a revisión' })).toBeEnabled());
    expect(screen.getByText('Borrador')).toHaveClass('chip');
    expect(screen.getByText('v1')).toBeInTheDocument();
  });

  it('Cantidad sin unidad: la comprobación automática lo señala antes de enviar a revisión', async () => {
    const user = userEvent.setup();
    mockApi({ ...base, 'GET /v1/admin/items/q-1': qItem({ statement: 'Paciente simulado de 80 kg.' }), 'GET /v1/admin/items': { items: [] } });
    renderApp('/preguntas/q-1', 'author');
    const statement = await screen.findByLabelText('Enunciado');
    await user.clear(statement);
    await user.type(statement, 'Un perro pesa 24 y necesita 0,2 mg/kg.');
    const checks = screen.getByRole('list', { name: 'Comprobaciones al enviar' });
    const qty = within(checks).getByText(/Cantidades con unidad/);
    expect(qty).toHaveClass('c-error');
    expect(qty).toHaveTextContent('Cantidades con unidad: 24');
    expect(screen.getByRole('list', { name: 'Motivos que impiden enviar' })).toHaveTextContent('Cantidad sin unidad: 24');
    expect(screen.getByRole('button', { name: 'Enviar a revisión' })).toBeDisabled();
  });
});

describe('B11 · vista previa con lectura en voz alta', () => {
  it('Escuchar un ejercicio: oye el enunciado como lo oirá el usuario y ve el texto que se dice, con las cantidades resaltadas', async () => {
    const user = userEvent.setup();
    const speakSpy = vi.spyOn(window.speechSynthesis, 'speak');
    mockApi({ 'GET /v1/admin/items/q-1': qItem({}) });
    renderApp('/vista-previa/q-1', 'author');
    await user.click(await screen.findByRole('button', { name: 'Manos libres' }));
    await user.click(screen.getByRole('button', { name: 'Reproducir' }));
    expect(speakSpy).toHaveBeenCalledTimes(1);
    const utterance = speakSpy.mock.calls[0]![0] as SpeechSynthesisUtterance;
    const shown = screen.getByTestId('texto-hablado');
    expect(utterance.text).toBe(shown.textContent!.replace(/\s+/g, ' ').trim());
    expect(utterance.lang).toBe('es-ES');
    // El normalizador lee las cantidades en palabras y la vista las resalta.
    const marks = within(shown).getAllByText((_, el) => el?.tagName === 'MARK');
    expect(marks.map((m) => m.textContent)).toEqual(['ochenta kilos', 'cuatro coma ocho miligramos', 'cinco miligramos por mililitro']);
    expect(shown).toHaveTextContent('¿Qué volumen cargas?');
    expect(screen.getByText('Leyendo')).toHaveAttribute('role', 'status');
  });

  it('Simular una respuesta: «cero coma noventa y seis» se interpreta como 0,96 y muestra el veredicto que recibiría', async () => {
    const user = userEvent.setup();
    mockApi({ 'GET /v1/admin/items/q-1': qItem({}) });
    renderApp('/vista-previa/q-1', 'author');
    await user.type(await screen.findByLabelText('Simular respuesta'), 'cero coma noventa y seis');
    await user.click(screen.getByRole('button', { name: 'Interpretar' }));
    expect(screen.getByTestId('interpretacion')).toHaveTextContent('0,96 ml');
    expect(screen.getByTestId('veredicto')).toHaveTextContent('Correcto');
    expect(screen.getByText(/«Cero coma noventa y seis mililitros\. ¿Correcto\?»/)).toBeInTheDocument();
    // Una respuesta diez veces mayor recibe su diagnóstico.
    await user.clear(screen.getByLabelText('Simular respuesta'));
    await user.type(screen.getByLabelText('Simular respuesta'), 'nueve coma seis');
    await user.click(screen.getByRole('button', { name: 'Interpretar' }));
    expect(screen.getByTestId('veredicto')).toHaveTextContent('Incorrecto');
    expect(screen.getByText('Tu respuesta es diez veces mayor. Revisa la coma')).toBeInTheDocument();
  });

  it('Vista previa en tablet: con tablet y orientación horizontal se ve la disposición de dos paneles', async () => {
    const user = userEvent.setup();
    mockApi({ 'GET /v1/admin/items/q-1': qItem({}) });
    renderApp('/vista-previa/q-1', 'author');
    const region = await screen.findByRole('region', { name: 'Vista previa del ejercicio' });
    expect(region).toHaveAttribute('data-layout', 'una-columna');
    await user.click(screen.getByRole('button', { name: 'Tablet' }));
    await user.click(screen.getByRole('button', { name: 'Horizontal' }));
    const tablet = screen.getByRole('region', { name: 'Vista previa del ejercicio' });
    expect(tablet).toHaveAttribute('data-layout', 'dos-paneles');
    expect(tablet).toHaveClass('tablet-h');
    expect(within(tablet).getByTestId('panel-datos')).toHaveTextContent('Paciente simulado de 80 kg');
    expect(within(tablet).getByTestId('panel-respuesta')).toHaveTextContent('Comprobar');
  });
});
