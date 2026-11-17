/**
 * B01 · Acceso con doble factor obligatorio. Paso 1: correo y contraseña.
 * Paso 2: alta del segundo factor en el primer acceso (secreto y QR) o
 * verificación con la aplicación de autenticación; alternativa con un código de
 * recuperación. Tras el alta se muestran los códigos de recuperación una vez.
 */
import { useEffect, useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import QRCode from 'qrcode';
import { createApi } from '../api/client';
import type { LoginResponse, MfaResponse } from '../api/types';
import { useSession } from './session';
import { Icon } from '../ui/kit';
import { Logo } from '../ui/Layout';

type Step = 'password' | 'enrol' | 'verify' | 'recovery' | 'codes';

export function Login() {
  const { api, account, signIn } = useSession();
  const navigate = useNavigate();
  const location = useLocation();
  const [step, setStep] = useState<Step>('password');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [login, setLogin] = useState<LoginResponse | null>(null);
  const [qr, setQr] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState<MfaResponse | null>(null);
  const from = (location.state as { from?: string } | null)?.from ?? '/';

  useEffect(() => {
    if (login?.otpauthUrl) QRCode.toDataURL(login.otpauthUrl, { margin: 1, width: 180 }).then(setQr).catch(() => setQr(null));
  }, [login?.otpauthUrl]);

  if (account && step !== 'codes') return <Navigate to={from} replace />;

  // El cliente sin token sirve para las rutas de acceso.
  const anon = createApi({ base: api.base });

  async function submitPassword(e: FormEvent) {
    e.preventDefault();
    setBusy(true); setError(null);
    try {
      const r = await anon.post<LoginResponse>('/v1/admin/auth/login', { email, password });
      setLogin(r);
      setCode('');
      setStep(r.mfaSetupRequired ? 'enrol' : 'verify');
    } catch (err) {
      setError((err as Error).message);
    } finally { setBusy(false); }
  }

  async function submitCode(e: FormEvent) {
    e.preventDefault();
    if (!login) return;
    setBusy(true); setError(null);
    try {
      const body = step === 'recovery' ? { challenge: login.challenge, recoveryCode: code.trim() } : { challenge: login.challenge, code: code.trim() };
      const r = await anon.post<MfaResponse>('/v1/admin/auth/mfa', body);
      if (r.recoveryCodes?.length) { setPending(r); setStep('codes'); return; }
      signIn(r.token, r.account);
      navigate(from, { replace: true });
    } catch (err) {
      setError((err as Error).message);
    } finally { setBusy(false); }
  }

  function finishEnrolment() {
    if (!pending) return;
    signIn(pending.token, pending.account);
    navigate(from, { replace: true });
  }

  const stepLabel = step === 'password' ? 'paso 1 de 2' : 'paso 2 de 2';

  return (
    <div className="vt row center" style={{ minHeight: '100vh', padding: '40px 16px', background: 'var(--bg)' }}>
      <main className="panel col g20" style={{ width: '100%', maxWidth: 460, padding: '40px 36px' }}>
        <div className="row g8"><Logo size={36} /><span className="ui b" style={{ fontSize: 22, letterSpacing: '-0.01em' }}>Volutrain<span className="c-primary">Med</span></span></div>

        {step === 'password' && (
          <form className="col g16" onSubmit={submitPassword} noValidate>
            <div className="col g6"><span className="t-over">Back office · {stepLabel}</span><h1 className="h1">Acceso</h1>
              <p className="t-body muted">Entra con tu correo profesional y tu contraseña.</p></div>
            <div className="field"><label htmlFor="email">Correo</label>
              <input id="email" className="input" type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></div>
            <div className="field"><label htmlFor="password">Contraseña</label>
              <input id="password" className="input" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></div>
            {error && <p className="err-msg" role="alert"><Icon name="error" size={16} />{error}</p>}
            <button className="btn btn-primary" type="submit" disabled={busy || !email || !password}>Continuar</button>
          </form>
        )}

        {step === 'enrol' && login && (
          <form className="col g16" onSubmit={submitCode} noValidate>
            <div className="col g6"><span className="t-over">Back office · {stepLabel}</span><h1 className="h1">Configura el segundo factor</h1>
              <p className="t-body muted">Es tu primer acceso: antes de entrar en ninguna sección, añade VolutrainMed a tu aplicación de autenticación.</p></div>
            <div className="row g16 ai-start wrap">
              {qr ? <img src={qr} width={160} height={160} alt="Código QR para la aplicación de autenticación" style={{ borderRadius: 8, border: '1px solid var(--border)' }} /> : null}
              <div className="col g6 grow">
                <span className="t-small muted">Si no puedes escanear el código, escribe esta clave:</span>
                <code className="mono b" data-testid="totp-secret" style={{ wordBreak: 'break-all', fontSize: 15 }}>{login.secret}</code>
              </div>
            </div>
            <div className="field"><label htmlFor="otp">Código de seis cifras</label>
              <input id="otp" className="input otp-input" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} /></div>
            {error && <p className="err-msg" role="alert"><Icon name="error" size={16} />{error}</p>}
            <button className="btn btn-primary" type="submit" disabled={busy || code.length !== 6}>Activar y entrar</button>
          </form>
        )}

        {(step === 'verify' || step === 'recovery') && login && (
          <form className="col g16" onSubmit={submitCode} noValidate>
            <div className="col g6"><span className="t-over">Back office · {stepLabel}</span><h1 className="h1">Verificación en dos pasos</h1>
              <p className="t-body muted">{step === 'verify' ? 'Escribe el código de seis cifras de tu aplicación de autenticación.' : 'Escribe uno de tus códigos de recuperación. Cada código sirve una sola vez.'}</p></div>
            {step === 'verify' ? (
              <div className="field"><label htmlFor="otp">Código de verificación</label>
                <input id="otp" className="input otp-input" inputMode="numeric" autoComplete="one-time-code" maxLength={6} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))} autoFocus /></div>
            ) : (
              <div className="field"><label htmlFor="rc">Código de recuperación</label>
                <input id="rc" className="input mono" value={code} onChange={(e) => setCode(e.target.value.toUpperCase())} autoFocus /></div>
            )}
            {error && <p className="err-msg" role="alert"><Icon name="error" size={16} />{error}</p>}
            <button className="btn btn-primary" type="submit" disabled={busy || (step === 'verify' ? code.length !== 6 : code.trim().length < 6)}>Verificar</button>
            <div className="row between t-small wrap g8">
              <button type="button" className="link" style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer' }} onClick={() => { setCode(''); setError(null); setStep(step === 'verify' ? 'recovery' : 'verify'); }}>
                {step === 'verify' ? 'Usar un código de recuperación' : 'Usar la aplicación de autenticación'}
              </button>
              <button type="button" className="link" style={{ background: 'none', border: 0, padding: 0, cursor: 'pointer' }} onClick={() => { setStep('password'); setLogin(null); setCode(''); setError(null); }}>Cambiar de cuenta</button>
            </div>
          </form>
        )}

        {step === 'codes' && pending && (
          <div className="col g16">
            <div className="col g6"><span className="t-over">Segundo factor activado</span><h1 className="h1">Guarda tus códigos de recuperación</h1>
              <p className="t-body muted">Te permiten entrar si pierdes el móvil. Se muestran solo ahora: cópialos en un lugar seguro.</p></div>
            <ul className="code-box" aria-label="Códigos de recuperación">
              {pending.recoveryCodes!.map((c) => <li key={c}>{c}</li>)}
            </ul>
            <button className="btn btn-primary" type="button" onClick={finishEnrolment}>He guardado los códigos, entrar</button>
          </div>
        )}

        <div className="card row g10 ai-start" style={{ background: 'var(--surface-2)', borderColor: 'transparent' }}>
          <Icon name="verified_user" className="c-primary" />
          <p className="t-small">El doble factor es obligatorio para todos los roles. Toda acción queda en el registro de auditoría.</p>
        </div>
      </main>
    </div>
  );
}
