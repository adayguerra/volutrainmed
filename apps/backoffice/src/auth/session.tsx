/** Sesión del back office: token con doble factor (12 h) y cuenta. */
import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { createApi, DEFAULT_API_BASE, type Api } from '../api/client';
import type { Account } from '../api/types';

const KEY = 'vtm.bo.session';

interface Stored { token: string; account: Account }

function load(): Stored | null {
  try {
    const raw = window.localStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Stored) : null;
  } catch {
    return null;
  }
}

function save(s: Stored | null) {
  try {
    if (s) window.localStorage.setItem(KEY, JSON.stringify(s));
    else window.localStorage.removeItem(KEY);
  } catch {
    /* almacenamiento no disponible: la sesión dura lo que la pestaña */
  }
}

export function apiBase(): string {
  return (import.meta.env.VITE_API_BASE as string | undefined) || DEFAULT_API_BASE;
}

interface SessionValue {
  account: Account | null;
  token: string | null;
  api: Api;
  signIn: (token: string, account: Account) => void;
  signOut: () => void;
}

const Ctx = createContext<SessionValue | null>(null);

export function SessionProvider({ children, base, initial }: { children: ReactNode; base?: string; initial?: Stored | null }) {
  const [session, setSession] = useState<Stored | null>(() => (initial !== undefined ? initial : load()));
  const signOut = useCallback(() => { save(null); setSession(null); }, []);
  const signIn = useCallback((token: string, account: Account) => { const s = { token, account }; save(s); setSession(s); }, []);
  const tokenRef = session?.token ?? null;
  const api = useMemo(() => createApi({ base: base ?? apiBase(), getToken: () => tokenRef, onUnauthorized: signOut }), [base, tokenRef, signOut]);
  const value = useMemo(() => ({ account: session?.account ?? null, token: tokenRef, api, signIn, signOut }), [session, tokenRef, api, signIn, signOut]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useSession(): SessionValue {
  const v = useContext(Ctx);
  if (!v) throw new Error('useSession fuera de SessionProvider');
  return v;
}

export function useApi(): Api {
  return useSession().api;
}
