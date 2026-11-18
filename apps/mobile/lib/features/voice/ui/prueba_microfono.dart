import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/dependencias.dart';
import '../../../app/tema.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/plataforma/plataforma.dart';
import '../domain/analizador.dart';

/// Prueba de micrófono de los ajustes de voz (M55): el usuario dice «cuatro
/// coma ocho mililitros por hora» y ve la cifra entendida. Se reconoce solo
/// en el dispositivo; no se guarda audio ni texto.
class PruebaMicrofono extends ConsumerStatefulWidget {
  const PruebaMicrofono({super.key});

  static const frase = 'Di «cuatro coma ocho mililitros por hora».';
  static const sinMotor = 'Sin reconocimiento en el dispositivo no hay prueba de micrófono. En manos libres puedes responder con el teclado y los botones.';

  @override
  ConsumerState<PruebaMicrofono> createState() => _PruebaMicrofonoState();
}

class _PruebaMicrofonoState extends ConsumerState<PruebaMicrofono> {
  bool _escuchando = false;
  String? _resultado;
  bool _bien = false;

  Future<void> _probar() async {
    final deps = ref.read(dependenciasProvider);
    setState(() {
      _escuchando = true;
      _resultado = null;
    });
    var permiso = await deps.permisos.estadoMicrofono();
    if (permiso != EstadoPermiso.concedido) permiso = await deps.permisos.pedirMicrofono();
    if (permiso != EstadoPermiso.concedido) {
      return _mostrar('Sin permiso de micrófono. Actívalo en los ajustes del sistema; la app funciona entera sin él.', false);
    }
    EventoVoz? ev;
    try {
      ev = await deps.motorVoz.escuchar().first;
    } on StateError {
      ev = null; // La escucha terminó sin eventos.
    }
    await deps.motorVoz.parar();
    switch (ev) {
      case VozTexto(:final texto):
        final r = parseSpoken(texto);
        if (r is SpokenNumber) {
          _mostrar('Entendido: ${formatQty(r.value, r.unit ?? '')}'.trim(), true);
        } else {
          _mostrar('No he entendido una cifra. Inténtalo de nuevo.', false);
        }
      case VozSilencio():
        _mostrar('No te he oído. Inténtalo de nuevo.', false);
      case VozRuido():
        _mostrar('Hay mucho ruido. Acerca el micrófono.', false);
      default:
        _mostrar(deps.motorVoz.disponible ? 'No te he entendido. Inténtalo de nuevo.' : (deps.motorVoz.motivoNoDisponible ?? PruebaMicrofono.sinMotor), false);
    }
  }

  void _mostrar(String texto, bool bien) {
    if (!mounted) return;
    setState(() {
      _escuchando = false;
      _resultado = texto;
      _bien = bien;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final motor = ref.watch(dependenciasProvider).motorVoz;
    if (!motor.disponible && _resultado == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(motor.motivoNoDisponible ?? PruebaMicrofono.sinMotor, style: context.textos.bodyMedium?.copyWith(color: c.atenuado)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(PruebaMicrofono.frase, style: context.textos.bodyMedium),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('probar-microfono'),
            onPressed: _escuchando ? null : _probar,
            icon: const Icon(Symbols.mic),
            label: Text(_escuchando ? 'Te escucho…' : 'Probar el micrófono'),
          ),
          if (_resultado != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Row(children: [
                Icon(_bien ? Symbols.check_circle : Symbols.info, color: _bien ? c.exito : c.aviso),
                const SizedBox(width: 8),
                Expanded(child: Text(_resultado!, style: context.textos.bodyMedium)),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          Text('El audio se reconoce en este dispositivo y no se guarda ni se envía.', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
        ],
      ),
    );
  }
}
