import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/reloj.dart';
import '../../home/ui/componentes_inicio.dart';
import '../../review/ui/pantalla_repaso.dart' show nombrePlantilla;
import '../domain/projections.dart';

/// Progreso y detalle de habilidad (M50–M51, T05). Todo se calcula en el
/// dispositivo a partir de los intentos: funciona sin conexión.

enum PeriodoProgreso { siete, treinta, todo }

extension on PeriodoProgreso {
  String get etiqueta => switch (this) { PeriodoProgreso.siete => '7 días', PeriodoProgreso.treinta => '30 días', PeriodoProgreso.todo => 'Todo' };
  int? get dias => switch (this) { PeriodoProgreso.siete => 7, PeriodoProgreso.treinta => 30, PeriodoProgreso.todo => null };
}

/// Cifras del periodo: precisión, tiempo frente al objetivo y días activos.
class CifrasPeriodo {
  const CifrasPeriodo({required this.precision, required this.tiempoObjetivo, required this.intentos});
  final double? precision;
  final double? tiempoObjetivo;
  final int intentos;

  static CifrasPeriodo de(Proyeccion p, PeriodoProgreso periodo) {
    final hoy = diaLocal(p.now);
    final desde = periodo.dias == null ? null : DateTime(hoy.year, hoy.month, hoy.day - (periodo.dias! - 1));
    final l = p.intentos.where((a) => cuentaParaDominio(a) && (desde == null || !diaLocal(a.deviceTime).isBefore(desde))).toList();
    if (l.isEmpty) return const CifrasPeriodo(precision: null, tiempoObjetivo: null, intentos: 0);
    final objetivo = l.fold<int>(0, (s, a) => s + a.targetMs);
    return CifrasPeriodo(
      precision: l.where((a) => a.correct).length / l.length,
      tiempoObjetivo: objetivo <= 0 ? null : l.fold<int>(0, (s, a) => s + a.responseMs) / objetivo,
      intentos: l.length,
    );
  }
}

class PantallaProgreso extends ConsumerStatefulWidget {
  const PantallaProgreso({super.key});
  @override
  ConsumerState<PantallaProgreso> createState() => _PantallaProgresoState();
}

class _PantallaProgresoState extends ConsumerState<PantallaProgreso> {
  PeriodoProgreso _periodo = PeriodoProgreso.siete;
  String? _seleccionada;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(proyeccionProvider);
    final contenido = ref.watch(contenidoProvider).value;
    if (p == null || contenido == null) return const Scaffold(body: SafeArea(child: Esqueleto()));
    final dos = ClaseAncho.de(context).dosPaneles;
    final skills = _habilidadesVisibles(p, contenido);
    final seleccionada = _seleccionada ?? (skills.isEmpty ? null : skills.first.id);

    final lista = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Semantics(header: true, child: Text('Progreso', style: context.textos.headlineSmall))),
                const DistintivoSinConexion(),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<PeriodoProgreso>(
                segments: [for (final x in PeriodoProgreso.values) ButtonSegment(value: x, label: Text(x.etiqueta))],
                selected: {_periodo},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _periodo = s.first),
              ),
              const SizedBox(height: 12),
              if (p.resumen.datosInsuficientes) ...[
                const Aviso(ResumenGlobal.mensajeDatosInsuficientes, icono: Symbols.insights, tono: TonoEtiqueta.primario),
                const SizedBox(height: 12),
              ],
              _Cifras(proyeccion: p, periodo: _periodo),
              const TituloSeccion('Habilidades'),
              for (final s in skills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tarjeta(
                    key: ValueKey('habilidad-${s.id}'),
                    seleccionada: dos && s.id == seleccionada,
                    onTap: () => dos ? setState(() => _seleccionada = s.id) : context.push(Rutas.habilidad(s.id)),
                    semantica: '${s.id} · ${s.name}. ${p.estadoHabilidad(s.id).etiqueta}',
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text('${s.id} · ${s.name}', style: context.textos.bodyMedium),
                        Etiqueta(p.estadoHabilidad(s.id).etiqueta, tono: tonoHabilidad(p.estadoHabilidad(s.id))),
                      ],
                    ),
                  ),
                ),
              TituloSeccion('Actividad · 5 semanas'),
              CalendarioActividad(calendario: p.resumen.calendario),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: DosPaneles(
          proporcion: 0.45,
          principal: lista,
          secundario: dos && seleccionada != null
              ? SingleChildScrollView(padding: const EdgeInsets.all(24), child: DetalleHabilidad(skillId: seleccionada))
              : null,
        ),
      ),
    );
  }
}

List<Skill> _habilidadesVisibles(Proyeccion p, ContenidoCargado c) {
  final usadas = <String>{for (final it in c.itinerarios.values) for (final u in it.units) ...u.skills, ...p.habilidades.keys};
  return c.global.skills.where((s) => usadas.contains(s.id)).toList();
}

class _Cifras extends StatelessWidget {
  const _Cifras({required this.proyeccion, required this.periodo});
  final Proyeccion proyeccion;
  final PeriodoProgreso periodo;
  @override
  Widget build(BuildContext context) {
    final cf = CifrasPeriodo.de(proyeccion, periodo);
    Widget celda(String clave, String titulo, String valor, String? pie) => SizedBox(
          width: 150,
          child: Tarjeta(
            semantica: '$titulo: $valor${pie == null ? '' : ', $pie'}',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: context.textos.labelMedium?.copyWith(color: context.vtm.atenuado)),
              Text(valor, key: ValueKey(clave), style: estiloCifra(context, size: 22)),
              if (pie != null) Text(pie, style: context.textos.bodySmall),
            ]),
          ),
        );
    final t = cf.tiempoObjetivo;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      celda('cifra-precision', 'Precisión', cf.precision == null ? '—' : porcentaje(cf.precision!), '${cf.intentos} ejercicios'),
      celda('cifra-tiempo', 'Tu ritmo', t == null ? '—' : textoRitmo(t), t == null ? 'sin datos todavía' : 'que el tiempo objetivo'),
      celda('cifra-dias', 'Días activos', '${proyeccion.resumen.diasActivosSemana}/7', 'esta semana'),
    ]);
  }
}

/// Calendario de actividad de 35 días con resumen en texto.
class CalendarioActividad extends StatelessWidget {
  const CalendarioActividad({super.key, required this.calendario});
  final Map<DateTime, int> calendario;
  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final dias = calendario.keys.toList()..sort();
    final activos = calendario.values.where((m) => m > 0).length;
    final maximo = calendario.values.fold<int>(0, math.max);
    final resumen = '${plural(activos, 'día', 'días')} con práctica en las últimas cinco semanas';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: resumen,
          excludeSemantics: true,
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            for (final d in dias)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: calendario[d]! <= 0 ? c.superficie2 : Color.lerp(c.primarioTinte, c.primario, maximo == 0 ? 0 : 0.3 + 0.7 * calendario[d]! / maximo),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(resumen, key: const ValueKey('resumen-actividad'), style: context.textos.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle de habilidad (M51)
// ---------------------------------------------------------------------------

class PantallaHabilidad extends ConsumerWidget {
  const PantallaHabilidad({super.key, required this.skillId});
  final String skillId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(skillId)),
        body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: AnchoMaximo(child: DetalleHabilidad(skillId: skillId)))),
      );
}

class DetalleHabilidad extends ConsumerStatefulWidget {
  const DetalleHabilidad({super.key, required this.skillId});
  final String skillId;
  @override
  ConsumerState<DetalleHabilidad> createState() => _DetalleHabilidadState();
}

class _DetalleHabilidadState extends ConsumerState<DetalleHabilidad> {
  bool _tabla = false;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(proyeccionProvider);
    final contenido = ref.watch(contenidoProvider).value;
    if (p == null || contenido == null) return const SizedBox.shrink();
    final c = context.vtm;
    final id = widget.skillId;
    final est = p.estadisticas(id);
    final estado = p.estadoHabilidad(id);
    final info = p.habilidades[id];
    final objetivoMs = info?.medianaObjetivoMs;

    return Column(
      key: ValueKey('detalle-habilidad-$id'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(contenido.global.skillName(id), style: context.textos.headlineSmall)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [Etiqueta(estado.etiqueta, tono: tonoHabilidad(estado)), Etiqueta(id)]),
        const SizedBox(height: 12),
        Text(est.resumen, key: const ValueKey('resumen-habilidad'), style: context.textos.bodyLarge),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('ver-tabla'),
            onPressed: () => setState(() => _tabla = !_tabla),
            icon: Icon(_tabla ? Symbols.bar_chart : Symbols.table),
            label: Text(_tabla ? 'Ver gráficas' : 'Ver tabla'),
          ),
        ),
        const TituloSeccion('Precisión semanal'),
        if (est.semanas.isEmpty)
          Text('Sin datos todavía', style: TextStyle(color: c.atenuado))
        else if (_tabla)
          _TablaSemanas(semanas: est.semanas, objetivoMs: objetivoMs)
        else
          _Barras(
            clave: 'grafica-precision',
            etiquetas: [for (var i = 0; i < est.semanas.length; i++) 'S${i + 1}'],
            valores: [for (final s in est.semanas) s.precision],
            textos: [for (final s in est.semanas) porcentaje(s.precision)],
            resumen: est.resumen,
          ),
        const TituloSeccion('Tiempo mediano'),
        if (est.semanas.isNotEmpty && !_tabla)
          _Barras(
            clave: 'grafica-tiempo',
            etiquetas: [for (var i = 0; i < est.semanas.length; i++) 'S${i + 1}'],
            valores: () {
              final maxMs = [...est.semanas.map((s) => s.medianaMs), objetivoMs ?? 0].reduce(math.max);
              return [for (final s in est.semanas) maxMs <= 0 ? 0.0 : s.medianaMs / maxMs];
            }(),
            textos: [for (final s in est.semanas) '${(s.medianaMs / 1000).round()} s'],
            resumen: 'Tiempo mediano de la última semana: ${(est.semanas.last.medianaMs / 1000).round()} s'
                '${objetivoMs == null ? '' : ', objetivo ${(objetivoMs / 1000).round()} s'}',
          ),
        if (est.semanas.isNotEmpty)
          Text(
            'Última semana: ${(est.semanas.last.medianaMs / 1000).round()} s${objetivoMs == null ? '' : ' · objetivo ${(objetivoMs / 1000).round()} s'}',
            style: context.textos.bodySmall,
          ),
        const TituloSeccion('Errores por tipo'),
        if (est.erroresPorTipo.isEmpty)
          Text('Sin errores registrados', style: TextStyle(color: c.atenuado))
        else
          for (final e in est.erroresPorTipo)
            _FilaBarra(texto: '${e.key} · ${errorLabels[e.key] ?? 'Sin clasificar'}', valor: e.value, maximo: est.erroresPorTipo.first.value),
        if (est.plantillasMasFalladas.isNotEmpty) ...[
          const TituloSeccion('Plantillas más falladas'),
          for (final e in est.plantillasMasFalladas.take(5))
            _FilaBarra(texto: nombrePlantilla(contenido, e.key), valor: e.value, maximo: est.plantillasMasFalladas.first.value),
        ],
      ],
    );
  }
}

/// Gráfica de barras con frase de resumen para lector de pantalla.
class _Barras extends StatelessWidget {
  const _Barras({required this.clave, required this.etiquetas, required this.valores, required this.textos, required this.resumen});
  final String clave;
  final List<String> etiquetas;
  final List<double> valores;
  final List<String> textos;
  final String resumen;
  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Semantics(
      label: resumen,
      excludeSemantics: true,
      child: SizedBox(
        key: ValueKey(clave),
        height: 140,
        child: CustomPaint(
          painter: _PintorBarras(valores: valores, color: c.primario, fondo: c.superficie2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(children: [
                for (var i = 0; i < etiquetas.length; i++)
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${textos[i]}\n${etiquetas[i]}', textAlign: TextAlign.center, style: context.textos.labelSmall),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorBarras extends CustomPainter {
  _PintorBarras({required this.valores, required this.color, required this.fondo});
  final List<double> valores;
  final Color color;
  final Color fondo;
  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    const pie = 36.0;
    final alto = size.height - pie;
    final ancho = size.width / valores.length;
    for (var i = 0; i < valores.length; i++) {
      final x = i * ancho + ancho * 0.25;
      final w = ancho * 0.5;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, w, alto), const Radius.circular(4)), Paint()..color = fondo);
      final h = alto * valores[i].clamp(0, 1);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, alto - h, w, h), const Radius.circular(4)), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_PintorBarras old) => old.valores != valores || old.color != color;
}

/// Vista alternativa en tabla de las gráficas semanales.
class _TablaSemanas extends StatelessWidget {
  const _TablaSemanas({required this.semanas, required this.objetivoMs});
  final List<PuntoSemanal> semanas;
  final double? objetivoMs;
  @override
  Widget build(BuildContext context) {
    final estilo = context.textos.bodySmall;
    final cab = context.textos.labelMedium;
    TableRow fila(List<String> celdas, TextStyle? s) => TableRow(children: [for (final x in celdas) Padding(padding: const EdgeInsets.all(6), child: Text(x, style: s))]);
    return Table(
      key: const ValueKey('tabla-habilidad'),
      border: TableBorder(horizontalInside: BorderSide(color: context.vtm.borde)),
      children: [
        fila(['Semana', 'Precisión', 'Tiempo mediano', 'Ejercicios'], cab),
        for (final (i, s) in semanas.indexed)
          fila(['S${i + 1} · ${s.semana.day}/${s.semana.month}', porcentaje(s.precision), '${(s.medianaMs / 1000).round()} s', '${s.intentos}'], estilo),
        if (objetivoMs != null) fila(['Objetivo', '', '${(objetivoMs! / 1000).round()} s', ''], estilo),
      ],
    );
  }
}

class _FilaBarra extends StatelessWidget {
  const _FilaBarra({required this.texto, required this.valor, required this.maximo});
  final String texto;
  final int valor;
  final int maximo;
  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Semantics(
      label: '$texto: $valor',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text(texto, style: context.textos.bodySmall)), Text('$valor', style: estiloCifra(context, size: 14))]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: maximo == 0 ? 0 : valor / maximo, minHeight: 6, color: c.primario, backgroundColor: c.superficie2),
          ),
        ]),
      ),
    );
  }
}

/// Ritmo frente al tiempo objetivo, en palabras: con una razón de 0,67 se
/// responde un 33 % más rápido que el objetivo.
String textoRitmo(double razon) {
  final pct = ((1 - razon).abs() * 100).round();
  if (pct == 0) return 'Igual';
  return razon < 1 ? '$pct % más rápido' : '$pct % más lento';
}
