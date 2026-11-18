import 'dart:convert';
import 'dart:typed_data';

import '../../../core/contenido/actualizador.dart' show SoloWifi;
import '../../../core/contenido/verificador.dart';
import '../../../core/data/almacenes.dart';
import '../../../core/data/api_client.dart';

/// Paquete de voz bajo demanda (hands-free-voice, «Paquete de voz bajo
/// demanda»). Se descarga solo al entrar en manos libres, se verifica con la
/// misma firma que el contenido y se guarda en el dispositivo. El modelo de
/// reconocimiento embebido llegará tras la prueba técnica; hoy el paquete
/// distribuye los recursos de idioma firmados.
class PaqueteVoz {
  const PaqueteVoz({required this.id, required this.version, required this.size, required this.sha256, required this.signature, this.url = ''});
  final String id;
  final String version;
  final int size;
  final String sha256;
  final String signature;
  final String url;

  factory PaqueteVoz.fromJson(Map<String, dynamic> j) => PaqueteVoz(
        id: '${j['id']}',
        version: '${j['version']}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        sha256: '${j['sha256']}',
        signature: '${j['signature']}',
        url: '${j['url'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {'id': id, 'version': version, 'size': size, 'sha256': sha256, 'signature': signature, 'url': url};

  /// «0,3 KB», «142 MB».
  String get tamanoTexto {
    if (size >= 1 << 20) return '${(size / (1 << 20)).toStringAsFixed(1).replaceAll('.', ',')} MB';
    return '${(size / 1024).toStringAsFixed(1).replaceAll('.', ',')} KB';
  }
}

const claveMetaPaqueteVoz = 'voz.paquete';
const claveBytesPaqueteVoz = 'voz.paquete.bytes';

class ServicioPaqueteVoz {
  ServicioPaqueteVoz({required this.api, required this.claves, this.restringido});

  /// Restricción «Descargar solo con wifi»; null = sin restricción.
  final Future<bool> Function()? restringido;
  final ApiClient api;
  final AlmacenClaves claves;

  /// Paquete instalado y válido, o null. Si el guardado no supera la
  /// verificación se borra.
  Future<PaqueteVoz?> instalado() async {
    final meta = await claves.leerJson(claveMetaPaqueteVoz);
    final b64 = await claves.leer(claveBytesPaqueteVoz);
    if (meta == null || b64 == null) return null;
    final p = PaqueteVoz.fromJson(meta);
    try {
      await verificarPaquete(id: p.id, version: p.version, sha256: p.sha256, firmaB64: p.signature, bytes: base64.decode(b64));
      return p;
    } on PaqueteNoValido {
      await borrar();
      return null;
    }
  }

  /// Datos del paquete publicado (tamaño para avisar antes de descargar).
  Future<PaqueteVoz> disponible() async => PaqueteVoz.fromJson(await api.voicePack());

  /// Descarga y verifica el paquete. Si la verificación falla se descarta y
  /// se lanza [PaqueteNoValido]; no se guarda nada.
  ///
  /// Con «Descargar solo con wifi» y datos móviles lanza [SoloWifi], salvo
  /// que el usuario lo autorice con [conDatos].
  Future<PaqueteVoz> descargar({PaqueteVoz? meta, bool conDatos = false}) async {
    if (!conDatos && (await restringido?.call() ?? false)) throw const SoloWifi();
    final p = meta ?? await disponible();
    final r = await api.descargar(p.url);
    final bytes = Uint8List.fromList(r.bytes);
    await verificarPaquete(id: p.id, version: p.version, sha256: p.sha256, firmaB64: p.signature, bytes: bytes);
    await guardar(p, bytes);
    return p;
  }

  Future<void> guardar(PaqueteVoz p, Uint8List bytes) async {
    await claves.escribir(claveBytesPaqueteVoz, base64.encode(bytes));
    await claves.escribirJson(claveMetaPaqueteVoz, p.toJson());
  }

  Future<void> borrar() async {
    await claves.borrar(claveMetaPaqueteVoz);
    await claves.borrar(claveBytesPaqueteVoz);
  }
}
