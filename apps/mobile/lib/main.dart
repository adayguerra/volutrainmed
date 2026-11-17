import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/dependencias.dart';
import 'core/data/almacenes.dart';
import 'core/data/api_client.dart';
import 'core/data/database.dart';
import 'core/domain/reloj.dart';
import 'core/plataforma/plataforma.dart';

/// Arranque de VolutrainMed con las dependencias reales: SQLite (Drift),
/// cliente HTTP, voz del sistema y servicios de la plataforma. La API se
/// configura con `--dart-define=API_BASE=http://…`.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final db = VtmDatabase();
  final deps = Dependencias(
    contenido: AlmacenContenidoDrift(db),
    aprendizaje: AlmacenAprendizajeDrift(db),
    claves: AlmacenClavesDrift(db),
    api: ApiClient(baseUrl: apiBaseDefecto),
    reloj: RelojSistema(),
    conectividad: ConectividadSistema(),
    sintetizador: SintetizadorSistema(),
    motorVoz: const MotorDeVozPendiente(),
    vibrador: VibradorSistema(),
    sonido: SonidoSistema(),
    permisos: PermisosSistema(),
    notificador: NotificadorRegistro(),
    leerActivo: (ruta) async => (await rootBundle.load(ruta)).buffer.asUint8List(),
  );
  runApp(ProviderScope(overrides: [dependenciasProvider.overrideWithValue(deps)], child: const VtmApp()));
}
