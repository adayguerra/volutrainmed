import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Progreso y detalle de habilidad (M50–M51, T05).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaProgreso extends StatelessWidget {
  const PantallaProgreso({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Progreso');
}

class PantallaHabilidad extends StatelessWidget {
  const PantallaHabilidad({super.key, required this.skillId});
  final String skillId;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Habilidad');
}
