import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/domain/content_models.dart';
import '../../core/domain/decimal_es.dart';
import '../../features/voice/domain/normalizador.dart';
import '../estado/estado_app.dart';
import '../tema.dart';

/// Componentes compartidos por todas las pantallas.

/// Cantidad con coma decimal en Space Mono. El lector de pantalla la anuncia
/// completa: «0,2 mg/kg» → «cero coma dos miligramos por kilo».
class Cantidad extends StatelessWidget {
  const Cantidad(this.valor, this.unidad, {super.key, this.tamano = 18, this.color, this.peso = FontWeight.w700});
  final String valor;
  final String unidad;
  final double tamano;
  final Color? color;
  final FontWeight peso;

  @override
  Widget build(BuildContext context) => Semantics(
        label: lecturaCantidad(valor, unidad),
        excludeSemantics: true,
        child: Text(formatQty(valor, unidad), style: estiloCifra(context, size: tamano, weight: peso, color: color)),
      );
}

/// Lectura completa de una cantidad para el lector de pantalla.
String lecturaCantidad(String valor, String unidad) {
  try {
    return readQuantity(valor, unidad);
  } catch (_) {
    return formatQty(valor, unidad);
  }
}

/// Lectura de un enunciado entero, con cada cantidad leída completa.
String lecturaEnunciado(Variant v) =>
    '${v.statement.map((s) => s.isQty ? lecturaCantidad(s.value!, s.unit!) : s.text!).join()} ${v.question}'.trim();

/// Rótulo de caso simulado (formative-boundary): «Caso simulado · perro».
String rotuloCaso(Variant v, {String? sector}) {
  final detalle = v.species ?? sector;
  return detalle == null || detalle.isEmpty ? 'Caso simulado' : 'Caso simulado · $detalle';
}

/// Enunciado de un ejercicio: los datos resaltados en Space Mono y la pregunta
/// al final. Siempre lleva el rótulo «Caso simulado».
class Enunciado extends StatelessWidget {
  const Enunciado(this.variante, {super.key, this.rotulo, this.compacto = false});
  final Variant variante;
  final String? rotulo;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final base = (compacto ? context.textos.bodyMedium : context.textos.bodyLarge)!;
    final spans = <InlineSpan>[
      for (final s in variante.statement)
        if (s.isQty)
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: c.primarioTinte, borderRadius: BorderRadius.circular(6)),
              child: Text(formatQty(s.value!, s.unit!), style: estiloCifra(context, size: base.fontSize! - 1)),
            ),
          )
        else
          TextSpan(text: s.text),
      if (variante.question.isNotEmpty) TextSpan(text: ' ${variante.question}', style: const TextStyle(fontWeight: FontWeight.w600)),
    ];
    return Semantics(
      label: lecturaEnunciado(variante),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Etiqueta(rotulo ?? rotuloCaso(variante), icono: Symbols.science),
          const SizedBox(height: 10),
          Text.rich(TextSpan(children: spans), style: base),
        ],
      ),
    );
  }
}

/// Etiqueta en forma de píldora (estado, rótulo).
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.icono, this.tono = TonoEtiqueta.neutro});
  final String texto;
  final IconData? icono;
  final TonoEtiqueta tono;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final (fondo, frente) = switch (tono) {
      TonoEtiqueta.neutro => (c.superficie2, c.texto),
      TonoEtiqueta.primario => (c.primarioTinte, c.primario),
      TonoEtiqueta.exito => (c.exitoTinte, c.exito),
      TonoEtiqueta.error => (c.errorTinte, c.errorFuerte),
      TonoEtiqueta.aviso => (c.avisoTinte, c.aviso),
      TonoEtiqueta.acento => (c.acentoTinte, c.acento),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 16, color: frente), const SizedBox(width: 6)],
          Flexible(child: Text(texto, style: context.textos.labelMedium?.copyWith(color: frente))),
        ],
      ),
    );
  }
}

enum TonoEtiqueta { neutro, primario, exito, error, aviso, acento }

/// Distintivo discreto «Sin conexión» (offline-sync): no bloquea nada.
class DistintivoSinConexion extends ConsumerWidget {
  const DistintivoSinConexion({super.key});
  static const texto = 'Sin conexión';
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(enLineaProvider)) return const SizedBox.shrink();
    return const Etiqueta(texto, icono: Symbols.cloud_off, tono: TonoEtiqueta.neutro);
  }
}

/// Tarjeta con borde según los tokens.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.onTap, this.seleccionada = false, this.padding = const EdgeInsets.all(16), this.tinte = false, this.semantica});
  final Widget child;
  final VoidCallback? onTap;
  final bool seleccionada;
  final EdgeInsets padding;
  final bool tinte;
  final String? semantica;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final contenido = Material(
      color: seleccionada || tinte ? c.primarioTinte : c.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: seleccionada ? c.primario : (tinte ? Colors.transparent : c.borde), width: seleccionada ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    if (semantica == null && onTap == null) return contenido;
    return Semantics(button: onTap != null, selected: seleccionada, label: semantica, child: contenido);
  }
}

/// Título de sección en versalitas.
class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key});
  final String texto;
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(texto.toUpperCase(), style: context.textos.labelSmall?.copyWith(color: context.vtm.atenuado)),
        ),
      );
}

/// Pantalla provisional para rutas aún no construidas.
class PantallaPendiente extends StatelessWidget {
  const PantallaPendiente(this.titulo, {super.key});
  final String titulo;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: Center(child: Text(titulo, style: context.textos.titleLarge)),
      );
}

/// Esqueleto de carga: aparece si la espera supera 300 ms. Nunca un
/// indicador giratorio a pantalla completa.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, this.filas = 4});
  final int filas;
  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> {
  bool _visible = false;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.expand();
    final c = context.vtm;
    return Semantics(
      label: 'Cargando',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < widget.filas; i++)
            Container(height: 72, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: c.superficie2, borderRadius: BorderRadius.circular(12))),
        ],
      ),
    );
  }
}
