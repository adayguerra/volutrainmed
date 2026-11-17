/** Disposición común: barra lateral por rol y área principal. */
import { useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { navFor } from '../auth/permissions';
import { useSession } from '../auth/session';
import { Icon } from './kit';

export function Logo({ size = 30 }: { size?: number }) {
  const id = `vclip${size}`;
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" aria-hidden="true">
      <defs><clipPath id={id}><path d="M7 7h26L22.5 33a2.7 2.7 0 0 1-5 0z" /></clipPath></defs>
      <g clipPath={`url(#${id})`}><rect x="0" y="0" width="40" height="40" fill="var(--surface)" /><path d="M0 19 Q20 25 40 19 V40 H0z" fill="var(--brand)" /></g>
      <path d="M7 7h26L22.5 33a2.7 2.7 0 0 1-5 0z" fill="none" stroke="var(--primary)" strokeWidth="2.6" strokeLinejoin="round" />
    </svg>
  );
}

function initials(name: string) {
  return name.replace(/\(.*?\)/g, '').trim().split(/\s+/).slice(0, 2).map((w) => w[0]?.toUpperCase() ?? '').join('');
}

export function Layout() {
  const { account, api, signOut } = useSession();
  const [counts, setCounts] = useState<{ reviews?: number; inquiries?: number }>({});
  const nav = navFor(account?.role);
  useEffect(() => {
    let alive = true;
    api.get<{ myWork?: { pendingReviews?: unknown[] }; inquiriesOpen?: number }>('/v1/admin/dashboard')
      .then((d) => { if (alive) setCounts({ reviews: d?.myWork?.pendingReviews?.length, inquiries: d?.inquiriesOpen }); })
      .catch(() => undefined);
    return () => { alive = false; };
  }, [api]);
  let lastGroup: string | null = null;
  return (
    <div className="vt bo">
      <nav className="bo-side" aria-label="Secciones">
        <div className="bo-brand"><Logo /><span>Volutrain<span className="c-primary">Med</span></span></div>
        {nav.map((n) => {
          const head = n.group && n.group !== lastGroup ? <span className="bo-sec">{n.group}</span> : null;
          lastGroup = n.group;
          const badge = n.badge === 'reviews' ? counts.reviews : n.badge === 'inquiries' ? counts.inquiries : undefined;
          return (
            <span key={n.to} style={{ display: 'contents' }}>
              {head}
              <NavLink to={n.to} end={n.to === '/'} className={({ isActive }) => (isActive ? 'on' : '')}>
                <Icon name={n.icon} />{n.label}{badge ? <span className="cnt" aria-label={`${badge} pendientes`}>{badge}</span> : null}
              </NavLink>
            </span>
          );
        })}
        <div style={{ flex: 1, minHeight: 24 }} />
        {account && (
          <div className="col g8" style={{ padding: 12, borderTop: '1px solid var(--border)', marginTop: 8 }}>
            <div className="row g10">
              <span className="row center ui b t-small" style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--primary-tint)', color: 'var(--primary)', flex: 'none' }} aria-hidden="true">{initials(account.name)}</span>
              <span className="col g4 grow" style={{ minWidth: 0 }}>
                <span className="ui sb t-small" style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{account.name}</span>
                <span className="t-label muted" data-testid="role-label">{account.roleLabel}</span>
              </span>
            </div>
            <button type="button" className="btn btn-tertiary btn-xs" onClick={signOut}><Icon name="logout" />Cerrar sesión</button>
          </div>
        )}
      </nav>
      <main className="bo-main" id="contenido">
        <Outlet />
      </main>
    </div>
  );
}
