import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp } from '../test/helpers';

function detail(over: Record<string, unknown> = {}) {
  return {
    user: { id: 'u-1', email: 'lucia@correo.es', alias: 'lucia_m', sectorId: 'anestesia', status: 'active', plan: 'gratuito', organization: null, lastActivity: null, createdAt: '2026-11-02T10:00:00Z' },
    entitlements: { premium: false }, devices: [{ id: 'd1', platform: 'ios', model: 'iPhone 14', app_version: '1.0.0', content_version: '2026.11.3', last_sync_at: new Date().toISOString() }],
    inquiries: [], grants: [], progress: { attempts: 120, accuracy: 93, active_days: 13, critical: 0, lessonsCompleted: 8 }, organization: null, ...over,
  };
}

describe('B18–B19 · usuarios y acciones de soporte', () => {
  it('lista usuarios con el correo enmascarado', async () => {
    mockApi({ 'GET /v1/admin/users': { items: [detail().user] } });
    renderApp('/usuarios', 'support');
    const row = await screen.findByRole('row', { name: /lucia_m/ });
    expect(row).toHaveTextContent('l•••••@correo.es');
    expect(row).not.toHaveTextContent('lucia@correo.es');
  });

  it('Conceder días de Premium: el usuario recibe el acceso y la acción queda en el registro de auditoría', async () => {
    const user = userEvent.setup();
    let granted = false;
    const api = mockApi({
      'GET /v1/admin/users/u-1': () => (granted ? detail({ entitlements: { premium: true, source: 'grant', expiresAt: '2026-11-24T10:00:00Z' }, grants: [{ days: 7, reason: 'Incidencia con la descarga · VM-2611-0031', starts_at: '', ends_at: '2026-11-24T10:00:00Z' }] }) : detail()),
      'POST /v1/admin/users/u-1/actions': ({ body }) => { granted = body.action === 'grant_premium'; return { entitlements: { premium: true } }; },
    });
    renderApp('/usuarios/u-1', 'support');
    expect(await screen.findByTestId('plan')).toHaveTextContent('Gratis');
    const grant = screen.getByRole('button', { name: 'Conceder 7 días' });
    expect(grant).toBeDisabled();
    await user.type(screen.getByLabelText('Motivo (obligatorio)'), 'Incidencia con la descarga · VM-2611-0031');
    await user.click(grant);
    await waitFor(() => expect(api.last('POST', '/v1/admin/users/u-1/actions')!.body).toEqual({ action: 'grant_premium', days: 7, reason: 'Incidencia con la descarga · VM-2611-0031' }));
    expect(await screen.findByText('Concedidos 7 días de Premium. La acción queda en el registro de auditoría con su motivo.')).toBeInTheDocument();
    await waitFor(() => expect(screen.getByTestId('plan')).toHaveTextContent('Premium'));
    expect(screen.getByRole('list', { name: 'Días concedidos' })).toHaveTextContent('7 días · Incidencia con la descarga · VM-2611-0031');
  });

  it('Supresión de datos: sus datos personales se suprimen o se anonimizan y la acción queda registrada', async () => {
    const user = userEvent.setup();
    let deleted = false;
    const api = mockApi({
      'GET /v1/admin/users/u-1': () => (deleted ? detail({ user: { ...detail().user, email: null, alias: 'anon-48f2', status: 'deleted' }, devices: [] }) : detail()),
      'POST /v1/admin/users/u-1/actions': () => { deleted = true; return { ok: true }; },
    });
    renderApp('/usuarios/u-1', 'support');
    await user.click(await screen.findByRole('button', { name: 'Anonimizar la cuenta' }));
    const dialog = screen.getByRole('dialog', { name: 'Suprimir los datos de la cuenta' });
    await user.type(within(dialog).getByLabelText('Motivo (obligatorio)'), 'Solicitud de eliminación de la cuenta desde la app');
    await user.click(within(dialog).getByRole('button', { name: 'Suprimir y anonimizar' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/users/u-1/actions')!.body).toMatchObject({ action: 'delete', reason: 'Solicitud de eliminación de la cuenta desde la app' }));
    expect(await screen.findByText('Datos personales suprimidos o anonimizados. La acción queda registrada en la auditoría.')).toBeInTheDocument();
    expect(await screen.findByRole('heading', { name: 'anon-48f2' })).toBeInTheDocument();
    expect(screen.getByText('Anonimizada')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Anonimizar la cuenta' })).not.toBeInTheDocument();
  });

  it('la administración de organización consulta pero no ejecuta acciones de soporte', async () => {
    mockApi({ 'GET /v1/admin/users/u-1': detail({ organization: { id: 'org-1', name: 'Facultad de demostración', nominal: true } }) });
    renderApp('/usuarios/u-1', 'org_admin');
    expect(await screen.findByText(/Facultad de demostración \(modo nominal\)/)).toBeInTheDocument();
    expect(screen.queryByRole('region', { name: 'Acciones de soporte' })).not.toBeInTheDocument();
  });

  it('la superadministración cambia el rol de una cuenta del back office', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'GET /v1/admin/accounts': { items: [{ id: 'a1', email: 'autor2@volutrainmed.test', name: 'Pablo Ruiz', role: 'author', roleLabel: 'Autoría', sectors: [], accreditation: null, orgId: null, active: true, mfaEnabled: false }] },
      'PATCH /v1/admin/accounts/a1': { account: {} },
    });
    renderApp('/cuentas', 'superadmin');
    await user.selectOptions(await screen.findByLabelText('Rol de Pablo Ruiz'), 'reviewer');
    await waitFor(() => expect(api.last('PATCH', '/v1/admin/accounts/a1')!.body).toEqual({ role: 'reviewer' }));
    expect(screen.getByRole('row', { name: /Pablo Ruiz/ })).toHaveTextContent('Pendiente');
  });
});
