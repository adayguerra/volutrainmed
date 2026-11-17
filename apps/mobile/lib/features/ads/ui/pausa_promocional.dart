import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/tema.dart';
import '../../../core/domain/learning_models.dart';
import '../domain/ad_selector.dart';

/// Datos del momento de la pausa promocional que aporta la sesión.
class DatosPausa {
  const DatosPausa({
    required this.modo,
    required this.sessionId,
    this.ejerciciosLeccion = 0,
    this.aciertosLeccion = 0,
    this.ultimaPausa = false,
    this.leccionConFallos = false,
    this.unidadCompletada = false,
    this.trasContrarreloj = false,
    this.trasManosLibres = false,
  });
  final SessionMode modo;
  final String sessionId;
  final int ejerciciosLeccion;
  final int aciertosLeccion;
  final bool ultimaPausa;
  final bool leccionConFallos;
  final bool unidadCompletada;
  final bool trasContrarreloj;
  final bool trasManosLibres;
}

/// Resultado de la pausa: si el usuario ha comprado Premium desde la acción
/// del anuncio, la sesión deja de mostrar pausas (premium-subscription).
class ResultadoPausa {
  const ResultadoPausa({required this.permanenciaMs, this.compro = false, this.anuncioId});
  final int permanenciaMs;
  final bool compro;
  final String? anuncioId;
}

/// Pausa promocional a pantalla completa (house-ads). La sesión la muestra
/// cuando `MotorSesion.fase == FaseSesion.pausaPromocional` y llama a
/// `MotorSesion.cerrarPausa()` en [alCerrar].
///
/// Interfaz estable entre la sesión y los anuncios; la implementación
/// completa (selector, cuenta atrás, acción hacia la suscripción, medición)
/// la aporta la capacidad de anuncios.
class PausaPromocional extends ConsumerStatefulWidget {
  const PausaPromocional({super.key, required this.datos, required this.alCerrar});
  final DatosPausa datos;
  final ValueChanged<ResultadoPausa> alCerrar;

  @override
  ConsumerState<PausaPromocional> createState() => _PausaPromocionalState();
}

class _PausaPromocionalState extends ConsumerState<PausaPromocional> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(rotuloPromocion, style: context.textos.labelSmall),
                const Spacer(),
                FilledButton(onPressed: () => widget.alCerrar(const ResultadoPausa(permanenciaMs: 0)), child: const Text('Continuar')),
              ],
            ),
          ),
        ),
      );
}
