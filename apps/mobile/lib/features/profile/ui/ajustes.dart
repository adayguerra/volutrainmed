import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/ajustes.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/contenido/actualizador.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import 'comunes_perfil.dart';

/// Ajustes de voz (M55). La lectura usa la voz del sistema; el
/// reconocimiento es embebido y nunca sale del dispositivo.
class PantallaAjustesVoz extends ConsumerWidget {
  const PantallaAjustesVoz({super.key});

  static const ejemplo = 'Cuatro coma ocho mililitros por hora';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(ajustesProvider);
    final n = ref.read(ajustesProvider.notifier);
    final deps = ref.watch(dependenciasProvider);
    final motor = deps.motorVoz;
    final c = context.vtm;
    return AndamioAjustes(titulo: 'Voz', hijos: [
      BloqueAjustes(titulo: 'Paquete de voz · español', hijos: [
        FilaAjuste(
          icono: motor.disponible ? Symbols.check_circle : Symbols.hourglass_top,
          titulo: motor.disponible ? 'Reconocimiento listo' : 'Reconocimiento pendiente',
          detalle: motor.disponible ? 'Funciona sin conexión. El audio no se guarda ni sale del dispositivo.' : motor.motivoNoDisponible,
        ),
      ]),
      BloqueAjustes(titulo: 'Lectura', hijos: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Velocidad ${a.velocidadVoz.toStringAsFixed(1).replaceAll('.', ',')}×', style: context.textos.titleSmall),
        ),
        Slider(
          value: a.velocidadVoz,
          min: 0.8,
          max: 1.5,
          divisions: 7,
          label: '${a.velocidadVoz.toStringAsFixed(1).replaceAll('.', ',')}×',
          semanticFormatterCallback: (v) => 'Velocidad ${v.toStringAsFixed(1).replaceAll('.', ' coma ')}',
          onChanged: (v) => n.cambiar((x) => x.copyWith(velocidadVoz: double.parse(v.toStringAsFixed(1)))),
        ),
        FilaAjuste(
          icono: Symbols.volume_up,
          titulo: 'Escuchar ejemplo',
          detalle: '«$ejemplo»',
          onTap: () => deps.sintetizador.decir(ejemplo, velocidad: a.velocidadVoz),
        ),
        OpcionesSegmentadas<String>(
          etiqueta: 'Lectura de explicaciones',
          opciones: const {'breve': 'Breve', 'completa': 'Completa', 'ninguna': 'Ninguna'},
          valor: a.lecturaExplicaciones,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(lecturaExplicaciones: v)),
        ),
      ]),
      BloqueAjustes(titulo: 'Reconocimiento', hijos: [
        OpcionesSegmentadas<ConfirmacionVoz>(
          etiqueta: 'Confirmar lo entendido',
          opciones: const {ConfirmacionVoz.siempre: 'Siempre', ConfirmacionVoz.siHayDuda: 'Si hay duda', ConfirmacionVoz.nunca: 'Nunca'},
          valor: a.confirmacion,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(confirmacion: v)),
        ),
        OpcionesSegmentadas<int>(
          etiqueta: 'Espera de silencio',
          opciones: const {600: '0,6 s', 900: '0,9 s', 1500: '1,5 s'},
          valor: a.esperaSilencioMs,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(esperaSilencioMs: v)),
        ),
        FilaInterruptor(
          titulo: 'Cifra a cifra por defecto',
          detalle: '«uno, dos, cero» = 120',
          valor: a.cifraACifra,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(cifraACifra: v)),
        ),
        FilaInterruptor(
          titulo: 'Aceptar «gammas»',
          detalle: 'Como sinónimo de microgramos',
          valor: a.gammas,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(gammas: v)),
        ),
        FilaInterruptor(
          titulo: 'Modo bolsillo',
          detalle: 'Bloquea los toques; doble toque para despertar',
          valor: a.modoBolsillo,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(modoBolsillo: v)),
        ),
      ]),
      BloqueAjustes(titulo: 'Prueba de micrófono', hijos: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            motor.disponible
                ? 'Di «cuatro coma ocho mililitros por hora» al empezar una sesión de manos libres para comprobar el micrófono.'
                : 'La prueba de micrófono estará disponible cuando llegue el reconocimiento embebido. Hasta entonces, en manos libres puedes responder con el teclado y los botones.',
            style: context.textos.bodyMedium?.copyWith(color: c.atenuado),
          ),
        ),
      ]),
    ]);
  }
}

/// Accesibilidad y apariencia (M56, T07) con muestra en vivo.
class PantallaAccesibilidad extends ConsumerWidget {
  const PantallaAccesibilidad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(ajustesProvider);
    final n = ref.read(ajustesProvider.notifier);
    final c = context.vtm;
    return AndamioAjustes(titulo: 'Accesibilidad y apariencia', hijos: [
      BloqueAjustes(titulo: 'Muestra en vivo', hijos: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Etiqueta('Caso simulado · perro', icono: Symbols.science),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text('Perro de', style: context.textos.bodyLarge),
                  const Cantidad('24', 'kg'),
                  Text('. Presentación:', style: context.textos.bodyLarge),
                  const Cantidad('5', 'mg/ml'),
                  Text('.', style: context.textos.bodyLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text('Se lee: «${lecturaCantidad('5', 'mg/ml')}»', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
            ],
          ),
        ),
      ]),
      BloqueAjustes(titulo: 'Texto y contraste', hijos: [
        OpcionesSegmentadas<double>(
          etiqueta: 'Tamaño de texto adicional',
          opciones: {0.0: 'Normal', 0.15: '+15 %', 0.3: '+30 %', 0.5: '+50 %'},
          valor: a.textoExtra,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(textoExtra: v)),
        ),
        FilaInterruptor(titulo: 'Alto contraste', detalle: 'Bordes y textos más marcados', valor: a.altoContraste, alCambiar: (v) => n.cambiar((x) => x.copyWith(altoContraste: v))),
        OpcionesSegmentadas<ThemeMode>(
          etiqueta: 'Tema',
          opciones: const {ThemeMode.light: 'Claro', ThemeMode.dark: 'Oscuro', ThemeMode.system: 'Sistema'},
          valor: a.tema,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(tema: v)),
        ),
      ]),
      BloqueAjustes(titulo: 'Movimiento y señales', hijos: [
        FilaInterruptor(titulo: 'Reducir movimiento', detalle: 'Solo fundidos de 150 ms', valor: a.reducirMovimiento, alCambiar: (v) => n.cambiar((x) => x.copyWith(reducirMovimiento: v))),
        FilaInterruptor(titulo: 'Respuesta háptica', detalle: 'Vibración al pulsar y al corregir', valor: a.haptica, alCambiar: (v) => n.cambiar((x) => x.copyWith(haptica: v))),
        FilaInterruptor(titulo: 'Sonidos', detalle: 'Respetan el modo silencio', valor: a.sonidos, alCambiar: (v) => n.cambiar((x) => x.copyWith(sonidos: v))),
      ]),
      BloqueAjustes(titulo: 'Práctica', hijos: [
        FilaInterruptor(
          titulo: 'Ejercicios sin límite de tiempo',
          detalle: 'El tiempo se mide pero no limita',
          valor: a.sinLimiteTiempo,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(sinLimiteTiempo: v)),
        ),
        OpcionesSegmentadas<bool>(
          etiqueta: 'Mano dominante',
          opciones: const {true: 'Izquierda', false: 'Derecha'},
          valor: a.manoIzquierda,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(manoIzquierda: v)),
        ),
        OpcionesSegmentadas<int>(
          etiqueta: 'Fichas de repaso al día',
          opciones: const {10: '10', 20: '20', 30: '30', 40: '40'},
          valor: a.topeRepaso,
          alCambiar: (v) => n.cambiar((x) => x.copyWith(topeRepaso: v)),
        ),
      ]),
      Text('Los cambios se aplican al momento.', style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
    ]);
  }
}

/// Meta de práctica y recordatorio diario.
class PantallaMetaAjustes extends ConsumerWidget {
  const PantallaMetaAjustes({super.key});

  static const idRecordatorio = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meta = ref.watch(usuarioProvider).value?.perfil?.goal;
    final a = ref.watch(ajustesProvider);
    final clave = meta == null ? 'ninguna' : (meta.kind == GoalKind.daily ? 'd${meta.minutes}' : 'w${meta.days}');
    Future<void> elegir(String k) async {
      final g = k.startsWith('d') ? Goal.daily(int.parse(k.substring(1))) : Goal.weekly(int.parse(k.substring(1)));
      await ref.read(usuarioProvider.notifier).editarPerfil((p) => p.copyWith(goal: g));
      final u = ref.read(usuarioProvider).value;
      if (u?.conCuenta == true) unawaited(ref.read(dependenciasProvider).api.patchMe({'goal': g.toJson()}).then((_) {}, onError: (_) {}));
    }

    return AndamioAjustes(titulo: 'Meta y recordatorios', hijos: [
      BloqueAjustes(titulo: 'Meta', hijos: [
        OpcionesSegmentadas<String>(
          etiqueta: 'Meta diaria',
          opciones: const {'d5': '5 min', 'd10': '10 min', 'd15': '15 min'},
          valor: clave,
          alCambiar: elegir,
        ),
        OpcionesSegmentadas<String>(
          etiqueta: 'Meta semanal (para quien trabaja a turnos)',
          opciones: const {'w2': '2 días', 'w3': '3 días', 'w4': '4 días', 'w5': '5 días'},
          valor: clave,
          alCambiar: elegir,
        ),
      ]),
      BloqueAjustes(titulo: 'Recordatorio diario', hijos: [
        FilaInterruptor(
          titulo: 'Recordarme el repaso',
          detalle: a.recordatorio == null ? 'Desactivado' : 'Cada día a las ${a.recordatorio}',
          valor: a.recordatorio != null,
          alCambiar: (v) async {
            final deps = ref.read(dependenciasProvider);
            if (!v) {
              await ref.read(ajustesProvider.notifier).cambiar((x) => x.copyWith(quitarRecordatorio: true));
              await deps.notificador.cancelar(idRecordatorio);
              return;
            }
            final hora = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 30));
            if (hora == null) return;
            final texto = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
            await ref.read(ajustesProvider.notifier).cambiar((x) => x.copyWith(recordatorio: texto));
            final ahora = deps.reloj.ahora();
            var cuando = DateTime(ahora.year, ahora.month, ahora.day, hora.hour, hora.minute);
            if (!cuando.isAfter(ahora)) cuando = cuando.add(const Duration(days: 1));
            await deps.notificador.programar(NotificacionProgramada(
              id: idRecordatorio,
              cuando: cuando,
              titulo: 'VolutrainMed',
              texto: 'Tienes fichas de repaso. Son unos minutos de entrenamiento.',
            ));
          },
        ),
      ]),
    ]);
  }
}

/// Itinerario activo: cambiar de itinerario descarga su paquete si hace falta.
class PantallaItinerario extends ConsumerStatefulWidget {
  const PantallaItinerario({super.key});
  @override
  ConsumerState<PantallaItinerario> createState() => _PantallaItinerarioState();
}

class _PantallaItinerarioState extends ConsumerState<PantallaItinerario> {
  String? _descargando;
  double? _fraccion;

  Future<void> _elegir(String id) async {
    final c = ref.read(contenidoProvider).value;
    final u = ref.read(usuarioProvider.notifier);
    final mensajero = ScaffoldMessenger.of(context);
    if (c?.itinerario(id) == null) {
      if (!ref.read(enLineaProvider)) {
        mensajero.showSnackBar(const SnackBar(content: Text('Hace falta conexión para descargar este itinerario. Puedes seguir entrenando con el actual.')));
        return;
      }
      setState(() => _descargando = id);
      final act = ref.read(actualizadorProvider);
      try {
        await act.descargarItinerario(id, progreso: (r, t) {
          if (mounted) setState(() => _fraccion = t <= 0 ? null : r / t);
        });
        await act.aplicarPreparadas();
      } catch (e) {
        if (mounted) setState(() => _descargando = null);
        mensajero.showSnackBar(SnackBar(content: Text('No se ha podido descargar: $e')));
        return;
      }
      if (mounted) setState(() => _descargando = null);
    }
    await u.editarPerfil((p) => p.copyWith(itineraryId: id));
    final estado = ref.read(usuarioProvider).value;
    if (estado?.conCuenta == true) {
      unawaited(ref.read(dependenciasProvider).api.patchMe({'itineraryId': id}).then((_) {}, onError: (_) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contenidoProvider).value;
    final actual = ref.watch(itinerarioActivoProvider)?.itinerary.id;
    final vtm = context.vtm;
    return AndamioAjustes(titulo: 'Mi itinerario', hijos: [
      if (c != null)
        for (final it in c.global.itineraries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Tarjeta(
              seleccionada: it.id == actual,
              onTap: _descargando == null ? () => _elegir(it.id) : null,
              semantica: '${it.name}${it.id == actual ? ', elegido' : ''}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(it.name, style: context.textos.titleMedium)),
                      if (it.id == actual) Icon(Symbols.check_circle, color: vtm.primario, fill: 1),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(it.description, style: context.textos.bodySmall?.copyWith(color: vtm.atenuado)),
                  const SizedBox(height: 8),
                  Etiqueta(
                    c.itinerario(it.id) != null ? 'En el dispositivo' : 'Se descarga al elegirlo',
                    icono: c.itinerario(it.id) != null ? Symbols.download_done : Symbols.download,
                    tono: c.itinerario(it.id) != null ? TonoEtiqueta.exito : TonoEtiqueta.neutro,
                  ),
                  if (_descargando == it.id) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _fraccion, semanticsLabel: 'Descargando ${it.name}'),
                  ],
                ],
              ),
            ),
          ),
    ]);
  }
}
