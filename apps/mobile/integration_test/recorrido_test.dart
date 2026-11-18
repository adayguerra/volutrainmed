import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:volutrainmed/app/app.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/data/database.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';
import 'package:volutrainmed/features/session/ui/pantalla_sesion.dart';
import 'package:volutrainmed/main.dart' as app;

/// Recorrido de extremo a extremo con la app real (SQLite, contenido firmado
/// incluido, complementos de la plataforma) en un simulador o dispositivo:
///
///   flutter test integration_test -d UDID
///
/// Bienvenida → alta en cuatro pasos con el aviso formativo → primera lección
/// (un fallo con su diagnóstico) → Inicio con el progreso → repaso con la
/// ficha fallada → Perfil → centro de sincronización.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Espera (con reloj real) a que aparezca [f].
  Future<void> esperar(WidgetTester t, Finder f, {Duration tope = const Duration(seconds: 30), String? que}) async {
    final fin = DateTime.now().add(tope);
    while (DateTime.now().isBefore(fin)) {
      await t.pump(const Duration(milliseconds: 200));
      if (f.evaluate().isNotEmpty) return;
    }
    fail('No ha aparecido ${que ?? f} en ${tope.inSeconds} s');
  }

  Future<void> tocar(WidgetTester t, Finder f) async {
    await esperar(t, f);
    await t.ensureVisible(f.first);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(f.first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 400));
  }

  Finder clave(String k) => find.byKey(ValueKey(k));

  Future<void> teclear(WidgetTester t, String texto) async {
    for (final ch in texto.replaceAll(RegExp('[^0-9,]'), '').split('')) {
      await t.tap(clave('tecla-$ch'));
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Finder pestana(String etiqueta) => find.descendant(
        of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
        matching: find.text(etiqueta),
      );

  testWidgets('recorrido completo: alta, primera lección con un fallo, inicio, repaso, perfil y sincronización', (t) async {
    // Instalación limpia: se vacía la base de datos local.
    final db = VtmDatabase();
    for (final tabla in db.allTables) {
      await db.delete(tabla).go();
    }
    await db.close();

    await app.main();

    // ---- Bienvenida ---------------------------------------------------------
    await esperar(t, find.text('Empezar'), que: 'la bienvenida');
    expect(find.textContaining('No es una calculadora clínica'), findsOneWidget);
    await tocar(t, find.text('Empezar'));

    // ---- Alta en cuatro pasos ----------------------------------------------
    await esperar(t, find.textContaining('Paso 1 de 4'));
    expect(t.widget<FilledButton>(clave('alta-continuar')).onPressed, isNull, reason: 'Continuar desactivado sin selección');
    await tocar(t, clave('sector-enfermeria'));
    await tocar(t, clave('alta-continuar'));

    await esperar(t, find.textContaining('Paso 2 de 4'));
    await tocar(t, clave('nivel-cero'));
    await tocar(t, clave('alta-continuar'));

    await esperar(t, find.textContaining('Paso 3 de 4'));
    await tocar(t, clave('meta-10'));
    await tocar(t, clave('alta-continuar'));

    await esperar(t, find.textContaining('Paso 4 de 4'));
    expect(find.textContaining('VolutrainMed es un entrenador. No lo uses para calcular dosis de pacientes reales'), findsOneWidget);
    await tocar(t, clave('lo-entiendo'));
    await tocar(t, clave('saltar-prueba'));

    // ---- Preparación del itinerario y primera lección ---------------------
    await tocar(t, clave('empezar-primera'));
    await esperar(t, clave('comprobar'), que: 'el primer ejercicio');
    MotorSesion motor() => PantallaSesion.ultimoMotor!;
    final total = motor().total;
    expect(total, greaterThanOrEqualTo(8));
    expect(find.textContaining('Caso simulado'), findsWidgets);

    // Primer ejercicio (numérico): respuesta diez veces mayor → diagnóstico.
    final primero = motor().actual!;
    expect(primero.bloque, 'numeric_unit');
    final mala = formatEs(canon(dec(primero.variante.answer!.value) * dec('10')));
    await teclear(t, mala);
    await tocar(t, clave('comprobar'));
    await esperar(t, clave('diagnostico'), que: 'el diagnóstico del error');
    expect(find.textContaining('diez veces mayor'), findsWidgets);
    expect(find.text('Incorrecto'), findsWidgets);
    await tocar(t, clave('continuar'));

    // Resto de la lección, respondiendo bien según el tipo de ejercicio.
    var vueltas = 0;
    while (motor().fase != FaseSesion.terminada && vueltas++ < 40) {
      await esperar(t, clave('comprobar').evaluate().isNotEmpty ? clave('comprobar') : clave('no-lo-se'));
      final e = motor().actual!;
      final v = e.variante;
      switch (e.bloque) {
        case 'numeric_unit':
          await teclear(t, formatEs(v.answer!.value));
          if (e.unidadAElegir) await tocar(t, clave('unidad-${v.answer!.unit}'));
          await tocar(t, clave('comprobar'));
        case 'single_choice' || 'range_choice':
          await tocar(t, clave('opcion-${v.options!.firstWhere((o) => o.correct).id}'));
          if (motor().fase == FaseSesion.ejercicio) await tocar(t, clave('comprobar'));
        case 'conversion_series':
          for (final s in v.series!) {
            if (motor().fase != FaseSesion.ejercicio) break;
            await teclear(t, formatEs(s.answer.value));
            await tocar(t, clave('comprobar'));
          }
        default:
          await tocar(t, clave('no-lo-se'));
      }
      await esperar(t, clave('continuar'), que: 'la corrección');
      expect(motor().ultimoResultado!.acierto, isTrue, reason: 'ejercicio ${e.variante.id}');
      await tocar(t, clave('continuar'));
    }
    expect(motor().fase, FaseSesion.terminada);

    // ---- Fin de lección -----------------------------------------------------
    await esperar(t, clave('titulo-fin'), que: 'el fin de lección');
    expect(find.textContaining('Lección completada'), findsWidgets);
    expect(find.textContaining('a repaso'), findsWidgets);
    await tocar(t, clave('continuar-fin'));

    // Tras la primera lección se ofrece la cuenta («Ahora no») y el recordatorio.
    await esperar(t, find.text('Ahora no'), que: 'la oferta de cuenta');
    await tocar(t, find.text('Ahora no'));
    await t.pump(const Duration(seconds: 1));
    if (find.text('Ahora no').evaluate().isNotEmpty) await tocar(t, find.text('Ahora no'));

    // ---- Inicio con el progreso ---------------------------------------------
    await esperar(t, pestana('Inicio'), que: 'la navegación principal');
    await esperar(t, find.textContaining('Continuar · Lección 2'), que: '«Continuar · Lección 2»');
    final contenedor = ProviderScope.containerOf(t.element(find.byType(VtmApp)));
    final p = contenedor.read(proyeccionProvider)!;
    expect(p.lecciones.values.where((l) => l.completada), hasLength(1));
    expect(p.puntosTotales, (total - 1) * puntosPorAcierto);
    expect(p.fichas, hasLength(1), reason: 'el fallo crea una ficha de repaso');
    expect(p.fichas.values.single.ultimoErrorCode, 'E2');
    expect(contenedor.read(usuarioProvider).value!.registroPospuesto, isTrue);

    // ---- Repaso: la ficha fallada está programada ---------------------------
    await tocar(t, pestana('Practicar'));
    GoRouter.of(t.element(find.byType(Scaffold).first)).go(Rutas.repaso);
    await esperar(t, find.byWidgetPredicate((w) => w is Text && ((w.data ?? '').contains('ficha'))), que: 'la pantalla de repaso');
    // Error crítico: la ficha entra en cuarentena y vence al día siguiente.
    final vencidaHoy = p.colaHoy.isNotEmpty;
    if (vencidaHoy) {
      expect(clave('empezar-repaso'), findsOneWidget);
    } else {
      expect(find.text('No tienes fichas para hoy'), findsOneWidget);
      expect(clave('proximo-repaso'), findsOneWidget);
      expect(find.textContaining('1 ficha'), findsWidgets);
    }

    // ---- Perfil y centro de sincronización ---------------------------------
    await tocar(t, pestana('Perfil'));
    await esperar(t, find.textContaining('Crea tu cuenta'), que: 'el recordatorio de cuenta del perfil');
    final fila = find.text('Descargas y sincronización');
    await t.scrollUntilVisible(fila, 200, scrollable: find.byType(Scrollable).first);
    await tocar(t, fila);
    await esperar(t, find.text('Sincronizar ahora'), que: 'el centro de sincronización');
    expect(find.text('Fundamentos'), findsWidgets);
    expect(find.textContaining('Solo en este dispositivo'), findsOneWidget);
  });
}
