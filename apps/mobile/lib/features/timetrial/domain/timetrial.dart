/// Contrarreloj (capacidad time-trial): elegibilidad, esprint de 60 s con
/// penalización y regla de precisión, y variante sin cuenta atrás.
///
/// Dominio puro Dart. El tiempo lo aporta el llamador con milisegundos
/// monótonos (`Reloj.monotonoMs`), nunca con temporizadores, de modo que las
/// pausas promocionales (que van al final, fuera del cronómetro) no cuentan.
library;

/// Estado de habilidad tal como lo ve el contrarreloj.
enum EstadoHabilidadCrono { nueva, enAprendizaje, consolidada, dominada, porRefrescar }

EstadoHabilidadCrono estadoCronoDesde(String s) => switch (s) {
      'consolidada' => EstadoHabilidadCrono.consolidada,
      'dominada' => EstadoHabilidadCrono.dominada,
      'porRefrescar' || 'por_refrescar' || 'refresh' => EstadoHabilidadCrono.porRefrescar,
      'enAprendizaje' || 'en_aprendizaje' || 'learning' => EstadoHabilidadCrono.enAprendizaje,
      _ => EstadoHabilidadCrono.nueva,
    };

const mensajeSinHabilidadConsolidada = 'Consolida una habilidad para abrir el contrarreloj';
const explicacionConsolidar =
    'Consolida esta habilidad para abrirla: 85 % de acierto en tus últimos 20 ejercicios, en dos días distintos';
const motivoInterrupcion =
    'El esprint se ha anulado porque la app pasó a segundo plano. Las marcas solo cuentan sin interrupciones';

bool contrarrelojAbierto(EstadoHabilidadCrono e) =>
    e == EstadoHabilidadCrono.consolidada || e == EstadoHabilidadCrono.dominada || e == EstadoHabilidadCrono.porRefrescar;

class ElegibilidadContrarreloj {
  const ElegibilidadContrarreloj({required this.abierta, this.mensaje});
  final bool abierta;
  final String? mensaje;
}

/// Elegibilidad de una habilidad concreta.
ElegibilidadContrarreloj elegibilidad(EstadoHabilidadCrono e) => contrarrelojAbierto(e)
    ? const ElegibilidadContrarreloj(abierta: true)
    : const ElegibilidadContrarreloj(abierta: false, mensaje: explicacionConsolidar);

/// Mensaje global de la pantalla de selección: null si alguna habilidad está abierta.
String? mensajeSeleccion(Map<String, EstadoHabilidadCrono> estados) =>
    estados.values.any(contrarrelojAbierto) ? null : mensajeSinHabilidadConsolidada;

/// Resultado de un esprint o de una serie.
class ResultadoContrarreloj {
  const ResultadoContrarreloj({
    required this.aciertos,
    required this.fallos,
    required this.puntos,
    required this.tiempoMedioMs,
    required this.anulado,
    required this.esRecord,
    this.motivoAnulacion,
  });
  final int aciertos;
  final int fallos;
  final int puntos;
  final int tiempoMedioMs;
  final bool anulado;
  final bool esRecord;
  final String? motivoAnulacion;

  int get total => aciertos + fallos;

  /// Precisión en porcentaje entero (redondeo aritmético).
  int get precisionPct => total == 0 ? 0 : ((aciertos * 100 + total ~/ 2) ~/ total);

  /// Marca válida: no anulada, con algún ejercicio y precisión ≥ 90 %.
  bool get valida => !anulado && total > 0 && aciertos * 100 >= 90 * total;

  /// Texto para la pantalla de cierre cuando la marca no vale.
  String? get mensajeNoValida => (!anulado && total > 0 && !valida)
      ? 'Marca no válida: precisión del $precisionPct %. La rapidez solo cuenta con precisión'
      : null;
}

/// Esprint de 60 segundos.
class Esprint {
  Esprint({
    required int inicioMs,
    this.duracionMs = 60000,
    this.penalizacionMs = 3000,
    this.mostrarCorrectaMs = 1200,
    this.puntosBase = 10,
    this.mejorMarcaValida,
  })  : _inicioMs = inicioMs,
        _ultimaRespuestaMs = inicioMs;

  final int duracionMs;
  final int penalizacionMs;
  final int mostrarCorrectaMs;
  final int puntosBase;

  /// Mejor número de aciertos en una marca válida anterior (null si no hay).
  final int? mejorMarcaValida;

  /// Escalones del multiplicador: crece con cada acierto seguido.
  static const escalones = [1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

  final int _inicioMs;
  int _penalizacionAcumuladaMs = 0;
  int _ultimaRespuestaMs;
  int _racha = 0;
  int _aciertos = 0;
  int _fallos = 0;
  int _puntos = 0;
  int _sumaTiemposMs = 0;
  bool _anulado = false;
  int? _finMs;
  int? mostrarCorrectaHasta;

  int get aciertos => _aciertos;
  int get fallos => _fallos;
  int get puntos => _puntos;
  bool get anulado => _anulado;
  double get multiplicador => escalones[_racha.clamp(0, escalones.length - 1)];

  int restanteMs(int ahoraMs) {
    if (_finMs != null) return 0;
    final r = duracionMs - (ahoraMs - _inicioMs) - _penalizacionAcumuladaMs;
    return r < 0 ? 0 : r;
  }

  bool terminado(int ahoraMs) => _anulado || _finMs != null || restanteMs(ahoraMs) <= 0;

  /// Últimos 10 segundos: la barra pasa a ámbar.
  bool enAvisoFinal(int ahoraMs) => restanteMs(ahoraMs) <= 10000;

  /// Registra una respuesta. Devuelve false si el esprint ya había terminado.
  bool responder({required bool correcto, required int ahoraMs}) {
    if (terminado(ahoraMs)) return false;
    _sumaTiemposMs += ahoraMs - _ultimaRespuestaMs;
    _ultimaRespuestaMs = ahoraMs;
    if (correcto) {
      _aciertos++;
      _puntos += (puntosBase * multiplicador).round();
      _racha++;
      mostrarCorrectaHasta = null;
    } else {
      _fallos++;
      _racha = 0;
      _penalizacionAcumuladaMs += penalizacionMs;
      mostrarCorrectaHasta = ahoraMs + mostrarCorrectaMs;
      if (restanteMs(ahoraMs) <= 0) _finMs = ahoraMs;
    }
    return true;
  }

  /// Excluye del cronómetro el tiempo que se muestra la respuesta correcta
  /// tras un fallo (1,2 s), para no penalizar dos veces. El llamador lo
  /// invoca al presentar el ejercicio siguiente.
  void presentarSiguiente(int ahoraMs) => _ultimaRespuestaMs = ahoraMs;

  /// La app pasa a segundo plano: el esprint se anula, no se pausa.
  void interrumpir() => _anulado = true;

  ResultadoContrarreloj resultado() {
    final total = _aciertos + _fallos;
    final base = ResultadoContrarreloj(
      aciertos: _aciertos,
      fallos: _fallos,
      puntos: _anulado ? 0 : _puntos,
      tiempoMedioMs: total == 0 ? 0 : _sumaTiemposMs ~/ total,
      anulado: _anulado,
      esRecord: false,
      motivoAnulacion: _anulado ? motivoInterrupcion : null,
    );
    final record = base.valida && (mejorMarcaValida == null || _aciertos > mejorMarcaValida!);
    return ResultadoContrarreloj(
      aciertos: base.aciertos,
      fallos: base.fallos,
      puntos: base.puntos,
      tiempoMedioMs: base.tiempoMedioMs,
      anulado: base.anulado,
      esRecord: record,
      motivoAnulacion: base.motivoAnulacion,
    );
  }
}

/// Variante sin cuenta atrás: N ejercicios, mide el tiempo sin limitarlo.
class SerieSinLimite {
  SerieSinLimite({required this.ejercicios, required int inicioMs}) : _ultimoMs = inicioMs;
  final int ejercicios;
  int _ultimoMs;
  final List<int> _tiempos = [];
  int _aciertos = 0;
  int _fallos = 0;
  bool _anulado = false;

  int get respondidos => _aciertos + _fallos;
  bool get terminada => _anulado || respondidos >= ejercicios;

  void presentarSiguiente(int ahoraMs) => _ultimoMs = ahoraMs;

  bool responder({required bool correcto, required int ahoraMs}) {
    if (terminada) return false;
    _tiempos.add(ahoraMs - _ultimoMs);
    _ultimoMs = ahoraMs;
    correcto ? _aciertos++ : _fallos++;
    return true;
  }

  /// Sin cuenta atrás la interrupción también anula la serie, para que las
  /// marcas sean comparables.
  void interrumpir() => _anulado = true;

  int get tiempoMedioMs => _tiempos.isEmpty ? 0 : _tiempos.reduce((a, b) => a + b) ~/ _tiempos.length;

  ResultadoContrarreloj resultado() => ResultadoContrarreloj(
        aciertos: _aciertos,
        fallos: _fallos,
        puntos: 0,
        tiempoMedioMs: tiempoMedioMs,
        anulado: _anulado,
        esRecord: false,
        motivoAnulacion: _anulado ? motivoInterrupcion : null,
      );
}
