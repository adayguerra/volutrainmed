import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependencias.dart';
import '../../app/estado/estado_app.dart';
import '../../core/data/api_client.dart';
import '../../core/domain/learning_models.dart';
import '../../core/sync/sincronizador.dart';

/// Acceso a la cuenta (onboarding-account, «Métodos de acceso» y «Registro
/// después de la primera lección»). El perfil local viaja con la petición para
/// que el servidor lo fusione; los intentos suben después por sincronización.

const textoCuentaSinConexion = 'Para crear la cuenta hace falta conexión. Tu progreso sigue guardado en este dispositivo.';
const textoCodigoIncorrecto = 'El código no es correcto';

/// Organización que ofrece plazas al dominio del correo.
class OfertaOrganizacion {
  const OfertaOrganizacion({required this.id, required this.nombre, required this.nominal, this.codigo});
  final String id;
  final String nombre;
  final bool nominal;
  final String? codigo;
}

/// Resultado de iniciar sesión.
class ResultadoAcceso {
  const ResultadoAcceso({required this.perfil, required this.esNueva, this.oferta});
  final UserProfile perfil;
  final bool esNueva;
  final OfertaOrganizacion? oferta;

  /// La cuenta ya tiene sector y aviso aceptado: no hace falta repetir el alta.
  bool get perfilCompleto => perfil.sectorId != null && perfil.disclaimerAcceptedAt != null;
}

class ServicioCuenta {
  ServicioCuenta(this.ref);
  final Ref ref;

  Dependencias get _deps => ref.read(dependenciasProvider);

  /// Perfil local que se envía para fusionarlo con la cuenta.
  Map<String, dynamic>? _perfilLocal() {
    final p = ref.read(usuarioProvider).value?.perfil;
    if (p == null) return null;
    final j = p.toJson()..remove('id')..remove('email');
    return j;
  }

  String get _deviceId => ref.read(usuarioProvider).value!.deviceId;

  /// Pide el código de seis cifras. Lanza [SinConexionException] sin red.
  Future<void> pedirCodigo(String email) async {
    if (!ref.read(enLineaProvider)) throw const SinConexionException('sin red');
    await _deps.api.otpRequest(email.trim().toLowerCase());
  }

  Future<ResultadoAcceso> verificarCodigo(String email, String codigo) async {
    if (!ref.read(enLineaProvider)) throw const SinConexionException('sin red');
    final r = await _deps.api.otpVerify(email: email.trim().toLowerCase(), code: codigo, deviceId: _deviceId, localProfile: _perfilLocal());
    return _completar(r);
  }

  /// Apple o Google. En desarrollo el servidor acepta `dev:<correo>`.
  Future<ResultadoAcceso> accederConProveedor(String proveedor, String idToken) async {
    if (!ref.read(enLineaProvider)) throw const SinConexionException('sin red');
    final r = await _deps.api.oauth(provider: proveedor, idToken: idToken, deviceId: _deviceId, localProfile: _perfilLocal());
    return _completar(r);
  }

  Future<ResultadoAcceso> _completar(Map<String, dynamic> r) async {
    final perfil = UserProfile.fromJson((r['user'] as Map).cast<String, dynamic>());
    await ref.read(usuarioProvider.notifier).iniciarSesion('${r['token']}', perfil);
    if (r['entitlements'] is Map) {
      await ref.read(derechosProvider.notifier).guardar(Entitlements.fromJson((r['entitlements'] as Map).cast<String, dynamic>()));
    }
    // Sube los intentos del perfil local y baja los de otros dispositivos.
    final sync = ref.read(sincronizadorProvider);
    try {
      await sync.sincronizar();
      await sync.recuperarHistorial();
    } catch (_) {
      // Se reintentará en segundo plano; el acceso ya está hecho.
    }
    OfertaOrganizacion? oferta;
    try {
      final o = (await _deps.api.orgDomainOffer())['organization'];
      if (o is Map) {
        oferta = OfertaOrganizacion(id: '${o['id']}', nombre: '${o['name']}', nominal: o['nominal'] == true, codigo: o['code'] as String?);
      }
    } catch (_) {}
    return ResultadoAcceso(perfil: perfil, esNueva: r['isNew'] == true, oferta: oferta);
  }
}

final servicioCuentaProvider = Provider<ServicioCuenta>(ServicioCuenta.new);
