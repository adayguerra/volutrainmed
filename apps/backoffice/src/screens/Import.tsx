/**
 * B13–B14 · Importación masiva desde hoja de cálculo (CSV) o JSON: hoja modelo,
 * subida, emparejado de columnas, validación por fila con corrección en la
 * propia tabla y confirmación. Lo importado se crea siempre en borrador y las
 * filas rechazadas salen en un informe descargable.
 */
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import type { Item } from '../api/types';
import { useSession } from '../auth/session';
import { download } from '../content/common';
import { normHeader, parseFile, toCsv } from '../content/csv';
import { Field, Icon, Notice, Page, Panel, useAction } from '../ui/kit';

type ImportType = 'T1' | 'T2' | 'case_rows';
interface Column { key: string; label: string; required: boolean }
interface RowResult { row: number; ok: boolean; errors: string[]; data: Record<string, string> }
interface Validation { total: number; ok: number; errors: number; rows: RowResult[]; columns: Column[] }
interface CommitResult { created: number; ids: string[]; rejected: { row: number; errors: string[] }[]; report: string }

const TYPES: { id: ImportType; label: string }[] = [
  { id: 'T1', label: 'Preguntas T1 · respuesta numérica' }, { id: 'T2', label: 'Preguntas T2 · selección única' }, { id: 'case_rows', label: 'Filas de tabla de casos' },
];
function readText(f: File): Promise<string> {
  if (typeof f.text === 'function') return f.text();
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result ?? ''));
    r.onerror = () => reject(r.error);
    r.readAsText(f);
  });
}

const STEP_LABELS = ['Descargar la hoja modelo', 'Subir el archivo', 'Emparejar y validar', 'Confirmar'];

export function Import() {
  const { api } = useSession();
  const { run, busy } = useAction();
  const [type, setType] = useState<ImportType>('T1');
  const [columns, setColumns] = useState<Column[]>([]);
  const [file, setFile] = useState<{ name: string; columns: string[] } | null>(null);
  const [rows, setRows] = useState<Record<string, string>[]>([]);
  const [mapping, setMapping] = useState<Record<string, string>>({});
  const [validation, setValidation] = useState<Validation | null>(null);
  const [onlyErrors, setOnlyErrors] = useState(true);
  const [result, setResult] = useState<CommitResult | null>(null);
  const [parseError, setParseError] = useState<string | null>(null);
  const [target, setTarget] = useState('');
  const [templates, setTemplates] = useState<Item[]>([]);

  useEffect(() => {
    api.post<Validation>('/v1/admin/import/validate', { type, rows: [] }).then((v) => setColumns(v.columns ?? [])).catch(() => setColumns([]));
    if (type === 'case_rows') api.get<{ items: Item[] }>('/v1/admin/items', { kind: 'template' }).then((r) => setTemplates(r.items.filter((t) => ((t.data as { variables?: { kind: string }[] }).variables ?? []).some((v) => v.kind === 'case_table')))).catch(() => setTemplates([]));
  }, [api, type]);

  const step = result ? 4 : validation ? 3 : file ? 3 : 2;

  async function downloadModel() {
    const csv = await run(() => api.text('/v1/admin/import/template', { type }));
    if (csv) download(`modelo-${type}.csv`, csv);
  }

  async function onFile(f: File) {
    setParseError(null); setValidation(null); setResult(null);
    try {
      const parsed = parseFile(f.name, await readText(f));
      if (parsed.rows.length > 2000) { setParseError(`El archivo tiene ${parsed.rows.length} filas: se admiten 2000 por archivo`); return; }
      setFile({ name: f.name, columns: parsed.columns });
      setRows(parsed.rows);
      const auto: Record<string, string> = {};
      for (const c of parsed.columns) {
        const n = normHeader(c);
        const m = columns.find((k) => k.key === n || normHeader(k.label) === n);
        auto[c] = m?.key ?? '';
      }
      setMapping(auto);
    } catch (e) {
      setParseError(`No se puede leer el archivo: ${(e as Error).message}`);
    }
  }

  const activeMapping = useMemo(() => Object.fromEntries(Object.entries(mapping).filter(([, v]) => v)), [mapping]);
  const missingRequired = columns.filter((c) => c.required && !Object.values(activeMapping).includes(c.key));

  async function validate(nextRows = rows) {
    const v = await run(() => api.post<Validation>('/v1/admin/import/validate', { type, rows: nextRows, mapping: activeMapping }));
    if (v) setValidation(v);
  }

  async function commit() {
    const r = await run(() => api.post<CommitResult>('/v1/admin/import/commit', { type, rows, mapping: activeMapping, targetTemplateId: type === 'case_rows' ? target : undefined }), (x) => `Se han creado ${x.created} borradores`);
    if (r) setResult(r);
  }

  function editCell(rowIndex: number, fileCol: string, value: string) {
    setRows((rs) => rs.map((r, i) => (i === rowIndex ? { ...r, [fileCol]: value } : r)));
  }

  const colFor = (key: string) => Object.entries(activeMapping).find(([, k]) => k === key)?.[0];
  const shown = validation?.rows.filter((r) => !onlyErrors || !r.ok) ?? [];
  const firstErrors = validation?.rows.filter((r) => !r.ok) ?? [];

  return (
    <Page title="Importación masiva" crumbs={[{ label: 'Contenido' }, { label: 'Importación' }, ...(file ? [{ label: file.name }] : [])]}>
      <ol className="row g8 wrap" aria-label="Pasos de la importación">
        {STEP_LABELS.map((l, i) => <li key={l} className={`chip${step === i + 1 ? ' chip-primary' : step > i + 1 ? ' chip-success' : ''}`} aria-current={step === i + 1 ? 'step' : undefined}>{i + 1} · {l}</li>)}
      </ol>
      <Panel title="Archivo" icon="upload_file">
        <div className="col g12">
          <div className="row g12 wrap ai-end">
            <Field label="Qué se importa" id="imp-type">
              <select id="imp-type" className="input" value={type} onChange={(e) => { setType(e.target.value as ImportType); setFile(null); setRows([]); setValidation(null); setResult(null); }}>
                {TYPES.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
              </select>
            </Field>
            <button type="button" className="btn btn-secondary btn-sm" onClick={downloadModel}><Icon name="download" />Descargar la hoja modelo</button>
            <Field label="Subir el archivo (CSV o JSON, hasta 2000 filas)" id="imp-file">
              <input id="imp-file" type="file" accept=".csv,.json,text/csv,application/json" className="input" style={{ paddingTop: 12 }} onChange={(e) => { const f = e.target.files?.[0]; if (f) void onFile(f); }} />
            </Field>
          </div>
          {type === 'case_rows' && (
            <Field label="Plantilla cuya tabla de casos se completa" id="imp-target">
              <select id="imp-target" className="input" value={target} onChange={(e) => setTarget(e.target.value)}><option value="">Elige una plantilla</option>{templates.map((t) => <option key={t.id} value={t.id}>{t.title}</option>)}</select>
            </Field>
          )}
          {parseError && <Notice kind="err">{parseError}</Notice>}
          {file && <p className="t-small">{file.name} · {rows.length} filas · {file.columns.length} columnas</p>}
        </div>
      </Panel>

      {file && !result && (
        <Panel title="Emparejar columnas" icon="link" bodyClass="tblwrap">
          <table className="tbl" aria-label="Emparejar columnas">
            <thead><tr><th>Columna del archivo</th><th>Campo</th><th>Estado</th></tr></thead>
            <tbody>{file.columns.map((c) => (
              <tr key={c}>
                <td className="mono">{c}</td>
                <td><select aria-label={`Campo para la columna ${c}`} className="input input-sm" value={mapping[c] ?? ''} onChange={(e) => setMapping({ ...mapping, [c]: e.target.value })}>
                  <option value="">Ignorar</option>{columns.map((k) => <option key={k.key} value={k.key}>{k.label}{k.required ? ' *' : ''}</option>)}
                </select></td>
                <td>{mapping[c] ? <span className="chip chip-success">Emparejada</span> : <span className="chip">Sin emparejar</span>}</td>
              </tr>
            ))}</tbody>
          </table>
          <div className="row g8 wrap" style={{ padding: 16 }}>
            {missingRequired.length > 0 && <span className="t-small c-warning">Sin emparejar: {missingRequired.map((c) => c.label).join(', ')}</span>}
            <span className="grow" />
            <button type="button" className="btn btn-primary btn-sm" disabled={busy} onClick={() => validate()}><Icon name="fact_check" />Validar filas</button>
          </div>
        </Panel>
      )}

      {validation && !result && (
        <Panel title={`Validación · ${validation.total} filas`} icon="rule">
          <div className="col g12">
            <div className="grid3">
              <div className="col g4"><span className="t-label muted">Correctas</span><span className="kpi c-success" data-testid="ok-count">{validation.ok}</span></div>
              <div className="col g4"><span className="t-label muted">Con error</span><span className="kpi c-error" data-testid="err-count">{validation.errors}</span></div>
              <div className="col g4"><span className="t-label muted">Total</span><span className="kpi">{validation.total}</span></div>
            </div>
            {validation.errors > 0 && (
              <Notice kind="err"><strong>{validation.errors} filas con error no se importarán.</strong> {firstErrors.slice(0, 3).map((r) => `Fila ${r.row}`).join(' · ')}{firstErrors.length > 3 ? ` · y ${firstErrors.length - 3} más` : ''}. Corrige las celdas aquí mismo: se revalidan al salir.</Notice>
            )}
            <label className="check-row t-small"><input type="checkbox" checked={onlyErrors} onChange={(e) => setOnlyErrors(e.target.checked)} />Solo errores</label>
            <div className="tblwrap">
              <table className="tbl" aria-label="Validación por fila">
                <thead><tr><th>Fila</th>{validation.columns.map((c) => <th key={c.key}>{c.label}</th>)}<th>Estado</th><th>Motivo</th></tr></thead>
                <tbody>{shown.slice(0, 300).map((r) => (
                  <tr key={r.row} data-testid={`fila-${r.row}`}>
                    <td className="mono">Fila {r.row}</td>
                    {validation.columns.map((c) => {
                      const fc = colFor(c.key);
                      return (
                        <td key={c.key}>
                          {!r.ok && fc ? (
                            <input aria-label={`Fila ${r.row} · ${c.label}`} className="input input-sm" value={rows[r.row - 1]?.[fc] ?? ''} onChange={(e) => editCell(r.row - 1, fc, e.target.value)} onBlur={() => validate()} />
                          ) : <span className="t-small">{fc ? rows[r.row - 1]?.[fc] : ''}</span>}
                        </td>
                      );
                    })}
                    <td>{r.ok ? <span className="chip chip-success">Correcta</span> : <span className="chip chip-error">Error</span>}</td>
                    <td className="t-small c-error">{r.errors.join(' · ')}</td>
                  </tr>
                ))}</tbody>
              </table>
            </div>
            <div className="row g8 wrap">
              <button type="button" className="btn btn-tertiary btn-sm" onClick={() => download('informe-validacion.csv', toCsv(['fila', 'estado', 'motivo'], validation.rows.map((r) => [r.row, r.ok ? 'correcta' : 'error', r.errors.join(' · ')])))}><Icon name="download" />Descargar informe</button>
              <span className="grow" />
              <button type="button" className="btn btn-tertiary btn-sm" onClick={() => { setFile(null); setRows([]); setValidation(null); }}>Cancelar</button>
              <button type="button" className="btn btn-primary btn-sm" disabled={busy || validation.ok === 0 || (type === 'case_rows' && !target)} onClick={commit}><Icon name="playlist_add" />Importar {validation.ok} como borrador</button>
            </div>
          </div>
        </Panel>
      )}

      {result && (
        <Panel title="Importación terminada" icon="task_alt">
          <div className="col g12" role="status">
            <Notice kind="ok"><strong>Se han creado {result.created} borradores.</strong> Lo importado queda siempre en borrador hasta su revisión.</Notice>
            {result.rejected.length > 0 && (
              <>
                <Notice kind="warn">{result.rejected.length} filas rechazadas: {result.rejected.slice(0, 5).map((r) => `Fila ${r.row}`).join(' · ')}{result.rejected.length > 5 ? '…' : ''}</Notice>
                <button type="button" className="btn btn-secondary btn-sm" onClick={() => download('filas-rechazadas.csv', toCsv(['fila', 'motivo'], result.rejected.map((r) => [r.row, r.errors.join(' · ')])))}><Icon name="download" />Descargar informe de filas rechazadas</button>
              </>
            )}
            <div className="row g8"><Link className="btn btn-primary btn-sm" to="/biblioteca?q=">Ver en la biblioteca</Link><button type="button" className="btn btn-tertiary btn-sm" onClick={() => { setResult(null); setFile(null); setValidation(null); setRows([]); }}>Importar otro archivo</button></div>
          </div>
        </Panel>
      )}
    </Page>
  );
}
