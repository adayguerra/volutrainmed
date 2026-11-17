import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/app/estado/ajustes.dart';
import 'package:volutrainmed/app/estado/estado_app.dart';
import 'package:volutrainmed/app/router.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/decimal_es.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/onboarding/domain/placement.dart';
import 'package:volutrainmed/features/onboarding/ui/pantallas_alta.dart';

import '../helpers/arnes.dart';

/// Pruebas de widget del alta (M01, M04–M11).

/// Usuario nuevo con perfil a medias (para entrar en un paso concreto).
EstadoUsuario usuarioEnAlta({String? nivel = 'cero', String itinerario = 'it-fundamentos', Map<String, dynamic>? prueba}) => EstadoUsuario(
      deviceId: 'disp-prueba',
      pruebaEnCurso: prueba,
      perfil: UserProfile(
        id: 'local-disp-prueba',
        alias: 'BuretaClara20',
        sectorId: 'enfermeria',
        itineraryId: itinerario,
        declaredLevel: nivel,
        goal: const Goal.daily(10),
        disclaimerAcceptedAt: ahoraPrueba,
        createdAt: ahoraPrueba,
      ),
    );

Future<void> tocar(WidgetTester t, Finder f) async {
  // Las listas se construyen bajo demanda: se desplaza hasta el elemento.
  if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await Arnes.asentar(t);
}

FilledButton botonContinuar(WidgetTester t) => t.widget<FilledButton>(find.byKey(const ValueKey('alta-continuar')));

PruebaNivel pruebaGuardada(Arnes a) =>
    PruebaNivel.fromJson((a.contenedor.read(usuarioProvider).value!.pruebaEnCurso!['prueba'] as Map).cast<String, dynamic>());

/// Responde la pregunta actual de la prueba de nivel a través de la interfaz.
Future<void> responderPrueba(WidgetTester t, Arnes a, {required bool bien}) async {
  if (!bien) {
    await tocar(t, find.byKey(const ValueKey('prueba-no-lo-se')));
    return;
  }
  final v = a.contenido.variante(pruebaGuardada(a).varianteActual!)!;
  if (v.options != null && v.options!.isNotEmpty) {
    await tocar(t, find.byKey(ValueKey('opcion-${v.options!.firstWhere((o) => o.correct).id}')));
  } else {
    for (final ch in formatEs(v.answer!.value).split('')) {
      await t.tap(find.byKey(ValueKey('tecla-$ch')));
      await t.pump();
    }
    if (!v.answer!.unitFixed && v.answer!.unitChoices.length > 1) await tocar(t, find.byKey(ValueKey('unidad-${v.answer!.unit}')));
  }
  await tocar(t, find.byKey(const ValueKey('prueba-siguiente')));
}

void main() {
  setUpAll(cargarContenidoDePrueba);

  testWidgets('onboarding-account · Continuar desactivado sin selección: «Continuar» sigue desactivado en cada paso sin opción elegida', (t) async {
    final a = Arnes(usuario: const EstadoUsuario(deviceId: 'disp-prueba'));
    await a.montar(t, ruta: Rutas.altaSector);
    expect(find.text('Paso 1 de 4'), findsOneWidget);
    expect(botonContinuar(t).onPressed, isNull);
    await tocar(t, find.byKey(const ValueKey('sector-enfermeria')));
    expect(botonContinuar(t).onPressed, isNotNull);
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));

    expect(a.ubicacion.ruta, Rutas.altaNivel);
    expect(botonContinuar(t).onPressed, isNull);
    await tocar(t, find.byKey(const ValueKey('nivel-afianzar')));
    expect(botonContinuar(t).onPressed, isNotNull);
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));

    expect(a.ubicacion.ruta, Rutas.altaMeta);
    expect(botonContinuar(t).onPressed, isNull);
    await tocar(t, find.byKey(const ValueKey('meta-semanal')));
    expect(botonContinuar(t).onPressed, isNotNull);
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    expect(a.contenedor.read(usuarioProvider).value!.perfil!.goal!.kind, GoalKind.weekly);
    expect(a.ubicacion.ruta, Rutas.altaAviso);
  });

  testWidgets('onboarding-account · Elección de sector: al elegir «Veterinaria» se propone su itinerario más habitual', (t) async {
    final a = Arnes(usuario: const EstadoUsuario(deviceId: 'disp-prueba'));
    await a.montar(t, ruta: Rutas.altaSector);
    await tocar(t, find.byKey(const ValueKey('sector-veterinaria')));
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    final perfil = a.contenedor.read(usuarioProvider).value!.perfil!;
    expect(perfil.sectorId, 'veterinaria');
    expect(perfil.itineraryId, 'it-vet-pequenos');
    expect(t.widget<Text>(find.byKey(const ValueKey('itinerario-propuesto'))).data, 'Anestesia y clínica de pequeños animales');
  });

  testWidgets('en tablet el paso de sector muestra la vista previa del itinerario propuesto (T08)', (t) async {
    final a = Arnes(usuario: const EstadoUsuario(deviceId: 'disp-prueba'));
    await a.montar(t, ruta: Rutas.altaSector, tamano: const Size(1194, 834));
    expect(find.text('Itinerario propuesto'.toUpperCase()), findsNothing);
    await tocar(t, find.byKey(const ValueKey('sector-medicina')));
    expect(find.text('ITINERARIO PROPUESTO'), findsOneWidget);
    expect(find.text('Fundamentos'), findsWidgets);
    expect(find.text('Conversión de unidades'), findsOneWidget);
  });

  testWidgets('formative-boundary · Aceptación obligatoria en el alta: no se continúa hasta marcar «Lo entiendo»', (t) async {
    final a = Arnes(usuario: usuarioEnAlta());
    await a.montar(t, ruta: Rutas.altaAviso);
    expect(find.text(textoAvisoFormativo), findsOneWidget);
    expect(find.text('Paso 4 de 4'), findsOneWidget);
    expect(botonContinuar(t).onPressed, isNull);
    expect(t.widget<TextButton>(find.byKey(const ValueKey('saltar-prueba'))).onPressed, isNull);
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    expect(a.ubicacion.ruta, Rutas.altaAviso, reason: 'sin marcar no avanza');

    await tocar(t, find.byKey(const ValueKey('lo-entiendo')));
    expect(botonContinuar(t).onPressed, isNotNull);
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    expect(a.ubicacion.ruta, Rutas.altaPrueba);
    expect(a.contenedor.read(usuarioProvider).value!.perfil!.disclaimerAcceptedAt, isNotNull);
  });

  testWidgets(
      'onboarding-account · Alta sin conexión, Primera lección sin cuenta y Sin permisos al arrancar: '
      'sin red se completa el alta y se entra a la primera unidad de Fundamentos sin correo ni permisos', (t) async {
    final a = Arnes(usuario: const EstadoUsuario(deviceId: 'disp-prueba'), conexion: false);
    await a.montar(t, ruta: Rutas.inicio);
    expect(a.ubicacion.ruta, Rutas.bienvenida);
    expect(find.text('Entrenador formativo. No es una calculadora clínica.'), findsOneWidget);
    await tocar(t, find.text('Empezar'));
    // Anestesia: su itinerario no viene incluido en la app.
    await tocar(t, find.byKey(const ValueKey('sector-anestesia')));
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    await tocar(t, find.byKey(const ValueKey('nivel-cero')));
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    await tocar(t, find.byKey(const ValueKey('meta-5')));
    await tocar(t, find.byKey(const ValueKey('alta-continuar')));
    await tocar(t, find.byKey(const ValueKey('lo-entiendo')));
    await tocar(t, find.byKey(const ValueKey('saltar-prueba')));

    expect(a.ubicacion.ruta, Rutas.altaDescarga);
    expect(find.textContaining('Sin conexión: empiezas con Fundamentos'), findsOneWidget);
    await tocar(t, find.byKey(const ValueKey('empezar-primera')));

    final u = a.contenedor.read(usuarioProvider).value!;
    expect(u.altaCompletada, isTrue);
    expect(u.conCuenta, isFalse);
    expect(u.perfil!.itineraryId, 'it-anestesia');
    expect(a.ubicacion.ruta, Rutas.leccion('u-f-1-l1'), reason: 'primera lección de Fundamentos, incluido en la app');
    // Sin correo ni contraseña: ninguna petición de acceso y ningún campo de correo.
    expect(a.peticiones.where((r) => r.url.path.startsWith('/v1/auth')), isEmpty);
    expect(find.byKey(const ValueKey('campo-correo')), findsNothing);
    // Ningún permiso del sistema antes de la primera lección.
    expect(a.permisos.solicitudes, 0);
  });

  testWidgets('onboarding-account · Omitir la prueba: la ruta empieza en la primera unidad sin convalidaciones', (t) async {
    final a = Arnes(usuario: usuarioEnAlta());
    await a.montar(t, ruta: Rutas.altaAviso);
    await tocar(t, find.byKey(const ValueKey('lo-entiendo')));
    await tocar(t, find.byKey(const ValueKey('saltar-prueba')));
    await tocar(t, find.byKey(const ValueKey('empezar-primera')));
    expect(a.ubicacion.ruta, Rutas.leccion('u-f-1-l1'));
    final p = a.contenedor.read(proyeccionProvider)!;
    expect(p.infoUnidades.values.where((i) => i.convalidada), isEmpty);
    expect(a.contenedor.read(aprendizajeProvider).value!.sesiones.where((s) => s.mode == SessionMode.placement), isEmpty);
  });

  testWidgets('onboarding-account · Unidades convalidadas: acertar las tres primeras unidades las convalida y propone empezar en la cuarta', (t) async {
    final a = Arnes(usuario: usuarioEnAlta(nivel: 'cero'));
    await a.montar(t, ruta: Rutas.altaPrueba);
    final unidades = a.contenido.fundamentos!.units;
    final primeras = unidades.take(3).map((u) => u.id).toSet();
    var vueltas = 0;
    while (a.ubicacion.ruta == Rutas.altaPrueba && vueltas++ < 14) {
      // Sin corrección: no aparece ningún veredicto durante la prueba.
      expect(find.text('Correcto'), findsNothing);
      expect(find.text('Incorrecto'), findsNothing);
      final unidad = pruebaGuardada(a).unidadIdActual!;
      await responderPrueba(t, a, bien: primeras.contains(unidad));
    }
    expect(a.ubicacion.ruta, Rutas.altaResultado);
    for (final u in unidades.take(3)) {
      expect(find.descendant(of: find.byKey(ValueKey('resultado-${u.id}')), matching: find.text('Convalidada')), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(ValueKey('resultado-${unidades[3].id}')), matching: find.text('Punto de entrada')), findsOneWidget);
    expect(find.text('Empiezas en ${unidades[3].name}'), findsOneWidget);

    await tocar(t, find.byKey(const ValueKey('empezar-aqui')));
    final s = a.contenedor.read(aprendizajeProvider).value!.sesiones.single;
    expect(s.mode, SessionMode.placement);
    expect(s.summary!.convalidatedUnitIds, unidades.take(3).map((u) => u.id).toList());
    expect(s.summary!.entryUnitId, unidades[3].id);
    expect(a.contenedor.read(usuarioProvider).value!.pruebaEnCurso, isNull);
    final p = a.contenedor.read(proyeccionProvider)!;
    for (final u in unidades.take(3)) {
      expect(p.infoUnidad(u.id)!.convalidada, isTrue);
    }
    expect(a.ubicacion.ruta, Rutas.altaDescarga);
    await tocar(t, find.byKey(const ValueKey('empezar-primera')));
    expect(a.ubicacion.ruta, startsWith('/sesion'));
    expect(a.ubicacion.ruta, contains('u-f-4'));
  });

  testWidgets('onboarding-account · Prueba interrumpida: al volver, la prueba se reanuda en la pregunta en la que se dejó', (t) async {
    final a = Arnes(usuario: usuarioEnAlta(nivel: 'afianzar'));
    await a.montar(t, ruta: Rutas.altaPrueba);
    await responderPrueba(t, a, bien: true);
    await responderPrueba(t, a, bien: false);
    await responderPrueba(t, a, bien: true);
    final antes = pruebaGuardada(a);
    expect(antes.numeroPregunta, 4);
    final variante = antes.varianteActual;
    final guardado = a.contenedor.read(usuarioProvider).value!;

    // Se cierra la app y se vuelve a abrir: el estado sale del dispositivo.
    final b = Arnes(usuario: guardado);
    await b.montar(t, ruta: Rutas.inicio);
    expect(b.ubicacion.ruta, Rutas.altaPrueba);
    expect(find.textContaining('4 de '), findsOneWidget);
    expect(pruebaGuardada(b).varianteActual, variante);
    expect(pruebaGuardada(b).itemsRespondidos, 3);
  });

  group('Permiso de notificaciones tras la primera lección', () {
    testWidgets('al activarlo se guarda la hora y se programa el aviso local', (t) async {
      final a = Arnes(permisos: PermisosFalsos());
      await a.montar(t, ruta: Rutas.permisoNotificaciones);
      expect(a.permisos.solicitudes, 0, reason: 'no se pide hasta tocar el botón');
      await tocar(t, find.text('Activar el recordatorio'));
      expect(a.permisos.solicitudes, 1);
      expect(a.contenedor.read(ajustesProvider).recordatorio, '20:30');
      expect(a.notificador.programadas[idNotificacionRepaso]!.cuando, DateTime(2026, 11, 17, 20, 30));
      expect(a.contenedor.read(usuarioProvider).value!.notificacionesOfrecidas, isTrue);
      expect(a.ubicacion.ruta, Rutas.inicio);
    });

    testWidgets('si se deniega, la app lo explica y sigue funcionando', (t) async {
      final a = Arnes(permisos: PermisosFalsos(respuestaNotificaciones: EstadoPermiso.denegado));
      await a.montar(t, ruta: Rutas.permisoNotificaciones);
      await tocar(t, find.text('Activar el recordatorio'));
      expect(find.textContaining('la app funciona igual'), findsOneWidget);
      expect(a.notificador.programadas, isEmpty);
      await tocar(t, find.text('Continuar'));
      expect(a.ubicacion.ruta, Rutas.inicio);
    });
  });

  test('proximaHora pasa al día siguiente si la hora ya ha pasado', () {
    expect(proximaHora('08:00', DateTime(2026, 11, 17, 10)), DateTime(2026, 11, 18, 8));
    expect(proximaHora('20:30', DateTime(2026, 11, 17, 10)), DateTime(2026, 11, 17, 20, 30));
  });

  test('el itinerario propuesto es el habitual del sector', () {
    final c = contenidoPrueba;
    expect(itinerarioPropuesto(c, 'veterinaria'), 'it-vet-pequenos');
    expect(itinerarioPropuesto(c, 'anestesia'), 'it-anestesia');
    expect(itinerarioPropuesto(c, 'enfermeria'), 'it-fundamentos');
    expect(c.global.sectors.whereType<Sector>(), hasLength(7));
  });
}

