import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../core/domain/learning_models.dart';
import '../data/anuncios.dart';
import '../domain/ad_selector.dart';

/// Datos del momento de la pausa promocional que aporta la sesión.
class DatosPausa {
  const DatosPausa({
    required this.modo,
    required this.sessionId,
    this.ejerciciosLeccion = 0,
    this.aciertosLeccion = 0,
    this.ultimaPausa = false,
    this.leccionConFallos = false,
    this.unidadCompletada = false,
    this.trasContrarreloj = false,
    this.trasManosLibres = false,
  });
  final SessionMode modo;
  final String sessionId;
  final int ejerciciosLeccion;
  final int aciertosLeccion;
  final bool ultimaPausa;
  final bool leccionConFallos;
  final bool unidadCompletada;
  final bool trasContrarreloj;
  final bool trasManosLibres;
}

/// Resultado de la pausa: si el usuario ha comprado Premium desde la acción
/// del anuncio, la sesión deja de mostrar pausas (premium-subscription).
class ResultadoPausa {
  const ResultadoPausa({required this.permanenciaMs, this.compro = false, this.anuncioId});
  final int permanenciaMs;
  final bool compro;
  final String? anuncioId;
}

/// Icono incluido en la app para cada ilustración de creatividad: sin
/// imágenes de red, funciona en modo avión.
IconData iconoIlustracion(String nombre) => switch (nombre) {
      'continuous_scale' => Symbols.straighten,
      'operation_step' => Symbols.calculate,
      'seven_divisions' => Symbols.calendar_month,
      'headset_halo' => Symbols.headset_mic,
      'streak_meniscus' => Symbols.local_fire_department,
      'two_bars' => Symbols.bar_chart,
      'branching_path' => Symbols.alt_route,
      'rising_line' => Symbols.trending_up,
      'validation_seal' => Symbols.verified,
      'full_meniscus' => Symbols.water_full,
      'continuous_bar' => Symbols.linear_scale,
      'building_access' => Symbols.apartment,
      _ => Symbols.campaign,
    };

/// Pausa promocional a pantalla completa (house-ads). La sesión la muestra
/// cuando `MotorSesion.fase == FaseSesion.pausaPromocional` y llama a
/// `MotorSesion.cerrarPausa()` en [alCerrar].
///
/// Tarjeta de 560 dp como máximo, rótulo «Promoción de VolutrainMed» arriba,
/// titular, texto, ilustración, acción del anuncio y «Continuar» siempre a la
/// vista, con la cuenta atrás configurada en el contenido (0 a 5 s).
class PausaPromocional extends ConsumerStatefulWidget {
  const PausaPromocional({super.key, required this.datos, required this.alCerrar});
  final DatosPausa datos;
  final ValueChanged<ResultadoPausa> alCerrar;

  @override
  ConsumerState<PausaPromocional> createState() => _PausaPromocionalState();
}

class _PausaPromocionalState extends ConsumerState<PausaPromocional> with SingleTickerProviderStateMixin {
  AnuncioElegido? _elegido;
  bool _cargado = false;
  int _restante = 0;
  Timer? _cuenta;
  late final int _inicioMs;
  bool _cerrada = false;
  bool _enAccion = false;
  final _focoContinuar = FocusNode(debugLabel: 'Continuar');
  late final AnimationController _entrada;

  @override
  void initState() {
    super.initState();
    _inicioMs = ref.read(dependenciasProvider).relojMs();
    _entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    unawaited(_preparar());
  }

  Future<void> _preparar() async {
    final e = await elegirAnuncio(ref.read, widget.datos);
    if (!mounted) return;
    final espera = (e?.esperaS ?? ref.read(contenidoProvider).value?.global.adParams.waitS ?? 3).clamp(0, 5);
    setState(() {
      _elegido = e;
      _cargado = true;
      _restante = espera;
    });
    _entrada.forward();
    if (e != null) {
      final vista = View.of(context);
      // El lector anuncia el rótulo, el titular y el texto.
      unawaited(SemanticsService.sendAnnouncement(vista, '$rotuloPromocion. ${e.anuncio.titular}. ${e.anuncio.texto}', TextDirection.ltr));
    }
    if (_restante <= 0) {
      _activar();
    } else {
      _cuenta = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _restante--);
        if (_restante <= 0) {
          t.cancel();
          _activar();
        }
      });
    }
  }

  void _activar() {
    if (!mounted) return;
    unawaited(SemanticsService.sendAnnouncement(View.of(context), 'Ya puedes continuar', TextDirection.ltr));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focoContinuar.requestFocus();
    });
  }

  int get _permanencia => ref.read(dependenciasProvider).relojMs() - _inicioMs;

  Future<void> _cerrar({bool compro = false}) async {
    if (_cerrada) return;
    _cerrada = true;
    _cuenta?.cancel();
    final ms = _permanencia;
    final e = _elegido;
    if (e != null) await registrarImpresion(ref.read, e, widget.datos, ms);
    widget.alCerrar(ResultadoPausa(permanenciaMs: ms, compro: compro, anuncioId: e?.anuncio.id));
  }

  Future<void> _accion() async {
    final e = _elegido;
    if (e == null || _enAccion) return;
    _enAccion = true;
    await registrarAccion(ref.read, e, widget.datos);
    if (!mounted) return;
    if (e.anuncio.creatividad.ctaAction == 'org_code') {
      await context.push(Rutas.organizacion);
    } else {
      await context.push<bool>(Uri(path: Rutas.suscripcion, queryParameters: {'anuncio': e.anuncio.id}).toString());
    }
    _enAccion = false;
    if (!mounted) return;
    // Si ha comprado, la sesión sigue sin más pausas.
    if (ref.read(derechosEfectivosProvider).sinAnuncios) await _cerrar(compro: true);
  }

  @override
  void dispose() {
    _cuenta?.cancel();
    _focoContinuar.dispose();
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final reducido = MediaQuery.disableAnimationsOf(context);
    final a = _elegido?.anuncio;
    final activo = _cargado && _restante <= 0;
    final etiquetaContinuar = activo ? 'Continuar' : 'Continuar ($_restante)';
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: c.lienzo,
        body: SafeArea(
          child: FadeTransition(
            key: const ValueKey('entrada-pausa'),
            opacity: _entrada,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: anchoTarjetaAnuncio),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          key: const ValueKey('tarjeta-anuncio'),
                          decoration: BoxDecoration(color: c.superficie, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.borde)),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(rotuloPromocion.toUpperCase(), key: const ValueKey('rotulo-promocion'), style: context.textos.labelSmall?.copyWith(color: c.atenuado)),
                                ),
                                const SizedBox(height: 20),
                                if (a != null) ...[
                                  Center(child: _ilustracion(context, a.creatividad.illustration, reducido)),
                                  const SizedBox(height: 20),
                                  Text(a.titular, style: context.textos.headlineSmall),
                                  const SizedBox(height: 8),
                                  Text(a.texto, style: context.textos.bodyMedium?.copyWith(color: c.atenuado)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (a != null) ...[
                        OutlinedButton(key: const ValueKey('accion-anuncio'), onPressed: _accion, child: Text(a.accion)),
                        const SizedBox(height: 8),
                      ],
                      Semantics(
                        liveRegion: true,
                        label: activo ? 'Continuar' : 'Continuar, disponible en $_restante segundos',
                        excludeSemantics: true,
                        button: true,
                        enabled: activo,
                        child: FilledButton(
                          key: const ValueKey('continuar-pausa'),
                          focusNode: _focoContinuar,
                          onPressed: activo ? () => _cerrar() : null,
                          child: Text(etiquetaContinuar),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ilustracion(BuildContext context, String nombre, bool reducido) {
    final c = context.vtm;
    final icono = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(color: c.primarioTinte, shape: BoxShape.circle),
      child: Icon(iconoIlustracion(nombre), size: 64, color: c.primario),
    );
    // Con movimiento reducido la ilustración no se anima.
    if (reducido) return ExcludeSemantics(key: const ValueKey('ilustracion-estatica'), child: icono);
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        key: const ValueKey('ilustracion-animada'),
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: icono,
      ),
    );
  }
}
