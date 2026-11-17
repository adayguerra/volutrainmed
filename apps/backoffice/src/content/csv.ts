/** Lectura y escritura de CSV (separador «;» o «,», comillas dobles) y de JSON para la importación masiva. */

export function detectDelimiter(firstLine: string): ';' | ',' | '\t' {
  const counts = { ';': (firstLine.match(/;/g) ?? []).length, ',': (firstLine.match(/,/g) ?? []).length, '\t': (firstLine.match(/\t/g) ?? []).length };
  return (Object.entries(counts).sort((a, b) => b[1] - a[1])[0]![0] as ';' | ',' | '\t');
}

export function parseCsv(text: string): { columns: string[]; rows: Record<string, string>[] } {
  const clean = text.replace(/^﻿/, '');
  const delim = detectDelimiter(clean.split(/\r?\n/)[0] ?? '');
  const records: string[][] = [];
  let field = ''; let record: string[] = []; let quoted = false;
  for (let i = 0; i < clean.length; i++) {
    const c = clean[i]!;
    if (quoted) {
      if (c === '"' && clean[i + 1] === '"') { field += '"'; i++; } else if (c === '"') quoted = false; else field += c;
    } else if (c === '"') quoted = true;
    else if (c === delim) { record.push(field); field = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && clean[i + 1] === '\n') i++;
      record.push(field); field = '';
      if (record.some((x) => x.trim() !== '')) records.push(record);
      record = [];
    } else field += c;
  }
  record.push(field);
  if (record.some((x) => x.trim() !== '')) records.push(record);
  const columns = (records.shift() ?? []).map((c) => c.trim());
  return { columns, rows: records.map((r) => Object.fromEntries(columns.map((c, i) => [c, (r[i] ?? '').trim()]))) };
}

export function parseFile(name: string, text: string): { columns: string[]; rows: Record<string, string>[] } {
  if (/\.json$/i.test(name) || text.trim().startsWith('[')) {
    const data = JSON.parse(text) as Record<string, unknown>[];
    if (!Array.isArray(data)) throw new Error('El JSON debe ser una lista de filas');
    const columns = [...new Set(data.flatMap((r) => Object.keys(r)))];
    return { columns, rows: data.map((r) => Object.fromEntries(columns.map((c) => [c, r[c] === undefined || r[c] === null ? '' : String(r[c])]))) };
  }
  return parseCsv(text);
}

export function toCsv(columns: string[], rows: (string | number | null | undefined)[][]): string {
  const esc = (v: unknown) => {
    const s = String(v ?? '');
    return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [columns.map(esc).join(';'), ...rows.map((r) => r.map(esc).join(';'))].join('\n');
}

export function normHeader(s: string): string {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}
