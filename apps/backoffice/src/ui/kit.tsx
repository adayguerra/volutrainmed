/** Componentes comunes: cabecera de página, paneles, estados, diálogos y avisos. */
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ApiError } from '../api/client';
import { STATE_LABELS } from '../api/types';

export function Icon({ name, fill, size, className }: { name: string; fill?: boolean; size?: number; className?: string }) {
  return <span className={`ms${fill ? ' ms-fill' : ''}${className ? ` ${className}` : ''}`} style={size ? { fontSize: size } : undefined} aria-hidden="true">{name}</span>;
}

export function Page({ title, crumbs, actions, children, chip }: { title: ReactNode; crumbs?: { label: string; to?: string }[]; actions?: ReactNode; children: ReactNode; chip?: ReactNode }) {
  return (
    <>
      <header className="bo-top">
        <div className="col g4 grow" style={{ minWidth: 240 }}>
          {crumbs?.length ? (
            <nav className="crumbs" aria-label="Ruta">
              {crumbs.map((c, i) => (
                <span key={i} className="row g6">
                  {i > 0 && <span aria-hidden="true">›</span>}
                  {c.to ? <Link to={c.to} className="muted" style={{ textDecoration: 'none' }}>{c.label}</Link> : <span>{c.label}</span>}
                </span>
              ))}
            </nav>
          ) : null}
          <div className="row g12 wrap"><h1 className="h1">{title}</h1>{chip}</div>
        </div>
        {actions ? <div className="row g8 wrap">{actions}</div> : null}
      </header>
      <div className="bo-body">{children}</div>
    </>
  );
}

export function Panel({ title, icon, actions, children, className, bodyClass = 'panel-b', id }: { title?: ReactNode; icon?: string; actions?: ReactNode; children: ReactNode; className?: string; bodyClass?: string; id?: string }) {
  return (
    <section className={`panel col${className ? ` ${className}` : ''}`} aria-labelledby={id}>
      {title !== undefined && (
        <div className="panel-h">
          {icon && <Icon name={icon} className="c-primary" />}
          <h2 id={id} className="grow" style={{ font: 'inherit', margin: 0 }}>{title}</h2>
          {actions}
        </div>
      )}
      {/* Una tabla desplazable debe poder recorrerse con el teclado. */}
      <div className={bodyClass} {...(bodyClass.includes('tblwrap') ? { tabIndex: 0, role: 'group', 'aria-label': 'Tabla desplazable' } : {})}>{children}</div>
    </section>
  );
}

const STATE_CHIP: Record<string, string> = {
  draft: 'chip', in_review: 'chip chip-primary', changes_requested: 'chip chip-warning', validated: 'chip chip-success', published: 'chip chip-success', retired: 'chip chip-line',
};

export function StateChip({ state, expired }: { state: string; expired?: boolean }) {
  if (expired) return <span className="chip chip-warning">Caducado</span>;
  return <span className={STATE_CHIP[state] ?? 'chip'}>{STATE_LABELS[state] ?? state}</span>;
}

export function Loading({ label = 'Cargando…' }: { label?: string }) {
  return (
    <div className="col g8" role="status" aria-live="polite">
      <span className="sr-only">{label}</span>
      <div className="skeleton" style={{ width: '60%' }} />
      <div className="skeleton" style={{ width: '85%' }} />
      <div className="skeleton" style={{ width: '40%' }} />
    </div>
  );
}

export function ErrorBox({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const msg = error instanceof Error ? error.message : String(error);
  return (
    <div className="notice err" role="alert">
      <Icon name="error" />
      <div className="col g8 grow"><span>{msg}</span>{onRetry && <button type="button" className="btn btn-secondary btn-xs" onClick={onRetry}>Reintentar</button>}</div>
    </div>
  );
}

export function Empty({ icon = 'inbox', title, children }: { icon?: string; title: string; children?: ReactNode }) {
  return <div className="empty"><Icon name={icon} size={36} /><strong className="ui">{title}</strong>{children}</div>;
}

export function Notice({ kind = 'info', icon, children }: { kind?: 'info' | 'ok' | 'warn' | 'err'; icon?: string; children: ReactNode }) {
  const def = { info: 'info', ok: 'check_circle', warn: 'warning', err: 'error' }[kind];
  return <div className={`notice ${kind}`} role={kind === 'err' ? 'alert' : undefined}><Icon name={icon ?? def} /><div className="grow">{children}</div></div>;
}

/** Carga asíncrona con estados de carga, error y recarga. */
export function useAsync<T>(fn: () => Promise<T>, deps: unknown[]): { data: T | undefined; error: unknown; loading: boolean; reload: () => void; setData: (d: T) => void } {
  const [state, setState] = useState<{ data: T | undefined; error: unknown; loading: boolean }>({ data: undefined, error: null, loading: true });
  const [tick, setTick] = useState(0);
  const fnRef = useRef(fn);
  fnRef.current = fn;
  useEffect(() => {
    let alive = true;
    setState((s) => ({ ...s, loading: true, error: null }));
    fnRef.current().then(
      (data) => { if (alive) setState({ data, error: null, loading: false }); },
      (error) => { if (alive) setState({ data: undefined, error, loading: false }); },
    );
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, tick]);
  return { ...state, reload: () => setTick((t) => t + 1), setData: (d: T) => setState({ data: d, error: null, loading: false }) };
}

export function Async<T>({ state, children }: { state: { data: T | undefined; error: unknown; loading: boolean; reload: () => void }; children: (d: T) => ReactNode }) {
  if (state.error) return <ErrorBox error={state.error} onRetry={state.reload} />;
  if (state.loading && state.data === undefined) return <Loading />;
  if (state.data === undefined) return null;
  return <>{children(state.data)}</>;
}

// ---------------------------------------------------------------------------- Avisos
interface Toast { id: number; text: string; err?: boolean }
const ToastCtx = createContext<(text: string, err?: boolean) => void>(() => undefined);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const push = useCallback((text: string, err?: boolean) => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, text, err }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 6000);
  }, []);
  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div aria-live="polite" role="status">
        {toasts.slice(-1).map((t) => <div key={t.id} className={`toast-fixed${t.err ? ' err' : ''}`}><Icon name={t.err ? 'error' : 'check_circle'} />{t.text}</div>)}
      </div>
    </ToastCtx.Provider>
  );
}

export function useToast() { return useContext(ToastCtx); }

/** Ejecuta una acción con aviso de éxito o de error. */
export function useAction() {
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const run = useCallback(async <T,>(fn: () => Promise<T>, ok?: string | ((r: T) => string)): Promise<T | undefined> => {
    setBusy(true);
    try {
      const r = await fn();
      if (ok) toast(typeof ok === 'function' ? ok(r) : ok);
      return r;
    } catch (e) {
      toast(e instanceof ApiError || e instanceof Error ? e.message : String(e), true);
      return undefined;
    } finally {
      setBusy(false);
    }
  }, [toast]);
  return { run, busy };
}

// ---------------------------------------------------------------------------- Diálogos
export function Modal({ title, children, onClose, labelledBy = 'modal-title' }: { title: string; children: ReactNode; onClose: () => void; labelledBy?: string }) {
  useEffect(() => {
    const h = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  }, [onClose]);
  return (
    <div className="overlay" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="modal" role="dialog" aria-modal="true" aria-labelledby={labelledBy}>
        <h2 id={labelledBy} className="t-sub">{title}</h2>
        {children}
      </div>
    </div>
  );
}

/** Diálogo que exige un motivo (acciones sensibles, retiradas, reversiones). */
export function ReasonDialog({ title, description, confirmLabel, danger, onConfirm, onClose, extra, initial = '' }: {
  title: string; description?: ReactNode; confirmLabel: string; danger?: boolean; onConfirm: (reason: string) => void | Promise<void>; onClose: () => void; extra?: ReactNode; initial?: string;
}) {
  const [reason, setReason] = useState(initial);
  return (
    <Modal title={title} onClose={onClose}>
      {description && <div className="t-small muted">{description}</div>}
      {extra}
      <div className="field">
        <label htmlFor="reason">Motivo (obligatorio)</label>
        <textarea id="reason" className="input" value={reason} onChange={(e) => setReason(e.target.value)} />
      </div>
      <div className="row g8 end">
        <button type="button" className="btn btn-tertiary btn-sm" onClick={onClose}>Cancelar</button>
        <button type="button" className={`btn btn-sm ${danger ? 'btn-danger-solid' : 'btn-primary'}`} disabled={!reason.trim()} onClick={() => onConfirm(reason.trim())}>{confirmLabel}</button>
      </div>
    </Modal>
  );
}

export function Field({ label, id, children, help, error }: { label: string; id: string; children: ReactNode; help?: ReactNode; error?: ReactNode }) {
  return (
    <div className="field">
      <label htmlFor={id}>{label}</label>
      {children}
      {help && <span className="help">{help}</span>}
      {error && <span className="err-msg" role="alert"><Icon name="error" size={16} />{error}</span>}
    </div>
  );
}

export function Tabs<T extends string>({ tabs, value, onChange, label }: { tabs: { id: T; label: ReactNode; n?: number }[]; value: T; onChange: (v: T) => void; label: string }) {
  return (
    <div className="tabs" role="tablist" aria-label={label}>
      {tabs.map((t) => (
        <button key={t.id} type="button" role="tab" aria-selected={value === t.id} className={`tab${value === t.id ? ' on' : ''}`} onClick={() => onChange(t.id)}>
          {t.n !== undefined && <span className="n">{t.n}</span>}{t.label}
        </button>
      ))}
    </div>
  );
}
