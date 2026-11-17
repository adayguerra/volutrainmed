import '@testing-library/jest-dom/vitest';
import { afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  try { window.localStorage.clear(); } catch { /* sin almacenamiento */ }
});

// jsdom no trae síntesis de voz ni URL.createObjectURL.
if (!('speechSynthesis' in window)) {
  Object.defineProperty(window, 'speechSynthesis', { value: { speak: vi.fn(), cancel: vi.fn(), getVoices: () => [] }, configurable: true, writable: true });
}
if (!('SpeechSynthesisUtterance' in window)) {
  (window as unknown as { SpeechSynthesisUtterance: unknown }).SpeechSynthesisUtterance = class { text: string; lang = ''; rate = 1; onboundary: unknown; onend: unknown; constructor(t: string) { this.text = t; } };
}
if (!URL.createObjectURL) URL.createObjectURL = () => 'blob:prueba';
if (!URL.revokeObjectURL) URL.revokeObjectURL = () => undefined;
