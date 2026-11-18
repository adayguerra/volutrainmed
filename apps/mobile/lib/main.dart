import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/demo.dart';
import 'app/dependencias.dart';
import 'app/router.dart';
import 'core/data/almacenes.dart';
import 'core/data/api_client.dart';
import 'core/data/database.dart';
import 'core/domain/reloj.dart';
import 'core/plataforma/motor_voz_sistema.dart';
import 'core/plataforma/notificaciones_locales.dart';
import 'core/plataforma/plataforma.dart';

/// Arranque de VolutrainMed con las dependencias reales: SQLite (Drift),
/// cliente HTTP, voz del sistema y servicios de la plataforma. La API se
/// configura con `--dart-define=API_BASE=http://…`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Reconocimiento solo en el dispositivo; si no se puede garantizar, manos
  // libres sigue con el teclado. Esta comprobación no pide permisos.
  final motorVoz = MotorDeVozSistema();
  await motorVoz.preparar();
  final db = VtmDatabase();
  final deps = Dependencias(
    contenido: AlmacenContenidoDrift(db),
    aprendizaje: AlmacenAprendizajeDrift(db),
    claves: AlmacenClavesDrift(db),
    api: ApiClient(baseUrl: apiBaseDefecto),
    reloj: RelojSistema(),
    conectividad: ConectividadSistema(),
    sintetizador: SintetizadorSistema(),
    motorVoz: motorVoz,
    vibrador: VibradorSistema(),
    sonido: SonidoSistema(),
    permisos: PermisosSistema(),
    notificador: NotificadorLocal(),
    leerActivo: (ruta) async => (await rootBundle.load(ruta)).buffer.asUint8List(),
  );
  await sembrarDemo(deps);
  // Web: la ruta de la URL (enlace directo o recarga) se lee antes de dibujar
  // nada; la pantalla de arranque la sustituiría por «/».
  final rutaUrl = rutaInicialDeLaPlataforma();
  runApp(ProviderScope(
    overrides: [
      dependenciasProvider.overrideWithValue(deps),
      if (modoDemo && rutaDemo.isNotEmpty)
        rutaInicialProvider.overrideWithValue(rutaDemo)
      else if (rutaUrl != null)
        rutaInicialProvider.overrideWithValue(rutaUrl),
    ],
    child: const VtmApp(),
  ));
}

/// Ruta con la que el sistema abre la app (en la web, la de la barra de
/// direcciones), o null si es la raíz.
String? rutaInicialDeLaPlataforma() {
  if (!kIsWeb) return null;
  final r = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  return r.isEmpty || r == '/' ? null : r;
}
