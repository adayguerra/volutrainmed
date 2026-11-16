# Fuentes de diseño de VolutrainMed

Este directorio conserva, sin modificar, las dos fuentes de diseño facilitadas para construir el producto.

| Carpeta | Origen | Contenido |
| --- | --- | --- |
| `claude-artifact/` | Lienzo de diseño en claude.ai (`9JAjEkHkp33GcUy8vRYjFn`) | 95 pantallas `.dc.html`: móvil (M01 = `Main`, M02–M61), tablet (T01–T08), back office (B01–B27) y sistema (S01), más la hoja de tokens y componentes (`tokens-components.css`) y el índice del lienzo (`canvas.json`) |
| `stitch/` | Proyecto Stitch `6253324110179111715` («UI UX Pro Max Suite») | Sistema de diseño «VolutrainMed Pro Max» (`DESIGN.md`) y el código HTML de 18 pantallas (`screens/`) |

La definición funcional que acompaña al proyecto Stitch está en `../docs/definicion-funcional.md`.

## Pantallas de Stitch

| Archivo | Pantalla | Equivalente en el lienzo de Claude |
| --- | --- | --- |
| `S01-inicio.html` | Inicio con ruta de aprendizaje | M12 |
| `S02-sesion-t1.html` | Sesión T1 con teclado propio y análisis dimensional | M17 |
| `S03-manos-libres.html` | Manos libres: escucha y confirmación | M43–M44 |
| `S04-practicar.html` | Practicar: repaso, manos libres | M14 |
| `S05-progreso.html` | Progreso y precisión | M50 |
| `S06-bienvenida.html` | Bienvenida | M01 |
| `S07-alta-sector.html` | Alta, paso 1 de 4: sector | M04 |
| `S08-detalle-unidad.html` | Detalle de unidad con guía rápida | M13 |
| `S09-prueba-nivel.html` | Prueba de nivel | M08 |
| `S10-sesion-t2-t6.html` | Selección única y estimación | M19, M21 |
| `S11-sesion-t3.html` | Ordenar pasos | M20 |
| `S12-sesion-t7.html` | Conversión relámpago | M22 |
| `S13-t9-jeringa-fase3.html` | Marcar en la jeringa (T9, fase 3: fuera de alcance de los cuatro cambios) | — |
| `S14-sesion-t8-encadenado.html` | Caso encadenado (T8, fase 2) | — |
| `S15-fin-sesion.html` | Fin de sesión | M30 |
| `S16-liga.html` | Liga semanal | M52 |
| `S17-paquetes-sin-conexion.html` | Descargas y modo sin conexión | M60 |
| `S18-perfil.html` | Perfil | M54 |

## Decisión de diseño

- **Identidad visual: Stitch.** Colores (primario `#0D5C75`, secundario `#088395`, verificación `#059669`, neutro `#0F172A`, lienzo `#F4FAFB`, borde `#C5D9E0`), tipografías (Space Grotesk para títulos, Noto Sans para cuerpo y Space Mono para cifras), radios y espaciados de `stitch/DESIGN.md`. El tema oscuro, que Stitch no define, se deriva de los valores oscuros del lienzo de Claude y de la definición funcional, con contraste comprobado.
- **Inventario de pantallas, flujos y textos: lienzo de Claude**, que sigue la definición funcional y los specs.
- **Los specs mandan.** Donde una pantalla de Stitch contradice el OpenSpec se sigue el OpenSpec. Casos detectados: nombres reales en la liga (se usan alias), pacientes no rotulados como simulados, números de colegiado y hospital en el perfil, mensajes de uso en quirófano o cabina, puntos decimales y nombres comerciales. Ninguno de esos textos se reproduce.
- **Iconos**: Material Symbols (como Stitch) en Flutter y en el back office.
