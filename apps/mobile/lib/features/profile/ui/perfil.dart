import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/ajustes.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/contenido/repositorio_contenido.dart' show versionApp;
import '../../../core/sync/sincronizador.dart';
import '../../subscription/domain/entitlements_policy.dart';
import 'comunes_perfil.dart';

const textoRecordatorioCuenta = 'Crea tu cuenta para no perder tu progreso';

/// Perfil (M54): alias, itinerario, nivel y acceso a todos los ajustes.
class PantallaPerfil extends ConsumerWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.vtm;
    final u = ref.watch(usuarioProvider).value;
    final contenido = ref.watch(contenidoProvider).value;
    final p = ref.watch(proyeccionProvider);
    final ajustes = ref.watch(ajustesProvider);
    final derechos = ref.watch(derechosProvider);
    final ahora = ref.watch(dependenciasProvider).reloj.ahora();
    final sync = ref.watch(sincronizadorProvider);
    final perfil = u?.perfil;
    final alias = perfil?.alias ?? 'Perfil local';
    final itinerario = contenido?.resumenItinerario(perfil?.itineraryId)?.name ?? contenido?.fundamentos?.itinerary.name ?? '';
    final iniciales = alias.isEmpty ? '?' : alias.characters.take(2).toString().toUpperCase();
    final sus = estadoParaPerfil(derechos, ahora);
    final meta = perfil?.goal;
    final textoMeta = meta == null
        ? 'Sin meta'
        : (meta.minutes != null ? '${meta.minutes} min al día' : '${meta.days} días por semana') + (ajustes.recordatorio == null ? '' : ' · aviso a las ${ajustes.recordatorio}');

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), actions: const [Padding(padding: EdgeInsets.only(right: 16), child: DistintivoSinConexion())]),
      body: AnchoMaximo(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: c.primarioTinte,
                    child: Text(iniciales, style: context.textos.titleMedium?.copyWith(color: c.primario)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alias, style: context.textos.titleLarge),
                      Text('$itinerario · nivel ${p?.nivel.nivel ?? 1}', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                    ],
                  ),
                ),
                Semantics(
                  label: '${p?.puntosTotales ?? 0} puntos',
                  excludeSemantics: true,
                  child: Text('${p?.puntosTotales ?? 0}', style: estiloCifra(context, size: 22, color: c.primario)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (u != null && !u.conCuenta) ...[
              Tarjeta(
                tinte: true,
                onTap: () => context.push(Rutas.cuenta),
                semantica: textoRecordatorioCuenta,
                child: Row(
                  children: [
                    Icon(Symbols.cloud_upload, color: c.primario),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(textoRecordatorioCuenta, style: context.textos.titleSmall),
                          Text('Tu progreso está guardado solo en este dispositivo.', style: context.textos.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Symbols.chevron_right, color: c.primario),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            BloqueAjustes(hijos: [
              FilaAjuste(icono: Symbols.route, titulo: 'Mi itinerario', detalle: itinerario, onTap: () => context.push(Rutas.itinerario)),
              FilaAjuste(icono: Symbols.flag, titulo: 'Meta y recordatorios', detalle: textoMeta, onTap: () => context.push(Rutas.meta)),
              FilaAjuste(icono: Symbols.record_voice_over, titulo: 'Voz', detalle: 'Lectura y reconocimiento en el dispositivo', onTap: () => context.push(Rutas.voz)),
              FilaAjuste(
                icono: Symbols.accessibility_new,
                titulo: 'Accesibilidad y apariencia',
                detalle: switch (ajustes.tema) { ThemeMode.light => 'Tema claro', ThemeMode.dark => 'Tema oscuro', ThemeMode.system => 'Tema del sistema' },
                onTap: () => context.push(Rutas.accesibilidad),
              ),
            ]),
            BloqueAjustes(hijos: [
              FilaAjuste(
                icono: Symbols.workspace_premium,
                titulo: 'Suscripción',
                detalle: [sus.titulo, ?sus.detalle, if (sus.gestionable) 'Gestionar en la tienda'].join(' · '),
                onTap: () => context.push(Rutas.suscripcion),
              ),
              FilaAjuste(
                icono: Symbols.apartment,
                titulo: 'Organización',
                detalle: derechos.organization?.name ?? 'Unirse con un código',
                onTap: () => context.push(Rutas.organizacion),
              ),
              ValueListenableBuilder(
                valueListenable: sync.estado,
                builder: (context, e, _) => FilaAjuste(
                  icono: Symbols.sync,
                  titulo: 'Descargas y sincronización',
                  detalle: e.error ?? (e.ultima == null ? (u?.conCuenta == true ? 'Pendiente de sincronizar' : 'Solo en este dispositivo') : 'Sincronizado ${fechaRelativa(e.ultima!, ahora)}'),
                  onTap: () => context.push(Rutas.sincronizacion),
                ),
              ),
            ]),
            BloqueAjustes(hijos: [
              FilaAjuste(icono: Symbols.contact_support, titulo: 'Consulta y ayuda', detalle: 'Avisar de un error o plantear una duda', onTap: () => context.push(Rutas.consultas)),
              FilaAjuste(icono: Symbols.shield_person, titulo: 'Privacidad', detalle: 'Exportar o eliminar tus datos', onTap: () => context.push(Rutas.privacidad)),
              FilaAjuste(icono: Symbols.gavel, titulo: 'Legal', detalle: 'Aviso formativo, términos y privacidad', onTap: () => context.push(Rutas.legal)),
            ]),
            if (u?.conCuenta == true)
              OutlinedButton.icon(
                onPressed: () => _cerrarSesion(context, ref),
                icon: const Icon(Symbols.logout),
                label: const Text('Cerrar sesión'),
              ),
            const SizedBox(height: 16),
            Center(
              child: Text('App $versionApp · Contenido ${contenido?.version ?? '—'}', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se borrará el progreso guardado en este dispositivo. Lo recuperarás al volver a entrar con tu cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    // Antes de borrar, se intenta subir lo pendiente.
    await ref.read(sincronizadorProvider).sincronizar(forzar: true);
    await ref.read(dependenciasProvider).aprendizaje.borrarTodo();
    await ref.read(aprendizajeProvider.notifier).recargar();
    await ref.read(usuarioProvider.notifier).cerrarSesion();
  }
}
