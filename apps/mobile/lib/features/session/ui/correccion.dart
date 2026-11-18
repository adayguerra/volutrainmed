import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../domain/motor_sesion.dart';

/// Veredicto y explicación paso a paso (answer-grading, M26–M28, T03).

/// Palabra del veredicto: siempre con icono y texto, nunca solo color.
String palabraVeredicto(Verdict v) => switch (v) {
      Verdict.correct => 'Correcto',
      Verdict.correctNote => 'Correcta con observación',
      Verdict.dontKnow => 'Resolución guiada',
      _ => 'Incorrecto',
    };

/// Texto que anuncia el lector de pantalla al corregir.
String anuncioVeredicto(ResultadoEjercicio r) {
  final buena = _lecturaCorrecta(r);
  return switch (r.verdict) {
    Verdict.correct => 'Correcto. $buena',
    Verdict.correctNote => 'Correcta con observación. ${r.nota ?? ''}'.trim(),
    Verdict.dontKnow => 'No lo sé. La respuesta correcta es $buena',
    _ => 'Incorrecto. La respuesta correcta es $buena',
  };
}

String _lecturaCorrecta(ResultadoEjercicio r) {
  final a = r.ejercicio.variante.answer;
  if (a != null && r.ejercicio.bloque == 'numeric_unit') return lecturaCantidad(a.value, a.unit);
  return r.correcta;
}

String? etiquetaError(String? code) {
  if (code == null || code == 'E0') return null;
  final l = errorLabels[code];
  return l == null ? code : '$code · $l';
}

/// Banda de veredicto con la respuesta correcta, la nota y el diagnóstico.
class BandaVeredicto extends StatelessWidget {
  const BandaVeredicto({super.key, required this.resultado});
  final ResultadoEjercicio resultado;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final r = resultado;
    final (fondo, frente, icono) = switch (r.verdict) {
      Verdict.correct => (c.exitoTinte, c.exito, Symbols.check_circle),
      Verdict.correctNote => (c.avisoTinte, c.aviso, Symbols.info),
      Verdict.dontKnow => (c.superficie2, c.texto, Symbols.lightbulb),
      _ => (c.errorTinte, c.errorFuerte, Symbols.cancel),
    };
    final a = r.ejercicio.variante.answer;
    final numerico = r.ejercicio.bloque == 'numeric_unit' && a != null;
    final error = etiquetaError(r.errorCode);
    return Semantics(
      container: true,
      liveRegion: true,
      label: anuncioVeredicto(r),
      child: Container(
        key: const ValueKey('banda-veredicto'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, color: frente, fill: 1, size: 28),
              const SizedBox(width: 10),
              Flexible(child: Text(palabraVeredicto(r.verdict), style: context.textos.titleLarge?.copyWith(color: frente))),
            ]),
            if (!r.acierto) ...[
              const SizedBox(height: 10),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                Text('Era', style: context.textos.bodyMedium),
                if (numerico) Cantidad(a.value, a.unit, tamano: 22) else Text(r.correcta, style: estiloCifra(context, size: 18)),
              ]),
              if (r.valor != null && numerico && r.verdict != Verdict.dontKnow) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  Text('Tu respuesta', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                  Cantidad(r.valor!, r.unidad ?? a.unit, tamano: 16, peso: FontWeight.w400, color: c.atenuado),
                ]),
              ],
            ] else if (numerico) ...[
              const SizedBox(height: 6),
              Cantidad(a.value, a.unit, tamano: 22),
            ],
            if (r.nota != null) ...[
              const SizedBox(height: 8),
              Text(r.nota!, key: const ValueKey('nota-veredicto'), style: context.textos.bodyMedium),
            ],
            if (r.detalleSerie != null) ...[
              const SizedBox(height: 8),
              Text('${r.detalleSerie!.where((x) => x).length} de ${r.detalleSerie!.length} conversiones bien', style: context.textos.bodyMedium),
            ],
            if (r.diagnostico != null && r.verdict == Verdict.incorrect) ...[
              const SizedBox(height: 10),
              Container(
                key: const ValueKey('diagnostico'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.superficie, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (error != null) Text(error, style: context.textos.labelLarge?.copyWith(color: c.errorFuerte)),
                  Text(r.diagnostico!, style: context.textos.bodyMedium),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de pasos con la operación, las unidades que se cancelan, el paso del
/// desvío y la comprobación de plausibilidad.
class PasosExplicacion extends StatelessWidget {
  const PasosExplicacion({super.key, required this.variante, this.pasoDesvio});
  final Variant variante;
  final int? pasoDesvio;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Column(
      key: const ValueKey('pasos-explicacion'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TituloSeccion('Cómo se hace'),
        for (final p in variante.steps) ...[
          _Paso(paso: p, desvio: p.n == pasoDesvio),
          const SizedBox(height: 8),
        ],
        if (variante.plausibility.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.primarioTinte, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.fact_check, color: c.primario),
              const SizedBox(width: 10),
              Expanded(child: Text(variante.plausibility, style: context.textos.bodyMedium)),
            ]),
          ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.paso, required this.desvio});
  final ExplanationStep paso;
  final bool desvio;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final resultado = paso.result.unit.isEmpty ? formatEs(paso.result.value) : formatQty(paso.result.value, paso.result.unit);
    final cancelan = paso.cancelled.isEmpty ? null : (paso.cancelledSpoken ?? '${paso.cancelled.join(', ')} se cancelan');
    return Semantics(
      label: 'Paso ${paso.n}. ${paso.text}. ${paso.operation} = $resultado.${cancelan == null ? '' : ' $cancelan.'}${desvio ? ' Aquí te desviaste.' : ''}',
      excludeSemantics: true,
      child: Container(
        key: desvio ? const ValueKey('paso-desvio') : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.superficie,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: desvio ? c.error : c.borde, width: desvio ? 2 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: desvio ? c.errorTinte : c.superficie2,
            child: Text('${paso.n}', style: context.textos.labelMedium?.copyWith(color: desvio ? c.errorFuerte : c.texto)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(paso.text, style: context.textos.titleSmall),
              const SizedBox(height: 4),
              Text('${paso.operation} = $resultado', style: estiloCifra(context, size: 15, weight: FontWeight.w500)),
              if (paso.cancelled.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  for (final u in paso.cancelled)
                    Text(u, style: estiloCifra(context, size: 14, weight: FontWeight.w400, color: c.atenuado).copyWith(decoration: TextDecoration.lineThrough)),
                  Text('se cancelan', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                ]),
              ],
              if (desvio) ...[
                const SizedBox(height: 6),
                Text('Aquí te desviaste', style: context.textos.labelLarge?.copyWith(color: c.errorFuerte)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Hoja con la explicación a demanda («Ver cómo se hace»): se cierra con el
/// gesto o con el botón «Cerrar».
Future<void> mostrarHojaExplicacion(BuildContext context, ResultadoEjercicio r) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(children: [
              Expanded(child: Text('Cómo se hace', style: ctx.textos.titleLarge)),
              IconButton(
                key: const ValueKey('cerrar-hoja'),
                tooltip: 'Cerrar',
                icon: const Icon(Symbols.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ]),
          ),
          Expanded(
            child: ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
              PasosExplicacion(variante: r.ejercicio.variante, pasoDesvio: r.pasoDesvio),
            ]),
          ),
        ]),
      ),
    );
