import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/data/api_client.dart';
import '../servicio_cuenta.dart';

/// Cuenta: correo con código de un solo uso, Apple y Google (M02–M03).

final _correoValido = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String _mensajeError(Object e) => switch (e) {
      SinConexionException() => textoCuentaSinConexion,
      ApiException(:final message) => message,
      _ => 'No se ha podido completar. Inténtalo de nuevo.',
    };

/// Tras iniciar sesión: completa el alta si la cuenta ya la tenía, ofrece la
/// organización del dominio y vuelve al punto de entrenamiento.
Future<void> _trasAcceso(BuildContext context, WidgetRef ref, ResultadoAcceso r) async {
  final u = ref.read(usuarioProvider).value!;
  var destino = Rutas.inicio;
  if (!u.altaCompletada) {
    if (r.perfilCompleto) {
      await ref.read(usuarioProvider.notifier).completarAlta();
    } else {
      destino = Rutas.altaSector;
    }
  }
  if (!context.mounted) return;
  if (r.oferta != null) {
    final ver = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tu organización te ofrece una plaza'),
        content: Text('${r.oferta!.nombre} tiene plazas para tu correo. Al unirte tendrás Premium. Antes de unirte verás qué datos tuyos podrá ver.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Ahora no')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ver la organización')),
        ],
      ),
    );
    if (!context.mounted) return;
    if (ver == true && ref.read(usuarioProvider).value!.altaCompletada) {
      context.go(Rutas.organizacion);
      return;
    }
  }
  context.go(destino);
}

class PantallaCuenta extends ConsumerStatefulWidget {
  const PantallaCuenta({super.key});
  @override
  ConsumerState<PantallaCuenta> createState() => _PantallaCuentaState();
}

class _PantallaCuentaState extends ConsumerState<PantallaCuenta> {
  final _correo = TextEditingController();
  String? _error;
  bool _enviando = false;

  bool get _acceso => GoRouterState.of(context).uri.queryParameters['modo'] == 'acceso';

  bool _iniciado = false;

  @override
  void initState() {
    super.initState();
    _correo.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    // Al volver desde el código se conserva el correo escrito.
    _correo.text = GoRouterState.of(context).uri.queryParameters['email'] ?? '';
  }

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  Future<void> _pedirCodigo() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(servicioCuentaProvider).pedirCodigo(_correo.text);
      if (!mounted) return;
      context.go(Uri(path: Rutas.codigo, queryParameters: {'email': _correo.text.trim().toLowerCase()}).toString());
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _proveedor(String proveedor) async {
    setState(() => _error = null);
    // En desarrollo el servidor acepta `dev:<correo>`; en producción el token
    // lo da el proveedor (pendiente de credenciales: el servidor lo explica).
    final token = kDebugMode && _correoValido.hasMatch(_correo.text.trim()) ? 'dev:${_correo.text.trim().toLowerCase()}' : '';
    if (kDebugMode && token.isEmpty) {
      setState(() => _error = 'Escribe tu correo arriba para el acceso de desarrollo con ${proveedor == 'apple' ? 'Apple' : 'Google'}.');
      return;
    }
    try {
      final r = await ref.read(servicioCuentaProvider).accederConProveedor(proveedor, token);
      if (mounted) await _trasAcceso(context, ref, r);
    } catch (e) {
      if (mounted) setState(() => _error = _mensajeError(e));
    }
  }

  Future<void> _ahoraNo() async {
    final u = ref.read(usuarioProvider).value!;
    if (!u.altaCompletada) {
      context.go(Rutas.bienvenida);
      return;
    }
    await ref.read(usuarioProvider.notifier).posponerRegistro();
    if (mounted) context.go(Rutas.inicio);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final enLinea = ref.watch(enLineaProvider);
    final valido = _correoValido.hasMatch(_correo.text.trim());
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Symbols.close), tooltip: 'Cerrar', onPressed: _ahoraNo)),
      body: SafeArea(
        child: AnchoMaximo(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(_acceso ? 'Entra en tu cuenta' : 'Guarda tu progreso', style: context.textos.headlineSmall),
              const SizedBox(height: 8),
              Text(
                _acceso
                    ? 'Recupera tu progreso, tus fichas de repaso y tus estadísticas.'
                    : 'Crea tu cuenta para no perder lo que llevas y entrenar en otros dispositivos.',
                style: context.textos.bodyMedium?.copyWith(color: c.atenuado),
              ),
              if (!enLinea) ...[
                const SizedBox(height: 16),
                Tarjeta(tinte: true, child: Row(children: [const Icon(Symbols.cloud_off), const SizedBox(width: 12), const Expanded(child: Text(textoCuentaSinConexion))])),
              ],
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('campo-correo'),
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => valido && enLinea ? _pedirCodigo() : null,
                decoration: const InputDecoration(labelText: 'Correo electrónico', helperText: 'Te enviaremos un código de seis cifras. Sin contraseñas.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: c.errorFuerte))),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: valido && enLinea && !_enviando ? _pedirCodigo : null,
                child: const Text('Enviarme el código'),
              ),
              const SizedBox(height: 16),
              Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('o', style: TextStyle(color: c.atenuado))), const Expanded(child: Divider())]),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: enLinea ? () => _proveedor('apple') : null, icon: const Icon(Symbols.ios), label: const Text('Continuar con Apple')),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: enLinea ? () => _proveedor('google') : null, icon: const Icon(Symbols.account_circle), label: const Text('Continuar con Google')),
              const SizedBox(height: 16),
              TextButton(onPressed: _ahoraNo, child: Text(_acceso ? 'Volver' : 'Ahora no')),
            ],
          ),
        ),
      ),
    );
  }
}

class PantallaCodigo extends ConsumerStatefulWidget {
  const PantallaCodigo({super.key, required this.email});
  final String email;
  @override
  ConsumerState<PantallaCodigo> createState() => _PantallaCodigoState();
}

class _PantallaCodigoState extends ConsumerState<PantallaCodigo> {
  final _codigo = TextEditingController();
  final _foco = FocusNode();
  String? _error;
  bool _verificando = false;
  int _espera = 60;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _arrancarEspera();
  }

  void _arrancarEspera() {
    _temporizador?.cancel();
    _espera = 60;
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _espera = _espera > 0 ? _espera - 1 : 0);
      if (_espera == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _codigo.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _cambio(String v) async {
    setState(() => _error = null);
    // Se comprueba al completar la sexta cifra.
    if (v.length == 6 && !_verificando) await _verificar(v);
  }

  Future<void> _verificar(String codigo) async {
    setState(() => _verificando = true);
    try {
      final r = await ref.read(servicioCuentaProvider).verificarCodigo(widget.email, codigo);
      if (mounted) await _trasAcceso(context, ref, r);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException && e.code == 'invalid_code' ? textoCodigoIncorrecto : _mensajeError(e);
        _codigo.clear();
        // Tras un error se puede pedir otro código al momento.
        _temporizador?.cancel();
        _espera = 0;
      });
      _foco.requestFocus();
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _reenviar() async {
    try {
      await ref.read(servicioCuentaProvider).pedirCodigo(widget.email);
      setState(() => _error = null);
      _arrancarEspera();
    } catch (e) {
      setState(() => _error = _mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final texto = _codigo.text;
    final mm = '${_espera ~/ 60}:${(_espera % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          tooltip: 'Cambiar el correo',
          onPressed: () => context.go(Uri(path: Rutas.cuenta, queryParameters: {'email': widget.email}).toString()),
        ),
      ),
      body: SafeArea(
        child: AnchoMaximo(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text('Revisa tu correo', style: context.textos.headlineSmall),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Escribe el código que hemos enviado a '),
                  TextSpan(text: widget.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '.'),
                ]),
                style: context.textos.bodyMedium,
              ),
              const SizedBox(height: 24),
              Stack(
                children: [
                  // Casillas visibles (solo dibujo); el campo real está encima, transparente.
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 6; i++)
                          Container(
                            width: 46,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _error != null ? c.errorTinte : c.superficie,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _error != null ? c.error : (i == texto.length ? c.primario : c.borde),
                                width: i == texto.length || _error != null ? 2 : 1,
                              ),
                            ),
                            child: Text(i < texto.length ? texto[i] : '', style: estiloCifra(context, size: 24)),
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.01,
                      child: TextField(
                        key: const ValueKey('campo-codigo'),
                        controller: _codigo,
                        focusNode: _foco,
                        autofocus: true,
                        enabled: !_verificando,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                        onChanged: _cambio,
                        decoration: const InputDecoration(labelText: 'Código de seis cifras', border: InputBorder.none, filled: false),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null)
                Semantics(
                  liveRegion: true,
                  child: Row(children: [
                    Icon(Symbols.error, color: c.errorFuerte, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, key: const ValueKey('error-codigo'), style: TextStyle(color: c.errorFuerte))),
                  ]),
                )
              else
                Text('Admite autorrelleno y pegado. Se comprueba al completar la sexta cifra.', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _espera == 0 ? _reenviar : null,
                child: Text(_espera == 0 ? 'Reenviar el código' : 'Reenviar el código en $mm'),
              ),
              const SizedBox(height: 8),
              FilledButton(onPressed: texto.length == 6 && !_verificando ? () => _verificar(texto) : null, child: const Text('Verificar')),
            ],
          ),
        ),
      ),
    );
  }
}
