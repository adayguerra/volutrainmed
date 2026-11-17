import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/tema.dart';

/// Piezas comunes de las pantallas de perfil y ajustes.

/// Fila de ajuste con icono, título, detalle y flecha.
class FilaAjuste extends StatelessWidget {
  const FilaAjuste({super.key, required this.icono, required this.titulo, this.detalle, this.onTap, this.final_});
  final IconData icono;
  final String titulo;
  final String? detalle;
  final VoidCallback? onTap;
  final Widget? final_;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(icono, color: c.primario),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: context.textos.titleSmall),
                      if (detalle != null) Text(detalle!, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                    ],
                  ),
                ),
                if (final_ != null) final_! else if (onTap != null) Icon(Symbols.chevron_right, color: c.atenuado),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interruptor con título y explicación (área táctil de toda la fila).
class FilaInterruptor extends StatelessWidget {
  const FilaInterruptor({super.key, required this.titulo, this.detalle, required this.valor, required this.alCambiar});
  final String titulo;
  final String? detalle;
  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(titulo, style: context.textos.titleSmall),
          subtitle: detalle == null ? null : Text(detalle!, style: context.textos.bodySmall?.copyWith(color: context.vtm.atenuado)),
          value: valor,
          onChanged: alCambiar,
        ),
      );
}

/// Bloque con título de sección y tarjeta.
class BloqueAjustes extends StatelessWidget {
  const BloqueAjustes({super.key, this.titulo, required this.hijos});
  final String? titulo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titulo != null)
            Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(titulo!.toUpperCase(), style: context.textos.labelSmall?.copyWith(color: c.atenuado)),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(color: c.superficie, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.borde)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < hijos.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.borde),
                  hijos[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de opciones excluyentes como botones segmentados que se adaptan al
/// ancho (y al texto ampliado) envolviendo en varias líneas.
class OpcionesSegmentadas<T> extends StatelessWidget {
  const OpcionesSegmentadas({super.key, required this.opciones, required this.valor, required this.alCambiar, this.etiqueta});
  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> alCambiar;
  final String? etiqueta;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (etiqueta != null) ...[Text(etiqueta!, style: context.textos.titleSmall), const SizedBox(height: 8)],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in opciones.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: e.key == valor,
                  onSelected: (_) => alCambiar(e.key),
                  selectedColor: c.primarioTinte,
                  labelStyle: context.textos.labelLarge?.copyWith(color: e.key == valor ? c.primario : c.texto),
                  showCheckmark: true,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Andamio de una pantalla de ajustes: barra con título y lista centrada con
/// el ancho de lectura en tablet.
class AndamioAjustes extends StatelessWidget {
  const AndamioAjustes({super.key, required this.titulo, required this.hijos, this.acciones});
  final String titulo;
  final List<Widget> hijos;
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo), actions: acciones),
        body: AnchoMaximo(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: hijos),
        ),
      );
}

/// «hoy, 19:42», «ayer, 08:05» o «12 nov, 10:00».
String fechaRelativa(DateTime t, DateTime ahora) {
  final l = t.toLocal();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  final dia = DateTime(l.year, l.month, l.day);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final d = hoy.difference(dia).inDays;
  if (d == 0) return 'hoy, $hm';
  if (d == 1) return 'ayer, $hm';
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
  return '${l.day} ${meses[l.month - 1]}, $hm';
}

/// Tamaño legible con coma decimal: «8,1 MB», «640 kB».
String tamanoLegible(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} kB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}
