import 'dart:convert';
import 'dart:typed_data';

import '../data/almacenes.dart';
import '../domain/content_models.dart';
import '../domain/ids.dart';
import 'verificador.dart';

/// Versión de la app que se compara con `minAppVersion` de los paquetes.
const versionApp = '1.0.0';

const claveRevocaciones = 'contenido.revocaciones';
const claveAvisoAppAntigua = 'contenido.avisoApp';
const textoActualizaApp = 'Actualiza la app para ver el contenido nuevo';

/// Lista de retirada (independiente de las versiones de contenido).
class Revocaciones {
  const Revocaciones({this.version = 0, this.templateIds = const {}, this.questionIds = const {}, this.variantIds = const {}});
  final int version;
  final Set<String> templateIds;
  final Set<String> questionIds;
  final Set<String> variantIds;

  bool retirada(Variant v) =>
      variantIds.contains(v.id) ||
      (v.templateId != null && templateIds.contains(v.templateId)) ||
      (v.questionId != null && questionIds.contains(v.questionId));

  bool retiradaClave(String itemKey) => templateIds.contains(itemKey) || questionIds.contains(itemKey);

  factory Revocaciones.fromJson(Map<String, dynamic>? j) => Revocaciones(
        version: (j?['version'] as num?)?.toInt() ?? 0,
        templateIds: {...((j?['templateIds'] as List?) ?? const []).map((e) => '$e')},
        questionIds: {...((j?['questionIds'] as List?) ?? const []).map((e) => '$e')},
        variantIds: {...((j?['variantIds'] as List?) ?? const []).map((e) => '$e')},
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'templateIds': templateIds.toList(),
        'questionIds': questionIds.toList(),
        'variantIds': variantIds.toList(),
      };
}

/// Contenido verificado y listo para entrenar. Inmutable durante una sesión:
/// una versión nueva solo se aplica al empezar la siguiente (offline-sync).
class ContenidoCargado {
  ContenidoCargado({required this.global, required this.itinerarios, required this.revocaciones, this.avisoAppAntigua}) {
    for (final it in itinerarios.values) {
      for (final v in it.variants) {
        _variantes[v.id] = v;
        _porClaveNivel.putIfAbsent('${v.itemKey}@${v.level}', () => []).add(v);
        _porClave.putIfAbsent(v.itemKey, () => []).add(v);
      }
    }
  }

  final GlobalPackage global;
  final Map<String, ItineraryPackage> itinerarios;
  final Revocaciones revocaciones;

  /// «Actualiza la app para ver el contenido nuevo» si hay contenido que
  /// exige una versión superior de la app.
  final String? avisoAppAntigua;

  final _variantes = <String, Variant>{};
  final _porClaveNivel = <String, List<Variant>>{};
  final _porClave = <String, List<Variant>>{};

  String get version => global.contentVersion;

  /// Versión de contenido de un itinerario (o la global).
  String versionDe(String? itineraryId) => itinerarios[itineraryId]?.contentVersion ?? version;

  ItineraryPackage? itinerario(String? id) => id == null ? null : itinerarios[id];

  /// Variante por id, o null si no existe o está retirada.
  Variant? variante(String id) {
    final v = _variantes[id];
    return v == null || revocaciones.retirada(v) ? null : v;
  }

  /// Variantes vigentes de una plantilla o pregunta en un nivel.
  List<Variant> variantes(String itemKey, int nivel) =>
      (_porClaveNivel['$itemKey@$nivel'] ?? const []).where((v) => !revocaciones.retirada(v)).toList();

  /// Variantes vigentes de una plantilla o pregunta en cualquier nivel.
  List<Variant> variantesDe(String itemKey) => (_porClave[itemKey] ?? const []).where((v) => !revocaciones.retirada(v)).toList();

  /// Niveles disponibles de una plantilla (ordenados).
  List<int> niveles(String itemKey) => ({for (final v in variantesDe(itemKey)) v.level}.toList()..sort());

  ExerciseType? tipo(String id) => global.type(id);

  Sector? sector(String? id) => global.sectors.where((s) => s.id == id).firstOrNull;

  ItinerarySummary? resumenItinerario(String? id) => global.itineraries.where((i) => i.id == id).firstOrNull;

  /// Itinerario de Fundamentos (incluido en la app).
  ItineraryPackage? get fundamentos =>
      itinerarios.values.where((i) => i.itinerary.isFoundations).firstOrNull ?? itinerarios['it-fundamentos'];

  ContenidoCargado conRevocaciones(Revocaciones r) =>
      ContenidoCargado(global: global, itinerarios: itinerarios, revocaciones: r, avisoAppAntigua: avisoAppAntigua);
}

/// Lector de los activos incluidos en la app (`rootBundle` en la app real).
typedef LectorActivos = Future<Uint8List> Function(String ruta);

/// Carga y verifica el contenido guardado en el dispositivo e instala el
/// contenido incluido en la app la primera vez.
class RepositorioContenido {
  RepositorioContenido({required this.almacen, required this.claves, required this.leerActivo});
  final AlmacenContenido almacen;
  final AlmacenClaves claves;
  final LectorActivos leerActivo;

  static const rutaManifiesto = 'assets/content/manifest.json';
  static String rutaPaquete(String id) => 'assets/content/$id.vtmpkg';

  /// Instala el contenido incluido si no hay versión activa o si la activa es
  /// más antigua. Los paquetes del manifiesto que no vienen en la app se
  /// ignoran (se descargan bajo demanda).
  Future<void> instalarIncluido() async {
    final manifiesto = (jsonDecode(utf8.decode(await leerActivo(rutaManifiesto))) as Map).cast<String, dynamic>();
    final activos = {for (final p in await almacen.paquetes(status: 'active')) p.clave: p};
    final archivos = <Map<String, dynamic>>[
      (manifiesto['global'] as Map).cast<String, dynamic>(),
      ...((manifiesto['packages'] as List?) ?? const []).map((e) => (e as Map).cast<String, dynamic>()),
    ];
    for (final f in archivos) {
      final id = '${f['id']}';
      final version = '${f['version']}';
      final actual = activos[id];
      if (actual != null && compararVersiones(actual.version, version) >= 0) continue;
      final Uint8List bytes;
      try {
        bytes = await leerActivo(rutaPaquete(id));
      } catch (_) {
        continue; // No incluido en la app.
      }
      await verificarPaquete(id: id, version: version, sha256: '${f['sha256']}', firmaB64: '${f['signature']}', bytes: bytes);
      await almacen.instalarActivo(PaqueteGuardado(
        clave: id,
        id: id,
        version: version,
        sha256: '${f['sha256']}',
        signature: '${f['signature']}',
        minAppVersion: '${f['minAppVersion'] ?? '1.0.0'}',
        gz: bytes,
        status: 'active',
      ));
    }
  }

  /// Aplica las versiones descargadas y verificadas. Solo debe llamarse entre
  /// sesiones (al arrancar o al empezar la siguiente sesión).
  Future<List<String>> aplicarPreparados() => almacen.activarPreparados();

  Future<Revocaciones> revocaciones() async => Revocaciones.fromJson(await claves.leerJson(claveRevocaciones));

  Future<void> guardarRevocaciones(Revocaciones r) => claves.escribirJson(claveRevocaciones, r.toJson());

  /// Lee, verifica de nuevo y decodifica los paquetes activos. Si un activo
  /// no supera la verificación, se recurre a la versión anterior.
  Future<ContenidoCargado> cargar() async {
    await instalarIncluido();
    final todos = await almacen.paquetes();
    final porClave = <String, List<PaqueteGuardado>>{};
    for (final p in todos) {
      if (p.status == 'staged') continue;
      porClave.putIfAbsent(p.clave, () => []).add(p);
    }
    GlobalPackage? global;
    final itinerarios = <String, ItineraryPackage>{};
    for (final entrada in porClave.entries) {
      final candidatos = entrada.value..sort((a, b) => a.status == 'active' ? -1 : (b.status == 'active' ? 1 : 0));
      for (final p in candidatos) {
        try {
          await verificarPaquete(id: p.id, version: p.version, sha256: p.sha256, firmaB64: p.signature, bytes: p.gz);
          final json = decodificarPaquete(p.gz);
          if (entrada.key == 'global') {
            global = GlobalPackage.fromJson(json);
          } else {
            final it = ItineraryPackage.fromJson(json);
            itinerarios[it.itinerary.id] = it;
          }
          break;
        } on PaqueteNoValido {
          continue;
        }
      }
    }
    if (global == null) throw StateError('No hay contenido global válido en el dispositivo');
    return ContenidoCargado(
      global: global,
      itinerarios: itinerarios,
      revocaciones: await revocaciones(),
      avisoAppAntigua: await claves.leer(claveAvisoAppAntigua),
    );
  }
}
