import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';
import type { Release } from '../api/types';

function rel(over: Partial<Release> = {}): Release {
  return {
    id: 'r-4', number: '2026.11.4', state: 'preparing', notes: null, rolloutPct: null, minAppVersion: '1.0.0',
    items: [{ id: 'tpl-remi', version: 1, kind: 'template', title: 'Remifentanilo encadenado' }],
    diff: {
      added: [{ id: 'tpl-remi', version: 1, kind: 'template', title: 'Remifentanilo encadenado' }],
      changed: [{ id: 'tpl-hep', version: 3, kind: 'template', title: 'Heparina sódica · bolo' }],
      retired: [{ id: 'tpl-lido', version: 2, kind: 'template', title: 'Lidocaína en infusión · perro' }],
      excluded: [{ id: 'tpl-goteo', version: 3, kind: 'template', title: 'Goteo 60 gotas/ml', reason: 'Con cambios solicitados por el revisor' }],
    },
    checks: null, testCode: null, createdAt: '2026-11-17T09:00:00Z', publishedAt: null, rolledBackReason: null, ...over,
  };
}

const prev: Release = { ...rel(), id: 'r-3', number: '2026.11.3', state: 'published', rolloutPct: 100, publishedAt: '2026-11-15T12:00:00Z', diff: null };
const older: Release = { ...rel(), id: 'r-2', number: '2026.11.2', state: 'superseded', rolloutPct: 100, publishedAt: '2026-11-10T12:00:00Z', diff: null };
const OK_CHECKS = [
  { id: 'double', label: 'Doble cálculo coincidente', ok: true, detail: '1412 variantes recalculadas con el motor independiente' },
  { id: 'collision', label: 'Sin colisiones entre respuesta correcta y errónea previsible', ok: true, detail: 'Ninguna' },
  { id: 'compat', label: 'Versión mínima de la app y dispositivos compatibles', ok: true, detail: '96 % de los dispositivos activos admite la versión 1.0.0' },
];

function routes(extra: Record<string, object> = {}, releases: Release[] = [rel(), prev, older]) {
  return {
    'GET /v1/admin/releases': { items: releases, pending: rel().diff },
    'GET /v1/admin/revocations': { items: [] },
    'GET /v1/admin/releases/compat': { total: 50, compatible: 48, pct: 96 },
    'GET /v1/admin/exercise-types': { items: [] },
    'GET /v1/admin/items': { items: [] },
    ...extra,
  };
}

describe('B17 · versionado y publicación', () => {
  it('Soporte: un usuario de soporte que abre la sección de publicación no tiene acceso', async () => {
    const api = mockApi(routes());
    renderApp('/publicacion', 'support');
    expect(await screen.findByText('No tienes acceso a esta sección')).toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: 'Secciones' });
    expect(within(nav).queryByRole('link', { name: /Publicación/ })).not.toBeInTheDocument();
    expect(within(nav).getByRole('link', { name: /Usuarios/ })).toBeInTheDocument();
    expect(api.calls.some((c) => c.path.startsWith('/v1/admin/releases'))).toBe(false);
  });

  it('Elemento sin validar: aparece atenuado con su motivo y no puede incluirse', async () => {
    mockApi(routes());
    renderApp('/publicacion', 'content_admin');
    const table = await screen.findByRole('table', { name: 'Cambios en esta versión' });
    const excluded = within(table).getByTestId('excluido');
    expect(excluded).toHaveClass('dim');
    expect(excluded).toHaveAttribute('aria-disabled', 'true');
    expect(excluded).toHaveTextContent('Goteo 60 gotas/ml');
    expect(excluded).toHaveTextContent('No se incluye: Con cambios solicitados por el revisor');
    expect(within(excluded).queryByRole('checkbox')).not.toBeInTheDocument();
    expect(within(excluded).queryByRole('link')).not.toBeInTheDocument();
  });

  it('Discrepancia en el doble cálculo: la publicación se bloquea y se enlaza la plantilla afectada', async () => {
    const user = userEvent.setup();
    mockApi(routes({
      'POST /v1/admin/releases/r-4/checks': { checks: [{ id: 'double', label: 'Doble cálculo coincidente', ok: false, detail: 'Discrepancia en tpl-remi.v1.3: 0.96 frente a 0.97', itemId: 'tpl-remi' }, ...OK_CHECKS.slice(1)], summary: { passed: false, failed: 1, total: 3 } },
    }));
    renderApp('/publicacion', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Ejecutar comprobaciones' }));
    const list = await screen.findByRole('list', { name: 'Resultado de las comprobaciones' });
    expect(list).toHaveTextContent('Discrepancia en tpl-remi.v1.3: 0.96 frente a 0.97');
    expect(within(list).getByRole('link', { name: 'Abrir la plantilla afectada' })).toHaveAttribute('href', '/plantillas/tpl-remi');
    expect(screen.getByText(/La publicación está bloqueada: 1 comprobaciones sin superar/)).toBeInTheDocument();
    for (const p of [5, 50, 100]) expect(screen.getByRole('button', { name: `Publicar al ${p} %` })).toBeDisabled();
  });

  it('Comprobaciones superadas: la acción «Publicar» queda disponible', async () => {
    const user = userEvent.setup();
    mockApi(routes({ 'POST /v1/admin/releases/r-4/checks': { checks: OK_CHECKS, summary: { passed: true, failed: 0, total: 3 } } }));
    renderApp('/publicacion', 'content_admin');
    expect(await screen.findByRole('button', { name: 'Publicar al 5 %' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Ejecutar comprobaciones' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Publicar al 5 %' })).toBeEnabled());
    expect(screen.getByRole('button', { name: 'Publicar al 100 %' })).toBeEnabled();
  });

  it('Compatibilidad con la app: muestra el porcentaje de dispositivos activos que la admite antes de publicar', async () => {
    mockApi(routes({ 'GET /v1/admin/releases/compat': { total: 200, compatible: 192, pct: 96 } }, [rel({ minAppVersion: '1.2.0' }), prev]));
    renderApp('/publicacion', 'content_admin');
    const compat = await screen.findByTestId('compat-version');
    await waitFor(() => expect(compat).toHaveTextContent('Versión mínima de la app 1.2.0 · la admite el 96 % de los dispositivos activos (192 de 200)'));
    expect(screen.getByRole('button', { name: 'Publicar al 5 %' })).toBeInTheDocument();
  });

  it('Aviso antes de publicar: muestra qué porcentaje de los dispositivos activos admite el tipo con versión mínima', async () => {
    mockApi(routes({
      'GET /v1/admin/exercise-types': { items: [{ id: 'T8', data: { name: 'Partes enlazadas', minAppVersion: '1.3.0' } }, { id: 'T1', data: { name: 'Numérica con unidad', minAppVersion: '1.0.0' } }] },
      'GET /v1/admin/items': { items: [{ id: 'tpl-remi', kind: 'template', data: { exerciseTypeId: 'T8' } }] },
      'GET /v1/admin/releases/compat': ({ query }: { query: URLSearchParams }) => (query.get('minAppVersion') === '1.3.0' ? { total: 100, compatible: 78, pct: 78 } : { total: 100, compatible: 100, pct: 100 }),
    }));
    renderApp('/publicacion', 'content_admin');
    const warn = await screen.findByRole('list', { name: 'Tipos con versión mínima' });
    expect(warn).toHaveTextContent('Incluye contenido del tipo T8 · Partes enlazadas, que exige la app 1.3.0: lo admite el 78 % de los dispositivos activos');
  });

  it('publica al 5 % escribiendo el nombre de la versión y despliega después al 50 y al 100 %', async () => {
    const user = userEvent.setup();
    let state: Release = rel({ checks: OK_CHECKS });
    const api = mockApi(routes({
      'GET /v1/admin/releases': () => ({ items: [state, prev, older], pending: rel().diff }),
      'POST /v1/admin/releases/r-4/publish': ({ body }: { body: { rolloutPct: number } }) => { state = { ...state, state: 'published', rolloutPct: body.rolloutPct, publishedAt: '2026-11-17T10:00:00Z' }; return { release: state }; },
      'POST /v1/admin/releases/r-4/rollout': ({ body }: { body: { rolloutPct: number } }) => { state = { ...state, rolloutPct: body.rolloutPct }; return { ok: true }; },
    }));
    renderApp('/publicacion', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Publicar al 5 %' }));
    const dialog = screen.getByRole('dialog');
    const confirm = within(dialog).getByRole('button', { name: 'Publicar' });
    expect(confirm).toBeDisabled();
    await user.type(within(dialog).getByLabelText(/Escribe el nombre de la versión/), '2026.11.4');
    await user.click(confirm);
    await waitFor(() => expect(api.last('POST', '/v1/admin/releases/r-4/publish')!.body).toEqual({ confirmName: '2026.11.4', rolloutPct: 5 }));
    expect(await screen.findByTestId('rollout')).toHaveTextContent('5 %');
    expect(screen.getByText(/El resto conserva la versión anterior/)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: '50 %' }));
    await waitFor(() => expect(screen.getByTestId('rollout')).toHaveTextContent('50 %'));
    await user.click(screen.getByRole('button', { name: '100 %' }));
    await waitFor(() => expect(screen.getByTestId('rollout')).toHaveTextContent('100 %'));
    expect(api.calls.filter((c) => c.path.endsWith('/rollout')).map((c) => c.body.rolloutPct)).toEqual([50, 100]);
  });

  it('revierte la versión activa con motivo obligatorio', async () => {
    const user = userEvent.setup();
    const api = mockApi(routes({ 'POST /v1/admin/releases/rollback': { rolledBack: '2026.11.3', active: '2026.11.2' } }, [prev, older]));
    renderApp('/publicacion', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Revertir a 2026.11.2' }));
    const dialog = screen.getByRole('dialog');
    expect(within(dialog).getByRole('button', { name: 'Revertir' })).toBeDisabled();
    await user.type(within(dialog).getByLabelText('Motivo (obligatorio)'), 'Error en la explicación de la heparina');
    await user.click(within(dialog).getByRole('button', { name: 'Revertir' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/releases/rollback')!.body).toEqual({ reason: 'Error en la explicación de la heparina' }));
    expect(await screen.findByText('Revertida 2026.11.3: vuelve a estar activa 2026.11.2')).toBeInTheDocument();
  });

  it('genera el paquete de prueba con su código QR', async () => {
    const user = userEvent.setup();
    mockApi(routes({ 'POST /v1/admin/releases/r-4/test-package': { testCode: 'PV4LRC92', qrPayload: 'volutrainmed://paquete-prueba?codigo=PV4LRC92', checks: OK_CHECKS } }));
    renderApp('/publicacion', 'content_admin');
    await user.click(await screen.findByRole('button', { name: 'Generar paquete de prueba' }));
    expect(await screen.findByTestId('test-code')).toHaveTextContent('PV4LRC92');
    expect(screen.getByText(/ningún usuario recibe este paquete/)).toBeInTheDocument();
  });
});
