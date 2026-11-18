import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contenido/repositorio_contenido.dart';
import '../../core/domain/content_models.dart';
import '../../core/domain/ids.dart';
import '../../core/domain/learning_models.dart';
import '../../core/plataforma/plataforma.dart';
import '../../features/progress/domain/projections.dart';
import '../../features/subscription/domain/entitlements_policy.dart';
import '../dependencias.dart';
import 'ajustes.dart';

/// Estado global de la app (Riverpod). Las pantallas leen de aquí y las
/// acciones escriben primero en el dispositivo: todo funciona sin conexión.

// ---------------------------------------------------------------------------
// Contenido
// ---------------------------------------------------------------------------

class ContenidoNotifier extends AsyncNotifier<ContenidoCargado> {
  @override
  Future<ContenidoCargado> build() async {
    final repo = ref.read(dependenciasProvider).repositorio;
    // Al arrancar no hay sesión en curso: se aplican las versiones preparadas.
    await repo.aplicarPreparados();
    return repo.cargar();
  }

  /// Vuelve a cargar el contenido activo (tras aplicar una versión nueva).
  Future<void> recargar() async {
    final repo = ref.read(dependenciasProvider).repositorio;
    state = AsyncData(await repo.cargar());
  }

  /// Aplica la lista de retirada al momento, sin esperar a otra versión.
  Future<void> aplicarRevocaciones(Revocaciones r) async {
    await ref.read(dependenciasProvider).repositorio.guardarRevocaciones(r);
    final actual = state.value;
    if (actual != null) state = AsyncData(actual.conRevocaciones(r));
  }
}

final contenidoProvider = AsyncNotifierProvider<ContenidoNotifier, ContenidoCargado>(ContenidoNotifier.new);

// ---------------------------------------------------------------------------
// Usuario (perfil local o cuenta)
// ---------------------------------------------------------------------------

@immutable
class EstadoUsuario {
  const EstadoUsuario({
    required this.deviceId,
    this.perfil,
    this.token,
    this.altaCompletada = false,
    this.registroPospuesto = false,
    this.primeraLeccionAt,
    this.notificacionesOfrecidas = false,
    this.microfonoOfrecido = false,
    this.pruebaEnCurso,
    this.cursorSync,
    this.ultimaSync,
  });

  final String deviceId;
  final UserProfile? perfil;

  /// Token de la cuenta; null con perfil local.
  final String? token;
  final bool altaCompletada;

  /// El usuario eligió «Ahora no» al ofrecerle la cuenta.
  final bool registroPospuesto;

  /// Fin de la primera lección (después se ofrecen la cuenta y el permiso de
  /// notificaciones, y empiezan las pausas promocionales).
  final DateTime? primeraLeccionAt;
  final bool notificacionesOfrecidas;
  final bool microfonoOfrecido;

  /// Estado guardado de la prueba de nivel para reanudarla.
  final Map<String, dynamic>? pruebaEnCurso;
  final String? cursorSync;
  final DateTime? ultimaSync;

  bool get conCuenta => token != null;
  bool get primeraLeccionHecha => primeraLeccionAt != null;

  EstadoUsuario copyWith({
    UserProfile? perfil,
    String? token,
    bool quitarToken = false,
    bool? altaCompletada,
    bool? registroPospuesto,
    DateTime? primeraLeccionAt,
    bool? notificacionesOfrecidas,
    bool? microfonoOfrecido,
    Map<String, dynamic>? pruebaEnCurso,
    bool quitarPrueba = false,
    String? cursorSync,
    DateTime? ultimaSync,
  }) =>
      EstadoUsuario(
        deviceId: deviceId,
        perfil: perfil ?? this.perfil,
        token: quitarToken ? null : (token ?? this.token),
        altaCompletada: altaCompletada ?? this.altaCompletada,
        registroPospuesto: registroPospuesto ?? this.registroPospuesto,
        primeraLeccionAt: primeraLeccionAt ?? this.primeraLeccionAt,
        notificacionesOfrecidas: notificacionesOfrecidas ?? this.notificacionesOfrecidas,
        microfonoOfrecido: microfonoOfrecido ?? this.microfonoOfrecido,
        pruebaEnCurso: quitarPrueba ? null : (pruebaEnCurso ?? this.pruebaEnCurso),
        cursorSync: cursorSync ?? this.cursorSync,
        ultimaSync: ultimaSync ?? this.ultimaSync,
      );

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'perfil': perfil?.toJson(),
        'token': token,
        'altaCompletada': altaCompletada,
        'registroPospuesto': registroPospuesto,
        'primeraLeccionAt': primeraLeccionAt?.toUtc().toIso8601String(),
        'notificacionesOfrecidas': notificacionesOfrecidas,
        'microfonoOfrecido': microfonoOfrecido,
        'pruebaEnCurso': pruebaEnCurso,
        'cursorSync': cursorSync,
        'ultimaSync': ultimaSync?.toUtc().toIso8601String(),
      };

  factory EstadoUsuario.fromJson(Map<String, dynamic> j) => EstadoUsuario(
        deviceId: '${j['deviceId']}',
        perfil: j['perfil'] is Map ? UserProfile.fromJson((j['perfil'] as Map).cast<String, dynamic>()) : null,
        token: j['token'] as String?,
        altaCompletada: j['altaCompletada'] == true,
        registroPospuesto: j['registroPospuesto'] == true,
        primeraLeccionAt: j['primeraLeccionAt'] == null ? null : DateTime.parse('${j['primeraLeccionAt']}'),
        notificacionesOfrecidas: j['notificacionesOfrecidas'] == true,
        microfonoOfrecido: j['microfonoOfrecido'] == true,
        pruebaEnCurso: (j['pruebaEnCurso'] as Map?)?.cast<String, dynamic>(),
        cursorSync: j['cursorSync'] as String?,
        ultimaSync: j['ultimaSync'] == null ? null : DateTime.parse('${j['ultimaSync']}'),
      );
}

const claveUsuario = 'usuario';

const _aliasA = ['Menisco', 'Émbolo', 'Bureta', 'Vial', 'Pipeta', 'Ampolla', 'Gotero', 'Matraz'];
const _aliasB = ['Ágil', 'Exacto', 'Sereno', 'Preciso', 'Constante', 'Atento', 'Claro', 'Firme'];

/// Seudónimo aleatorio: nunca se piden nombres reales (ligas con alias).
String aliasAleatorio(Random r) => '${_aliasA[r.nextInt(_aliasA.length)]}${_aliasB[r.nextInt(_aliasB.length)]}${r.nextInt(90) + 10}';

class UsuarioNotifier extends AsyncNotifier<EstadoUsuario> {
  @override
  Future<EstadoUsuario> build() async {
    final deps = ref.read(dependenciasProvider);
    final j = await deps.claves.leerJson(claveUsuario);
    if (j != null) {
      final e = EstadoUsuario.fromJson(j);
      deps.api.token = () => state.value?.token;
      return e;
    }
    final e = EstadoUsuario(deviceId: nuevoId());
    await deps.claves.escribirJson(claveUsuario, e.toJson());
    deps.api.token = () => state.value?.token;
    return e;
  }

  EstadoUsuario get _e => state.value!;

  Future<void> _guardar(EstadoUsuario e) async {
    state = AsyncData(e);
    await ref.read(dependenciasProvider).claves.escribirJson(claveUsuario, e.toJson());
  }

  Future<void> actualizar(EstadoUsuario Function(EstadoUsuario) f) => _guardar(f(_e));

  /// Crea (o completa) el perfil local durante el alta. No pide correo.
  Future<void> editarPerfil(UserProfile Function(UserProfile) f) async {
    final deps = ref.read(dependenciasProvider);
    final base = _e.perfil ?? UserProfile(id: 'local-${_e.deviceId}', alias: aliasAleatorio(deps.azar), createdAt: deps.reloj.ahora().toUtc());
    await _guardar(_e.copyWith(perfil: f(base)));
  }

  Future<void> completarAlta() => _guardar(_e.copyWith(altaCompletada: true));

  Future<void> marcarPrimeraLeccion() async {
    if (_e.primeraLeccionHecha) return;
    await _guardar(_e.copyWith(primeraLeccionAt: ref.read(dependenciasProvider).reloj.ahora()));
  }

  Future<void> posponerRegistro() => _guardar(_e.copyWith(registroPospuesto: true));

  /// Sesión iniciada: el perfil de la cuenta sustituye al local (el servidor
  /// ya ha fusionado los campos) y los intentos suben por sincronización.
  Future<void> iniciarSesion(String token, UserProfile perfil) =>
      _guardar(_e.copyWith(token: token, perfil: perfil, registroPospuesto: false));

  /// Cierra la sesión y vuelve a un perfil local sin datos de la cuenta.
  Future<void> cerrarSesion() => _guardar(EstadoUsuario(deviceId: _e.deviceId, altaCompletada: false));
}

final usuarioProvider = AsyncNotifierProvider<UsuarioNotifier, EstadoUsuario>(UsuarioNotifier.new);

// ---------------------------------------------------------------------------
// Aprendizaje: intentos y sesiones (fuente de verdad, diseño D5)
// ---------------------------------------------------------------------------

@immutable
class DatosAprendizaje {
  const DatosAprendizaje({this.intentos = const [], this.sesiones = const []});
  final List<Attempt> intentos;
  final List<SessionRecord> sesiones;
}

class AprendizajeNotifier extends AsyncNotifier<DatosAprendizaje> {
  @override
  Future<DatosAprendizaje> build() async {
    final a = ref.read(dependenciasProvider).aprendizaje;
    return DatosAprendizaje(intentos: await a.intentos(), sesiones: await a.sesiones());
  }

  DatosAprendizaje get _d => state.value ?? const DatosAprendizaje();

  /// Guarda el intento en el dispositivo y lo encola para subirlo.
  Future<void> registrarIntento(Attempt a) async {
    state = AsyncData(DatosAprendizaje(intentos: [..._d.intentos, a], sesiones: _d.sesiones));
    await ref.read(dependenciasProvider).aprendizaje.guardarIntento(a);
  }

  Future<void> registrarSesion(SessionRecord s) async {
    state = AsyncData(DatosAprendizaje(intentos: _d.intentos, sesiones: [..._d.sesiones.where((x) => x.id != s.id), s]));
    await ref.read(dependenciasProvider).aprendizaje.guardarSesion(s);
  }

  /// Encola un evento de analítica (impresión de anuncio, variante saltada…).
  Future<void> registrarEvento(String nombre, Map<String, dynamic> props) async {
    final deps = ref.read(dependenciasProvider);
    final e = AnalyticsEvent(id: nuevoId(), name: nombre, at: deps.reloj.ahora().toUtc(), props: props);
    await deps.aprendizaje.encolar('event', e.id, e.toJson());
  }

  Future<void> recargar() async => state = AsyncData(await build());
}

final aprendizajeProvider = AsyncNotifierProvider<AprendizajeNotifier, DatosAprendizaje>(AprendizajeNotifier.new);

// ---------------------------------------------------------------------------
// Derechos (Premium, plaza de organización)
// ---------------------------------------------------------------------------

const claveDerechos = 'derechos';

class DerechosNotifier extends Notifier<Entitlements> {
  @override
  Entitlements build() => Entitlements.none(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

  Future<void> cargar() async {
    final j = await ref.read(dependenciasProvider).claves.leerJson(claveDerechos);
    if (j != null) state = Entitlements.fromJson(j);
  }

  Future<void> guardar(Entitlements e) async {
    state = e;
    await ref.read(dependenciasProvider).claves.escribirJson(claveDerechos, e.toJson());
  }
}

final derechosProvider = NotifierProvider<DerechosNotifier, Entitlements>(DerechosNotifier.new);

/// Derechos efectivos ahora (validez de 30 días sin conexión).
final derechosEfectivosProvider = Provider<DerechosEfectivos>((ref) {
  final e = ref.watch(derechosProvider);
  return derechosEfectivos(e, ref.watch(dependenciasProvider).reloj.ahora());
});

// ---------------------------------------------------------------------------
// Conexión
// ---------------------------------------------------------------------------

final conexionProvider = StreamProvider<bool>((ref) async* {
  final c = ref.watch(dependenciasProvider).conectividad;
  yield await c.hayConexion();
  yield* c.cambios;
});

/// true si hay conexión (o mientras se desconoce).
final enLineaProvider = Provider<bool>((ref) => ref.watch(conexionProvider).value ?? true);

// ---------------------------------------------------------------------------
// Proyecciones
// ---------------------------------------------------------------------------

/// Itinerario activo del usuario; Fundamentos si el suyo no está descargado.
final itinerarioActivoProvider = Provider<ItineraryPackage?>((ref) {
  final c = ref.watch(contenidoProvider).value;
  if (c == null) return null;
  final id = ref.watch(usuarioProvider).value?.perfil?.itineraryId;
  return c.itinerario(id) ?? c.fundamentos;
});

final proyeccionProvider = Provider<Proyeccion?>((ref) {
  final c = ref.watch(contenidoProvider).value;
  final a = ref.watch(aprendizajeProvider).value;
  if (c == null || a == null) return null;
  final u = ref.watch(usuarioProvider).value;
  final aj = ref.watch(ajustesProvider);
  return proyectar(
    attempts: a.intentos,
    sessions: a.sesiones,
    itineraries: c.itinerarios.values.toList(),
    achievements: c.global.achievements,
    goal: u?.perfil?.goal,
    now: ref.watch(dependenciasProvider).reloj.ahora(),
    topeRepaso: aj.topeRepaso,
    habilidadesConocidas: c.global.skills.map((s) => s.id),
  );
});

/// Señales hápticas y sonoras según los ajustes y el modo silencio.
final senalesProvider = Provider<Senales>((ref) {
  final deps = ref.watch(dependenciasProvider);
  return Senales(
    vibrador: deps.vibrador,
    sonido: deps.sonido,
    hapticaActiva: () => ref.read(ajustesProvider).haptica,
    sonidosActivos: () => ref.read(ajustesProvider).sonidos,
  );
});

/// Carga inicial: ajustes, usuario, aprendizaje, derechos y contenido.
final arranqueProvider = FutureProvider<void>((ref) async {
  await ref.read(ajustesProvider.notifier).cargar();
  await ref.read(derechosProvider.notifier).cargar();
  await ref.read(usuarioProvider.future);
  await ref.read(aprendizajeProvider.future);
  await ref.read(contenidoProvider.future);
});
