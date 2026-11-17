/// Reloj inyectable: todo el dominio pide la hora aquí para poder probar
/// cuarentenas, rachas, topes diarios y validez de la suscripción.
library;

abstract class Reloj {
  DateTime ahora();

  /// Milisegundos monótonos para medir tiempos de respuesta.
  int monotonoMs();
}

class RelojSistema implements Reloj {
  RelojSistema() : _sw = Stopwatch()..start();
  final Stopwatch _sw;
  @override
  DateTime ahora() => DateTime.now();
  @override
  int monotonoMs() => _sw.elapsedMilliseconds;
}

/// Reloj controlable para pruebas.
class RelojFijo implements Reloj {
  RelojFijo(this._ahora);
  DateTime _ahora;
  int _ms = 0;
  @override
  DateTime ahora() => _ahora;
  @override
  int monotonoMs() => _ms;
  void avanzar(Duration d) {
    _ahora = _ahora.add(d);
    _ms += d.inMilliseconds;
  }

  void fijar(DateTime t) => _ahora = t;
}

/// Día local (sin hora) para rachas, topes diarios y días distintos.
DateTime diaLocal(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

int diasEntre(DateTime a, DateTime b) {
  final da = diaLocal(a);
  final db = diaLocal(b);
  return DateTime.utc(db.year, db.month, db.day).difference(DateTime.utc(da.year, da.month, da.day)).inDays;
}

/// Lunes de la semana local de [t].
DateTime lunesDe(DateTime t) {
  final d = diaLocal(t);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}
