import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../core/data/almacenes.dart';
import '../../../core/data/api_client.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../domain/entitlements_policy.dart';

/// Tienda y derechos de Premium (premium-subscription). En desarrollo la
/// compra pasa por la tienda de pruebas de `services/api`; en producción se
/// sustituye por la tienda del dispositivo y el proveedor de suscripciones.

/// Lector de proveedores: vale `ref.read` de un `Ref` o de un `WidgetRef`.
typedef Lector = T Function<T>(ProviderListenable<T> provider);

const claveProductos = 'tienda.productos';
const claveAvisoCaducidad = 'derechos.avisoCaducidad';
const claveAvisoRevalidar = 'derechos.avisoRevalidar';
const idRecordatorioPrueba = 4207;

/// Precios guardados con la fecha en que se obtuvieron de la tienda.
class PreciosTienda {
  const PreciosTienda({this.productos = const [], this.obtenidosEn});
  final List<StoreProduct> productos;
  final DateTime? obtenidosEn;

  StoreProduct? producto(String plan) => productos.where((p) => p.plan == plan).firstOrNull;
  String? precio(String plan) => producto(plan)?.price;
  bool get vacio => productos.isEmpty;
}

Future<PreciosTienda> leerPreciosGuardados(AlmacenClaves claves) async {
  final j = await claves.leerJson(claveProductos);
  if (j == null) return const PreciosTienda();
  return PreciosTienda(
    productos: ((j['products'] as List?) ?? const []).map((e) => StoreProduct.fromJson((e as Map).cast<String, dynamic>())).toList(),
    obtenidosEn: j['fetchedAt'] == null ? null : DateTime.tryParse('${j['fetchedAt']}'),
  );
}

/// Pide los precios a la tienda y los guarda. Lanza si no hay conexión.
Future<PreciosTienda> refrescarPrecios(Lector leer) async {
  final deps = leer(dependenciasProvider);
  final r = await deps.api.storeProducts();
  final productos = ((r['products'] as List?) ?? const []).map((e) => StoreProduct.fromJson((e as Map).cast<String, dynamic>())).toList();
  // La frescura se mide con el reloj del dispositivo, que es el que decide.
  final obtenidos = deps.reloj.ahora();
  await deps.claves.escribirJson(claveProductos, {'products': productos.map((p) => p.toJson()).toList(), 'fetchedAt': obtenidos.toIso8601String()});
  return PreciosTienda(productos: productos, obtenidosEn: obtenidos);
}

/// Revalida los derechos con el servidor (al abrir la app con conexión, al
/// abrir la suscripción y tras iniciar sesión). Sin cuenta o sin conexión no
/// hace nada: los derechos guardados siguen valiendo 30 días.
Future<bool> refrescarDerechos(Lector leer) async {
  final deps = leer(dependenciasProvider);
  if (!deps.api.conCuenta) return false;
  try {
    final e = Entitlements.fromJson(await deps.api.entitlements());
    await leer(derechosProvider.notifier).guardar(e);
    await programarRecordatorioPrueba(leer, e);
    return true;
  } on SinConexionException {
    return false;
  } on ApiException {
    return false;
  }
}

enum ResultadoCompra { completada, cancelada, fallida, sinConexion, sinCuenta }

/// Compra (o prueba) en la tienda de pruebas. [simular] solo existe en la
/// tienda de pruebas: `ok`, `cancel` o `fail`.
Future<ResultadoCompra> comprar(Lector leer, StoreProduct producto, {required bool conPrueba, String simular = 'ok', String? anuncioId}) async {
  final deps = leer(dependenciasProvider);
  if (!deps.api.conCuenta) return ResultadoCompra.sinCuenta;
  try {
    final r = await deps.api.storePurchase({
      'productId': producto.id,
      'withTrial': conPrueba,
      'receipt': 'sandbox',
      'simulate': simular,
      'attributedAdId': ?anuncioId,
    });
    final e = Entitlements.fromJson((r['entitlements'] as Map).cast<String, dynamic>());
    await leer(derechosProvider.notifier).guardar(e);
    await programarRecordatorioPrueba(leer, e, precio: producto.price, plan: producto.plan);
    return ResultadoCompra.completada;
  } on SinConexionException {
    return ResultadoCompra.sinConexion;
  } on ApiException catch (e) {
    if (e.code == 'purchase_cancelled' || e.status == 409) return ResultadoCompra.cancelada;
    return ResultadoCompra.fallida;
  }
}

/// Restaura las compras de la cuenta (otro dispositivo, reinstalación).
Future<ResultadoCompra> restaurar(Lector leer) async {
  final deps = leer(dependenciasProvider);
  if (!deps.api.conCuenta) return ResultadoCompra.sinCuenta;
  try {
    final r = await deps.api.storeRestore();
    final e = Entitlements.fromJson((r['entitlements'] as Map).cast<String, dynamic>());
    await leer(derechosProvider.notifier).guardar(e);
    return ResultadoCompra.completada;
  } on SinConexionException {
    return ResultadoCompra.sinConexion;
  } on ApiException {
    return ResultadoCompra.fallida;
  }
}

/// Programa la notificación local previa al fin de la prueba (24–48 h antes),
/// con la fecha y el importe del primer cobro. Se entrega aunque no haya
/// conexión.
Future<void> programarRecordatorioPrueba(Lector leer, Entitlements e, {String? precio, String? plan}) async {
  final deps = leer(dependenciasProvider);
  final cuando = momentoRecordatorioPrueba(e, deps.reloj.ahora());
  if (cuando == null || e.trialEndsAt == null) return;
  final guardados = await leerPreciosGuardados(deps.claves);
  final planCobro = plan ?? 'annual';
  final importeCobro = precio ?? guardados.precio(planCobro) ?? (planCobro == 'annual' ? '39.99' : '6.99');
  await deps.notificador.programar(NotificacionProgramada(
    id: idRecordatorioPrueba,
    cuando: cuando,
    titulo: 'Tu prueba de Premium termina pronto',
    texto: textoRecordatorioPrueba(finPrueba: e.trialEndsAt!, precio: importeCobro, plan: planCobro),
  ));
}

/// Avisos de derechos que deben verse al abrir la app: «Conéctate para
/// comprobar tu suscripción» (más de 30 días sin revalidar) y «Tu Premium ha
/// terminado» (una sola vez por caducidad).
Future<List<String>> avisosDerechos(Lector leer) async {
  final deps = leer(dependenciasProvider);
  final e = leer(derechosProvider);
  final ahora = deps.reloj.ahora();
  final avisos = <String>[];
  final efectivos = derechosEfectivos(e, ahora);
  if (efectivos.aviso != null) {
    final ya = await deps.claves.leer(claveAvisoRevalidar);
    final marca = e.validatedAt.toIso8601String();
    if (ya != marca) {
      avisos.add(efectivos.aviso!);
      await deps.claves.escribir(claveAvisoRevalidar, marca);
    }
  }
  final ultimo = await deps.claves.leer(claveAvisoCaducidad);
  if (debeAvisarPremiumTerminado(e, ahora, ultimo == null ? null : DateTime.tryParse(ultimo))) {
    avisos.add(avisoPremiumTerminado);
    await deps.claves.escribir(claveAvisoCaducidad, e.expiresAt!.toIso8601String());
  }
  return avisos;
}
