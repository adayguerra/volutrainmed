import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependencias.dart';
import '../../app/estado/ajustes.dart';
import '../../app/estado/estado_app.dart';
import '../data/almacenes.dart';
import '../data/api_client.dart';
import '../domain/ids.dart';
import 'repositorio_contenido.dart';
import 'verificador.dart';

/// Estado de la actualización de contenido para la interfaz (centro de
/// sincronización, descarga del alta, avisos).
@immutable
class EstadoActualizacion {
  const EstadoActualizacion({
    this.comprobando = false,
    this.descargando,
    this.recibidos = 0,
    this.total = 0,
    this.preparada,
    this.error,
    this.avisoAppAntigua,
    this.ultimaComprobacion,
    this.esperaWifi = false,
  });

  /// Hay una versión nueva que no se ha bajado porque el ajuste «Descargar
  /// solo con wifi» está activo y la conexión es de datos móviles.
  final bool esperaWifi;

  final bool comprobando;

  /// Clave lógica (`global` o itinerario) que se está descargando.
  final String? descargando;
  final int recibidos;
  final int total;

  /// Versión descargada y verificada, pendiente de aplicarse entre sesiones.
  final String? preparada;
  final String? error;

  /// «Actualiza la app para ver el contenido nuevo».
  final String? avisoAppAntigua;
  final DateTime? ultimaComprobacion;

  double? get fraccion => total <= 0 ? null : (recibidos / total).clamp(0, 1).toDouble();

  EstadoActualizacion copyWith({
    bool? comprobando,
    String? descargando,
    bool sinDescarga = false,
    int? recibidos,
    int? total,
    String? preparada,
    String? error,
    bool sinError = false,
    String? avisoAppAntigua,
    bool sinAviso = false,
    DateTime? ultimaComprobacion,
    bool? esperaWifi,
  }) =>
      EstadoActualizacion(
        comprobando: comprobando ?? this.comprobando,
        descargando: sinDescarga ? null : (descargando ?? this.descargando),
        recibidos: recibidos ?? this.recibidos,
        total: total ?? this.total,
        preparada: preparada ?? this.preparada,
        error: sinError ? null : (error ?? this.error),
        avisoAppAntigua: sinAviso ? null : (avisoAppAntigua ?? this.avisoAppAntigua),
        ultimaComprobacion: ultimaComprobacion ?? this.ultimaComprobacion,
        esperaWifi: esperaWifi ?? this.esperaWifi,
      );
}

/// Descarga, verificación y cambio de versión del contenido (offline-sync,
/// diseño D8).
abstract class ActualizadorContenido {
  ValueListenable<EstadoActualizacion> get estado;

  /// Pide el manifiesto, aplica al momento la lista de retirada y descarga y
  /// prepara las versiones nuevas del contenido global y de los itinerarios
  /// instalados. No cambia el contenido en uso.
  Future<void> comprobar();

  /// Descarga (o reanuda) y verifica el paquete de un itinerario y lo deja
  /// preparado. [progreso] recibe bytes recibidos y totales. Para usarlo hay
  /// que llamar después a [aplicarPreparadas] (fuera de una sesión).
  ///
  /// Con «Descargar solo con wifi» y conexión de datos móviles lanza
  /// [SoloWifi], salvo que el usuario lo autorice con [conDatos].
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso, bool conDatos = false});

  /// Aplica las versiones preparadas si no hay ninguna sesión en curso.
  /// Devuelve true si el contenido ha cambiado.
  Future<bool> aplicarPreparadas();

  /// Itinerarios disponibles en el dispositivo (incluidos o descargados).
  Future<Set<String>> itinerariosInstalados();
}

/// Implementación sin red: solo hay contenido incluido.
class ActualizadorSinRed implements ActualizadorContenido {
  final _estado = ValueNotifier(const EstadoActualizacion());
  @override
  ValueListenable<EstadoActualizacion> get estado => _estado;
  @override
  Future<void> comprobar() async {}
  @override
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso, bool conDatos = false}) async {}
  @override
  Future<bool> aplicarPreparadas() async => false;
  @override
  Future<Set<String>> itinerariosInstalados() async => {'it-fundamentos'};
}

/// Archivo firmado del manifiesto.
class ArchivoFirmado {
  const ArchivoFirmado({required this.clave, required this.id, required this.version, required this.url, required this.sha256, required this.firma, required this.tamano, required this.minAppVersion});
  final String clave;
  final String id;
  final String version;
  final String url;
  final String sha256;
  final String firma;
  final int tamano;
  final String minAppVersion;

  factory ArchivoFirmado.fromJson(String clave, Map<String, dynamic> j) => ArchivoFirmado(
        clave: clave,
        id: '${j['id']}',
        version: '${j['version']}',
        url: '${j['url']}',
        sha256: '${j['sha256']}',
        firma: '${j['signature']}',
        tamano: (j['size'] as num?)?.toInt() ?? 0,
        minAppVersion: '${j['minAppVersion'] ?? '1.0.0'}',
      );

  bool get compatible => compararVersiones(minAppVersion, versionApp) <= 0;
}

/// No se ha podido completar una descarga (sin conexión o paquete rechazado).
class DescargaFallida implements Exception {
  const DescargaFallida(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

const textoSoloWifi = 'Solo se descarga con wifi. Conéctate a una wifi o cambia el ajuste en Descargas y sincronización';

/// La descarga no se hace porque el ajuste «Descargar solo con wifi» está
/// activo y la conexión es de datos móviles.
class SoloWifi extends DescargaFallida {
  const SoloWifi() : super(textoSoloWifi);
}

/// ¿Está restringida ahora la descarga de paquetes (ajuste solo wifi activo y
/// conexión de datos móviles)?
typedef RestriccionWifi = Future<bool> Function();

final restriccionWifiProvider = Provider<RestriccionWifi>((ref) {
  final deps = ref.watch(dependenciasProvider);
  return () async => ref.read(ajustesProvider).soloWifi && await deps.conectividad.soloDatosMoviles();
});

class ActualizadorReal implements ActualizadorContenido {
  ActualizadorReal({
    required this.almacen,
    required this.claves,
    required this.api,
    required this.repositorio,
    required this.deviceId,
    required this.aplicarRevocaciones,
    required this.recargarContenido,
    this.reintentosVerificacion = 1,
    this.restringido,
  });

  /// Restricción «solo wifi»; null = sin restricción.
  final RestriccionWifi? restringido;

  final AlmacenContenido almacen;
  final AlmacenClaves claves;
  final ApiClient api;
  final RepositorioContenido repositorio;
  final String Function() deviceId;
  final Future<void> Function(Revocaciones r) aplicarRevocaciones;
  final Future<void> Function() recargarContenido;

  /// Reintentos inmediatos si la verificación falla (además del primero).
  final int reintentosVerificacion;

  final _estado = ValueNotifier(const EstadoActualizacion());
  @override
  ValueListenable<EstadoActualizacion> get estado => _estado;

  ({ArchivoFirmado global, Map<String, ArchivoFirmado> itinerarios, Map<String, dynamic> crudo})? _manifiesto;

  Future<({ArchivoFirmado global, Map<String, ArchivoFirmado> itinerarios, Map<String, dynamic> crudo})> _pedirManifiesto() async {
    final m = await api.manifest(deviceId: deviceId(), appVersion: versionApp);
    final its = <String, ArchivoFirmado>{};
    for (final p in ((m['packages'] as List?) ?? const []).cast<Map>()) {
      final j = p.cast<String, dynamic>();
      final clave = '${j['itineraryId'] ?? j['id']}';
      its[clave] = ArchivoFirmado.fromJson(clave, j);
    }
    final r = (global: ArchivoFirmado.fromJson('global', (m['global'] as Map).cast<String, dynamic>()), itinerarios: its, crudo: m);
    _manifiesto = r;
    return r;
  }

  Future<String?> _versionLocal(String clave) async {
    String? mejor;
    for (final p in await almacen.paquetes()) {
      if (p.clave != clave || p.status == 'previous') continue;
      if (mejor == null || compararVersiones(p.version, mejor) > 0) mejor = p.version;
    }
    return mejor;
  }

  @override
  Future<Set<String>> itinerariosInstalados() async =>
      {for (final p in await almacen.paquetes()) if (p.clave != 'global' && p.status != 'previous') p.clave};

  @override
  Future<void> comprobar() async {
    if (_estado.value.comprobando) return;
    _estado.value = _estado.value.copyWith(comprobando: true, sinError: true);
    try {
      final m = await _pedirManifiesto();
      // La lista de retirada se aplica al momento, sin esperar a otra versión.
      final rev = Revocaciones.fromJson((m.crudo['revocations'] as Map?)?.cast<String, dynamic>());
      final actual = await repositorio.revocaciones();
      if (rev.version != actual.version || rev.templateIds.length != actual.templateIds.length || rev.variantIds.length != actual.variantIds.length || rev.questionIds.length != actual.questionIds.length) {
        await aplicarRevocaciones(rev);
      }
      var appAntigua = m.crudo['newerRequiresAppVersion'] != null;
      final objetivos = <ArchivoFirmado>[m.global, for (final c in await itinerariosInstalados()) ?m.itinerarios[c]];
      // Solo wifi: el manifiesto y la lista de retirada (pequeños y de
      // seguridad) ya se han aplicado; los paquetes esperan a una wifi.
      final sinWifi = await restringido?.call() ?? false;
      var esperaWifi = false;
      for (final f in objetivos) {
        final local = await _versionLocal(f.clave);
        if (local != null && compararVersiones(f.version, local) <= 0) continue;
        if (!f.compatible) {
          appAntigua = true;
          continue;
        }
        if (sinWifi) {
          esperaWifi = true;
          continue;
        }
        await _descargar(f);
      }
      if (appAntigua) {
        await claves.escribir(claveAvisoAppAntigua, textoActualizaApp);
      } else {
        await claves.borrar(claveAvisoAppAntigua);
      }
      _estado.value = _estado.value.copyWith(
        comprobando: false,
        ultimaComprobacion: DateTime.now(),
        avisoAppAntigua: appAntigua ? textoActualizaApp : null,
        sinAviso: !appAntigua,
        esperaWifi: esperaWifi,
      );
    } on ApiException catch (e) {
      // 404 no_content: aún no hay contenido publicado; no es un error.
      _estado.value = _estado.value.copyWith(comprobando: false, error: e.status == 404 ? null : e.message, sinError: e.status == 404, sinDescarga: true);
    } catch (e) {
      _estado.value = _estado.value.copyWith(comprobando: false, error: e is DescargaFallida ? e.mensaje : 'Sin conexión', sinDescarga: true);
    }
  }

  @override
  Future<void> descargarItinerario(String itineraryId, {void Function(int recibidos, int total)? progreso, bool conDatos = false}) async {
    final m = _manifiesto ?? await _pedirManifiesto();
    final f = m.itinerarios[itineraryId] ?? (await _pedirManifiesto()).itinerarios[itineraryId];
    if (f == null) throw DescargaFallida('El itinerario $itineraryId no está publicado');
    if (!f.compatible) {
      await claves.escribir(claveAvisoAppAntigua, textoActualizaApp);
      throw const DescargaFallida(textoActualizaApp);
    }
    final local = await _versionLocal(itineraryId);
    if (local != null && compararVersiones(local, f.version) >= 0) {
      progreso?.call(f.tamano, f.tamano);
      return;
    }
    if (!conDatos && (await restringido?.call() ?? false)) throw const SoloWifi();
    await _descargar(f, progreso: progreso);
  }

  /// Descarga reanudable con verificación. Si la verificación falla, descarta
  /// los bytes, conserva la versión anterior y reintenta.
  Future<void> _descargar(ArchivoFirmado f, {void Function(int, int)? progreso}) async {
    for (var intento = 0; intento <= reintentosVerificacion; intento++) {
      final bytes = await _bajarBytes(f, progreso: progreso);
      try {
        await verificarPaquete(id: f.id, version: f.version, sha256: f.sha256, firmaB64: f.firma, bytes: bytes);
      } on PaqueteNoValido {
        final previa = await almacen.descarga(f.id, f.version);
        await almacen.borrarDescarga(f.id, f.version);
        // Se recuerda el número de fallos para el centro de sincronización.
        await claves.escribir('contenido.fallos.${f.clave}', '${(previa?.failures ?? 0) + intento + 1}');
        if (intento == reintentosVerificacion) throw const DescargaFallida('El paquete descargado no es válido. Lo reintentaremos');
        continue;
      }
      await almacen.guardarPreparado(PaqueteGuardado(
        clave: f.clave,
        id: f.id,
        version: f.version,
        sha256: f.sha256,
        signature: f.firma,
        minAppVersion: f.minAppVersion,
        gz: bytes,
        status: 'staged',
      ));
      await almacen.borrarDescarga(f.id, f.version);
      await claves.borrar('contenido.fallos.${f.clave}');
      _estado.value = _estado.value.copyWith(preparada: f.version, sinDescarga: true);
      return;
    }
  }

  Future<Uint8List> _bajarBytes(ArchivoFirmado f, {void Function(int, int)? progreso}) async {
    final previa = await almacen.descarga(f.id, f.version);
    var bytes = BytesBuilder(copy: false)..add(previa?.partial ?? Uint8List(0));
    var fallos = previa?.failures ?? 0;
    var total = f.tamano;
    Future<void> guardar() => almacen.guardarDescarga(DescargaParcial(
          clave: f.clave,
          fileId: f.id,
          version: f.version,
          url: f.url,
          sha256: f.sha256,
          signature: f.firma,
          size: total,
          minAppVersion: f.minAppVersion,
          partial: bytes.toBytes(),
          failures: fallos,
        ));
    _estado.value = _estado.value.copyWith(descargando: f.clave, recibidos: bytes.length, total: total);
    progreso?.call(bytes.length, total);
    while (total <= 0 || bytes.length < total) {
      final RespuestaBytes r;
      try {
        r = await api.descargar(f.url, desde: bytes.length);
      } catch (e) {
        fallos++;
        await guardar();
        throw DescargaFallida('Descarga interrumpida: se reanudará al volver la conexión ($e)');
      }
      if (r.status == 416) break;
      if (r.status == 200) bytes = BytesBuilder(copy: false); // el servidor ignoró el rango
      bytes.add(r.bytes);
      total = r.totalSize ?? (total > 0 ? total : bytes.length);
      await guardar();
      _estado.value = _estado.value.copyWith(recibidos: bytes.length, total: total);
      progreso?.call(bytes.length, total);
      if (r.bytes.isEmpty) break;
    }
    return bytes.toBytes();
  }

  @override
  Future<bool> aplicarPreparadas() async {
    final cambiadas = await repositorio.aplicarPreparados();
    if (cambiadas.isEmpty) return false;
    await recargarContenido();
    return true;
  }
}

final actualizadorProvider = Provider<ActualizadorContenido>((ref) {
  final deps = ref.watch(dependenciasProvider);
  return ActualizadorReal(
    almacen: deps.contenido,
    claves: deps.claves,
    api: deps.api,
    repositorio: deps.repositorio,
    restringido: ref.watch(restriccionWifiProvider),
    deviceId: () => ref.read(usuarioProvider).value?.deviceId ?? 'sin-dispositivo',
    aplicarRevocaciones: (r) => ref.read(contenidoProvider.notifier).aplicarRevocaciones(r),
    recargarContenido: () => ref.read(contenidoProvider.notifier).recargar(),
  );
});
