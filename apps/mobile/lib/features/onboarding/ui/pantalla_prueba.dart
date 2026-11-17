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
import '../../../app/widgets/teclado.dart';
import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/ids.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../../grading/domain/grading.dart';
import '../domain/placement.dart';

/// Prueba de nivel (M08) y resultado (M09). Sin correcciones durante la
/// prueba, sin pausas promocionales y reanudable: el estado se guarda tras
/// cada respuesta en `EstadoUsuario.pruebaEnCurso`.

/// Itinerario sobre el que se hace la prueba: el del usuario si está en el
/// dispositivo y tiene ítems de prueba; si no, Fundamentos (incluido).
ItineraryPackage? paquetePrueba(ContenidoCargado c, String? itineraryId) {
  final propio = c.itinerario(itineraryId);
  if (propio != null && propio.placement.isNotEmpty) return propio;
  return c.fundamentos;
}

class PantallaPruebaNivel extends ConsumerStatefulWidget {
  const PantallaPruebaNivel({super.key});
  @override
  ConsumerState<PantallaPruebaNivel> createState() => _PantallaPruebaNivelState();
}

class _PantallaPruebaNivelState extends ConsumerState<PantallaPruebaNivel> {
  PruebaNivel? _prueba;
  Map<String, dynamic> _guardado = const {};
  final _entrada = EntradaNumerica();
  String? _unidad;
  String? _opcion;

  @override
  void initState() {
    super.initState();
    _entrada.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final u = ref.read(usuarioProvider).value!;
    final c = ref.read(contenidoProvider).value!;
    final previa = u.pruebaEnCurso;
    if (previa != null && previa['prueba'] is Map) {
      _guardado = previa;
      _prueba = PruebaNivel.fromJson((previa['prueba'] as Map).cast<String, dynamic>());
    } else {
      final pkg = paquetePrueba(c, u.perfil?.itineraryId)!;
      _prueba = PruebaNivel.iniciar(pkg, u.perfil?.declaredLevel);
      _guardado = {'itinerario': pkg.itinerary.id, 'inicio': ref.read(dependenciasProvider).reloj.ahora().toUtc().toIso8601String(), 'aciertos': 0};
      await _guardar();
    }
    if (!mounted) return;
    setState(() {});
    _saltarSiNoHay();
  }

  Future<void> _guardar() =>
      ref.read(usuarioProvider.notifier).actualizar((e) => e.copyWith(pruebaEnCurso: {..._guardado, 'prueba': _prueba!.toJson()}));

  Variant? get _variante {
    final id = _prueba?.varianteActual;
    return id == null ? null : ref.read(contenidoProvider).value!.variante(id);
  }

  /// Variante retirada o inexistente: cuenta como no sabida y se sigue.
  void _saltarSiNoHay() {
    if (_prueba == null) return;
    if (_prueba!.terminada) {
      context.go(Rutas.altaResultado);
      return;
    }
    if (_variante == null || motivoDefectoPrueba(_variante!) != null) _responder(false);
  }

  Future<void> _responder(bool correcto) async {
    _prueba!.responder(correcto: correcto);
    _guardado = {..._guardado, 'aciertos': (_guardado['aciertos'] as num? ?? 0).toInt() + (correcto ? 1 : 0)};
    await _guardar();
    if (!mounted) return;
    setState(() {
      _entrada.limpiar();
      _unidad = null;
      _opcion = null;
    });
    _saltarSiNoHay();
  }

  bool get _listo {
    final v = _variante;
    if (v == null) return false;
    if (v.options != null && v.options!.isNotEmpty) return _opcion != null;
    final a = v.answer;
    if (a == null) return false;
    final elegir = !a.unitFixed && a.unitChoices.length > 1;
    return !_entrada.vacia && (!elegir || _unidad != null);
  }

  void _siguiente() {
    final v = _variante!;
    bool ok;
    if (v.options != null && v.options!.isNotEmpty) {
      ok = gradeChoice(v.options!, _opcion!).verdict == Verdict.correct;
    } else {
      final g = grade(v.answer!, v.predictedErrors, GradeInput(_entrada.texto, unit: _unidad));
      ok = isCorrectVerdict(g.verdict);
    }
    // Sin corrección visible: solo se pasa a la siguiente pregunta.
    _responder(ok);
  }

  @override
  Widget build(BuildContext context) {
    final p = _prueba;
    final v = _variante;
    final vtm = context.vtm;
    if (p == null || v == null) return const Scaffold(body: SizedBox.shrink());
    final opciones = v.options ?? const <ChoiceOption>[];
    final a = v.answer;
    final elegir = a != null && !a.unitFixed && a.unitChoices.length > 1;
    final senales = ref.read(senalesProvider);
    _entrada.alRechazo = () => senales.emitir(Senal.aviso);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('${p.numeroPregunta} de ${p.maximo} máx.', key: const ValueKey('numero-pregunta'), style: estiloCifra(context, size: 16)),
      ),
      body: SafeArea(
        child: TecladoFisico(
          entrada: _entrada,
          alEnviar: _listo ? _siguiente : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnchoMaximo(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      Enunciado(v, rotulo: 'Prueba de nivel · sin corrección'),
                      const SizedBox(height: 16),
                      if (opciones.isNotEmpty)
                        for (final (i, o) in opciones.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Tarjeta(
                              key: ValueKey('opcion-${o.id}'),
                              seleccionada: _opcion == o.id,
                              onTap: () => setState(() => _opcion = o.id),
                              semantica: 'Opción ${String.fromCharCode(65 + i)}: ${o.label}',
                              child: Row(children: [
                                Text(String.fromCharCode(65 + i), style: context.textos.titleSmall?.copyWith(color: vtm.atenuado)),
                                const SizedBox(width: 14),
                                Expanded(child: Text(o.label, style: estiloCifra(context, size: 18, weight: FontWeight.w500))),
                              ]),
                            ),
                          )
                      else ...[
                        CampoRespuesta(entrada: _entrada, unidad: elegir ? _unidad : a?.unit),
                        if (elegir) ...[
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final u in a.unitChoices)
                              ChoiceChip(key: ValueKey('unidad-$u'), label: Text(u), selected: _unidad == u, onSelected: (_) => setState(() => _unidad = u)),
                          ]),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text('Si no lo sabes, dilo: ajustamos mejor.', style: context.textos.bodySmall?.copyWith(color: vtm.atenuado))),
                        TextButton(key: const ValueKey('prueba-no-lo-se'), onPressed: () => _responder(false), child: const Text('No lo sé')),
                      ]),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (opciones.isEmpty) ...[TecladoNumerico(entrada: _entrada, senales: senales), const SizedBox(height: 8)],
                  AnchoMaximo(
                    ancho: anchoTeclado,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(key: const ValueKey('prueba-siguiente'), onPressed: _listo ? _siguiente : null, child: const Text('Siguiente')),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La prueba solo dibuja respuestas numéricas y de opción.
String? motivoDefectoPrueba(Variant v) {
  if (v.options != null && v.options!.isNotEmpty) return v.options!.any((o) => o.correct) ? null : 'Opciones no válidas';
  return v.answer == null ? 'Tipo no admitido en la prueba' : null;
}

class PantallaResultadoPrueba extends ConsumerWidget {
  const PantallaResultadoPrueba({super.key});

  String _duracion(Duration d) => d.inMinutes > 0 ? '${d.inMinutes} min ${d.inSeconds % 60} s' : '${d.inSeconds} s';

  Future<void> _registrar(WidgetRef ref, BuildContext context, PruebaNivel prueba, Map<String, dynamic> guardado, {required bool convalidar}) async {
    final deps = ref.read(dependenciasProvider);
    final u = ref.read(usuarioProvider).value!;
    final c = ref.read(contenidoProvider).value!;
    final r = prueba.resultado();
    final inicio = DateTime.tryParse('${guardado['inicio']}') ?? deps.reloj.ahora();
    final fin = deps.reloj.ahora();
    final total = prueba.itemsRespondidos;
    final aciertos = (guardado['aciertos'] as num? ?? 0).toInt();
    final pkg = c.itinerario('${guardado['itinerario']}');
    await ref.read(aprendizajeProvider.notifier).registrarSesion(SessionRecord(
          id: nuevoId(),
          deviceId: u.deviceId,
          mode: SessionMode.placement,
          startedAt: inicio,
          endedAt: fin,
          completed: true,
          practiceMs: fin.difference(inicio).inMilliseconds.clamp(0, 1 << 31),
          contentVersion: c.versionDe(pkg?.itinerary.id),
          summary: SessionSummary(
            correct: aciertos,
            total: total,
            errors: total - aciertos,
            accuracy: total == 0 ? 0 : aciertos / total,
            convalidatedUnitIds: convalidar ? r.unidadesConvalidadas : const [],
            entryUnitId: convalidar ? r.unidadEntrada : pkg?.units.firstOrNull?.id,
          ),
        ));
    await ref.read(usuarioProvider.notifier).actualizar((e) => e.copyWith(quitarPrueba: true));
    if (context.mounted) context.go(Rutas.altaDescarga);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(usuarioProvider).value!;
    final c = ref.watch(contenidoProvider).value!;
    final guardado = u.pruebaEnCurso;
    if (guardado == null || guardado['prueba'] is! Map) return const Scaffold(body: SizedBox.shrink());
    final prueba = PruebaNivel.fromJson((guardado['prueba'] as Map).cast<String, dynamic>());
    final r = prueba.resultado();
    final pkg = c.itinerario('${guardado['itinerario']}') ?? c.fundamentos!;
    final inicio = DateTime.tryParse('${guardado['inicio']}');
    final ahora = ref.read(dependenciasProvider).reloj.ahora();
    final entrada = pkg.units.where((x) => x.id == r.unidadEntrada).firstOrNull;
    final vtm = context.vtm;
    return Scaffold(
      body: SafeArea(
        child: AnchoMaximo(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 16), children: [
                if (inicio != null) Text('Resultado · ${_duracion(ahora.difference(inicio))}', style: context.textos.labelMedium?.copyWith(color: vtm.atenuado)),
                const SizedBox(height: 8),
                Semantics(
                  header: true,
                  child: Text(entrada == null ? 'Has convalidado todo el itinerario' : 'Empiezas en ${entrada.name}', style: context.textos.headlineSmall),
                ),
                const SizedBox(height: 8),
                Text(
                  r.unidadesConvalidadas.isEmpty
                      ? 'Empiezas por el principio: así afianzas la base.'
                      : 'Convalidamos ${r.unidadesConvalidadas.length} ${r.unidadesConvalidadas.length == 1 ? 'unidad' : 'unidades'}. Puedes empezar antes si prefieres repasarlas.',
                  style: context.textos.bodyMedium,
                ),
                const SizedBox(height: 20),
                for (final un in pkg.units)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Tarjeta(
                      key: ValueKey('resultado-${un.id}'),
                      seleccionada: un.id == r.unidadEntrada,
                      child: Row(children: [
                        Icon(
                          r.unidadesConvalidadas.contains(un.id) ? Symbols.check_circle : (un.id == r.unidadEntrada ? Symbols.flag : Symbols.lock),
                          color: r.unidadesConvalidadas.contains(un.id) ? vtm.exito : (un.id == r.unidadEntrada ? vtm.primario : vtm.atenuado),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(un.name, style: context.textos.titleSmall)),
                        if (r.unidadesConvalidadas.contains(un.id))
                          const Etiqueta('Convalidada', tono: TonoEtiqueta.exito)
                        else if (un.id == r.unidadEntrada)
                          const Etiqueta('Punto de entrada', tono: TonoEtiqueta.primario),
                      ]),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton(
                  key: const ValueKey('empezar-aqui'),
                  onPressed: () => _registrar(ref, context, prueba, guardado, convalidar: true),
                  child: const Text('Empezar aquí'),
                ),
                if (r.unidadesConvalidadas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('empezar-antes'),
                    onPressed: () => _registrar(ref, context, prueba, guardado, convalidar: false),
                    child: const Text('Prefiero empezar antes'),
                  ),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
