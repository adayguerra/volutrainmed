/// Fichas de repaso como proyección de los intentos (diseños D5 y D7).
///
/// Una ficha es una plantilla (o pregunta) en un nivel de dificultad. Se crea
/// cuando un primer intento falla o es «No lo sé» y, desde entonces, cada
/// primer intento posterior con la misma clave la actualiza con FSRS. La
/// calificación se deduce de la respuesta, sin preguntar al usuario.
library;

import '../../../core/domain/content_models.dart' show errorLabels;
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';
import 'fsrs.dart';

/// Tope diario de la cola de repaso: entre 10 y 40, 20 por defecto.
const topeRepasoPorDefecto = 20;
const topeRepasoMinimo = 10;
const topeRepasoMaximo = 40;

int normalizarTope(int? tope) => (tope ?? topeRepasoPorDefecto).clamp(topeRepasoMinimo, topeRepasoMaximo);

/// Calificación automática (spaced-review, «Calificación automática»).
Rating calificar(Attempt a) {
  if (a.verdict == Verdict.dontKnow || !a.correct) return Rating.again;
  if (a.hintsUsed > 0 || (a.targetMs > 0 && a.responseMs > 2 * a.targetMs)) return Rating.hard;
  if (a.targetMs > 0 && a.responseMs < 0.6 * a.targetMs) return Rating.easy;
  return Rating.good;
}

/// Ordena y deduplica intentos por id: la fusión de dispositivos es la unión
/// de conjuntos y el orden es determinista por (deviceTime, id).
List<Attempt> ordenarIntentos(Iterable<Attempt> intentos) {
  final porId = <String, Attempt>{};
  for (final a in intentos) {
    porId.putIfAbsent(a.id, () => a);
  }
  final l = porId.values.toList()
    ..sort((x, y) {
      final c = x.deviceTime.compareTo(y.deviceTime);
      return c != 0 ? c : x.id.compareTo(y.id);
    });
  return l;
}

class FichaRepaso {
  FichaRepaso({
    required this.clave,
    required this.templateId,
    required this.questionId,
    required this.level,
    required this.skillId,
    required this.creada,
  });

  /// `plantilla@nivel`, igual que [Attempt.cardKey].
  final String clave;
  final String? templateId;
  final String? questionId;
  final int level;
  final String skillId;
  final DateTime creada;

  FsrsCard card = const FsrsCard();

  /// Cuarentena tras un error crítico: vence al día siguiente y no alarga el
  /// intervalo hasta dos aciertos en días distintos.
  bool cuarentena = false;
  final Set<DateTime> diasAciertoCuarentena = {};

  /// El último fallo fue un error crítico.
  bool ultimoFalloCritico = false;
  DateTime? ultimoFallo;
  String? ultimoErrorCode;
  bool ultimoFueNoLoSe = false;

  /// Fallos en modo repaso o calentamiento (para «por refrescar»).
  int fallosEnRepaso = 0;
  final Set<String> variantesVistas = {};

  /// Intervalos programados, en orden (para comprobar que crecen).
  final List<int> historialIntervalos = [];

  DateTime get vence => card.due ?? creada;

  /// Crítica para el orden de la cola: en cuarentena o con fallo crítico.
  bool get critica => cuarentena || ultimoFalloCritico;

  bool vencida(DateTime now) => !vence.isAfter(now);

  /// Días de retraso respecto al vencimiento (0 si no vence aún).
  int diasVencida(DateTime now) => vencida(now) ? diasEntre(vence, now) : 0;
}

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

String _cuando(DateTime t, DateTime now) {
  final d = diasEntre(t, now);
  if (d <= 0) return 'hoy';
  if (d == 1) return 'ayer';
  final l = t.toLocal();
  if (d < 7) return 'el ${_diasSemana[l.weekday - 1]}';
  return 'el ${l.day} de ${_meses[l.month - 1]}';
}

/// Motivo de la ficha: «Fallaste esta el martes: unidad».
String motivoFicha(FichaRepaso f, DateTime now) {
  final cuando = f.ultimoFallo == null ? '' : ' ${_cuando(f.ultimoFallo!, now)}';
  if (f.ultimoFueNoLoSe) return 'Respondiste «No lo sé»$cuando.';
  final code = f.ultimoErrorCode;
  final tipo = (code == null || code == 'E0') ? null : errorLabels[code]?.toLowerCase();
  return tipo == null ? 'Fallaste esta$cuando.' : 'Fallaste esta$cuando: $tipo.';
}

/// Reproduce los intentos y devuelve las fichas por clave.
Map<String, FichaRepaso> proyectarFichas(Iterable<Attempt> intentos, {FsrsScheduler fsrs = const FsrsScheduler()}) {
  final fichas = <String, FichaRepaso>{};
  for (final a in ordenarIntentos(intentos)) {
    if (a.mode == SessionMode.placement) continue;
    final existente = fichas[a.cardKey];
    if (existente != null) existente.variantesVistas.add(a.variantId);
    if (a.attemptNumber != 1) continue;
    var f = existente;
    if (f == null) {
      if (a.correct) continue;
      f = FichaRepaso(
        clave: a.cardKey,
        templateId: a.templateId,
        questionId: a.questionId,
        level: a.level,
        skillId: a.skillId,
        creada: a.deviceTime,
      )..variantesVistas.add(a.variantId);
      fichas[a.cardKey] = f;
    }
    _aplicar(f, a, fsrs);
  }
  return fichas;
}

void _aplicar(FichaRepaso f, Attempt a, FsrsScheduler fsrs) {
  final rating = calificar(a);
  final now = a.deviceTime;
  final nueva = fsrs.review(f.card, rating, now);
  if (!a.correct) {
    f.ultimoFallo = now;
    f.ultimoErrorCode = a.errorCode;
    f.ultimoFueNoLoSe = a.verdict == Verdict.dontKnow;
    f.ultimoFalloCritico = a.critical;
    if (a.mode == SessionMode.review || a.mode == SessionMode.warmup) f.fallosEnRepaso++;
    if (a.critical) {
      f.cuarentena = true;
      f.diasAciertoCuarentena.clear();
    } else if (f.cuarentena) {
      // Un fallo dentro de la cuarentena reinicia la cuenta de aciertos.
      f.diasAciertoCuarentena.clear();
    }
    f.card = nueva.copyWith(due: inicioDiaMas(now, 1), intervaloDias: 1);
  } else if (f.cuarentena) {
    f.diasAciertoCuarentena.add(diaLocal(now));
    if (f.diasAciertoCuarentena.length >= 2) {
      // Sale de la cuarentena: el intervalo empieza a crecer con FSRS.
      f.cuarentena = false;
      f.ultimoFalloCritico = false;
      f.diasAciertoCuarentena.clear();
      f.card = nueva;
    } else {
      f.card = nueva.copyWith(due: inicioDiaMas(now, 1), intervaloDias: 1);
    }
  } else {
    f.card = nueva;
  }
  f.historialIntervalos.add(f.card.intervaloDias);
}

/// Cola de hoy: solo vencidas, críticas primero y después las más vencidas,
/// limitada al tope diario (10–40, 20 por defecto).
List<FichaRepaso> colaDeHoy(Iterable<FichaRepaso> fichas, DateTime now, {int? tope}) {
  final vencidas = fichas.where((f) => f.vencida(now)).toList()
    ..sort((a, b) {
      if (a.critica != b.critica) return a.critica ? -1 : 1;
      final c = a.vence.compareTo(b.vence);
      return c != 0 ? c : a.clave.compareTo(b.clave);
    });
  return vencidas.take(normalizarTope(tope)).toList();
}

/// Fecha y número de fichas del próximo repaso, cuando no hay nada vencido.
({DateTime fecha, int fichas})? proximoRepaso(Iterable<FichaRepaso> fichas, DateTime now) {
  final futuras = fichas.where((f) => !f.vencida(now)).toList();
  if (futuras.isEmpty) return null;
  final primera = futuras.map((f) => diaLocal(f.vence)).reduce((a, b) => a.isBefore(b) ? a : b);
  return (fecha: primera, fichas: futuras.where((f) => diaLocal(f.vence) == primera).length);
}

/// Elige una variante distinta de las ya vistas (spaced-review, «Variante
/// nueva en el repaso»). Si todas se han visto, rota de forma estable.
String? elegirVarianteRepaso(FichaRepaso f, List<String> candidatas) {
  if (candidatas.isEmpty) return null;
  for (final c in candidatas) {
    if (!f.variantesVistas.contains(c)) return c;
  }
  return candidatas[f.variantesVistas.length % candidatas.length];
}

/// Cola de una sesión de repaso: un acierto saca la ficha; un fallo la manda
/// al final, dos veces como máximo.
class ColaSesionRepaso {
  ColaSesionRepaso(Iterable<String> claves, {this.maxReapariciones = 2}) : _cola = List.of(claves);

  final List<String> _cola;
  final int maxReapariciones;
  final Map<String, int> _reapariciones = {};
  final List<String> resueltas = [];
  final List<String> pendientes = [];

  String? get actual => _cola.isEmpty ? null : _cola.first;
  bool get terminada => _cola.isEmpty;
  int get restantes => _cola.length;
  List<String> get orden => List.unmodifiable(_cola);

  /// Registra la respuesta a la ficha actual.
  void responder({required bool acierto}) {
    if (_cola.isEmpty) return;
    final clave = _cola.removeAt(0);
    if (acierto) {
      resueltas.add(clave);
      return;
    }
    final n = _reapariciones[clave] ?? 0;
    if (n < maxReapariciones) {
      _reapariciones[clave] = n + 1;
      _cola.add(clave);
    } else {
      pendientes.add(clave);
    }
  }
}
