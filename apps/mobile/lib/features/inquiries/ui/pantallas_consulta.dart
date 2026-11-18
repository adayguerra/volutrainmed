import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/data/almacenes.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/sync/sincronizador.dart';
import '../domain/consultas.dart';

/// Formulario de consulta (M58). Aviso fijo: no se atienden consultas sobre
/// pacientes. Desde un ejercicio llega con el ejercicio ya adjunto.
class PantallaConsulta extends ConsumerStatefulWidget {
  const PantallaConsulta({super.key, this.adjunto});
  final Map<String, dynamic>? adjunto;
  @override
  ConsumerState<PantallaConsulta> createState() => _PantallaConsultaState();
}

class _PantallaConsultaState extends ConsumerState<PantallaConsulta> {
  late String _tipo;
  final _mensaje = TextEditingController();
  late final TextEditingController _correo;
  bool _enviando = false;

  Map<String, dynamic>? get _ejercicio => ejercicioAdjunto(widget.adjunto);

  @override
  void initState() {
    super.initState();
    _tipo = _ejercicio != null ? 'exercise_error' : 'explanation_doubt';
    _correo = TextEditingController(text: ref.read(usuarioProvider).value?.perfil?.email ?? '');
  }

  @override
  void dispose() {
    _mensaje.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final deps = ref.read(dependenciasProvider);
    final c = await guardarConsulta(
      almacen: deps.aprendizaje,
      reloj: deps.reloj,
      tipo: _tipo,
      mensaje: _mensaje.text,
      correo: _correo.text,
      ejercicio: _ejercicio,
    );
    // Se intenta enviar ya; sin conexión queda pendiente y se envía después.
    await ref.read(sincronizadorProvider).sincronizar(forzar: true);
    if (!mounted) return;
    context.pushReplacement(Uri(path: Rutas.consultas, queryParameters: {'enviada': c.id}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final ej = _ejercicio;
    final respuesta = ej?['answerValue'] == null ? null : formatQty('${ej!['answerValue']}', '${ej['answerUnit'] ?? ''}').trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta')),
      body: AnchoMaximo(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.avisoTinte, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Symbols.info, color: c.aviso),
                const SizedBox(width: 8),
                Expanded(child: Text('$textoSinConsultasClinicas.', style: context.textos.bodyMedium?.copyWith(color: c.aviso, fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 16),
            const TituloSeccion('Tipo'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in tiposConsulta.entries)
                ChoiceChip(
                  label: Text(t.value),
                  selected: _tipo == t.key,
                  onSelected: (_) => setState(() => _tipo = t.key),
                  selectedColor: c.primarioTinte,
                ),
            ]),
            if (ej != null) ...[
              const SizedBox(height: 16),
              const TituloSeccion('Ejercicio adjunto'),
              Tarjeta(
                tinte: true,
                child: Row(children: [
                  Icon(Symbols.attach_file, color: c.primario),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [widget.adjunto?['etiqueta'] ?? ej['templateId'] ?? ej['questionId'] ?? 'Ejercicio', ej['variantId'], ?respuesta].join(' · '),
                      key: const ValueKey('ejercicio-adjunto'),
                      style: context.textos.bodyMedium,
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            const TituloSeccion('Mensaje'),
            TextField(
              controller: _mensaje,
              minLines: 4,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(hintText: 'Cuéntanos qué esperabas y qué viste.'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            const TituloSeccion('Correo de respuesta'),
            TextField(controller: _correo, keyboardType: TextInputType.emailAddress, autocorrect: false, decoration: const InputDecoration(hintText: 'Opcional')),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _mensaje.text.trim().isEmpty || _enviando ? null : _enviar,
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mis consultas (M59): estado de cada consulta, también las pendientes de
/// envío por falta de conexión.
class PantallaMisConsultas extends ConsumerStatefulWidget {
  const PantallaMisConsultas({super.key});
  @override
  ConsumerState<PantallaMisConsultas> createState() => _PantallaMisConsultasState();
}

class _PantallaMisConsultasState extends ConsumerState<PantallaMisConsultas> {
  List<ConsultaGuardada> _consultas = const [];
  late final ValueNotifierListener _escucha;

  @override
  void initState() {
    super.initState();
    _escucha = ValueNotifierListener(ref.read(sincronizadorProvider).estado, _cargar);
    _cargar();
  }

  @override
  void dispose() {
    _escucha.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final l = await ref.read(dependenciasProvider).aprendizaje.consultas();
    if (mounted) setState(() => _consultas = l);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final enviada = GoRouterState.of(context).uri.queryParameters['enviada'];
    final recien = _consultas.where((x) => x.id == enviada).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis consultas')),
      body: AnchoMaximo(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (recien != null) ...[
              Tarjeta(
                tinte: true,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    recien.status == 'pending'
                        ? 'Consulta guardada. Sin conexión: se enviará al conectar.'
                        : 'Consulta enviada. Referencia ${recien.reference ?? ''}. Te responderemos por correo.',
                    style: context.textos.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_consultas.isEmpty) Text('Aún no has enviado ninguna consulta.', style: context.textos.bodyMedium?.copyWith(color: c.atenuado)),
            for (final q in _consultas)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(tiposConsulta['${q.json['type']}'] ?? 'Consulta', style: context.textos.titleSmall)),
                        Etiqueta(
                          estadosConsulta[q.status] ?? q.status,
                          tono: switch (q.status) { 'pending' => TonoEtiqueta.aviso, 'answered' => TonoEtiqueta.exito, _ => TonoEtiqueta.primario },
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        q.status == 'pending' ? 'Sin enviar · se enviará al conectar' : 'Referencia ${q.reference ?? '—'}',
                        style: context.textos.bodySmall?.copyWith(color: c.atenuado),
                      ),
                      const SizedBox(height: 4),
                      Text('${q.json['message']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: context.textos.bodyMedium),
                      if (q.reply != null) ...[
                        const SizedBox(height: 8),
                        Text('Respuesta: ${q.reply}', style: context.textos.bodyMedium?.copyWith(color: c.primario)),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => context.push(Rutas.consulta), icon: const Icon(Symbols.edit), label: const Text('Nueva consulta')),
          ],
        ),
      ),
    );
  }
}

/// Escucha un `ValueListenable` y llama a [alCambiar] en cada cambio.
class ValueNotifierListener {
  ValueNotifierListener(this._fuente, this._alCambiar) {
    _fuente.addListener(_alCambiar);
  }
  final Listenable _fuente;
  final VoidCallback _alCambiar;
  void dispose() => _fuente.removeListener(_alCambiar);
}
