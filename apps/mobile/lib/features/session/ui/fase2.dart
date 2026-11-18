import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../../grading/domain/grading.dart';
import '../domain/motor_sesion.dart';

/// Respuestas de los tipos de la fase 2 (add-growth-features), dibujadas por
/// el mismo intérprete de bloques: completar el planteamiento (T4), detectar
/// el error (T5), emparejar (T10) y caso encadenado (T8). Todo se hace con
/// toques: no hace falta arrastrar.

final _hueco = RegExp(r'\{(g\d+)\}');

/// T4: operación con huecos. Se toca una ficha y después un hueco; tocar un
/// hueco lleno lo vacía.
class RespuestaHuecos extends StatelessWidget {
  const RespuestaHuecos({super.key, required this.datos, required this.colocadas, required this.fichaSeleccionada, required this.alTocarFicha, required this.alTocarHueco, this.huecosMal = const []});
  final GapFill datos;
  final Map<String, String> colocadas;
  final String? fichaSeleccionada;
  final ValueChanged<String> alTocarFicha;
  final ValueChanged<String> alTocarHueco;
  final List<String> huecosMal;

  @override
  Widget build(BuildContext context) {
    final usadas = colocadas.values.toList();
    final libres = [...datos.tiles];
    for (final u in usadas) {
      libres.remove(u);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Toca una ficha y después el hueco. Sobran fichas.', style: context.textos.bodySmall),
      const SizedBox(height: 10),
      OperacionConHuecos(datos: datos, colocadas: colocadas, huecosMal: huecosMal, alTocarHueco: alTocarHueco),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (i, f) in libres.indexed)
          ChoiceChip(
            key: ValueKey('ficha-$f-$i'),
            label: Text(f, style: estiloCifra(context, size: 16, weight: FontWeight.w500)),
            selected: fichaSeleccionada == f,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => alTocarFicha(f),
          ),
      ]),
    ]);
  }
}

/// Operación con sus huecos (también en la corrección, con los fallos marcados).
class OperacionConHuecos extends StatelessWidget {
  const OperacionConHuecos({super.key, required this.datos, required this.colocadas, this.huecosMal = const [], this.alTocarHueco});
  final GapFill datos;
  final Map<String, String> colocadas;
  final List<String> huecosMal;
  final ValueChanged<String>? alTocarHueco;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final piezas = <Widget>[];
    var desde = 0;
    for (final m in _hueco.allMatches(datos.template)) {
      final texto = datos.template.substring(desde, m.start).trim();
      if (texto.isNotEmpty) piezas.add(Text(texto, style: estiloCifra(context, size: 18, weight: FontWeight.w500)));
      final id = m.group(1)!;
      final ficha = colocadas[id];
      final mal = huecosMal.contains(id);
      piezas.add(Semantics(
        button: alTocarHueco != null,
        label: 'Hueco ${id.substring(1)}: ${ficha ?? 'vacío'}${mal ? ', incorrecto' : ''}',
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('hueco-$id'),
          borderRadius: BorderRadius.circular(10),
          onTap: alTocarHueco == null ? null : () => alTocarHueco!(id),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64, minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mal ? c.errorTinte : (ficha == null ? c.superficie2 : c.primarioTinte),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: mal ? c.error : (ficha == null ? c.borde : c.primario), width: mal ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (mal) ...[Icon(Symbols.close, size: 16, color: c.errorFuerte), const SizedBox(width: 4)],
              Text(ficha ?? '…', style: estiloCifra(context, size: 16, weight: FontWeight.w600, color: mal ? c.errorFuerte : null)),
            ]),
          ),
        ),
      ));
      desde = m.end;
    }
    final resto = datos.template.substring(desde).trim();
    if (resto.isNotEmpty) piezas.add(Text(resto, style: estiloCifra(context, size: 18, weight: FontWeight.w500)));
    return Wrap(spacing: 6, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: piezas);
  }
}

/// T5: pasos resueltos; se toca el paso que contiene el error o «No hay
/// ningún error».
class RespuestaPasos extends StatelessWidget {
  const RespuestaPasos({super.key, required this.pasos, required this.seleccionado, required this.alElegir});
  final List<WorkedStep> pasos;

  /// Número del paso elegido; -1 = «No hay ningún error».
  final int? seleccionado;
  final ValueChanged<int> alElegir;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Toca el paso que tiene el error.', style: context.textos.bodySmall),
        const SizedBox(height: 8),
        for (final p in pasos)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tarjeta(
              key: ValueKey('paso-resuelto-${p.n}'),
              seleccionada: seleccionado == p.n,
              semantica: 'Paso ${p.n}: ${p.text}',
              onTap: () => alElegir(p.n),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 14, backgroundColor: context.vtm.superficie2, child: Text('${p.n}', style: context.textos.labelMedium)),
                const SizedBox(width: 12),
                Expanded(child: Text(p.text, style: estiloCifra(context, size: 15, weight: FontWeight.w500))),
              ]),
            ),
          ),
        Tarjeta(
          key: const ValueKey('paso-resuelto-ninguno'),
          seleccionada: seleccionado == -1,
          semantica: 'No hay ningún error',
          onTap: () => alElegir(-1),
          child: Row(children: [const Icon(Symbols.done_all), const SizedBox(width: 12), Expanded(child: Text('No hay ningún error', style: context.textos.bodyMedium))]),
        ),
      ]);
}

/// T10: dos columnas; se toca un elemento de cada una para unirlos. Cada
/// pareja se corrige al unirla y queda marcada con icono y texto.
class RespuestaParejas extends StatelessWidget {
  const RespuestaParejas({super.key, required this.pares, required this.unidos, required this.correccion, required this.izquierdaSel, required this.alTocarIzquierda, required this.alTocarDerecha, required this.ordenDerecha});
  final List<MatchPair> pares;

  /// Izquierda → derecha unida.
  final Map<String, String> unidos;

  /// Izquierda → si la pareja unida es correcta.
  final Map<String, bool> correccion;
  final String? izquierdaSel;
  final ValueChanged<String> alTocarIzquierda;
  final ValueChanged<String> alTocarDerecha;

  /// Columna derecha barajada de forma estable.
  final List<String> ordenDerecha;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final derechasUsadas = unidos.values.toSet();
    Widget celda(String texto, {required Key key, required bool usada, required bool sel, bool? ok, VoidCallback? onTap, required String semantica}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Tarjeta(
            key: key,
            seleccionada: sel,
            tinte: usada && ok == null,
            semantica: semantica,
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              if (ok != null) ...[
                Icon(ok ? Symbols.check_circle : Symbols.cancel, size: 18, color: ok ? c.exito : c.errorFuerte, fill: 1),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(texto, style: estiloCifra(context, size: 15, weight: FontWeight.w500))),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Toca un elemento de cada columna para unirlos.', style: context.textos.bodySmall),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(children: [
            for (final p in pares)
              celda(
                p.left,
                key: ValueKey('izq-${p.left}'),
                usada: unidos.containsKey(p.left),
                sel: izquierdaSel == p.left,
                ok: correccion[p.left],
                semantica: unidos.containsKey(p.left)
                    ? '${p.left} unido con ${unidos[p.left]}: ${correccion[p.left] == true ? 'correcto' : 'incorrecto'}'
                    : p.left,
                onTap: unidos.containsKey(p.left) ? null : () => alTocarIzquierda(p.left),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(children: [
            for (final d in ordenDerecha)
              celda(
                d,
                key: ValueKey('der-$d'),
                usada: derechasUsadas.contains(d),
                sel: false,
                semantica: derechasUsadas.contains(d) ? '$d, ya unido' : d,
                onTap: derechasUsadas.contains(d) || izquierdaSel == null ? null : () => alTocarDerecha(d),
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 4),
      Text('${unidos.length} de ${pares.length} unidas', key: const ValueKey('parejas-unidas'), style: context.textos.labelLarge),
    ]);
  }
}

/// T8: partes del caso encadenado. Las ya respondidas muestran su veredicto
/// y, si fallaron, el valor correcto con el que continúa la siguiente.
class PartesCadena extends StatelessWidget {
  const PartesCadena({super.key, required this.partes, required this.resultados});
  final List<ChainPart> partes;
  final List<GradeResult> resultados;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final i = resultados.length.clamp(0, partes.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var k = 0; k < resultados.length; k++) ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isCorrectVerdict(resultados[k].verdict) ? Symbols.check : Symbols.close, size: 18, color: isCorrectVerdict(resultados[k].verdict) ? c.exito : c.errorFuerte),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isCorrectVerdict(resultados[k].verdict)
                  ? 'Parte ${k + 1}: correcto, ${resultados[k].correctDisplay}'
                  : 'Parte ${k + 1}: incorrecto. Sigue con ${resultados[k].correctDisplay}',
              key: ValueKey('parte-hecha-$k'),
              style: context.textos.bodySmall,
            ),
          ),
        ]),
        const SizedBox(height: 4),
      ],
      const SizedBox(height: 6),
      Text('Parte ${i + 1} de ${partes.length}', style: context.textos.titleSmall),
      const SizedBox(height: 4),
      Text(partes[i].prompt, key: const ValueKey('parte-actual'), style: context.textos.bodyLarge),
    ]);
  }
}

/// Detalle de la corrección de los tipos de la fase 2.
class DetalleFase2 extends StatelessWidget {
  const DetalleFase2({super.key, required this.resultado});
  final ResultadoEjercicio resultado;

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final v = r.ejercicio.variante;
    final p = r.payload is Map ? (r.payload as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final c = context.vtm;
    switch (r.ejercicio.bloque) {
      case 'fill_gaps':
        if (r.verdict == Verdict.dontKnow) return OperacionConHuecos(datos: v.gapFill!, colocadas: v.gapFill!.gapAnswers);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TituloSeccion('Tu planteamiento'),
          OperacionConHuecos(
            key: const ValueKey('huecos-corregidos'),
            datos: v.gapFill!,
            colocadas: ((p['placed'] as Map?) ?? const {}).cast<String, String>(),
            huecosMal: ((p['wrongGaps'] as List?) ?? const []).cast<String>(),
          ),
        ]);
      case 'step_pick':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TituloSeccion('Pasos resueltos'),
          for (final w in v.worked!)
            Container(
              key: w.correct ? null : ValueKey('paso-erroneo-${w.n}'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: w.correct ? c.superficie : c.errorTinte,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: w.correct ? c.borde : c.error, width: w.correct ? 1 : 2),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${w.n}. ${w.text}', style: estiloCifra(context, size: 15, weight: FontWeight.w500)),
                if (!w.correct && w.correction != null) ...[
                  const SizedBox(height: 4),
                  Text('Corrección: ${w.correction}', style: context.textos.bodyMedium?.copyWith(color: c.errorFuerte)),
                ],
              ]),
            ),
        ]);
      case 'matching':
        final elegidos = ((p['pairs'] as Map?) ?? const {}).cast<String, String>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TituloSeccion('Parejas'),
          for (final par in v.pairs!)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(elegidos[par.left] == par.right ? Symbols.check : Symbols.close, size: 18, color: elegidos[par.left] == par.right ? c.exito : c.errorFuerte),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    elegidos[par.left] == par.right || elegidos[par.left] == null
                        ? '${par.left} = ${par.right}'
                        : '${par.left} = ${par.right} (uniste ${elegidos[par.left]})',
                    style: estiloCifra(context, size: 15, weight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
        ]);
      case 'chain':
        final partes = ((p['parts'] as List?) ?? const []).cast<Map>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const TituloSeccion('Partes del caso'),
          for (var i = 0; i < v.chain!.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Builder(builder: (context) {
                final d = i < partes.length ? partes[i] : const {};
                final ok = d['verdict'] == 'correct' || d['verdict'] == 'correct_note';
                final valor = d['value'] as String?;
                final tuya = valor == null ? 'sin respuesta' : formatQty(valor, v.chain![i].answer.unit);
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(ok ? Symbols.check : Symbols.close, size: 18, color: ok ? c.exito : c.errorFuerte),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${i + 1}. ${v.chain![i].prompt} ${ok ? d['correct'] : 'Era ${d['correct']} (tu respuesta: $tuya)'}',
                      key: ValueKey('parte-corregida-$i'),
                      style: context.textos.bodyMedium,
                    ),
                  ),
                ]);
              }),
            ),
        ]);
    }
    return const SizedBox.shrink();
  }
}
