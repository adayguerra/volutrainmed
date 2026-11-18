import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../../progress/domain/projections.dart';
import '../domain/motor_sesion.dart';
import 'correccion.dart';

/// Datos de la pantalla de fin de sesión (gamification-progress, M30, M31,
/// M34, T06).
class DatosFin {
  const DatosFin({
    required this.motor,
    required this.cambios,
    required this.nombreHabilidad,
    this.nivelAntes,
    this.nivelDespues,
    this.racha,
    this.titulo,
  });
  final MotorSesion motor;
  final List<CambioEstado> cambios;
  final String Function(String skillId) nombreHabilidad;
  final int? nivelAntes;
  final int? nivelDespues;
  final RachaInfo? racha;
  final String? titulo;

  bool get subeNivel => nivelAntes != null && nivelDespues != null && nivelDespues! > nivelAntes!;

  /// Hito: una habilidad pasa a consolidada o dominada.
  CambioEstado? get hito => cambios.where((c) => c.a == EstadoHabilidad.consolidada || c.a == EstadoHabilidad.dominada).firstOrNull;
}

/// «Lección completada: 2 fichas van a repaso».
String textoFinLeccion(int fallos) => switch (fallos) {
      0 => 'Lección completada sin fallos',
      1 => 'Lección completada: 1 ficha va a repaso',
      _ => 'Lección completada: $fallos fichas van a repaso',
    };

/// Segundos con una décima y coma decimal («38 s», «3,9 s»).
String segundos(int ms) {
  final d = (ms + 50) ~/ 100;
  return d % 10 == 0 ? '${d ~/ 10} s' : '${d ~/ 10},${d % 10} s';
}

class FinSesion extends StatefulWidget {
  const FinSesion({super.key, required this.datos, required this.alContinuar, this.alRepasar});
  final DatosFin datos;
  final VoidCallback alContinuar;
  final VoidCallback? alRepasar;

  @override
  State<FinSesion> createState() => _FinSesionState();
}

class _FinSesionState extends State<FinSesion> {
  bool _celebrando = false;
  bool _hito = false;
  Timer? _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_t != null || _hito) return;
    final reducido = MediaQuery.disableAnimationsOf(context);
    _hito = widget.datos.hito != null;
    if (widget.datos.subeNivel && !reducido) {
      // Celebración breve: 1,2 s como máximo y se cierra con un toque.
      _celebrando = true;
      _t = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _celebrando = false);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.datos;
    final m = d.motor;
    final tablet = ClaseAncho.de(context).dosPaneles;
    final resumen = _Resumen(datos: d, alContinuar: widget.alContinuar, alRepasar: widget.alRepasar);
    final cuerpo = tablet && m.primerosIntentos.isNotEmpty
        ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: resumen),
            VerticalDivider(width: 1, color: context.vtm.borde),
            Expanded(child: _TablaEjercicios(motor: m)),
          ])
        : resumen;
    return Stack(children: [
      Positioned.fill(child: cuerpo),
      if (_celebrando)
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('celebracion-nivel'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _celebrando = false),
            child: ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Symbols.military_tech, size: 56, color: context.vtm.acento, fill: 1),
                        const SizedBox(height: 12),
                        Text('Subes al nivel ${d.nivelDespues}', style: context.textos.headlineSmall),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
      else if (_hito)
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('hito'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _hito = false),
            child: ColoredBox(
              color: Colors.black54,
              child: SafeArea(
                child: Center(
                  child: AnchoMaximo(
                    ancho: 480,
                    alineacion: Alignment.center,
                    child: Card(
                      margin: const EdgeInsets.all(24),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Symbols.workspace_premium, size: 48, color: context.vtm.exito, fill: 1),
                          const SizedBox(height: 12),
                          Text(
                            d.hito!.a == EstadoHabilidad.dominada ? 'Habilidad dominada' : 'Habilidad consolidada',
                            style: context.textos.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(d.nombreHabilidad(d.hito!.skillId), style: context.textos.titleMedium, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            d.hito!.a.abreContrarreloj ? 'Se abre el contrarreloj de esta habilidad.' : '',
                            style: context.textos.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: () => setState(() => _hito = false), child: const Text('Continuar')),
                          const SizedBox(height: 8),
                          Text('Toca en cualquier parte para continuar', style: context.textos.bodySmall),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.datos, required this.alContinuar, this.alRepasar});
  final DatosFin datos;
  final VoidCallback alContinuar;
  final VoidCallback? alRepasar;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final m = datos.motor;
    final p = m.primerosIntentos;
    final aciertos = p.where((r) => r.acierto).length;
    final fallos = m.fallos;
    final repaso = m.modo == SessionMode.review;
    final titulo = datos.titulo ??
        (repaso
            ? 'Repaso terminado'
            : m.esReto
                ? (m.retoSuperado ? 'Reto superado' : 'Reto no superado')
                : textoFinLeccion(fallos.length));
    final subtitulo = repaso
        ? '$aciertos de ${p.length} resueltas a la primera'
        : m.esReto
            ? (m.retoSuperado ? '$aciertos de ${p.length}. La unidad queda superada y se abre la siguiente.' : '$aciertos de ${p.length}. Hacen falta 9 aciertos y ningún error crítico.')
            : '$aciertos de ${p.length}';
    final precision = p.isEmpty ? 0 : (aciertos * 100 / p.length).round();
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Icon(repaso ? Symbols.event_repeat : Symbols.task_alt, size: 40, color: c.exito),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text(titulo, key: const ValueKey('titulo-fin'), style: context.textos.headlineSmall)),
          const SizedBox(height: 4),
          Text(subtitulo, style: context.textos.bodyLarge),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _Cifra(etiqueta: 'Precisión', valor: precision, sufijo: ' %'),
            _Dato(etiqueta: 'Tiempo medio', valor: segundos(m.tiempoMedioMs), detalle: 'objetivo ${segundos(m.tiempoObjetivoMedioMs)}'),
            _Cifra(etiqueta: 'Puntos', valor: m.puntosGanados, prefijo: '+'),
          ]),
          if (datos.racha != null && datos.racha!.metaCumplidaHoy) ...[
            const SizedBox(height: 12),
            Tarjeta(
              tinte: true,
              child: Row(children: [
                Icon(Symbols.local_fire_department, color: c.acento, fill: 1),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${datos.racha!.actual} ${datos.racha!.tipo == GoalKind.weekly ? (datos.racha!.actual == 1 ? 'semana' : 'semanas') : (datos.racha!.actual == 1 ? 'día' : 'días')} de racha · Meta cumplida',
                    style: context.textos.titleSmall,
                  ),
                ),
              ]),
            ),
          ],
          if (datos.subeNivel) ...[
            const SizedBox(height: 12),
            Etiqueta('Nivel ${datos.nivelDespues}', icono: Symbols.military_tech, tono: TonoEtiqueta.acento),
          ],
          if (datos.cambios.isNotEmpty) ...[
            const SizedBox(height: 16),
            const TituloSeccion('Habilidades que cambian'),
            for (final cb in datos.cambios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(datos.nombreHabilidad(cb.skillId), style: context.textos.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                      Etiqueta(cb.de.etiqueta),
                      const Icon(Symbols.arrow_forward, size: 18, semanticLabel: 'pasa a'),
                      Etiqueta(cb.a.etiqueta, tono: TonoEtiqueta.exito),
                    ]),
                  ]),
                ),
              ),
          ],
          if (fallos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const TituloSeccion('Fallos'),
            for (final f in fallos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.ejercicio.variante.question.isEmpty ? f.ejercicio.variante.id : f.ejercicio.variante.question, style: context.textos.bodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      f.noLoSe ? 'No lo sé' : (etiquetaError(f.errorCode) ?? 'Sin clasificar'),
                      style: context.textos.labelLarge?.copyWith(color: c.errorFuerte),
                    ),
                  ]),
                ),
              ),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FilledButton(key: const ValueKey('continuar-fin'), onPressed: alContinuar, child: const Text('Continuar')),
          if (fallos.isNotEmpty && alRepasar != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: alRepasar, child: const Text('Repasar ahora los fallos')),
          ],
        ]),
      ),
    ]);
  }
}

/// Cifra con conteo animado; con movimiento reducido aparece el valor final.
class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor, this.prefijo = '', this.sufijo = ''});
  final String etiqueta;
  final int valor;
  final String prefijo;
  final String sufijo;
  @override
  Widget build(BuildContext context) {
    final reducido = MediaQuery.disableAnimationsOf(context);
    Widget texto(int v) => Text('$prefijo$v$sufijo', style: estiloCifra(context, size: 26));
    return _Caja(
      etiqueta: etiqueta,
      semantica: '$etiqueta $prefijo$valor$sufijo',
      child: reducido
          ? texto(valor)
          : TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: valor),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, _) => texto(v),
            ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor, this.detalle});
  final String etiqueta;
  final String valor;
  final String? detalle;
  @override
  Widget build(BuildContext context) => _Caja(
        etiqueta: etiqueta,
        semantica: '$etiqueta $valor${detalle == null ? '' : ', $detalle'}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valor, style: estiloCifra(context, size: 26)),
          if (detalle != null) Text(detalle!, style: context.textos.bodySmall?.copyWith(color: context.vtm.atenuado)),
        ]),
      );
}

class _Caja extends StatelessWidget {
  const _Caja({required this.etiqueta, required this.child, required this.semantica});
  final String etiqueta;
  final Widget child;
  final String semantica;
  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: semantica,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 140),
          child: Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(etiqueta, style: context.textos.labelMedium?.copyWith(color: context.vtm.atenuado)),
              const SizedBox(height: 4),
              child,
            ]),
          ),
        ),
      );
}

/// Tabla de los ejercicios de la lección (tablet, T06).
class _TablaEjercicios extends StatelessWidget {
  const _TablaEjercicios({required this.motor});
  final MotorSesion motor;
  @override
  Widget build(BuildContext context) {
    final p = motor.primerosIntentos;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const TituloSeccion('Ejercicios de la lección'),
      Table(
        columnWidths: const {0: IntrinsicColumnWidth(), 3: IntrinsicColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            for (final h in ['N.º', 'Tu respuesta', 'Veredicto', 'Tiempo'])
              Padding(padding: const EdgeInsets.all(6), child: Text(h, style: context.textos.labelMedium)),
          ]),
          for (var i = 0; i < p.length; i++)
            TableRow(children: [
              Padding(padding: const EdgeInsets.all(6), child: Text('${i + 1}')),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(p[i].valor == null ? '—' : (p[i].unidad == null ? formatEs(p[i].valor!) : formatQty(p[i].valor!, p[i].unidad!)), style: estiloCifra(context, size: 14, weight: FontWeight.w400)),
              ),
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(p[i].acierto ? palabraVeredicto(p[i].verdict) : (etiquetaError(p[i].errorCode) ?? palabraVeredicto(p[i].verdict))),
              ),
              Padding(padding: const EdgeInsets.all(6), child: Text(segundos(p[i].respuestaMs))),
            ]),
        ],
      ),
    ]);
  }
}
