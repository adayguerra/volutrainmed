import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/learning_models.dart';
import 'database.dart';

/// Puertos de almacenamiento local. La app usa la implementación Drift; las
/// pruebas de widget usan la de memoria para no depender de SQLite ni dejar
/// temporizadores pendientes.

class PaqueteGuardado {
  const PaqueteGuardado({
    required this.clave,
    required this.id,
    required this.version,
    required this.sha256,
    required this.signature,
    required this.minAppVersion,
    required this.gz,
    required this.status,
  });

  /// Clave lógica: `global` o el id del itinerario. El cambio de versión
  /// sustituye por esta clave aunque el id firmado cambie entre versiones.
  final String clave;

  /// Id del archivo firmado (entra en la cadena firmada).
  final String id;
  final String version;
  final String sha256;
  final String signature;
  final String minAppVersion;
  final Uint8List gz;
  final String status;

  PaqueteGuardado conEstado(String s) => PaqueteGuardado(
        clave: clave,
        id: id,
        version: version,
        sha256: sha256,
        signature: signature,
        minAppVersion: minAppVersion,
        gz: gz,
        status: s,
      );
}

class DescargaParcial {
  const DescargaParcial({
    required this.clave,
    required this.fileId,
    required this.version,
    required this.url,
    required this.sha256,
    required this.signature,
    required this.size,
    required this.minAppVersion,
    required this.partial,
    required this.failures,
  });
  final String clave;
  final String fileId;
  final String version;
  final String url;
  final String sha256;
  final String signature;
  final int size;
  final String minAppVersion;
  final Uint8List partial;
  final int failures;
}

abstract class AlmacenContenido {
  Future<List<PaqueteGuardado>> paquetes({String? status});
  Future<void> guardarPreparado(PaqueteGuardado p);

  /// Cambio atómico: las versiones preparadas pasan a activas y las activas
  /// sustituidas quedan como anteriores. Devuelve las claves cambiadas.
  Future<List<String>> activarPreparados();
  Future<void> instalarActivo(PaqueteGuardado p);
  Future<DescargaParcial?> descarga(String fileId, String version);
  Future<void> guardarDescarga(DescargaParcial d);
  Future<void> borrarDescarga(String fileId, String version);
}

class ElementoSalida {
  const ElementoSalida({required this.seq, required this.kind, required this.refId, required this.payload, required this.tries, this.nextAttemptAt});
  final int seq;
  final String kind;
  final String refId;
  final String payload;
  final int tries;
  final DateTime? nextAttemptAt;
}

class ConsultaGuardada {
  const ConsultaGuardada({required this.id, required this.json, required this.status, this.reference, this.reply, required this.createdAt});
  final String id;
  final Map<String, dynamic> json;
  final String status;
  final String? reference;
  final String? reply;
  final DateTime createdAt;
}

abstract class AlmacenAprendizaje {
  /// Guarda el intento y lo encola en la bandeja de salida en una transacción.
  Future<void> guardarIntento(Attempt a);
  Future<void> guardarSesion(SessionRecord s);
  Future<List<Attempt>> intentos();
  Future<List<SessionRecord>> sesiones();

  /// Inserta intentos y sesiones llegados del servidor sin duplicar ni encolar.
  Future<int> fusionar(List<Attempt> intentos, List<SessionRecord> sesiones);

  Future<void> encolar(String kind, String refId, Map<String, dynamic> payload);
  Future<List<ElementoSalida>> pendientes({required DateTime ahora, String? kind, int limite = 500});
  Future<int> contarPendientes();
  Future<void> marcarEnviados(List<int> seqs);
  Future<void> marcarFallo(List<int> seqs, DateTime siguiente, String error);

  Future<void> guardarConsulta(ConsultaGuardada c);
  Future<List<ConsultaGuardada>> consultas();

  Future<void> borrarTodo();
}

abstract class AlmacenClaves {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
  Future<void> borrar(String clave);

  Future<Map<String, dynamic>?> leerJson(String clave) async {
    final v = await leer(clave);
    if (v == null) return null;
    final d = jsonDecode(v);
    return d is Map ? d.cast<String, dynamic>() : null;
  }

  Future<void> escribirJson(String clave, Object? valor) => escribir(clave, jsonEncode(valor));
}

// ---------------------------------------------------------------------------
// Implementación Drift
// ---------------------------------------------------------------------------

class AlmacenContenidoDrift implements AlmacenContenido {
  AlmacenContenidoDrift(this.db);
  final VtmDatabase db;

  PaqueteGuardado _p(ContentPackageRow r) => PaqueteGuardado(
        clave: r.key,
        id: r.id,
        version: r.version,
        sha256: r.sha256,
        signature: r.signature,
        minAppVersion: r.minAppVersion,
        gz: r.gz,
        status: r.status,
      );

  @override
  Future<List<PaqueteGuardado>> paquetes({String? status}) async {
    final q = db.select(db.contentPackages);
    if (status != null) q.where((t) => t.status.equals(status));
    return (await q.get()).map(_p).toList();
  }

  ContentPackagesCompanion _c(PaqueteGuardado p, String status) => ContentPackagesCompanion.insert(
        key: p.clave,
        id: p.id,
        version: p.version,
        sha256: p.sha256,
        signature: p.signature,
        minAppVersion: Value(p.minAppVersion),
        gz: p.gz,
        status: status,
        installedAt: DateTime.now(),
      );

  @override
  Future<void> guardarPreparado(PaqueteGuardado p) => db.transaction(() async {
        // Si esa versión ya está activa no hay nada que preparar.
        final activa = await (db.select(db.contentPackages)
              ..where((t) => t.key.equals(p.clave) & t.version.equals(p.version) & t.status.equals('active')))
            .getSingleOrNull();
        if (activa != null) return;
        await (db.delete(db.contentPackages)..where((t) => t.key.equals(p.clave) & t.status.equals('staged'))).go();
        await db.into(db.contentPackages).insertOnConflictUpdate(_c(p, 'staged'));
      });

  @override
  Future<List<String>> activarPreparados() => db.transaction(() async {
        final staged = await (db.select(db.contentPackages)..where((t) => t.status.equals('staged'))).get();
        for (final s in staged) {
          await (db.delete(db.contentPackages)..where((t) => t.key.equals(s.key) & t.status.equals('previous'))).go();
          await (db.update(db.contentPackages)..where((t) => t.key.equals(s.key) & t.status.equals('active')))
              .write(const ContentPackagesCompanion(status: Value('previous')));
          await (db.update(db.contentPackages)..where((t) => t.key.equals(s.key) & t.version.equals(s.version)))
              .write(const ContentPackagesCompanion(status: Value('active')));
        }
        return staged.map((s) => s.key).toList();
      });

  @override
  Future<void> instalarActivo(PaqueteGuardado p) => db.transaction(() async {
        await (db.delete(db.contentPackages)
              ..where((t) => t.key.equals(p.clave) & (t.status.equals('previous') | t.version.equals(p.version))))
            .go();
        await (db.update(db.contentPackages)..where((t) => t.key.equals(p.clave) & t.status.equals('active')))
            .write(const ContentPackagesCompanion(status: Value('previous')));
        await db.into(db.contentPackages).insertOnConflictUpdate(_c(p, 'active'));
      });

  @override
  Future<DescargaParcial?> descarga(String fileId, String version) async {
    final r = await (db.select(db.contentDownloads)..where((t) => t.fileId.equals(fileId) & t.version.equals(version))).getSingleOrNull();
    if (r == null) return null;
    return DescargaParcial(
      clave: r.key,
      fileId: r.fileId,
      version: r.version,
      url: r.url,
      sha256: r.sha256,
      signature: r.signature,
      size: r.size,
      minAppVersion: r.minAppVersion,
      partial: r.partial,
      failures: r.failures,
    );
  }

  @override
  Future<void> guardarDescarga(DescargaParcial d) => db.into(db.contentDownloads).insertOnConflictUpdate(ContentDownloadsCompanion.insert(
        key: d.clave,
        fileId: d.fileId,
        version: d.version,
        url: d.url,
        sha256: d.sha256,
        signature: d.signature,
        size: d.size,
        minAppVersion: Value(d.minAppVersion),
        partial: d.partial,
        failures: Value(d.failures),
        updatedAt: DateTime.now(),
      ));

  @override
  Future<void> borrarDescarga(String fileId, String version) =>
      (db.delete(db.contentDownloads)..where((t) => t.fileId.equals(fileId) & t.version.equals(version))).go();
}

class AlmacenAprendizajeDrift implements AlmacenAprendizaje {
  AlmacenAprendizajeDrift(this.db);
  final VtmDatabase db;

  @override
  Future<void> guardarIntento(Attempt a) => db.transaction(() async {
        final json = a.toJson();
        await db.into(db.attempts).insert(
              AttemptsCompanion.insert(id: a.id, sessionId: a.sessionId, json: jsonEncode(json), deviceTime: a.deviceTime),
              mode: InsertMode.insertOrIgnore,
            );
        await encolar('attempt', a.id, json);
      });

  @override
  Future<void> guardarSesion(SessionRecord s) => db.transaction(() async {
        final json = s.toJson();
        await db.into(db.sessions).insertOnConflictUpdate(SessionsCompanion.insert(id: s.id, json: jsonEncode(json), startedAt: s.startedAt));
        await encolar('session', s.id, json);
      });

  @override
  Future<List<Attempt>> intentos() async =>
      (await db.select(db.attempts).get()).map((r) => Attempt.fromJson(jsonDecode(r.json) as Map<String, dynamic>)).toList();

  @override
  Future<List<SessionRecord>> sesiones() async =>
      (await db.select(db.sessions).get()).map((r) => SessionRecord.fromJson(jsonDecode(r.json) as Map<String, dynamic>)).toList();

  @override
  Future<int> fusionar(List<Attempt> intentos, List<SessionRecord> sesiones) => db.transaction(() async {
        // Se cuentan solo los intentos nuevos: `insertOrIgnore` no informa de
        // forma fiable de las filas ignoradas, así que se consulta antes.
        final ids = intentos.map((a) => a.id).toList();
        final existentes = <String>{};
        for (var i = 0; i < ids.length; i += 500) {
          final trozo = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
          final filas = await (db.selectOnly(db.attempts)
                ..addColumns([db.attempts.id])
                ..where(db.attempts.id.isIn(trozo)))
              .get();
          existentes.addAll(filas.map((r) => r.read(db.attempts.id)!));
        }
        var n = 0;
        for (final a in intentos) {
          if (existentes.contains(a.id)) continue;
          existentes.add(a.id);
          await db.into(db.attempts).insert(
                AttemptsCompanion.insert(id: a.id, sessionId: a.sessionId, json: jsonEncode(a.toJson()), deviceTime: a.deviceTime),
                mode: InsertMode.insertOrIgnore,
              );
          n++;
        }
        for (final s in sesiones) {
          await db.into(db.sessions).insert(
                SessionsCompanion.insert(id: s.id, json: jsonEncode(s.toJson()), startedAt: s.startedAt),
                mode: InsertMode.insertOrIgnore,
              );
        }
        return n;
      });

  @override
  Future<void> encolar(String kind, String refId, Map<String, dynamic> payload) => db.into(db.outbox).insert(
        OutboxCompanion.insert(kind: kind, refId: refId, payload: jsonEncode(payload), createdAt: DateTime.now()),
        onConflict: DoUpdate((old) => OutboxCompanion(payload: Value(jsonEncode(payload))), target: [db.outbox.kind, db.outbox.refId]),
      );

  @override
  Future<List<ElementoSalida>> pendientes({required DateTime ahora, String? kind, int limite = 500}) async {
    final q = db.select(db.outbox)
      ..where((t) => t.nextAttemptAt.isNull() | t.nextAttemptAt.isSmallerOrEqualValue(ahora))
      ..orderBy([(t) => OrderingTerm.asc(t.seq)])
      ..limit(limite);
    if (kind != null) q.where((t) => t.kind.equals(kind));
    return (await q.get())
        .map((r) => ElementoSalida(seq: r.seq, kind: r.kind, refId: r.refId, payload: r.payload, tries: r.tries, nextAttemptAt: r.nextAttemptAt))
        .toList();
  }

  @override
  Future<int> contarPendientes() async {
    final c = db.outbox.seq.count();
    final r = await (db.selectOnly(db.outbox)..addColumns([c])).getSingle();
    return r.read(c) ?? 0;
  }

  @override
  Future<void> marcarEnviados(List<int> seqs) => (db.delete(db.outbox)..where((t) => t.seq.isIn(seqs))).go();

  @override
  Future<void> marcarFallo(List<int> seqs, DateTime siguiente, String error) => db.customUpdate(
        'UPDATE outbox SET tries = tries + 1, next_attempt_at = ?, last_error = ? WHERE seq IN (${seqs.map((_) => '?').join(',')})',
        variables: [Variable.withDateTime(siguiente), Variable.withString(error), ...seqs.map(Variable.withInt)],
        updates: {db.outbox},
      );

  @override
  Future<void> guardarConsulta(ConsultaGuardada c) => db.into(db.inquiries).insertOnConflictUpdate(InquiriesCompanion.insert(
        id: c.id,
        json: jsonEncode(c.json),
        status: c.status,
        reference: Value(c.reference),
        reply: Value(c.reply),
        createdAt: c.createdAt,
      ));

  @override
  Future<List<ConsultaGuardada>> consultas() async => (await (db.select(db.inquiries)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get())
      .map((r) => ConsultaGuardada(
            id: r.id,
            json: jsonDecode(r.json) as Map<String, dynamic>,
            status: r.status,
            reference: r.reference,
            reply: r.reply,
            createdAt: r.createdAt,
          ))
      .toList();

  @override
  Future<void> borrarTodo() => db.transaction(() async {
        await db.delete(db.attempts).go();
        await db.delete(db.sessions).go();
        await db.delete(db.outbox).go();
        await db.delete(db.inquiries).go();
      });
}

class AlmacenClavesDrift extends AlmacenClaves {
  AlmacenClavesDrift(this.db);
  final VtmDatabase db;
  @override
  Future<String?> leer(String clave) async =>
      (await (db.select(db.keyValues)..where((t) => t.key.equals(clave))).getSingleOrNull())?.value;
  @override
  Future<void> escribir(String clave, String valor) =>
      db.into(db.keyValues).insertOnConflictUpdate(KeyValuesCompanion.insert(key: clave, value: valor));
  @override
  Future<void> borrar(String clave) => (db.delete(db.keyValues)..where((t) => t.key.equals(clave))).go();
}

// ---------------------------------------------------------------------------
// Implementación en memoria (pruebas de widget)
// ---------------------------------------------------------------------------

class AlmacenContenidoMemoria implements AlmacenContenido {
  final List<PaqueteGuardado> _p = [];
  final Map<String, DescargaParcial> _d = {};

  @override
  Future<List<PaqueteGuardado>> paquetes({String? status}) async => _p.where((p) => status == null || p.status == status).toList();

  @override
  Future<void> guardarPreparado(PaqueteGuardado p) async {
    if (_p.any((x) => x.clave == p.clave && x.version == p.version && x.status == 'active')) return;
    _p.removeWhere((x) => x.clave == p.clave && (x.status == 'staged' || x.version == p.version));
    _p.add(p.conEstado('staged'));
  }

  @override
  Future<List<String>> activarPreparados() async {
    final staged = _p.where((x) => x.status == 'staged').toList();
    for (final s in staged) {
      _p.removeWhere((x) => x.clave == s.clave && x.status == 'previous');
      for (var i = 0; i < _p.length; i++) {
        if (_p[i].clave == s.clave && _p[i].status == 'active') _p[i] = _p[i].conEstado('previous');
      }
      _p.remove(s);
      _p.add(s.conEstado('active'));
    }
    return staged.map((s) => s.clave).toList();
  }

  @override
  Future<void> instalarActivo(PaqueteGuardado p) async {
    _p.removeWhere((x) => x.clave == p.clave && (x.status == 'previous' || x.version == p.version));
    for (var i = 0; i < _p.length; i++) {
      if (_p[i].clave == p.clave && _p[i].status == 'active') _p[i] = _p[i].conEstado('previous');
    }
    _p.add(p.conEstado('active'));
  }

  @override
  Future<DescargaParcial?> descarga(String fileId, String version) async => _d['$fileId|$version'];
  @override
  Future<void> guardarDescarga(DescargaParcial d) async => _d['${d.fileId}|${d.version}'] = d;
  @override
  Future<void> borrarDescarga(String fileId, String version) async => _d.remove('$fileId|$version');
}

class AlmacenAprendizajeMemoria implements AlmacenAprendizaje {
  final Map<String, Attempt> _a = {};
  final Map<String, SessionRecord> _s = {};
  final List<(int, String, String, String, int, DateTime?)> _o = [];
  final Map<String, ConsultaGuardada> _c = {};
  int _seq = 0;

  @override
  Future<void> guardarIntento(Attempt a) async {
    _a.putIfAbsent(a.id, () => a);
    await encolar('attempt', a.id, a.toJson());
  }

  @override
  Future<void> guardarSesion(SessionRecord s) async {
    _s[s.id] = s;
    await encolar('session', s.id, s.toJson());
  }

  @override
  Future<List<Attempt>> intentos() async => _a.values.toList();
  @override
  Future<List<SessionRecord>> sesiones() async => _s.values.toList();

  @override
  Future<int> fusionar(List<Attempt> intentos, List<SessionRecord> sesiones) async {
    var n = 0;
    for (final a in intentos) {
      if (!_a.containsKey(a.id)) {
        _a[a.id] = a;
        n++;
      }
    }
    for (final s in sesiones) {
      _s.putIfAbsent(s.id, () => s);
    }
    return n;
  }

  @override
  Future<void> encolar(String kind, String refId, Map<String, dynamic> payload) async {
    _o.removeWhere((e) => e.$2 == kind && e.$3 == refId);
    _o.add((++_seq, kind, refId, jsonEncode(payload), 0, null));
  }

  @override
  Future<List<ElementoSalida>> pendientes({required DateTime ahora, String? kind, int limite = 500}) async => _o
      .where((e) => (kind == null || e.$2 == kind) && (e.$6 == null || !e.$6!.isAfter(ahora)))
      .take(limite)
      .map((e) => ElementoSalida(seq: e.$1, kind: e.$2, refId: e.$3, payload: e.$4, tries: e.$5, nextAttemptAt: e.$6))
      .toList();

  @override
  Future<int> contarPendientes() async => _o.length;
  @override
  Future<void> marcarEnviados(List<int> seqs) async => _o.removeWhere((e) => seqs.contains(e.$1));
  @override
  Future<void> marcarFallo(List<int> seqs, DateTime siguiente, String error) async {
    for (var i = 0; i < _o.length; i++) {
      final e = _o[i];
      if (seqs.contains(e.$1)) _o[i] = (e.$1, e.$2, e.$3, e.$4, e.$5 + 1, siguiente);
    }
  }

  @override
  Future<void> guardarConsulta(ConsultaGuardada c) async => _c[c.id] = c;
  @override
  Future<List<ConsultaGuardada>> consultas() async => _c.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<void> borrarTodo() async {
    _a.clear();
    _s.clear();
    _o.clear();
    _c.clear();
  }
}

class AlmacenClavesMemoria extends AlmacenClaves {
  AlmacenClavesMemoria([Map<String, String>? inicial]) : _m = {...?inicial};
  final Map<String, String> _m;
  @override
  Future<String?> leer(String clave) async => _m[clave];
  @override
  Future<void> escribir(String clave, String valor) async => _m[clave] = valor;
  @override
  Future<void> borrar(String clave) async => _m.remove(clave);
}
