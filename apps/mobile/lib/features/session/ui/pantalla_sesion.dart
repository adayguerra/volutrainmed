import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Sesión de ejercicios, corrección y fin de lección (M17–M31, T02, T03, T06).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaSesion extends StatelessWidget {
  const PantallaSesion({super.key, required this.parametros});
  final Map<String, String> parametros;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Sesión');
}
