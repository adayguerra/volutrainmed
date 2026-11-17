import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Base de datos local (diseño D6, definición funcional 9.5).
///
/// Tres grupos de tablas:
/// - **Contenido** (solo lectura para la app): paquetes firmados ya verificados,
///   descargas parciales reanudables y lista de retirada.
/// - **Aprendizaje**: sesiones e intentos. Solo se añaden; todo lo demás
///   (fichas, dominio, rachas, progreso) se proyecta a partir de ellos.
/// - **Bandeja de salida**: intentos, sesiones, eventos y consultas
///   pendientes de subir, con su número de reintentos.
/// Además, una tabla clave-valor para perfil, preferencias y cachés.

@DataClassName('ContentPackageRow')
class ContentPackages extends Table {
  TextColumn get id => text()();
  TextColumn get version => text()();
  TextColumn get sha256 => text()();
  TextColumn get signature => text()();
  TextColumn get minAppVersion => text().withDefault(const Constant('1.0.0'))();

  /// Bytes gzip tal como se firmaron (se vuelven a verificar al cargarlos).
  BlobColumn get gz => blob()();

  /// active | staged | previous
  TextColumn get status => text()();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id, version};
}

@DataClassName('ContentDownloadRow')
class ContentDownloads extends Table {
  TextColumn get fileId => text()();
  TextColumn get version => text()();
  TextColumn get url => text()();
  TextColumn get sha256 => text()();
  TextColumn get signature => text()();
  IntColumn get size => integer()();
  TextColumn get minAppVersion => text().withDefault(const Constant('1.0.0'))();

  /// Bytes recibidos hasta ahora (descarga reanudable con `Range`).
  BlobColumn get partial => blob()();
  IntColumn get failures => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {fileId, version};
}

@DataClassName('AttemptRow')
class Attempts extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get json => text()();
  DateTimeColumn get deviceTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SessionRow')
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  DateTimeColumn get startedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('OutboxRow')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  /// attempt | session | event | inquiry
  TextColumn get kind => text()();
  TextColumn get refId => text()();
  TextColumn get payload => text()();
  IntColumn get tries => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {kind, refId},
      ];
}

@DataClassName('InquiryRow')
class Inquiries extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();

  /// pending | received | in_review | answered
  TextColumn get status => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get reply => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('KeyValueRow')
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [ContentPackages, ContentDownloads, Attempts, Sessions, Outbox, Inquiries, KeyValues])
class VtmDatabase extends _$VtmDatabase {
  VtmDatabase([QueryExecutor? executor]) : super(executor ?? _abrir());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _abrir() => driftDatabase(
        name: 'volutrainmed',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );
}
