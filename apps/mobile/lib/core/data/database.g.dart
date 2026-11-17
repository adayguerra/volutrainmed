// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ContentPackagesTable extends ContentPackages
    with TableInfo<$ContentPackagesTable, ContentPackageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentPackagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minAppVersionMeta = const VerificationMeta(
    'minAppVersion',
  );
  @override
  late final GeneratedColumn<String> minAppVersion = GeneratedColumn<String>(
    'min_app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
  );
  static const VerificationMeta _gzMeta = const VerificationMeta('gz');
  @override
  late final GeneratedColumn<Uint8List> gz = GeneratedColumn<Uint8List>(
    'gz',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    version,
    sha256,
    signature,
    minAppVersion,
    gz,
    status,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_packages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentPackageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('min_app_version')) {
      context.handle(
        _minAppVersionMeta,
        minAppVersion.isAcceptableOrUnknown(
          data['min_app_version']!,
          _minAppVersionMeta,
        ),
      );
    }
    if (data.containsKey('gz')) {
      context.handle(_gzMeta, gz.isAcceptableOrUnknown(data['gz']!, _gzMeta));
    } else if (isInserting) {
      context.missing(_gzMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, version};
  @override
  ContentPackageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentPackageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      minAppVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}min_app_version'],
      )!,
      gz: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}gz'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $ContentPackagesTable createAlias(String alias) {
    return $ContentPackagesTable(attachedDatabase, alias);
  }
}

class ContentPackageRow extends DataClass
    implements Insertable<ContentPackageRow> {
  final String id;
  final String version;
  final String sha256;
  final String signature;
  final String minAppVersion;

  /// Bytes gzip tal como se firmaron (se vuelven a verificar al cargarlos).
  final Uint8List gz;

  /// active | staged | previous
  final String status;
  final DateTime installedAt;
  const ContentPackageRow({
    required this.id,
    required this.version,
    required this.sha256,
    required this.signature,
    required this.minAppVersion,
    required this.gz,
    required this.status,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['sha256'] = Variable<String>(sha256);
    map['signature'] = Variable<String>(signature);
    map['min_app_version'] = Variable<String>(minAppVersion);
    map['gz'] = Variable<Uint8List>(gz);
    map['status'] = Variable<String>(status);
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  ContentPackagesCompanion toCompanion(bool nullToAbsent) {
    return ContentPackagesCompanion(
      id: Value(id),
      version: Value(version),
      sha256: Value(sha256),
      signature: Value(signature),
      minAppVersion: Value(minAppVersion),
      gz: Value(gz),
      status: Value(status),
      installedAt: Value(installedAt),
    );
  }

  factory ContentPackageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentPackageRow(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      sha256: serializer.fromJson<String>(json['sha256']),
      signature: serializer.fromJson<String>(json['signature']),
      minAppVersion: serializer.fromJson<String>(json['minAppVersion']),
      gz: serializer.fromJson<Uint8List>(json['gz']),
      status: serializer.fromJson<String>(json['status']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'sha256': serializer.toJson<String>(sha256),
      'signature': serializer.toJson<String>(signature),
      'minAppVersion': serializer.toJson<String>(minAppVersion),
      'gz': serializer.toJson<Uint8List>(gz),
      'status': serializer.toJson<String>(status),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  ContentPackageRow copyWith({
    String? id,
    String? version,
    String? sha256,
    String? signature,
    String? minAppVersion,
    Uint8List? gz,
    String? status,
    DateTime? installedAt,
  }) => ContentPackageRow(
    id: id ?? this.id,
    version: version ?? this.version,
    sha256: sha256 ?? this.sha256,
    signature: signature ?? this.signature,
    minAppVersion: minAppVersion ?? this.minAppVersion,
    gz: gz ?? this.gz,
    status: status ?? this.status,
    installedAt: installedAt ?? this.installedAt,
  );
  ContentPackageRow copyWithCompanion(ContentPackagesCompanion data) {
    return ContentPackageRow(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      signature: data.signature.present ? data.signature.value : this.signature,
      minAppVersion: data.minAppVersion.present
          ? data.minAppVersion.value
          : this.minAppVersion,
      gz: data.gz.present ? data.gz.value : this.gz,
      status: data.status.present ? data.status.value : this.status,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentPackageRow(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('signature: $signature, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('gz: $gz, ')
          ..write('status: $status, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    sha256,
    signature,
    minAppVersion,
    $driftBlobEquality.hash(gz),
    status,
    installedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentPackageRow &&
          other.id == this.id &&
          other.version == this.version &&
          other.sha256 == this.sha256 &&
          other.signature == this.signature &&
          other.minAppVersion == this.minAppVersion &&
          $driftBlobEquality.equals(other.gz, this.gz) &&
          other.status == this.status &&
          other.installedAt == this.installedAt);
}

class ContentPackagesCompanion extends UpdateCompanion<ContentPackageRow> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> sha256;
  final Value<String> signature;
  final Value<String> minAppVersion;
  final Value<Uint8List> gz;
  final Value<String> status;
  final Value<DateTime> installedAt;
  final Value<int> rowid;
  const ContentPackagesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.signature = const Value.absent(),
    this.minAppVersion = const Value.absent(),
    this.gz = const Value.absent(),
    this.status = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentPackagesCompanion.insert({
    required String id,
    required String version,
    required String sha256,
    required String signature,
    this.minAppVersion = const Value.absent(),
    required Uint8List gz,
    required String status,
    required DateTime installedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       version = Value(version),
       sha256 = Value(sha256),
       signature = Value(signature),
       gz = Value(gz),
       status = Value(status),
       installedAt = Value(installedAt);
  static Insertable<ContentPackageRow> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? sha256,
    Expression<String>? signature,
    Expression<String>? minAppVersion,
    Expression<Uint8List>? gz,
    Expression<String>? status,
    Expression<DateTime>? installedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (sha256 != null) 'sha256': sha256,
      if (signature != null) 'signature': signature,
      if (minAppVersion != null) 'min_app_version': minAppVersion,
      if (gz != null) 'gz': gz,
      if (status != null) 'status': status,
      if (installedAt != null) 'installed_at': installedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentPackagesCompanion copyWith({
    Value<String>? id,
    Value<String>? version,
    Value<String>? sha256,
    Value<String>? signature,
    Value<String>? minAppVersion,
    Value<Uint8List>? gz,
    Value<String>? status,
    Value<DateTime>? installedAt,
    Value<int>? rowid,
  }) {
    return ContentPackagesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      sha256: sha256 ?? this.sha256,
      signature: signature ?? this.signature,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      gz: gz ?? this.gz,
      status: status ?? this.status,
      installedAt: installedAt ?? this.installedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (minAppVersion.present) {
      map['min_app_version'] = Variable<String>(minAppVersion.value);
    }
    if (gz.present) {
      map['gz'] = Variable<Uint8List>(gz.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentPackagesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('sha256: $sha256, ')
          ..write('signature: $signature, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('gz: $gz, ')
          ..write('status: $status, ')
          ..write('installedAt: $installedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentDownloadsTable extends ContentDownloads
    with TableInfo<$ContentDownloadsTable, ContentDownloadRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentDownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minAppVersionMeta = const VerificationMeta(
    'minAppVersion',
  );
  @override
  late final GeneratedColumn<String> minAppVersion = GeneratedColumn<String>(
    'min_app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('1.0.0'),
  );
  static const VerificationMeta _partialMeta = const VerificationMeta(
    'partial',
  );
  @override
  late final GeneratedColumn<Uint8List> partial = GeneratedColumn<Uint8List>(
    'partial',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failuresMeta = const VerificationMeta(
    'failures',
  );
  @override
  late final GeneratedColumn<int> failures = GeneratedColumn<int>(
    'failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    version,
    url,
    sha256,
    signature,
    size,
    minAppVersion,
    partial,
    failures,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentDownloadRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('min_app_version')) {
      context.handle(
        _minAppVersionMeta,
        minAppVersion.isAcceptableOrUnknown(
          data['min_app_version']!,
          _minAppVersionMeta,
        ),
      );
    }
    if (data.containsKey('partial')) {
      context.handle(
        _partialMeta,
        partial.isAcceptableOrUnknown(data['partial']!, _partialMeta),
      );
    } else if (isInserting) {
      context.missing(_partialMeta);
    }
    if (data.containsKey('failures')) {
      context.handle(
        _failuresMeta,
        failures.isAcceptableOrUnknown(data['failures']!, _failuresMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId, version};
  @override
  ContentDownloadRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentDownloadRow(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      minAppVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}min_app_version'],
      )!,
      partial: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}partial'],
      )!,
      failures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failures'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ContentDownloadsTable createAlias(String alias) {
    return $ContentDownloadsTable(attachedDatabase, alias);
  }
}

class ContentDownloadRow extends DataClass
    implements Insertable<ContentDownloadRow> {
  final String fileId;
  final String version;
  final String url;
  final String sha256;
  final String signature;
  final int size;
  final String minAppVersion;

  /// Bytes recibidos hasta ahora (descarga reanudable con `Range`).
  final Uint8List partial;
  final int failures;
  final DateTime updatedAt;
  const ContentDownloadRow({
    required this.fileId,
    required this.version,
    required this.url,
    required this.sha256,
    required this.signature,
    required this.size,
    required this.minAppVersion,
    required this.partial,
    required this.failures,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<String>(fileId);
    map['version'] = Variable<String>(version);
    map['url'] = Variable<String>(url);
    map['sha256'] = Variable<String>(sha256);
    map['signature'] = Variable<String>(signature);
    map['size'] = Variable<int>(size);
    map['min_app_version'] = Variable<String>(minAppVersion);
    map['partial'] = Variable<Uint8List>(partial);
    map['failures'] = Variable<int>(failures);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ContentDownloadsCompanion toCompanion(bool nullToAbsent) {
    return ContentDownloadsCompanion(
      fileId: Value(fileId),
      version: Value(version),
      url: Value(url),
      sha256: Value(sha256),
      signature: Value(signature),
      size: Value(size),
      minAppVersion: Value(minAppVersion),
      partial: Value(partial),
      failures: Value(failures),
      updatedAt: Value(updatedAt),
    );
  }

  factory ContentDownloadRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentDownloadRow(
      fileId: serializer.fromJson<String>(json['fileId']),
      version: serializer.fromJson<String>(json['version']),
      url: serializer.fromJson<String>(json['url']),
      sha256: serializer.fromJson<String>(json['sha256']),
      signature: serializer.fromJson<String>(json['signature']),
      size: serializer.fromJson<int>(json['size']),
      minAppVersion: serializer.fromJson<String>(json['minAppVersion']),
      partial: serializer.fromJson<Uint8List>(json['partial']),
      failures: serializer.fromJson<int>(json['failures']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<String>(fileId),
      'version': serializer.toJson<String>(version),
      'url': serializer.toJson<String>(url),
      'sha256': serializer.toJson<String>(sha256),
      'signature': serializer.toJson<String>(signature),
      'size': serializer.toJson<int>(size),
      'minAppVersion': serializer.toJson<String>(minAppVersion),
      'partial': serializer.toJson<Uint8List>(partial),
      'failures': serializer.toJson<int>(failures),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ContentDownloadRow copyWith({
    String? fileId,
    String? version,
    String? url,
    String? sha256,
    String? signature,
    int? size,
    String? minAppVersion,
    Uint8List? partial,
    int? failures,
    DateTime? updatedAt,
  }) => ContentDownloadRow(
    fileId: fileId ?? this.fileId,
    version: version ?? this.version,
    url: url ?? this.url,
    sha256: sha256 ?? this.sha256,
    signature: signature ?? this.signature,
    size: size ?? this.size,
    minAppVersion: minAppVersion ?? this.minAppVersion,
    partial: partial ?? this.partial,
    failures: failures ?? this.failures,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ContentDownloadRow copyWithCompanion(ContentDownloadsCompanion data) {
    return ContentDownloadRow(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      version: data.version.present ? data.version.value : this.version,
      url: data.url.present ? data.url.value : this.url,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      signature: data.signature.present ? data.signature.value : this.signature,
      size: data.size.present ? data.size.value : this.size,
      minAppVersion: data.minAppVersion.present
          ? data.minAppVersion.value
          : this.minAppVersion,
      partial: data.partial.present ? data.partial.value : this.partial,
      failures: data.failures.present ? data.failures.value : this.failures,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentDownloadRow(')
          ..write('fileId: $fileId, ')
          ..write('version: $version, ')
          ..write('url: $url, ')
          ..write('sha256: $sha256, ')
          ..write('signature: $signature, ')
          ..write('size: $size, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('partial: $partial, ')
          ..write('failures: $failures, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileId,
    version,
    url,
    sha256,
    signature,
    size,
    minAppVersion,
    $driftBlobEquality.hash(partial),
    failures,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentDownloadRow &&
          other.fileId == this.fileId &&
          other.version == this.version &&
          other.url == this.url &&
          other.sha256 == this.sha256 &&
          other.signature == this.signature &&
          other.size == this.size &&
          other.minAppVersion == this.minAppVersion &&
          $driftBlobEquality.equals(other.partial, this.partial) &&
          other.failures == this.failures &&
          other.updatedAt == this.updatedAt);
}

class ContentDownloadsCompanion extends UpdateCompanion<ContentDownloadRow> {
  final Value<String> fileId;
  final Value<String> version;
  final Value<String> url;
  final Value<String> sha256;
  final Value<String> signature;
  final Value<int> size;
  final Value<String> minAppVersion;
  final Value<Uint8List> partial;
  final Value<int> failures;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ContentDownloadsCompanion({
    this.fileId = const Value.absent(),
    this.version = const Value.absent(),
    this.url = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.signature = const Value.absent(),
    this.size = const Value.absent(),
    this.minAppVersion = const Value.absent(),
    this.partial = const Value.absent(),
    this.failures = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentDownloadsCompanion.insert({
    required String fileId,
    required String version,
    required String url,
    required String sha256,
    required String signature,
    required int size,
    this.minAppVersion = const Value.absent(),
    required Uint8List partial,
    this.failures = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : fileId = Value(fileId),
       version = Value(version),
       url = Value(url),
       sha256 = Value(sha256),
       signature = Value(signature),
       size = Value(size),
       partial = Value(partial),
       updatedAt = Value(updatedAt);
  static Insertable<ContentDownloadRow> custom({
    Expression<String>? fileId,
    Expression<String>? version,
    Expression<String>? url,
    Expression<String>? sha256,
    Expression<String>? signature,
    Expression<int>? size,
    Expression<String>? minAppVersion,
    Expression<Uint8List>? partial,
    Expression<int>? failures,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (version != null) 'version': version,
      if (url != null) 'url': url,
      if (sha256 != null) 'sha256': sha256,
      if (signature != null) 'signature': signature,
      if (size != null) 'size': size,
      if (minAppVersion != null) 'min_app_version': minAppVersion,
      if (partial != null) 'partial': partial,
      if (failures != null) 'failures': failures,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentDownloadsCompanion copyWith({
    Value<String>? fileId,
    Value<String>? version,
    Value<String>? url,
    Value<String>? sha256,
    Value<String>? signature,
    Value<int>? size,
    Value<String>? minAppVersion,
    Value<Uint8List>? partial,
    Value<int>? failures,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ContentDownloadsCompanion(
      fileId: fileId ?? this.fileId,
      version: version ?? this.version,
      url: url ?? this.url,
      sha256: sha256 ?? this.sha256,
      signature: signature ?? this.signature,
      size: size ?? this.size,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      partial: partial ?? this.partial,
      failures: failures ?? this.failures,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (minAppVersion.present) {
      map['min_app_version'] = Variable<String>(minAppVersion.value);
    }
    if (partial.present) {
      map['partial'] = Variable<Uint8List>(partial.value);
    }
    if (failures.present) {
      map['failures'] = Variable<int>(failures.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentDownloadsCompanion(')
          ..write('fileId: $fileId, ')
          ..write('version: $version, ')
          ..write('url: $url, ')
          ..write('sha256: $sha256, ')
          ..write('signature: $signature, ')
          ..write('size: $size, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('partial: $partial, ')
          ..write('failures: $failures, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts
    with TableInfo<$AttemptsTable, AttemptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTimeMeta = const VerificationMeta(
    'deviceTime',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTime = GeneratedColumn<DateTime>(
    'device_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, json, deviceTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttemptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('device_time')) {
      context.handle(
        _deviceTimeMeta,
        deviceTime.isAcceptableOrUnknown(data['device_time']!, _deviceTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttemptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttemptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      deviceTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_time'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class AttemptRow extends DataClass implements Insertable<AttemptRow> {
  final String id;
  final String sessionId;
  final String json;
  final DateTime deviceTime;
  const AttemptRow({
    required this.id,
    required this.sessionId,
    required this.json,
    required this.deviceTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['json'] = Variable<String>(json);
    map['device_time'] = Variable<DateTime>(deviceTime);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      json: Value(json),
      deviceTime: Value(deviceTime),
    );
  }

  factory AttemptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttemptRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      json: serializer.fromJson<String>(json['json']),
      deviceTime: serializer.fromJson<DateTime>(json['deviceTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'json': serializer.toJson<String>(json),
      'deviceTime': serializer.toJson<DateTime>(deviceTime),
    };
  }

  AttemptRow copyWith({
    String? id,
    String? sessionId,
    String? json,
    DateTime? deviceTime,
  }) => AttemptRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    json: json ?? this.json,
    deviceTime: deviceTime ?? this.deviceTime,
  );
  AttemptRow copyWithCompanion(AttemptsCompanion data) {
    return AttemptRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      json: data.json.present ? data.json.value : this.json,
      deviceTime: data.deviceTime.present
          ? data.deviceTime.value
          : this.deviceTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttemptRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('json: $json, ')
          ..write('deviceTime: $deviceTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, json, deviceTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttemptRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.json == this.json &&
          other.deviceTime == this.deviceTime);
}

class AttemptsCompanion extends UpdateCompanion<AttemptRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> json;
  final Value<DateTime> deviceTime;
  final Value<int> rowid;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.json = const Value.absent(),
    this.deviceTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttemptsCompanion.insert({
    required String id,
    required String sessionId,
    required String json,
    required DateTime deviceTime,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       json = Value(json),
       deviceTime = Value(deviceTime);
  static Insertable<AttemptRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? json,
    Expression<DateTime>? deviceTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (json != null) 'json': json,
      if (deviceTime != null) 'device_time': deviceTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? json,
    Value<DateTime>? deviceTime,
    Value<int>? rowid,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      json: json ?? this.json,
      deviceTime: deviceTime ?? this.deviceTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (deviceTime.present) {
      map['device_time'] = Variable<DateTime>(deviceTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('json: $json, ')
          ..write('deviceTime: $deviceTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, json, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String json;
  final DateTime startedAt;
  const SessionRow({
    required this.id,
    required this.json,
    required this.startedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      json: Value(json),
      startedAt: Value(startedAt),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  SessionRow copyWith({String? id, String? json, DateTime? startedAt}) =>
      SessionRow(
        id: id ?? this.id,
        json: json ?? this.json,
        startedAt: startedAt ?? this.startedAt,
      );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.json == this.json &&
          other.startedAt == this.startedAt);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> json;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String json,
    required DateTime startedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<DateTime>? startedAt,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<String> refId = GeneratedColumn<String>(
    'ref_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triesMeta = const VerificationMeta('tries');
  @override
  late final GeneratedColumn<int> tries = GeneratedColumn<int>(
    'tries',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    kind,
    refId,
    payload,
    tries,
    nextAttemptAt,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
        _refIdMeta,
        refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta),
      );
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('tries')) {
      context.handle(
        _triesMeta,
        tries.isAcceptableOrUnknown(data['tries']!, _triesMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {kind, refId},
  ];
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      refId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      tries: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tries'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int seq;

  /// attempt | session | event | inquiry
  final String kind;
  final String refId;
  final String payload;
  final int tries;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final DateTime createdAt;
  const OutboxRow({
    required this.seq,
    required this.kind,
    required this.refId,
    required this.payload,
    required this.tries,
    this.nextAttemptAt,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    map['ref_id'] = Variable<String>(refId);
    map['payload'] = Variable<String>(payload);
    map['tries'] = Variable<int>(tries);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      kind: Value(kind),
      refId: Value(refId),
      payload: Value(payload),
      tries: Value(tries),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      refId: serializer.fromJson<String>(json['refId']),
      payload: serializer.fromJson<String>(json['payload']),
      tries: serializer.fromJson<int>(json['tries']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'refId': serializer.toJson<String>(refId),
      'payload': serializer.toJson<String>(payload),
      'tries': serializer.toJson<int>(tries),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxRow copyWith({
    int? seq,
    String? kind,
    String? refId,
    String? payload,
    int? tries,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxRow(
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    refId: refId ?? this.refId,
    payload: payload ?? this.payload,
    tries: tries ?? this.tries,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      refId: data.refId.present ? data.refId.value : this.refId,
      payload: data.payload.present ? data.payload.value : this.payload,
      tries: data.tries.present ? data.tries.value : this.tries,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('payload: $payload, ')
          ..write('tries: $tries, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    kind,
    refId,
    payload,
    tries,
    nextAttemptAt,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.refId == this.refId &&
          other.payload == this.payload &&
          other.tries == this.tries &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> seq;
  final Value<String> kind;
  final Value<String> refId;
  final Value<String> payload;
  final Value<int> tries;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.refId = const Value.absent(),
    this.payload = const Value.absent(),
    this.tries = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String kind,
    required String refId,
    required String payload,
    this.tries = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
  }) : kind = Value(kind),
       refId = Value(refId),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<String>? refId,
    Expression<String>? payload,
    Expression<int>? tries,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (refId != null) 'ref_id': refId,
      if (payload != null) 'payload': payload,
      if (tries != null) 'tries': tries,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? kind,
    Value<String>? refId,
    Value<String>? payload,
    Value<int>? tries,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      refId: refId ?? this.refId,
      payload: payload ?? this.payload,
      tries: tries ?? this.tries,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<String>(refId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (tries.present) {
      map['tries'] = Variable<int>(tries.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('refId: $refId, ')
          ..write('payload: $payload, ')
          ..write('tries: $tries, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $InquiriesTable extends Inquiries
    with TableInfo<$InquiriesTable, InquiryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InquiriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta(
    'reference',
  );
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replyMeta = const VerificationMeta('reply');
  @override
  late final GeneratedColumn<String> reply = GeneratedColumn<String>(
    'reply',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    json,
    status,
    reference,
    reply,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inquiries';
  @override
  VerificationContext validateIntegrity(
    Insertable<InquiryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('reference')) {
      context.handle(
        _referenceMeta,
        reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta),
      );
    }
    if (data.containsKey('reply')) {
      context.handle(
        _replyMeta,
        reply.isAcceptableOrUnknown(data['reply']!, _replyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InquiryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InquiryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      reference: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference'],
      ),
      reply: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reply'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $InquiriesTable createAlias(String alias) {
    return $InquiriesTable(attachedDatabase, alias);
  }
}

class InquiryRow extends DataClass implements Insertable<InquiryRow> {
  final String id;
  final String json;

  /// pending | received | in_review | answered
  final String status;
  final String? reference;
  final String? reply;
  final DateTime createdAt;
  const InquiryRow({
    required this.id,
    required this.json,
    required this.status,
    this.reference,
    this.reply,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reference != null) {
      map['reference'] = Variable<String>(reference);
    }
    if (!nullToAbsent || reply != null) {
      map['reply'] = Variable<String>(reply);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InquiriesCompanion toCompanion(bool nullToAbsent) {
    return InquiriesCompanion(
      id: Value(id),
      json: Value(json),
      status: Value(status),
      reference: reference == null && nullToAbsent
          ? const Value.absent()
          : Value(reference),
      reply: reply == null && nullToAbsent
          ? const Value.absent()
          : Value(reply),
      createdAt: Value(createdAt),
    );
  }

  factory InquiryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InquiryRow(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      status: serializer.fromJson<String>(json['status']),
      reference: serializer.fromJson<String?>(json['reference']),
      reply: serializer.fromJson<String?>(json['reply']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'status': serializer.toJson<String>(status),
      'reference': serializer.toJson<String?>(reference),
      'reply': serializer.toJson<String?>(reply),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InquiryRow copyWith({
    String? id,
    String? json,
    String? status,
    Value<String?> reference = const Value.absent(),
    Value<String?> reply = const Value.absent(),
    DateTime? createdAt,
  }) => InquiryRow(
    id: id ?? this.id,
    json: json ?? this.json,
    status: status ?? this.status,
    reference: reference.present ? reference.value : this.reference,
    reply: reply.present ? reply.value : this.reply,
    createdAt: createdAt ?? this.createdAt,
  );
  InquiryRow copyWithCompanion(InquiriesCompanion data) {
    return InquiryRow(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      status: data.status.present ? data.status.value : this.status,
      reference: data.reference.present ? data.reference.value : this.reference,
      reply: data.reply.present ? data.reply.value : this.reply,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InquiryRow(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('status: $status, ')
          ..write('reference: $reference, ')
          ..write('reply: $reply, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, json, status, reference, reply, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InquiryRow &&
          other.id == this.id &&
          other.json == this.json &&
          other.status == this.status &&
          other.reference == this.reference &&
          other.reply == this.reply &&
          other.createdAt == this.createdAt);
}

class InquiriesCompanion extends UpdateCompanion<InquiryRow> {
  final Value<String> id;
  final Value<String> json;
  final Value<String> status;
  final Value<String?> reference;
  final Value<String?> reply;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InquiriesCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.status = const Value.absent(),
    this.reference = const Value.absent(),
    this.reply = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InquiriesCompanion.insert({
    required String id,
    required String json,
    required String status,
    this.reference = const Value.absent(),
    this.reply = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<InquiryRow> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<String>? status,
    Expression<String>? reference,
    Expression<String>? reply,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (status != null) 'status': status,
      if (reference != null) 'reference': reference,
      if (reply != null) 'reply': reply,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InquiriesCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<String>? status,
    Value<String?>? reference,
    Value<String?>? reply,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return InquiriesCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      status: status ?? this.status,
      reference: reference ?? this.reference,
      reply: reply ?? this.reply,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (reply.present) {
      map['reply'] = Variable<String>(reply.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InquiriesCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('status: $status, ')
          ..write('reference: $reference, ')
          ..write('reply: $reply, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValueRow extends DataClass implements Insertable<KeyValueRow> {
  final String key;
  final String value;
  const KeyValueRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValueRow copyWith({String? key, String? value}) =>
      KeyValueRow(key: key ?? this.key, value: value ?? this.value);
  KeyValueRow copyWithCompanion(KeyValuesCompanion data) {
    return KeyValueRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueRow &&
          other.key == this.key &&
          other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValueRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValueRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$VtmDatabase extends GeneratedDatabase {
  _$VtmDatabase(QueryExecutor e) : super(e);
  $VtmDatabaseManager get managers => $VtmDatabaseManager(this);
  late final $ContentPackagesTable contentPackages = $ContentPackagesTable(
    this,
  );
  late final $ContentDownloadsTable contentDownloads = $ContentDownloadsTable(
    this,
  );
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $InquiriesTable inquiries = $InquiriesTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contentPackages,
    contentDownloads,
    attempts,
    sessions,
    outbox,
    inquiries,
    keyValues,
  ];
}

typedef $$ContentPackagesTableCreateCompanionBuilder =
    ContentPackagesCompanion Function({
      required String id,
      required String version,
      required String sha256,
      required String signature,
      Value<String> minAppVersion,
      required Uint8List gz,
      required String status,
      required DateTime installedAt,
      Value<int> rowid,
    });
typedef $$ContentPackagesTableUpdateCompanionBuilder =
    ContentPackagesCompanion Function({
      Value<String> id,
      Value<String> version,
      Value<String> sha256,
      Value<String> signature,
      Value<String> minAppVersion,
      Value<Uint8List> gz,
      Value<String> status,
      Value<DateTime> installedAt,
      Value<int> rowid,
    });

class $$ContentPackagesTableFilterComposer
    extends Composer<_$VtmDatabase, $ContentPackagesTable> {
  $$ContentPackagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get gz => $composableBuilder(
    column: $table.gz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentPackagesTableOrderingComposer
    extends Composer<_$VtmDatabase, $ContentPackagesTable> {
  $$ContentPackagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get gz => $composableBuilder(
    column: $table.gz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentPackagesTableAnnotationComposer
    extends Composer<_$VtmDatabase, $ContentPackagesTable> {
  $$ContentPackagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get gz =>
      $composableBuilder(column: $table.gz, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$ContentPackagesTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $ContentPackagesTable,
          ContentPackageRow,
          $$ContentPackagesTableFilterComposer,
          $$ContentPackagesTableOrderingComposer,
          $$ContentPackagesTableAnnotationComposer,
          $$ContentPackagesTableCreateCompanionBuilder,
          $$ContentPackagesTableUpdateCompanionBuilder,
          (
            ContentPackageRow,
            BaseReferences<
              _$VtmDatabase,
              $ContentPackagesTable,
              ContentPackageRow
            >,
          ),
          ContentPackageRow,
          PrefetchHooks Function()
        > {
  $$ContentPackagesTableTableManager(
    _$VtmDatabase db,
    $ContentPackagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentPackagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentPackagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentPackagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
                Value<Uint8List> gz = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentPackagesCompanion(
                id: id,
                version: version,
                sha256: sha256,
                signature: signature,
                minAppVersion: minAppVersion,
                gz: gz,
                status: status,
                installedAt: installedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String version,
                required String sha256,
                required String signature,
                Value<String> minAppVersion = const Value.absent(),
                required Uint8List gz,
                required String status,
                required DateTime installedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentPackagesCompanion.insert(
                id: id,
                version: version,
                sha256: sha256,
                signature: signature,
                minAppVersion: minAppVersion,
                gz: gz,
                status: status,
                installedAt: installedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentPackagesTable, ContentPackageRow>(table),
                  BaseReferences<
                    _$VtmDatabase,
                    $ContentPackagesTable,
                    ContentPackageRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentPackagesTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $ContentPackagesTable,
      ContentPackageRow,
      $$ContentPackagesTableFilterComposer,
      $$ContentPackagesTableOrderingComposer,
      $$ContentPackagesTableAnnotationComposer,
      $$ContentPackagesTableCreateCompanionBuilder,
      $$ContentPackagesTableUpdateCompanionBuilder,
      (
        ContentPackageRow,
        BaseReferences<_$VtmDatabase, $ContentPackagesTable, ContentPackageRow>,
      ),
      ContentPackageRow,
      PrefetchHooks Function()
    >;
typedef $$ContentDownloadsTableCreateCompanionBuilder =
    ContentDownloadsCompanion Function({
      required String fileId,
      required String version,
      required String url,
      required String sha256,
      required String signature,
      required int size,
      Value<String> minAppVersion,
      required Uint8List partial,
      Value<int> failures,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ContentDownloadsTableUpdateCompanionBuilder =
    ContentDownloadsCompanion Function({
      Value<String> fileId,
      Value<String> version,
      Value<String> url,
      Value<String> sha256,
      Value<String> signature,
      Value<int> size,
      Value<String> minAppVersion,
      Value<Uint8List> partial,
      Value<int> failures,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ContentDownloadsTableFilterComposer
    extends Composer<_$VtmDatabase, $ContentDownloadsTable> {
  $$ContentDownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get partial => $composableBuilder(
    column: $table.partial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentDownloadsTableOrderingComposer
    extends Composer<_$VtmDatabase, $ContentDownloadsTable> {
  $$ContentDownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get partial => $composableBuilder(
    column: $table.partial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentDownloadsTableAnnotationComposer
    extends Composer<_$VtmDatabase, $ContentDownloadsTable> {
  $$ContentDownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get partial =>
      $composableBuilder(column: $table.partial, builder: (column) => column);

  GeneratedColumn<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ContentDownloadsTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $ContentDownloadsTable,
          ContentDownloadRow,
          $$ContentDownloadsTableFilterComposer,
          $$ContentDownloadsTableOrderingComposer,
          $$ContentDownloadsTableAnnotationComposer,
          $$ContentDownloadsTableCreateCompanionBuilder,
          $$ContentDownloadsTableUpdateCompanionBuilder,
          (
            ContentDownloadRow,
            BaseReferences<
              _$VtmDatabase,
              $ContentDownloadsTable,
              ContentDownloadRow
            >,
          ),
          ContentDownloadRow,
          PrefetchHooks Function()
        > {
  $$ContentDownloadsTableTableManager(
    _$VtmDatabase db,
    $ContentDownloadsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentDownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentDownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentDownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fileId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
                Value<Uint8List> partial = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentDownloadsCompanion(
                fileId: fileId,
                version: version,
                url: url,
                sha256: sha256,
                signature: signature,
                size: size,
                minAppVersion: minAppVersion,
                partial: partial,
                failures: failures,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileId,
                required String version,
                required String url,
                required String sha256,
                required String signature,
                required int size,
                Value<String> minAppVersion = const Value.absent(),
                required Uint8List partial,
                Value<int> failures = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContentDownloadsCompanion.insert(
                fileId: fileId,
                version: version,
                url: url,
                sha256: sha256,
                signature: signature,
                size: size,
                minAppVersion: minAppVersion,
                partial: partial,
                failures: failures,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentDownloadsTable, ContentDownloadRow>(
                    table,
                  ),
                  BaseReferences<
                    _$VtmDatabase,
                    $ContentDownloadsTable,
                    ContentDownloadRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentDownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $ContentDownloadsTable,
      ContentDownloadRow,
      $$ContentDownloadsTableFilterComposer,
      $$ContentDownloadsTableOrderingComposer,
      $$ContentDownloadsTableAnnotationComposer,
      $$ContentDownloadsTableCreateCompanionBuilder,
      $$ContentDownloadsTableUpdateCompanionBuilder,
      (
        ContentDownloadRow,
        BaseReferences<
          _$VtmDatabase,
          $ContentDownloadsTable,
          ContentDownloadRow
        >,
      ),
      ContentDownloadRow,
      PrefetchHooks Function()
    >;
typedef $$AttemptsTableCreateCompanionBuilder = AttemptsCompanion Function({
  required String id,
  required String sessionId,
  required String json,
  required DateTime deviceTime,
  Value<int> rowid,
});
typedef $$AttemptsTableUpdateCompanionBuilder = AttemptsCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> json,
  Value<DateTime> deviceTime,
  Value<int> rowid,
});

class $$AttemptsTableFilterComposer
    extends Composer<_$VtmDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTime => $composableBuilder(
    column: $table.deviceTime,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttemptsTableOrderingComposer
    extends Composer<_$VtmDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTime => $composableBuilder(
    column: $table.deviceTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttemptsTableAnnotationComposer
    extends Composer<_$VtmDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTime => $composableBuilder(
    column: $table.deviceTime,
    builder: (column) => column,
  );
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $AttemptsTable,
          AttemptRow,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (
            AttemptRow,
            BaseReferences<_$VtmDatabase, $AttemptsTable, AttemptRow>,
          ),
          AttemptRow,
          PrefetchHooks Function()
        > {
  $$AttemptsTableTableManager(_$VtmDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> deviceTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                sessionId: sessionId,
                json: json,
                deviceTime: deviceTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String json,
                required DateTime deviceTime,
                Value<int> rowid = const Value.absent(),
              }) => AttemptsCompanion.insert(
                id: id,
                sessionId: sessionId,
                json: json,
                deviceTime: deviceTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttemptsTable, AttemptRow>(table),
                  BaseReferences<_$VtmDatabase, $AttemptsTable, AttemptRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $AttemptsTable,
      AttemptRow,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (AttemptRow, BaseReferences<_$VtmDatabase, $AttemptsTable, AttemptRow>),
      AttemptRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String json,
  required DateTime startedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> json,
  Value<DateTime> startedAt,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$VtmDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$VtmDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$VtmDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$VtmDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$VtmDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                json: json,
                startedAt: startedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required DateTime startedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                json: json,
                startedAt: startedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$VtmDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (SessionRow, BaseReferences<_$VtmDatabase, $SessionsTable, SessionRow>),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String kind,
  required String refId,
  required String payload,
  Value<int> tries,
  Value<DateTime?> nextAttemptAt,
  Value<String?> lastError,
  required DateTime createdAt,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> kind,
  Value<String> refId,
  Value<String> payload,
  Value<int> tries,
  Value<DateTime?> nextAttemptAt,
  Value<String?> lastError,
  Value<DateTime> createdAt,
});

class $$OutboxTableFilterComposer
    extends Composer<_$VtmDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tries => $composableBuilder(
    column: $table.tries,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$VtmDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refId => $composableBuilder(
    column: $table.refId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tries => $composableBuilder(
    column: $table.tries,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$VtmDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get tries =>
      $composableBuilder(column: $table.tries, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$VtmDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$VtmDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> refId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> tries = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                kind: kind,
                refId: refId,
                payload: payload,
                tries: tries,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String kind,
                required String refId,
                required String payload,
                Value<int> tries = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
              }) => OutboxCompanion.insert(
                seq: seq,
                kind: kind,
                refId: refId,
                payload: payload,
                tries: tries,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$VtmDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$VtmDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$InquiriesTableCreateCompanionBuilder = InquiriesCompanion Function({
  required String id,
  required String json,
  required String status,
  Value<String?> reference,
  Value<String?> reply,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$InquiriesTableUpdateCompanionBuilder = InquiriesCompanion Function({
  Value<String> id,
  Value<String> json,
  Value<String> status,
  Value<String?> reference,
  Value<String?> reply,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$InquiriesTableFilterComposer
    extends Composer<_$VtmDatabase, $InquiriesTable> {
  $$InquiriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InquiriesTableOrderingComposer
    extends Composer<_$VtmDatabase, $InquiriesTable> {
  $$InquiriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reference => $composableBuilder(
    column: $table.reference,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reply => $composableBuilder(
    column: $table.reply,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InquiriesTableAnnotationComposer
    extends Composer<_$VtmDatabase, $InquiriesTable> {
  $$InquiriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get reply =>
      $composableBuilder(column: $table.reply, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$InquiriesTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $InquiriesTable,
          InquiryRow,
          $$InquiriesTableFilterComposer,
          $$InquiriesTableOrderingComposer,
          $$InquiriesTableAnnotationComposer,
          $$InquiriesTableCreateCompanionBuilder,
          $$InquiriesTableUpdateCompanionBuilder,
          (
            InquiryRow,
            BaseReferences<_$VtmDatabase, $InquiriesTable, InquiryRow>,
          ),
          InquiryRow,
          PrefetchHooks Function()
        > {
  $$InquiriesTableTableManager(_$VtmDatabase db, $InquiriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InquiriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InquiriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InquiriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> reference = const Value.absent(),
                Value<String?> reply = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InquiriesCompanion(
                id: id,
                json: json,
                status: status,
                reference: reference,
                reply: reply,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required String status,
                Value<String?> reference = const Value.absent(),
                Value<String?> reply = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => InquiriesCompanion.insert(
                id: id,
                json: json,
                status: status,
                reference: reference,
                reply: reply,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InquiriesTable, InquiryRow>(table),
                  BaseReferences<_$VtmDatabase, $InquiriesTable, InquiryRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InquiriesTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $InquiriesTable,
      InquiryRow,
      $$InquiriesTableFilterComposer,
      $$InquiriesTableOrderingComposer,
      $$InquiriesTableAnnotationComposer,
      $$InquiriesTableCreateCompanionBuilder,
      $$InquiriesTableUpdateCompanionBuilder,
      (InquiryRow, BaseReferences<_$VtmDatabase, $InquiriesTable, InquiryRow>),
      InquiryRow,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$VtmDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$VtmDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$VtmDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$VtmDatabase,
          $KeyValuesTable,
          KeyValueRow,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (
            KeyValueRow,
            BaseReferences<_$VtmDatabase, $KeyValuesTable, KeyValueRow>,
          ),
          KeyValueRow,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$VtmDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValueRow>(table),
                  BaseReferences<_$VtmDatabase, $KeyValuesTable, KeyValueRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$VtmDatabase,
      $KeyValuesTable,
      KeyValueRow,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (
        KeyValueRow,
        BaseReferences<_$VtmDatabase, $KeyValuesTable, KeyValueRow>,
      ),
      KeyValueRow,
      PrefetchHooks Function()
    >;

class $VtmDatabaseManager {
  final _$VtmDatabase _db;
  $VtmDatabaseManager(this._db);
  $$ContentPackagesTableTableManager get contentPackages =>
      $$ContentPackagesTableTableManager(_db, _db.contentPackages);
  $$ContentDownloadsTableTableManager get contentDownloads =>
      $$ContentDownloadsTableTableManager(_db, _db.contentDownloads);
  $$AttemptsTableTableManager get attempts =>
      $$AttemptsTableTableManager(_db, _db.attempts);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$InquiriesTableTableManager get inquiries =>
      $$InquiriesTableTableManager(_db, _db.inquiries);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
