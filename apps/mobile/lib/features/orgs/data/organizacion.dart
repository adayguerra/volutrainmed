import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../core/domain/learning_models.dart';

/// Organizaciones, lado app (organizations): vista previa antes de unirse con
/// lo que verá la organización, unión con aceptación del modo nominal,
/// apartado «Qué ve tu organización», itinerarios asignados y salida. La
/// información de la organización se guarda para verla sin conexión.

const claveOrgCache = 'org.cache';
const textoPlazasAgotadas = 'La organización no tiene plazas libres. Ya le hemos avisado';
const textoVigenciaTerminada =
    'La licencia de tu organización ha terminado. Conservas todo tu progreso y vuelves al plan gratuito.';
const textoOrgSinCuenta = 'Para unirte a una organización necesitas una cuenta: así tu plaza te acompaña en todos tus dispositivos.';

/// Mensaje para cada error de la API al unirse.
String mensajeErrorOrg(String code, String porDefecto) => switch (code) {
      'seats_exhausted' => textoPlazasAgotadas,
      'org_expired' => 'La licencia de la organización ha terminado',
      'already_member' => 'Ya perteneces a otra organización. Sal de ella antes de unirte',
      'not_found' => 'El código no corresponde a ninguna organización',
      _ => porDefecto,
    };

class VistaPreviaOrg {
  const VistaPreviaOrg({required this.id, required this.nombre, required this.nominal, required this.datosVisibles, this.grupo});
  final String id;
  final String nombre;
  final bool nominal;
  final List<String> datosVisibles;
  final String? grupo;

  factory VistaPreviaOrg.fromJson(Map<String, dynamic> j) {
    final o = (j['organization'] as Map).cast<String, dynamic>();
    return VistaPreviaOrg(
      id: '${o['id']}',
      nombre: '${o['name']}',
      nominal: o['nominal'] == true,
      datosVisibles: ((o['visibleData'] as List?) ?? const []).map((e) => '$e').toList(),
      grupo: (j['group'] as Map?)?['name']?.toString(),
    );
  }
}

class MiOrganizacion {
  const MiOrganizacion({required this.id, required this.nombre, required this.nominal, required this.datosVisibles, this.grupo, this.itinerariosAsignados = const []});
  final String id;
  final String nombre;
  final bool nominal;
  final String? grupo;
  final List<String> datosVisibles;
  final List<String> itinerariosAsignados;

  static MiOrganizacion? fromJson(Map<String, dynamic>? j) {
    final o = (j?['organization'] as Map?)?.cast<String, dynamic>();
    if (j == null || o == null) return null;
    return MiOrganizacion(
      id: '${o['id']}',
      nombre: '${o['name']}',
      nominal: o['nominal'] == true,
      grupo: (j['group'] as Map?)?['name']?.toString(),
      datosVisibles: ((j['visibleData'] as List?) ?? const []).map((e) => '$e').toList(),
      itinerariosAsignados: ((j['assignedItineraries'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

class EstadoOrg {
  const EstadoOrg({this.miembro, this.sinCuenta = false, this.desdeCache = false, this.vigenciaTerminada = false});
  final MiOrganizacion? miembro;
  final bool sinCuenta;
  final bool desdeCache;

  /// La plaza de organización ha caducado: plan gratuito, progreso intacto.
  final bool vigenciaTerminada;
}

bool _plazaCaducada(Entitlements e) => e.source == 'organization' && !e.premium;

final orgProvider = FutureProvider.autoDispose<EstadoOrg>((ref) async {
  final deps = ref.read(dependenciasProvider);
  final u = await ref.read(usuarioProvider.future);
  final caducada = _plazaCaducada(ref.watch(derechosProvider));
  if (!u.conCuenta) return EstadoOrg(sinCuenta: true, vigenciaTerminada: caducada);
  if (ref.read(enLineaProvider)) {
    try {
      final j = await deps.api.orgMine();
      await deps.claves.escribirJson(claveOrgCache, j);
      ref.invalidate(itinerariosAsignadosProvider);
      return EstadoOrg(miembro: MiOrganizacion.fromJson(j), vigenciaTerminada: caducada);
    } catch (_) {
      // Se recurre a la información guardada.
    }
  }
  final cache = await deps.claves.leerJson(claveOrgCache);
  return EstadoOrg(miembro: MiOrganizacion.fromJson(cache), desdeCache: true, vigenciaTerminada: caducada);
});

/// Itinerarios asignados por la organización (guardados, sin red).
final itinerariosAsignadosProvider = FutureProvider<List<String>>((ref) async {
  final j = await ref.read(dependenciasProvider).claves.leerJson(claveOrgCache);
  return MiOrganizacion.fromJson(j)?.itinerariosAsignados ?? const [];
});

Future<VistaPreviaOrg> previsualizarOrg(WidgetRef ref, String codigo) async =>
    VistaPreviaOrg.fromJson(await ref.read(dependenciasProvider).api.orgPreview(codigo.trim().toUpperCase()));

/// Se une a la organización y guarda los derechos de la plaza (sin pausas).
Future<void> unirseOrg(WidgetRef ref, String codigo, {required bool aceptaNominal}) async {
  final deps = ref.read(dependenciasProvider);
  final r = await deps.api.orgJoin(codigo.trim().toUpperCase(), aceptaNominal);
  final ent = r['entitlements'];
  if (ent is Map) await ref.read(derechosProvider.notifier).guardar(Entitlements.fromJson(ent.cast<String, dynamic>()));
  try {
    await deps.claves.escribirJson(claveOrgCache, await deps.api.orgMine());
  } catch (_) {}
  ref.invalidate(itinerariosAsignadosProvider);
  ref.invalidate(orgProvider);
}

Future<void> salirOrg(WidgetRef ref) async {
  final deps = ref.read(dependenciasProvider);
  await deps.api.orgLeave();
  await deps.claves.escribirJson(claveOrgCache, {'organization': null});
  try {
    final ent = await deps.api.entitlements();
    await ref.read(derechosProvider.notifier).guardar(Entitlements.fromJson(ent));
  } catch (_) {}
  ref.invalidate(itinerariosAsignadosProvider);
  ref.invalidate(orgProvider);
}
