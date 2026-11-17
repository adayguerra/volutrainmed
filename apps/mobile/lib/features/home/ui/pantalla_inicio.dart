import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Inicio con ruta, detalle de unidad y Practicar (M12–M16, T01).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Inicio');
}

class PantallaUnidad extends StatelessWidget {
  const PantallaUnidad({super.key, required this.unitId});
  final String unitId;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Unidad');
}

class PantallaPracticar extends StatelessWidget {
  const PantallaPracticar({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Practicar');
}
