import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { authenticator } from 'otplib';
import { describe, expect, it } from 'vitest';
import { account, HttpError, mockApi, renderApp } from '../test/helpers';

// Ventana de ±1 paso (como la API) para que la prueba no falle al cruzar un límite de 30 s.
authenticator.options = { window: 1 };
const SECRET = authenticator.generateSecret();

describe('B01 · acceso con doble factor obligatorio', () => {
  it('Primer acceso: debe configurar el segundo factor antes de acceder a ninguna sección', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'POST /v1/admin/auth/login': { challenge: 'ch-1', mfaSetupRequired: true, otpauthUrl: `otpauth://totp/VolutrainMed:nueva?secret=${SECRET}&issuer=VolutrainMed`, secret: SECRET },
      'POST /v1/admin/auth/mfa': ({ body }) => {
        if (!authenticator.check(body.code, SECRET)) throw new HttpError(400, 'invalid_code', 'El código no es correcto');
        return { token: 'tkn', account: account('author', { name: 'Autora nueva' }), recoveryCodes: ['A1B2C3D4', 'E5F6A7B8', '11112222', '33334444', '55556666', '77778888', '9999AAAA', 'BBBBCCCC'] };
      },
      'GET /v1/admin/dashboard': { role: 'author', empty: false, onboarding: null, myWork: { drafts: [], pendingReviews: [], changesRequested: [] }, alerts: [], expiredNow: 0, catalog: [], activity: null, lastRelease: null, inquiriesOpen: 0, updatedAt: new Date().toISOString() },
    });
    // Sin sesión, cualquier sección redirige al acceso.
    renderApp('/biblioteca', null);
    await user.type(await screen.findByLabelText('Correo'), 'nueva@volutrainmed.test');
    await user.type(screen.getByLabelText('Contraseña'), 'VolutrainMed-2026!');
    await user.click(screen.getByRole('button', { name: 'Continuar' }));

    // Paso obligatorio de alta del segundo factor: ninguna sección es accesible todavía.
    expect(await screen.findByRole('heading', { name: 'Configura el segundo factor' })).toBeInTheDocument();
    expect(screen.queryByRole('navigation', { name: 'Secciones' })).not.toBeInTheDocument();
    expect(screen.getByTestId('totp-secret')).toHaveTextContent(SECRET);

    // Un código erróneo no da acceso.
    await user.type(screen.getByLabelText('Código de seis cifras'), '000000');
    await user.click(screen.getByRole('button', { name: 'Activar y entrar' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('El código no es correcto');
    expect(screen.queryByRole('navigation', { name: 'Secciones' })).not.toBeInTheDocument();

    // Con el código TOTP correcto se activa el factor y se muestran los códigos de recuperación.
    await user.clear(screen.getByLabelText('Código de seis cifras'));
    await user.type(screen.getByLabelText('Código de seis cifras'), authenticator.generate(SECRET));
    await user.click(screen.getByRole('button', { name: 'Activar y entrar' }));
    const codes = await screen.findByRole('list', { name: 'Códigos de recuperación' });
    expect(within(codes).getAllByRole('listitem')).toHaveLength(8);
    expect(api.last('POST', '/v1/admin/auth/mfa')!.body).toMatchObject({ challenge: 'ch-1' });
    expect(screen.queryByRole('navigation', { name: 'Secciones' })).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: /He guardado los códigos/ }));
    expect(await screen.findByRole('navigation', { name: 'Secciones' })).toBeInTheDocument();
  });

  it('una cuenta con el factor ya activo verifica con la aplicación y entra', async () => {
    const user = userEvent.setup();
    mockApi({
      'POST /v1/admin/auth/login': { challenge: 'ch-2', mfaSetupRequired: false },
      'POST /v1/admin/auth/mfa': ({ body }) => ({ token: 'tkn', account: account('reviewer'), _code: body.code }),
      'GET /v1/admin/dashboard': new HttpError(500, 'x', 'x'),
    });
    renderApp('/acceso', null);
    await user.type(screen.getByLabelText('Correo'), 'revisor.clinico@volutrainmed.test');
    await user.type(screen.getByLabelText('Contraseña'), 'VolutrainMed-2026!');
    await user.click(screen.getByRole('button', { name: 'Continuar' }));
    expect(await screen.findByRole('heading', { name: 'Verificación en dos pasos' })).toBeInTheDocument();
    await user.type(screen.getByLabelText('Código de verificación'), authenticator.generate(SECRET));
    await user.click(screen.getByRole('button', { name: 'Verificar' }));
    expect(await screen.findByTestId('role-label')).toHaveTextContent('Revisión experta');
  });

  it('permite entrar con un código de recuperación de un solo uso', async () => {
    const user = userEvent.setup();
    const api = mockApi({
      'POST /v1/admin/auth/login': { challenge: 'ch-3', mfaSetupRequired: false },
      'POST /v1/admin/auth/mfa': ({ body }) => {
        if (body.recoveryCode !== 'A1B2C3D4') throw new HttpError(400, 'invalid_code', 'El código de recuperación no es válido');
        return { token: 'tkn', account: account('support') };
      },
    });
    renderApp('/acceso', null);
    await user.type(screen.getByLabelText('Correo'), 'soporte@volutrainmed.test');
    await user.type(screen.getByLabelText('Contraseña'), 'VolutrainMed-2026!');
    await user.click(screen.getByRole('button', { name: 'Continuar' }));
    await user.click(await screen.findByRole('button', { name: 'Usar un código de recuperación' }));
    await user.type(screen.getByLabelText('Código de recuperación'), 'a1b2c3d4');
    await user.click(screen.getByRole('button', { name: 'Verificar' }));
    await waitFor(() => expect(screen.getByTestId('role-label')).toHaveTextContent('Soporte'));
    expect(api.last('POST', '/v1/admin/auth/mfa')!.body).toEqual({ challenge: 'ch-3', recoveryCode: 'A1B2C3D4' });
  });

  it('muestra el error de credenciales sin avanzar', async () => {
    const user = userEvent.setup();
    mockApi({ 'POST /v1/admin/auth/login': () => { throw new HttpError(401, 'unauthorized', 'Correo o contraseña incorrectos'); } });
    renderApp('/acceso', null);
    await user.type(screen.getByLabelText('Correo'), 'x@volutrainmed.test');
    await user.type(screen.getByLabelText('Contraseña'), 'mala');
    await user.click(screen.getByRole('button', { name: 'Continuar' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Correo o contraseña incorrectos');
  });
});
