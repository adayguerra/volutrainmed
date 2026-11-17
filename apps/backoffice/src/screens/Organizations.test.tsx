import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { mockApi, renderApp, type Call } from '../test/helpers';

const ORG = { id: 'org-1', name: 'Facultad de demostración', type: 'universidad', seats: 150, seatsUsed: 120, valid_from: '2026-09-01', valid_to: '2027-08-31', nominal: false, removes_ads: true, invite_code: 'FACDEMO1', domains: ['facultad.example'] };
const GROUPS = [{ id: 'g1', name: 'Enfermería · 2.º curso', invite_code: 'G1CODE', itineraries: ['it-fundamentos'], members: 42 }, { id: 'g2', name: 'Seminario', invite_code: 'G2CODE', itineraries: [], members: 3 }];

function routes(extra: Record<string, object> = {}) {
  return {
    'GET /v1/admin/orgs': { items: [ORG] },
    'GET /v1/admin/orgs/org-1': { organization: ORG, groups: GROUPS, admins: [{ id: 'a', name: 'Administración de la Facultad', email: 'organizacion@volutrainmed.test' }], invites: [], privateLeagues: [] },
    'GET /v1/admin/structure': { tree: [{ id: 'comun', title: 'Común', children: [{ id: 'it-fundamentos', title: 'Fundamentos' }] }] },
    'GET /v1/admin/orgs/org-1/report': ({ query }: Call) => (query.get('groupId') === 'g2'
      ? { insufficient: true, activeMembers: 3, message: 'El grupo tiene menos de 5 miembros activos: no se muestran datos agregados para que no puedan atribuirse a personas concretas' }
      : { insufficient: false, activeMembers: 38, members: 42, completionLessons: 312, accuracy: 88.4, skillsMastered: ['H1', 'H2'] }),
    ...extra,
  };
}

describe('B20 · organizaciones', () => {
  it('Informe de grupo: ve la finalización, la precisión media y las habilidades dominadas del grupo, sin nombres', async () => {
    const user = userEvent.setup();
    mockApi(routes());
    renderApp('/organizaciones', 'org_admin');
    const groups = await screen.findByRole('table', { name: 'Grupos' });
    await user.click(within(within(groups).getByRole('row', { name: /Enfermería · 2\.º curso/ })).getByRole('button', { name: 'Ver informe' }));
    const report = await screen.findByRole('region', { name: 'Informe del grupo Enfermería · 2.º curso' });
    await waitFor(() => expect(within(report).getByTestId('finalizacion')).toHaveTextContent('312'));
    expect(within(report).getByTestId('precision')).toHaveTextContent('88,4 %');
    expect(within(report).getByTestId('habilidades')).toHaveTextContent('H1, H2');
    expect(within(report).getByText('Solo datos agregados del grupo, sin nombres.')).toBeInTheDocument();
    expect(within(report).queryByRole('table')).not.toBeInTheDocument();
  });

  it('Grupo pequeño: con menos de 5 miembros activos el informe no muestra datos agregados', async () => {
    const user = userEvent.setup();
    mockApi(routes());
    renderApp('/organizaciones', 'org_admin');
    const groups = await screen.findByRole('table', { name: 'Grupos' });
    await user.click(within(within(groups).getByRole('row', { name: /Seminario/ })).getByRole('button', { name: 'Ver informe' }));
    const report = await screen.findByRole('region', { name: 'Informe del grupo Seminario' });
    expect(await within(report).findByText(/menos de 5 miembros activos: no se muestran datos agregados/)).toBeInTheDocument();
    expect(within(report).queryByTestId('precision')).not.toBeInTheDocument();
  });

  it('Invitación masiva: con 120 correos, 3 mal escritos, se envían 117 invitaciones y se listan las 3 filas con error', async () => {
    const user = userEvent.setup();
    const api = mockApi(routes({
      'POST /v1/admin/orgs/org-1/invites': ({ body }: Call) => {
        const invalid: { row: number; value: string }[] = [];
        let sent = 0;
        (body.emails as string[]).forEach((e, i) => { if (/^[^@\s]+@[^@\s]+\.[a-z]{2,}$/.test(e.toLowerCase())) sent++; else invalid.push({ row: i + 1, value: e }); });
        return { sent, invalid };
      },
    }));
    renderApp('/organizaciones', 'org_admin');
    const emails = Array.from({ length: 120 }, (_, i) => (i === 9 ? 'alumna10@facultad' : i === 49 ? 'alumno50facultad.example' : i === 99 ? 'alumna 100@facultad.example' : `estudiante${i + 1}@facultad.example`));
    const file = new File([`correo\n${emails.join('\n')}`], 'promocion.csv', { type: 'text/csv' });
    await user.selectOptions(await screen.findByLabelText('Grupo de destino'), 'g1');
    await user.upload(screen.getByLabelText(/Archivo de correos/), file);
    await waitFor(() => expect(api.last('POST', '/v1/admin/orgs/org-1/invites')).toBeTruthy());
    expect(api.last('POST', '/v1/admin/orgs/org-1/invites')!.body.emails).toHaveLength(120);
    expect(api.last('POST', '/v1/admin/orgs/org-1/invites')!.body.groupId).toBe('g1');
    expect(await screen.findByText('Se han enviado 117 invitaciones.')).toBeInTheDocument();
    const errors = screen.getByRole('list', { name: 'Filas con error' });
    expect(within(errors).getAllByRole('listitem').map((li) => li.textContent)).toEqual(['Fila 10: alumna10@facultad', 'Fila 50: alumno50facultad.example', 'Fila 100: alumna 100@facultad.example']);
  });

  it('asigna itinerarios a un grupo y crea una liga privada', async () => {
    const user = userEvent.setup();
    const api = mockApi(routes({ 'PATCH /v1/admin/orgs/org-1/groups/g2': { group: {} }, 'POST /v1/admin/orgs/org-1/private-leagues': { league: {} } }));
    renderApp('/organizaciones', 'org_admin');
    await user.selectOptions(await screen.findByLabelText('Itinerarios del grupo Seminario'), 'it-fundamentos');
    await waitFor(() => expect(api.last('PATCH', '/v1/admin/orgs/org-1/groups/g2')!.body).toEqual({ itineraries: ['it-fundamentos'] }));
    await user.type(screen.getByLabelText('Nombre de la liga'), 'Promoción 2026');
    await user.selectOptions(screen.getByLabelText('Grupo'), 'g1');
    await user.click(screen.getByRole('button', { name: 'Crear liga privada' }));
    await waitFor(() => expect(api.last('POST', '/v1/admin/orgs/org-1/private-leagues')!.body).toEqual({ name: 'Promoción 2026', groupId: 'g1' }));
  });
});
