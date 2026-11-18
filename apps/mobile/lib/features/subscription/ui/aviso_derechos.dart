import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../data/tienda.dart';

/// Al abrir la app: revalida los derechos si hay conexión y cuenta, programa
/// el recordatorio de fin de prueba y muestra una sola vez los avisos «Tu
/// Premium ha terminado» y «Conéctate para comprobar tu suscripción».
class AvisoDerechos extends ConsumerStatefulWidget {
  const AvisoDerechos({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AvisoDerechos> createState() => _AvisoDerechosState();
}

class _AvisoDerechosState extends ConsumerState<AvisoDerechos> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_comprobar()));
  }

  Future<void> _comprobar() async {
    if (await ref.read(dependenciasProvider).conectividad.hayConexion()) {
      await refrescarDerechos(ref.read);
    }
    await programarRecordatorioPrueba(ref.read, ref.read(derechosProvider));
    final avisos = await avisosDerechos(ref.read);
    if (!mounted) return;
    for (final a in avisos) {
      VtmApp.mensajero.currentState?.showSnackBar(SnackBar(content: Text(a), duration: const Duration(seconds: 6)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
