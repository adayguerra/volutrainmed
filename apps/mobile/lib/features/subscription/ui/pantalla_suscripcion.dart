import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Suscripción Premium (M57).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaSuscripcion extends StatelessWidget {
  const PantallaSuscripcion({super.key, this.anuncioId});
  final String? anuncioId;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Suscripción');
}
