/// Derechos de Premium evaluados en el dispositivo (diseño D9 de
/// add-house-ads-and-premium): validez sin conexión, caducidad, prueba,
/// recordatorio previo al cobro, límite de manos libres y estado en Perfil.
library;

import 'package:decimal/decimal.dart';

import '../../../core/domain/content_models.dart';
import '../../../core/domain/learning_models.dart';

const validezSinConexion = Duration(days: 30);
const frescuraPrecios = Duration(days: 7);
const avisoRevalidar = 'Conéctate para comprobar tu suscripción';
const avisoPremiumTerminado = 'Tu Premium ha terminado';
const textoCancelar = 'Cancela cuando quieras desde los ajustes de la tienda';
const textoCompraSinConexion = 'Para comprar hace falta conexión. Tu acceso ya adquirido sigue activo.';

enum MotivoPlanGratuito { ninguno, sinValidarMasDe30Dias, caducado, sinSuscripcion }

/// Derechos efectivos en este momento.
class DerechosEfectivos {
  const DerechosEfectivos({required this.premium, required this.sinAnuncios, required this.motivo, this.aviso});
  final bool premium;
  final bool sinAnuncios;
  final MotivoPlanGratuito motivo;

  /// Aviso que debe verse (p. ej. «Conéctate para comprobar tu suscripción»).
  final String? aviso;
}

bool _caducado(Entitlements e, DateTime ahora) => e.expiresAt != null && !ahora.isBefore(e.expiresAt!);

/// ¿El registro guardado concede Premium (activo, cancelado aún en periodo,
/// prueba o plaza de organización)?
bool _concede(Entitlements e) =>
    (e.premium || e.noAds) && (e.status == 'active' || e.status == 'cancelled' || e.plan == 'trial' || e.source == 'organization');

DerechosEfectivos derechosEfectivos(Entitlements e, DateTime ahora) {
  if (!_concede(e)) {
    return DerechosEfectivos(
      premium: false,
      sinAnuncios: false,
      motivo: e.status == 'expired' ? MotivoPlanGratuito.caducado : MotivoPlanGratuito.sinSuscripcion,
    );
  }
  if (_caducado(e, ahora)) {
    return const DerechosEfectivos(premium: false, sinAnuncios: false, motivo: MotivoPlanGratuito.caducado);
  }
  if (ahora.difference(e.validatedAt) > validezSinConexion) {
    return const DerechosEfectivos(
      premium: false,
      sinAnuncios: false,
      motivo: MotivoPlanGratuito.sinValidarMasDe30Dias,
      aviso: avisoRevalidar,
    );
  }
  return DerechosEfectivos(premium: e.premium || e.source == 'organization', sinAnuncios: true, motivo: MotivoPlanGratuito.ninguno);
}

/// Aviso único «Tu Premium ha terminado»: se muestra si el Premium ha
/// caducado y aún no se avisó de esta caducidad concreta.
///
/// [ultimoAvisoParaExpiracion] es la fecha de caducidad de la que ya se avisó
/// (se guarda en local tras mostrar el aviso).
bool debeAvisarPremiumTerminado(Entitlements e, DateTime ahora, DateTime? ultimoAvisoParaExpiracion) {
  final huboPremium = e.premium || e.noAds || e.status == 'expired';
  if (!huboPremium || e.expiresAt == null) return false;
  final caducado = e.status == 'expired' || _caducado(e, ahora);
  if (!caducado) return false;
  return ultimoAvisoParaExpiracion == null || !ultimoAvisoParaExpiracion.isAtSameMomentAs(e.expiresAt!);
}

/// Acción principal de la pantalla de suscripción.
String accionPrincipal(Entitlements e) => e.trialUsed ? 'Suscribirme' : 'Probar 7 días gratis';

bool pruebaDisponible(Entitlements e) => !e.trialUsed;

/// Fecha del primer cobro si se empieza la prueba ahora.
DateTime fechaPrimerCobro(DateTime ahora, {int diasPrueba = 7}) => ahora.add(Duration(days: diasPrueba));

/// Momento de la notificación local previa al fin de la prueba (24–48 h antes).
/// Devuelve null si no hay prueba o faltan menos de 24 h.
DateTime? momentoRecordatorioPrueba(Entitlements e, DateTime ahora) {
  if (e.plan != 'trial' || e.trialEndsAt == null) return null;
  final fin = e.trialEndsAt!;
  final restante = fin.difference(ahora);
  if (restante < const Duration(hours: 24)) return null;
  final objetivo = fin.subtract(const Duration(hours: 48));
  return objetivo.isAfter(ahora) ? objetivo : ahora;
}

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

String fechaLarga(DateTime t) {
  final l = t.toLocal();
  return '${l.day} de ${_meses[l.month - 1]}';
}

/// Importe con coma decimal y dos decimales: «39,99 €».
String importe(String precio, [String moneda = 'EUR']) {
  final s = Decimal.parse(precio).round(scale: 2).toStringAsFixed(2).replaceAll('.', ',');
  return moneda == 'EUR' ? '$s €' : '$s $moneda';
}

String textoRecordatorioPrueba({required DateTime finPrueba, required String precio, required String plan}) {
  final periodo = plan == 'annual' ? 'al año' : 'al mes';
  return 'Tu prueba de Premium termina el ${fechaLarga(finPrueba)}. Ese día se cobrarán ${importe(precio)} $periodo. $textoCancelar.';
}

/// Precios visibles solo con conexión y obtenidos en los últimos 7 días.
bool mostrarPrecios({required bool conectado, required DateTime? obtenidosEn, required DateTime ahora}) =>
    conectado && obtenidosEn != null && !ahora.difference(obtenidosEn).isNegative && ahora.difference(obtenidosEn) <= frescuraPrecios;

/// Límite diario de manos libres del plan gratuito.
class LimiteManosLibres {
  const LimiteManosLibres({required this.permitido, required this.restanteMs, this.mensaje});
  final bool permitido;

  /// Milisegundos que quedan hoy; null = sin límite (Premium).
  final int? restanteMs;
  final String? mensaje;
}

LimiteManosLibres limiteManosLibres({required bool premium, required int usadoHoyMs, required FreePlanRules reglas}) {
  if (premium) return const LimiteManosLibres(permitido: true, restanteMs: null);
  final limiteMs = reglas.handsfreeDailyMinutes * 60000;
  final restante = limiteMs - usadoHoyMs;
  if (restante <= 0) {
    return LimiteManosLibres(
      permitido: false,
      restanteMs: 0,
      mensaje:
          'Has usado hoy tus ${reglas.handsfreeDailyMinutes} minutos de manos libres. Sigue en modo táctil o entrena sin límite con Premium.',
    );
  }
  return LimiteManosLibres(permitido: true, restanteMs: restante);
}

/// Estado de la suscripción para Perfil.
class EstadoSuscripcion {
  const EstadoSuscripcion({required this.titulo, this.detalle, this.gestionable = false});
  final String titulo;
  final String? detalle;

  /// Muestra el enlace «Gestionar en la tienda».
  final bool gestionable;
}

EstadoSuscripcion estadoParaPerfil(Entitlements e, DateTime ahora) {
  final d = derechosEfectivos(e, ahora);
  if (!d.premium && !d.sinAnuncios) {
    return EstadoSuscripcion(titulo: 'Plan gratuito', detalle: d.aviso);
  }
  if (e.source == 'organization') {
    final nombre = e.organization?.name ?? 'tu organización';
    return EstadoSuscripcion(titulo: 'Plaza de $nombre', detalle: e.expiresAt == null ? null : 'Hasta el ${fechaLarga(e.expiresAt!)}');
  }
  if (e.plan == 'trial') {
    final fin = e.trialEndsAt ?? e.expiresAt;
    final dias = fin == null ? 0 : (fin.difference(ahora).inHours / 24).ceil();
    return EstadoSuscripcion(
      titulo: 'Prueba gratuita · quedan $dias ${dias == 1 ? 'día' : 'días'}',
      detalle: fin == null ? null : 'Primer cobro el ${fechaLarga(fin)}',
      gestionable: true,
    );
  }
  final titulo = switch (e.plan) { 'annual' => 'Premium anual', 'monthly' => 'Premium mensual', _ => 'Premium' };
  String? detalle;
  if (e.status == 'cancelled' && e.expiresAt != null) {
    detalle = 'Termina el ${fechaLarga(e.expiresAt!)}';
  } else if (e.renewsAt != null) {
    detalle = 'Se renueva el ${fechaLarga(e.renewsAt!)}';
  }
  return EstadoSuscripcion(titulo: titulo, detalle: detalle, gestionable: e.source == 'store');
}
