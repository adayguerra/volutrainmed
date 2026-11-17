import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/domain/content_models.dart';
import '../../../core/domain/decimal_es.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/plataforma/plataforma.dart';
import '../../ads/domain/ad_selector.dart';
import '../../session/domain/motor_sesion.dart';
import 'analizador.dart';
import 'normalizador.dart';

/// Máquina de estados del turno de manos libres (hands-free-voice, tarea 7.5).
///
/// Lee los datos y, al final, la pregunta; escucha; confirma lo entendido;
/// corrige con el motor de sesión; dice el veredicto y pasa al siguiente. Todo
/// ocurre en el dispositivo: el texto reconocido solo se interpreta y se
/// descarta, y el intento guarda únicamente la cifra, su unidad y métricas
/// técnicas. Este módulo no tiene ruta de red.
///
/// Dart puro (salvo `ChangeNotifier`): la síntesis, el reconocimiento, las
/// esperas y las señales se inyectan.

enum EstadoTurno { leyendo, escuchando, confirmando, preguntando, veredicto, cuna, pausa, teclado, confirmandoSalida, terminada }

const textoNoTeHeOido = 'No te he oído. ¿Lo repito?';
const textoRuido = 'Hay mucho ruido. Acerca el micrófono o usa los botones';
const textoRepetir = 'No te he entendido. ¿Puedes repetirlo?';
const textoCifraACifra = 'Dímelo cifra a cifra, por ejemplo: cuatro, coma, ocho.';
const textoAbroTeclado = 'Te abro el teclado';
const textoOtraVez = 'Vale, dímelo otra vez.';
const textoSalir = '¿Quieres salir de la sesión? Di «sí» o «no».';
const textoSinAudio = 'No se ha guardado audio ni texto transcrito.';

/// Confianza a partir de la cual la confirmación abreviada no pregunta.
const umbralConfianza = 0.85;

/// Espera de la confirmación abreviada antes de corregir.
const esperaConfirmacionAbreviada = Duration(milliseconds: 1500);

/// Duración máxima de la cuña hablada.
const duracionMaximaCuna = Duration(seconds: 4);

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Texto hablado de un enunciado: primero los datos y, en último lugar, la
/// pregunta (hands-free-voice, «La pregunta va al final»). Las cantidades se
/// leen completas con su unidad.
String textoEnunciadoHablado(Variant v) {
  final datos = v.statement.map((s) => s.isQty ? readQuantity(s.value!, s.unit!) : speakFragment(s.text!)).join().replaceAll(RegExp(r'\s+'), ' ').trim();
  final pregunta = speakText(v.question);
  return [datos, pregunta].where((x) => x.isNotEmpty).join(' ');
}

/// Solo los datos (comando «repite los datos»).
String textoDatosHablados(Variant v) =>
    v.statement.map((s) => s.isQty ? readQuantity(s.value!, s.unit!) : speakFragment(s.text!)).join().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Opciones habladas de T2 y T6: «Opción uno: …».
String textoOpcionesHabladas(List<ChoiceOption> opciones) =>
    [for (var i = 0; i < opciones.length; i++) 'Opción ${numberToWords('${i + 1}', 'f', true)}: ${speakText(opciones[i].label)}.'].join(' ');

/// Pasos de la explicación para el comando «explica».
String textoExplicacionHablada(Variant v) => [
      for (final p in v.steps)
        'Paso ${numberToWords('${p.n}')}: ${speakText(p.text)}. ${speakText(p.operation)}${p.result.value.isEmpty ? '' : ' igual a ${readQuantity(p.result.value, p.result.unit)}'}.',
      if (v.plausibility.isNotEmpty) speakText(v.plausibility),
    ].join(' ');

/// Respuesta interpretada pendiente de confirmar.
class Entendido {
  const Entendido({required this.valor, this.unidad, this.opcionId, this.confianza = 1, this.asrMs = 0});

  /// Cifra canónica con punto («4.8»).
  final String valor;
  final String? unidad;

  /// T2 y T6: opción elegida.
  final String? opcionId;
  final double confianza;
  final int asrMs;

  String get pantalla => unidad == null || unidad!.isEmpty ? formatEs(valor) : formatQty(valor, unidad!);
}

/// Resumen final de la sesión (M48).
class ResumenManosLibres {
  const ResumenManosLibres({
    required this.ejercicios,
    required this.aciertos,
    required this.aRepaso,
    required this.entendidasALaPrimera,
    required this.respondidasPorVoz,
    required this.alTeclado,
    required this.minutos,
    this.anuncio,
    required this.registro,
  });
  final int ejercicios;
  final int aciertos;
  final int aRepaso;
  final int entendidasALaPrimera;
  final int respondidasPorVoz;
  final int alTeclado;
  final int minutos;

  /// Anuncio por el que el usuario dijo «más información» durante una cuña.
  final AnuncioResuelto? anuncio;
  final SessionRecord registro;

  double get precision => ejercicios == 0 ? 0 : aciertos / ejercicios;
  double get fraccionALaPrimera => respondidasPorVoz == 0 ? 1 : entendidasALaPrimera / respondidasPorVoz;

  /// «Veinticuatro de veintiséis. Dos fichas a repaso. Di siguiente o salir.»
  String get hablado =>
      '${_capital(numberToWords('$aciertos', 'm'))} de ${numberToWords('$ejercicios', 'm')}. '
      '${aRepaso == 1 ? 'Una ficha' : '${_capital(numberToWords('$aRepaso', 'f', true))} fichas'} a repaso.';
}

typedef EsperarFn = Future<void> Function(Duration d);

Future<void> _esperaReal(Duration d) => Future<void>.delayed(d);

class TurnoManosLibres extends ChangeNotifier {
  TurnoManosLibres({
    required this.motor,
    required this.sintetizador,
    required this.motorVoz,
    this.confirmacion = 'siempre',
    this.cifraACifraPorDefecto = false,
    this.sinonimos = const {},
    this.lexico,
    this.velocidad = 1.0,
    this.esperaSilencio = const Duration(milliseconds: 900),
    this.limiteMs,
    this.elegirCuna,
    this.alSenal,
    this.alTerminar,
    EsperarFn? esperar,
  }) : esperar = esperar ?? _esperaReal {
    final registrar = motor.alRegistrar;
    // Las métricas técnicas de voz se añaden al intento; nunca el audio ni el
    // texto reconocido.
    motor.alRegistrar = (a) {
      final m = VoiceMetrics(asrMs: _asrMsUltimo, confidence: _confianzaUltima, recognitionFailures: _fallos);
      final conMetricas = Attempt.fromJson({...a.toJson(), 'voiceMetrics': m.toJson()});
      intentos.add(conMetricas);
      registrar?.call(conMetricas);
    };
  }

  final MotorSesion motor;
  final Sintetizador sintetizador;
  final MotorDeVoz motorVoz;

  /// 'siempre' | 'siHayDuda' | 'nunca' (ajustes de voz).
  final String confirmacion;
  final bool cifraACifraPorDefecto;

  /// Sinónimos de sector activados: «gammas» → «µg».
  final Map<String, String> sinonimos;
  final VoiceLexicon? lexico;
  double velocidad;
  final Duration esperaSilencio;

  /// Duración elegida (o lo que queda del plan gratuito); null = sin límite.
  final int? limiteMs;

  /// Cuña hablada tras el veredicto (null con Premium o sin anuncio).
  final AnuncioResuelto? Function()? elegirCuna;
  final void Function(Senal s)? alSenal;
  final void Function(ResumenManosLibres r)? alTerminar;
  final EsperarFn esperar;

  // ---- Estado visible ------------------------------------------------------
  EstadoTurno estado = EstadoTurno.leyendo;
  EstadoTurno? _antesDePausa;
  EstadoTurno? _antesDeSalir;

  /// Último texto dicho (todo lo dicho aparece también escrito).
  String textoPantalla = '';
  final List<String> dichos = [];
  Entendido? entendido;
  ResultadoEjercicio? resultado;

  /// Aviso visible (ruido ambiente).
  String? aviso;
  bool cifraACifra = false;
  List<String> opcionesAmbiguas = const [];
  List<String> unidadesEnDuda = const [];
  bool _ofrecidoRepetir = false;
  int _fallos = 0;
  int _asrMsUltimo = 0;
  double _confianzaUltima = 1;
  int alTeclado = 0;
  int entendidasALaPrimera = 0;
  int respondidasPorVoz = 0;
  final List<Attempt> intentos = [];
  AnuncioResuelto? cunaActual;
  AnuncioResuelto? anuncioInteres;
  int _generacion = 0;
  ResumenManosLibres? resumen;

  // Serie T7: una conversión por turno.
  int indiceSerie = 0;
  final List<String?> respuestasSerie = [];

  EjercicioPreparado? get ejercicio => motor.actual;
  int get fallosReconocimiento => _fallos;
  bool get pausado => estado == EstadoTurno.pausa;
  bool get esSerie => ejercicio?.bloque == 'conversion_series';
  bool get esOpcion => ejercicio?.bloque == 'single_choice' || ejercicio?.bloque == 'range_choice';

  /// «Di solo la cifra. La unidad es ml/h.»
  String? get unidadFija {
    final e = ejercicio;
    if (e == null) return null;
    if (esSerie) return e.variante.series![indiceSerie].answer.unit;
    final a = e.variante.answer;
    if (a == null || esOpcion) return null;
    return a.unitFixed || a.unitChoices.length <= 1 ? a.unit : null;
  }

  SpokenOptions get _opciones => SpokenOptions(
        digitByDigit: cifraACifra,
        confusions: lexico?.confusions,
        commands: lexico == null || lexico!.commands.isEmpty ? null : {...defaultCommands, ...lexico!.commands},
        synonyms: sinonimos,
      );

  Future<void> _decir(String texto) async {
    textoPantalla = texto;
    dichos.add(texto);
    notifyListeners();
    await sintetizador.decir(texto, velocidad: velocidad);
  }

  void _cambiar(EstadoTurno e) {
    estado = e;
    if (e == EstadoTurno.escuchando) alSenal?.call(Senal.escucha);
    notifyListeners();
  }

  // ---- Inicio y lectura ----------------------------------------------------

  Future<void> iniciar() async {
    cifraACifra = cifraACifraPorDefecto;
    if (motor.excluidosPorVoz > 0) {
      final n = motor.excluidosPorVoz;
      await _decir(n == 1 ? 'Un ejercicio queda para el modo táctil.' : '${_capital(numberToWords('$n'))} ejercicios quedan para el modo táctil.');
    }
    if (motor.fase == FaseSesion.terminada || motor.actual == null) {
      await _terminar(completada: true);
      return;
    }
    await leer();
  }

  /// Lee el enunciado (o la conversión actual de la serie) y abre la escucha.
  Future<void> leer({bool soloDatos = false}) async {
    final e = ejercicio;
    if (e == null) return;
    final g = ++_generacion;
    _cambiar(EstadoTurno.leyendo);
    final v = e.variante;
    String texto;
    if (esSerie) {
      final item = v.series![indiceSerie];
      texto = indiceSerie == 0 ? '${textoEnunciadoHablado(v)} ${speakText(item.tts)}' : speakText(item.tts);
    } else if (soloDatos) {
      texto = textoDatosHablados(v);
    } else {
      texto = textoEnunciadoHablado(v);
      if (esOpcion) texto = '$texto ${textoOpcionesHabladas(v.options!)}';
    }
    await _decir(texto);
    if (g != _generacion || estado != EstadoTurno.leyendo) return;
    _cambiar(EstadoTurno.escuchando);
  }

  // ---- Escucha -------------------------------------------------------------

  /// Abre una escucha con el motor de voz y procesa lo que llegue. Devuelve
  /// false si no ha llegado nada (motor no disponible o guion agotado).
  Future<bool> escucharUnaVez() async {
    if (!motorVoz.disponible) return false;
    if (estado != EstadoTurno.escuchando && estado != EstadoTurno.confirmando && estado != EstadoTurno.preguntando && estado != EstadoTurno.veredicto && estado != EstadoTurno.cuna && estado != EstadoTurno.confirmandoSalida && estado != EstadoTurno.pausa) {
      return false;
    }
    var algo = false;
    await for (final ev in motorVoz.escuchar(silencioCorte: esperaSilencio)) {
      algo = true;
      await oir(ev);
    }
    return algo;
  }

  /// Procesa un evento del reconocimiento.
  Future<void> oir(EventoVoz ev) async {
    switch (ev) {
      case VozBotonAuriculares():
        await alternarPausa();
        return;
      case VozRuido():
        if (estado == EstadoTurno.escuchando) {
          aviso = textoRuido;
          await _decir(textoRuido);
        }
        return;
      case VozSilencio():
        if (estado == EstadoTurno.escuchando) {
          _ofrecidoRepetir = true;
          await _decir(textoNoTeHeOido);
        }
        return;
      case VozNoEntendida():
        if (estado == EstadoTurno.escuchando || estado == EstadoTurno.confirmando) await _falloReconocimiento();
        return;
      case VozTexto():
        await _texto(ev);
    }
  }

  Future<void> _texto(VozTexto ev) async {
    _asrMsUltimo = ev.ms;
    _confianzaUltima = ev.confianza;
    if (estado == EstadoTurno.preguntando && unidadesEnDuda.isNotEmpty) {
      final u = _unidadDicha(ev.texto, unidadesEnDuda);
      if (u != null) {
        final previo = entendido!;
        unidadesEnDuda = const [];
        await _proponer(Entendido(valor: previo.valor, unidad: u, confianza: 1, asrMs: ev.ms));
        return;
      }
    }
    final r = parseSpoken(ev.texto, opts: _opciones);
    switch (r) {
      case SpokenCommandResult(:final command):
        await comando(command);
      case SpokenNumber(:final value, :final unit):
        await _numero(value, unit, ev);
      case SpokenAmbiguous(:final options, :final question):
        if (estado != EstadoTurno.escuchando && estado != EstadoTurno.confirmando && estado != EstadoTurno.preguntando) return;
        opcionesAmbiguas = options;
        _cambiar(EstadoTurno.preguntando);
        await _decir(question);
      case SpokenUnparsed():
        if (estado == EstadoTurno.escuchando || estado == EstadoTurno.confirmando || estado == EstadoTurno.preguntando) await _falloReconocimiento();
    }
  }

  String? _unidadDicha(String texto, List<String> candidatas) {
    final t = stripDiacritics(texto.toLowerCase());
    for (final u in candidatas) {
      for (final f in defaultUnitForms[u] ?? const <String>[]) {
        if (t.contains(stripDiacritics(f))) return u;
      }
    }
    return null;
  }

  Future<void> _falloReconocimiento() async {
    _fallos++;
    if (_fallos == 1) {
      _cambiar(EstadoTurno.escuchando);
      await _decir(textoRepetir);
    } else if (_fallos == 2) {
      cifraACifra = true;
      _cambiar(EstadoTurno.escuchando);
      await _decir(textoCifraACifra);
    } else {
      await _decir(textoAbroTeclado);
      abrirTeclado(contar: true);
    }
  }

  Future<void> _numero(String valor, String? unidad, VozTexto ev) async {
    if (estado != EstadoTurno.escuchando && estado != EstadoTurno.confirmando && estado != EstadoTurno.preguntando) return;
    final e = ejercicio;
    if (e == null) return;
    if (estado == EstadoTurno.preguntando && opcionesAmbiguas.isNotEmpty && !opcionesAmbiguas.contains(valor)) {
      await _decir(textoRepetir);
      return;
    }
    opcionesAmbiguas = const [];
    if (esOpcion) {
      final opciones = e.variante.options!;
      ChoiceOption? o = opciones.where((x) => x.value != null && x.value == valor && (unidad == null || x.unit == unidad)).firstOrNull;
      final i = int.tryParse(valor);
      if (o == null && i != null && i >= 1 && i <= opciones.length) o = opciones[i - 1];
      if (o == null) {
        await _falloReconocimiento();
        return;
      }
      await _proponer(Entendido(valor: valor, unidad: o.unit, opcionId: o.id, confianza: ev.confianza, asrMs: ev.ms));
      return;
    }
    var u = unidad;
    final fija = unidadFija;
    if (fija != null) {
      u ??= fija;
    } else if (u == null) {
      _cambiar(EstadoTurno.escuchando);
      await _decir('Di también la unidad.');
      return;
    }
    // Duda entre dos unidades de sonido parecido: se pregunta.
    for (final alt in ev.alternativas) {
      final ra = parseSpoken(alt, opts: _opciones);
      if (ra is SpokenNumber && ra.value == valor && ra.unit != null && ra.unit != u) {
        final q = unitQuestion(u, ra.unit!);
        if (q != null) {
          entendido = Entendido(valor: valor, unidad: u, confianza: ev.confianza, asrMs: ev.ms);
          unidadesEnDuda = [u, ra.unit!];
          _cambiar(EstadoTurno.preguntando);
          await _decir(q);
          return;
        }
      }
    }
    await _proponer(Entendido(valor: valor, unidad: u, confianza: ev.confianza, asrMs: ev.ms));
  }

  /// Repite lo entendido con su unidad antes de corregir.
  Future<void> _proponer(Entendido en) async {
    entendido = en;
    final e = ejercicio!;
    if (confirmacion == 'nunca') {
      await _corregir();
      return;
    }
    String lectura;
    if (en.opcionId != null) {
      final o = e.variante.options!.firstWhere((x) => x.id == en.opcionId);
      final i = e.variante.options!.indexOf(o) + 1;
      lectura = 'Opción ${numberToWords('$i', 'f', true)}: ${speakText(o.label)}';
    } else {
      lectura = en.unidad == null || en.unidad!.isEmpty ? _capital(numberToWords(en.valor)) : confirmationText(en.valor, en.unidad!);
    }
    // Se deletrean los enteros con cifras que se confunden («sesenta»); con
    // decimales, las cifras tras la coma ya se dicen una a una.
    final deletreo = en.opcionId == null && !en.valor.contains('.') ? spellingFor(en.valor) : null;
    if (deletreo != null) lectura = '${_capital(numberToWords(en.valor))}: $deletreo';
    final abreviada = confirmacion == 'siHayDuda' && en.confianza >= umbralConfianza && deletreo == null;
    _cambiar(EstadoTurno.confirmando);
    if (abreviada) {
      final g = ++_generacion;
      await _decir('$lectura.');
      await esperar(esperaConfirmacionAbreviada);
      // Si no ha llegado un «no» durante la espera, se corrige.
      if (g == _generacion && estado == EstadoTurno.confirmando && identical(entendido, en)) await _corregir();
      return;
    }
    await _decir('$lectura. ¿Correcto?');
  }

  // ---- Corrección ----------------------------------------------------------

  Future<void> _corregir({bool porTeclado = false}) async {
    final e = ejercicio;
    final en = entendido;
    if (e == null || en == null) return;
    _generacion++;
    if (!porTeclado) {
      respondidasPorVoz++;
      if (_fallos == 0) entendidasALaPrimera++;
    }
    if (esSerie) {
      respuestasSerie.add(en.valor.replaceAll('.', ','));
      final serie = e.variante.series!;
      final bien = motor.corregirConversion(indiceSerie, en.valor.replaceAll('.', ','));
      alSenal?.call(bien ? Senal.acierto : Senal.fallo);
      entendido = null;
      if (indiceSerie < serie.length - 1) {
        indiceSerie++;
        await _decir(bien ? 'Bien.' : 'Era ${readQuantity(serie[indiceSerie - 1].answer.value, serie[indiceSerie - 1].answer.unit)}.');
        await leer();
        return;
      }
      resultado = motor.responderSerie(respuestasSerie);
    } else if (en.opcionId != null) {
      resultado = motor.responderOpcion(en.opcionId!);
    } else {
      resultado = motor.responderNumerico(en.valor.replaceAll('.', ','), unidad: en.unidad);
    }
    await _veredicto();
  }

  Future<void> _veredicto() async {
    final r = resultado!;
    _cambiar(EstadoTurno.veredicto);
    alSenal?.call(r.acierto ? Senal.acierto : Senal.fallo);
    final e = r.ejercicio;
    final a = e.variante.answer;
    final correctaHablada = a != null ? readQuantity(a.value, a.unit) : speakText(r.correcta);
    if (r.acierto) {
      await _decir(r.verdict == Verdict.correctNote && r.nota != null ? 'Correcto. ${speakText(r.nota!)}' : 'Correcto');
      await avanzar();
      return;
    }
    if (r.noLoSe) {
      await _decir('La respuesta es $correctaHablada.');
    } else {
      final diag = r.diagnostico == null ? '' : ' ${speakText(r.diagnostico!)}.';
      await _decir('Incorrecto. Era $correctaHablada.$diag');
    }
  }

  // ---- Avance y cuña -------------------------------------------------------

  /// Pasa al ejercicio siguiente (con la cuña si toca).
  Future<void> avanzar() async {
    if (motor.fase == FaseSesion.correccion) {
      _fallos = 0;
      _ofrecidoRepetir = false;
      cifraACifra = cifraACifraPorDefecto;
      indiceSerie = 0;
      respuestasSerie.clear();
      entendido = null;
      resultado = null;
      aviso = null;
      motor.continuar();
    }
    if (motor.fase == FaseSesion.pausaPromocional) {
      final cuna = elegirCuna?.call();
      if (cuna != null && (cuna.cuna ?? '').isNotEmpty) {
        cunaActual = cuna;
        final g = ++_generacion;
        _cambiar(EstadoTurno.cuna);
        await _decir(cuna.cuna!);
        if (g != _generacion || estado != EstadoTurno.cuna) return;
      }
      _cerrarCuna();
    }
    if (_limiteAlcanzado || motor.fase == FaseSesion.terminada) {
      await _terminar(completada: true);
      return;
    }
    await leer();
  }

  void _cerrarCuna() {
    cunaActual = null;
    if (motor.fase == FaseSesion.pausaPromocional) motor.cerrarPausa();
  }

  bool get _limiteAlcanzado {
    if (limiteMs == null) return false;
    return motor.registro(completada: false).practiceMs >= limiteMs!;
  }

  // ---- Comandos y botones --------------------------------------------------

  Future<void> comando(String c) async {
    if (estado == EstadoTurno.pausa) {
      if (c == SpokenCommand.continua || c == SpokenCommand.siguiente) await alternarPausa();
      return;
    }
    if (estado == EstadoTurno.confirmandoSalida) {
      if (c == SpokenCommand.si) {
        await _terminar(completada: false);
      } else if (c == SpokenCommand.no) {
        cancelarSalida();
      }
      return;
    }
    if (estado == EstadoTurno.cuna) {
      if (c == SpokenCommand.siguiente || c == SpokenCommand.salta) {
        await saltarCuna();
      } else if (c == SpokenCommand.masInformacion) {
        anuncioInteres = cunaActual;
        notifyListeners();
      }
      return;
    }
    switch (c) {
      case SpokenCommand.si:
        if (estado == EstadoTurno.confirmando) {
          await _corregir();
        } else if (_ofrecidoRepetir) {
          _ofrecidoRepetir = false;
          await leer();
        }
      case SpokenCommand.no:
        if (estado == EstadoTurno.confirmando || estado == EstadoTurno.preguntando) {
          // Se vuelve a escuchar sin corregir.
          _generacion++;
          entendido = null;
          _cambiar(EstadoTurno.escuchando);
          await _decir(textoOtraVez);
        }
      case SpokenCommand.repite:
        await repetir();
      case SpokenCommand.repiteDatos:
        await leer(soloDatos: true);
      case SpokenCommand.siguiente || SpokenCommand.salta:
        await siguiente();
      case SpokenCommand.noLoSe:
        await noLoSe();
      case SpokenCommand.pausa:
        await alternarPausa();
      case SpokenCommand.explica:
        await explicar();
      case SpokenCommand.teclado:
        abrirTeclado();
      case SpokenCommand.salir:
        await pedirSalida();
      case SpokenCommand.masDespacio:
        velocidad = (velocidad - 0.2).clamp(0.6, 2.0);
        await repetir();
      case SpokenCommand.masRapido:
        velocidad = (velocidad + 0.2).clamp(0.6, 2.0);
        await repetir();
      case SpokenCommand.cifraACifra:
        cifraACifra = true;
        notifyListeners();
      case SpokenCommand.masInformacion:
        break;
    }
  }

  Future<void> repetir() async {
    if (estado == EstadoTurno.veredicto || estado == EstadoTurno.terminada) {
      if (estado == EstadoTurno.veredicto) await _decir(textoPantalla);
      return;
    }
    await leer();
  }

  /// «No lo sé»: dice la respuesta correcta y registra el ejercicio como no
  /// acertado.
  Future<void> noLoSe() async {
    if (motor.fase != FaseSesion.ejercicio) return;
    _generacion++;
    if (esSerie) {
      while (respuestasSerie.length < ejercicio!.variante.series!.length) {
        respuestasSerie.add(null);
      }
      resultado = motor.responderSerie(respuestasSerie);
      await _veredicto();
      return;
    }
    resultado = motor.noLoSe();
    await _veredicto();
  }

  /// «Siguiente»: tras el veredicto avanza; durante la cuña la salta; con el
  /// ejercicio en pantalla lo deja sin responder (cuenta como no acertado).
  Future<void> siguiente() async {
    switch (estado) {
      case EstadoTurno.veredicto:
        await avanzar();
      case EstadoTurno.cuna:
        await saltarCuna();
      case EstadoTurno.pausa:
        await alternarPausa();
      default:
        if (motor.fase == FaseSesion.ejercicio) {
          await noLoSe();
          await avanzar();
        }
    }
  }

  Future<void> saltarCuna() async {
    if (estado != EstadoTurno.cuna) return;
    _generacion++;
    await sintetizador.parar();
    _cerrarCuna();
    if (motor.fase == FaseSesion.terminada) {
      await _terminar(completada: true);
      return;
    }
    await leer();
  }

  Future<void> explicar() async {
    final e = resultado?.ejercicio ?? ejercicio;
    if (e == null) return;
    await _decir(textoExplicacionHablada(e.variante));
  }

  void abrirTeclado({bool contar = false}) {
    if (motor.fase != FaseSesion.ejercicio) return;
    _generacion++;
    if (contar || estado != EstadoTurno.teclado) alTeclado++;
    _cambiar(EstadoTurno.teclado);
  }

  /// Respuesta escrita con el teclado (sin hablar).
  Future<void> responderTeclado(String raw, {String? unidad}) async {
    if (motor.fase != FaseSesion.ejercicio) return;
    final p = parseUserNumber(raw);
    if (!p.ok) return;
    final e = ejercicio!;
    final u = unidad ?? unidadFija ?? e.variante.answer?.unit;
    entendido = Entendido(valor: p.value!, unidad: u);
    await _corregir(porTeclado: true);
  }

  /// Respuesta a una opción con su botón (T2 y T6).
  Future<void> responderOpcionBoton(String opcionId) async {
    if (motor.fase != FaseSesion.ejercicio) return;
    final o = ejercicio!.variante.options!.firstWhere((x) => x.id == opcionId);
    entendido = Entendido(valor: o.value ?? '', unidad: o.unit, opcionId: opcionId);
    await _corregir(porTeclado: true);
  }

  /// Pausa o reanuda en el mismo punto (toque en la pantalla, «pausa» /
  /// «continúa» o botón de los auriculares).
  Future<void> alternarPausa() async {
    if (estado == EstadoTurno.terminada) return;
    if (estado != EstadoTurno.pausa) {
      _antesDePausa = estado;
      _generacion++;
      motor.pausar();
      await sintetizador.parar();
      alSenal?.call(Senal.pausa);
      _cambiar(EstadoTurno.pausa);
      textoPantalla = 'En pausa';
      notifyListeners();
      return;
    }
    motor.reanudar();
    final previo = _antesDePausa ?? EstadoTurno.escuchando;
    _antesDePausa = null;
    alSenal?.call(Senal.pausa);
    if (previo == EstadoTurno.leyendo || previo == EstadoTurno.escuchando) {
      await leer();
    } else if (previo == EstadoTurno.cuna) {
      _cerrarCuna();
      await leer();
    } else {
      _cambiar(previo);
    }
  }

  Future<void> pedirSalida() async {
    if (estado == EstadoTurno.confirmandoSalida || estado == EstadoTurno.terminada) return;
    _antesDeSalir = estado;
    _generacion++;
    _cambiar(EstadoTurno.confirmandoSalida);
    await _decir(textoSalir);
  }

  void cancelarSalida() {
    _cambiar(_antesDeSalir ?? EstadoTurno.escuchando);
    _antesDeSalir = null;
  }

  Future<void> confirmarSalida() => _terminar(completada: false);

  Future<void> _terminar({required bool completada}) async {
    if (estado == EstadoTurno.terminada) return;
    _generacion++;
    await sintetizador.parar();
    final reg = motor.registro(completada: completada && motor.resultados.isNotEmpty);
    final p = motor.primerosIntentos;
    resumen = ResumenManosLibres(
      ejercicios: p.length,
      aciertos: p.where((r) => r.acierto).length,
      aRepaso: p.where((r) => !r.acierto).length,
      entendidasALaPrimera: entendidasALaPrimera,
      respondidasPorVoz: respondidasPorVoz,
      alTeclado: alTeclado,
      minutos: (reg.practiceMs / 60000).round(),
      anuncio: anuncioInteres,
      registro: reg,
    );
    _cambiar(EstadoTurno.terminada);
    alTerminar?.call(resumen!);
    if (completada) await _decir('${resumen!.hablado} Di siguiente o salir.');
  }

  /// Valor que se muestra en pantalla tras entender una respuesta.
  String? get cifraEntendida => entendido?.pantalla;
}
