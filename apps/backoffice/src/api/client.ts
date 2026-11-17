/**
 * Cliente de la API del back office. La base es inyectable para que lo comparta
 * la aplicación (VITE_API_BASE) y el guion de extremo a extremo (e2e/).
 */

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

export interface ApiOptions {
  base: string;
  getToken?: () => string | null;
  onUnauthorized?: () => void;
  fetchImpl?: typeof fetch;
}

export type Query = Record<string, string | number | boolean | null | undefined>;

export function qs(q?: Query): string {
  if (!q) return '';
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(q)) if (v !== undefined && v !== null && v !== '') p.set(k, String(v));
  const s = p.toString();
  return s ? `?${s}` : '';
}

export function createApi(opts: ApiOptions) {
  const base = opts.base.replace(/\/$/, '');
  async function request<T>(method: string, path: string, body?: unknown, raw = false): Promise<T> {
    const headers: Record<string, string> = {};
    const token = opts.getToken?.();
    if (token) headers.Authorization = `Bearer ${token}`;
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const f = opts.fetchImpl ?? globalThis.fetch;
    let res: Response;
    try {
      res = await f(`${base}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
    } catch {
      throw new ApiError(0, 'network', 'No hay conexión con la API. Comprueba que el servidor está en marcha');
    }
    if (raw) {
      if (!res.ok) throw new ApiError(res.status, 'http_error', `Error ${res.status}`);
      return (await res.text()) as unknown as T;
    }
    const text = await res.text();
    let data: unknown = null;
    if (text) {
      try { data = JSON.parse(text); } catch { data = text; }
    }
    if (!res.ok) {
      const err = (data as { error?: { code?: string; message?: string } } | null)?.error;
      if (res.status === 401 && opts.onUnauthorized && !path.startsWith('/v1/admin/auth/')) opts.onUnauthorized();
      throw new ApiError(res.status, err?.code ?? 'http_error', err?.message ?? `Error ${res.status}`);
    }
    return data as T;
  }
  return {
    base,
    get: <T>(path: string, q?: Query) => request<T>('GET', `${path}${qs(q)}`),
    post: <T>(path: string, body: unknown = {}) => request<T>('POST', path, body),
    put: <T>(path: string, body: unknown = {}) => request<T>('PUT', path, body),
    patch: <T>(path: string, body: unknown = {}) => request<T>('PATCH', path, body),
    text: (path: string, q?: Query) => request<string>('GET', `${path}${qs(q)}`, undefined, true),
  };
}

export type Api = ReturnType<typeof createApi>;

export const DEFAULT_API_BASE = 'http://localhost:8787';
