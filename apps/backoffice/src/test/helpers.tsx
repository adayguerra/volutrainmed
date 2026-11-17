/** Utilidades de prueba: API simulada por rutas y montaje de la aplicación con un rol. */
import { render } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { vi } from 'vitest';
import { AppRoutes } from '../App';
import { SessionProvider } from '../auth/session';
import { ToastProvider } from '../ui/kit';
import type { Account, Role } from '../api/types';
import { ROLE_LABELS } from '../api/types';

export const BASE = 'http://api.prueba';

export interface Call { method: string; path: string; query: URLSearchParams; body: any }
type Handler = (c: Call) => unknown;
export type Routes = Record<string, Handler | object>;

export class HttpError { constructor(public status: number, public code: string, public message: string) {} }

/**
 * Sustituye fetch: las claves son «MÉTODO /ruta» con segmentos «:param».
 * Un manejador puede devolver un objeto o lanzar HttpError.
 */
export function mockApi(routes: Routes) {
  const calls: Call[] = [];
  const compiled = Object.entries(routes).map(([k, h]) => {
    const [method, pattern] = k.split(' ') as [string, string];
    const re = new RegExp(`^${pattern.replace(/:[a-zA-Z]+/g, '[^/]+')}$`);
    return { method, re, h };
  });
  const fn = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    const method = (init?.method ?? 'GET').toUpperCase();
    const body = init?.body ? JSON.parse(String(init.body)) : undefined;
    const call: Call = { method, path: url.pathname, query: url.searchParams, body };
    calls.push(call);
    const r = compiled.find((c) => c.method === method && c.re.test(url.pathname));
    if (!r) return new Response(JSON.stringify({ error: { code: 'not_found', message: `Sin simular: ${method} ${url.pathname}` } }), { status: 404 });
    try {
      const out = typeof r.h === 'function' ? await (r.h as Handler)(call) : r.h;
      if (typeof out === 'string') return new Response(out, { status: 200 });
      return new Response(JSON.stringify(out ?? {}), { status: 200, headers: { 'Content-Type': 'application/json' } });
    } catch (e) {
      if (e instanceof HttpError) return new Response(JSON.stringify({ error: { code: e.code, message: e.message } }), { status: e.status });
      throw e;
    }
  });
  vi.stubGlobal('fetch', fn);
  return { calls, fn, last: (method: string, path: string) => [...calls].reverse().find((c) => c.method === method && c.path === path) };
}

export function account(role: Role, extra: Partial<Account> = {}): Account {
  return {
    id: `acc-${role}`, email: `${role}@volutrainmed.test`, name: `Cuenta ${ROLE_LABELS[role]}`, role, roleLabel: ROLE_LABELS[role],
    sectors: role === 'reviewer' ? ['comun', 'enfermeria'] : [], accreditation: null, orgId: role === 'org_admin' ? 'org-1' : null, active: true, mfaEnabled: true, ...extra,
  };
}

export function renderApp(path: string, role: Role | null, extra: Partial<Account> = {}) {
  const initial = role ? { token: 'tkn', account: account(role, extra) } : null;
  return render(
    <MemoryRouter initialEntries={[path]}>
      <SessionProvider base={BASE} initial={initial}>
        <ToastProvider><AppRoutes /></ToastProvider>
      </SessionProvider>
    </MemoryRouter>,
  );
}
