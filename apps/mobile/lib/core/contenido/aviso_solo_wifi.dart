import 'package:flutter/material.dart';

import 'actualizador.dart';

/// Ejecuta una descarga pedida por el usuario respetando «Descargar solo con
/// wifi»: si la conexión es de datos móviles explica el motivo y ofrece
/// «Descargar ahora con datos». Si el usuario no lo autoriza se relanza
/// [SoloWifi].
Future<T> descargarRespetandoWifi<T>(BuildContext context, Future<T> Function(bool conDatos) descarga) async {
  try {
    return await descarga(false);
  } on SoloWifi {
    if (!context.mounted) rethrow;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descarga con datos móviles'),
        content: const Text(textoSoloWifi),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Esperar a la wifi')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Descargar ahora con datos')),
        ],
      ),
    );
    if (ok != true) rethrow;
    return descarga(true);
  }
}
