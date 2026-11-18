import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/ajustes.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../app/widgets/teclado.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../../../core/sync/sincronizador.dart';
import '../../ads/domain/ad_selector.dart';
import '../../ads/ui/pausa_promocional.dart';
import '../../progress/domain/projections.dart';
import '../data/controlador_crono.dart';
import '../domain/timetrial.dart';

/// Contrarreloj (M36–M39): selección por habilidad consolidada, esprint de
/// 60 s o serie sin cuenta atrás, cierre con la marca y sus fallos.

/// Tiempo con una cifra decimal y coma: 3900 ms → «3,9 s».
String segundosEs(int ms) => '${formatEs(canon(dec('${(ms / 100).round()}') / dec('10')))} s';

String relojMinSeg(int ms) {
  final s = (ms / 1000).ceil();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

EstadoHabilidadCrono estadoCrono(EstadoHabilidad e) => estadoCronoDesde(e.name);

enum _Fase { seleccion, jugando, pausa, resumen, interrumpido }

class PantallaContrarreloj extends ConsumerStatefulWidget {
  const PantallaContrarreloj({super.key});

  /// Último controlador creado (solo para las pruebas).
  @visibleForTesting
  static ControladorCrono? ultimo;

  @override
  ConsumerState<PantallaContrarreloj> createState() => _PantallaContrarrelojState();
}

class _PantallaContrarrelojState extends ConsumerState<PantallaContrarreloj> with WidgetsBindingObserver {
  _Fase _fase = _Fase.seleccion;
  bool _sinCuentaAtras = false;
  ControladorCrono? _c;
  Timer? _tic;
  Timer? _falloTimer;
  final _entrada = EntradaNumerica();
  int? _mejorAnterior;

  Dependencias get _deps => ref.read(dependenciasProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entrada.alRechazo = () {
      if (ref.read(ajustesProvider).haptica) _deps.vibrador.vibrar(Senal.aviso);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tic?.cancel();
    _falloTimer?.cancel();
    _entrada.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_fase != _Fase.jugando) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // La interrupción anula el esprint: no se pausa ni se registra marca.
      _c?.interrumpir();
      _tic?.cancel();
      _falloTimer?.cancel();
      setState(() => _fase = _Fase.interrumpido);
    }
  }

  void _empezar(String skillId) {
    final contenido = ref.read(contenidoProvider).value!;
    final sesiones = ref.read(aprendizajeProvider).value?.sesiones ?? const [];
    final forzado = ref.read(ajustesProvider).sinLimiteTiempo;
    final sinCuenta = _sinCuentaAtras || forzado;
    final variantes = variantesCrono(contenido, skillId, _deps.azar);
    if (variantes.isEmpty) return;
    _mejorAnterior = mejorMarcaValida(sesiones, skillId);
    final c = ControladorCrono(
      contenido: contenido,
      skillId: skillId,
      deviceId: ref.read(usuarioProvider).value!.deviceId,
      relojMs: _deps.relojMs,
      ahora: _deps.reloj.ahora,
      sinCuentaAtras: sinCuenta,
      variantes: variantes,
      mejorMarca: _mejorAnterior,
      alRegistrar: (a) => ref.read(aprendizajeProvider.notifier).registrarIntento(a),
    )..empezar();
    PantallaContrarreloj.ultimo = c;
    _entrada.limpiar();
    setState(() {
      _c = c;
      _fase = _Fase.jugando;
    });
    _tic?.cancel();
    _tic = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _fase != _Fase.jugando) return;
      if (_c!.terminado) {
        _terminar();
      } else if (_c!.esprint != null) {
        setState(() {});
      }
    });
  }

  void _trasRespuesta() {
    final c = _c!;
    _entrada.limpiar();
    if (c.mostrando != null) {
      ref.read(senalesProvider).emitir(Senal.fallo);
      _falloTimer?.cancel();
      _falloTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        c.cerrarFallo();
        setState(() {});
        if (c.terminado) _terminar();
      });
    } else {
      ref.read(senalesProvider).emitir(Senal.acierto);
    }
    setState(() {});
    if (c.mostrando == null && c.terminado) _terminar();
  }

  void _comprobar() {
    final c = _c;
    if (c == null || c.mostrando != null || _entrada.vacia || _fase != _Fase.jugando) return;
    c.responderNumerico(_entrada.texto);
    _trasRespuesta();
  }

  void _opcion(String id) {
    final c = _c;
    if (c == null || c.mostrando != null || _fase != _Fase.jugando) return;
    c.responderOpcion(id);
    _trasRespuesta();
  }

  Future<void> _terminar() async {
    if (_fase != _Fase.jugando) return;
    _tic?.cancel();
    _falloTimer?.cancel();
    final c = _c!;
    if (c.anulado) {
      setState(() => _fase = _Fase.interrumpido);
      return;
    }
    await ref.read(aprendizajeProvider.notifier).registrarSesion(c.registro());
    unawaited(ref.read(sincronizadorProvider).sincronizar().catchError((_) {}));
    if (!mounted) return;
    // Una única pausa promocional al terminar, antes del resumen.
    final pausa = PoliticaPausa.debeMostrar(
      sinAnuncios: ref.read(derechosEfectivosProvider).sinAnuncios,
      modo: c.modo,
      esPrimeraLeccion: false,
      enContrarrelojEntreEjercicios: false,
      contadorEjercicios: 1,
      frecuencia: 1,
    );
    setState(() => _fase = pausa ? _Fase.pausa : _Fase.resumen);
  }

  @override
  Widget build(BuildContext context) {
    switch (_fase) {
      case _Fase.seleccion:
        return _Seleccion(
          sinCuentaAtras: _sinCuentaAtras,
          alCambiarModo: (v) => setState(() => _sinCuentaAtras = v),
          alEmpezar: _empezar,
        );
      case _Fase.jugando:
        return _juego(context);
      case _Fase.pausa:
        return PausaPromocional(
          datos: DatosPausa(modo: _c!.modo, sessionId: _c!.sessionId, trasContrarreloj: true),
          alCerrar: (_) => setState(() => _fase = _Fase.resumen),
        );
      case _Fase.resumen:
        return _Resumen(
          c: _c!,
          anterior: _mejorAnterior,
          alOtraVez: () => _empezar(_c!.skillId),
          alSalir: () => setState(() => _fase = _Fase.seleccion),
        );
      case _Fase.interrumpido:
        return Scaffold(
          appBar: AppBar(title: const Text('Contrarreloj')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Symbols.timer_off, size: 48, color: context.vtm.aviso),
                const SizedBox(height: 16),
                Text('Esprint anulado', style: context.textos.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(motivoInterrupcion, key: const ValueKey('motivo-interrupcion'), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => setState(() => _fase = _Fase.seleccion), child: const Text('Volver')),
              ],
            ),
          ),
        );
    }
  }

  Widget _juego(BuildContext context) {
    final c = _c!;
    final v = c.actual;
    final vtm = context.vtm;
    final esNumerico = c.bloque == 'numeric_unit';
    final falla = c.mostrando;
    final cabecera = c.esprint != null
        ? Row(
            children: [
              Semantics(
                label: 'Quedan ${(c.restanteMs() / 1000).ceil()} segundos',
                excludeSemantics: true,
                child: Text(relojMinSeg(c.restanteMs()),
                    key: const ValueKey('reloj-crono'),
                    style: estiloCifra(context, size: 28, color: c.esprint!.enAvisoFinal(_deps.relojMs()) ? vtm.aviso : vtm.texto)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Etiqueta('${c.aciertos} aciertos', icono: Symbols.check, tono: TonoEtiqueta.exito),
                    Etiqueta('×${formatEs(c.multiplicador.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), ''))}',
                        tono: TonoEtiqueta.primario),
                    if (_mejorAnterior != null) Etiqueta('Récord $_mejorAnterior'),
                  ],
                ),
              ),
            ],
          )
        : Row(
            children: [
              Expanded(child: Text('Ejercicio ${c.respondidos + 1} de ${c.serie!.ejercicios}', style: context.textos.titleMedium)),
              const SizedBox(width: 8),
              const Etiqueta('Sin cuenta atrás', icono: Symbols.timer_off),
            ],
          );
    final cuerpo = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecera,
              const SizedBox(height: 16),
              Enunciado(v, compacto: true),
              const SizedBox(height: 16),
              if (falla != null)
                Container(
                  key: const ValueKey('fallo-crono'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: vtm.errorTinte, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Symbols.close, color: vtm.errorFuerte),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Incorrecto. Era ${falla.correcta}', style: context.textos.bodyMedium?.copyWith(color: vtm.errorFuerte))),
                  ]),
                ),
              if (falla == null && esNumerico) CampoRespuesta(entrada: _entrada, unidad: v.answer?.unit),
              if (falla == null && !esNumerico)
                for (final o in v.options!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      key: ValueKey('opcion-${o.id}'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), alignment: Alignment.centerLeft),
                      onPressed: () => _opcion(o.id),
                      child: Text(o.label, style: estiloCifra(context, size: 18, weight: FontWeight.w500)),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) _abandonar();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Salir', icon: const Icon(Symbols.close), onPressed: _abandonar),
          title: Text(c.esprint != null ? 'Esprint 60 s' : 'Sin cuenta atrás'),
        ),
        body: SafeArea(
          child: TecladoFisico(
            entrada: _entrada,
            alEnviar: _comprobar,
            child: Column(
              children: [
                Expanded(child: cuerpo),
                if (esNumerico)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(children: [
                      TecladoNumerico(entrada: _entrada, senales: ref.read(senalesProvider), habilitado: falla == null),
                      const SizedBox(height: 8),
                      AnchoMaximo(
                        ancho: anchoTeclado,
                        child: ListenableBuilder(
                          listenable: _entrada,
                          builder: (context, _) => SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              key: const ValueKey('comprobar-crono'),
                              onPressed: falla == null && !_entrada.vacia ? _comprobar : null,
                              child: const Text('Comprobar'),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abandonar() {
    // Salir a mitad anula la marca, como una interrupción.
    _c?.interrumpir();
    _tic?.cancel();
    _falloTimer?.cancel();
    setState(() => _fase = _Fase.seleccion);
  }
}

/// Selección de habilidad y modalidad (M36).
class _Seleccion extends ConsumerWidget {
  const _Seleccion({required this.sinCuentaAtras, required this.alCambiarModo, required this.alEmpezar});
  final bool sinCuentaAtras;
  final ValueChanged<bool> alCambiarModo;
  final ValueChanged<String> alEmpezar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contenido = ref.watch(contenidoProvider).value;
    final proy = ref.watch(proyeccionProvider);
    final sesiones = ref.watch(aprendizajeProvider).value?.sesiones ?? const <SessionRecord>[];
    final forzado = ref.watch(ajustesProvider).sinLimiteTiempo;
    if (contenido == null || proy == null) return const Scaffold(body: Esqueleto());
    final skills = contenido.global.skills.where((s) => contenido.itinerarios.values.any((it) => it.variants.any((v) => v.skillId == s.id))).toList();
    final estados = {for (final s in skills) s.id: estadoCrono(proy.estadoHabilidad(s.id))};
    final mensaje = mensajeSeleccion(estados);
    final sinLimite = sinCuentaAtras || forzado;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(Rutas.practicar),
        ),
        title: const Text('Contrarreloj'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnchoMaximo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Esprint 60 s'), icon: Icon(Symbols.timer)),
                    ButtonSegment(value: true, label: Text('Sin cuenta atrás'), icon: Icon(Symbols.timer_off)),
                  ],
                  selected: {sinLimite},
                  onSelectionChanged: forzado ? null : (s) => alCambiarModo(s.first),
                ),
                const SizedBox(height: 12),
                Text(
                  sinLimite
                      ? (forzado
                          ? 'Tienes activado «Ejercicios sin límite de tiempo»: una serie de $ejerciciosSerieSinLimite ejercicios sin cuenta atrás. Al final verás tu tiempo medio.'
                          : 'Una serie de $ejerciciosSerieSinLimite ejercicios sin cuenta atrás. Al final verás tu tiempo medio.')
                      : 'Cada fallo resta 3 s y corta el multiplicador. Con menos del 90 % de precisión la marca no cuenta para récords ni ligas.',
                  style: context.textos.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (mensaje != null)
                  Tarjeta(
                    tinte: true,
                    child: Row(children: [
                      Icon(Symbols.lock, color: context.vtm.primario),
                      const SizedBox(width: 12),
                      Expanded(child: Text(mensaje, key: const ValueKey('mensaje-sin-consolidar'), style: context.textos.titleSmall)),
                    ]),
                  ),
                if (mensaje != null) const SizedBox(height: 16),
                for (final s in skills) ...[
                  _FilaHabilidad(
                    skillId: s.id,
                    nombre: s.name,
                    estado: estados[s.id]!,
                    mejor: sesionMejorMarca(sesiones, s.id),
                    alEmpezar: () => alEmpezar(s.id),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaHabilidad extends StatelessWidget {
  const _FilaHabilidad({required this.skillId, required this.nombre, required this.estado, required this.mejor, required this.alEmpezar});
  final String skillId;
  final String nombre;
  final EstadoHabilidadCrono estado;
  final SessionRecord? mejor;
  final VoidCallback alEmpezar;

  @override
  Widget build(BuildContext context) {
    final e = elegibilidad(estado);
    final r = mejor?.summary;
    final detalle = !e.abierta
        ? 'Consolida esta habilidad para abrirla'
        : (r == null ? 'Sin marca todavía' : 'Mejor marca: ${r.correct} aciertos · ${porcentaje(r.accuracy)}');
    return Tarjeta(
      key: ValueKey('habilidad-$skillId'),
      onTap: e.abierta
          ? null
          : () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('$skillId · $nombre'),
                  content: Text(e.mensaje!, key: const ValueKey('explicacion-consolidar')),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
                ),
              ),
      child: Row(
        children: [
          Icon(e.abierta ? Symbols.bolt : Symbols.lock, color: e.abierta ? context.vtm.primario : context.vtm.atenuado),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$skillId · $nombre', style: context.textos.titleSmall),
              Text(detalle, style: context.textos.bodySmall?.copyWith(color: context.vtm.atenuado)),
            ]),
          ),
          if (e.abierta) FilledButton(key: ValueKey('empezar-$skillId'), onPressed: alEmpezar, child: const Text('Empezar')),
        ],
      ),
    );
  }
}

/// Cierre del esprint (M38 con récord, M39 marca no válida).
class _Resumen extends StatelessWidget {
  const _Resumen({required this.c, required this.anterior, required this.alOtraVez, required this.alSalir});
  final ControladorCrono c;
  final int? anterior;
  final VoidCallback alOtraVez;
  final VoidCallback alSalir;

  @override
  Widget build(BuildContext context) {
    final r = c.resultado();
    final vtm = context.vtm;
    final sinLimite = c.serie != null;
    final noValida = sinLimite ? null : r.mensajeNoValida;
    Widget dato(String etiqueta, String valor) => Expanded(
          child: Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(etiqueta, style: context.textos.bodySmall?.copyWith(color: vtm.atenuado)),
              Text(valor, style: estiloCifra(context, size: 20)),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(sinLimite ? 'Serie sin cuenta atrás' : 'Esprint')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AnchoMaximo(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (noValida != null)
                  Tarjeta(
                    key: const ValueKey('marca-no-valida'),
                    child: Row(children: [
                      Icon(Symbols.error, color: vtm.errorFuerte),
                      const SizedBox(width: 12),
                      Expanded(child: Text(noValida, style: context.textos.titleSmall?.copyWith(color: vtm.errorFuerte))),
                    ]),
                  )
                else if (!sinLimite) ...[
                  Text('${r.aciertos} aciertos', style: context.textos.headlineMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    if (r.esRecord) const Etiqueta('Nuevo récord', key: ValueKey('nuevo-record'), icono: Symbols.emoji_events, tono: TonoEtiqueta.acento),
                    const Etiqueta('Marca válida', icono: Symbols.verified, tono: TonoEtiqueta.exito),
                  ]),
                ] else
                  Text('Tiempo medio: ${segundosEs(r.tiempoMedioMs)}', key: const ValueKey('tiempo-medio'), style: context.textos.headlineSmall),
                const SizedBox(height: 16),
                Row(children: [
                  dato('Aciertos', '${r.aciertos}'),
                  const SizedBox(width: 8),
                  dato('Precisión', '${r.precisionPct} %'),
                  const SizedBox(width: 8),
                  dato('Tiempo medio', segundosEs(r.tiempoMedioMs)),
                ]),
                if (!sinLimite && anterior != null) ...[
                  const SizedBox(height: 8),
                  Text('Anterior: $anterior', style: context.textos.bodyMedium),
                ],
                if (c.fallos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TituloSeccion(c.fallos.length == 1 ? '1 fallo pasa al repaso' : '${c.fallos.length} fallos pasan al repaso'),
                  for (final f in c.fallos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('${f.variante.question} Era ${f.correcta}', style: context.textos.bodyMedium),
                    ),
                ],
                if (noValida != null) ...[
                  const SizedBox(height: 12),
                  Text('Baja el ritmo: con 9 de cada 10 bien, la marca cuenta.', style: context.textos.bodyMedium),
                ],
                const SizedBox(height: 24),
                FilledButton(key: const ValueKey('otra-vez'), onPressed: alOtraVez, child: const Text('Otra vez')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: alSalir, child: const Text('Salir')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
