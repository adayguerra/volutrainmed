/**
 * B11 · Vista previa con lectura en voz alta: el ejercicio como lo muestra la
 * app (móvil o tablet, vertical u horizontal, claro u oscuro, tamaño de texto),
 * modo táctil o manos libres con el texto que se dice y las cantidades
 * resaltadas (mismo normalizador de lectura que la app), y simulación de una
 * respuesta hablada con su interpretación, la confirmación y el veredicto.
 */
import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { confirmationText, generateVariants, grade, parseSpoken, resolveQuestion, type QuestionDefinition, type TemplateDefinition } from '@vtm/engine';
import type { Variant } from '@vtm/contracts';
import type { ItemDetail } from '../api/types';
import { useSession } from '../auth/session';
import { normalizeTemplate } from '../content/template';
import { ExercisePreview, spokenParts, type Device, type Orientation } from '../content/ExercisePreview';
import { Async, Field, Icon, Notice, Page, Panel, useAsync } from '../ui/kit';
import { num } from '../ui/format';

const VERDICT: Record<string, { label: string; cls: string }> = {
  correct: { label: 'Correcto', cls: 'chip chip-success' }, correct_note: { label: 'Correcto con observación', cls: 'chip chip-success' }, incorrect: { label: 'Incorrecto', cls: 'chip chip-error' },
};

function Seg<T extends string>({ label, value, options, onChange }: { label: string; value: T; options: [T, string][]; onChange: (v: T) => void }) {
  return (
    <div className="segctl" role="group" aria-label={label}>
      {options.map(([v, l]) => <button key={v} type="button" className={value === v ? 'on' : ''} aria-pressed={value === v} onClick={() => onChange(v)}>{l}</button>)}
    </div>
  );
}

export function speak(text: string, rate = 1): boolean {
  const synth = (window as { speechSynthesis?: SpeechSynthesis }).speechSynthesis;
  const U = (window as { SpeechSynthesisUtterance?: typeof SpeechSynthesisUtterance }).SpeechSynthesisUtterance;
  if (!synth || !U) return false;
  synth.cancel();
  const u = new U(text);
  u.lang = 'es-ES';
  u.rate = rate;
  synth.speak(u);
  return true;
}

export function SpokenSimulator({ v }: { v: Variant }) {
  const [text, setText] = useState('');
  const [res, setRes] = useState<ReturnType<typeof parseSpoken> | null>(null);
  const answer = v.answer;
  const graded = res && res.kind === 'number' && answer ? grade(answer, v.predictedErrors, { raw: res.value, unit: res.unit ?? answer.unit }) : null;
  return (
    <section className="col g12" aria-label="Simulación de respuesta hablada">
      <form className="row g8 wrap" onSubmit={(e) => { e.preventDefault(); setRes(parseSpoken(text)); }}>
        <div className="grow"><Field label="Simular respuesta" id="sim"><input id="sim" className="input" value={text} onChange={(e) => setText(e.target.value)} placeholder="cuatro coma ocho" /></Field></div>
        <button type="submit" className="btn btn-secondary btn-sm" style={{ alignSelf: 'flex-end' }} disabled={!text.trim()}>Interpretar</button>
      </form>
      {res && (
        <dl className="col g8" aria-label="Resultado de la simulación">
          {res.kind === 'number' ? (
            <>
              <div className="row g8"><dt className="t-label muted" style={{ width: 160 }}>Interpretación</dt><dd className="kv" data-testid="interpretacion" style={{ margin: 0, fontSize: 24 }}>{num(res.value)}{res.unit || answer?.unit ? ` ${res.unit ?? answer?.unit}` : ''}</dd></div>
              <div className="row g8"><dt className="t-label muted" style={{ width: 160 }}>Confirmación hablada</dt><dd style={{ margin: 0 }}>«{confirmationText(res.value, res.unit ?? answer?.unit ?? '')}. ¿Correcto?»</dd></div>
              {graded && <div className="row g8"><dt className="t-label muted" style={{ width: 160 }}>Veredicto</dt><dd style={{ margin: 0 }} className="row g8"><span className={VERDICT[graded.verdict]?.cls} data-testid="veredicto">{VERDICT[graded.verdict]?.label ?? graded.verdict}</span>{graded.diagnosis && <span className="t-small">{graded.diagnosis}</span>}{graded.note && <span className="t-small">{graded.note}</span>}</dd></div>}
            </>
          ) : res.kind === 'ambiguous' ? <Notice kind="warn">{res.question}</Notice>
            : res.kind === 'command' ? <Notice>Se interpreta como la orden «{res.command}».</Notice>
              : <Notice kind="err">No se ha reconocido ninguna cifra.</Notice>}
        </dl>
      )}
    </section>
  );
}

export function Preview() {
  const { id } = useParams();
  const { api } = useSession();
  const detail = useAsync(() => api.get<ItemDetail>(`/v1/admin/items/${id}`), [api, id]);
  const [device, setDevice] = useState<Device>('phone');
  const [orientation, setOrientation] = useState<Orientation>('portrait');
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  const [zoom, setZoom] = useState<'100' | '150' | '200'>('100');
  const [mode, setMode] = useState<'touch' | 'handsfree'>('touch');
  const [pick, setPick] = useState<'concrete' | 'random' | 'extremes'>('concrete');
  const [index, setIndex] = useState(0);
  const [rate, setRate] = useState<'0.8' | '1' | '1.5'>('1');
  const [playing, setPlaying] = useState(false);
  const [noVoice, setNoVoice] = useState(false);

  const variants: Variant[] = useMemo(() => {
    const it = detail.data?.item;
    if (!it) return [];
    try {
      if (it.kind === 'template') return generateVariants({ ...normalizeTemplate(it.data as Partial<TemplateDefinition>), version: it.version }, { perLevel: 6, seed: 17 }).variants.map((r) => r.variant);
      if (it.kind === 'question') return [resolveQuestion(it.data as unknown as QuestionDefinition)];
    } catch { /* plantilla incompleta */ }
    return [];
  }, [detail.data]);

  const sorted = useMemo(() => [...variants].filter((v) => v.answer).sort((a, b) => Number(a.answer!.value) - Number(b.answer!.value)), [variants]);
  const current: Variant | undefined = pick === 'extremes' ? (index % 2 === 0 ? sorted[0] : sorted[sorted.length - 1]) ?? variants[0] : variants[index % Math.max(variants.length, 1)];
  const custom = detail.data?.item.kind === 'template' ? (detail.data.item.data as { tts?: string | null }).tts : (detail.data?.item.data as { tts?: string | null } | undefined)?.tts;
  const parts = current ? spokenParts(current, custom) : [];
  const spokenText = parts.map((p) => p.text).join('').replace(/\s+/g, ' ').trim();

  function play() {
    if (!current) return;
    const ok = speak(spokenText, Number(rate));
    setNoVoice(!ok);
    setPlaying(ok);
  }

  return (
    <Page title="Vista previa con voz" crumbs={[{ label: 'Biblioteca', to: '/biblioteca' }, { label: detail.data?.item.title ?? '…' }, { label: 'Vista previa' }]}
      actions={<Link className="btn btn-secondary btn-sm" to={detail.data?.item.kind === 'question' ? `/preguntas/${id}` : `/plantillas/${id}`}><Icon name="close" />Cerrar vista previa</Link>}>
      <Async state={detail}>
        {() => !current ? <Notice kind="warn">No se puede generar ninguna variante: completa la plantilla en el editor.</Notice> : (
          <>
            <div className="row g8 wrap">
              <Seg label="Dispositivo" value={device} options={[['phone', 'Móvil'], ['tablet', 'Tablet']]} onChange={(d) => { setDevice(d); if (d === 'phone') setOrientation('portrait'); }} />
              <Seg label="Orientación" value={orientation} options={[['portrait', 'Vertical'], ['landscape', 'Horizontal']]} onChange={setOrientation} />
              <Seg label="Tema" value={theme} options={[['light', 'Claro'], ['dark', 'Oscuro']]} onChange={setTheme} />
              <Seg label="Tamaño del texto" value={zoom} options={[['100', '100 %'], ['150', '150 %'], ['200', '200 %']]} onChange={setZoom} />
            </div>
            <div className="split">
              <div style={{ overflowX: 'auto' }}><ExercisePreview v={current} device={device} orientation={orientation} dark={theme === 'dark'} zoom={Number(zoom)} /></div>
              <div className="col g16">
                <Panel title="Modo" icon="hearing">
                  <div className="col g12">
                    <Seg label="Modo de la sesión" value={mode} options={[['touch', 'Táctil'], ['handsfree', 'Manos libres']]} onChange={setMode} />
                    {mode === 'handsfree' && (
                      <section className="col g10" aria-label="Lectura en voz alta">
                        <div className="row g8 wrap">
                          <button type="button" className="btn btn-primary btn-sm" onClick={play}><Icon name="play_arrow" />{playing ? 'Repetir' : 'Reproducir'}</button>
                          <Seg label="Velocidad" value={rate} options={[['0.8', '0,8×'], ['1', '1×'], ['1.5', '1,5×']]} onChange={setRate} />
                        </div>
                        {playing && <span className="chip chip-primary" role="status">Leyendo</span>}
                        {noVoice && <Notice kind="warn">Este navegador no tiene síntesis de voz: se muestra solo el texto que se dice.</Notice>}
                        <div className="card spoken t-body" aria-label="Texto que se dice" data-testid="texto-hablado">
                          {parts.map((p, i) => (p.qty ? <mark key={i}>{p.text}</mark> : <span key={i}>{p.text}</span>))}
                        </div>
                      </section>
                    )}
                  </div>
                </Panel>
                <Panel title="Simulación" icon="mic"><SpokenSimulator v={current} /></Panel>
                <Panel title="Variante" icon="tune">
                  <div className="col g8">
                    <Seg label="Variante" value={pick} options={[['concrete', 'Concreta'], ['random', 'Al azar'], ['extremes', 'Extremos']]} onChange={(p) => { setPick(p); if (p === 'random') setIndex(Math.floor(Math.random() * variants.length)); else setIndex(0); }} />
                    {pick === 'concrete' && variants.length > 1 && (
                      <Field label="Número de variante" id="vidx"><select id="vidx" className="input input-sm" value={index} onChange={(e) => setIndex(Number(e.target.value))}>{variants.map((v, i) => <option key={v.id} value={i}>{i + 1} · nivel {v.level}</option>)}</select></Field>
                    )}
                    {pick === 'extremes' && <button type="button" className="btn btn-tertiary btn-xs" onClick={() => setIndex(index + 1)}>{index % 2 === 0 ? 'Ver el máximo' : 'Ver el mínimo'}</button>}
                    <Link className="btn btn-secondary btn-sm" to="/publicacion"><Icon name="qr_code_2" />Probar en un dispositivo</Link>
                  </div>
                </Panel>
              </div>
            </div>
          </>
        )}
      </Async>
    </Page>
  );
}
