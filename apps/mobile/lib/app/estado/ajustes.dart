import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dependencias.dart';

enum ConfirmacionVoz { siempre, siHayDuda, nunca }

/// Preferencias del usuario (perfil › accesibilidad, voz, meta). Se guardan
/// en el dispositivo y no se sincronizan.
@immutable
class Ajustes {
  const Ajustes({
    this.tema = ThemeMode.system,
    this.textoExtra = 0,
    this.altoContraste = false,
    this.reducirMovimiento = false,
    this.haptica = true,
    this.sonidos = true,
    this.sinLimiteTiempo = false,
    this.manoIzquierda = false,
    this.topeRepaso = 20,
    this.velocidadVoz = 1.0,
    this.confirmacion = ConfirmacionVoz.siempre,
    this.esperaSilencioMs = 900,
    this.cifraACifra = false,
    this.gammas = false,
    this.soloWifi = true,
    this.recordatorio,
    this.lecturaExplicaciones = 'breve',
    this.modoBolsillo = false,
  });

  final ThemeMode tema;

  /// Tamaño de texto adicional sobre el del sistema (0 a 0,5).
  final double textoExtra;
  final bool altoContraste;

  /// Preferencia propia de movimiento reducido (además de la del sistema).
  final bool reducirMovimiento;
  final bool haptica;
  final bool sonidos;

  /// «Ejercicios sin límite de tiempo»: el tiempo se mide pero no limita.
  final bool sinLimiteTiempo;
  final bool manoIzquierda;
  final int topeRepaso;
  final double velocidadVoz;
  final ConfirmacionVoz confirmacion;
  final int esperaSilencioMs;
  final bool cifraACifra;

  /// Sinónimo de sector «gammas» = microgramos.
  final bool gammas;
  final bool soloWifi;

  /// Hora del recordatorio diario («20:30») o null si no hay.
  final String? recordatorio;
  final String lecturaExplicaciones;
  final bool modoBolsillo;

  Ajustes copyWith({
    ThemeMode? tema,
    double? textoExtra,
    bool? altoContraste,
    bool? reducirMovimiento,
    bool? haptica,
    bool? sonidos,
    bool? sinLimiteTiempo,
    bool? manoIzquierda,
    int? topeRepaso,
    double? velocidadVoz,
    ConfirmacionVoz? confirmacion,
    int? esperaSilencioMs,
    bool? cifraACifra,
    bool? gammas,
    bool? soloWifi,
    String? recordatorio,
    bool quitarRecordatorio = false,
    String? lecturaExplicaciones,
    bool? modoBolsillo,
  }) =>
      Ajustes(
        tema: tema ?? this.tema,
        textoExtra: textoExtra ?? this.textoExtra,
        altoContraste: altoContraste ?? this.altoContraste,
        reducirMovimiento: reducirMovimiento ?? this.reducirMovimiento,
        haptica: haptica ?? this.haptica,
        sonidos: sonidos ?? this.sonidos,
        sinLimiteTiempo: sinLimiteTiempo ?? this.sinLimiteTiempo,
        manoIzquierda: manoIzquierda ?? this.manoIzquierda,
        topeRepaso: topeRepaso ?? this.topeRepaso,
        velocidadVoz: velocidadVoz ?? this.velocidadVoz,
        confirmacion: confirmacion ?? this.confirmacion,
        esperaSilencioMs: esperaSilencioMs ?? this.esperaSilencioMs,
        cifraACifra: cifraACifra ?? this.cifraACifra,
        gammas: gammas ?? this.gammas,
        soloWifi: soloWifi ?? this.soloWifi,
        recordatorio: quitarRecordatorio ? null : (recordatorio ?? this.recordatorio),
        lecturaExplicaciones: lecturaExplicaciones ?? this.lecturaExplicaciones,
        modoBolsillo: modoBolsillo ?? this.modoBolsillo,
      );

  Map<String, dynamic> toJson() => {
        'tema': tema.name,
        'textoExtra': textoExtra,
        'altoContraste': altoContraste,
        'reducirMovimiento': reducirMovimiento,
        'haptica': haptica,
        'sonidos': sonidos,
        'sinLimiteTiempo': sinLimiteTiempo,
        'manoIzquierda': manoIzquierda,
        'topeRepaso': topeRepaso,
        'velocidadVoz': velocidadVoz,
        'confirmacion': confirmacion.name,
        'esperaSilencioMs': esperaSilencioMs,
        'cifraACifra': cifraACifra,
        'gammas': gammas,
        'soloWifi': soloWifi,
        'recordatorio': recordatorio,
        'lecturaExplicaciones': lecturaExplicaciones,
        'modoBolsillo': modoBolsillo,
      };

  factory Ajustes.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const Ajustes();
    T en<T extends Enum>(List<T> vs, Object? v, T d) => vs.where((x) => x.name == v).firstOrNull ?? d;
    return Ajustes(
      tema: en(ThemeMode.values, j['tema'], ThemeMode.system),
      textoExtra: (j['textoExtra'] as num?)?.toDouble() ?? 0,
      altoContraste: j['altoContraste'] == true,
      reducirMovimiento: j['reducirMovimiento'] == true,
      haptica: j['haptica'] != false,
      sonidos: j['sonidos'] != false,
      sinLimiteTiempo: j['sinLimiteTiempo'] == true,
      manoIzquierda: j['manoIzquierda'] == true,
      topeRepaso: (j['topeRepaso'] as num?)?.toInt() ?? 20,
      velocidadVoz: (j['velocidadVoz'] as num?)?.toDouble() ?? 1.0,
      confirmacion: en(ConfirmacionVoz.values, j['confirmacion'], ConfirmacionVoz.siempre),
      esperaSilencioMs: (j['esperaSilencioMs'] as num?)?.toInt() ?? 900,
      cifraACifra: j['cifraACifra'] == true,
      gammas: j['gammas'] == true,
      soloWifi: j['soloWifi'] != false,
      recordatorio: j['recordatorio'] as String?,
      lecturaExplicaciones: (j['lecturaExplicaciones'] as String?) ?? 'breve',
      modoBolsillo: j['modoBolsillo'] == true,
    );
  }
}

const claveAjustes = 'ajustes';

class AjustesNotifier extends Notifier<Ajustes> {
  @override
  Ajustes build() => const Ajustes();

  /// Carga los ajustes guardados (al arrancar).
  Future<void> cargar() async {
    state = Ajustes.fromJson(await ref.read(dependenciasProvider).claves.leerJson(claveAjustes));
  }

  Future<void> cambiar(Ajustes Function(Ajustes) f) async {
    state = f(state);
    await ref.read(dependenciasProvider).claves.escribirJson(claveAjustes, state.toJson());
  }
}

final ajustesProvider = NotifierProvider<AjustesNotifier, Ajustes>(AjustesNotifier.new);
