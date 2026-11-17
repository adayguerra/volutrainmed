/**
 * Ejercicio tal como lo muestra la app (móvil en vertical o tablet en
 * horizontal con dos paneles, tema claro u oscuro). Lo usan el editor de
 * preguntas, la vista previa con voz y la ficha de revisión.
 */
import type { CSSProperties } from 'react';
import type { StatementSegment, Variant } from '@vtm/contracts';
import { readQuantity, speakFragment, speakText } from '@vtm/engine';
import { num } from '../ui/format';

export type Device = 'phone' | 'tablet';
export type Orientation = 'portrait' | 'landscape';

export function Statement({ segs }: { segs: StatementSegment[] }) {
  return <>{segs.map((s, i) => (s.t === 'text' ? <span key={i}>{s.v}</span> : <span key={i} className="qty">{num(s.value)}{s.unit === '%' ? ' %' : ` ${s.unit}`}</span>))}</>;
}

/** Texto que dice la voz, con las cantidades resaltadas. */
export function spokenParts(v: Pick<Variant, 'statement' | 'question' | 'tts'>, custom?: string | null): { text: string; qty: boolean }[] {
  if (custom) return [{ text: speakText(custom), qty: false }];
  const parts = v.statement.map((s) => (s.t === 'text' ? { text: speakFragment(s.v), qty: false } : { text: readQuantity(s.value, s.unit), qty: true }));
  parts.push({ text: ` ${speakText(v.question)}`, qty: false });
  return parts;
}

function Response({ v, compact }: { v: Variant; compact?: boolean }) {
  const t = v.exerciseTypeId;
  if (v.options?.length) {
    return (
      <div className="col g8" role="radiogroup" aria-label="Opciones">
        {v.options.map((o, i) => (
          <div key={o.id} className="opt" role="radio" aria-checked="false" style={compact ? { minHeight: 48, fontSize: 16 } : undefined}>
            <span className="lt">{String.fromCharCode(65 + i)}</span><span>{o.label}</span>
          </div>
        ))}
      </div>
    );
  }
  if (v.orderItems?.length) {
    return <ol className="col g8" aria-label="Pasos para ordenar">{v.orderItems.map((o) => <li key={o.id} className="step"><span className="n">⋮⋮</span><span>{o.text}</span></li>)}</ol>;
  }
  if (v.series?.length) {
    return <div className="col g8"><span className="t-label muted">Conversión 1 de {v.series.length}</span><p className="t-stmt">{v.series[0]!.prompt}</p><div className="answer" style={{ height: 64 }}><span className="ph">0</span><span className="u">{v.series[0]!.answer.unit}</span></div></div>;
  }
  const unit = v.answer?.unit ?? '';
  return (
    <div className="col g12">
      <div className="answer" style={{ height: 72 }} aria-label={`Respuesta en ${unit}`}><span className="ph">0</span><span className="u">{v.answer?.unitFixed === false ? `${unit} ▾` : unit}</span></div>
      {t !== 'T6' && (
        <div className="grid3" style={{ gap: 6 }} aria-hidden="true">
          {['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'].map((k) => <span key={k} className="row center mono" style={{ height: 40, borderRadius: 10, background: 'var(--surface)', border: '1px solid var(--border)' }}>{k}</span>)}
        </div>
      )}
    </div>
  );
}

export function ExercisePreview({ v, device = 'phone', orientation = 'portrait', dark = false, zoom = 100, label = 'Vista previa del ejercicio' }: {
  v: Variant; device?: Device; orientation?: Orientation; dark?: boolean; zoom?: number; label?: string;
}) {
  const twoPanels = device === 'tablet' && orientation === 'landscape';
  const cls = `device ${twoPanels ? 'tablet-h' : 'phone-v'}${dark ? ' dark' : ''}`;
  const data = (
    <div className="col g12" data-testid="panel-datos">
      <span className="t-label muted">{v.exerciseTypeId} · nivel {v.level}</span>
      <p className="t-stmt"><Statement segs={v.statement} /></p>
      <p className="ui sb t-body">{v.question}</p>
    </div>
  );
  const response = <div className="col g12" data-testid="panel-respuesta"><Response v={v} compact={!twoPanels} /><button type="button" className="btn btn-primary" tabIndex={-1}>Comprobar</button></div>;
  return (
    <div style={{ zoom: zoom / 100 } as CSSProperties}>
      <div className={cls} role="region" aria-label={label} data-layout={twoPanels ? 'dos-paneles' : 'una-columna'}>
        <div className="dev-body">{data}{response}</div>
      </div>
    </div>
  );
}
