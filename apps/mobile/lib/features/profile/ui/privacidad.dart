import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/tema.dart';
import '../../../core/data/api_client.dart';
import '../../../core/plataforma/archivos.dart';
import 'comunes_perfil.dart';

/// Aviso formativo, incluido en la app (se lee sin conexión).
const avisoFormativo = 'VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.';
const puntosAvisoFormativo = [
  'Todos los casos son simulados.',
  'La pauta viene siempre en el enunciado.',
  'Tú calculas y la app corrige. Nunca calcula por ti.',
];

const textoSolicitudExportacion = 'Solicitud recibida. Preparamos tu archivo';
const textoArchivoListo = 'Tu archivo está listo';
const textoConfirmarEliminar = 'ELIMINAR';

/// Privacidad (M61): exportar los datos y eliminar la cuenta.
class PantallaPrivacidad extends ConsumerStatefulWidget {
  const PantallaPrivacidad({super.key});
  @override
  ConsumerState<PantallaPrivacidad> createState() => _PantallaPrivacidadState();
}

enum _Exportacion { nada, pedida, lista, error }

class _PantallaPrivacidadState extends ConsumerState<PantallaPrivacidad> {
  _Exportacion _exp = _Exportacion.nada;
  Map<String, dynamic>? _archivo;
  String? _error;
  ArchivoGuardado? _guardado;
  String? _avisoArchivo;

  /// Nombre del archivo exportado: `volutrainmed-datos-AAAA-MM-DD.json`.
  String _nombreArchivo() {
    final h = ref.read(dependenciasProvider).reloj.ahora();
    String d(int n) => n.toString().padLeft(2, '0');
    return 'volutrainmed-datos-${h.year}-${d(h.month)}-${d(h.day)}.json';
  }

  /// Guarda el archivo (descarga en la web, documentos de la app en el
  /// móvil) y, si se pide y es posible, abre la hoja de compartir.
  Future<void> _guardarArchivo({bool compartir = false}) async {
    final f = _archivo;
    if (f == null) return;
    final guardador = ref.read(guardadorArchivosProvider);
    try {
      final g = _guardado ?? await guardador.guardar(_nombreArchivo(), const JsonEncoder.withIndent('  ').convert(f));
      if (compartir) await guardador.compartir(g, asunto: 'Mis datos de VolutrainMed');
      if (!mounted) return;
      setState(() {
        _guardado = g;
        _avisoArchivo = g.ruta == null ? 'Archivo ${g.nombre} descargado.' : 'Guardado como ${g.nombre} en los documentos de la app.';
      });
    } catch (_) {
      if (mounted) setState(() => _avisoArchivo = 'No se ha podido guardar el archivo. Puedes copiarlo.');
    }
  }

  Future<void> _exportar() async {
    final deps = ref.read(dependenciasProvider);
    final u = ref.read(usuarioProvider).value!;
    setState(() {
      _exp = _Exportacion.pedida;
      _error = null;
    });
    if (!u.conCuenta) {
      // Perfil local: el archivo se genera en el dispositivo.
      final d = ref.read(aprendizajeProvider).value;
      _listo({
        'profile': u.perfil?.toJson(),
        'attempts': [for (final a in d?.intentos ?? const []) a.toJson()],
        'sessions': [for (final s in d?.sesiones ?? const []) s.toJson()],
        'inquiries': [for (final c in await deps.aprendizaje.consultas()) c.json],
      });
      return;
    }
    try {
      final r = await deps.api.exportRequest();
      final id = '${r['requestId']}';
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration(milliseconds: i == 0 ? 300 : 1000));
        if (!mounted) return;
        final s = await deps.api.exportStatus(id);
        if (s['status'] == 'ready') {
          _listo((s['file'] as Map?)?.cast<String, dynamic>() ?? const {});
          return;
        }
      }
      setState(() => _error = 'El archivo tarda más de lo previsto. Vuelve a intentarlo en unos minutos.');
    } on SinConexionException {
      setState(() {
        _exp = _Exportacion.error;
        _error = 'Hace falta conexión para pedir la exportación.';
      });
    } on ApiException catch (e) {
      setState(() {
        _exp = _Exportacion.error;
        _error = e.message;
      });
    }
  }

  void _listo(Map<String, dynamic> f) {
    if (!mounted) return;
    setState(() {
      _exp = _Exportacion.lista;
      _archivo = f;
    });
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(context: context, builder: (_) => const DialogoEliminarCuenta());
    if (confirmado != true || !mounted) return;
    final deps = ref.read(dependenciasProvider);
    final u = ref.read(usuarioProvider).value!;
    final mensajero = ScaffoldMessenger.of(context);
    if (u.conCuenta) {
      try {
        await deps.api.deleteMe();
      } on SinConexionException {
        mensajero.showSnackBar(const SnackBar(content: Text('Hace falta conexión para eliminar la cuenta.')));
        return;
      } on ApiException catch (e) {
        mensajero.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      }
    }
    await deps.aprendizaje.borrarTodo();
    await ref.read(aprendizajeProvider.notifier).recargar();
    await ref.read(usuarioProvider.notifier).cerrarSesion();
    mensajero.showSnackBar(const SnackBar(content: Text('Cuenta eliminada. Tus datos personales se han suprimido.')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final f = _archivo;
    return AndamioAjustes(titulo: 'Privacidad', hijos: [
      BloqueAjustes(titulo: 'Tus datos', hijos: [
        FilaAjuste(
          icono: Symbols.download,
          titulo: 'Exportar mis datos',
          detalle: 'Tu perfil y tu historial de aprendizaje en un archivo',
          onTap: _exp == _Exportacion.pedida ? null : _exportar,
        ),
        if (_exp == _Exportacion.pedida)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Semantics(liveRegion: true, child: Text(_error ?? textoSolicitudExportacion, style: context.textos.bodyMedium)),
          ),
        if (_exp == _Exportacion.error)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(_error ?? '', style: context.textos.bodyMedium?.copyWith(color: c.errorFuerte)),
          ),
        if (_exp == _Exportacion.lista && f != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(liveRegion: true, child: Text(textoArchivoListo, style: context.textos.titleSmall?.copyWith(color: c.exito))),
                const SizedBox(height: 4),
                Text(
                  'Perfil, ${(f['attempts'] as List?)?.length ?? 0} intentos, ${(f['sessions'] as List?)?.length ?? 0} sesiones y ${(f['inquiries'] as List?)?.length ?? 0} consultas.',
                  style: context.textos.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _guardarArchivo,
                      icon: const Icon(Symbols.download),
                      label: const Text('Guardar el archivo'),
                    ),
                    if (ref.watch(guardadorArchivosProvider).puedeCompartir)
                      OutlinedButton.icon(
                        onPressed: () => _guardarArchivo(compartir: true),
                        icon: const Icon(Symbols.share),
                        label: const Text('Compartir'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(f))),
                      icon: const Icon(Symbols.content_copy),
                      label: const Text('Copiar'),
                    ),
                  ],
                ),
                if (_avisoArchivo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Semantics(liveRegion: true, child: Text(_avisoArchivo!, style: context.textos.bodySmall)),
                  ),
              ],
            ),
          ),
      ]),
      BloqueAjustes(titulo: 'Cuenta', hijos: [
        FilaAjuste(icono: Symbols.delete_forever, titulo: 'Eliminar cuenta', detalle: 'Se suprimen o anonimizan tus datos personales', onTap: _eliminar),
      ]),
    ]);
  }
}

/// Confirmación por escrito: hay que teclear ELIMINAR.
class DialogoEliminarCuenta extends StatefulWidget {
  const DialogoEliminarCuenta({super.key});
  @override
  State<DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<DialogoEliminarCuenta> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valido => _ctrl.text.trim().toUpperCase() == textoConfirmarEliminar;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return AlertDialog(
      title: const Text('Eliminar la cuenta'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Se borrarán tu progreso, tus rachas y tus consultas. No se puede deshacer.'),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Escribe ELIMINAR para confirmar'),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: c.errorFuerte, foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: _valido ? () => Navigator.pop(context, true) : null,
          child: const Text('Eliminar la cuenta'),
        ),
      ],
    );
  }
}

/// Legal: aviso formativo completo, términos y privacidad. Va incluido en la
/// app y se lee sin conexión.
class PantallaLegal extends StatelessWidget {
  const PantallaLegal({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return AndamioAjustes(titulo: 'Legal', hijos: [
      BloqueAjustes(titulo: 'Aviso formativo', hijos: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Symbols.school, color: c.primario),
                const SizedBox(width: 8),
                Expanded(child: Text('Esto es un entrenamiento', style: context.textos.titleMedium)),
              ]),
              const SizedBox(height: 12),
              Text(avisoFormativo, style: context.textos.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final p in puntosAvisoFormativo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Symbols.check, size: 20, color: c.exito),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p, style: context.textos.bodyMedium)),
                  ]),
                ),
            ],
          ),
        ),
      ]),
      BloqueAjustes(titulo: 'Términos de uso', hijos: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'VolutrainMed ofrece ejercicios formativos de cálculo de dosis y volúmenes con casos simulados, validados por profesionales. '
            'No es un producto sanitario ni una calculadora clínica, y no debe usarse para decidir tratamientos de pacientes reales. '
            'No respondemos consultas sobre pacientes ni tratamientos.',
            style: context.textos.bodyMedium,
          ),
        ),
      ]),
      BloqueAjustes(titulo: 'Privacidad', hijos: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Guardamos tu alias, tu correo si creas una cuenta y tu historial de aprendizaje para sincronizar tu progreso. '
            'La voz se procesa en el dispositivo: no se envían ni se guardan audio ni transcripciones. '
            'Los anuncios son propios, sin redes publicitarias ni identificadores publicitarios. '
            'Puedes exportar o eliminar tus datos desde Perfil › Privacidad.',
            style: context.textos.bodyMedium,
          ),
        ),
      ]),
    ]);
  }
}
