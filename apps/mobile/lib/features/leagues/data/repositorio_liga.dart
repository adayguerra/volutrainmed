import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../core/data/api_client.dart';
import '../../../core/domain/reloj.dart';
import '../domain/league.dart';

/// Liga semanal y ligas privadas (leagues, lado app): consulta a la API con
/// cuenta, caché de la última clasificación con su hora para verla sin
/// conexión y puntos propios pendientes de sumar calculados en el dispositivo.

const claveLigaCache = 'liga.cache';
const claveLigasPrivadasCache = 'liga.privadas';
const textoReglaLiga = 'Solo puntúan los aciertos al primer intento. Tope de 300 puntos al día.';
const textoLigaSinCuenta = 'Las ligas necesitan una cuenta: compites con un alias, sin tu nombre ni tu correo.';

class LigaPrivada {
  const LigaPrivada({required this.id, required this.nombre, required this.filas});
  final String id;
  final String nombre;
  final List<FilaLiga> filas;

  factory LigaPrivada.fromJson(Map<String, dynamic> j) => LigaPrivada(
        id: '${j['id']}',
        nombre: '${j['name'] ?? ''}',
        filas: ((j['standings'] as List?) ?? const []).whereType<Map>().map((e) => FilaLiga.fromJson(e.cast<String, dynamic>())).toList()
          ..sort((a, b) => a.position.compareTo(b.position)),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': nombre, 'standings': filas.map((f) => f.toJson()).toList()};
}

class EstadoLiga {
  const EstadoLiga({this.clasificacion, this.desdeCache = false, this.sinCuenta = false, this.privadas = const [], this.puntosPendientes = 0, this.error});
  final ClasificacionLiga? clasificacion;

  /// Clasificación guardada (sin conexión): se muestra con su antigüedad.
  final bool desdeCache;
  final bool sinCuenta;
  final List<LigaPrivada> privadas;

  /// Puntos propios de intentos aún no sincronizados (con tope diario).
  final int puntosPendientes;
  final String? error;
}

/// Puntos de liga de lo que aún está en la bandeja de salida.
Future<int> puntosPendientesLiga(Ref ref) async {
  final deps = ref.read(dependenciasProvider);
  final c = ref.read(contenidoProvider).value;
  if (c == null) return 0;
  final ahora = deps.reloj.ahora();
  final pendientes = await deps.aprendizaje.pendientes(ahora: DateTime(9999), limite: 100000);
  final idsIntentos = {for (final e in pendientes) if (e.kind == 'attempt') e.refId};
  final idsSesiones = {for (final e in pendientes) if (e.kind == 'session') e.refId};
  final datos = ref.read(aprendizajeProvider).value;
  if (datos == null) return 0;
  final p = puntosLiga(
    intentos: datos.intentos.where((a) => idsIntentos.contains(a.id)),
    sesiones: datos.sesiones.where((s) => idsSesiones.contains(s.id)),
    config: c.global.league,
    desde: lunesDe(ahora),
  );
  return p.total;
}

final ligaProvider = FutureProvider.autoDispose<EstadoLiga>((ref) async {
  final deps = ref.read(dependenciasProvider);
  final u = await ref.read(usuarioProvider.future);
  ref.watch(aprendizajeProvider);
  if (!u.conCuenta) return const EstadoLiga(sinCuenta: true);
  final pendientes = await puntosPendientesLiga(ref);
  final enLinea = ref.read(enLineaProvider);
  if (enLinea) {
    try {
      final j = await deps.api.leagueCurrent();
      // Sin «computedAt» (no participa) se fecha con la hora del dispositivo.
      final json = {...j, 'computedAt': j['computedAt'] ?? deps.reloj.ahora().toUtc().toIso8601String()};
      await deps.claves.escribirJson(claveLigaCache, json);
      var privadas = const <LigaPrivada>[];
      try {
        final p = await deps.api.leaguesPrivate();
        privadas = ((p['leagues'] as List?) ?? const []).whereType<Map>().map((e) => LigaPrivada.fromJson(e.cast<String, dynamic>())).toList();
        await deps.claves.escribirJson(claveLigasPrivadasCache, {'leagues': privadas.map((x) => x.toJson()).toList()});
      } catch (_) {}
      return EstadoLiga(clasificacion: ClasificacionLiga.fromJson(json), privadas: privadas, puntosPendientes: pendientes);
    } on ApiException catch (e) {
      final cache = await _desdeCache(deps, pendientes);
      return cache ?? EstadoLiga(error: e.message, puntosPendientes: pendientes);
    } catch (_) {
      // Sin conexión real: se recurre a la caché.
    }
  }
  return await _desdeCache(deps, pendientes) ?? EstadoLiga(puntosPendientes: pendientes, desdeCache: true);
});

Future<EstadoLiga?> _desdeCache(Dependencias deps, int pendientes) async {
  final j = await deps.claves.leerJson(claveLigaCache);
  if (j == null) return null;
  final p = await deps.claves.leerJson(claveLigasPrivadasCache);
  return EstadoLiga(
    clasificacion: ClasificacionLiga.fromJson(j),
    desdeCache: true,
    puntosPendientes: pendientes,
    privadas: ((p?['leagues'] as List?) ?? const []).whereType<Map>().map((e) => LigaPrivada.fromJson(e.cast<String, dynamic>())).toList(),
  );
}

/// Alias válido: seudónimo de 3 a 20 caracteres sin espacios ni arrobas.
String? validarAlias(String a) {
  final t = a.trim();
  if (t.length < 3 || t.length > 20) return 'Entre 3 y 20 caracteres';
  if (t.contains('@') || t.contains(' ')) return 'Sin espacios ni arrobas: usa un seudónimo';
  return null;
}

/// Entra o sale de las ligas (y cambia el alias). Requiere conexión.
Future<void> cambiarParticipacion(WidgetRef ref, bool participar, {String? alias}) async {
  final deps = ref.read(dependenciasProvider);
  await deps.api.leagueParticipation(participar, alias: alias?.trim());
  final cache = await deps.claves.leerJson(claveLigaCache);
  if (cache != null) await deps.claves.escribirJson(claveLigaCache, {...cache, 'participating': participar});
  final u = ref.read(usuarioProvider).value;
  if (alias != null && u?.perfil != null) {
    await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(alias: alias.trim(), leaguesOptIn: participar));
  } else if (u?.perfil != null) {
    await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(leaguesOptIn: participar));
  }
  ref.invalidate(ligaProvider);
}

/// Etiqueta de una fila para el lector de pantalla (solo alias).
String etiquetaFila(FilaLiga f) => ClasificacionLiga.etiquetaFila(f);
