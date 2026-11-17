/** Formato español: coma decimal, fechas cortas y tiempos relativos. */

export function num(v: string | number | null | undefined, digits?: number): string {
  if (v === null || v === undefined || v === '') return '—';
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return String(v);
  if (digits !== undefined) return n.toLocaleString('es-ES', { maximumFractionDigits: digits, minimumFractionDigits: 0, useGrouping: Math.abs(n) >= 10000 });
  // Cadena decimal exacta: se cambia el punto por la coma sin redondear.
  if (typeof v === 'string' && /^-?\d+(\.\d+)?$/.test(v)) return v.replace('.', ',');
  return n.toLocaleString('es-ES', { maximumFractionDigits: 6, useGrouping: Math.abs(n) >= 10000 });
}

export function pct(v: number | null | undefined, digits = 0): string {
  if (v === null || v === undefined || !Number.isFinite(v)) return '—';
  return `${num(v, digits)} %`;
}

export function qty(value: string | null | undefined, unit?: string | null): string {
  if (value === null || value === undefined) return '—';
  return unit ? `${num(value)} ${unit}` : num(value);
}

const MONTHS = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

export function date(d: string | Date | null | undefined, withTime = false): string {
  if (!d) return '—';
  const x = typeof d === 'string' ? new Date(d) : d;
  if (Number.isNaN(x.getTime())) return '—';
  const base = `${x.getDate()} ${MONTHS[x.getMonth()]} ${x.getFullYear()}`;
  return withTime ? `${base}, ${String(x.getHours()).padStart(2, '0')}:${String(x.getMinutes()).padStart(2, '0')}` : base;
}

export function ago(d: string | Date | null | undefined, now = Date.now()): string {
  if (!d) return '—';
  const x = typeof d === 'string' ? new Date(d) : d;
  const s = Math.round((now - x.getTime()) / 1000);
  if (s < 60) return 'ahora';
  if (s < 3600) return `hace ${Math.floor(s / 60)} min`;
  if (s < 86400) return `hace ${Math.floor(s / 3600)} h`;
  const days = Math.floor(s / 86400);
  if (days === 1) return 'ayer';
  if (days < 30) return `hace ${days} días`;
  return date(x);
}

export function ms(v: number | null | undefined): string {
  if (v === null || v === undefined) return '—';
  return `${num(v / 1000, 1)} s`;
}
