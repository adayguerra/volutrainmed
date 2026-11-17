/**
 * Recorrido de humo contra una API real (opcional): cada rol entra con doble
 * factor y abre todas las pantallas que su rol permite; ninguna debe mostrar un
 * error. Solo se ejecuta con BO_SMOKE_API (por ejemplo http://localhost:8788) y
 * reutiliza los secretos TOTP que guarda el guion e2e.
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { cleanup, render, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { authenticator } from 'otplib';
import { describe, expect, it } from 'vitest';
import { AppRoutes } from './App';
import { SessionProvider } from './auth/session';
import { ToastProvider } from './ui/kit';
import { createApi } from './api/client';
import { canAccess } from './auth/permissions';
import { screens } from './screens/registry';
import type { Account, LoginResponse, MfaResponse } from './api/types';

const BASE = process.env.BO_SMOKE_API;
const STATE = join(tmpdir(), `vtm-bo-e2e-${(BASE ?? '').replace(/\W+/g, '_')}.json`);
const EMAILS = ['superadmin', 'contenido', 'autora', 'revisor.clinico', 'analista', 'soporte', 'organizacion'].map((e) => `${e}@volutrainmed.test`);

async function signIn(email: string): Promise<{ token: string; account: Account }> {
  const secrets: Record<string, string> = existsSync(STATE) ? JSON.parse(readFileSync(STATE, 'utf8')) : {};
  const anon = createApi({ base: BASE! });
  const l = await anon.post<LoginResponse>('/v1/admin/auth/login', { email, password: 'VolutrainMed-2026!' });
  const secret = l.secret ?? secrets[email];
  if (!secret) throw new Error(`Sin secreto TOTP para ${email}`);
  const r = await anon.post<MfaResponse>('/v1/admin/auth/mfa', { challenge: l.challenge, code: authenticator.generate(secret) });
  if (l.secret) { secrets[email] = l.secret; writeFileSync(STATE, JSON.stringify(secrets, null, 2)); }
  return { token: r.token, account: r.account };
}

describe.skipIf(!BASE)('humo contra la API real', () => {
  for (const email of EMAILS) {
    it(`todas las pantallas del rol de ${email} cargan sin errores`, async () => {
      const s = await signIn(email);
      const api = createApi({ base: BASE!, getToken: () => s.token });
      const users = await api.get<{ items: { id: string }[] }>('/v1/admin/users').then((r) => r.items).catch(() => []);
      const sample = process.env.BO_SMOKE_ITEM ?? 'tpl-f-mg-ug';
      const ids: Record<string, string> = { id: sample, itemId: sample };
      const paths = ['/', ...screens.filter((x) => canAccess(s.account.role, x.section)).map((x) => x.path)]
        .map((p) => (p.startsWith('/usuarios/:') ? (users[0] ? `/usuarios/${users[0].id}` : null) : p.startsWith('/preguntas/:') ? '/preguntas/q-v-t3-volumen' : p.replace(/:(\w+)/, (_, k: string) => ids[k] ?? 'x')))
        .filter((p): p is string => Boolean(p));
      const failures: string[] = [];
      for (const path of paths) {
        const { container } = render(
          <MemoryRouter initialEntries={[path]}>
            <SessionProvider base={BASE} initial={s}><ToastProvider><AppRoutes /></ToastProvider></SessionProvider>
          </MemoryRouter>,
        );
        try {
          await waitFor(() => expect(container.querySelector('.skeleton')).toBeNull(), { timeout: 15000 });
          await new Promise((r) => setTimeout(r, 300));
          await waitFor(() => expect(container.querySelector('.skeleton')).toBeNull(), { timeout: 15000 });
          const err = container.querySelector('.notice.err[role="alert"], .toast-fixed.err');
          if (err) failures.push(`${path}: ${err.textContent}`);
          if (container.textContent?.includes('No tienes acceso')) failures.push(`${path}: sin acceso`);
          if ((container.querySelector('main')?.textContent ?? '').length < 40) failures.push(`${path}: pantalla vacía`);
        } finally {
          cleanup();
        }
      }
      expect(failures).toEqual([]);
    }, 120000);
  }
});
