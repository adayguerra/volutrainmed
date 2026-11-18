import { defineConfig } from '@playwright/test';

/**
 * Recorrido en un navegador real (Chromium) contra una API real.
 * BO_E2E_API: base de la API (por defecto http://localhost:8788). Compila el
 * back office apuntando a esa API y lo sirve con `vite preview`.
 */
const API = process.env.BO_E2E_API ?? 'http://localhost:8788';
const PORT = Number(process.env.BO_E2E_PORT ?? 4173);

export default defineConfig({
  testDir: './e2e/browser',
  testMatch: '**/*.pw.ts',
  timeout: 180_000,
  fullyParallel: false,
  workers: 1,
  reporter: [['list']],
  use: { baseURL: `http://localhost:${PORT}`, locale: 'es-ES', colorScheme: 'light', trace: 'retain-on-failure' },
  projects: [
    { name: 'escritorio-1280', use: { viewport: { width: 1280, height: 800 } } },
    { name: 'tablet-768', use: { viewport: { width: 768, height: 1024 } } },
  ],
  webServer: {
    command: `pnpm exec vite build && pnpm exec vite preview --port ${PORT} --strictPort`,
    url: `http://localhost:${PORT}`,
    env: { VITE_API_BASE: API },
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
