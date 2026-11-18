import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/contenido/actualizador.dart';
import '../../../core/contenido/aviso_solo_wifi.dart';
import '../../../core/data/api_client.dart';
import '../data/organizacion.dart';

/// Perfil › Organización: unirse con un código (con la vista previa de lo
/// que verá la organización), «Qué ve tu organización», itinerarios
/// asignados y salida.
class PantallaOrganizacion extends ConsumerStatefulWidget {
  const PantallaOrganizacion({super.key});
  @override
  ConsumerState<PantallaOrganizacion> createState() => _PantallaOrganizacionState();
}

class _PantallaOrganizacionState extends ConsumerState<PantallaOrganizacion> {
  final _codigo = TextEditingController();
  VistaPreviaOrg? _previa;
  bool _acepta = false;
  bool _ocupado = false;
  String? _error;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() f) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await f();
    } on ApiException catch (e) {
      _error = mensajeErrorOrg(e.code, e.message);
    } on SinConexionException {
      _error = 'Para unirte a una organización hace falta conexión';
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _comprobar() => _ejecutar(() async {
        final p = await previsualizarOrg(ref, _codigo.text);
        _previa = p;
        _acepta = false;
      });

  Future<void> _unirse() => _ejecutar(() async {
        await unirseOrg(ref, _codigo.text, aceptaNominal: _previa!.nominal && _acepta);
        _previa = null;
        _codigo.clear();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Te has unido a la organización')));
      });

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de la organización?'),
        content: const Text('Conservas todo tu progreso. Perderás la plaza y sus ventajas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salir')),
        ],
      ),
    );
    if (ok == true) await _ejecutar(() => salirOrg(ref));
  }

  Future<void> _usarItinerario(String id) async {
    final m = ScaffoldMessenger.of(context);
    await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(itineraryId: id));
    final act = ref.read(actualizadorProvider);
    try {
      final instalado = (await act.itinerariosInstalados()).contains(id);
      if (!instalado && mounted) {
        await descargarRespetandoWifi(context, (datos) => act.descargarItinerario(id, conDatos: datos));
        await act.aplicarPreparadas();
      }
      m.showSnackBar(const SnackBar(content: Text('Itinerario cambiado')));
    } on SoloWifi {
      m.showSnackBar(const SnackBar(content: Text('Itinerario elegido. Se descargará cuando haya wifi')));
    } catch (_) {
      m.showSnackBar(const SnackBar(content: Text('Itinerario elegido. Se descargará cuando haya conexión')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(orgProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Organización')),
      body: estado.when(
        loading: () => const Esqueleto(),
        error: (e, _) => Center(child: Text('$e')),
        data: (e) => ListView(
          padding: const EdgeInsets.all(16),
          children: [AnchoMaximo(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _contenido(context, e)))],
        ),
      ),
    );
  }

  List<Widget> _contenido(BuildContext context, EstadoOrg e) {
    final c = context.vtm;
    final out = <Widget>[];
    if (e.vigenciaTerminada && e.miembro == null) {
      out.addAll([
        Tarjeta(
          key: const ValueKey('vigencia-terminada'),
          child: Row(children: [
            Icon(Symbols.event_busy, color: c.aviso),
            const SizedBox(width: 12),
            Expanded(child: Text(textoVigenciaTerminada, style: context.textos.bodyMedium)),
          ]),
        ),
        const SizedBox(height: 16),
      ]);
    }
    if (e.sinCuenta) {
      out.addAll([
        Text(textoOrgSinCuenta, style: context.textos.bodyMedium),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.push(Rutas.cuenta), child: const Text('Crear mi cuenta')),
      ]);
      return out;
    }
    final m = e.miembro;
    if (m != null) {
      final actual = ref.watch(usuarioProvider).value?.perfil?.itineraryId;
      final contenido = ref.watch(contenidoProvider).value;
      out.addAll([
        Text(m.nombre, style: context.textos.headlineSmall),
        if (m.grupo != null) Text('Grupo: ${m.grupo}', style: context.textos.bodyMedium),
        const SizedBox(height: 8),
        Etiqueta(m.nominal ? 'Modo nominal: ve tus datos individuales' : 'Solo datos agregados del grupo',
            icono: m.nominal ? Symbols.person : Symbols.groups, tono: TonoEtiqueta.primario),
        const SizedBox(height: 16),
        const TituloSeccion('Qué ve tu organización'),
        Tarjeta(
          key: const ValueKey('que-ve'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final d in m.datosVisibles)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Symbols.visibility, size: 18, color: c.atenuado),
                  const SizedBox(width: 8),
                  Expanded(child: Text(d, style: context.textos.bodyMedium)),
                ]),
              ),
          ]),
        ),
        if (m.itinerariosAsignados.isNotEmpty) ...[
          const SizedBox(height: 16),
          const TituloSeccion('Itinerarios asignados'),
          for (final id in m.itinerariosAsignados)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tarjeta(
                key: ValueKey('asignado-$id'),
                tinte: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(contenido?.resumenItinerario(id)?.name ?? id, style: context.textos.titleSmall),
                  const SizedBox(height: 6),
                  const Align(alignment: Alignment.centerLeft, child: Etiqueta('Asignado por tu organización', icono: Symbols.star, tono: TonoEtiqueta.acento)),
                  const SizedBox(height: 8),
                  if (actual == id)
                    Text('Es tu itinerario actual', style: context.textos.bodySmall)
                  else
                    OutlinedButton(key: ValueKey('usar-$id'), onPressed: () => _usarItinerario(id), child: const Text('Usar este itinerario')),
                ]),
              ),
            ),
        ],
        if (e.desdeCache) ...[const SizedBox(height: 8), Text('Información guardada en el dispositivo', style: context.textos.bodySmall)],
        const SizedBox(height: 24),
        if (_error != null) ...[Text(_error!, key: const ValueKey('error-org'), style: TextStyle(color: c.errorFuerte)), const SizedBox(height: 8)],
        OutlinedButton(onPressed: _ocupado ? null : _salir, child: const Text('Salir de la organización')),
      ]);
      return out;
    }
    final p = _previa;
    out.addAll([
      Text('Unirse con un código', style: context.textos.titleLarge),
      const SizedBox(height: 8),
      Text('Escribe el código que te ha dado tu universidad, hospital o clínica. Antes de unirte verás qué datos tuyos verá.', style: context.textos.bodyMedium),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('campo-codigo'),
        controller: _codigo,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Código de invitación'),
        onChanged: (_) => setState(() => _previa = null),
      ),
      const SizedBox(height: 12),
      if (p == null)
        FilledButton(key: const ValueKey('comprobar-codigo'), onPressed: _ocupado ? null : _comprobar, child: const Text('Comprobar el código')),
      if (_error != null) ...[const SizedBox(height: 8), Text(_error!, key: const ValueKey('error-org'), style: TextStyle(color: c.errorFuerte))],
      if (p != null) ...[
        Tarjeta(
          key: const ValueKey('vista-previa-org'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p.nombre, style: context.textos.titleMedium),
            if (p.grupo != null) Text('Grupo: ${p.grupo}', style: context.textos.bodyMedium),
            const SizedBox(height: 12),
            Text(p.nominal ? 'Esta organización usa el modo nominal. Verá:' : 'La organización verá:', style: context.textos.titleSmall),
            const SizedBox(height: 4),
            for (final d in p.datosVisibles) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $d', style: context.textos.bodyMedium)),
            if (p.nominal) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey('aceptar-nominal'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _acepta,
                onChanged: (v) => setState(() => _acepta = v ?? false),
                title: const Text('Acepto que la organización vea estos datos'),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('unirse-org'),
              onPressed: _ocupado || (p.nominal && !_acepta) ? null : _unirse,
              child: const Text('Unirme'),
            ),
          ]),
        ),
      ],
    ]);
    return out;
  }
}

/// Aviso en Inicio del itinerario asignado por la organización.
class DestacadoOrganizacion extends ConsumerWidget {
  const DestacadoOrganizacion({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asignados = ref.watch(itinerariosAsignadosProvider).value ?? const [];
    final contenido = ref.watch(contenidoProvider).value;
    if (asignados.isEmpty || contenido == null) return const SizedBox.shrink();
    final actual = ref.watch(usuarioProvider).value?.perfil?.itineraryId;
    final nombres = asignados.map((id) => contenido.resumenItinerario(id)?.name ?? id).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tarjeta(
        key: const ValueKey('destacado-organizacion'),
        tinte: true,
        onTap: asignados.contains(actual) ? null : () => context.push(Rutas.organizacion),
        child: Row(children: [
          Icon(Symbols.star, color: context.vtm.acento),
          const SizedBox(width: 12),
          Expanded(child: Text('Asignado por tu organización: $nombres', style: context.textos.bodyMedium)),
        ]),
      ),
    );
  }
}
