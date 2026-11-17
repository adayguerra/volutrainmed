import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { HttpError, mockApi, renderApp } from '../test/helpers';
import { defaultLevels } from '../content/template';

const CHECKLIST = [
  ['pauta_plausible', 'Pauta plausible'], ['presentacion_existente', 'Presentación existente'], ['unidades_correctas', 'Unidades correctas'], ['aritmetica_verificada', 'Aritmética verificada'],
  ['redondeo_instrumento', 'Redondeo adecuado al instrumento'], ['explicacion_clara', 'Explicación clara'], ['texto_voz_correcto', 'Texto para voz correcto'], ['errores_previsibles_pertinentes', 'Errores previsibles pertinentes'],
].map(([key, label]) => ({ key: key!, label: label! }));

function variant(i: number, value: string, recalculated = value) {
  return { id: `tpl-melox.v2.${i}`, level: (i % 5) + 1, statement: `Perro de ${10 + i} kg. Pauta 0,2 mg/kg. Presentación 5 mg/ml.`, question: '¿Qué volumen cargas?', tts: 'Perro de diez kilos', answer: { value, unit: 'ml' }, recalculated, matches: value === recalculated, assignment: { peso: { value: String(10 + i), unit: 'kg' } } };
}

function sheet(over: Record<string, unknown> = {}, itemOver: Record<string, unknown> = {}) {
  return {
    item: { id: 'tpl-melox', version: 2, kind: 'template', state: 'in_review', sectorId: 'veterinaria', parentId: null, order: 1, title: 'Meloxicam SC en perro', data: { exerciseTypeId: 'T1', levels: defaultLevels() }, authorId: 'acc-otra', fingerprint: 'huella-1', validations: 0, validatedUntil: null, updatedAt: '', createdAt: '', linkedInquiry: null, ...itemOver },
    authorName: 'M. Ortega', sample: Array.from({ length: 20 }, (_, i) => variant(i, ((10 + i) * 0.04).toFixed(2).replace(/\.?0+$/, ''))),
    extremes: [variant(90, '0.2'), variant(91, '1.6')], comments: [], reviews: [], changesDuringReview: [], checklist: CHECKLIST, requiredValidations: 1,
    canValidate: true, canComment: true, reasonCannotValidate: null, ...over,
  };
}

async function checkAll(user: ReturnType<typeof userEvent.setup>, except?: string) {
  for (const c of CHECKLIST) if (c.label !== except) await user.click(screen.getByLabelText(c.label));
}

describe('B15 · bandeja de revisión', () => {
  it('Validación caducada: la plantilla vuelve a la bandeja de revisión y aparece en las alertas del panel', async () => {
    const expired = { id: 'tpl-bupi', version: 5, kind: 'template', state: 'in_review', sectorId: 'anestesia', title: 'Bupivacaína · volumen máximo', data: { exerciseTypeId: 'T1' }, validatedUntil: '2026-10-01T00:00:00Z', authorName: 'J. Rivas', mySector: true, ownContent: false, daysInReview: 0, modifiedDuringReview: false };
    mockApi({
      'GET /v1/admin/reviews/inbox': { items: [expired], checklist: CHECKLIST },
      'GET /v1/admin/dashboard': { role: 'reviewer', empty: false, onboarding: null, myWork: { drafts: [], pendingReviews: [{ id: 'tpl-bupi', title: 'Bupivacaína · volumen máximo', kind: 'template', sectorId: 'anestesia', exerciseTypeId: 'T1', since: new Date().toISOString() }], changesRequested: [] }, alerts: [{ severity: 'media', itemId: 'tpl-bupi', title: 'Bupivacaína · volumen máximo', reason: 'Validación caducada: vuelve a revisión' }], expiredNow: 1, catalog: [], activity: null, lastRelease: null, inquiriesOpen: 0, updatedAt: new Date().toISOString() },
    });
    const { unmount } = renderApp('/revision', 'reviewer', { sectors: ['anestesia'] });
    const row = await screen.findByRole('row', { name: /Bupivacaína · volumen máximo/ });
    expect(row).toHaveTextContent('Validación caducada');
    expect(within(row).getByText('Caducado')).toBeInTheDocument();
    unmount();
    renderApp('/', 'reviewer', { sectors: ['anestesia'] });
    const alerts = await screen.findByRole('region', { name: 'Alertas de calidad' });
    expect(within(alerts).getByRole('row', { name: /Bupivacaína/ })).toHaveTextContent('Validación caducada: vuelve a revisión');
  });

  it('el revisor ve primero sus sectores y puede ver todos', async () => {
    const user = userEvent.setup();
    const base = { version: 1, kind: 'template', state: 'in_review', data: { exerciseTypeId: 'T1' }, validatedUntil: null, ownContent: false, modifiedDuringReview: false };
    mockApi({ 'GET /v1/admin/reviews/inbox': { items: [{ ...base, id: 'a', title: 'Heparina', sectorId: 'enfermeria', authorName: 'L. Sanz', mySector: true, daysInReview: 3 }, { ...base, id: 'b', title: 'Lidocaína en gato', sectorId: 'veterinaria', authorName: 'M. Ortega', mySector: false, daysInReview: 5 }], checklist: CHECKLIST } });
    renderApp('/revision', 'reviewer', { sectors: ['comun', 'enfermeria'] });
    expect(await screen.findByText(/Tus sectores acreditados:/)).toHaveTextContent('Enfermería');
    expect(screen.getByRole('row', { name: /Heparina/ })).toBeInTheDocument();
    expect(screen.queryByRole('row', { name: /Lidocaína/ })).not.toBeInTheDocument();
    await user.selectOptions(screen.getByLabelText('Sector'), 'all');
    expect(screen.getByRole('row', { name: /Lidocaína/ })).toHaveTextContent('Solo comentar');
  });
});

describe('B16 · ficha de revisión', () => {
  it('Muestra de variantes: ve 20 variantes al azar, las de valores extremos y el recálculo independiente junto a cada respuesta', async () => {
    mockApi({ 'GET /v1/admin/reviews/tpl-melox': sheet() });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    const table = await screen.findByRole('table', { name: 'Variantes de muestra' });
    const rows = within(table).getAllByTestId('muestra');
    expect(rows).toHaveLength(22);
    expect(within(table).getByText('Extremo · mínimo')).toBeInTheDocument();
    expect(within(table).getByText('Extremo · máximo')).toBeInTheDocument();
    expect(within(table).getAllByText('Coincide')).toHaveLength(20);
    for (const r of rows) expect(within(r).getByText((_, el) => el?.getAttribute('data-col') === 'recalculo').textContent).toMatch(/ ml$/);
    expect(screen.getByRole('button', { name: 'Otras 20' })).toBeInTheDocument();
  });

  it('Lista incompleta: con un punto sin marcar la validación no se registra', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/reviews/tpl-melox': sheet() });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    await screen.findByText('Lista de comprobación · 0 de 8');
    await checkAll(user, 'Texto para voz correcto');
    expect(screen.getByText('Lista de comprobación · 7 de 8')).toBeInTheDocument();
    const validate = screen.getByRole('button', { name: 'Validar' });
    expect(validate).toBeDisabled();
    await user.click(validate);
    expect(api.calls.some((c) => c.path.endsWith('/decision'))).toBe(false);
  });

  it('valida con la lista completa enviando la huella de la versión', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/reviews/tpl-melox': sheet(), 'POST /v1/admin/reviews/tpl-melox/decision': { state: 'validated', validations: 1 } });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    await screen.findByText('Lista de comprobación · 0 de 8');
    await checkAll(user);
    await user.click(screen.getByRole('button', { name: 'Validar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/reviews/tpl-melox/decision')).toBeTruthy());
    const body = api.last('POST', '/v1/admin/reviews/tpl-melox/decision')!.body;
    expect(body.decision).toBe('validate');
    expect(body.fingerprint).toBe('huella-1');
    expect(Object.values(body.checklist).filter(Boolean)).toHaveLength(8);
    expect(await screen.findByText(/Validado\. La validación guarda revisor, acreditación, fecha y huella/)).toBeInTheDocument();
  });

  it('Autor que intenta validar lo suyo: la acción «Validar» no está disponible', async () => {
    mockApi({ 'GET /v1/admin/reviews/tpl-melox': sheet({ canValidate: false, reasonCannotValidate: 'Nadie valida contenido propio' }, { authorId: 'acc-reviewer' }) });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    expect(await screen.findByText('Nadie valida contenido propio')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Validar' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('Pauta plausible')).toBeDisabled();
  });

  it('Revisor sin acreditación en el sector: puede comentar y no puede validar', async () => {
    const user = userEvent.setup();
    let comments: unknown[] = [];
    const api = mockApi({
      'GET /v1/admin/reviews/tpl-melox': () => sheet({ canValidate: false, canComment: true, reasonCannotValidate: 'No estás acreditado en este sector: puedes comentar, no validar', comments }),
      'POST /v1/admin/reviews/tpl-melox/comments': ({ body }) => { comments = [{ id: 'c1', author_name: 'Revisor de enfermería', anchor: null, body: body.body, created_at: new Date().toISOString() }]; return { comment: comments[0] }; },
    });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['enfermeria'] });
    expect(await screen.findByText('No estás acreditado en este sector: puedes comentar, no validar')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Validar' })).not.toBeInTheDocument();
    await user.type(screen.getByLabelText('Añade un comentario'), 'La subcutánea en gato merece una nota.');
    await user.click(screen.getByRole('button', { name: 'Comentar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/reviews/tpl-melox/comments')!.body).toEqual({ body: 'La subcutánea en gato merece una nota.' }));
    expect(await screen.findByRole('list', { name: 'Comentarios' })).toHaveTextContent('La subcutánea en gato merece una nota.');
  });

  it('Sector con doble revisión: con una sola validación la plantilla sigue en revisión hasta la segunda', async () => {
    const user = userEvent.setup();
    let validated = false;
    mockApi({
      'GET /v1/admin/reviews/tpl-melox': () => sheet({ requiredValidations: 2 }, { sectorId: 'pediatria', state: 'in_review', validations: validated ? 1 : 0 }),
      'POST /v1/admin/reviews/tpl-melox/decision': () => { validated = true; return { state: 'in_review', validations: 1 }; },
    });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['pediatria'] });
    expect(await screen.findByText(/Este sector exige dos revisores: 0 de 2/)).toBeInTheDocument();
    await checkAll(user);
    await user.click(screen.getByRole('button', { name: 'Validar' }));
    expect(await screen.findByText('Validación registrada (1 de 2). Sigue en revisión hasta la segunda validación.')).toBeInTheDocument();
    expect(await screen.findByText(/Este sector exige dos revisores: 1 de 2/)).toBeInTheDocument();
    expect(screen.getAllByText('En revisión').length).toBeGreaterThan(0);
  });

  it('Contenido modificado durante la revisión: el revisor ve las diferencias y la lista de comprobación se reinicia', async () => {
    const user = userEvent.setup();
    let modified = false;
    mockApi({
      'GET /v1/admin/reviews/tpl-melox': () => (modified
        ? sheet({ changesDuringReview: [{ path: 'formula', before: 'caso.dosis × peso', after: 'caso.dosis × peso ÷ caso.conc' }] }, { fingerprint: 'huella-2' })
        : sheet()),
      'POST /v1/admin/reviews/tpl-melox/decision': () => { modified = true; throw new HttpError(409, 'modified_during_review', 'El autor ha modificado el contenido durante la revisión: revisa las diferencias; la lista de comprobación se reinicia'); },
    });
    renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    await screen.findByText('Lista de comprobación · 0 de 8');
    await checkAll(user);
    expect(screen.getByText('Lista de comprobación · 8 de 8')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Validar' }));
    const diff = await screen.findByRole('region', { name: 'Diferencias durante la revisión' });
    expect(diff).toHaveTextContent('formula');
    expect(diff).toHaveTextContent('caso.dosis × peso ÷ caso.conc');
    expect(screen.getByText('Lista de comprobación · 0 de 8')).toBeInTheDocument();
    expect(screen.getByLabelText('Pauta plausible')).not.toBeChecked();
  });

  it('Cambios solicitados: el contenido vuelve al autor en estado «cambios solicitados» con el comentario visible', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'GET /v1/admin/reviews/tpl-melox': sheet(), 'POST /v1/admin/reviews/tpl-melox/decision': { state: 'changes_requested', validations: 0 } });
    const { unmount } = renderApp('/revision/tpl-melox', 'reviewer', { sectors: ['veterinaria'] });
    await user.type(await screen.findByLabelText('Comentario de la decisión'), 'Revisa la concentración del gato');
    await user.click(screen.getByRole('button', { name: 'Solicitar cambios' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/reviews/tpl-melox/decision')!.body).toMatchObject({ decision: 'request_changes', comment: 'Revisa la concentración del gato' }));
    unmount();
    // La autora abre su plantilla y ve el estado y el comentario.
    const tplItem = { ...sheet().item, state: 'changes_requested', authorId: 'acc-author', data: { id: 'tpl-melox', version: 2, name: 'Meloxicam SC en perro', sectorId: 'veterinaria', skillId: 'H4', exerciseTypeId: 'T1', variables: [], statement: '', question: '', formula: '', answerUnit: 'ml', unitChoices: ['ml'], equivalents: [], rounding: { mode: 'none' }, tolerance: { kind: 'exact' }, constraints: { conditions: [] }, predictedErrors: [], steps: [], plausibility: '', levels: defaultLevels(), variantsPerLevel: 20 } };
    mockApi({
      'GET /v1/admin/items/tpl-melox': { item: tplItem, versions: [tplItem], reviews: [{ id: 'r1', item_version: 2, decision: 'request_changes', reviewer_name: 'Revisora de veterinaria', comment: 'Revisa la concentración del gato', created_at: '' }], comments: [], canEdit: true, canValidate: false },
      'GET /v1/admin/structure': { tree: [], itinerariesWithoutSector: [] }, 'GET /v1/admin/exercise-types': { items: [] },
    });
    renderApp('/plantillas/tpl-melox', 'author');
    expect((await screen.findAllByText('Cambios solicitados', { selector: '.chip' })).length).toBeGreaterThan(0);
    expect(screen.getByText(/Cambios solicitados por Revisora de veterinaria:/).parentElement).toHaveTextContent('«Revisa la concentración del gato»');
  });
});
