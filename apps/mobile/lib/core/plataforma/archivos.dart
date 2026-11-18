import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'archivos_io.dart' if (dart.library.js_interop) 'archivos_web.dart' as impl;

/// Archivo entregado al usuario (exportación de datos).
class ArchivoGuardado {
  const ArchivoGuardado({required this.nombre, this.ruta});
  final String nombre;

  /// Ruta en el dispositivo; null en la web (lo descarga el navegador).
  final String? ruta;
}

/// Entrega de archivos al usuario: en la web, descarga del navegador; en el
/// móvil, archivo en los documentos de la app y hoja de compartir.
abstract class GuardadorArchivos {
  /// Guarda [contenido] como archivo de texto con el nombre indicado.
  Future<ArchivoGuardado> guardar(String nombre, String contenido, {String mime = 'application/json'});

  /// true si [compartir] abre la hoja de compartir del sistema.
  bool get puedeCompartir;

  Future<void> compartir(ArchivoGuardado archivo, {String? asunto});
}

/// Doble de pruebas: recuerda lo guardado y lo compartido.
class GuardadorArchivosFalso implements GuardadorArchivos {
  final guardados = <({String nombre, String contenido, String mime})>[];
  final compartidos = <ArchivoGuardado>[];

  @override
  bool get puedeCompartir => true;

  @override
  Future<ArchivoGuardado> guardar(String nombre, String contenido, {String mime = 'application/json'}) async {
    guardados.add((nombre: nombre, contenido: contenido, mime: mime));
    return ArchivoGuardado(nombre: nombre, ruta: '/documentos/$nombre');
  }

  @override
  Future<void> compartir(ArchivoGuardado archivo, {String? asunto}) async => compartidos.add(archivo);
}

final guardadorArchivosProvider = Provider<GuardadorArchivos>((ref) => impl.crearGuardador());
