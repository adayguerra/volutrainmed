import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:volutrainmed/app/app.dart';
import 'package:volutrainmed/app/dependencias.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/data/almacenes.dart';
import 'package:volutrainmed/core/data/api_client.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/domain/reloj.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';

/// Arnés común de las pruebas de la app: almacenes en memoria, contenido real
/// incluido en la app (verificado una vez por archivo de prueba), API
/// simulada y dobles de la plataforma.
///
/// Uso:
/// ```dart
/// setUpAll(cargarContenidoDePrueba);
/// testWidgets('…', (t) async {
///   final a = Arnes();
///   await a.montar(t, ruta: Rutas.inicio);
/// });
/// ```

/// Lector de activos desde el disco (las pruebas se ejecutan en apps/mobile).
Future<Uint8List> leerActivoDisco(String ruta) async => File(ruta).readAsBytes();

ContenidoCargado? _contenido;

/// Contenido incluido en la app, verificado con su firma real.
ContenidoCargado get contenidoPrueba => _contenido ?? (throw StateError('Llama a cargarContenidoDePrueba en setUpAll'));

Future<ContenidoCargado> cargarContenidoDePrueba() async {
  if (_contenido != null) return _contenido!;
  final repo = RepositorioContenido(almacen: AlmacenContenidoMemoria(), claves: AlmacenClavesMemoria(), leerActivo: leerActivoDisco);
  return _contenido = await repo.cargar();
}

/// Momento fijo de las pruebas: martes 17 de noviembre de 2026, 10:00.
final ahoraPrueba = DateTime(2026, 11, 17, 10);

/// Usuario con el alta completada, perfil local de enfermería y Fundamentos.
EstadoUsuario usuarioDePrueba({
  bool alta = true,
  String sector = 'enfermeria',
  String itinerario = 'it-fundamentos',
  Goal? meta = const Goal.daily(10),
  String? token,
  bool primeraLeccion = true,
}) =>
    EstadoUsuario(
      deviceId: 'disp-prueba',
      altaCompletada: alta,
      token: token,
      primeraLeccionAt: primeraLeccion ? ahoraPrueba.subtract(const Duration(days: 3)) : null,
      perfil: alta
          ? UserProfile(
              id: 'local-disp-prueba',
              alias: 'MeniscoÁgil12',
              sectorId: sector,
              itineraryId: itinerario,
              declaredLevel: 'afianzar',
              goal: meta,
              disclaimerAcceptedAt: ahoraPrueba.subtract(const Duration(days: 3)),
              createdAt: ahoraPrueba.subtract(const Duration(days: 3)),
            )
          : null,
    );

/// Contenido fijo para las pruebas de widget (sin E/S real).
class ContenidoFijo extends ContenidoNotifier {
  ContenidoFijo(this.c);
  final ContenidoCargado c;
  @override
  Future<ContenidoCargado> build() async => c;
}

/// Respuesta HTTP simulada; por defecto, sin conexión.
typedef ManejadorHttp = Future<http.Response> Function(http.Request req);

Future<http.Response> sinRed(http.Request _) async => throw http.ClientException('sin red');

class Arnes {
  Arnes({
    EstadoUsuario? usuario,
    this.ajustes,
    this.derechos,
    List<Attempt> intentos = const [],
    List<SessionRecord> sesiones = const [],
    ManejadorHttp? http,
    DateTime? ahora,
    bool conexion = true,
    ContenidoCargado? contenido,
    MotorDeVoz? motorVoz,
    PermisosFalsos? permisos,
  })  : usuario = usuario ?? usuarioDePrueba(),
        contenido = contenido ?? contenidoPrueba,
        manejador = http ?? sinRed,
        reloj = RelojFijo(ahora ?? ahoraPrueba),
        conectividad = ConectividadFalsa(conexion),
        motorVoz = motorVoz ?? const MotorDeVozPendiente(),
        permisos = permisos ?? PermisosFalsos() {
    for (final a in intentos) {
      _semillaIntentos.add(a);
    }
    _semillaSesiones.addAll(sesiones);
  }

  final EstadoUsuario usuario;
  final Ajustes? ajustes;
  final Entitlements? derechos;
  final ContenidoCargado contenido;
  ManejadorHttp manejador;
  final RelojFijo reloj;
  final ConectividadFalsa conectividad;
  final MotorDeVoz motorVoz;
  final PermisosFalsos permisos;
  final _semillaIntentos = <Attempt>[];
  final _semillaSesiones = <SessionRecord>[];

  final claves = AlmacenClavesMemoria();
  final aprendizaje = AlmacenAprendizajeMemoria();
  final almacenContenido = AlmacenContenidoMemoria();
  final sintetizador = SintetizadorFalso();
  final vibrador = VibradorFalso();
  final sonido = SonidoFalso();
  final notificador = NotificadorRegistro();
  final peticiones = <http.Request>[];
  int _ms = 0;

  /// Peticiones de la app salvo la comprobación de contenido (manifiesto y
  /// paquetes firmados), que se hace al arrancar con conexión.
  List<http.Request> get peticionesSinContenido => peticiones.where((r) => !r.url.path.startsWith('/v1/content/')).toList();

  /// Avanza el reloj monótono de la sesión (tiempos de respuesta).
  void avanzarMs(int ms) => _ms += ms;

  late final Dependencias deps;
  late ProviderContainer contenedor;

  Future<void> _sembrar() async {
    await claves.escribirJson(claveUsuario, usuario.toJson());
    if (ajustes != null) await claves.escribirJson(claveAjustes, ajustes!.toJson());
    if (derechos != null) await claves.escribirJson(claveDerechos, derechos!.toJson());
    await aprendizaje.fusionar(_semillaIntentos, _semillaSesiones);
  }

  Dependencias _crearDeps() => Dependencias(
        contenido: almacenContenido,
        aprendizaje: aprendizaje,
        claves: claves,
        api: ApiClient(
          baseUrl: 'http://api.prueba',
          client: MockClient((req) {
            peticiones.add(req);
            return manejador(req);
          }),
        ),
        reloj: reloj,
        conectividad: conectividad,
        sintetizador: sintetizador,
        motorVoz: motorVoz,
        vibrador: vibrador,
        sonido: sonido,
        permisos: permisos,
        notificador: notificador,
        leerActivo: leerActivoDisco,
        relojMs: () => _ms,
        azar: Random(7),
      );

  List<Override> get overrides => [
        dependenciasProvider.overrideWithValue(deps),
        contenidoProvider.overrideWith(() => ContenidoFijo(contenido)),
      ];

  /// Contenedor sin interfaz (pruebas de lógica con proveedores).
  Future<ProviderContainer> contenedorSinInterfaz() async {
    await _sembrar();
    deps = _crearDeps();
    contenedor = ProviderContainer(overrides: overrides, retry: (_, _) => null);
    await contenedor.read(arranqueProvider.future);
    return contenedor;
  }

  /// Monta la app en [ruta] con el tamaño de pantalla indicado (en dp).
  Future<void> montar(
    WidgetTester t, {
    String ruta = Rutas.inicio,
    Size tamano = const Size(390, 844),
    double escalaTexto = 1.0,
    Brightness brillo = Brightness.light,
    bool movimientoReducido = false,
  }) async {
    await t.runAsync(_sembrar);
    deps = _crearDeps();
    t.view.physicalSize = tamano;
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    t.platformDispatcher.platformBrightnessTestValue = brillo;
    t.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: movimientoReducido);
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
      t.platformDispatcher.clearTextScaleFactorTestValue();
      t.platformDispatcher.clearPlatformBrightnessTestValue();
      t.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    await t.pumpWidget(UncontrolledProviderScope(
      container: contenedor = ProviderContainer(
        overrides: [...overrides, rutaInicialProvider.overrideWithValue(ruta)],
        retry: (_, _) => null,
      ),
      child: const VtmApp(),
    ));
    addTearDown(contenedor.dispose);
    await asentar(t);
  }

  /// Bombea hasta que no queden fotogramas pendientes (con tope).
  static Future<void> asentar(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await t.pumpAndSettle(const Duration(milliseconds: 50), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
  }

  GoRouterLocation get ubicacion => GoRouterLocation(contenedor.read(routerProvider).routerDelegate.currentConfiguration.uri.toString());
}

/// Envoltorio para comparar la ruta actual en las aserciones.
class GoRouterLocation {
  const GoRouterLocation(this.ruta);
  final String ruta;
  @override
  String toString() => ruta;
}

/// Comprueba que ningún widget ha desbordado (texto al 200 %).
void sinDesbordes(WidgetTester t) {
  final e = t.takeException();
  expect(e, isNull, reason: 'Excepción de dibujo: $e');
}
