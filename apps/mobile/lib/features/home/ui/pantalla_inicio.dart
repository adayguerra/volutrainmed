import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../orgs/ui/pantalla_organizacion.dart' show DestacadoOrganizacion;
import '../../../app/adaptativo.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/domain/content_models.dart';
import '../../progress/domain/projections.dart';
import 'componentes_inicio.dart';

/// Inicio con ruta, detalle de unidad y Practicar (M12–M16, T01).

const textoBannerSinConexion = 'Sin conexión · tu progreso se guarda en el dispositivo';

/// Ruta de la sesión que abre «Continuar»: con calentamiento si hay fichas
/// vencidas (learning-path, «Calentamiento de repaso»).
String rutaContinuar(Proyeccion p, Lesson l) => Rutas.leccion(l.id, calentamiento: p.fichasVencidas > 0);

/// Unidad que se muestra desplegada: la de la siguiente lección, o la primera
/// en curso o disponible.
String? unidadActual(Proyeccion p, ItineraryPackage it) {
  final l = p.siguienteLeccion(it);
  if (l != null) return l.unitId;
  for (final u in it.units) {
    final e = p.unidades[u.id] ?? EstadoUnidad.bloqueada;
    if (e == EstadoUnidad.enCurso || e == EstadoUnidad.disponible) return u.id;
  }
  return it.units.firstOrNull?.id;
}

class PantallaInicio extends ConsumerStatefulWidget {
  const PantallaInicio({super.key});
  @override
  ConsumerState<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends ConsumerState<PantallaInicio> {
  String? _seleccionada;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(proyeccionProvider);
    final it = ref.watch(itinerarioActivoProvider);
    if (p == null || it == null) return const Scaffold(body: SafeArea(child: Esqueleto()));
    final clase = ClaseAncho.de(context);
    final actual = unidadActual(p, it);
    final seleccionada = _seleccionada ?? actual;
    final siguiente = p.siguienteLeccion(it);

    final ruta = _Ruta(
      proyeccion: p,
      itinerario: it,
      desplegada: clase.dosPaneles ? null : actual,
      seleccionada: clase.dosPaneles ? seleccionada : null,
      alElegirUnidad: (id) => clase.dosPaneles ? setState(() => _seleccionada = id) : context.push(Rutas.unidad(id)),
    );
    final boton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: AnchoMaximo(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('continuar'),
            onPressed: siguiente == null ? () => context.go(Rutas.practicar) : () => context.push(rutaContinuar(p, siguiente)),
            child: Text(siguiente == null ? 'Práctica libre' : 'Continuar · Lección ${siguiente.order}', textAlign: TextAlign.center),
          ),
        ),
      ),
    );

    final cuerpo = clase.dosPaneles
        ? DosPaneles(
            proporcion: 0.45,
            principal: Column(children: [Expanded(child: ruta), boton]),
            secundario: seleccionada == null
                ? null
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetalleUnidad(unitId: seleccionada, enPanel: true),
                        const SizedBox(height: 16),
                        const _TarjetasPracticaTablet(),
                      ],
                    ),
                  ),
          )
        : Column(children: [Expanded(child: ruta), boton]);
    return Scaffold(body: SafeArea(child: cuerpo));
  }
}

/// Cabecera, avisos, tarjeta de repaso y lista de unidades.
class _Ruta extends ConsumerWidget {
  const _Ruta({required this.proyeccion, required this.itinerario, required this.desplegada, required this.seleccionada, required this.alElegirUnidad});
  final Proyeccion proyeccion;
  final ItineraryPackage itinerario;
  final String? desplegada;
  final String? seleccionada;
  final ValueChanged<String> alElegirUnidad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = proyeccion;
    final c = context.vtm;
    final enLinea = ref.watch(enLineaProvider);
    final aviso = ref.watch(contenidoProvider).value?.avisoAppAntigua;
    final cola = p.colaHoy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Cabecera(proyeccion: p),
              const SizedBox(height: 12),
              if (!enLinea) ...[
                const Aviso(textoBannerSinConexion, icono: Symbols.cloud_off),
                const SizedBox(height: 8),
              ],
              if (p.racha.aviso != null) ...[
                Aviso(p.racha.aviso!, icono: Symbols.local_fire_department),
                const SizedBox(height: 8),
              ],
              if (aviso != null) ...[
                Aviso(aviso, icono: Symbols.system_update, tono: TonoEtiqueta.aviso),
                const SizedBox(height: 8),
              ],
              const DestacadoOrganizacion(),
              Semantics(header: true, child: Text(itinerario.itinerary.name, style: context.textos.titleLarge)),
              const SizedBox(height: 12),
              if (cola.isNotEmpty) ...[
                TarjetaRepaso(cola: cola, onTap: () => context.push(Rutas.repaso)),
                const SizedBox(height: 16),
              ],
              for (final u in itinerario.units) ...[
                _NodoUnidad(
                  unit: u,
                  proyeccion: p,
                  desplegada: u.id == desplegada,
                  seleccionada: u.id == seleccionada,
                  alTocar: () => alElegirUnidad(u.id),
                ),
                const SizedBox(height: 10),
              ],
              if (itinerario.units.isEmpty) Text('Sin unidades descargadas', style: TextStyle(color: c.atenuado)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.proyeccion});
  final Proyeccion proyeccion;
  @override
  Widget build(BuildContext context) {
    final r = proyeccion.racha;
    final c = context.vtm;
    final unidadRacha = r.tipo.name == 'weekly' ? ('semana', 'semanas') : ('día', 'días');
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AnilloMeta(racha: r),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(textoMeta(r), style: context.textos.bodyMedium),
        ),
        Semantics(
          label: 'Racha de ${plural(r.actual, unidadRacha.$1, unidadRacha.$2)}',
          excludeSemantics: true,
          child: Etiqueta(plural(r.actual, unidadRacha.$1, unidadRacha.$2), icono: Symbols.local_fire_department, tono: TonoEtiqueta.acento),
        ),
        Semantics(
          label: '${proyeccion.puntosTotales} puntos',
          excludeSemantics: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Symbols.star, size: 18, color: c.primario),
            const SizedBox(width: 4),
            Text('${proyeccion.puntosTotales}', style: estiloCifra(context, size: 16)),
          ]),
        ),
        const DistintivoSinConexion(),
      ],
    );
  }
}

/// Nodo de la ruta: unidad con icono y texto de estado; desplegada, sus
/// lecciones.
class _NodoUnidad extends StatelessWidget {
  const _NodoUnidad({required this.unit, required this.proyeccion, required this.desplegada, required this.seleccionada, required this.alTocar});
  final Unit unit;
  final Proyeccion proyeccion;
  final bool desplegada;
  final bool seleccionada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = proyeccion;
    final c = context.vtm;
    final estado = p.unidades[unit.id] ?? EstadoUnidad.bloqueada;
    final info = p.infoUnidad(unit.id);
    var detalle = estado.etiqueta;
    if (estado == EstadoUnidad.enCurso && info != null) detalle += ' · ${info.leccionesHechas} de ${info.leccionesTotales} lecciones';
    return Tarjeta(
      key: ValueKey('unidad-${unit.id}'),
      seleccionada: seleccionada,
      onTap: alTocar,
      semantica: 'Unidad ${unit.order} · ${unit.name}. $detalle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(iconoUnidad(estado), color: estado == EstadoUnidad.bloqueada ? c.atenuado : c.primario),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unidad ${unit.order} · ${unit.name}', style: context.textos.titleMedium),
                    const SizedBox(height: 4),
                    Text(detalle, key: ValueKey('estado-${unit.id}'), style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                  ],
                ),
              ),
            ],
          ),
          if (desplegada) ...[
            const SizedBox(height: 12),
            ListaLecciones(unitId: unit.id, proyeccion: p),
          ],
        ],
      ),
    );
  }
}

/// Lecciones de una unidad con su estado. Tocar una bloqueada explica qué
/// falta y no la inicia.
class ListaLecciones extends StatelessWidget {
  const ListaLecciones({super.key, required this.unitId, required this.proyeccion, this.conPrecision = false});
  final String unitId;
  final Proyeccion proyeccion;
  final bool conPrecision;

  @override
  Widget build(BuildContext context) {
    final p = proyeccion;
    final c = context.vtm;
    final ls = p.leccionesPorUnidad[unitId] ?? const <Lesson>[];
    return Column(
      children: [
        for (final l in ls)
          Builder(builder: (context) {
            final e = p.estadoLeccion(l.id);
            final prog = p.lecciones[l.id];
            final siguiente = !e.hecha && e == EstadoLeccion.disponible;
            final partes = <String>[
              e.etiqueta,
              if (l.kind == LessonKind.challenge && !e.hecha) '10 ejercicios · 9 aciertos y ningún error crítico' else '${l.estimatedMinutes} min',
              if (conPrecision && prog?.mejorPrecision != null) '${(prog!.mejorPrecision! * 100).round()} %',
            ];
            return Semantics(
              button: true,
              label: '${l.order}. ${l.title}. ${partes.join(' · ')}',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('leccion-${l.id}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (e == EstadoLeccion.bloqueada) {
                    final m = p.mensajeBloqueo(l.id) ?? 'Lección bloqueada';
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(m)));
                    return;
                  }
                  context.push(Rutas.leccion(l.id));
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(iconoLeccion(e), size: 22, color: e == EstadoLeccion.bloqueada ? c.atenuado : (e.hecha ? c.exito : c.primario)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l.order}. ${l.title}', style: context.textos.bodyMedium?.copyWith(fontWeight: siguiente ? FontWeight.w600 : null)),
                              Text(partes.join(' · '), style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detalle de unidad (M13)
// ---------------------------------------------------------------------------

class PantallaUnidad extends ConsumerWidget {
  const PantallaUnidad({super.key, required this.unitId});
  final String unitId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = ref.watch(itinerarioActivoProvider);
    final u = it?.units.where((x) => x.id == unitId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(u == null ? 'Unidad' : 'Unidad ${u.order}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AnchoMaximo(child: DetalleUnidad(unitId: unitId)),
        ),
      ),
    );
  }
}

/// Detalle de unidad: habilidades, lecciones hechas, guía rápida, lecciones y
/// acciones. Se usa en pantalla propia (móvil) y en el panel derecho (tablet).
class DetalleUnidad extends ConsumerWidget {
  const DetalleUnidad({super.key, required this.unitId, this.enPanel = false});
  final String unitId;
  final bool enPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(proyeccionProvider);
    final it = ref.watch(itinerarioActivoProvider);
    final contenido = ref.watch(contenidoProvider).value;
    final u = it?.units.where((x) => x.id == unitId).firstOrNull;
    if (p == null || u == null || contenido == null) return const SizedBox.shrink();
    final c = context.vtm;
    final info = p.infoUnidad(u.id);
    final ls = p.leccionesPorUnidad[u.id] ?? const <Lesson>[];
    final reto = ls.where((l) => l.kind == LessonKind.challenge).firstOrNull;
    final siguiente = ls.where((l) => !p.estadoLeccion(l.id).hecha && p.estadoLeccion(l.id) == EstadoLeccion.disponible && l.kind != LessonKind.challenge).firstOrNull;
    final bloqueada = (p.unidades[u.id] ?? EstadoUnidad.bloqueada) == EstadoUnidad.bloqueada;
    final g = u.guide;

    return Column(
      key: ValueKey('detalle-${u.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (enPanel) Text('Unidad ${u.order}', style: context.textos.labelSmall?.copyWith(color: c.atenuado)),
        Semantics(header: true, child: Text(u.name, style: context.textos.headlineSmall)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in u.skills) Etiqueta('$s · ${contenido.global.skillName(s)}', tono: TonoEtiqueta.primario),
          Etiqueta((p.unidades[u.id] ?? EstadoUnidad.bloqueada).etiqueta, icono: iconoUnidad(p.unidades[u.id] ?? EstadoUnidad.bloqueada), tono: tonoUnidad(p.unidades[u.id] ?? EstadoUnidad.bloqueada)),
        ]),
        const SizedBox(height: 8),
        if (info != null) Text('${info.leccionesHechas} de ${info.leccionesTotales} lecciones', style: context.textos.bodyMedium),
        if (g.equivalences.isNotEmpty || g.exampleStatement.isNotEmpty) ...[
          const TituloSeccion('Guía rápida'),
          Tarjeta(
            tinte: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g.equivalences.isNotEmpty) Wrap(spacing: 16, runSpacing: 6, children: [for (final e in g.equivalences) Text(e, style: estiloCifra(context, size: 15))]),
                if (g.exampleStatement.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(g.exampleStatement, style: context.textos.bodyMedium),
                  for (final s in g.exampleSteps) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s, style: estiloCifra(context, size: 14, weight: FontWeight.w400))),
                  if (g.exampleAnswer.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(g.exampleAnswer, style: estiloCifra(context, size: 15))),
                ],
              ],
            ),
          ),
        ],
        const TituloSeccion('Lecciones'),
        ListaLecciones(unitId: u.id, proyeccion: p, conPrecision: true),
        const SizedBox(height: 16),
        if (siguiente != null)
          FilledButton(
            key: const ValueKey('empezar-leccion'),
            onPressed: () => context.push(Rutas.leccion(siguiente.id)),
            child: Text('Empezar lección ${siguiente.order}'),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            key: const ValueKey('manos-libres-unidad'),
            onPressed: () => context.push(Rutas.manosLibres),
            icon: const Icon(Symbols.headphones),
            label: const Text('Manos libres'),
          ),
          if (reto != null && !bloqueada && !(info?.retoSuperado ?? false))
            OutlinedButton.icon(
              key: const ValueKey('reto-y-saltar'),
              onPressed: () => context.push(Rutas.leccion(reto.id)),
              icon: const Icon(Symbols.flag),
              label: const Text('Reto y saltar'),
            ),
        ]),
      ],
    );
  }
}

/// Tarjetas de repaso y contrarreloj del panel derecho en tablet (T01).
class _TarjetasPracticaTablet extends ConsumerWidget {
  const _TarjetasPracticaTablet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(proyeccionProvider);
    if (p == null) return const SizedBox.shrink();
    final cola = p.colaHoy;
    final abiertas = p.habilidades.values.where((h) => h.estado.abreContrarreloj).length;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      SizedBox(
        width: 260,
        child: Tarjeta(
          onTap: () => context.push(cola.isEmpty ? Rutas.repaso : Rutas.repaso),
          semantica: 'Repaso. ${plural(cola.length, 'ficha', 'fichas')}',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Repaso', style: context.textos.titleMedium),
            Text(cola.isEmpty ? 'Sin fichas para hoy' : '${plural(cola.length, 'ficha', 'fichas')} · ${TarjetaRepaso.resumen(cola)}', style: context.textos.bodySmall),
          ]),
        ),
      ),
      SizedBox(
        width: 260,
        child: Tarjeta(
          onTap: () => context.push(Rutas.contrarreloj),
          semantica: 'Contrarreloj',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Contrarreloj', style: context.textos.titleMedium),
            Text(abiertas == 0 ? 'Consolida una habilidad para abrir el contrarreloj' : plural(abiertas, 'habilidad abierta', 'habilidades abiertas'), style: context.textos.bodySmall),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Practicar (M14)
// ---------------------------------------------------------------------------

class PantallaPracticar extends ConsumerWidget {
  const PantallaPracticar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(proyeccionProvider);
    final contenido = ref.watch(contenidoProvider).value;
    if (p == null || contenido == null) return const Scaffold(body: SafeArea(child: Esqueleto()));
    final c = context.vtm;
    final cola = p.colaHoy;
    final abiertas = p.habilidades.values.where((h) => h.estado.abreContrarreloj).length;
    final it = ref.watch(itinerarioActivoProvider);
    final usadas = {for (final u in it?.units ?? const <Unit>[]) ...u.skills};
    final habilidades = contenido.global.skills.where((s) => usadas.isEmpty || usadas.contains(s.id)).toList();

    Widget tarjeta(String clave, IconData icono, String titulo, String texto, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Tarjeta(
            key: ValueKey(clave),
            onTap: onTap,
            semantica: '$titulo. $texto',
            child: Row(children: [
              Icon(icono, color: c.primario),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo, style: context.textos.titleMedium),
                  Text(texto, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                ]),
              ),
              Icon(Symbols.chevron_right, color: c.atenuado),
            ]),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AnchoMaximo(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Semantics(header: true, child: Text('Practicar', style: context.textos.headlineSmall))),
                    const DistintivoSinConexion(),
                  ]),
                  const SizedBox(height: 16),
                  tarjeta(
                    'practicar-repaso',
                    Symbols.cards,
                    'Repaso de errores',
                    cola.isEmpty ? 'No tienes fichas para hoy' : '${plural(cola.length, 'ficha', 'fichas')} para hoy · ${TarjetaRepaso.resumen(cola)}',
                    () => context.push(Rutas.repaso),
                  ),
                  tarjeta('practicar-manos-libres', Symbols.headphones, 'Manos libres', 'Entrena sin mirar ni tocar. La voz no sale del dispositivo.', () => context.push(Rutas.manosLibres)),
                  tarjeta(
                    'practicar-contrarreloj',
                    Symbols.timer,
                    'Contrarreloj',
                    abiertas == 0
                        ? 'Consolida una habilidad para abrir el contrarreloj'
                        : 'Esprint de 60 s en habilidades consolidadas · ${plural(abiertas, 'habilidad abierta', 'habilidades abiertas')}',
                    () => context.push(Rutas.contrarreloj),
                  ),
                  const TituloSeccion('Práctica libre por habilidad'),
                  for (final s in habilidades)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Tarjeta(
                        key: ValueKey('practica-${s.id}'),
                        onTap: () => context.push(Rutas.practicaHabilidad(s.id)),
                        semantica: '${s.id} · ${s.name}. ${p.estadoHabilidad(s.id).etiqueta}',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Text('${s.id} · ${s.name}', style: context.textos.bodyMedium),
                            Etiqueta(p.estadoHabilidad(s.id).etiqueta, tono: tonoHabilidad(p.estadoHabilidad(s.id))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
