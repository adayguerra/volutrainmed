import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as c;
import 'package:cryptography/cryptography.dart';

/// Clave pública de firma de contenido, fijada en la app (Ed25519 en bruto,
/// 32 bytes en base64; identificador `vtm-content-2026-1`). Coincide con
/// `assets/content/content-signing.pub.b64` y con `GET /v1/content/public-key`.
const clavePublicaContenido = 'iwggOKKqMNhKikGscioXCBuC/CrqAQRHs6Bc3JPtqGw=';
const idClaveContenido = 'vtm-content-2026-1';

/// Cadena firmada: `${id}|${version}|${sha256}` (contrato `signaturePayload`).
String cadenaFirmada(String id, String version, String sha256) => '$id|$version|$sha256';

String sha256Hex(List<int> bytes) => c.sha256.convert(bytes).toString();

enum MotivoRechazo { resumen, firma, formato }

class PaqueteNoValido implements Exception {
  const PaqueteNoValido(this.motivo, this.detalle);
  final MotivoRechazo motivo;
  final String detalle;
  @override
  String toString() => 'PaqueteNoValido(${motivo.name}): $detalle';
}

/// Comprueba resumen SHA-256 y firma Ed25519 de un paquete. Lanza
/// [PaqueteNoValido] si alguna comprobación falla.
Future<void> verificarPaquete({
  required String id,
  required String version,
  required String sha256,
  required String firmaB64,
  required Uint8List bytes,
  String clavePublicaB64 = clavePublicaContenido,
}) async {
  final calculado = sha256Hex(bytes);
  if (calculado != sha256.toLowerCase()) {
    throw PaqueteNoValido(MotivoRechazo.resumen, 'El resumen no coincide ($calculado)');
  }
  final List<int> firma;
  try {
    firma = base64.decode(firmaB64);
  } catch (_) {
    throw const PaqueteNoValido(MotivoRechazo.firma, 'Firma ilegible');
  }
  final ok = await Ed25519().verify(
    utf8.encode(cadenaFirmada(id, version, sha256)),
    signature: Signature(firma, publicKey: SimplePublicKey(base64.decode(clavePublicaB64), type: KeyPairType.ed25519)),
  );
  if (!ok) throw const PaqueteNoValido(MotivoRechazo.firma, 'La firma no es válida');
}

/// Descomprime (gzip) y decodifica el JSON de un paquete. Usa `archive`,
/// que funciona también en la web.
Map<String, dynamic> decodificarPaquete(Uint8List gz) {
  try {
    final json = utf8.decode(const GZipDecoder().decodeBytes(gz));
    return (jsonDecode(json) as Map).cast<String, dynamic>();
  } catch (e) {
    throw PaqueteNoValido(MotivoRechazo.formato, 'No se puede leer el paquete: $e');
  }
}
