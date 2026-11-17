import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
import '../../../core/contenido/actualizador.dart';
import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../../../core/sync/sincronizador.dart';
import '../../ads/ui/pausa_promocional.dart';
import '../../progress/domain/projections.dart';
import '../../review/domain/review_projection.dart';
import '../domain/motor_sesion.dart';
import 'borrador.dart';
import 'correccion.dart';
import 'fin_sesion.dart';

/// Sesión de ejercicios a pantalla completa, sin navegación principal
/// (exercise-session, M17–M31, T02, T03, T06).
///
/// Parámetros de la ruta: `modo` (leccion, repaso, practica), `leccion`,
/// `calentamiento=1` y `habilidad`.
class PantallaSesion extends ConsumerStatefulWidget {
  const PantallaSesion({super.key, required this.parametros});
  final Map<String, String> parametros;

  /// Motor de la última sesión abierta (solo para las pruebas).
  @visibleForTesting
  static MotorSesion? ultimoMotor;

  @override
  ConsumerState<PantallaSesion> createState() => _PantallaSesionState();
}

const textoSalirTitulo = '¿Salir de la lección?';
const textoSegundoIntento = 'Segundo intento · no puntúa';

class _PantallaSesionState extends ConsumerState<PantallaSesion> with WidgetsBindingObserver {
  MotorSesion? _motor;
  String? _error;
  bool _fin = false;
  DatosFin? _datosFin;
  Proyeccion? _antes;
  bool _eraPrimeraLeccion = false;

  // Estado de la respuesta del ejercicio actual. La entrada vive aquí, no en
  // el diseño: girar la tablet no pierde lo escrito.
  final _entrada = EntradaNumerica();
  String? _unidad;
  String? _opcion;
  final List<String> _orden = [];
  final List<String?> _serie = [];
  final List<bool> _marcasSerie = [];
  int _pistas = 0;
  String? _varianteMostrada;

  // Cuentas atrás visibles (T6 informativa, T7 de 60 s).
  Timer? _cuentaAtras;
  int _restanteS = 0;
  bool _enSegundoPlano = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entrada.alRechazo = _rechazo;
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cuentaAtras?.cancel();
    _entrada.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final m = _motor;
    if (m == null) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      _enSegundoPlano = true;
      m.pausar();
    } else if (state == AppLifecycleState.resumed) {
      _enSegundoPlano = false;
      m.reanudar();
    }
  }

  Dependencias get _deps => ref.read(dependenciasProvider);

  void _rechazo() {
    // Segunda coma: no se escribe y hay una señal háptica breve.
    if (ref.read(ajustesProvider).haptica) _deps.vibrador.vibrar(Senal.aviso);
  }

  // ---- Preparación ---------------------------------------------------------

  Future<void> _preparar() async {
    try {
      // El contenido nuevo solo se aplica entre sesiones: justo antes de crear el motor.
      final cambio = await ref.read(actualizadorProvider).aplicarPreparadas();
      if (cambio) await ref.read(contenidoProvider.notifier).recargar();
      final contenido = await ref.read(contenidoProvider.future);
      final usuario = await ref.read(usuarioProvider.future);
      await ref.read(aprendizajeProvider.future);
      if (!mounted) return;
      final p = widget.parametros;
      final modoTxt = p['modo'] ?? 'leccion';
      final proyeccion = ref.read(proyeccionProvider);
      _antes = proyeccion;
      Lesson? leccion;
      if (modoTxt == 'leccion') {
        leccion = _buscarLeccion(contenido, p['leccion']);
        if (leccion == null) {
          setState(() => _error = 'No se encuentra la lección en el contenido descargado.');
          return;
        }
      }
      final modo = switch (modoTxt) { 'repaso' => SessionMode.review, 'practica' => SessionMode.practice, _ => SessionMode.lesson };
      final cola = proyeccion?.colaHoy ?? const <FichaRepaso>[];
      final derechos = ref.read(derechosEfectivosProvider);
      _eraPrimeraLeccion = !usuario.primeraLeccionHecha;
      final m = MotorSesion(
        contenido: contenido,
        modo: modo,
        deviceId: usuario.deviceId,
        relojMs: _deps.relojMs,
        ahora: _deps.reloj.ahora,
        leccion: leccion,
        calentamiento: modo == SessionMode.lesson && p['calentamiento'] == '1' ? cola.take(5).toList() : const [],
        fichasRepaso: modo == SessionMode.review ? cola : const [],
        variantesPractica: modo == SessionMode.practice ? _variantesPractica(contenido, p['habilidad']) : const [],
        sinAnuncios: derechos.premium || derechos.sinAnuncios,
        esPrimeraLeccion: _eraPrimeraLeccion && modo == SessionMode.lesson,
        frecuenciaAnuncios: contenido.global.adParams.frequencyTouch,
        azar: _deps.azar,
        alRegistrar: (a) => ref.read(aprendizajeProvider.notifier).registrarIntento(a),
        alEvento: (n, props) => ref.read(aprendizajeProvider.notifier).registrarEvento(n, props),
      )..preparar();
      PantallaSesion.ultimoMotor = m;
      setState(() {
        _motor = m;
        _alCambiarFase();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se ha podido preparar la sesión: $e');
    }
  }

  Lesson? _buscarLeccion(ContenidoCargado c, String? id) {
    for (final it in c.itinerarios.values) {
      for (final l in it.lessons) {
        if (l.id == id) return l;
      }
    }
    return null;
  }

  /// Práctica libre de una habilidad: unas diez variantes de sus plantillas.
  List<Variant> _variantesPractica(ContenidoCargado c, String? skillId) {
    final porPlantilla = <String, List<Variant>>{};
    for (final it in c.itinerarios.values) {
      for (final v in it.variants) {
        if (v.skillId != skillId || c.revocaciones.retirada(v)) continue;
        if (motivoDefecto(v, c.tipo(v.exerciseTypeId)) != null) continue;
        porPlantilla.putIfAbsent(v.itemKey, () => []).add(v);
      }
    }
    final claves = porPlantilla.keys.toList()..sort();
    final out = <Variant>[];
    var i = 0;
    while (out.length < 10 && claves.isNotEmpty && i < 40) {
      final l = porPlantilla[claves[i % claves.length]]!;
      out.add(l[_deps.azar.nextInt(l.length)]);
      i++;
    }
    return out;
  }

  // ---- Cambios de fase -----------------------------------------------------

  void _alCambiarFase() {
    final m = _motor!;
    if (m.fase == FaseSesion.ejercicio && m.actual!.variante.id != _varianteMostrada) {
      _varianteMostrada = m.actual!.variante.id;
      _entrada.limpiar();
      _unidad = null;
      _opcion = null;
      _orden.clear();
      _serie.clear();
      _marcasSerie.clear();
      _pistas = 0;
      _iniciarCuentaAtras(m.actual!);
    } else if (m.fase != FaseSesion.ejercicio) {
      _cuentaAtras?.cancel();
    }
    if (m.fase == FaseSesion.terminada && !_fin) {
      _fin = true;
      unawaited(_finalizar());
    }
  }

  void _iniciarCuentaAtras(EjercicioPreparado e) {
    _cuentaAtras?.cancel();
    final sinLimite = ref.read(ajustesProvider).sinLimiteTiempo;
    if (e.bloque == 'conversion_series') {
      _restanteS = e.variante.targetTimeS > 0 ? e.variante.targetTimeS : 60;
    } else if (e.bloque == 'range_choice') {
      _restanteS = e.variante.targetTimeS;
    } else {
      return;
    }
    if (sinLimite) return;
    _cuentaAtras = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _enSegundoPlano || _motor?.fase != FaseSesion.ejercicio) return;
      setState(() => _restanteS = _restanteS > 0 ? _restanteS - 1 : 0);
      if (_restanteS == 0) {
        _cuentaAtras?.cancel();
        // En T7 el tiempo total se agota: se corrige lo contestado.
        if (_motor?.actual?.bloque == 'conversion_series') _terminarSerie();
      }
    });
  }

  Future<void> _finalizar() async {
    final m = _motor!;
    final reg = m.registro(completada: true);
    await ref.read(aprendizajeProvider.notifier).registrarSesion(reg);
    final esLeccion = m.modo == SessionMode.lesson;
    if (esLeccion) await ref.read(usuarioProvider.notifier).marcarPrimeraLeccion();
    unawaited(ref.read(sincronizadorProvider).sincronizar().catchError((_) {}));
    final despues = ref.read(proyeccionProvider);
    final contenido = m.contenido;
    if (!mounted) return;
    setState(() {
      _datosFin = DatosFin(
        motor: m,
        cambios: _antes != null && despues != null ? cambiosDeEstado(_antes!.mapaEstados, despues.mapaEstados) : const [],
        nombreHabilidad: contenido.global.skillName,
        nivelAntes: _antes?.nivel.nivel,
        nivelDespues: despues?.nivel.nivel,
        racha: despues?.racha,
        titulo: m.modo == SessionMode.review && m.resultados.isEmpty ? 'No tienes fichas para hoy' : null,
      );
    });
  }

  void _salirAlFinal() {
    final u = ref.read(usuarioProvider).value;
    final m = _motor!;
    if (m.modo == SessionMode.lesson && u != null) {
      if (_eraPrimeraLeccion && !u.conCuenta && !u.registroPospuesto) {
        context.go(Rutas.cuenta);
        return;
      }
      if (!u.notificacionesOfrecidas) {
        context.go(Rutas.permisoNotificaciones);
        return;
      }
    }
    context.go(m.modo == SessionMode.lesson ? Rutas.inicio : Rutas.practicar);
  }

  // ---- Acciones ------------------------------------------------------------

  bool get _puedeComprobar {
    final e = _motor?.actual;
    if (e == null || _motor!.fase != FaseSesion.ejercicio) return false;
    return switch (e.bloque) {
      'numeric_unit' => !_entrada.vacia && (!e.unidadAElegir || _unidad != null),
      'single_choice' || 'range_choice' => _opcion != null,
      'ordering' => _orden.length == (e.variante.orderItems?.length ?? 0),
      'conversion_series' => !_entrada.vacia,
      _ => false,
    };
  }

  void _comprobar() {
    final m = _motor!;
    final e = m.actual;
    if (e == null || !_puedeComprobar) return;
    if (e.bloque == 'conversion_series') {
      _siguienteConversion();
      return;
    }
    final r = switch (e.bloque) {
      'numeric_unit' => m.responderNumerico(_entrada.texto, unidad: e.unidadAElegir ? _unidad : null, pistas: _pistas),
      'ordering' => m.responderOrden(List.of(_orden), pistas: _pistas),
      _ => m.responderOpcion(_opcion!, pistas: _pistas),
    };
    _tras(r);
  }

  void _siguienteConversion() {
    final m = _motor!;
    final i = _serie.length;
    final ok = m.corregirConversion(i, _entrada.texto);
    setState(() {
      _serie.add(_entrada.texto);
      _marcasSerie.add(ok);
      _entrada.limpiar();
    });
    if (_serie.length >= (m.actual!.variante.series?.length ?? 0)) _terminarSerie();
  }

  void _terminarSerie() {
    final m = _motor!;
    if (m.fase != FaseSesion.ejercicio) return;
    _tras(m.responderSerie(List.of(_serie)));
  }

  void _noLoSe() => _tras(_motor!.noLoSe());

  void _tras(ResultadoEjercicio r) {
    _cuentaAtras?.cancel();
    final senales = ref.read(senalesProvider);
    unawaited(senales.emitir(r.acierto ? Senal.acierto : Senal.fallo));
    final vista = View.maybeOf(context);
    if (vista != null) unawaited(SemanticsService.sendAnnouncement(vista, anuncioVeredicto(r), TextDirection.ltr));
    setState(_alCambiarFase);
  }

  void _continuar() {
    final m = _motor!;
    // Los derechos pueden haber cambiado (compra desde un anuncio).
    final d = ref.read(derechosEfectivosProvider);
    if (d.premium || d.sinAnuncios) m.sinAnuncios = true;
    m.continuar();
    setState(_alCambiarFase);
  }

  void _segundoIntento() {
    _motor!.iniciarSegundoIntento();
    setState(_alCambiarFase);
  }

  void _cerrarPausa(ResultadoPausa r) {
    final m = _motor!;
    final d = ref.read(derechosEfectivosProvider);
    if (r.compro || d.premium || d.sinAnuncios) m.sinAnuncios = true;
    m.cerrarPausa();
    setState(_alCambiarFase);
  }

  Future<void> _confirmarSalida() async {
    final m = _motor;
    if (m == null || _fin) {
      if (_fin && m != null) {
        _salirAlFinal();
      } else {
        context.go(Rutas.inicio);
      }
      return;
    }
    final hechos = m.primerosIntentos.length;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(textoSalirTitulo),
        content: Text('Se guarda lo hecho hasta aquí: $hechos de ${m.total} ejercicios. La lección quedará sin completar.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Seguir con la lección')),
          FilledButton(key: const ValueKey('confirmar-salir'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salir')),
        ],
      ),
    );
    if (salir != true || !mounted) return;
    await ref.read(aprendizajeProvider.notifier).registrarSesion(m.registro(completada: false));
    if (mounted) context.go(m.modo == SessionMode.lesson ? Rutas.inicio : Rutas.practicar);
  }

  void _informarError(ResultadoEjercicio r) {
    final v = r.ejercicio.variante;
    context.push(Rutas.consulta, extra: {
      'type': 'exercise_error',
      'variantId': v.id,
      'templateId': v.templateId,
      'questionId': v.questionId,
      'answerValue': r.valor,
      'answerUnit': r.unidad,
    });
  }

  // ---- Dibujo --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final m = _motor;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        body: SafeArea(
          child: _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : m == null
                  ? const Esqueleto()
                  : _cuerpo(m),
        ),
      ),
    );
  }

  Widget _cuerpo(MotorSesion m) {
    if (m.fase == FaseSesion.pausaPromocional) {
      return PausaPromocional(
        datos: DatosPausa(
          modo: m.modo,
          sessionId: m.sessionId,
          ejerciciosLeccion: m.total,
          aciertosLeccion: m.primerosIntentos.where((r) => r.acierto).length,
          ultimaPausa: m.ultimaPausa,
          leccionConFallos: m.fallos.isNotEmpty,
          unidadCompletada: m.retoSuperado,
        ),
        alCerrar: _cerrarPausa,
      );
    }
    if (m.fase == FaseSesion.terminada) {
      final d = _datosFin;
      if (d == null) return const Esqueleto();
      return FinSesion(
        datos: d,
        alContinuar: _salirAlFinal,
        alRepasar: m.modo == SessionMode.lesson ? () => context.go(Rutas.sesionRepaso()) : null,
      );
    }
    final tablet = ClaseAncho.de(context).dosPaneles;
    final izquierda = Column(children: [
      _BarraSesion(motor: m, alCerrar: _confirmarSalida),
      Expanded(child: m.fase == FaseSesion.correccion ? _correccion(m, tablet) : _ejercicio(m)),
    ]);
    if (!tablet) return izquierda;
    final derecha = m.fase == FaseSesion.correccion
        ? ListView(padding: const EdgeInsets.all(16), children: [
            PasosExplicacion(variante: m.ultimoResultado!.ejercicio.variante, pasoDesvio: m.ultimoResultado!.pasoDesvio),
            const SizedBox(height: 8),
            _enlaceInformar(m.ultimoResultado!),
          ])
        : Borrador(key: ValueKey('borrador-${m.actual?.variante.id}-${m.actual?.intentoNumero}'));
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: AnchoMaximo(child: izquierda)),
      VerticalDivider(width: 1, color: context.vtm.borde),
      Expanded(child: derecha),
    ]);
  }

  Widget _enlaceInformar(ResultadoEjercicio r) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Symbols.flag),
          onPressed: () => _informarError(r),
          label: const Text('Informar de un error en este ejercicio'),
        ),
      );

  Widget _ejercicio(MotorSesion m) {
    final e = m.actual!;
    final v = e.variante;
    final c = context.vtm;
    final senales = ref.read(senalesProvider);
    final superior = <Widget>[
      if (e.intentoNumero == 2) ...[const Etiqueta(textoSegundoIntento, icono: Symbols.replay, tono: TonoEtiqueta.acento), const SizedBox(height: 10)],
      if (e.ficha != null) ...[
        Etiqueta(motivoFicha(e.ficha!, _deps.reloj.ahora()), icono: Symbols.history, tono: TonoEtiqueta.aviso),
        const SizedBox(height: 10),
      ],
      if (m.esReto) ...[const Etiqueta('Reto de unidad · sin pistas', icono: Symbols.flag), const SizedBox(height: 10)],
      if (e.unidadAElegir) ...[Etiqueta('Nivel ${v.level} · eliges la unidad', tono: TonoEtiqueta.primario), const SizedBox(height: 10)],
      if (e.bloque == 'range_choice' || e.bloque == 'conversion_series') ...[
        Row(children: [
          Etiqueta(
            ref.read(ajustesProvider).sinLimiteTiempo ? 'Sin límite de tiempo' : '$_restanteS s',
            icono: Symbols.timer,
            tono: _restanteS <= 10 ? TonoEtiqueta.aviso : TonoEtiqueta.neutro,
          ),
        ]),
        const SizedBox(height: 10),
      ],
      Enunciado(v),
      if (e.planteamientoVisible && (v.approach ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('planteamiento'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.primarioTinte, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Planteamiento', style: context.textos.labelLarge?.copyWith(color: c.primario)),
            const SizedBox(height: 4),
            Text(v.approach!, style: estiloCifra(context, size: 15, weight: FontWeight.w500)),
          ]),
        ),
      ],
      if (_pistas > 0 && (v.hint ?? '').isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('pista'),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.acentoTinte, borderRadius: BorderRadius.circular(12)),
          child: Text('Pista: ${v.hint}', style: context.textos.bodyMedium),
        ),
      ],
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (m.pistasPermitidas && (v.hint ?? '').isNotEmpty && _pistas == 0)
          TextButton.icon(key: const ValueKey('boton-pista'), onPressed: () => setState(() => _pistas++), icon: const Icon(Symbols.lightbulb), label: const Text('Pista')),
        TextButton.icon(key: const ValueKey('no-lo-se'), onPressed: _noLoSe, icon: const Icon(Symbols.help), label: const Text('No lo sé')),
      ]),
      const SizedBox(height: 8),
      ..._respuestaSuperior(e),
    ];
    final inferior = _respuestaInferior(e, senales);
    return TecladoFisico(
      entrada: _entrada,
      senales: senales,
      alEnviar: _comprobar,
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('scroll-ejercicio'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: superior),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: inferior),
      ]),
    );
  }

  /// Parte desplazable de la respuesta (opciones, pasos, serie).
  List<Widget> _respuestaSuperior(EjercicioPreparado e) {
    final v = e.variante;
    switch (e.bloque) {
      case 'single_choice' || 'range_choice':
        final letras = 'ABCDEFGH';
        return [
          for (final (i, o) in v.options!.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tarjeta(
                key: ValueKey('opcion-${o.id}'),
                seleccionada: _opcion == o.id,
                semantica: 'Opción ${letras[i % letras.length]}: ${o.value != null && o.unit != null ? lecturaCantidad(o.value!, o.unit!) : o.label}',
                onTap: () => setState(() => _opcion = o.id),
                child: Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: context.vtm.superficie2, child: Text(letras[i % letras.length], style: context.textos.labelLarge)),
                  const SizedBox(width: 14),
                  Expanded(child: Text(o.label, style: estiloCifra(context, size: 18, weight: FontWeight.w500))),
                ]),
              ),
            ),
        ];
      case 'ordering':
        final items = {for (final i in v.orderItems!) i.id: i};
        final pendientes = v.orderItems!.where((i) => !_orden.contains(i.id)).toList();
        return [
          Text('Toca los pasos en orden.', style: context.textos.bodySmall),
          const SizedBox(height: 8),
          for (var p = 0; p < v.orderItems!.length; p++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tarjeta(
                key: ValueKey('posicion-$p'),
                semantica: p < _orden.length ? 'Posición ${p + 1}: ${items[_orden[p]]!.text}' : 'Posición ${p + 1}, vacía',
                child: Row(children: [
                  Text('${p + 1}', style: context.textos.titleSmall),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p < _orden.length ? items[_orden[p]]!.text : 'Posición ${p + 1}', style: context.textos.bodyMedium?.copyWith(color: p < _orden.length ? null : context.vtm.atenuado))),
                ]),
              ),
            ),
          const SizedBox(height: 8),
          for (final i in pendientes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Tarjeta(
                key: ValueKey('paso-${i.id}'),
                semantica: 'Añadir paso: ${i.text}',
                onTap: () => setState(() => _orden.add(i.id)),
                child: Row(children: [
                  const Icon(Symbols.add_circle),
                  const SizedBox(width: 12),
                  Expanded(child: Text(i.text, style: context.textos.bodyMedium)),
                ]),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('deshacer'),
              onPressed: _orden.isEmpty ? null : () => setState(_orden.removeLast),
              icon: const Icon(Symbols.undo),
              label: const Text('Deshacer'),
            ),
          ),
        ];
      case 'conversion_series':
        final serie = v.series!;
        final i = _serie.length.clamp(0, serie.length - 1);
        return [
          Text('Conversión ${i + 1} de ${serie.length} · ${_marcasSerie.where((x) => x).length} aciertos', style: context.textos.titleSmall),
          const SizedBox(height: 8),
          Text(serie[i].prompt, key: const ValueKey('conversion-actual'), style: estiloCifra(context, size: 26)),
          const SizedBox(height: 8),
          for (var k = 0; k < _serie.length; k++)
            Row(children: [
              Icon(_marcasSerie[k] ? Symbols.check : Symbols.close, size: 18, color: _marcasSerie[k] ? context.vtm.exito : context.vtm.errorFuerte),
              const SizedBox(width: 6),
              Expanded(child: Text('${serie[k].prompt} → ${_serie[k]}${_marcasSerie[k] ? '' : ' (incorrecta)'}', style: context.textos.bodySmall)),
            ]),
        ];
    }
    return const [];
  }

  /// Parte fija inferior: campo, unidades, teclado y «Comprobar».
  Widget _respuestaInferior(EjercicioPreparado e, Senales senales) {
    final comprobar = ListenableBuilder(
      listenable: _entrada,
      builder: (context, _) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('comprobar'),
          onPressed: _puedeComprobar ? _comprobar : null,
          child: Text(e.bloque == 'conversion_series' ? 'Comprobar' : 'Comprobar'),
        ),
      ),
    );
    if (e.bloque == 'numeric_unit' || e.bloque == 'conversion_series') {
      final a = e.variante.answer;
      final unidad = e.bloque == 'numeric_unit' ? (e.unidadAElegir ? _unidad : a?.unit) : null;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        AnchoMaximo(ancho: anchoTeclado, child: CampoRespuesta(entrada: _entrada, unidad: unidad)),
        if (e.unidadAElegir) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final u in a!.unitChoices)
              ChoiceChip(
                key: ValueKey('unidad-$u'),
                label: Text(u, style: estiloCifra(context, size: 16, weight: FontWeight.w500)),
                selected: _unidad == u,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (_) => setState(() => _unidad = u),
              ),
          ]),
        ],
        const SizedBox(height: 8),
        TecladoNumerico(entrada: _entrada, senales: senales),
        const SizedBox(height: 8),
        AnchoMaximo(ancho: anchoTeclado, child: comprobar),
      ]);
    }
    return comprobar;
  }

  Widget _correccion(MotorSesion m, bool tablet) {
    final r = m.ultimoResultado!;
    final mostrarPasos = !r.acierto && !tablet;
    final contenido = <Widget>[
      // El veredicto va primero: visible sin desplazarse aunque el texto esté al 200 %.
      BandaVeredicto(resultado: r),
      const SizedBox(height: 12),
      Enunciado(r.ejercicio.variante, compacto: true),
      if (r.acierto && !tablet)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('ver-como-se-hace'),
            onPressed: () => mostrarHojaExplicacion(context, r),
            icon: const Icon(Symbols.menu_book),
            label: const Text('Ver cómo se hace'),
          ),
        ),
      if (mostrarPasos) ...[const SizedBox(height: 12), PasosExplicacion(variante: r.ejercicio.variante, pasoDesvio: r.pasoDesvio)],
      if (!tablet) ...[const SizedBox(height: 4), _enlaceInformar(r)],
    ];
    return Column(children: [
      Expanded(child: ListView(key: const ValueKey('scroll-correccion'), padding: const EdgeInsets.all(16), children: contenido)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(children: [
          if (m.segundoIntentoDisponible) ...[
            Expanded(child: OutlinedButton(key: const ValueKey('segundo-intento'), onPressed: _segundoIntento, child: const Text('Probar con otros números', textAlign: TextAlign.center))),
            const SizedBox(width: 8),
          ],
          Expanded(child: FilledButton(key: const ValueKey('continuar'), onPressed: _continuar, child: const Text('Continuar'))),
        ]),
      ),
    ]);
  }
}

/// Barra superior de la sesión: cerrar y progreso segmentado.
class _BarraSesion extends StatelessWidget {
  const _BarraSesion({required this.motor, required this.alCerrar});
  final MotorSesion motor;
  final VoidCallback alCerrar;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final hechos = motor.resultados.where((r) => r.ejercicio.intentoNumero == 1).toList();
    final total = motor.total < 1 ? 1 : motor.total;
    final pos = motor.posicion.clamp(0, total);
    return SizedBox(
      height: 56,
      child: Row(children: [
        IconButton(key: const ValueKey('cerrar-sesion'), tooltip: 'Cerrar la sesión', icon: const Icon(Symbols.close), onPressed: alCerrar),
        Expanded(
          child: Semantics(
            label: 'Ejercicio $pos de $total',
            excludeSemantics: true,
            child: Row(children: [
              for (var i = 0; i < total; i++)
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: i < hechos.length ? (hechos[i].acierto ? c.exito : c.error) : (i == hechos.length ? c.primario : c.borde),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(motor.modo == SessionMode.review ? '$pos / $total' : '$pos de $total', style: context.textos.labelLarge),
        ),
      ]),
    );
  }
}
