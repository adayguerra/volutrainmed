import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/dependencias.dart';
import '../../app/estado/estado_app.dart';
import '../contenido/repositorio_contenido.dart' show versionApp;
import '../data/almacenes.dart';
import '../data/api_client.dart';
import '../domain/learning_models.dart';
import '../domain/reloj.dart';

const textoErrorSync = 'No se ha podido sincronizar. Lo reintentaremos';

/// Intentos por lote de subida (contrato: 500 como máximo).
const loteMaximo = 500;

/// Estado de la sincronización para la interfaz (centro de sincronización).
@immutable
class EstadoSync {
  const EstadoSync({this.sincronizando = false, this.pendientes = 0, this.ultima, this.error});
  final bool sincronizando;
  final int pendientes;
  final DateTime? ultima;

  /// «No se ha podido sincronizar. Lo reintentaremos» tras un fallo.
  final String? error;

  EstadoSync copyWith({bool? sincronizando, int? pendientes, DateTime? ultima, String? error, bool sinError = false}) => EstadoSync(
        sincronizando: sincronizando ?? this.sincronizando,
        pendientes: pendientes ?? this.pendientes,
        ultima: ultima ?? this.ultima,
        error: sinError ? null : (error ?? this.error),
      );
}

/// Sincronización del progreso (offline-sync, diseños D5 y D6): sube la
/// bandeja de salida por lotes idempotentes y baja lo de otros dispositivos.
abstract class Sincronizador {
  ValueListenable<EstadoSync> get estado;

  /// Sincroniza ahora (en segundo plano; nunca interrumpe el entrenamiento).
  /// Con [forzar] se reintentan también los elementos aplazados por un fallo
  /// anterior (al recuperar la conexión o con «Sincronizar ahora»).
  Future<void> sincronizar({bool forzar = false});

  /// Tras iniciar sesión en un dispositivo nuevo: baja todo el historial.
  Future<void> recuperarHistorial();

  /// Vuelve a contar los elementos pendientes.
  Future<void> refrescar();
}

class SincronizadorInactivo implements Sincronizador {
  final _estado = ValueNotifier(const EstadoSync());
  @override
  ValueListenable<EstadoSync> get estado => _estado;
  @override
  Future<void> sincronizar({bool forzar = false}) async {}
  @override
  Future<void> recuperarHistorial() async {}
  @override
  Future<void> refrescar() async {}
}

/// Espera antes de reintentar un elemento que ha fallado [intentos] veces:
/// 30 s, 1 min, 2 min… hasta una hora.
Duration esperaReintento(int intentos) => Duration(seconds: min(3600, 30 * pow(2, intentos).toInt()));

/// Estado de una consulta según el servidor.
String estadoConsultaLocal(String servidor) => switch (servidor) {
      'in_review' || 'reviewing' => 'in_review',
      'answered' || 'closed' => 'answered',
      _ => 'received',
    };

class SincronizadorReal implements Sincronizador {
  SincronizadorReal({
    required this.almacen,
    required this.api,
    required this.reloj,
    required this.usuario,
    required this.guardarCursor,
    required this.alRecibir,
  });

  final AlmacenAprendizaje almacen;
  final ApiClient api;
  final Reloj reloj;

  /// Estado del usuario en este momento (dispositivo, token y cursor).
  final EstadoUsuario? Function() usuario;
  final Future<void> Function(String cursor, DateTime cuando) guardarCursor;

  /// Se llama tras incorporar intentos llegados del servidor.
  final Future<void> Function() alRecibir;

  final _estado = ValueNotifier(const EstadoSync());
  Future<void>? _enCurso;

  @override
  ValueListenable<EstadoSync> get estado => _estado;

  @override
  Future<void> refrescar() async {
    _estado.value = _estado.value.copyWith(pendientes: await almacen.contarPendientes());
  }

  @override
  Future<void> sincronizar({bool forzar = false}) => _enCurso ??= _ejecutar(forzar: forzar).whenComplete(() => _enCurso = null);

  @override
  Future<void> recuperarHistorial() async {
    await _enCurso;
    _estado.value = _estado.value.copyWith(sincronizando: true);
    try {
      await _recibir(desdeCero: true);
      _estado.value = _estado.value.copyWith(sincronizando: false, ultima: reloj.ahora(), sinError: true);
    } catch (_) {
      _estado.value = _estado.value.copyWith(sincronizando: false, error: textoErrorSync);
    }
  }

  Future<void> _ejecutar({required bool forzar}) async {
    final u = usuario();
    if (u == null) return;
    _estado.value = _estado.value.copyWith(sincronizando: true);
    var fallo = false;
    try {
      fallo |= !await _enviarConsultas(u, forzar);
      fallo |= !await _enviarEventosSinCuenta(u, forzar);
      if (u.conCuenta) {
        fallo |= !await _subir(u, forzar);
        if (!fallo) {
          await _recibir();
          await _refrescarConsultas();
        }
      }
    } catch (_) {
      fallo = true;
    }
    final pendientes = await almacen.contarPendientes();
    _estado.value = fallo
        ? _estado.value.copyWith(sincronizando: false, pendientes: pendientes, error: textoErrorSync)
        : _estado.value.copyWith(sincronizando: false, pendientes: pendientes, ultima: reloj.ahora(), sinError: true);
  }

  DateTime _corte(bool forzar) => forzar ? DateTime(9999) : reloj.ahora();

  Future<void> _fallo(List<ElementoSalida> elementos, Object e) async {
    if (elementos.isEmpty) return;
    final intentos = elementos.map((x) => x.tries).reduce(max);
    await almacen.marcarFallo(elementos.map((x) => x.seq).toList(), reloj.ahora().add(esperaReintento(intentos)), '$e');
  }

  /// Consultas: se admiten sin cuenta, con el identificador del dispositivo.
  Future<bool> _enviarConsultas(EstadoUsuario u, bool forzar) async {
    var ok = true;
    final consultas = {for (final c in await almacen.consultas()) c.id: c};
    for (final e in await almacen.pendientes(ahora: _corte(forzar), kind: 'inquiry')) {
      try {
        final r = await api.postInquiry((jsonDecode(e.payload) as Map).cast<String, dynamic>(), deviceId: u.deviceId);
        await almacen.marcarEnviados([e.seq]);
        final c = consultas[e.refId];
        if (c != null) {
          await almacen.guardarConsulta(ConsultaGuardada(
            id: c.id,
            json: c.json,
            status: estadoConsultaLocal('${r['status'] ?? 'received'}'),
            reference: r['reference'] as String?,
            reply: c.reply,
            createdAt: c.createdAt,
          ));
        }
      } catch (err) {
        await _fallo([e], err);
        ok = false;
      }
    }
    return ok;
  }

  /// Sin cuenta, los eventos se envían con el identificador seudónimo del
  /// dispositivo. Con cuenta viajan junto a los intentos.
  Future<bool> _enviarEventosSinCuenta(EstadoUsuario u, bool forzar) async {
    if (u.conCuenta) return true;
    final eventos = await almacen.pendientes(ahora: _corte(forzar), kind: 'event', limite: 1000);
    if (eventos.isEmpty) return true;
    try {
      await api.events(u.deviceId, [for (final e in eventos) (jsonDecode(e.payload) as Map).cast<String, dynamic>()]);
      await almacen.marcarEnviados(eventos.map((e) => e.seq).toList());
      return true;
    } catch (err) {
      await _fallo(eventos, err);
      return false;
    }
  }

  /// Sube intentos, sesiones y eventos en lotes idempotentes por `id`.
  Future<bool> _subir(EstadoUsuario u, bool forzar) async {
    final corte = _corte(forzar);
    final enviados = <int>{};
    while (true) {
      final intentos = (await almacen.pendientes(ahora: corte, kind: 'attempt', limite: loteMaximo + enviados.length))
          .where((e) => !enviados.contains(e.seq))
          .take(loteMaximo)
          .toList();
      final sesiones = (await almacen.pendientes(ahora: corte, kind: 'session', limite: 100000)).where((e) => !enviados.contains(e.seq)).take(loteMaximo).toList();
      final eventos = (await almacen.pendientes(ahora: corte, kind: 'event', limite: 100000)).where((e) => !enviados.contains(e.seq)).take(1000).toList();
      final lote = [...intentos, ...sesiones, ...eventos];
      if (lote.isEmpty) return true;
      List<Map<String, dynamic>> cargas(List<ElementoSalida> l) => [for (final e in l) (jsonDecode(e.payload) as Map).cast<String, dynamic>()];
      try {
        await api.syncPush({
          'deviceId': u.deviceId,
          'appVersion': versionApp,
          'attempts': cargas(intentos),
          'sessions': cargas(sesiones),
          'events': cargas(eventos),
        });
        final seqs = lote.map((e) => e.seq).toList();
        await almacen.marcarEnviados(seqs);
        enviados.addAll(seqs);
      } catch (err) {
        await _fallo(lote, err);
        return false;
      }
    }
  }

  /// Baja intentos y sesiones de otros dispositivos con el cursor.
  Future<void> _recibir({bool desdeCero = false}) async {
    final u = usuario();
    if (u == null || !u.conCuenta) return;
    String? cursor = desdeCero ? null : u.cursorSync;
    var nuevos = 0;
    while (true) {
      final r = await api.syncPull(cursor);
      final intentos = ((r['attempts'] as List?) ?? const []).map((e) => Attempt.fromJson((e as Map).cast<String, dynamic>())).toList();
      final sesiones = ((r['sessions'] as List?) ?? const []).map((e) => SessionRecord.fromJson((e as Map).cast<String, dynamic>())).toList();
      nuevos += await almacen.fusionar(intentos, sesiones);
      if (sesiones.isNotEmpty) nuevos++;
      cursor = r['cursor'] as String? ?? cursor;
      if (r['hasMore'] != true) break;
    }
    if (cursor != null) await guardarCursor(cursor, reloj.ahora());
    if (nuevos > 0) await alRecibir();
  }

  Future<void> _refrescarConsultas() async {
    try {
      final r = await api.inquiries();
      final locales = {for (final c in await almacen.consultas()) c.id: c};
      for (final i in ((r['items'] as List?) ?? const []).cast<Map>()) {
        final c = locales['${i['id']}'];
        if (c == null) continue;
        await almacen.guardarConsulta(ConsultaGuardada(
          id: c.id,
          json: c.json,
          status: estadoConsultaLocal('${i['status']}'),
          reference: (i['reference'] as String?) ?? c.reference,
          reply: i['reply'] as String?,
          createdAt: c.createdAt,
        ));
      }
    } catch (_) {
      // El estado de las consultas no es crítico: se reintenta en la próxima.
    }
  }

  void dispose() => _estado.dispose();
}

final sincronizadorProvider = Provider<Sincronizador>((ref) {
  final deps = ref.watch(dependenciasProvider);
  final s = SincronizadorReal(
    almacen: deps.aprendizaje,
    api: deps.api,
    reloj: deps.reloj,
    usuario: () => ref.read(usuarioProvider).value,
    guardarCursor: (c, t) => ref.read(usuarioProvider.notifier).actualizar((e) => e.copyWith(cursorSync: c, ultimaSync: t)),
    alRecibir: () => ref.read(aprendizajeProvider.notifier).recargar(),
  );
  ref.onDispose(s.dispose);
  return s;
});

/// Sincronización automática, sin intervención del usuario: al arrancar con
/// conexión y cada vez que se recupera la conexión. Se activa al leerlo desde
/// la raíz de la app.
final sincronizacionAutomaticaProvider = Provider<void>((ref) {
  final s = ref.watch(sincronizadorProvider);
  ref.listen(conexionProvider, (prev, next) {
    final antes = prev?.value;
    final ahora = next.value;
    if (ahora == true && antes == false) unawaited(s.sincronizar(forzar: true));
    if (ahora == true && antes == null) unawaited(_alArrancar(ref, s));
  }, fireImmediately: true);
});

Future<void> _alArrancar(Ref ref, Sincronizador s) async {
  await s.refrescar();
  final u = ref.read(usuarioProvider).value;
  // Sin cuenta y sin nada pendiente no hay nada que hacer: ninguna petición.
  if (u == null || (!u.conCuenta && s.estado.value.pendientes == 0)) return;
  await s.sincronizar();
}
