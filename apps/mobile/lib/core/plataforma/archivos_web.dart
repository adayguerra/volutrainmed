import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'archivos.dart';

GuardadorArchivos crearGuardador() => _GuardadorNavegador();

/// Web: el navegador descarga el archivo (enlace temporal a un Blob).
class _GuardadorNavegador implements GuardadorArchivos {
  @override
  bool get puedeCompartir => false;

  @override
  Future<ArchivoGuardado> guardar(String nombre, String contenido, {String mime = 'application/json'}) async {
    final blob = web.Blob([contenido.toJS].toJS, web.BlobPropertyBag(type: '$mime;charset=utf-8'));
    final url = web.URL.createObjectURL(blob);
    final enlace = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = nombre
      ..style.display = 'none';
    web.document.body!.append(enlace);
    enlace.click();
    enlace.remove();
    web.URL.revokeObjectURL(url);
    return ArchivoGuardado(nombre: nombre);
  }

  @override
  Future<void> compartir(ArchivoGuardado archivo, {String? asunto}) async {}
}
