import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/features/subscription/domain/entitlements_policy.dart';

void main() {
  final ahora = DateTime.utc(2026, 11, 16, 12);

  Entitlements anual({required DateTime validado, String status = 'active', DateTime? expira, DateTime? renueva}) => Entitlements(
        premium: true,
        noAds: true,
        source: 'store',
        plan: 'annual',
        status: status,
        expiresAt: expira ?? ahora.add(const Duration(days: 200)),
        renewsAt: renueva,
        trialUsed: true,
        validatedAt: validado,
      );

  test('[premium-subscription] Escenario: Inicio de la prueba', () {
    final e = Entitlements.none(ahora);
    expect(accionPrincipal(e), 'Probar 7 días gratis');
    expect(pruebaDisponible(e), isTrue);
    expect(fechaPrimerCobro(ahora), ahora.add(const Duration(days: 7)));
  });

  test('[premium-subscription] Escenario: Prueba ya consumida', () {
    final e = Entitlements(trialUsed: true, validatedAt: ahora);
    expect(accionPrincipal(e), 'Suscribirme');
    expect(pruebaDisponible(e), isFalse);
  });

  test('[premium-subscription] Escenario: Dos semanas sin conexión', () {
    final d = derechosEfectivos(anual(validado: ahora.subtract(const Duration(days: 14))), ahora);
    expect(d.sinAnuncios, isTrue);
    expect(d.premium, isTrue);
    expect(d.aviso, isNull);
  });

  test('[premium-subscription] Escenario: Más de treinta días sin conexión', () {
    final d = derechosEfectivos(anual(validado: ahora.subtract(const Duration(days: 31))), ahora);
    expect(d.sinAnuncios, isFalse);
    expect(d.premium, isFalse);
    expect(d.aviso, 'Conéctate para comprobar tu suscripción');
    expect(d.motivo, MotivoPlanGratuito.sinValidarMasDe30Dias);
  });

  test('[premium-subscription] Escenario: Cancelación a mitad de periodo', () {
    final e = Entitlements(
      premium: true,
      noAds: true,
      source: 'store',
      plan: 'monthly',
      status: 'cancelled',
      expiresAt: ahora.add(const Duration(days: 10)),
      trialUsed: true,
      validatedAt: ahora,
    );
    for (var dia = 0; dia < 10; dia++) {
      expect(derechosEfectivos(e, ahora.add(Duration(days: dia))).sinAnuncios, isTrue, reason: 'día $dia');
    }
    expect(derechosEfectivos(e, ahora.add(const Duration(days: 10))).sinAnuncios, isFalse);
    expect(estadoParaPerfil(e, ahora).detalle, startsWith('Termina el'));
  });

  test('[premium-subscription] Escenario: Suscripción caducada', () {
    final fin = ahora.subtract(const Duration(hours: 1));
    final e = anual(validado: ahora.subtract(const Duration(days: 2)), expira: fin);
    expect(derechosEfectivos(e, ahora).sinAnuncios, isFalse);
    expect(debeAvisarPremiumTerminado(e, ahora, null), isTrue);
    // Tras mostrarlo una vez, se guarda la caducidad avisada y no se repite.
    expect(debeAvisarPremiumTerminado(e, ahora.add(const Duration(days: 1)), fin), isFalse);
    expect(avisoPremiumTerminado, 'Tu Premium ha terminado');
  });

  test('[premium-subscription] Escenario: Límite de manos libres en el plan gratuito', () {
    const reglas = FreePlanRules(handsfreeDailyMinutes: 5);
    final l = limiteManosLibres(premium: false, usadoHoyMs: 5 * 60000, reglas: reglas);
    expect(l.permitido, isFalse);
    expect(l.mensaje, contains('modo táctil'));
    expect(l.mensaje, contains('Premium'));
    expect(limiteManosLibres(premium: false, usadoHoyMs: 60000, reglas: reglas).restanteMs, 4 * 60000);
  });

  test('[premium-subscription] Escenario: Manos libres con Premium', () {
    final l = limiteManosLibres(premium: true, usadoHoyMs: 30 * 60000, reglas: const FreePlanRules());
    expect(l.permitido, isTrue);
    expect(l.restanteMs, isNull);
  });

  test('[premium-subscription] Escenario: Aviso previo al cobro', () {
    final inicio = ahora;
    final e = Entitlements(
      premium: true,
      noAds: true,
      source: 'store',
      plan: 'trial',
      status: 'active',
      trialUsed: true,
      trialEndsAt: inicio.add(const Duration(days: 7)),
      expiresAt: inicio.add(const Duration(days: 7)),
      validatedAt: inicio,
    );
    final momento = momentoRecordatorioPrueba(e, inicio)!;
    expect(e.trialEndsAt!.difference(momento), const Duration(hours: 48));
    // Día 5 de la prueba: faltan 48 h → se avisa ya.
    final dia5 = inicio.add(const Duration(days: 5));
    expect(momentoRecordatorioPrueba(e, dia5), dia5);
    // A menos de 24 h ya no se programa.
    expect(momentoRecordatorioPrueba(e, inicio.add(const Duration(days: 6, hours: 1))), isNull);
    final texto = textoRecordatorioPrueba(finPrueba: e.trialEndsAt!, precio: '39.99', plan: 'annual');
    expect(texto, contains('23 de noviembre'));
    expect(texto, contains('39,99 €'));
    expect(derechosEfectivos(e, dia5).sinAnuncios, isTrue);
  });

  test('[premium-subscription] Escenario: Usuario con plan anual', () {
    final renueva = DateTime.utc(2027, 3, 2, 12);
    final s = estadoParaPerfil(anual(validado: ahora, renueva: renueva), ahora);
    expect(s.titulo, 'Premium anual');
    expect(s.detalle, 'Se renueva el 2 de marzo');
    expect(s.gestionable, isTrue);
  });

  test('[premium-subscription] Escenario: Precios no disponibles', () {
    expect(mostrarPrecios(conectado: false, obtenidosEn: ahora, ahora: ahora), isFalse);
    expect(mostrarPrecios(conectado: true, obtenidosEn: ahora.subtract(const Duration(days: 8)), ahora: ahora), isFalse);
    expect(mostrarPrecios(conectado: true, obtenidosEn: ahora.subtract(const Duration(days: 1)), ahora: ahora), isTrue);
  });

  test('[organizations] Escenario: Miembro sin conexión', () {
    final e = Entitlements(
      premium: true,
      noAds: true,
      source: 'organization',
      plan: 'organization',
      status: 'active',
      validatedAt: ahora.subtract(const Duration(days: 10)),
      organization: const OrganizationRef(id: 'org-1', name: 'Facultad de Enfermería', nominal: false),
    );
    expect(derechosEfectivos(e, ahora).sinAnuncios, isTrue);
    expect(estadoParaPerfil(e, ahora).titulo, 'Plaza de Facultad de Enfermería');
  });

  test('plan gratuito en Perfil', () {
    expect(estadoParaPerfil(Entitlements.none(ahora), ahora).titulo, 'Plan gratuito');
    expect(importe('6.99'), '6,99 €');
  });
}
