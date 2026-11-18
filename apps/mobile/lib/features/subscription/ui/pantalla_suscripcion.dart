import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/data/api_client.dart';
import '../../../core/domain/learning_models.dart';
import '../../ads/data/anuncios.dart';
import '../../ads/domain/ad_variables.dart';
import '../data/tienda.dart';
import '../domain/entitlements_policy.dart';

const textoCompraFallida = 'La tienda no ha podido completar el pago. No se ha hecho ningún cargo.';
const textoNecesitaCuenta = 'Para suscribirte necesitas una cuenta: así Premium te sigue en todos tus dispositivos.';
const textoSinPrecios = 'No hemos podido obtener los precios de la tienda.';

/// Suscripción Premium (M57). Precio de cada plan con su periodo, fecha del
/// primer cobro si hay prueba, condiciones de renovación, cómo cancelar y un
/// botón de cierre siempre visible. Sin conexión no se muestran precios.
class PantallaSuscripcion extends ConsumerStatefulWidget {
  const PantallaSuscripcion({super.key, this.anuncioId});

  /// Anuncio desde el que se ha abierto (atribución de la compra).
  final String? anuncioId;

  @override
  ConsumerState<PantallaSuscripcion> createState() => _PantallaSuscripcionState();
}

class _PantallaSuscripcionState extends ConsumerState<PantallaSuscripcion> {
  PreciosTienda _precios = const PreciosTienda();
  bool _cargandoPrecios = true;
  bool _errorPrecios = false;
  String _plan = 'annual';
  String _simular = 'ok';
  bool _comprando = false;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    final deps = ref.read(dependenciasProvider);
    final guardados = await leerPreciosGuardados(deps.claves);
    if (mounted) setState(() => _precios = guardados);
    final enLinea = await deps.conectividad.hayConexion();
    if (enLinea) {
      try {
        final p = await refrescarPrecios(ref.read);
        if (mounted) setState(() => _precios = p);
      } on SinConexionException {
        if (mounted) setState(() => _errorPrecios = true);
      } on ApiException {
        if (mounted) setState(() => _errorPrecios = true);
      }
      await refrescarDerechos(ref.read);
    }
    if (mounted) setState(() => _cargandoPrecios = false);
  }

  void _cerrar([bool compro = false]) {
    if (context.canPop()) {
      context.pop(compro);
    } else {
      context.go(Rutas.inicio);
    }
  }

  Future<void> _comprar() async {
    final producto = _precios.producto(_plan);
    if (producto == null) return;
    final deps = ref.read(dependenciasProvider);
    if (!deps.api.conCuenta) {
      setState(() => _error = textoNecesitaCuenta);
      return;
    }
    setState(() {
      _comprando = true;
      _error = null;
    });
    final derechos = ref.read(derechosProvider);
    final r = await comprar(
      ref.read,
      producto,
      conPrueba: pruebaDisponible(derechos),
      simular: _simular,
      anuncioId: widget.anuncioId ?? ref.read(anuncioAtribuidoProvider),
    );
    if (!mounted) return;
    setState(() => _comprando = false);
    switch (r) {
      case ResultadoCompra.completada:
        _cerrar(true);
      case ResultadoCompra.cancelada:
        // Vuelve a la pantalla sin cargos y sin mensaje de error.
        break;
      case ResultadoCompra.fallida:
        setState(() => _error = textoCompraFallida);
      case ResultadoCompra.sinConexion:
        setState(() => _error = textoCompraSinConexion);
      case ResultadoCompra.sinCuenta:
        setState(() => _error = textoNecesitaCuenta);
    }
  }

  Future<void> _restaurar() async {
    final r = await restaurar(ref.read);
    if (!mounted) return;
    final premium = ref.read(derechosEfectivosProvider).sinAnuncios;
    setState(() {
      _error = null;
      _mensaje = switch (r) {
        ResultadoCompra.completada => premium ? 'Compras restauradas: Premium activo' : 'No hay compras que restaurar en esta cuenta',
        ResultadoCompra.sinCuenta => 'Inicia sesión con tu cuenta para restaurar tus compras',
        ResultadoCompra.sinConexion => 'Para restaurar compras hace falta conexión',
        _ => 'No se han podido restaurar las compras. Inténtalo más tarde',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final deps = ref.watch(dependenciasProvider);
    final enLinea = ref.watch(enLineaProvider);
    final derechos = ref.watch(derechosProvider);
    final efectivos = ref.watch(derechosEfectivosProvider);
    final ahora = deps.reloj.ahora();
    final visibles = mostrarPrecios(conectado: enLinea, obtenidosEn: _precios.obtenidosEn, ahora: ahora) && !_precios.vacio;
    final prueba = pruebaDisponible(derechos);
    final seleccionado = _precios.producto(_plan);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Premium'),
        actions: [
          IconButton(key: const ValueKey('cerrar-suscripcion'), tooltip: 'Cerrar', icon: const Icon(Symbols.close), onPressed: () => _cerrar()),
        ],
      ),
      body: SafeArea(
        child: AnchoMaximo(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text('Entrena todos los cálculos de tu sector', style: context.textos.headlineSmall),
              const SizedBox(height: 16),
              for (final (icono, texto) in const [
                (Symbols.block, 'Sin pausas promocionales entre ejercicios'),
                (Symbols.map, 'Todos los itinerarios y sectores'),
                (Symbols.headset_mic, 'Manos libres sin límite diario'),
                (Symbols.timer, 'Contrarreloj completo'),
                (Symbols.monitoring, 'Estadísticas avanzadas por habilidad'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(icono, color: c.primario),
                    const SizedBox(width: 12),
                    Expanded(child: Text(texto, style: context.textos.bodyMedium)),
                  ]),
                ),
              const SizedBox(height: 16),
              if (efectivos.premium || efectivos.sinAnuncios) ...[
                Tarjeta(
                  tinte: true,
                  child: Text('Ya tienes Premium: ${estadoParaPerfil(derechos, ahora).titulo}', style: context.textos.titleMedium),
                ),
                const SizedBox(height: 16),
              ],
              if (!enLinea)
                _Aviso(texto: textoCompraSinConexion, icono: Symbols.cloud_off)
              else if (visibles) ...[
                for (final p in [_precios.producto('annual'), _precios.producto('monthly')].whereType<StoreProduct>())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TarjetaPlan(producto: p, mensual: _precios.precio('monthly'), seleccionada: _plan == p.plan, alElegir: () => setState(() => _plan = p.plan)),
                  ),
                if (seleccionado != null)
                  Text(
                    _condiciones(seleccionado, prueba, ahora),
                    key: const ValueKey('condiciones'),
                    style: context.textos.bodySmall?.copyWith(color: c.atenuado),
                  ),
                const SizedBox(height: 4),
                Text(textoCancelar, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
              ] else if (_cargandoPrecios)
                const _Aviso(texto: 'Obteniendo los precios de la tienda…', icono: Symbols.storefront)
              else ...[
                _Aviso(texto: _errorPrecios ? textoSinPrecios : textoCompraSinConexion, icono: Symbols.storefront),
                TextButton(onPressed: () {
                  setState(() {
                    _cargandoPrecios = true;
                    _errorPrecios = false;
                  });
                  _cargar();
                }, child: const Text('Reintentar')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: _Aviso(texto: _error!, icono: Symbols.error, error: true),
                ),
                if (_error == textoCompraFallida)
                  TextButton(key: const ValueKey('reintentar-compra'), onPressed: _comprar, child: const Text('Reintentar')),
                if (_error == textoNecesitaCuenta)
                  TextButton(onPressed: () => context.push(Rutas.cuenta), child: const Text('Crear cuenta o iniciar sesión')),
              ],
              if (_mensaje != null) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: _Aviso(texto: _mensaje!, icono: Symbols.info)),
              ],
              if (kDebugMode && visibles) ...[
                const SizedBox(height: 16),
                Text('Tienda de pruebas · simular resultado', style: context.textos.labelMedium),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const ValueKey('simular-compra'),
                  segments: const [
                    ButtonSegment(value: 'ok', label: Text('Correcto')),
                    ButtonSegment(value: 'cancel', label: Text('Cancelado')),
                    ButtonSegment(value: 'fail', label: Text('Fallido')),
                  ],
                  selected: {_simular},
                  onSelectionChanged: (s) => setState(() => _simular = s.first),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('accion-principal-suscripcion'),
                onPressed: enLinea && visibles && !_comprando && !(efectivos.premium && derechos.status == 'active') ? _comprar : null,
                child: Text(accionPrincipal(derechos)),
              ),
              const SizedBox(height: 8),
              TextButton(key: const ValueKey('restaurar-compras'), onPressed: _restaurar, child: const Text('Restaurar compras')),
              TextButton(onPressed: () => context.push(Rutas.organizacion), child: const Text('Tengo un código de organización')),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: () => context.push(Rutas.legal), child: const Text('Términos')),
                  TextButton(onPressed: () => context.push(Rutas.legal), child: const Text('Privacidad')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _condiciones(StoreProduct p, bool prueba, DateTime ahora) {
    final periodo = p.plan == 'annual' ? 'al año' : 'al mes';
    final renovacion = 'se renueva salvo que canceles 24 horas antes.';
    if (prueba) {
      return '${p.trialDays} días gratis. Primer cobro el ${fechaLarga(fechaPrimerCobro(ahora, diasPrueba: p.trialDays))}: ${importe(p.price)} $periodo; $renovacion';
    }
    return '${importe(p.price)} $periodo; $renovacion';
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({required this.producto, required this.mensual, required this.seleccionada, required this.alElegir});
  final StoreProduct producto;
  final String? mensual;
  final bool seleccionada;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final anual = producto.plan == 'annual';
    final precio = anual ? '${importe(producto.price)}/año' : '${importe(producto.price)}/mes';
    final ahorro = anual && mensual != null ? 'Ahorra un ${ahorroPct(mensual!, producto.price)} %' : null;
    return Tarjeta(
      seleccionada: seleccionada,
      onTap: alElegir,
      semantica: '${anual ? 'Plan anual' : 'Plan mensual'}, $precio${ahorro == null ? '' : ', $ahorro'}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anual ? 'Anual' : 'Mensual', style: context.textos.titleMedium),
                if (ahorro != null) ...[const SizedBox(height: 4), Etiqueta(ahorro, tono: TonoEtiqueta.exito)],
                if (anual) ...[const SizedBox(height: 4), Text('${equivalenteMes(producto.price)} € al mes', style: context.textos.bodySmall)],
              ],
            ),
          ),
          Text(precio, style: estiloCifra(context, size: 17)),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.icono, this.error = false});
  final String texto;
  final IconData icono;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: error ? c.errorTinte : c.superficie2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icono, color: error ? c.errorFuerte : c.atenuado),
        const SizedBox(width: 12),
        Expanded(child: Text(texto, style: context.textos.bodyMedium?.copyWith(color: error ? c.errorFuerte : c.texto))),
      ]),
    );
  }
}
