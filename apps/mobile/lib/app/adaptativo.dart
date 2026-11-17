import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'tema.dart';

/// Clases de ancho (adaptive-accessible-ui): compacta < 600 dp, media de 600 a
/// 839 dp y expandida ≥ 840 dp.
enum ClaseAncho {
  compacta,
  media,
  expandida;

  static ClaseAncho deAncho(double w) => w < 600 ? compacta : (w < 840 ? media : expandida);
  static ClaseAncho de(BuildContext context) => deAncho(MediaQuery.sizeOf(context).width);

  bool get dosPaneles => this != compacta;
}

/// Ancho máximo del texto de lectura en tablet.
const anchoLectura = 640.0;

/// Ancho máximo del teclado numérico en tablet.
const anchoTeclado = 420.0;

/// Ancho máximo de la tarjeta de la pausa promocional en tablet.
const anchoTarjetaAnuncio = 560.0;

/// Limita el ancho del contenido de lectura y lo centra.
class AnchoMaximo extends StatelessWidget {
  const AnchoMaximo({super.key, this.ancho = anchoLectura, required this.child, this.alineacion = Alignment.topCenter});
  final double ancho;
  final Widget child;
  final Alignment alineacion;
  @override
  Widget build(BuildContext context) => Align(
        alignment: alineacion,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: ancho), child: child),
      );
}

/// Dos paneles en tablet; un panel (el principal) en móvil.
class DosPaneles extends StatelessWidget {
  const DosPaneles({super.key, required this.principal, required this.secundario, this.proporcion = 0.5});
  final Widget principal;
  final Widget? secundario;
  final double proporcion;
  @override
  Widget build(BuildContext context) {
    if (!ClaseAncho.de(context).dosPaneles || secundario == null) return principal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: (proporcion * 100).round(), child: principal),
        VerticalDivider(width: 1, color: context.vtm.borde),
        Expanded(flex: ((1 - proporcion) * 100).round(), child: secundario!),
      ],
    );
  }
}

/// Destinos de la navegación principal.
class Destino {
  const Destino(this.etiqueta, this.icono, this.ruta);
  final String etiqueta;
  final IconData icono;
  final String ruta;
}

const destinos = [
  Destino('Inicio', Symbols.home, '/inicio'),
  Destino('Practicar', Symbols.fitness_center, '/practicar'),
  Destino('Progreso', Symbols.monitoring, '/progreso'),
  Destino('Ligas', Symbols.trophy, '/ligas'),
  Destino('Perfil', Symbols.person, '/perfil'),
];

/// Armazón con barra inferior (compacta) o carril lateral (media y expandida).
class ArmazonPrincipal extends StatelessWidget {
  const ArmazonPrincipal({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _ir(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final clase = ClaseAncho.de(context);
    if (clase == ClaseAncho.compacta) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _ir,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [for (final d in destinos) NavigationDestination(icon: Icon(d.icono), selectedIcon: Icon(d.icono, fill: 1), label: d.etiqueta)],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _ir,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Icon(Symbols.vaccines, color: context.vtm.primario, semanticLabel: 'VolutrainMed'),
              ),
              destinations: [for (final d in destinos) NavigationRailDestination(icon: Icon(d.icono), selectedIcon: Icon(d.icono, fill: 1), label: Text(d.etiqueta))],
            ),
            VerticalDivider(width: 1, color: context.vtm.borde),
            Expanded(child: shell),
          ],
        ),
      ),
    );
  }
}
