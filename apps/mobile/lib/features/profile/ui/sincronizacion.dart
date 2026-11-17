import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/ajustes.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/contenido/actualizador.dart';
import '../../../core/contenido/repositorio_contenido.dart' show textoActualizaApp;
import '../../../core/data/almacenes.dart';
import '../../../core/sync/sincronizador.dart';
import 'comunes_perfil.dart';

/// Texto del estado de la sincronización: «Sincronizado · hoy, 19:42 ·
/// 0 elementos pendientes».
String textoEstadoSync(EstadoSync e, {required bool conCuenta, required DateTime ahora}) {
  final pend = '${e.pendientes} ${e.pendientes == 1 ? 'elemento pendiente' : 'elementos pendientes'}';
  if (e.sincronizando) return 'Sincronizando… · $pend';
  if (!conCuenta) return 'Solo en este dispositivo · $pend';
  if (e.ultima == null) return 'Sin sincronizar · $pend';
  return 'Sincronizado · ${fechaRelativa(e.ultima!, ahora)} · $pend';
}

/// Descargas y sincronización (M60).
class PantallaSincronizacion extends ConsumerStatefulWidget {
  const PantallaSincronizacion({super.key});
  @override
  ConsumerState<PantallaSincronizacion> createState() => _PantallaSincronizacionState();
}

class _PantallaSincronizacionState extends ConsumerState<PantallaSincronizacion> {
  List<PaqueteGuardado> _paquetes = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await ref.read(sincronizadorProvider).refrescar();
    final p = await ref.read(dependenciasProvider).contenido.paquetes();
    if (mounted) setState(() => _paquetes = p);
  }

  Future<void> _descargar(String id) async {
    final act = ref.read(actualizadorProvider);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await act.descargarItinerario(id);
      await act.aplicarPreparadas();
    } catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text('$e')));
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(sincronizadorProvider);
    final act = ref.watch(actualizadorProvider);
    final u = ref.watch(usuarioProvider).value;
    final contenido = ref.watch(contenidoProvider).value;
    final ajustes = ref.watch(ajustesProvider);
    final enLinea = ref.watch(enLineaProvider);
    final ahora = ref.watch(dependenciasProvider).reloj.ahora();
    final c = context.vtm;
    final usado = _paquetes.fold<int>(0, (s, p) => s + p.gz.length);

    return AndamioAjustes(titulo: 'Descargas y sincronización', hijos: [
      ValueListenableBuilder(
        valueListenable: sync.estado,
        builder: (context, e, _) => BloqueAjustes(hijos: [
          FilaAjuste(
            icono: e.error != null ? Symbols.sync_problem : Symbols.cloud_done,
            titulo: e.error != null ? 'Pendiente de sincronizar' : 'Progreso',
            detalle: textoEstadoSync(e, conCuenta: u?.conCuenta == true, ahora: ahora),
          ),
          if (e.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Semantics(liveRegion: true, child: Text(e.error!, style: context.textos.bodyMedium?.copyWith(color: c.errorFuerte))),
            ),
          if (u?.conCuenta != true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Tu progreso se guarda en el dispositivo. Crea tu cuenta para sincronizarlo con otros dispositivos.', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: e.sincronizando || !enLinea ? null : () => sync.sincronizar(forzar: true).then((_) => _cargar()),
              icon: const Icon(Symbols.sync),
              label: Text(enLinea ? 'Sincronizar ahora' : 'Sin conexión'),
            ),
          ),
        ]),
      ),
      ValueListenableBuilder(
        valueListenable: act.estado,
        builder: (context, e, _) => BloqueAjustes(titulo: 'Contenido descargado', hijos: [
          if ((e.avisoAppAntigua ?? contenido?.avisoAppAntigua) != null)
            FilaAjuste(icono: Symbols.system_update, titulo: textoActualizaApp, detalle: 'Mientras, sigues con el contenido compatible.'),
          if (contenido != null)
            for (final it in contenido.global.itineraries)
              _filaItinerario(context, it.id, it.name, e),
          if (e.preparada != null)
            FilaAjuste(icono: Symbols.new_releases, titulo: 'Versión ${e.preparada} lista', detalle: 'Se aplicará al empezar la próxima sesión.'),
        ]),
      ),
      BloqueAjustes(titulo: 'Preferencias', hijos: [
        FilaInterruptor(
          titulo: 'Descargar solo con wifi',
          detalle: 'Contenido y voz',
          valor: ajustes.soloWifi,
          alCambiar: (v) => ref.read(ajustesProvider.notifier).cambiar((x) => x.copyWith(soloWifi: v)),
        ),
        FilaAjuste(icono: Symbols.storage, titulo: 'Espacio usado', detalle: tamanoLegible(usado)),
      ]),
    ]);
  }

  Widget _filaItinerario(BuildContext context, String id, String nombre, EstadoActualizacion e) {
    final activo = _paquetes.where((p) => p.clave == id && p.status == 'active').firstOrNull;
    final enUso = ref.read(contenidoProvider).value?.itinerario(id);
    final descargando = e.descargando == id;
    if (activo != null || enUso != null) {
      final version = activo?.version ?? enUso!.contentVersion;
      return FilaAjuste(
        icono: Symbols.download_done,
        titulo: nombre,
        detalle: [if (activo != null) tamanoLegible(activo.gz.length), 'versión $version'].join(' · '),
        final_: const Etiqueta('Actualizado', tono: TonoEtiqueta.exito),
      );
    }
    return FilaAjuste(
      icono: Symbols.download,
      titulo: nombre,
      detalle: descargando ? 'Descargando… ${((e.fraccion ?? 0) * 100).round()} %' : 'No descargado',
      final_: TextButton(onPressed: descargando ? null : () => _descargar(id), child: const Text('Descargar')),
    );
  }
}
