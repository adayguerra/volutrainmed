import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/data/almacenes.dart';
import 'package:volutrainmed/core/data/database.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';

/// Pruebas de la capa de datos sobre SQLite en memoria (Drift). Se usan
/// pruebas `test()` normales: Drift deja temporizadores que no casan con
/// `testWidgets`.

Attempt intento(String id, {String sesion = 's1', DateTime? t}) => Attempt(
      id: id,
      sessionId: sesion,
      deviceId: 'd1',
      mode: SessionMode.lesson,
      lessonId: 'u-f-1-l1',
      templateId: 'tpl-f-mg-ug',
      variantId: 'v-$id',
      skillId: 'H1',
      exerciseTypeId: 'T1',
      level: 1,
      answerValue: '1000',
      answerUnit: 'µg',
      verdict: Verdict.correct,
      responseMs: 12000,
      targetMs: 15000,
      points: 10,
      contentVersion: '2026.11.0',
      deviceTime: t ?? DateTime.utc(2026, 11, 17, 10),
    );

SessionRecord sesion(String id) => SessionRecord(
      id: id,
      deviceId: 'd1',
      mode: SessionMode.lesson,
      lessonId: 'u-f-1-l1',
      startedAt: DateTime.utc(2026, 11, 17, 10),
      endedAt: DateTime.utc(2026, 11, 17, 10, 5),
      completed: true,
      practiceMs: 300000,
      inputMode: InputMode.touch,
      contentVersion: '2026.11.0',
    );

PaqueteGuardado paquete(String clave, String id, String version, {String status = 'active'}) => PaqueteGuardado(
      clave: clave,
      id: id,
      version: version,
      sha256: 'sha-$version',
      signature: 'firma',
      minAppVersion: '1.0.0',
      gz: Uint8List.fromList([1, 2, 3]),
      status: status,
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late VtmDatabase db;

  setUp(() => db = VtmDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Contenido', () {
    test('el paquete del servidor sustituye al incluido aunque cambie el id firmado', () async {
      final c = AlmacenContenidoDrift(db);
      await c.instalarActivo(paquete('it-fundamentos', 'it-fundamentos', '2026.11.0'));
      await c.guardarPreparado(paquete('it-fundamentos', '2026.11.1:it-fundamentos', '2026.11.1'));

      // Hasta activar, la versión en uso sigue siendo la anterior.
      expect((await c.paquetes(status: 'active')).single.version, '2026.11.0');
      expect((await c.paquetes(status: 'staged')).single.id, '2026.11.1:it-fundamentos');

      final cambiadas = await c.activarPreparados();
      expect(cambiadas, ['it-fundamentos']);
      final activos = await c.paquetes(status: 'active');
      expect(activos, hasLength(1));
      expect(activos.single.version, '2026.11.1');
      expect((await c.paquetes(status: 'previous')).single.version, '2026.11.0');
    });

    test('preparar una versión que ya está activa no la degrada', () async {
      final c = AlmacenContenidoDrift(db);
      await c.instalarActivo(paquete('global', 'global', '2026.11.0'));
      await c.guardarPreparado(paquete('global', 'global', '2026.11.0'));
      expect(await c.paquetes(status: 'staged'), isEmpty);
      expect((await c.paquetes(status: 'active')).single.version, '2026.11.0');
    });

    test('solo se conserva una versión anterior por clave', () async {
      final c = AlmacenContenidoDrift(db);
      await c.instalarActivo(paquete('global', 'global', '1'));
      await c.instalarActivo(paquete('global', 'g2', '2'));
      await c.instalarActivo(paquete('global', 'g3', '3'));
      expect((await c.paquetes(status: 'active')).single.version, '3');
      expect((await c.paquetes(status: 'previous')).single.version, '2');
      expect(await c.paquetes(), hasLength(2));
    });

    test('la descarga parcial se guarda y se reanuda', () async {
      final c = AlmacenContenidoDrift(db);
      await c.guardarDescarga(DescargaParcial(
        clave: 'it-anestesia',
        fileId: '2026.11.1:it-anestesia',
        version: '2026.11.1',
        url: '/v1/content/files/x',
        sha256: 'abc',
        signature: 'f',
        size: 100,
        minAppVersion: '1.0.0',
        partial: Uint8List.fromList(List.filled(40, 7)),
        failures: 1,
      ));
      final d = await c.descarga('2026.11.1:it-anestesia', '2026.11.1');
      expect(d!.partial.length, 40);
      expect(d.clave, 'it-anestesia');
      expect(d.failures, 1);
      await c.borrarDescarga('2026.11.1:it-anestesia', '2026.11.1');
      expect(await c.descarga('2026.11.1:it-anestesia', '2026.11.1'), isNull);
    });
  });

  group('Aprendizaje y bandeja de salida', () {
    test('guardar un intento lo encola en la misma transacción', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      await a.guardarSesion(sesion('s1'));
      expect((await a.intentos()).single.id, 'a1');
      expect((await a.sesiones()).single.id, 's1');
      final p = await a.pendientes(ahora: DateTime.now());
      expect(p.map((e) => e.kind), ['attempt', 'session']);
      expect(await a.contarPendientes(), 2);
    });

    test('el intento conserva todos sus campos al releerlo', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      final r = (await a.intentos()).single;
      expect(r.toJson(), intento('a1').toJson());
    });

    test('guardar dos veces el mismo intento no lo duplica', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      await a.guardarIntento(intento('a1'));
      expect(await a.intentos(), hasLength(1));
      expect(await a.contarPendientes(), 1);
    });

    test('fusionar cuenta solo los intentos nuevos y no encola nada', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      await a.marcarEnviados((await a.pendientes(ahora: DateTime.now())).map((e) => e.seq).toList());
      final n = await a.fusionar([intento('a1'), intento('a2'), intento('a3')], [sesion('s9')]);
      expect(n, 2);
      expect(await a.intentos(), hasLength(3));
      expect(await a.sesiones(), hasLength(1));
      expect(await a.contarPendientes(), 0);
    });

    test('un fallo de envío aplaza el reintento y suma un intento', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      final ahora = DateTime(2026, 11, 17, 12);
      final seqs = (await a.pendientes(ahora: ahora)).map((e) => e.seq).toList();
      await a.marcarFallo(seqs, ahora.add(const Duration(minutes: 5)), 'sin conexión');
      expect(await a.pendientes(ahora: ahora), isEmpty);
      final luego = await a.pendientes(ahora: ahora.add(const Duration(minutes: 6)));
      expect(luego.single.tries, 1);
      expect(await a.contarPendientes(), 1);
    });

    test('los pendientes se filtran por tipo y respetan el límite', () async {
      final a = AlmacenAprendizajeDrift(db);
      for (var i = 0; i < 5; i++) {
        await a.guardarIntento(intento('a$i'));
      }
      await a.encolar('event', 'e1', {'id': 'e1', 'name': 'ad_impression'});
      expect(await a.pendientes(ahora: DateTime.now(), kind: 'attempt', limite: 3), hasLength(3));
      expect((await a.pendientes(ahora: DateTime.now(), kind: 'event')).single.refId, 'e1');
    });

    test('encolar de nuevo la misma referencia actualiza la carga', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.encolar('inquiry', 'q1', {'v': 1});
      await a.encolar('inquiry', 'q1', {'v': 2});
      final p = await a.pendientes(ahora: DateTime.now());
      expect(p.single.payload, '{"v":2}');
    });

    test('consultas guardadas por fecha descendente', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarConsulta(ConsultaGuardada(id: 'q1', json: const {'message': 'uno'}, status: 'pending', createdAt: DateTime(2026, 11, 1)));
      await a.guardarConsulta(ConsultaGuardada(id: 'q2', json: const {'message': 'dos'}, status: 'received', reference: 'C-ABC', createdAt: DateTime(2026, 11, 2)));
      final c = await a.consultas();
      expect(c.map((e) => e.id), ['q2', 'q1']);
      expect(c.first.reference, 'C-ABC');
    });

    test('borrar todo deja el aprendizaje y la bandeja vacíos', () async {
      final a = AlmacenAprendizajeDrift(db);
      await a.guardarIntento(intento('a1'));
      await a.guardarSesion(sesion('s1'));
      await a.borrarTodo();
      expect(await a.intentos(), isEmpty);
      expect(await a.sesiones(), isEmpty);
      expect(await a.contarPendientes(), 0);
    });
  });

  group('Clave-valor', () {
    test('lee, escribe, sobrescribe y borra', () async {
      final k = AlmacenClavesDrift(db);
      expect(await k.leer('perfil'), isNull);
      await k.escribirJson('perfil', {'alias': 'MeniscoÁgil12'});
      await k.escribirJson('perfil', {'alias': 'BuretaClara20'});
      expect((await k.leerJson('perfil'))!['alias'], 'BuretaClara20');
      await k.borrar('perfil');
      expect(await k.leer('perfil'), isNull);
    });
  });

  group('Paridad con la implementación en memoria', () {
    test('la memoria sigue las mismas reglas de cambio por clave', () async {
      final c = AlmacenContenidoMemoria();
      await c.instalarActivo(paquete('it-fundamentos', 'it-fundamentos', '2026.11.0'));
      await c.guardarPreparado(paquete('it-fundamentos', '2026.11.1:it-fundamentos', '2026.11.1'));
      expect(await c.activarPreparados(), ['it-fundamentos']);
      expect((await c.paquetes(status: 'active')).single.version, '2026.11.1');
      expect((await c.paquetes(status: 'previous')).single.version, '2026.11.0');
    });
  });
}
