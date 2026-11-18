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
import '../../../core/domain/learning_models.dart';
import '../../home/ui/componentes_inicio.dart';
import '../domain/review_projection.dart';

/// Repaso: entrada con la cola de hoy (M32) y cola vacía (M35). La sesión de
/// repaso se hace en la pantalla de sesión (`Rutas.sesionRepaso()`).

const textoSinFichas = 'No tienes fichas para hoy';

/// Nombre legible de una plantilla o pregunta del contenido.
String nombrePlantilla(ContenidoCargado c, String clave) {
  for (final it in c.itinerarios.values) {
    for (final t in it.templates) {
      if (t.id == clave) return t.name;
    }
  }
  return clave;
}

class PantallaRepaso extends ConsumerWidget {
  const PantallaRepaso({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(proyeccionProvider);
    final contenido = ref.watch(contenidoProvider).value;
    if (p == null || contenido == null) return const Scaffold(body: SafeArea(child: Esqueleto()));
    final cola = p.colaHoy;
    return Scaffold(
      appBar: AppBar(title: const Text('Repaso')),
      body: SafeArea(
        child: cola.isEmpty
            ? _ColaVacia(proximo: p.proximo, ahora: p.now)
            : _EntradaRepaso(cola: cola, contenido: contenido, intentosFallidos: p.intentos.where((a) => !a.correct).toList()),
      ),
    );
  }
}

class _EntradaRepaso extends StatelessWidget {
  const _EntradaRepaso({required this.cola, required this.contenido, required this.intentosFallidos});
  final List<FichaRepaso> cola;
  final ContenidoCargado contenido;
  final List<Attempt> intentosFallidos;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final criticas = cola.where((f) => f.critica).length;
    final porError = <String, int>{};
    final porHabilidad = <String, int>{};
    for (final f in cola) {
      final code = f.ultimoFueNoLoSe ? null : f.ultimoErrorCode;
      if (code != null && code != 'E0') porError[code] = (porError[code] ?? 0) + 1;
      porHabilidad[f.skillId] = (porHabilidad[f.skillId] ?? 0) + 1;
    }
    final frecuentes = <String, int>{};
    for (final a in intentosFallidos) {
      final k = a.templateId ?? a.questionId ?? a.variantId;
      frecuentes[k] = (frecuentes[k] ?? 0) + 1;
    }
    List<MapEntry<String, int>> orden(Map<String, int> m) => m.entries.toList()..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnchoMaximo(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Tarjeta(
                      tinte: true,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${plural(cola.length, 'ficha', 'fichas')} para hoy', key: const ValueKey('total-fichas'), style: context.textos.headlineSmall),
                        Text('Unos ${minutosRepaso(cola.length)} minutos', style: context.textos.bodyMedium),
                        if (criticas > 0) ...[
                          const SizedBox(height: 8),
                          Etiqueta('$criticas con error crítico van primero', icono: Symbols.priority_high, tono: TonoEtiqueta.error),
                        ],
                      ]),
                    ),
                    if (porError.isNotEmpty) ...[
                      const TituloSeccion('Por tipo de error'),
                      for (final e in orden(porError))
                        _Fila(izquierda: '${e.key} · ${errorLabels[e.key] ?? e.key}', derecha: '${e.value}'),
                    ],
                    const TituloSeccion('Por habilidad'),
                    for (final e in orden(porHabilidad)) _Fila(izquierda: contenido.global.skillName(e.key), derecha: '${e.value}'),
                    if (frecuentes.isNotEmpty) ...[
                      const TituloSeccion('Tus errores más frecuentes'),
                      for (final e in orden(frecuentes).take(3))
                        _Fila(izquierda: nombrePlantilla(contenido, e.key), derecha: plural(e.value, 'vez', 'veces')),
                    ],
                    const SizedBox(height: 8),
                    Text('Orden de hoy', style: context.textos.labelSmall?.copyWith(color: c.atenuado)),
                    const SizedBox(height: 4),
                    for (final (i, f) in cola.indexed)
                      Padding(
                        key: ValueKey('cola-$i'),
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [
                          SizedBox(width: 28, child: Text('${i + 1}', style: estiloCifra(context, size: 13, weight: FontWeight.w400))),
                          Expanded(child: Text(nombrePlantilla(contenido, f.templateId ?? f.questionId ?? f.clave), style: context.textos.bodySmall)),
                          if (f.critica) Etiqueta('Crítico', key: ValueKey('critica-$i'), tono: TonoEtiqueta.error),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AnchoMaximo(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('empezar-repaso'),
                onPressed: () => context.push(Rutas.sesionRepaso()),
                child: Text('Empezar repaso (${cola.length})'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.izquierda, required this.derecha});
  final String izquierda;
  final String derecha;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(izquierda, style: context.textos.bodyMedium)),
          const SizedBox(width: 8),
          Text(derecha, style: estiloCifra(context, size: 15)),
        ]),
      );
}

class _ColaVacia extends StatelessWidget {
  const _ColaVacia({required this.proximo, required this.ahora});
  final ({DateTime fecha, int fichas})? proximo;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final texto = proximo == null
        ? 'Aún no hay repasos programados. Mientras, puedes practicar la habilidad que quieras.'
        : 'Tu próximo repaso es ${cuandoRelativo(proximo!.fecha, ahora)}, con ${plural(proximo!.fichas, 'ficha', 'fichas')}. Mientras, puedes practicar la habilidad que quieras.';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Symbols.task_alt, size: 56, color: c.exito),
              const SizedBox(height: 16),
              Text(textoSinFichas, textAlign: TextAlign.center, style: context.textos.headlineSmall),
              const SizedBox(height: 8),
              Text(texto, key: const ValueKey('proximo-repaso'), textAlign: TextAlign.center, style: context.textos.bodyMedium),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('practica-libre'),
                onPressed: () => context.go(Rutas.practicar),
                child: const Text('Práctica libre'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
