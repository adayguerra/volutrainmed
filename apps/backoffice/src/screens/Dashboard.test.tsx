import { screen, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';
import type { DashboardData } from './Dashboard';

function dash(over: Partial<DashboardData> = {}): DashboardData {
  return {
    role: 'content_admin', empty: false, onboarding: null,
    myWork: { drafts: [], pendingReviews: [], changesRequested: [] },
    alerts: [], expiredNow: 0, catalog: [{ sector_id: 'comun', published: 12, total: 14 }],
    activity: { users: 4812, sessions: 21340, accuracy: 87 }, lastRelease: { number: '2026.11.1', published_at: new Date().toISOString(), rollout_pct: 100 },
    inquiriesOpen: 3, updatedAt: new Date().toISOString(), ...over,
  };
}

describe('B02 · panel de control por rol', () => {
  it('Revisor: ve primero las revisiones pendientes de sus sectores', async () => {
    mockApi({
      'GET /v1/admin/dashboard': dash({
        role: 'reviewer',
        myWork: {
          drafts: [],
          pendingReviews: [
            { id: 'tpl-hep', title: 'Heparina sódica · bolo', kind: 'template', sectorId: 'enfermeria', exerciseTypeId: 'T1', since: new Date(Date.now() - 3 * 86400000).toISOString() },
            { id: 'q-adr', title: 'Adrenalina 1:1000 · concentración', kind: 'question', sectorId: 'comun', exerciseTypeId: 'T2', since: new Date().toISOString() },
          ],
          changesRequested: [{ id: 'tpl-x', title: 'Goteo 60 gotas/ml' }],
        },
      }),
    });
    renderApp('/', 'reviewer');
    const panels = await screen.findAllByRole('region');
    // El primer bloque de trabajo es el de revisiones de sus sectores.
    expect(panels[0]).toHaveAttribute('data-testid', 'panel-revisiones');
    expect(within(panels[0]!).getByRole('heading')).toHaveTextContent('Revisiones pendientes de tus sectores');
    expect(within(panels[0]!).getByRole('link', { name: 'Heparina sódica · bolo' })).toHaveAttribute('href', '/revision/tpl-hep');
    expect(screen.queryByTestId('panel-borradores')).not.toBeInTheDocument();
  });

  it('el autor ve primero sus borradores', async () => {
    mockApi({ 'GET /v1/admin/dashboard': dash({ role: 'author', myWork: { drafts: [{ id: 'tpl-a', title: 'Lidocaína en gato', state: 'draft', kind: 'template', updatedAt: new Date().toISOString() }], pendingReviews: [], changesRequested: [] } }) });
    renderApp('/', 'author');
    const panels = await screen.findAllByRole('region');
    expect(panels[0]).toHaveAttribute('data-testid', 'panel-borradores');
  });

  it('Instalación nueva: el panel muestra una guía de cinco pasos: sector, itinerario, plantilla, revisión y publicación', async () => {
    mockApi({
      'GET /v1/admin/dashboard': dash({
        empty: true, lastRelease: null,
        onboarding: [
          { step: 1, title: 'Crea el primer sector', done: true },
          { step: 2, title: 'Añade un itinerario', done: false },
          { step: 3, title: 'Escribe una plantilla', done: false },
          { step: 4, title: 'Envíala a revisión', done: false },
          { step: 5, title: 'Publica la primera versión', done: false },
        ],
      }),
    });
    renderApp('/', 'content_admin');
    expect(await screen.findByRole('heading', { name: 'Te damos la bienvenida' })).toBeInTheDocument();
    const guide = screen.getByRole('list', { name: 'Guía de cinco pasos' });
    const steps = within(guide).getAllByRole('listitem');
    expect(steps).toHaveLength(5);
    expect(steps.map((s) => within(s).getByText(/^(Crea|Añade|Escribe|Envíala|Publica)/).textContent)).toEqual([
      'Crea el primer sector', 'Añade un itinerario', 'Escribe una plantilla', 'Envíala a revisión', 'Publica la primera versión',
    ]);
    expect(screen.getByText('Primeros pasos · 1 de 5')).toBeInTheDocument();
    expect(within(steps[1]!).getByRole('link', { name: 'Empezar' })).toHaveAttribute('href', '/estructura');
  });

  it('Plantilla demasiado difícil: aparece en las alertas del panel de control', async () => {
    mockApi({
      'GET /v1/admin/dashboard': dash({
        alerts: [{ severity: 'alta', itemId: 'tpl-nora', title: 'Noradrenalina en ml/h', reason: 'Acierto al primer intento del 35 %', sectorId: 'anestesia', exerciseTypeId: 'T1' }],
      }),
    });
    renderApp('/', 'content_admin');
    const alerts = await screen.findByRole('region', { name: 'Alertas de calidad' });
    const row = within(alerts).getByRole('row', { name: /Noradrenalina en ml\/h/ });
    expect(row).toHaveTextContent('Alta');
    expect(row).toHaveTextContent('Acierto al primer intento del 35 %');
    expect(within(row).getByRole('link', { name: 'Noradrenalina en ml/h' })).toHaveAttribute('href', '/analitica/tpl-nora');
  });

  it('el soporte no ve alertas de calidad ni el catálogo', async () => {
    mockApi({ 'GET /v1/admin/dashboard': dash({ role: 'support' }) });
    renderApp('/', 'support');
    expect(await screen.findByText('Actividad · 7 días')).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Alertas de calidad' })).not.toBeInTheDocument();
    expect(screen.queryByText('Estado del catálogo')).not.toBeInTheDocument();
  });
});
