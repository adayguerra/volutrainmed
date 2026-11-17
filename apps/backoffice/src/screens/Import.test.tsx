import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';

const COLUMNS = [
  { key: 'enunciado', label: 'Enunciado', required: true }, { key: 'pregunta', label: 'Pregunta', required: true }, { key: 'respuesta', label: 'Respuesta', required: true },
  { key: 'unidad', label: 'Unidad de la respuesta', required: true }, { key: 'habilidad', label: 'Habilidad (H1–H12)', required: true }, { key: 'sector', label: 'Sector', required: true },
  { key: 'nivel', label: 'Nivel (1–5)', required: true }, { key: 'explicacion', label: 'Explicación (pasos separados por |)', required: true },
];

/** Réplica de la validación de la API para la falta de unidad (mismo texto que services/api). */
function validateLike({ body }: Call) {
  const mapped = (body.rows as Record<string, string>[]).map((r) => (body.mapping ? Object.fromEntries(Object.entries(body.mapping as Record<string, string>).map(([c, k]) => [k, r[c] ?? ''])) : r));
  const rows = mapped.map((r, i) => {
    const errors = COLUMNS.filter((c) => c.required && !String(r[c.key] ?? '').trim()).map((c) => `Fila ${i + 1}: falta ${c.key === 'unidad' ? 'la unidad de la respuesta' : c.label.toLowerCase()}`);
    return { row: i + 1, ok: !errors.length, errors, data: r };
  });
  return { total: rows.length, ok: rows.filter((r) => r.ok).length, errors: rows.filter((r) => !r.ok).length, rows, columns: COLUMNS };
}

function csv(n: number, withoutUnit: (i: number) => boolean) {
  const head = 'enunciado;pregunta;respuesta;unidad;habilidad;sector;nivel;explicacion';
  const lines = Array.from({ length: n }, (_, i) => `Necesitas ${i + 10} mg con 5 mg/ml.;¿Qué volumen cargas?;${(i + 10) / 5};${withoutUnit(i + 1) ? '' : 'ml'};H4;comun;2;mg ÷ mg/ml`);
  return [head, ...lines].join('\n');
}

describe('B13–B14 · importación masiva', () => {
  it('Fila con error: muestra «Fila 14: falta la unidad de la respuesta» y permite corregirla en la propia tabla', async () => {
    const user = userEvent.setup();
    const api = mockApi({ 'POST /v1/admin/import/validate': validateLike });
    renderApp('/importar', 'author');
    const file = new File([csv(20, (r) => r === 14)], 'preguntas_t1.csv', { type: 'text/csv' });
    await user.upload(await screen.findByLabelText(/Subir el archivo/), file);
    const mapTable = await screen.findByRole('table', { name: 'Emparejar columnas' });
    await waitFor(() => expect(within(mapTable).getByLabelText('Campo para la columna unidad')).toHaveValue('unidad'));
    await user.click(screen.getByRole('button', { name: 'Validar filas' }));
    const row14 = await screen.findByTestId('fila-14');
    expect(row14).toHaveTextContent('Fila 14: falta la unidad de la respuesta');
    expect(screen.getByTestId('err-count')).toHaveTextContent('1');
    // Se corrige la celda en la tabla y se revalida al salir.
    await user.type(within(row14).getByLabelText('Fila 14 · Unidad de la respuesta'), 'ml');
    await user.tab();
    await waitFor(() => expect(screen.getByTestId('err-count')).toHaveTextContent('0'));
    expect(api.last('POST', '/v1/admin/import/validate')!.body.rows[13].unidad).toBe('ml');
    expect(screen.getByRole('button', { name: 'Importar 20 como borrador' })).toBeEnabled();
  });

  it('Importación parcial: con 180 filas válidas y 20 con error se crean 180 borradores y se ofrece un informe con las 20 filas rechazadas', async () => {
    const user = userEvent.setup();
    const bad = (r: number) => r % 10 === 0;
    const api = mockApi({
      'POST /v1/admin/import/validate': validateLike,
      'POST /v1/admin/import/commit': (c) => {
        const v = validateLike(c);
        const rejected = v.rows.filter((r) => !r.ok).map((r) => ({ row: r.row, errors: r.errors }));
        return { created: v.ok, ids: v.rows.filter((r) => r.ok).map((r) => `q-imp-${r.row}`), rejected, report: rejected.map((r) => r.errors.join('; ')).join('\n') };
      },
    });
    renderApp('/importar', 'author');
    await user.upload(await screen.findByLabelText(/Subir el archivo/), new File([csv(200, bad)], 'lote.csv', { type: 'text/csv' }));
    await user.click(await screen.findByRole('button', { name: 'Validar filas' }));
    expect(await screen.findByTestId('ok-count')).toHaveTextContent('180');
    expect(screen.getByTestId('err-count')).toHaveTextContent('20');
    await user.click(screen.getByRole('button', { name: 'Importar 180 como borrador' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/import/commit')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/import/commit')!.body.rows).toHaveLength(200);
    expect(await screen.findByText('Se han creado 180 borradores.')).toBeInTheDocument();
    expect(screen.getByText(/20 filas rechazadas: Fila 10 · Fila 20/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Descargar informe de filas rechazadas' })).toBeInTheDocument();
  });
});
