import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Perfil y ajustes (M54–M56, M60–M61, T07).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Perfil');
}

class PantallaAjustesVoz extends StatelessWidget {
  const PantallaAjustesVoz({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Voz');
}

class PantallaAccesibilidad extends StatelessWidget {
  const PantallaAccesibilidad({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Accesibilidad y apariencia');
}

class PantallaSincronizacion extends StatelessWidget {
  const PantallaSincronizacion({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Descargas y sincronización');
}

class PantallaPrivacidad extends StatelessWidget {
  const PantallaPrivacidad({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Privacidad');
}

class PantallaLegal extends StatelessWidget {
  const PantallaLegal({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Legal');
}

class PantallaMetaAjustes extends StatelessWidget {
  const PantallaMetaAjustes({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Meta y recordatorios');
}

class PantallaItinerario extends StatelessWidget {
  const PantallaItinerario({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Mi itinerario');
}

class PantallaOrganizacion extends StatelessWidget {
  const PantallaOrganizacion({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Organización');
}
