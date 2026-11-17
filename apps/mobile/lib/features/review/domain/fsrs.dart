/// Planificador FSRS-4.5 propio, determinista (sin «fuzz»), en Dart puro.
///
/// Diseño D7: repaso espaciado con FSRS en el dispositivo y retención objetivo
/// del 90 %. Se usa la versión 4.5 del algoritmo con sus pesos por defecto.
/// Simplificación documentada: no hay pasos de aprendizaje dentro del mismo
/// día; todo intervalo se expresa en días enteros (mínimo 1) y la ficha vence
/// al empezar el día local correspondiente.
library;

import 'dart:math' as math;

import '../../../core/domain/reloj.dart';

/// Inicio del día local que está [dias] días después de [t] (seguro con
/// cambios de hora).
DateTime inicioDiaMas(DateTime t, int dias) {
  final d = diaLocal(t);
  return DateTime(d.year, d.month, d.day + dias);
}

enum Rating { again, hard, good, easy }

extension RatingValor on Rating {
  /// Valor numérico de FSRS: 1 (otra vez) a 4 (fácil).
  int get valor => index + 1;

  String get etiqueta => switch (this) {
        Rating.again => 'Otra vez',
        Rating.hard => 'Difícil',
        Rating.good => 'Bien',
        Rating.easy => 'Fácil',
      };
}

enum EstadoTarjeta { nueva, aprendiendo, repaso, reaprendiendo }

/// Estado FSRS de una ficha.
class FsrsCard {
  const FsrsCard({
    this.stability = 0,
    this.difficulty = 0,
    this.due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.state = EstadoTarjeta.nueva,
    this.intervaloDias = 0,
  });

  final double stability;
  final double difficulty;
  final DateTime? due;
  final DateTime? lastReview;
  final int reps;
  final int lapses;
  final EstadoTarjeta state;

  /// Último intervalo programado, en días.
  final int intervaloDias;

  FsrsCard copyWith({
    double? stability,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    EstadoTarjeta? state,
    int? intervaloDias,
  }) =>
      FsrsCard(
        stability: stability ?? this.stability,
        difficulty: difficulty ?? this.difficulty,
        due: due ?? this.due,
        lastReview: lastReview ?? this.lastReview,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        state: state ?? this.state,
        intervaloDias: intervaloDias ?? this.intervaloDias,
      );
}

class FsrsScheduler {
  const FsrsScheduler({
    this.retencion = 0.9,
    this.intervaloMaximo = 36500,
    this.w = pesosFsrs45,
  });

  /// Pesos por defecto de FSRS-4.5.
  static const pesosFsrs45 = <double>[
    0.4872, 1.4003, 3.7145, 13.8206, 5.1618, 1.2298, 0.8975, 0.031, 1.6474, //
    0.1367, 1.0461, 2.1072, 0.0793, 0.3246, 1.587, 0.2272, 2.8755,
  ];

  static const double decay = -0.5;
  static const double factor = 19 / 81; // 0,9^(1/decay) − 1

  final double retencion;
  final int intervaloMaximo;
  final List<double> w;

  /// Recuperabilidad tras [dias] con estabilidad [s].
  double recuperabilidad(double dias, double s) => s <= 0 ? 0 : math.pow(1 + factor * dias / s, decay).toDouble();

  int intervaloPara(double s) {
    final i = s / factor * (math.pow(retencion, 1 / decay) - 1);
    return i.round().clamp(1, intervaloMaximo);
  }

  double _d0(int g) => (w[4] - (g - 3) * w[5]).clamp(1.0, 10.0);

  double _s0(int g) => math.max(w[g - 1], 0.1);

  double _siguienteD(double d, int g) {
    final dPrima = d - w[6] * (g - 3);
    return (w[7] * _d0(3) + (1 - w[7]) * dPrima).clamp(1.0, 10.0);
  }

  double _sRecuerdo(double d, double s, double r, int g) {
    final hard = g == 2 ? w[15] : 1.0;
    final easy = g == 4 ? w[16] : 1.0;
    return s *
        (math.exp(w[8]) * (11 - d) * math.pow(s, -w[9]) * (math.exp(w[10] * (1 - r)) - 1) * hard * easy + 1);
  }

  double _sOlvido(double d, double s, double r) {
    final v = w[11] * math.pow(d, -w[12]) * (math.pow(s + 1, w[13]) - 1) * math.exp(w[14] * (1 - r));
    return math.min(v, s);
  }

  /// Aplica una calificación y programa el siguiente repaso.
  FsrsCard review(FsrsCard card, Rating rating, DateTime now) {
    final g = rating.valor;
    double s;
    double d;
    EstadoTarjeta estado;
    var lapses = card.lapses;
    if (card.state == EstadoTarjeta.nueva || card.lastReview == null) {
      s = _s0(g);
      d = _d0(g);
      estado = rating == Rating.again ? EstadoTarjeta.aprendiendo : EstadoTarjeta.repaso;
    } else {
      final dias = math.max(0, diasEntre(card.lastReview!, now)).toDouble();
      final r = recuperabilidad(dias, card.stability);
      d = _siguienteD(card.difficulty, g);
      if (rating == Rating.again) {
        s = _sOlvido(card.difficulty, card.stability, r);
        lapses++;
        estado = EstadoTarjeta.reaprendiendo;
      } else {
        s = _sRecuerdo(card.difficulty, card.stability, r, g);
        estado = EstadoTarjeta.repaso;
      }
    }
    s = s.clamp(0.1, intervaloMaximo.toDouble());
    final intervalo = rating == Rating.again ? 1 : intervaloPara(s);
    return FsrsCard(
      stability: s,
      difficulty: d,
      due: inicioDiaMas(now, intervalo),
      lastReview: now,
      reps: card.reps + 1,
      lapses: lapses,
      state: estado,
      intervaloDias: intervalo,
    );
  }
}
