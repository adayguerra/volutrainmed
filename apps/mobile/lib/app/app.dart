import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'estado/ajustes.dart';
import 'estado/estado_app.dart';
import '../core/sync/sincronizador.dart';
import 'router.dart';
import 'tema.dart';

const textoSinConexion = 'Sin conexión. Puedes seguir entrenando';

/// Raíz de la app: tema claro u oscuro, tamaño de texto adicional, movimiento
/// reducido y aviso único al perder la conexión.
class VtmApp extends ConsumerWidget {
  const VtmApp({super.key});

  static final mensajero = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arranque = ref.watch(arranqueProvider);
    final ajustes = ref.watch(ajustesProvider);
    ref.listen(conexionProvider, (prev, next) {
      final antes = prev?.value;
      final ahora = next.value;
      if (antes == true && ahora == false) {
        mensajero.currentState?.showSnackBar(const SnackBar(content: Text(textoSinConexion)));
      }
    });

    Widget envolver(BuildContext context, Widget? child) {
      final mq = MediaQuery.of(context);
      final escala = mq.textScaler.scale(1) * (1 + ajustes.textoExtra);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: TextScaler.linear(escala.clamp(1.0, 3.0)),
          disableAnimations: mq.disableAnimations || ajustes.reducirMovimiento,
        ),
        child: child ?? const SizedBox.shrink(),
      );
    }

    final temaClaro = construirTema(Brightness.light, altoContraste: ajustes.altoContraste);
    final temaOscuro = construirTema(Brightness.dark, altoContraste: ajustes.altoContraste);
    const locales = [Locale('es', 'ES')];
    const delegados = [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate];

    if (!arranque.hasValue) {
      return MaterialApp(
        title: 'VolutrainMed',
        debugShowCheckedModeBanner: false,
        theme: temaClaro,
        darkTheme: temaOscuro,
        themeMode: ajustes.tema,
        locale: locales.first,
        supportedLocales: locales,
        localizationsDelegates: delegados,
        home: Scaffold(
          body: Center(
            child: arranque.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No se ha podido abrir el contenido del dispositivo. Reinstala la app o escribe a soporte.\n\n${arranque.error}', textAlign: TextAlign.center),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }
    // Sincronización automática al arrancar y al recuperar la conexión.
    ref.watch(sincronizacionAutomaticaProvider);
    return MaterialApp.router(
      title: 'VolutrainMed',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: mensajero,
      theme: temaClaro,
      darkTheme: temaOscuro,
      themeMode: ajustes.tema,
      locale: locales.first,
      supportedLocales: locales,
      localizationsDelegates: delegados,
      routerConfig: ref.watch(routerProvider),
      builder: envolver,
    );
  }
}
