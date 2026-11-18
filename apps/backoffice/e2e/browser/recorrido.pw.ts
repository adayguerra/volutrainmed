/**
 * Recorrido en navegador real: acceso con doble factor (TOTP real) y visita de
 * las pantallas principales a 1280 px y a 768 px. En cada una se comprueba que
 * no hay errores de consola, que no hay desbordamiento horizontal y que axe no
 * encuentra problemas de accesibilidad graves o críticos (WCAG 2.1 A y AA).
 */
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import AxeBuilder from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';
import { authenticator } from 'otplib';

const API = process.env.BO_E2E_API ?? 'http://localhost:8788';
const STATE = process.env.BO_E2E_STATE ?? join(tmpdir(), `vtm-bo-e2e-${API.replace(/\W+/g, '_')}.json`);
const PASSWORD = 'VolutrainMed-2026!';

function secrets(): Record<string, string> {
  return existsSync(STATE) ? JSON.parse(readFileSync(STATE, 'utf8')) : {};
}

async function login(page: Page, email: string) {
  await page.goto('/acceso');
  await page.getByLabel('Correo').fill(email);
  await page.getByLabel('Contraseña').fill(PASSWORD);
  await page.getByRole('button', { name: 'Continuar' }).click();
  const enrol = page.getByRole('heading', { name: 'Configura el segundo factor' });
  const verify = page.getByRole('heading', { name: 'Verificación en dos pasos' });
  await expect(enrol.or(verify)).toBeVisible();
  if (await enrol.isVisible()) {
    const secret = (await page.getByTestId('totp-secret').innerText()).trim();
    await expect(page.getByAltText('Código QR para la aplicación de autenticación')).toBeVisible();
    await page.getByLabel('Código de seis cifras').fill(authenticator.generate(secret));
    await page.getByRole('button', { name: 'Activar y entrar' }).click();
    await expect(page.getByRole('list', { name: 'Códigos de recuperación' }).getByRole('listitem')).toHaveCount(8);
    writeFileSync(STATE, JSON.stringify({ ...secrets(), [email]: secret }, null, 2));
    await page.getByRole('button', { name: /He guardado los códigos/ }).click();
  } else {
    const secret = secrets()[email];
    expect(secret, `secreto TOTP de ${email} (vuelve a sembrar la API con --reset)`).toBeTruthy();
    await page.getByLabel('Código de verificación').fill(authenticator.generate(secret!));
    await page.getByRole('button', { name: 'Verificar' }).click();
  }
  await expect(page.getByRole('navigation', { name: 'Secciones' })).toBeVisible();
}

const SCREENS: { path: string; name: string; ready: string | RegExp }[] = [
  { path: '/', name: 'Panel de control', ready: 'Panel de control' },
  { path: '/estructura', name: 'Estructura', ready: 'Sectores e itinerarios' },
  { path: '/biblioteca', name: 'Biblioteca', ready: 'Biblioteca' },
  { path: '/plantillas/tpl-f-mg-ug', name: 'Editor de plantilla', ready: 'Miligramos a microgramos' },
  { path: '/preguntas/q-v-t3-volumen', name: 'Editor de pregunta', ready: /Orden: volumen por peso/ },
  { path: '/vista-previa/tpl-f-mg-ug', name: 'Vista previa con voz', ready: 'Vista previa con voz' },
  { path: '/tipos', name: 'Tipos de ejercicio', ready: 'Tipos de ejercicio' },
  { path: '/importar', name: 'Importación', ready: 'Importación masiva' },
  { path: '/revision', name: 'Bandeja de revisión', ready: 'Revisión experta' },
  { path: '/revision/tpl-f-mg-ug', name: 'Ficha de revisión', ready: /Miligramos a microgramos/ },
  { path: '/publicacion', name: 'Publicación', ready: /Versión 2026/ },
  { path: '/usuarios', name: 'Usuarios', ready: 'Usuarios' },
  { path: '/cuentas', name: 'Cuentas y roles', ready: 'Cuentas y roles' },
  { path: '/organizaciones', name: 'Organizaciones', ready: 'Organizaciones' },
  { path: '/consultas', name: 'Consultas', ready: 'Consultas' },
  { path: '/logros', name: 'Logros', ready: 'Logros' },
  { path: '/ligas', name: 'Ligas', ready: 'Ligas' },
  { path: '/analitica', name: 'Analítica', ready: 'Analítica de contenido' },
  { path: '/analitica/tpl-f-mg-ug', name: 'Analítica de un elemento', ready: 'Miligramos a microgramos' },
  { path: '/catalogos', name: 'Catálogos', ready: 'Catálogos de unidades y voz' },
  { path: '/auditoria', name: 'Auditoría', ready: 'Registro de auditoría' },
];

async function settle(page: Page) {
  await page.waitForLoadState('networkidle');
  await expect(page.locator('.skeleton')).toHaveCount(0);
}

async function check(page: Page, label: string, consoleErrors: string[]) {
  await settle(page);
  const overflow = await page.evaluate(() => {
    const client = document.documentElement.clientWidth;
    const scroll = document.documentElement.scrollWidth;
    const culprits: string[] = [];
    if (scroll > client + 1) {
      const clipped = (el: Element): boolean => { for (let p = el.parentElement; p; p = p.parentElement) { const o = getComputedStyle(p).overflowX; if (o !== 'visible') return true; } return false; };
      for (const el of Array.from(document.querySelectorAll('body *'))) {
        const r = el.getBoundingClientRect();
        if (r.width > 0 && r.right > client + 1 && !clipped(el) && !Array.from(el.children).some((c) => c.getBoundingClientRect().right > client + 1)) {
          culprits.push(`${el.tagName.toLowerCase()}.${String(el.className).replace(/\s+/g, '.')}→${Math.round(r.right)}`);
        }
      }
    }
    return { scroll, client, culprits: culprits.slice(0, 5) };
  });
  expect.soft(overflow.scroll, `${label}: desbordamiento horizontal (${overflow.scroll} > ${overflow.client}) por ${overflow.culprits.join(', ')}`).toBeLessThanOrEqual(overflow.client + 1);
  await expect.soft(page.locator('.notice.err[role="alert"]'), `${label}: error en pantalla`).toHaveCount(0);
  const axe = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
  const serious = axe.violations.filter((v) => process.env.BO_AXE_ALL === '1' || v.impact === 'serious' || v.impact === 'critical')
    .map((v) => `${v.id} (${v.nodes.length}): ${v.nodes.slice(0, 3).map((n) => n.target.join(' ')).join(' | ')}`);
  expect.soft(serious, `${label}: accesibilidad`).toEqual([]);
  expect.soft(consoleErrors.splice(0), `${label}: errores de consola`).toEqual([]);
}

test('acceso con doble factor y recorrido de las pantallas principales', async ({ page }, info) => {
  const consoleErrors: string[] = [];
  page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(m.text()); });
  page.on('pageerror', (e) => consoleErrors.push(`excepción: ${e.message}`));

  await page.goto('/acceso');
  await check(page, 'Acceso', consoleErrors);
  await login(page, 'superadmin@volutrainmed.test');

  for (const s of SCREENS) {
    await test.step(`${s.name} (${info.project.name})`, async () => {
      // Navegación dentro de la aplicación (sin recargar): la sesión vive en el almacenamiento local.
      await page.goto(s.path);
      await expect(page.getByRole('heading', { level: 1, name: s.ready })).toBeVisible();
      await check(page, s.name, consoleErrors);
    });
  }

  await test.step('pestañas y diálogos con contenido propio', async () => {
    await page.goto('/catalogos');
    for (const tab of ['Instrumentos', 'Habilidades', 'Especies', /Voz/, 'Anuncios propios']) {
      await page.getByRole('tab', { name: tab }).click();
      await check(page, `Catálogos · ${String(tab)}`, consoleErrors);
    }
    await page.getByRole('button', { name: 'Nuevo anuncio' }).click();
    await check(page, 'Catálogos · diálogo de anuncio', consoleErrors);
    await page.keyboard.press('Escape');

    await page.goto('/plantillas/tpl-f-mg-ug');
    for (const tab of [/Variables/, /Enunciado/, /Fórmula y respuesta/, /Restricciones/, /Explicación y niveles/]) {
      await page.getByRole('tab', { name: tab }).click();
      await check(page, `Plantilla · ${String(tab)}`, consoleErrors);
    }
    await page.getByRole('button', { name: 'Generar 20 variantes de muestra' }).click();
    await expect(page.getByTestId('variant-row')).toHaveCount(20);
    await page.getByRole('button', { name: 'Prueba masiva (1000)' }).click();
    await expect(page.getByRole('region', { name: 'Informe de la prueba masiva' })).toBeVisible();
    await check(page, 'Plantilla · panel de pruebas', consoleErrors);

    await page.goto('/vista-previa/tpl-f-mg-ug');
    await page.getByRole('button', { name: 'Manos libres' }).click();
    await page.getByLabel('Simular respuesta').fill('doscientos cincuenta');
    await page.getByRole('button', { name: 'Interpretar' }).click();
    await expect(page.getByTestId('interpretacion')).toBeVisible();
    await check(page, 'Vista previa · manos libres', consoleErrors);

    await page.goto('/estructura');
    await page.getByRole('button', { name: /^Enfermería/ }).first().click();
    await check(page, 'Estructura · ficha de un nodo', consoleErrors);
  });

  await test.step('el teclado llega al contenido y el foco es visible', async () => {
    await page.goto('/biblioteca');
    await settle(page);
    await page.keyboard.press('Tab');
    const outline = await page.evaluate(() => { const el = document.activeElement as HTMLElement; const cs = getComputedStyle(el); return { tag: el.tagName, width: cs.outlineWidth, style: cs.outlineStyle }; });
    expect.soft(outline.tag, 'el primer tabulador enfoca un control').not.toBe('BODY');
    expect.soft(outline.style !== 'none' && outline.width !== '0px', `foco visible en ${outline.tag}`).toBeTruthy();
  });

  await test.step('cierre de sesión', async () => {
    await page.getByRole('button', { name: 'Cerrar sesión' }).click();
    await expect(page.getByRole('heading', { name: 'Acceso' })).toBeVisible();
  });
});

test('un rol sin permiso no entra por la dirección directa', async ({ page }) => {
  await login(page, 'soporte@volutrainmed.test');
  await expect(page.getByRole('navigation', { name: 'Secciones' }).getByRole('link', { name: /Publicación/ })).toHaveCount(0);
  await page.goto('/publicacion');
  await expect(page.getByText('No tienes acceso a esta sección')).toBeVisible();
});
