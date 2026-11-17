import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/data/almacenes.dart';
import 'package:volutrainmed/core/data/api_client.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/domain/reloj.dart';
import 'package:volutrainmed/core/sync/sincronizador.dart';
import 'package:volutrainmed/features/progress/domain/projections.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';

import '../helpers/arnes.dart';
import '../helpers/respuestas.dart';
import 'servidor_falso.dart';

/// Hace una lección completa en un dispositivo y la guarda en su almacén.
Future<void> hacerLeccion(AlmacenAprendizaje almacen, ContenidoCargado c, String lessonId, String deviceId, DateTime cuando, {int fallos = 0, int msPorEjercicio = 8000}) async {
  var ms = 0;
  final intentos = <Attempt>[];
  final leccion = c.fundamentos!.lessons.firstWhere((l) => l.id == lessonId);
  final m = MotorSesion(
    contenido: c,
    modo: SessionMode.lesson,
    deviceId: deviceId,
    relojMs: () => ms,
    ahora: () => cuando.add(Duration(milliseconds: ms)),
    leccion: leccion,
    azar: Random(lessonId.hashCode),
    alRegistrar: intentos.add,
  )..preparar();
  var i = 0;
  while (m.fase != FaseSesion.terminada) {
    ms += msPorEjercicio;
    i++ < fallos ? responderMal(m) : responderBien(m);
    m.continuar();
    if (m.fase == FaseSesion.pausaPromocional) m.cerrarPausa();
  }
  for (final a in intentos) {
    await almacen.guardarIntento(a);
  }
  await almacen.guardarSesion(m.registro(completada: true));
}

Attempt intentoSintetico(int i) => Attempt(
      id: 'a-${i.toString().padLeft(4, '0')}',
      sessionId: 's1',
      deviceId: 'disp-prueba',
      mode: SessionMode.lesson,
      lessonId: 'u-f-1-l1',
      templateId: 'tpl-f-mg-ug',
      variantId: 'v$i',
      skillId: 'H1',
      exerciseTypeId: 'T1',
      level: 1,
      answerValue: '1000',
      answerUnit: 'µg',
      verdict: Verdict.correct,
      responseMs: 9000,
      targetMs: 15000,
      points: 10,
      contentVersion: '2026.11.0',
      deviceTime: ahoraPrueba.add(Duration(seconds: i)),
    );

/// Dispositivo de prueba con su almacén y su sincronizador.
class Dispositivo {
  Dispositivo(this.id, ServidorFalso s, {String? token = 'tok'}) {
    api = ApiClient(baseUrl: 'http://api.prueba', client: MockClient(s.manejar), token: () => token);
    sync = SincronizadorReal(
      almacen: almacen,
      api: api,
      reloj: RelojFijo(ahoraPrueba),
      usuario: () => EstadoUsuario(deviceId: id, token: token, cursorSync: cursor),
      guardarCursor: (c, _) async => cursor = c,
      alRecibir: () async => recibidos++,
    );
  }
  final String id;
  final almacen = AlmacenAprendizajeMemoria();
  late final ApiClient api;
  late final SincronizadorReal sync;
  String? cursor;
  int recibidos = 0;

  Future<Proyeccion> proyeccion(ContenidoCargado c) async => proyectar(
        attempts: await almacen.intentos(),
        sessions: await almacen.sesiones(),
        itineraries: c.itinerarios.values.toList(),
        goal: const Goal.daily(5),
        now: ahoraPrueba.add(const Duration(hours: 3)),
      );
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  group('Sincronizador (lógica)', () {
    test('offline-sync · Envío repetido: un lote enviado dos veces por un corte se conserva una sola vez', () async {
      final s = ServidorFalso();
      final d = Dispositivo('disp-prueba', s);
      for (var i = 0; i < 120; i++) {
        await d.almacen.guardarIntento(intentoSintetico(i));
      }
      // El servidor recibe el lote pero la respuesta se pierde por un corte.
      s.proximaSubida = (_) async => throw http.ClientException('corte de red');
      await d.sync.sincronizar();
      expect(d.sync.estado.value.error, textoErrorSync);
      expect(await d.almacen.contarPendientes(), 120, reason: 'la app no sabe que llegó: lo reintenta');
      expect(s.intentos, hasLength(120));

      await d.sync.sincronizar(forzar: true);
      expect(s.lotes, hasLength(2));
      expect(s.lotes[1], s.lotes[0], reason: 'se reenvían los mismos identificadores');
      expect(s.intentos, hasLength(120), reason: 'el servidor conserva cada intento una sola vez');
      expect(s.duplicados, 120);
      expect(await d.almacen.contarPendientes(), 0);
      expect(await d.almacen.intentos(), hasLength(120), reason: 'la recepción no duplica nada en el dispositivo');
      expect(d.sync.estado.value.error, isNull);
    });

    test('los lotes de subida no superan 500 intentos', () async {
      final s = ServidorFalso();
      final d = Dispositivo('disp-prueba', s);
      for (var i = 0; i < 1100; i++) {
        await d.almacen.guardarIntento(intentoSintetico(i));
      }
      await d.sync.sincronizar();
      expect(s.lotes.map((l) => l.length), [500, 500, 100]);
      expect(await d.almacen.contarPendientes(), 0);
    });

    test('tras un fallo se espera más antes de reintentar', () async {
      expect(esperaReintento(0), const Duration(seconds: 30));
      expect(esperaReintento(1), const Duration(minutes: 1));
      expect(esperaReintento(20), const Duration(hours: 1));
      final d = Dispositivo('disp-prueba', ServidorFalso());
      await d.almacen.guardarIntento(intentoSintetico(1));
      final api = ApiClient(baseUrl: 'http://x', client: MockClient((_) async => throw http.ClientException('sin red')), token: () => 'tok');
      final sync = SincronizadorReal(
        almacen: d.almacen,
        api: api,
        reloj: RelojFijo(ahoraPrueba),
        usuario: () => const EstadoUsuario(deviceId: 'd', token: 'tok'),
        guardarCursor: (_, _) async {},
        alRecibir: () async {},
      );
      await sync.sincronizar();
      expect(await d.almacen.pendientes(ahora: ahoraPrueba.add(const Duration(seconds: 29))), isEmpty);
      expect(await d.almacen.pendientes(ahora: ahoraPrueba.add(const Duration(seconds: 31))), hasLength(1));
    });

    test('sin cuenta no se suben intentos, pero sí eventos con el dispositivo seudónimo', () async {
      final s = ServidorFalso();
      final d = Dispositivo('disp-prueba', s, token: null);
      await d.almacen.guardarIntento(intentoSintetico(1));
      await d.almacen.encolar('event', 'e1', {'id': 'e1', 'name': 'ad_impression', 'at': '2026-11-17T10:00:00Z', 'props': {}});
      await d.sync.sincronizar();
      expect(s.lotes, isEmpty);
      expect(s.eventos, {'e1'});
      expect(await d.almacen.contarPendientes(), 1, reason: 'el intento espera a la cuenta');
    });

    test('offline-sync · Dos dispositivos sin conexión: ambos muestran las dos lecciones, las mismas fichas y la misma racha', () async {
      final c = contenidoPrueba;
      final s = ServidorFalso();
      final movil = Dispositivo('movil', s);
      final tablet = Dispositivo('tablet', s);
      await hacerLeccion(movil.almacen, c, 'u-f-1-l1', 'movil', ahoraPrueba, fallos: 2);
      await hacerLeccion(tablet.almacen, c, 'u-f-1-l2', 'tablet', ahoraPrueba.add(const Duration(hours: 1)), fallos: 1);

      await movil.sync.sincronizar();
      await tablet.sync.sincronizar();
      await movil.sync.sincronizar();

      final pm = await movil.proyeccion(c);
      final pt = await tablet.proyeccion(c);
      expect(pm.lecciones.keys.toSet(), {'u-f-1-l1', 'u-f-1-l2'});
      expect(pt.lecciones.keys.toSet(), {'u-f-1-l1', 'u-f-1-l2'});
      expect(pm.fichas.keys.toSet(), pt.fichas.keys.toSet());
      expect(pm.fichas, isNotEmpty);
      expect(pm.racha.actual, pt.racha.actual);
      expect(pm.puntosTotales, pt.puntosTotales);
    });

    test('offline-sync · Dispositivo nuevo: recupera su progreso, sus fichas de repaso y sus estadísticas', () async {
      final c = contenidoPrueba;
      final s = ServidorFalso();
      final viejo = Dispositivo('viejo', s);
      await hacerLeccion(viejo.almacen, c, 'u-f-1-l1', 'viejo', ahoraPrueba, fallos: 3);
      await viejo.sync.sincronizar();

      final nuevo = Dispositivo('nuevo', s);
      await nuevo.sync.recuperarHistorial();
      expect(nuevo.recibidos, 1, reason: 'se recalculan las proyecciones');
      final pv = await viejo.proyeccion(c);
      final pn = await nuevo.proyeccion(c);
      expect(pn.lecciones.keys, pv.lecciones.keys);
      expect(pn.fichas.keys.toSet(), pv.fichas.keys.toSet());
      expect(pn.fichas, isNotEmpty);
      expect(pn.estadisticas('H1').erroresPorTipo.length, pv.estadisticas('H1').erroresPorTipo.length);
      expect(pn.resumen.sesionesCompletadas, pv.resumen.sesionesCompletadas);
      expect(nuevo.cursor, isNotNull);
    });
  });

  test('offline-sync · Semana sin conexión: lecciones, repaso, rachas y estadísticas se actualizan en el dispositivo', () async {
    final c = contenidoPrueba;
    final d = Dispositivo('disp-prueba', ServidorFalso());
    final sinRed = SincronizadorReal(
      almacen: d.almacen,
      api: ApiClient(baseUrl: 'http://x', client: MockClient((_) async => throw http.ClientException('sin red')), token: () => 'tok'),
      reloj: RelojFijo(ahoraPrueba),
      usuario: () => const EstadoUsuario(deviceId: 'disp-prueba', token: 'tok'),
      guardarCursor: (_, _) async {},
      alRecibir: () async {},
    );
    const lecciones = ['u-f-1-l1', 'u-f-1-l2', 'u-f-1-l3', 'u-f-1-l4', 'u-f-2-l1', 'u-f-2-l2', 'u-f-2-l3'];
    final inicio = ahoraPrueba.subtract(const Duration(days: 6));
    for (var dia = 0; dia < 7; dia++) {
      await hacerLeccion(d.almacen, c, lecciones[dia], 'disp-prueba', inicio.add(Duration(days: dia)), fallos: 1, msPorEjercicio: 45000);
      await sinRed.sincronizar(forzar: true);
      expect(sinRed.estado.value.error, textoErrorSync, reason: 'el fallo de red no interrumpe nada');
    }
    final p = proyectar(
      attempts: await d.almacen.intentos(),
      sessions: await d.almacen.sesiones(),
      itineraries: c.itinerarios.values.toList(),
      goal: const Goal.daily(5),
      now: ahoraPrueba.add(const Duration(hours: 2)),
    );
    expect(p.lecciones.keys.toSet(), lecciones.toSet());
    expect(p.racha.actual, 7);
    expect(p.fichas, isNotEmpty, reason: 'los fallos van al repaso');
    expect(p.resumen.sesionesCompletadas, 7);
    expect(p.resumen.datosInsuficientes, isFalse);
    expect(await d.almacen.contarPendientes(), (await d.almacen.intentos()).length + 7, reason: 'todo queda en la bandeja para cuando haya conexión');
  });

  group('Centro de sincronización', () {
    testWidgets('offline-sync · Recuperación de la conexión: 120 intentos pendientes se envían y el centro muestra cero pendientes', (t) async {
      final s = ServidorFalso();
      final a = Arnes(usuario: usuarioDePrueba(token: 'tok'), conexion: false, http: s.manejar);
      for (var i = 0; i < 120; i++) {
        await a.aprendizaje.guardarIntento(intentoSintetico(i));
      }
      await a.montar(t, ruta: Rutas.sincronizacion);
      expect(find.textContaining('120 elementos pendientes'), findsOneWidget);

      a.conectividad.conectado = true;
      await Arnes.asentar(t);
      expect(s.intentos, hasLength(120));
      expect(find.textContaining('0 elementos pendientes'), findsOneWidget);
      expect(find.textContaining('Sincronizado ·'), findsOneWidget);
    });

    testWidgets('offline-sync · Error de sincronización: se muestra el aviso, se reintenta más tarde y el entrenamiento sigue', (t) async {
      final a = Arnes(
        usuario: usuarioDePrueba(token: 'tok'),
        http: (r) async => http.Response('{"error":{"code":"internal","message":"Error"}}', 500),
      );
      await a.aprendizaje.guardarIntento(intentoSintetico(1));
      await a.montar(t, ruta: Rutas.sincronizacion);
      expect(find.text(textoErrorSync), findsOneWidget);
      expect(await a.aprendizaje.contarPendientes(), 1, reason: 'queda en la bandeja para reintentarlo');
      expect(await a.aprendizaje.pendientes(ahora: ahoraPrueba), isEmpty, reason: 'aplazado con espera');
      // El entrenamiento no se interrumpe: la navegación sigue disponible.
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Inicio')));
      await Arnes.asentar(t);
      expect(a.ubicacion.ruta, Rutas.inicio);
    });

    testWidgets('sin cuenta el centro explica que el progreso queda en el dispositivo', (t) async {
      final a = Arnes();
      await a.montar(t, ruta: Rutas.sincronizacion);
      expect(find.textContaining('Solo en este dispositivo'), findsOneWidget);
      expect(find.textContaining('Fundamentos'), findsWidgets);
      expect(a.peticiones, isEmpty, reason: 'sin cuenta y sin pendientes no hay tráfico');
      final u = a.contenedor.read(usuarioProvider).value!;
      expect(u.conCuenta, isFalse);
    });
  });
}
