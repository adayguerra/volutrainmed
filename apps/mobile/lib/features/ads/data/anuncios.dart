import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import '../../subscription/data/tienda.dart';
import '../../subscription/domain/entitlements_policy.dart';
import '../domain/ad_selector.dart';
import '../ui/pausa_promocional.dart';

/// Inventario propio y local de anuncios (house-ads): todo se decide en el
/// dispositivo con el contenido descargado. Aquí no hay ninguna llamada de
/// red ni identificadores publicitarios.

const claveImpresiones = 'anuncios.impresiones';
const claveAnuncioAnterior = 'anuncios.anterior';

/// Anuncio cuya acción tocó el usuario en esta sesión de la app; la compra
/// posterior queda atribuida a él (house-ads, «Conversión atribuida»).
class AnuncioAtribuidoNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void fijar(String? id) => state = id;
}

final anuncioAtribuidoProvider = NotifierProvider<AnuncioAtribuidoNotifier, String?>(AnuncioAtribuidoNotifier.new);

/// Milisegundos de manos libres usados hoy (plan gratuito).
int manosLibresHoyMs(List<SessionRecord> sesiones, DateTime ahora) {
  final hoy = diaLocal(ahora);
  return sesiones
      .where((s) => s.mode == SessionMode.handsfree && diaLocal(s.startedAt) == hoy)
      .fold(0, (n, s) => n + s.practiceMs);
}

/// Anuncio elegido para una pausa, con el contexto que lo activó.
class AnuncioElegido {
  const AnuncioElegido(this.anuncio, this.contexto, this.esperaS);
  final AnuncioResuelto anuncio;
  final ContextoAnuncio contexto;
  final int esperaS;
}

/// Construye el contexto de la pausa con datos reales del usuario.
Future<ContextoAnuncio> construirContexto(Lector leer, DatosPausa datos, {bool modoVoz = false}) async {
  final deps = leer(dependenciasProvider);
  final ahora = deps.reloj.ahora();
  final contenido = leer(contenidoProvider).value;
  final params = contenido?.global.adParams;
  final usuario = leer(usuarioProvider).value;
  final proy = leer(proyeccionProvider);
  final derechos = leer(derechosProvider);
  final precios = await leerPreciosGuardados(deps.claves);
  final sesiones = leer(aprendizajeProvider).value?.sesiones ?? const [];
  final efectivos = derechosEfectivos(derechos, ahora);
  final limite = limiteManosLibres(
    premium: efectivos.premium,
    usadoHoyMs: manosLibresHoyMs(sesiones, ahora),
    reglas: contenido?.global.freePlan ?? const FreePlanRules(),
  );
  return ContextoAnuncio(
    ahora: ahora,
    impresiones: ContadorImpresiones.fromJson(await deps.claves.leerJson(claveImpresiones)),
    sectorId: usuario?.perfil?.sectorId,
    anterior: await deps.claves.leer(claveAnuncioAnterior),
    modoVoz: modoVoz,
    esperaS: params?.waitS ?? 3,
    enLeccion: datos.modo == SessionMode.lesson || datos.modo == SessionMode.challenge,
    ejerciciosLeccion: datos.ejerciciosLeccion,
    aciertosLeccion: datos.aciertosLeccion,
    pruebaDisponible: pruebaDisponible(derechos),
    limiteManosLibresAgotado: !limite.permitido,
    trasSesionManosLibres: datos.trasManosLibres,
    rachaDias: proy?.racha.actual ?? 0,
    precioMensual: precios.precio('monthly'),
    precioAnual: precios.precio('annual'),
    preciosObtenidosEn: precios.obtenidosEn,
    unidadCompletada: datos.unidadCompletada,
    ultimaPausaLeccion: datos.ultimaPausa,
    leccionConFallos: datos.leccionConFallos,
    trasContrarreloj: datos.trasContrarreloj,
    organizacionesActivas: contenido?.global.orgsEnabled ?? false,
  );
}

/// Elige el anuncio de esta pausa y registra la impresión en el contador
/// diario y como anuncio anterior (para no repetirlo en la siguiente).
Future<AnuncioElegido?> elegirAnuncio(Lector leer, DatosPausa datos, {bool modoVoz = false}) async {
  final deps = leer(dependenciasProvider);
  final contenido = leer(contenidoProvider).value;
  if (contenido == null) return null;
  final ctx = await construirContexto(leer, datos, modoVoz: modoVoz);
  final selector = SelectorAnuncios(campanas: contenido.global.campaigns, params: contenido.global.adParams);
  final a = selector.elegir(ctx, deps.azar);
  if (a == null) return null;
  ctx.impresiones.registrar(a.id, ctx.ahora);
  await deps.claves.escribirJson(claveImpresiones, ctx.impresiones.toJson());
  await deps.claves.escribir(claveAnuncioAnterior, a.id);
  return AnuncioElegido(a, ctx, ctx.esperaS);
}

/// Cuña hablada para el modo manos libres (4 s como máximo): solo entran
/// anuncios con `voiceSpot`.
Future<AnuncioResuelto?> cunaParaManosLibres(Lector leer, DatosPausa datos) async =>
    (await elegirAnuncio(leer, datos, modoVoz: true))?.anuncio;

/// Encola la impresión (se envía al recuperar la conexión).
Future<void> registrarImpresion(Lector leer, AnuncioElegido e, DatosPausa datos, int permanenciaMs) =>
    leer(aprendizajeProvider.notifier).registrarEvento('ad_impression', {
      'adId': e.anuncio.id,
      'campaignId': e.anuncio.creatividad.campaignId,
      'context': e.anuncio.creatividad.context,
      'mode': sessionModeWire(datos.modo),
      'sessionId': datos.sessionId,
      'dwellMs': permanenciaMs,
      'dwellS': (permanenciaMs / 1000).round(),
    });

/// Encola el toque en la acción del anuncio y lo recuerda para atribuir la
/// compra.
Future<void> registrarAccion(Lector leer, AnuncioElegido e, DatosPausa datos) async {
  leer(anuncioAtribuidoProvider.notifier).fijar(e.anuncio.id);
  await leer(aprendizajeProvider.notifier).registrarEvento('ad_cta', {
    'adId': e.anuncio.id,
    'context': e.anuncio.creatividad.context,
    'action': e.anuncio.creatividad.ctaAction,
    'sessionId': datos.sessionId,
  });
}
