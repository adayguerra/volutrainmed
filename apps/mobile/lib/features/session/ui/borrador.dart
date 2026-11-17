import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/tema.dart';

/// Hoja de borrador de la tablet (adaptive-accessible-ui): trazos de lápiz o
/// dedo que no se guardan ni se sincronizan. La sesión le da una clave por
/// ejercicio, de modo que aparece vacía en cada ejercicio nuevo.
class Borrador extends StatefulWidget {
  const Borrador({super.key});
  @override
  State<Borrador> createState() => EstadoBorrador();
}

class EstadoBorrador extends State<Borrador> {
  final List<List<Offset>> trazos = [];

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [
            Expanded(child: Text('Borrador', style: context.textos.titleMedium)),
            IconButton(
              tooltip: 'Limpiar el borrador',
              icon: const Icon(Symbols.ink_eraser),
              onPressed: trazos.isEmpty ? null : () => setState(trazos.clear),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Para lápiz o dedo. No se guarda ni se sincroniza; se limpia en cada ejercicio. Con teclado físico: escribe las cifras e Intro comprueba.',
            style: context.textos.bodySmall?.copyWith(color: c.atenuado),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Semantics(
            label: 'Hoja de borrador',
            child: Container(
              key: const ValueKey('lienzo-borrador'),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(color: c.superficie, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.borde)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onPanStart: (d) => setState(() => trazos.add([d.localPosition])),
                  onPanUpdate: (d) => setState(() => trazos.last.add(d.localPosition)),
                  child: CustomPaint(painter: _Pintor(trazos, c.texto), size: Size.infinite),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pintor extends CustomPainter {
  _Pintor(this.trazos, this.color);
  final List<List<Offset>> trazos;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final t in trazos) {
      if (t.length == 1) {
        canvas.drawCircle(t.first, 1.5, p);
        continue;
      }
      final path = Path()..moveTo(t.first.dx, t.first.dy);
      for (final o in t.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_Pintor old) => true;
}
