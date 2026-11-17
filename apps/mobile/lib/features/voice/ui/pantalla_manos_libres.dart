import 'dart:async';

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
import '../../../app/widgets/teclado.dart';
import '../../../core/contenido/verificador.dart';
import '../../../core/data/api_client.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../../ads/domain/ad_selector.dart';
import '../../session/domain/motor_sesion.dart';
import '../../subscription/domain/entitlements_policy.dart';
import '../data/paquete_voz.dart';
import '../domain/sesion_manos_libres.dart';
import '../domain/turno.dart';

/// Manos libres (M40–M49, T04): comprobaciones, paquete de voz, contenido y
/// duración, sesión por voz con botones de 72 dp y teclado, modo bolsillo y
/// resumen. La voz se procesa en este dispositivo.

enum _Fase { comprobando, limite, paquete, previa, config, sesion, resumen }

const textoVozLocal = 'Voz procesada en este dispositivo';
const textoMicrofonoDenegado =
    'Sin micrófono puedes seguir en modo táctil o responder con el teclado. Actívalo cuando quieras en Ajustes › VolutrainMed › Micrófono. La app funciona entera sin él.';
const textoSinPaqueteSinConexion = 'Para descargar el paquete de voz hace falta conexión. Mientras, puedes entrenar en modo táctil.';
const textoPaqueteAlterado = 'El paquete descargado no ha superado la verificación y se ha descartado.';
const claveImpresiones = 'anuncios.impresiones';

class PantallaManosLibres extends ConsumerStatefulWidget {
  const PantallaManosLibres({super.key});
  @override
  ConsumerState<PantallaManosLibres> createState() => _PantallaManosLibresState();
}

class _PantallaManosLibresState extends ConsumerState<PantallaManosLibres> {
  _Fase _fase = _Fase.comprobando;
  LimiteManosLibres? _limite;
  PaqueteVoz? _paquete;
  PaqueteVoz? _disponible;
  String? _errorPaquete;
  bool _descargando = false;
  EstadoPermiso _microfono = EstadoPermiso.noPedido;

  // Configuración (M41).
  ContenidoManosLibres _que = ContenidoManosLibres.leccion;
  int? _minutos = 10;
  String? _skillId;
  late ConfirmacionVoz _confirmacion;

  TurnoManosLibres? _turno;
  bool _escuchando = false;
  bool _despierto = false;
  final _entrada = EntradaNumerica();
  String? _anterior;

  Dependencias get _deps => ref.read(dependenciasProvider);
  ServicioPaqueteVoz get _servicio => ServicioPaqueteVoz(api: _deps.api, claves: _deps.claves);

  @override
  void initState() {
    super.initState();
    _confirmacion = ref.read(ajustesProvider).confirmacion;
    WidgetsBinding.instance.addPostFrameCallback((_) => _comprobar());
  }

  @override
  void dispose() {
    _turno?.removeListener(_alCambiar);
    _turno?.dispose();
    _entrada.dispose();
    super.dispose();
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  Future<void> _comprobar() async {
    final ahora = _deps.reloj.ahora();
    final efectivos = ref.read(derechosEfectivosProvider);
    final c = ref.read(contenidoProvider).value!;
    final datos = ref.read(aprendizajeProvider).value;
    final limite = limiteManosLibres(premium: efectivos.premium, usadoHoyMs: usadoHoyManosLibresMs(datos?.sesiones ?? const [], ahora), reglas: c.global.freePlan);
    _limite = limite;
    if (!limite.permitido) {
      setState(() => _fase = _Fase.limite);
      return;
    }
    _paquete = await _servicio.instalado();
    _microfono = await _deps.permisos.estadoMicrofono();
    if (!mounted) return;
    if (_paquete == null) {
      if (ref.read(enLineaProvider)) {
        try {
          _disponible = await _servicio.disponible();
        } catch (_) {
          _disponible = null;
        }
      }
      if (mounted) setState(() => _fase = _Fase.paquete);
      return;
    }
    setState(() => _fase = _Fase.previa);
  }

  Future<void> _descargar() async {
    setState(() {
      _descargando = true;
      _errorPaquete = null;
    });
    try {
      _paquete = await _servicio.descargar(meta: _disponible);
      if (mounted) setState(() => _fase = _Fase.previa);
    } on PaqueteNoValido {
      await _servicio.borrar();
      _errorPaquete = textoPaqueteAlterado;
    } on SinConexionException {
      _errorPaquete = textoSinPaqueteSinConexion;
    } catch (e) {
      _errorPaquete = 'No se ha podido descargar el paquete de voz. Inténtalo de nuevo.';
    }
    if (mounted) setState(() => _descargando = false);
  }

  Future<void> _pedirMicrofono() async {
    final r = await _deps.permisos.pedirMicrofono();
    await ref.read(usuarioProvider.notifier).actualizar((u) => u.copyWith(microfonoOfrecido: true));
    if (mounted) setState(() => _microfono = r);
  }

  void _modoTactil() => context.go(Rutas.inicio);

  // ---- Sesión --------------------------------------------------------------

  Future<void> _empezar() async {
    final c = ref.read(contenidoProvider).value!;
    final p = ref.read(proyeccionProvider);
    final it = ref.read(itinerarioActivoProvider);
    final ajustes = ref.read(ajustesProvider);
    final efectivos = ref.read(derechosEfectivosProvider);
    final usuario = ref.read(usuarioProvider).value!;
    final aprendizaje = ref.read(aprendizajeProvider.notifier);
    final deps = _deps;
    Lesson? leccion;
    if (it != null) leccion = p?.siguienteLeccion(it) ?? it.lessons.firstOrNull;
    final motor = crearMotorManosLibres(
      contenido: c,
      que: _que,
      deviceId: usuario.deviceId,
      relojMs: deps.relojMs,
      ahora: deps.reloj.ahora,
      leccion: leccion,
      fichas: p?.colaHoy ?? const [],
      variantes: _que == ContenidoManosLibres.habilidad && it != null ? variantesHabilidadVoz(c, it, _skillId ?? it.units.first.skills.first, deps.azar) : const [],
      sinAnuncios: efectivos.sinAnuncios,
      frecuenciaAnuncios: c.global.adParams.frequencyVoice,
      azar: deps.azar,
      alRegistrar: aprendizaje.registrarIntento,
      alEvento: aprendizaje.registrarEvento,
    );
    final elegido = _minutos == null ? null : _minutos! * 60000;
    final restante = _limite?.restanteMs;
    final limite = [elegido, restante].whereType<int>().fold<int?>(null, (m, v) => m == null || v < m ? v : m);
    final senales = ref.read(senalesProvider);
    final impresiones = ContadorImpresiones.fromJson(await deps.claves.leerJson(claveImpresiones));
    final selector = SelectorAnuncios(campanas: c.global.campaigns, params: c.global.adParams);
    final turno = TurnoManosLibres(
      motor: motor,
      sintetizador: deps.sintetizador,
      motorVoz: deps.motorVoz,
      confirmacion: _confirmacion.name,
      cifraACifraPorDefecto: ajustes.cifraACifra,
      sinonimos: ajustes.gammas ? const {'gammas': 'µg'} : const {},
      lexico: c.global.voiceLexicon,
      velocidad: ajustes.velocidadVoz,
      esperaSilencio: Duration(milliseconds: ajustes.esperaSilencioMs),
      limiteMs: limite,
      alSenal: senales.emitir,
      elegirCuna: efectivos.sinAnuncios
          ? null
          : () {
              final ahora = deps.reloj.ahora();
              final a = selector.elegir(
                ContextoAnuncio(
                  ahora: ahora,
                  impresiones: impresiones,
                  sectorId: usuario.perfil?.sectorId,
                  anterior: _anterior,
                  modoVoz: true,
                  esperaS: c.global.adParams.waitS,
                  enLeccion: false,
                  pruebaDisponible: pruebaDisponible(ref.read(derechosProvider)),
                  trasSesionManosLibres: true,
                  limiteManosLibresAgotado: false,
                  organizacionesActivas: c.global.orgsEnabled,
                ),
                deps.azar,
              );
              if (a != null) {
                _anterior = a.id;
                impresiones.registrar(a.id, ahora);
                deps.claves.escribirJson(claveImpresiones, impresiones.toJson());
                aprendizaje.registrarEvento('ad_impression', {'adId': a.id, 'context': a.creatividad.context, 'voice': true, 'sessionId': motor.sessionId});
              }
              return a;
            },
      alTerminar: (r) async {
        await aprendizaje.registrarSesion(r.registro);
        if (mounted) setState(() => _fase = _Fase.resumen);
      },
    );
    turno.addListener(_alCambiar);
    setState(() {
      _turno = turno;
      _fase = _Fase.sesion;
    });
    await turno.iniciar();
    unawaited(_bucle());
  }

  /// Escucha mientras el motor de voz esté disponible y haya algo que oír.
  Future<void> _bucle() async {
    final t = _turno;
    if (t == null || _escuchando) return;
    _escuchando = true;
    try {
      while (mounted && t.estado != EstadoTurno.terminada) {
        final algo = await t.escucharUnaVez();
        if (!algo) break;
      }
    } finally {
      _escuchando = false;
    }
  }

  Future<void> _accion(Future<void> Function(TurnoManosLibres t) f) async {
    final t = _turno;
    if (t == null) return;
    await f(t);
    unawaited(_bucle());
  }

  // ---- Interfaz ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cuerpo = switch (_fase) {
      _Fase.comprobando => const Esqueleto(),
      _Fase.limite => _pantallaLimite(),
      _Fase.paquete => _pantallaPaquete(),
      _Fase.previa => _pantallaPrevia(),
      _Fase.config => _pantallaConfig(),
      _Fase.sesion => _pantallaSesion(),
      _Fase.resumen => _pantallaResumen(),
    };
    if (_fase == _Fase.sesion) return cuerpo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manos libres'),
        leading: IconButton(icon: const Icon(Symbols.close), tooltip: 'Cerrar', onPressed: () => context.canPop() ? context.pop() : context.go(Rutas.practicar)),
      ),
      body: SafeArea(child: AnchoMaximo(child: cuerpo)),
    );
  }

  Widget _lista(List<Widget> hijos, {List<Widget> pie = const []}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: hijos)),
          if (pie.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: pie)),
        ],
      );

  Widget _pantallaLimite() => _lista([
        Text('Límite diario alcanzado', style: context.textos.headlineSmall),
        const SizedBox(height: 12),
        Text(_limite?.mensaje ?? '', style: context.textos.bodyLarge),
      ], pie: [
        FilledButton(onPressed: _modoTactil, child: const Text('Seguir en modo táctil')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => context.push(Rutas.suscripcion), child: const Text('Ver Premium')),
      ]);

  Widget _pantallaPaquete() {
    final enLinea = ref.watch(enLineaProvider);
    return _lista([
      Text('Descarga el paquete de voz', style: context.textos.headlineSmall),
      const SizedBox(height: 8),
      Text('Reconocimiento y lectura funcionan dentro del dispositivo. Se descarga una vez y sirve sin conexión.', style: context.textos.bodyMedium),
      const SizedBox(height: 16),
      Tarjeta(
        child: Row(children: [
          const Icon(Symbols.record_voice_over),
          const SizedBox(width: 12),
          Expanded(child: Text('Español de España${_disponible == null ? '' : ' · ${_disponible!.tamanoTexto}'}', style: context.textos.titleMedium)),
        ]),
      ),
      if (!enLinea || (_disponible == null && _errorPaquete == null)) ...[
        const SizedBox(height: 16),
        Text(textoSinPaqueteSinConexion, style: context.textos.bodyMedium),
      ],
      if (_errorPaquete != null) ...[
        const SizedBox(height: 16),
        Etiqueta(_errorPaquete!, icono: Symbols.error, tono: TonoEtiqueta.error),
      ],
    ], pie: [
      if (enLinea)
        FilledButton(
          onPressed: _descargando ? null : _descargar,
          child: Text(_errorPaquete == textoPaqueteAlterado ? 'Descargar de nuevo' : (_descargando ? 'Descargando…' : 'Descargar')),
        ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: _modoTactil, child: const Text('Usar el modo táctil')),
    ]);
  }

  Widget _fila(IconData icono, String titulo, String detalle, bool listo) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tarjeta(
          child: Row(children: [
            Icon(icono),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: context.textos.titleSmall),
                Text(detalle, style: context.textos.bodySmall),
              ]),
            ),
            Etiqueta(listo ? 'Listo' : 'Pendiente', tono: listo ? TonoEtiqueta.exito : TonoEtiqueta.aviso),
          ]),
        ),
      );

  Widget _pantallaPrevia() {
    final voz = _deps.motorVoz;
    final ofrecido = ref.watch(usuarioProvider).value?.microfonoOfrecido ?? false;
    final denegado = _microfono == EstadoPermiso.denegado || _microfono == EstadoPermiso.denegadoPermanente;
    return _lista([
      _fila(Symbols.download_done, 'Paquete de voz', 'Descargado · ${_paquete?.tamanoTexto ?? ''}', true),
      _fila(Symbols.mic, 'Micrófono', _microfono == EstadoPermiso.concedido ? 'Permiso concedido' : (denegado ? 'Sin permiso' : 'Lo pediremos ahora'), _microfono == EstadoPermiso.concedido),
      _fila(Symbols.hearing, 'Reconocimiento', voz.disponible ? 'En el dispositivo, sin red' : (voz.motivoNoDisponible ?? ''), voz.disponible),
      if (!ofrecido && _microfono != EstadoPermiso.concedido) ...[
        const SizedBox(height: 8),
        Text('Para entender tus respuestas, manos libres usa el micrófono. El audio no se guarda ni sale del dispositivo.', style: context.textos.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _pedirMicrofono, child: const Text('Permitir el micrófono')),
      ],
      if (denegado) ...[
        const SizedBox(height: 8),
        Tarjeta(
          tinte: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Micrófono sin permiso', style: context.textos.titleSmall),
            const SizedBox(height: 4),
            Text(textoMicrofonoDenegado, style: context.textos.bodyMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: _deps.permisos.abrirAjustes, child: const Text('Abrir ajustes')),
              OutlinedButton(onPressed: _modoTactil, child: const Text('Usar el modo táctil')),
            ]),
          ]),
        ),
      ],
      const SizedBox(height: 8),
      Text('El audio no se guarda ni sale del dispositivo. Funciona en modo avión.', style: context.textos.bodySmall),
    ], pie: [
      FilledButton(onPressed: () => setState(() => _fase = _Fase.config), child: const Text('Continuar')),
    ]);
  }

  Widget _pantallaConfig() {
    final p = ref.watch(proyeccionProvider);
    final it = ref.watch(itinerarioActivoProvider);
    final c = ref.watch(contenidoProvider).value!;
    final leccion = it == null ? null : (p?.siguienteLeccion(it) ?? it.lessons.firstOrNull);
    final habilidades = it == null ? <String>[] : {for (final u in it.units) ...u.skills}.toList();
    _skillId ??= habilidades.firstOrNull;
    Widget opcion(ContenidoManosLibres v, String titulo, String detalle) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tarjeta(
            seleccionada: _que == v,
            semantica: titulo,
            onTap: () => setState(() => _que = v),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: context.textos.titleMedium),
              Text(detalle, style: context.textos.bodySmall),
            ]),
          ),
        );
    return _lista([
      Text('¿Qué quieres entrenar?', style: context.textos.headlineSmall),
      const SizedBox(height: 12),
      opcion(ContenidoManosLibres.repaso, 'Repaso', '${p?.colaHoy.length ?? 0} fichas pendientes'),
      opcion(ContenidoManosLibres.leccion, 'Lección actual', leccion == null ? '' : '${it!.units.firstWhere((u) => u.id == leccion.unitId).name} · Lección ${leccion.order}'),
      opcion(ContenidoManosLibres.habilidad, 'Una habilidad', _skillId == null ? 'Elige cuál' : c.global.skillName(_skillId!)),
      if (_que == ContenidoManosLibres.habilidad)
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in habilidades)
            ChoiceChip(label: Text('$s · ${c.global.skillName(s)}'), selected: _skillId == s, onSelected: (_) => setState(() => _skillId = s)),
        ]),
      const TituloSeccion('Duración'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in duracionesManosLibres)
          ChoiceChip(label: Text(m == null ? 'Sin límite' : '$m min'), selected: _minutos == m, onSelected: (_) => setState(() => _minutos = m)),
      ]),
      const SizedBox(height: 12),
      Text('Solo entran ejercicios compatibles con voz: respuesta numérica, selección, estimación y conversión.', style: context.textos.bodySmall),
      const TituloSeccion('Confirmar lo entendido'),
      SegmentedButton<ConfirmacionVoz>(
        segments: const [
          ButtonSegment(value: ConfirmacionVoz.siempre, label: Text('Siempre')),
          ButtonSegment(value: ConfirmacionVoz.siHayDuda, label: Text('Si hay duda')),
          ButtonSegment(value: ConfirmacionVoz.nunca, label: Text('Nunca')),
        ],
        selected: {_confirmacion},
        onSelectionChanged: (s) => setState(() => _confirmacion = s.first),
      ),
    ], pie: [
      FilledButton(onPressed: _empezar, child: const Text('Empezar')),
    ]);
  }

  // ---- Sesión (M42–M47, T04) -----------------------------------------------

  static String palabraEstado(TurnoManosLibres t) => switch (t.estado) {
        EstadoTurno.leyendo => 'Leyendo',
        EstadoTurno.escuchando => 'Te escucho',
        EstadoTurno.confirmando => '¿Correcto?',
        EstadoTurno.preguntando => '¿Cuál?',
        EstadoTurno.veredicto => t.resultado?.acierto == true ? 'Correcto' : (t.resultado?.noLoSe == true ? 'Respuesta' : 'Incorrecto'),
        EstadoTurno.cuna => rotuloPromocion,
        EstadoTurno.pausa => 'En pausa',
        EstadoTurno.teclado => 'Teclado',
        EstadoTurno.confirmandoSalida => '¿Salir?',
        EstadoTurno.terminada => 'Terminado',
      };

  String _ayuda(TurnoManosLibres t) => switch (t.estado) {
        EstadoTurno.leyendo => 'Di «repite», «más despacio» o «pausa» cuando quieras.',
        EstadoTurno.escuchando => t.unidadFija != null ? 'Di solo la cifra. La unidad es ${t.unidadFija}.' : 'Di la cifra y la unidad.',
        EstadoTurno.confirmando => 'Di «sí» o «no», o dila otra vez directamente.',
        EstadoTurno.veredicto => 'Di «explica», «siguiente» o «repite».',
        EstadoTurno.pausa => 'Di «continúa» o toca la pantalla.',
        EstadoTurno.cuna => 'Di «siguiente» para saltarla o «más información».',
        _ => '',
      };

  Widget _pantallaSesion() {
    final t = _turno!;
    final ajustes = ref.watch(ajustesProvider);
    final c = context.vtm;
    final e = t.ejercicio;
    final m = t.motor;
    final restante = t.limiteMs == null ? null : (t.limiteMs! - m.registro(completada: false).practiceMs).clamp(0, t.limiteMs!);
    final cabecera = 'Ejercicio ${m.posicion.clamp(1, m.total == 0 ? 1 : m.total)} de ${m.total}'
        '${restante == null ? '' : ' · Quedan ${restante ~/ 60000}:${((restante % 60000) ~/ 1000).toString().padLeft(2, '0')}'}';
    final correcto = t.resultado?.acierto;

    final principal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          IconButton(icon: const Icon(Symbols.close), tooltip: 'Salir', onPressed: () => _accion((t) => t.pedirSalida())),
          Expanded(child: Text(cabecera, style: context.textos.labelLarge)),
        ]),
        Expanded(
          child: GestureDetector(
            key: const ValueKey('zona-pausa'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _accion((t) => t.alternarPausa()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    palabraEstado(t),
                    key: const ValueKey('estado-voz'),
                    style: context.textos.displaySmall?.copyWith(
                      color: t.estado == EstadoTurno.veredicto ? (correcto == true ? c.exito : c.errorFuerte) : c.primario,
                    ),
                  ),
                ),
                if (t.estado == EstadoTurno.veredicto)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(correcto == true ? Symbols.check_circle : Symbols.cancel, color: correcto == true ? c.exito : c.errorFuerte, size: 32),
                  ),
                if (t.cifraEntendida != null && (t.estado == EstadoTurno.confirmando || t.estado == EstadoTurno.preguntando)) ...[
                  const SizedBox(height: 12),
                  Text(t.cifraEntendida!, key: const ValueKey('cifra-entendida'), style: estiloCifra(context, size: 48)),
                ],
                const SizedBox(height: 12),
                Text(t.textoPantalla, key: const ValueKey('texto-dicho'), style: context.textos.bodyLarge),
                if (t.aviso != null) ...[
                  const SizedBox(height: 12),
                  Etiqueta(t.aviso!, icono: Symbols.noise_aware, tono: TonoEtiqueta.aviso),
                ],
                const SizedBox(height: 12),
                Text(_ayuda(t), style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
                if (!_deps.motorVoz.disponible) ...[
                  const SizedBox(height: 12),
                  Tarjeta(tinte: true, child: Text(_deps.motorVoz.motivoNoDisponible ?? '', style: context.textos.bodySmall)),
                ],
                if (t.estado == EstadoTurno.confirmandoSalida) ...[
                  const SizedBox(height: 16),
                  Tarjeta(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('¿Salir de la sesión?', style: context.textos.titleMedium),
                      const SizedBox(height: 8),
                      Text('Se guarda lo hecho hasta aquí.', style: context.textos.bodyMedium),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: () => t.cancelarSalida(), child: const Text('Seguir')),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: () => t.confirmarSalida(), child: const Text('Salir')),
                    ]),
                  ),
                ],
                if (t.estado == EstadoTurno.teclado && e != null) ...[const SizedBox(height: 16), _respuestaManual(t, e)],
              ],
            ),
          ),
        ),
        _botonera(t),
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.lock, size: 16, color: c.atenuado),
            const SizedBox(width: 6),
            Flexible(child: Text(textoVozLocal, style: context.textos.labelMedium?.copyWith(color: c.atenuado))),
          ]),
        ),
      ],
    );

    final lateral = e == null
        ? null
        : ListView(padding: const EdgeInsets.all(16), children: [
            Enunciado(e.variante, rotulo: 'Enunciado', compacto: true),
            const TituloSeccion('Esta sesión'),
            for (final (i, r) in m.primerosIntentos.indexed)
              ListTile(
                dense: true,
                leading: Text('${i + 1}', style: estiloCifra(context, size: 14)),
                title: Text(r.valor == null ? (r.noLoSe ? 'No lo sé' : '—') : r.correcta),
                trailing: Etiqueta(r.acierto ? 'Correcto' : 'Incorrecto', tono: r.acierto ? TonoEtiqueta.exito : TonoEtiqueta.error),
              ),
          ]);

    Widget pantalla = Scaffold(
      body: SafeArea(child: DosPaneles(principal: AnchoMaximo(child: principal), secundario: lateral, proporcion: 0.55)),
    );

    if (ajustes.modoBolsillo && !_despierto) {
      pantalla = Stack(children: [
        pantalla,
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('modo-bolsillo'),
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => setState(() => _despierto = true),
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(palabraEstado(t), style: context.textos.headlineSmall?.copyWith(color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(cabecera, style: context.textos.bodyMedium?.copyWith(color: const Color(0xFFCBD5E1))),
                  const SizedBox(height: 24),
                  Text('Toque bloqueado · doble toque para despertar', style: context.textos.bodySmall?.copyWith(color: const Color(0xFFCBD5E1))),
                ]),
              ),
            ),
          ),
        ),
      ]);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _accion((t) => t.pedirSalida());
      },
      child: pantalla,
    );
  }

  Widget _botonGrande(String texto, IconData icono, VoidCallback onTap, Key key) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            height: 72,
            child: OutlinedButton(
              key: key,
              onPressed: onTap,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icono),
                FittedBox(child: Text(texto)),
              ]),
            ),
          ),
        ),
      );

  Widget _botonera(TurnoManosLibres t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(children: [
          Row(children: [
            _botonGrande('Repetir', Symbols.replay, () => _accion((t) => t.repetir()), const ValueKey('boton-repetir')),
            _botonGrande('No lo sé', Symbols.help, () => _accion((t) => t.noLoSe()), const ValueKey('boton-no-lo-se')),
            _botonGrande('Siguiente', Symbols.skip_next, () => _accion((t) => t.siguiente()), const ValueKey('boton-siguiente')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _botonGrande('Teclado', Symbols.keyboard, () => _accion((t) async => t.abrirTeclado()), const ValueKey('boton-teclado')),
            _botonGrande(t.pausado ? 'Continuar' : 'Pausa', t.pausado ? Symbols.play_arrow : Symbols.pause, () => _accion((t) => t.alternarPausa()), const ValueKey('boton-pausa')),
          ]),
        ]),
      );

  Widget _respuestaManual(TurnoManosLibres t, EjercicioPreparado e) {
    final v = e.variante;
    if (t.esOpcion) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, o) in v.options!.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: ValueKey('opcion-${o.id}'),
              onPressed: () => _accion((t) => t.responderOpcionBoton(o.id)),
              child: Text('${String.fromCharCode(65 + i)} · ${o.label}'),
            ),
          ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CampoRespuesta(entrada: _entrada, unidad: t.unidadFija ?? v.answer?.unit),
      const SizedBox(height: 8),
      TecladoNumerico(entrada: _entrada, senales: ref.read(senalesProvider)),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: _entrada,
        builder: (context, _) => FilledButton(
          key: const ValueKey('boton-comprobar'),
          onPressed: _entrada.vacia
              ? null
              : () async {
                  final raw = _entrada.texto;
                  _entrada.limpiar();
                  await _accion((t) => t.responderTeclado(raw));
                },
          child: const Text('Comprobar'),
        ),
      ),
    ]);
  }

  Widget _pantallaResumen() {
    final r = _turno!.resumen!;
    final pct = (r.precision * 100).round();
    final primera = (r.fraccionALaPrimera * 100).round();
    return _lista([
      Text('Sesión de manos libres · ${r.minutos} min', style: context.textos.labelLarge),
      const SizedBox(height: 8),
      Text('${r.ejercicios} ejercicios · $pct %', style: context.textos.headlineMedium),
      const SizedBox(height: 12),
      Tarjeta(tinte: true, child: Text('Resumen hablado: «${r.hablado}»', style: context.textos.bodyMedium)),
      const SizedBox(height: 12),
      _dato('A repaso', '${r.aRepaso}'),
      _dato('Entendidas a la primera', '$primera %'),
      _dato('Al teclado', '${r.alTeclado}'),
      const SizedBox(height: 12),
      Text(textoSinAudio, style: context.textos.bodySmall),
      if (r.anuncio != null) ...[
        const SizedBox(height: 16),
        Tarjeta(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(rotuloPromocion, style: context.textos.labelSmall),
            const SizedBox(height: 6),
            Text(r.anuncio!.titular, style: context.textos.titleMedium),
            Text(r.anuncio!.texto, style: context.textos.bodyMedium),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('accion-anuncio'),
              onPressed: () => context.push('${Rutas.suscripcion}?anuncio=${r.anuncio!.id}'),
              child: Text(r.anuncio!.accion),
            ),
          ]),
        ),
      ],
    ], pie: [
      FilledButton(
        onPressed: () {
          _turno?.removeListener(_alCambiar);
          setState(() {
            _turno = null;
            _fase = _Fase.config;
          });
        },
        child: const Text('Otra sesión'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => context.go(Rutas.practicar), child: const Text('Salir')),
    ]);
  }

  Widget _dato(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(k, style: context.textos.bodyMedium)), Text(v, style: estiloCifra(context, size: 18))]),
      );
}
