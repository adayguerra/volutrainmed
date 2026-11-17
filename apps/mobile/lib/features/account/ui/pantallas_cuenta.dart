import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Cuenta: correo con código, Apple y Google (M02–M03).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaCuenta extends StatelessWidget {
  const PantallaCuenta({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Guarda tu progreso');
}

class PantallaCodigo extends StatelessWidget {
  const PantallaCodigo({super.key, required this.email});
  final String email;
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Revisa tu correo');
}
