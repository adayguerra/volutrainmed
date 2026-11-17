/// Ligas semanales (capacidad leagues, lado app): modelo de la clasificación
/// de `GET /v1/leagues/current`, caché sin conexión con su antigüedad, zonas
/// rotuladas y puntos locales pendientes con tope diario.
///
/// La clasificación solo muestra alias, nunca nombres ni correos.
library;

import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';
import '../../../core/domain/reloj.dart';

enum ZonaLiga { ascenso, permanencia, descenso }

const rotulosZona = {
  ZonaLiga.ascenso: 'Zona de ascenso',
  ZonaLiga.permanencia: 'Permanencia',
  ZonaLiga.descenso: 'Zona de descenso',
};

const textoNoParticipas = 'No participas en ligas';

class FilaLiga {
  const FilaLiga({required this.position, required this.alias, required this.points, required this.me});
  final int position;
  final String alias;
  final int points;
  final bool me;
  factory FilaLiga.fromJson(Map<String, dynamic> j) => FilaLiga(
        position: (j['position'] as num?)?.toInt() ?? 0,
        alias: '${j['alias'] ?? ''}',
        points: (j['points'] as num?)?.toInt() ?? 0,
        me: j['me'] == true,
      );
  Map<String, dynamic> toJson() => {'position': position, 'alias': alias, 'points': points, 'me': me};
}

class ClasificacionLiga {
  const ClasificacionLiga({
    required this.participating,
    this.week,
    this.division,
    this.endsAt,
    this.standings = const [],
    this.promote = 7,
    this.relegate = 5,
    required this.computedAt,
    this.pendingPoints = 0,
  });
  final bool participating;
  final String? week;
  final String? division;
  final DateTime? endsAt;
  final List<FilaLiga> standings;
  final int promote;
  final int relegate;
  final DateTime computedAt;
  final int pendingPoints;

  factory ClasificacionLiga.fromJson(Map<String, dynamic> j) {
    final zones = (j['zones'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ClasificacionLiga(
      participating: j['participating'] != false,
      week: j['week']?.toString(),
      division: j['division']?.toString(),
      endsAt: j['endsAt'] == null ? null : DateTime.tryParse('${j['endsAt']}'),
      standings: ((j['standings'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FilaLiga.fromJson(e.cast<String, dynamic>()))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
      promote: (zones['promote'] as num?)?.toInt() ?? 7,
      relegate: (zones['relegate'] as num?)?.toInt() ?? 5,
      computedAt: DateTime.tryParse('${j['computedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pendingPoints: (j['pendingPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'participating': participating,
        'week': week,
        'division': division,
        'endsAt': endsAt?.toUtc().toIso8601String(),
        'standings': standings.map((f) => f.toJson()).toList(),
        'zones': {'promote': promote, 'relegate': relegate},
        'computedAt': computedAt.toUtc().toIso8601String(),
        'pendingPoints': pendingPoints,
      };

  FilaLiga? get propia {
    for (final f in standings) {
      if (f.me) return f;
    }
    return null;
  }

  ZonaLiga zonaDe(FilaLiga f) {
    final n = standings.length;
    if (f.position <= promote) return ZonaLiga.ascenso;
    if (n > promote + relegate && f.position > n - relegate) return ZonaLiga.descenso;
    return ZonaLiga.permanencia;
  }

  /// Días que quedan hasta el cierre de la semana.
  int diasRestantes(DateTime ahora) {
    if (endsAt == null) return 0;
    final d = endsAt!.difference(ahora).inHours;
    return d <= 0 ? 0 : (d / 24).ceil();
  }

  /// Etiqueta accesible: «Posición 6, lucia_m, 418 puntos».
  static String etiquetaFila(FilaLiga f) => 'Posición ${f.position}, ${f.alias}, ${f.points} puntos${f.me ? ', tú' : ''}';
}

/// «Clasificación de hace 3 h», «de hace 12 min», «de hace 2 días».
String textoAntiguedad(DateTime computedAt, DateTime ahora) {
  final d = ahora.difference(computedAt);
  if (d.inMinutes < 1) return 'Clasificación de hace un momento';
  if (d.inHours < 1) return 'Clasificación de hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'Clasificación de hace ${d.inHours} h';
  final dias = d.inDays;
  return 'Clasificación de hace $dias ${dias == 1 ? 'día' : 'días'}';
}

/// Puntos de liga calculados en el dispositivo, pendientes de sumar.
///
/// Solo puntúan los aciertos al primer intento; la bonificación de
/// contrarreloj exige marca válida; tope diario por día local.
class PuntosLigaLocales {
  const PuntosLigaLocales({required this.porDia});
  final Map<DateTime, int> porDia;
  int get total => porDia.values.fold(0, (a, b) => a + b);
  int hoy(DateTime ahora) => porDia[diaLocal(ahora)] ?? 0;
}

PuntosLigaLocales puntosLiga({
  required Iterable<Attempt> intentos,
  required Iterable<SessionRecord> sesiones,
  required LeagueConfig config,
  DateTime? desde,
}) {
  final crudos = <DateTime, int>{};
  void sumar(DateTime t, int p) {
    if (desde != null && t.isBefore(desde)) return;
    final d = diaLocal(t);
    crudos[d] = (crudos[d] ?? 0) + p;
  }

  for (final a in intentos) {
    if (a.attemptNumber == 1 && a.correct && a.mode != SessionMode.placement) {
      sumar(a.deviceTime, config.pointsPerCorrect);
    }
  }
  for (final s in sesiones) {
    final esCrono = s.mode == SessionMode.timetrial;
    if (esCrono && s.completed && s.summary?.valid == true && s.summary?.cancelled != true) {
      sumar(s.endedAt, config.timetrialBonus);
    }
  }
  return PuntosLigaLocales(porDia: {for (final e in crudos.entries) e.key: e.value > config.dailyCap ? config.dailyCap : e.value});
}
