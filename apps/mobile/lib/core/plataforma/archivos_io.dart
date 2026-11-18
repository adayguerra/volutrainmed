import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'archivos.dart';

GuardadorArchivos crearGuardador() => _GuardadorDispositivo();

/// Móvil y escritorio: el archivo queda en los documentos de la app y puede
/// enviarse con la hoja de compartir del sistema.
class _GuardadorDispositivo implements GuardadorArchivos {
  @override
  bool get puedeCompartir => true;

  @override
  Future<ArchivoGuardado> guardar(String nombre, String contenido, {String mime = 'application/json'}) async {
    final dir = await getApplicationDocumentsDirectory();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsString(contenido, flush: true);
    return ArchivoGuardado(nombre: nombre, ruta: archivo.path);
  }

  @override
  Future<void> compartir(ArchivoGuardado archivo, {String? asunto}) async {
    final ruta = archivo.ruta;
    if (ruta == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(ruta, mimeType: 'application/json', name: archivo.nombre)], subject: asunto));
  }
}
