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
import '../../../core/contenido/actualizador.dart';
import '../../../core/contenido/aviso_solo_wifi.dart';
import '../../../core/contenido/repositorio_contenido.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';

export 'pantalla_prueba.dart';

/// Alta: bienvenida, sector, nivel, meta, aviso formativo, descarga y permiso
/// de notificaciones (M01, M04–M07, M10–M11, T08). Cuatro pasos, uno por
/// pantalla; «Continuar» solo se activa con una opción elegida. No se pide
/// ningún permiso del sistema antes de la primera lección.

/// Texto del aviso formativo (formative-boundary). Va incluido en la app.
const textoAvisoFormativo = 'VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales.';
const puntosAvisoFormativo = [
  'Todos los casos son simulados.',
  'La pauta viene siempre en el enunciado.',
  'Tú calculas y la app corrige. Nunca calcula por ti.',
];

/// Esqueleto común de un paso del alta.
class _PasoAlta extends StatelessWidget {
  const _PasoAlta({
    required this.paso,
    required this.titulo,
    this.subtitulo,
    required this.children,
    required this.accion,
    this.alContinuar,
    this.atras,
    this.pie = const [],
    this.panelDerecho,
  });
  final int paso;
  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final String accion;
  final VoidCallback? alContinuar;
  final String? atras;
  final List<Widget> pie;
  final Widget? panelDerecho;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final principal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: AnchoMaximo(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              children: [
                Semantics(
                  label: 'Paso $paso de 4',
                  child: Row(children: [
                    Text('Paso $paso de 4', style: context.textos.labelMedium?.copyWith(color: c.atenuado)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: paso / 4, minHeight: 6, backgroundColor: c.superficie2, color: c.primario),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                Semantics(header: true, child: Text(titulo, style: context.textos.headlineSmall)),
                if (subtitulo != null) ...[
                  const SizedBox(height: 8),
                  Text(subtitulo!, style: context.textos.bodyMedium?.copyWith(color: c.atenuado)),
                ],
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
        AnchoMaximo(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(key: const ValueKey('alta-continuar'), onPressed: alContinuar, child: Text(accion)),
                ...pie,
              ],
            ),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        leading: atras == null ? null : IconButton(icon: const Icon(Symbols.arrow_back), tooltip: 'Atrás', onPressed: () => context.go(atras!)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(child: DosPaneles(principal: principal, secundario: panelDerecho, proporcion: 0.55)),
    );
  }
}

/// Opción seleccionable (radio) con título y descripción.
class _Opcion extends StatelessWidget {
  const _Opcion({required this.titulo, this.descripcion, required this.seleccionada, required this.alElegir, this.icono, this.clave});
  final String titulo;
  final String? descripcion;
  final bool seleccionada;
  final VoidCallback alElegir;
  final IconData? icono;
  final Key? clave;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: seleccionada,
        child: Tarjeta(
          key: clave,
          seleccionada: seleccionada,
          onTap: alElegir,
          child: Row(
            children: [
              if (icono != null) ...[Icon(icono, color: seleccionada ? c.primario : c.atenuado), const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: context.textos.titleMedium),
                    if (descripcion != null && descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(descripcion!, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                    ],
                  ],
                ),
              ),
              Icon(seleccionada ? Symbols.radio_button_checked : Symbols.radio_button_unchecked, color: seleccionada ? c.primario : c.atenuado),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M01 · Bienvenida
// ---------------------------------------------------------------------------

class PantallaBienvenida extends ConsumerStatefulWidget {
  const PantallaBienvenida({super.key});
  @override
  ConsumerState<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends ConsumerState<PantallaBienvenida> {
  @override
  void initState() {
    super.initState();
    // Prueba de nivel interrumpida: se reanuda en la pregunta en que quedó.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prueba = ref.read(usuarioProvider).value?.pruebaEnCurso;
      if (!mounted || prueba == null) return;
      final terminada = (prueba['prueba'] as Map?)?['terminada'] == true;
      context.go(terminada ? Rutas.altaResultado : Rutas.altaPrueba);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    const ventajas = [
      (Symbols.timer, 'Sesiones de 3 a 5 minutos con corrección paso a paso.'),
      (Symbols.headphones, 'Modo manos libres que funciona sin conexión.'),
      (Symbols.verified, 'Casos simulados revisados por profesionales de tu sector.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  children: [
                    Row(children: [
                      Icon(Symbols.vaccines, color: c.primario, size: 32),
                      const SizedBox(width: 8),
                      Flexible(child: Text('VolutrainMed', style: context.textos.titleLarge?.copyWith(color: c.primario))),
                    ]),
                    const SizedBox(height: 32),
                    ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: c.primarioTinte, borderRadius: BorderRadius.circular(16)),
                        child: Column(children: [
                          Text('Jeringa de 1 ml', style: context.textos.labelMedium?.copyWith(color: c.atenuado)),
                          const SizedBox(height: 8),
                          Text('0,96 ml', style: estiloCifra(context, size: 40, color: c.primario)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Semantics(header: true, child: Text('Entrena el cálculo de dosis con precisión y rapidez', style: context.textos.headlineMedium)),
                    const SizedBox(height: 20),
                    for (final (i, t) in ventajas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(i, color: c.primario),
                          const SizedBox(width: 12),
                          Expanded(child: Text(t, style: context.textos.bodyMedium)),
                        ]),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(onPressed: () => context.go(Rutas.altaSector), child: const Text('Empezar')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.go(Uri(path: Rutas.cuenta, queryParameters: {'modo': 'acceso'}).toString()),
                      child: const Text('Ya tengo cuenta'),
                    ),
                    const SizedBox(height: 12),
                    Text('Entrenador formativo. No es una calculadora clínica.', textAlign: TextAlign.center, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M04 · Sector (con vista previa en tablet, T08)
// ---------------------------------------------------------------------------

IconData _iconoSector(String id) => switch (id) {
      'enfermeria' => Symbols.medical_services,
      'medicina' => Symbols.stethoscope,
      'anestesia' => Symbols.airwave,
      'emergencias' => Symbols.emergency,
      'farmacia' => Symbols.medication,
      'pediatria' => Symbols.child_care,
      'veterinaria' => Symbols.pets,
      _ => Symbols.school,
    };

/// Itinerario que se propone para un sector: el más habitual del sector.
String? itinerarioPropuesto(ContenidoCargado c, String sectorId) {
  final s = c.sector(sectorId);
  return s?.defaultItineraryId ?? (s?.itineraryIds.isNotEmpty == true ? s!.itineraryIds.first : c.fundamentos?.itinerary.id);
}

class PantallaSector extends ConsumerStatefulWidget {
  const PantallaSector({super.key});
  @override
  ConsumerState<PantallaSector> createState() => _PantallaSectorState();
}

class _PantallaSectorState extends ConsumerState<PantallaSector> {
  String? _sector;

  @override
  void initState() {
    super.initState();
    _sector = ref.read(usuarioProvider).value?.perfil?.sectorId;
  }

  Future<void> _continuar() async {
    final c = ref.read(contenidoProvider).value!;
    final it = itinerarioPropuesto(c, _sector!);
    await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(sectorId: _sector, itineraryId: it));
    if (mounted) context.go(Rutas.altaNivel);
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contenidoProvider).value!;
    return _PasoAlta(
      paso: 1,
      titulo: '¿En qué sector trabajas o estudias?',
      atras: Rutas.bienvenida,
      accion: 'Continuar',
      alContinuar: _sector == null ? null : _continuar,
      panelDerecho: _sector == null ? null : _VistaPreviaItinerario(itineraryId: itinerarioPropuesto(c, _sector!)),
      children: [
        for (final s in c.global.sectors)
          _Opcion(
            clave: ValueKey('sector-${s.id}'),
            titulo: s.name,
            descripcion: s.typicalCalcs,
            icono: _iconoSector(s.id),
            seleccionada: _sector == s.id,
            alElegir: () => setState(() => _sector = s.id),
          ),
      ],
    );
  }
}

/// Vista previa del itinerario propuesto (panel derecho en tablet, T08).
class _VistaPreviaItinerario extends ConsumerWidget {
  const _VistaPreviaItinerario({required this.itineraryId});
  final String? itineraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contenidoProvider).value!;
    final resumen = c.resumenItinerario(itineraryId);
    final paquete = c.itinerario(itineraryId);
    final ejemplo = paquete?.variants.where((v) => v.exerciseTypeId == 'T1').firstOrNull;
    final vtm = context.vtm;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const TituloSeccion('Itinerario propuesto'),
        Text(resumen?.name ?? 'Fundamentos', style: context.textos.titleLarge),
        if (resumen?.description.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(resumen!.description, style: context.textos.bodyMedium?.copyWith(color: vtm.atenuado)),
        ],
        const SizedBox(height: 16),
        if (paquete != null)
          for (final (i, u) in paquete.units.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(backgroundColor: vtm.primarioTinte, child: Text('${i + 1}', style: TextStyle(color: vtm.primario))),
              title: Text(u.name),
            )
        else
          Text('Se descargará al terminar el alta. Mientras, empiezas con Fundamentos, incluido en la app.', style: context.textos.bodySmall),
        if (ejemplo != null) ...[
          const SizedBox(height: 16),
          const TituloSeccion('Ejemplo de caso'),
          Tarjeta(child: Enunciado(ejemplo, compacto: true)),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// M05 · Nivel declarado
// ---------------------------------------------------------------------------

class PantallaNivel extends ConsumerStatefulWidget {
  const PantallaNivel({super.key});
  @override
  ConsumerState<PantallaNivel> createState() => _PantallaNivelState();
}

class _PantallaNivelState extends ConsumerState<PantallaNivel> {
  String? _nivel;
  static const niveles = [
    ('cero', 'Empiezo de cero', 'Repaso desde Fundamentos: conversiones, concentraciones y volumen a cargar.'),
    ('afianzar', 'Lo uso y quiero afianzarlo', 'Practico lo que ya sé hasta hacerlo sin errores.'),
    ('agilidad', 'Lo domino y busco agilidad', 'Voy a por rapidez con precisión; la prueba de nivel me sitúa.'),
  ];

  @override
  void initState() {
    super.initState();
    _nivel = ref.read(usuarioProvider).value?.perfil?.declaredLevel;
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contenidoProvider).value!;
    final perfil = ref.watch(usuarioProvider).value?.perfil;
    final it = c.resumenItinerario(perfil?.itineraryId);
    final sector = c.sector(perfil?.sectorId);
    return _PasoAlta(
      paso: 2,
      titulo: '¿Cómo te manejas con el cálculo de dosis?',
      atras: Rutas.altaSector,
      accion: 'Continuar',
      alContinuar: _nivel == null
          ? null
          : () async {
              await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(declaredLevel: _nivel));
              if (context.mounted) context.go(Rutas.altaMeta);
            },
      children: [
        for (final (id, t, d) in niveles)
          _Opcion(clave: ValueKey('nivel-$id'), titulo: t, descripcion: d, seleccionada: _nivel == id, alElegir: () => setState(() => _nivel = id)),
        const SizedBox(height: 8),
        Tarjeta(
          tinte: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Itinerario propuesto', style: context.textos.labelMedium),
              const SizedBox(height: 4),
              Text(it?.name ?? 'Fundamentos', key: const ValueKey('itinerario-propuesto'), style: context.textos.titleMedium),
              if (sector != null) Text(sector.name, style: context.textos.bodySmall),
              const SizedBox(height: 4),
              Text('Lo puedes cambiar más tarde desde Perfil.', style: context.textos.bodySmall?.copyWith(color: context.vtm.atenuado)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// M06 · Meta
// ---------------------------------------------------------------------------

class PantallaMeta extends ConsumerStatefulWidget {
  const PantallaMeta({super.key});
  @override
  ConsumerState<PantallaMeta> createState() => _PantallaMetaState();
}

class _PantallaMetaState extends ConsumerState<PantallaMeta> {
  Goal? _meta;
  int _dias = 4;

  @override
  void initState() {
    super.initState();
    _meta = ref.read(usuarioProvider).value?.perfil?.goal;
    if (_meta?.kind == GoalKind.weekly) _dias = _meta!.days ?? 4;
  }

  bool _es(Goal g) => _meta != null && _meta!.kind == g.kind && (g.kind == GoalKind.weekly || _meta!.minutes == g.minutes);

  @override
  Widget build(BuildContext context) {
    const diarias = [(5, 'Una lección corta'), (10, 'Una lección y el repaso'), (15, 'Dos lecciones y el repaso')];
    final semanal = _meta?.kind == GoalKind.weekly;
    return _PasoAlta(
      paso: 3,
      titulo: 'Elige tu meta',
      subtitulo: 'La constancia pesa más que la duración. Puedes cambiarla cuando quieras.',
      atras: Rutas.altaNivel,
      accion: 'Continuar',
      alContinuar: _meta == null
          ? null
          : () async {
              final g = semanal ? Goal.weekly(_dias) : _meta!;
              await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(goal: g));
              if (context.mounted) context.go(Rutas.altaAviso);
            },
      children: [
        for (final (m, d) in diarias)
          _Opcion(
            clave: ValueKey('meta-$m'),
            titulo: '$m minutos al día',
            descripcion: d,
            icono: Symbols.timer,
            seleccionada: _es(Goal.daily(m)),
            alElegir: () => setState(() => _meta = Goal.daily(m)),
          ),
        _Opcion(
          clave: const ValueKey('meta-semanal'),
          titulo: 'Meta semanal',
          descripcion: 'Para quien trabaja a turnos: cuenta la semana, no cada día.',
          icono: Symbols.calendar_month,
          seleccionada: semanal,
          alElegir: () => setState(() => _meta = Goal.weekly(_dias)),
        ),
        if (semanal) ...[
          const SizedBox(height: 4),
          Text('Días de práctica por semana', style: context.textos.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in [2, 3, 4, 5, 6])
                ChoiceChip(
                  label: Text('$d días'),
                  selected: _dias == d,
                  onSelected: (_) => setState(() {
                    _dias = d;
                    _meta = Goal.weekly(d);
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// M07 · Aviso formativo
// ---------------------------------------------------------------------------

class PantallaAviso extends ConsumerStatefulWidget {
  const PantallaAviso({super.key});
  @override
  ConsumerState<PantallaAviso> createState() => _PantallaAvisoState();
}

class _PantallaAvisoState extends ConsumerState<PantallaAviso> {
  bool _entendido = false;

  Future<void> _aceptar({required bool conPrueba}) async {
    final deps = ref.read(dependenciasProvider);
    await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(disclaimerAcceptedAt: deps.reloj.ahora().toUtc()));
    if (!mounted) return;
    context.go(conPrueba ? Rutas.altaPrueba : Rutas.altaDescarga);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return _PasoAlta(
      paso: 4,
      titulo: 'Esto es un entrenamiento',
      atras: Rutas.altaMeta,
      accion: 'Aceptar y continuar',
      alContinuar: _entendido ? () => _aceptar(conPrueba: true) : null,
      pie: [
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('saltar-prueba'),
          onPressed: _entendido ? () => _aceptar(conPrueba: false) : null,
          child: const Text('Saltar la prueba de nivel'),
        ),
      ],
      children: [
        Tarjeta(
          tinte: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.school, color: c.primario),
            const SizedBox(width: 12),
            Expanded(child: Text(textoAvisoFormativo, style: context.textos.titleMedium)),
          ]),
        ),
        const SizedBox(height: 16),
        for (final p in puntosAvisoFormativo)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.check_circle, color: c.exito, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(p, style: context.textos.bodyMedium)),
            ]),
          ),
        const SizedBox(height: 8),
        CheckboxListTile(
          key: const ValueKey('lo-entiendo'),
          value: _entendido,
          onChanged: (v) => setState(() => _entendido = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Lo entiendo'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// M10 · Descarga del itinerario
// ---------------------------------------------------------------------------

/// Primera lección pendiente del itinerario activo (respeta la unidad de
/// entrada de la prueba de nivel).
String? primeraLeccion(WidgetRef ref) {
  final it = ref.read(itinerarioActivoProvider);
  if (it == null) return null;
  final p = ref.read(proyeccionProvider);
  final l = p?.siguienteLeccion(it) ?? it.lessons.where((l) => l.unitId == it.units.first.id).fold<Lesson?>(null, (a, l) => a == null || l.order < a.order ? l : a);
  return l?.id;
}

class PantallaDescarga extends ConsumerStatefulWidget {
  const PantallaDescarga({super.key});
  @override
  ConsumerState<PantallaDescarga> createState() => _PantallaDescargaState();
}

enum _EstadoDescarga { instalado, descargando, sinConexion, fallo }

class _PantallaDescargaState extends ConsumerState<PantallaDescarga> {
  _EstadoDescarga _estado = _EstadoDescarga.instalado;
  int _recibidos = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  String? get _itinerario => ref.read(usuarioProvider).value?.perfil?.itineraryId;

  Future<void> _preparar() async {
    final id = _itinerario;
    final c = ref.read(contenidoProvider).value!;
    if (id == null || c.itinerario(id) != null) {
      setState(() => _estado = _EstadoDescarga.instalado);
      return;
    }
    if (!ref.read(enLineaProvider)) {
      setState(() => _estado = _EstadoDescarga.sinConexion);
      return;
    }
    setState(() => _estado = _EstadoDescarga.descargando);
    final act = ref.read(actualizadorProvider);
    try {
      await descargarRespetandoWifi(
        context,
        (datos) => act.descargarItinerario(id, conDatos: datos, progreso: (r, t) {
          if (mounted) {
            setState(() {
              _recibidos = r;
              _total = t;
            });
          }
        }),
      );
      if (await act.aplicarPreparadas()) await ref.read(contenidoProvider.notifier).recargar();
      if (!mounted) return;
      final ok = ref.read(contenidoProvider).value!.itinerario(id) != null;
      setState(() => _estado = ok ? _EstadoDescarga.instalado : _EstadoDescarga.fallo);
    } catch (_) {
      if (mounted) setState(() => _estado = _EstadoDescarga.fallo);
    }
  }

  Future<void> _empezar() async {
    await ref.read(usuarioProvider.notifier).completarAlta();
    if (!mounted) return;
    final l = primeraLeccion(ref);
    context.go(l == null ? Rutas.inicio : Rutas.leccion(l));
  }

  String _mb(int b) => (b / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contenidoProvider).value!;
    final vtm = context.vtm;
    final nombre = c.resumenItinerario(_itinerario)?.name ?? 'Fundamentos';
    final descargando = _estado == _EstadoDescarga.descargando;
    final (icono, linea) = switch (_estado) {
      _EstadoDescarga.instalado => (Symbols.download_done, 'Listo en el dispositivo'),
      _EstadoDescarga.descargando => (Symbols.downloading, _total > 0 ? '${_mb(_recibidos)} de ${_mb(_total)} MB' : 'Descargando…'),
      _EstadoDescarga.sinConexion => (Symbols.cloud_off, 'Sin conexión: empiezas con Fundamentos, incluido en la app. Tu itinerario se descargará al conectar.'),
      _EstadoDescarga.fallo => (Symbols.error, 'No se ha podido descargar. Empiezas con Fundamentos, incluido en la app, y lo reintentaremos.'),
    };
    const pasos = [
      (Symbols.timer, 'Practica en huecos de 5 minutos', 'Una lección es corta: cabe en un trayecto o en una pausa.'),
      (Symbols.replay, 'Cada fallo vuelve al repaso', 'Se explica paso a paso y reaparece con otros números.'),
      (Symbols.wifi_off, 'Funciona sin conexión', 'El contenido queda en el dispositivo; el progreso se sincroniza al conectar.'),
    ];
    return Scaffold(
      body: SafeArea(
        child: AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  children: [
                    Semantics(header: true, child: Text('Preparando tu itinerario', style: context.textos.headlineSmall)),
                    const SizedBox(height: 16),
                    Tarjeta(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(icono, color: vtm.primario),
                          const SizedBox(width: 12),
                          Expanded(child: Text(nombre, style: context.textos.titleMedium)),
                        ]),
                        const SizedBox(height: 10),
                        if (descargando) ...[
                          LinearProgressIndicator(value: _total > 0 ? _recibidos / _total : null),
                          const SizedBox(height: 8),
                        ],
                        Semantics(liveRegion: true, child: Text(linea, key: const ValueKey('estado-descarga'), style: context.textos.bodySmall)),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    const TituloSeccion('Cómo funciona'),
                    for (final (i, t, d) in pasos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(i, color: vtm.primario),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t, style: context.textos.titleSmall),
                              Text(d, style: context.textos.bodySmall?.copyWith(color: vtm.atenuado)),
                            ]),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton(key: const ValueKey('empezar-primera'), onPressed: descargando ? null : _empezar, child: const Text('Empezar la primera lección')),
                  if (descargando) ...[
                    const SizedBox(height: 8),
                    Text('Disponible al terminar la descarga', textAlign: TextAlign.center, style: context.textos.bodySmall),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// M11 · Permiso de notificaciones (tras la primera lección)
// ---------------------------------------------------------------------------

/// Próxima vez que llega [hora] («20:30») a partir de [ahora].
DateTime proximaHora(String hora, DateTime ahora) {
  final p = hora.split(':');
  var t = DateTime(ahora.year, ahora.month, ahora.day, int.parse(p[0]), int.parse(p[1]));
  if (!t.isAfter(ahora)) t = t.add(const Duration(days: 1));
  return t;
}

const idNotificacionRepaso = 1;

class PantallaPermisoNotificaciones extends ConsumerStatefulWidget {
  const PantallaPermisoNotificaciones({super.key});
  @override
  ConsumerState<PantallaPermisoNotificaciones> createState() => _PantallaPermisoNotificacionesState();
}

class _PantallaPermisoNotificacionesState extends ConsumerState<PantallaPermisoNotificaciones> {
  TimeOfDay _hora = const TimeOfDay(hour: 20, minute: 30);
  String? _aviso;

  String get _texto => '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}';

  Future<void> _terminar() async {
    await ref.read(usuarioProvider.notifier).actualizar((e) => e.copyWith(notificacionesOfrecidas: true));
    if (mounted) context.go(Rutas.inicio);
  }

  Future<void> _activar() async {
    final deps = ref.read(dependenciasProvider);
    final r = await deps.permisos.pedirNotificaciones();
    if (r == EstadoPermiso.concedido) {
      await ref.read(ajustesProvider.notifier).cambiar((a) => a.copyWith(recordatorio: _texto));
      await deps.notificador.programar(NotificacionProgramada(
        id: idNotificacionRepaso,
        cuando: proximaHora(_texto, deps.reloj.ahora()),
        titulo: 'VolutrainMed',
        texto: 'Tienes fichas de repaso pendientes. Son unos minutos.',
        diaria: true,
      ));
      await _terminar();
    } else {
      setState(() => _aviso = 'Sin permiso no podemos avisarte. Puedes activarlo más adelante en los ajustes del sistema; la app funciona igual.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vtm = context.vtm;
    return Scaffold(
      body: SafeArea(
        child: AnchoMaximo(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 16), children: [
                Icon(Symbols.notifications, color: vtm.primario, size: 40),
                const SizedBox(height: 16),
                Semantics(header: true, child: Text('¿Te recordamos tu repaso?', style: context.textos.headlineSmall)),
                const SizedBox(height: 8),
                Text('Un aviso al día, a la hora que elijas, con las fichas que tienes pendientes.', style: context.textos.bodyMedium),
                const SizedBox(height: 20),
                Tarjeta(
                  child: Row(children: [
                    Icon(Symbols.vaccines, color: vtm.primario),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Tienes 8 fichas de repaso. Son unos 4 minutos.')),
                  ]),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora del aviso'),
                  trailing: Text(_texto, style: estiloCifra(context)),
                  onTap: () async {
                    final h = await showTimePicker(context: context, initialTime: _hora);
                    if (h != null) setState(() => _hora = h);
                  },
                ),
                if (_aviso != null) Text(_aviso!, style: context.textos.bodySmall),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton(onPressed: _aviso == null ? _activar : null, child: const Text('Activar el recordatorio')),
                const SizedBox(height: 8),
                TextButton(onPressed: _terminar, child: Text(_aviso == null ? 'Ahora no' : 'Continuar')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
