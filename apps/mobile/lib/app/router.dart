import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/ui/pantallas_cuenta.dart';
import '../features/home/ui/pantalla_inicio.dart';
import '../features/inquiries/ui/pantallas_consulta.dart';
import '../features/leagues/ui/pantalla_ligas.dart';
import '../features/onboarding/ui/pantallas_alta.dart';
import '../features/profile/ui/pantallas_perfil.dart';
import '../features/progress/ui/pantalla_progreso.dart';
import '../features/review/ui/pantalla_repaso.dart';
import '../features/session/ui/pantalla_sesion.dart';
import '../features/subscription/ui/pantalla_suscripcion.dart';
import '../features/timetrial/ui/pantalla_contrarreloj.dart';
import '../features/voice/ui/pantalla_manos_libres.dart';
import 'adaptativo.dart';
import 'estado/estado_app.dart';

/// Rutas de la app. Las pestañas viven en un `StatefulShellRoute` (barra
/// inferior o carril lateral); el alta, la sesión y las pantallas modales van
/// a pantalla completa, sin navegación principal.
abstract final class Rutas {
  static const bienvenida = '/bienvenida';
  static const altaSector = '/alta/sector';
  static const altaNivel = '/alta/nivel';
  static const altaMeta = '/alta/meta';
  static const altaAviso = '/alta/aviso';
  static const altaPrueba = '/alta/prueba';
  static const altaResultado = '/alta/resultado';
  static const altaDescarga = '/alta/descarga';
  static const permisoNotificaciones = '/permisos/notificaciones';
  static const cuenta = '/cuenta';
  static const codigo = '/cuenta/codigo';
  static const inicio = '/inicio';
  static String unidad(String id) => '/inicio/unidad/$id';
  static const practicar = '/practicar';
  static const repaso = '/practicar/repaso';
  static const progreso = '/progreso';
  static String habilidad(String id) => '/progreso/habilidad/$id';
  static const ligas = '/ligas';
  static const perfil = '/perfil';
  static const voz = '/perfil/voz';
  static const accesibilidad = '/perfil/accesibilidad';
  static const sincronizacion = '/perfil/sincronizacion';
  static const privacidad = '/perfil/privacidad';
  static const legal = '/perfil/legal';
  static const meta = '/perfil/meta';
  static const itinerario = '/perfil/itinerario';
  static const organizacion = '/perfil/organizacion';
  static const sesion = '/sesion';
  static const consulta = '/consulta';
  static const consultas = '/consultas';
  static const suscripcion = '/suscripcion';
  static const manosLibres = '/manos-libres';
  static const contrarreloj = '/contrarreloj';

  /// Sesión de una lección. [calentamiento] antepone hasta 5 fichas vencidas.
  static String leccion(String lessonId, {bool calentamiento = false}) =>
      Uri(path: sesion, queryParameters: {'modo': 'leccion', 'leccion': lessonId, if (calentamiento) 'calentamiento': '1'}).toString();
  static String sesionRepaso() => Uri(path: sesion, queryParameters: {'modo': 'repaso'}).toString();
  static String practicaHabilidad(String skillId) => Uri(path: sesion, queryParameters: {'modo': 'practica', 'habilidad': skillId}).toString();
}

bool _esAlta(String loc) => loc == Rutas.bienvenida || loc.startsWith('/alta') || loc.startsWith(Rutas.cuenta);

GoRouter crearRouter(Ref ref, {String? inicial}) {
  final refresco = ValueNotifier<int>(0);
  ref.listen(usuarioProvider, (_, _) => refresco.value++);
  ref.onDispose(refresco.dispose);
  return GoRouter(
    initialLocation: inicial ?? Rutas.inicio,
    refreshListenable: refresco,
    redirect: (context, state) {
      final u = ref.read(usuarioProvider).value;
      if (u == null) return null;
      final loc = state.matchedLocation;
      if (!u.altaCompletada && !_esAlta(loc) && !loc.startsWith(Rutas.sesion) && !loc.startsWith(Rutas.legal)) return Rutas.bienvenida;
      return null;
    },
    routes: [
      GoRoute(path: Rutas.bienvenida, builder: (_, _) => const PantallaBienvenida()),
      GoRoute(path: Rutas.altaSector, builder: (_, _) => const PantallaSector()),
      GoRoute(path: Rutas.altaNivel, builder: (_, _) => const PantallaNivel()),
      GoRoute(path: Rutas.altaMeta, builder: (_, _) => const PantallaMeta()),
      GoRoute(path: Rutas.altaAviso, builder: (_, _) => const PantallaAviso()),
      GoRoute(path: Rutas.altaPrueba, builder: (_, _) => const PantallaPruebaNivel()),
      GoRoute(path: Rutas.altaResultado, builder: (_, _) => const PantallaResultadoPrueba()),
      GoRoute(path: Rutas.altaDescarga, builder: (_, _) => const PantallaDescarga()),
      GoRoute(path: Rutas.permisoNotificaciones, builder: (_, _) => const PantallaPermisoNotificaciones()),
      GoRoute(path: Rutas.cuenta, builder: (_, _) => const PantallaCuenta()),
      GoRoute(path: Rutas.codigo, builder: (_, s) => PantallaCodigo(email: s.uri.queryParameters['email'] ?? '')),
      GoRoute(path: Rutas.sesion, builder: (_, s) => PantallaSesion(parametros: s.uri.queryParameters)),
      GoRoute(path: Rutas.consulta, builder: (_, s) => PantallaConsulta(adjunto: s.extra as Map<String, dynamic>?)),
      GoRoute(path: Rutas.consultas, builder: (_, _) => const PantallaMisConsultas()),
      GoRoute(
        path: Rutas.suscripcion,
        pageBuilder: (_, s) => MaterialPage(fullscreenDialog: true, child: PantallaSuscripcion(anuncioId: s.uri.queryParameters['anuncio'])),
      ),
      GoRoute(path: Rutas.manosLibres, builder: (_, _) => const PantallaManosLibres()),
      GoRoute(path: Rutas.contrarreloj, builder: (_, _) => const PantallaContrarreloj()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ArmazonPrincipal(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.inicio,
              builder: (_, _) => const PantallaInicio(),
              routes: [GoRoute(path: 'unidad/:id', builder: (_, s) => PantallaUnidad(unitId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.practicar,
              builder: (_, _) => const PantallaPracticar(),
              routes: [GoRoute(path: 'repaso', builder: (_, _) => const PantallaRepaso())],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.progreso,
              builder: (_, _) => const PantallaProgreso(),
              routes: [GoRoute(path: 'habilidad/:id', builder: (_, s) => PantallaHabilidad(skillId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Rutas.ligas, builder: (_, _) => const PantallaLigas())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Rutas.perfil,
              builder: (_, _) => const PantallaPerfil(),
              routes: [
                GoRoute(path: 'voz', builder: (_, _) => const PantallaAjustesVoz()),
                GoRoute(path: 'accesibilidad', builder: (_, _) => const PantallaAccesibilidad()),
                GoRoute(path: 'sincronizacion', builder: (_, _) => const PantallaSincronizacion()),
                GoRoute(path: 'privacidad', builder: (_, _) => const PantallaPrivacidad()),
                GoRoute(path: 'legal', builder: (_, _) => const PantallaLegal()),
                GoRoute(path: 'meta', builder: (_, _) => const PantallaMetaAjustes()),
                GoRoute(path: 'itinerario', builder: (_, _) => const PantallaItinerario()),
                GoRoute(path: 'organizacion', builder: (_, _) => const PantallaOrganizacion()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}

/// Ruta inicial (las pruebas la sustituyen para abrir una pantalla concreta).
final rutaInicialProvider = Provider<String?>((_) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final r = crearRouter(ref, inicial: ref.watch(rutaInicialProvider));
  ref.onDispose(r.dispose);
  return r;
});
