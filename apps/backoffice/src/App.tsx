/** Rutas del back office con guarda de sesión y de permisos por rol. */
import { Suspense, type ReactNode } from 'react';
import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import { canAccess, type Section } from './auth/permissions';
import { useSession } from './auth/session';
import { Login } from './auth/Login';
import { Layout } from './ui/Layout';
import { Icon, Loading, Page, ToastProvider } from './ui/kit';
import { Dashboard } from './screens/Dashboard';
import { screens } from './screens/registry';

function RequireAuth({ children }: { children: ReactNode }) {
  const { account } = useSession();
  const location = useLocation();
  if (!account) return <Navigate to="/acceso" replace state={{ from: location.pathname }} />;
  return <>{children}</>;
}

export function NoAccess() {
  return (
    <Page title="Sin acceso">
      <div className="panel panel-b col g12" role="alert" style={{ maxWidth: 560 }}>
        <div className="row g10"><Icon name="lock" className="c-warning" /><strong className="ui">No tienes acceso a esta sección</strong></div>
        <p className="t-small muted">Tu rol no incluye esta sección del back office. Si lo necesitas, pide el cambio a la superadministración; el cambio de rol queda en auditoría.</p>
      </div>
    </Page>
  );
}

function Guard({ section, children }: { section: Section; children: ReactNode }) {
  const { account } = useSession();
  if (!canAccess(account?.role, section)) return <NoAccess />;
  return <Suspense fallback={<div className="bo-body"><Loading /></div>}>{children}</Suspense>;
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/acceso" element={<Login />} />
      <Route element={<RequireAuth><Layout /></RequireAuth>}>
        <Route index element={<Dashboard />} />
        {screens.map((s) => {
          const C = s.component;
          return <Route key={s.path} path={s.path} element={<Guard section={s.section}><C /></Guard>} />;
        })}
        <Route path="*" element={<Page title="Página no encontrada"><p className="muted">La dirección no corresponde a ninguna sección.</p></Page>} />
      </Route>
    </Routes>
  );
}

export function App() {
  return <ToastProvider><AppRoutes /></ToastProvider>;
}

