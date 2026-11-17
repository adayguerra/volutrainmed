import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Consultas (M58–M59).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaConsulta extends StatelessWidget {
  const PantallaConsulta({super.key, this.adjunto});
  final Map<String, dynamic>? adjunto;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Consulta');
}

class PantallaMisConsultas extends StatelessWidget {
  const PantallaMisConsultas({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Mis consultas');
}
