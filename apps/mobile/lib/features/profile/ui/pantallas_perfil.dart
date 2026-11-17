import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

export 'ajustes.dart';
export 'perfil.dart';
export 'privacidad.dart';
export 'sincronizacion.dart';

/// Perfil y ajustes (M54–M56, M60–M61, T07).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaOrganizacion extends StatelessWidget {
  const PantallaOrganizacion({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Organización');
}
