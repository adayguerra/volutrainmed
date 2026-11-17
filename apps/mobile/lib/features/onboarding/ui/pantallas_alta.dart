import 'package:flutter/material.dart';

import '../../../app/widgets/comunes.dart';

/// Alta: bienvenida, sector, nivel, meta, aviso formativo, prueba de nivel, descarga y permisos (M01–M11, T08).
/// Pantallas provisionales: se sustituyen por las definitivas.

class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Bienvenida');
}

class PantallaSector extends StatelessWidget {
  const PantallaSector({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Sector');
}

class PantallaNivel extends StatelessWidget {
  const PantallaNivel({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Nivel');
}

class PantallaMeta extends StatelessWidget {
  const PantallaMeta({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Meta');
}

class PantallaAviso extends StatelessWidget {
  const PantallaAviso({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Aviso formativo');
}

class PantallaPruebaNivel extends StatelessWidget {
  const PantallaPruebaNivel({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Prueba de nivel');
}

class PantallaResultadoPrueba extends StatelessWidget {
  const PantallaResultadoPrueba({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Resultado de la prueba');
}

class PantallaDescarga extends StatelessWidget {
  const PantallaDescarga({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Preparando tu itinerario');
}

class PantallaPermisoNotificaciones extends StatelessWidget {
  const PantallaPermisoNotificaciones({super.key});
  @override
  Widget build(BuildContext context) => const PantallaPendiente('Recordatorio');
}
