import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import '../../progress/domain/projections.dart';
import '../../review/domain/review_projection.dart';

/// Piezas compartidas por Inicio, Practicar, Repaso y Progreso.

/// Icono de cada estado de unidad (siempre acompañado de su texto).
IconData iconoUnidad(EstadoUnidad e) => switch (e) {
      EstadoUnidad.bloqueada => Symbols.lock,
      EstadoUnidad.disponible => Symbols.play_circle,
      EstadoUnidad.enCurso => Symbols.pending,
      EstadoUnidad.superada => Symbols.check_circle,
      EstadoUnidad.dominada => Symbols.workspace_premium,
      EstadoUnidad.porRefrescar => Symbols.refresh,
    };

TonoEtiqueta tonoUnidad(EstadoUnidad e) => switch (e) {
      EstadoUnidad.bloqueada => TonoEtiqueta.neutro,
      EstadoUnidad.disponible || EstadoUnidad.enCurso => TonoEtiqueta.primario,
      EstadoUnidad.superada || EstadoUnidad.dominada => TonoEtiqueta.exito,
      EstadoUnidad.porRefrescar => TonoEtiqueta.aviso,
    };

IconData iconoLeccion(EstadoLeccion e) => switch (e) {
      EstadoLeccion.bloqueada => Symbols.lock,
      EstadoLeccion.disponible => Symbols.play_circle,
      EstadoLeccion.completada => Symbols.check_circle,
      EstadoLeccion.convalidada => Symbols.verified,
    };

TonoEtiqueta tonoHabilidad(EstadoHabilidad e) => switch (e) {
      EstadoHabilidad.nueva => TonoEtiqueta.neutro,
      EstadoHabilidad.enAprendizaje => TonoEtiqueta.primario,
      EstadoHabilidad.consolidada || EstadoHabilidad.dominada => TonoEtiqueta.exito,
      EstadoHabilidad.porRefrescar => TonoEtiqueta.aviso,
    };

/// Minutos estimados de una cola de repaso (unos 30 s por ficha).
int minutosRepaso(int fichas) => fichas <= 0 ? 0 : math.max(1, (fichas * 30 / 60).ceil());

String plural(int n, String singular, String pluralForm) => '$n ${n == 1 ? singular : pluralForm}';

const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/// «mañana», «el jueves» o «el 3 de diciembre».
String cuandoRelativo(DateTime fecha, DateTime ahora) {
  final d = diasEntre(diaLocal(ahora), diaLocal(fecha));
  if (d <= 0) return 'hoy';
  if (d == 1) return 'mañana';
  final l = fecha.toLocal();
  if (d < 7) return 'el ${_dias[l.weekday - 1]}';
  return 'el ${l.day} de ${_meses[l.month - 1]}';
}

/// Texto de la meta: «Meta de hoy 6 de 10 minutos» o «Meta semanal 2 de 4 días».
String textoMeta(RachaInfo r) {
  if (r.tipo == GoalKind.weekly) return 'Meta semanal ${r.progresoHoy.floor()} de ${r.objetivo} días';
  final hechos = math.min(r.progresoHoy.floor(), r.objetivo);
  return 'Meta de hoy $hechos de ${r.objetivo} minutos';
}

/// Anillo de la meta de práctica.
class AnilloMeta extends StatelessWidget {
  const AnilloMeta({super.key, required this.racha, this.tamano = 56});
  final RachaInfo racha;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final f = racha.metaCumplidaHoy ? 1.0 : racha.fraccion;
    final texto = racha.tipo == GoalKind.weekly
        ? '${racha.progresoHoy.floor()}/${racha.objetivo}'
        : '${math.min(racha.progresoHoy.floor(), racha.objetivo)}/${racha.objetivo}';
    return Semantics(
      label: '${textoMeta(racha)}${racha.metaCumplidaHoy ? '. Meta cumplida' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: CustomPaint(
          key: const ValueKey('anillo-meta'),
          painter: _PintorAnillo(fraccion: f, fondo: c.superficie2, frente: racha.metaCumplidaHoy ? c.exito : c.primario),
          child: Center(
            child: racha.metaCumplidaHoy
                ? Icon(Symbols.check, color: c.exito, size: tamano * 0.42)
                : FittedBox(child: Padding(padding: const EdgeInsets.all(8), child: Text(texto, style: estiloCifra(context, size: 13)))),
          ),
        ),
      ),
    );
  }
}

/// Fracción pintada del anillo (expuesta para las pruebas).
class _PintorAnillo extends CustomPainter {
  _PintorAnillo({required this.fraccion, required this.fondo, required this.frente});
  final double fraccion;
  final Color fondo;
  final Color frente;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 6.0;
    final r = Rect.fromLTWH(grosor / 2, grosor / 2, size.width - grosor, size.height - grosor);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, 2 * math.pi, false, p..color = fondo);
    if (fraccion > 0) canvas.drawArc(r, -math.pi / 2, 2 * math.pi * fraccion, false, p..color = frente);
  }

  @override
  bool shouldRepaint(_PintorAnillo old) => old.fraccion != fraccion || old.frente != frente;
}

/// Tarjeta de repaso pendiente: «12 fichas para hoy · Unos 6 minutos · 3 con error crítico».
class TarjetaRepaso extends StatelessWidget {
  const TarjetaRepaso({super.key, required this.cola, required this.onTap});
  final List<FichaRepaso> cola;
  final VoidCallback onTap;

  static String resumen(List<FichaRepaso> cola) {
    final criticas = cola.where((f) => f.critica).length;
    return [
      'Unos ${minutosRepaso(cola.length)} minutos',
      if (criticas > 0) '$criticas con error crítico',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Tarjeta(
      tinte: true,
      onTap: onTap,
      semantica: '${plural(cola.length, 'ficha', 'fichas')} para hoy. ${resumen(cola)}',
      child: Row(
        children: [
          Icon(Symbols.cards, color: c.primario),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${plural(cola.length, 'ficha', 'fichas')} para hoy', style: context.textos.titleMedium),
                Text(resumen(cola), style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
              ],
            ),
          ),
          Icon(Symbols.chevron_right, color: c.atenuado),
        ],
      ),
    );
  }
}

/// Línea de aviso discreta (sin conexión, racha, contenido nuevo).
class Aviso extends StatelessWidget {
  const Aviso(this.texto, {super.key, this.icono = Symbols.info, this.tono = TonoEtiqueta.neutro});
  final String texto;
  final IconData icono;
  final TonoEtiqueta tono;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final (fondo, frente) = switch (tono) {
      TonoEtiqueta.aviso => (c.avisoTinte, c.aviso),
      TonoEtiqueta.primario => (c.primarioTinte, c.primario),
      _ => (c.superficie2, c.texto),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icono, size: 20, color: frente),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: context.textos.bodySmall?.copyWith(color: frente))),
        ],
      ),
    );
  }
}
