import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/contenido/repositorio_contenido.dart';
import 'package:volutrainmed/core/domain/content_models.dart';
import 'package:volutrainmed/core/domain/learning_models.dart';
import 'package:volutrainmed/core/plataforma/falsos.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';
import 'package:volutrainmed/features/ads/domain/ad_selector.dart';
import 'package:volutrainmed/features/progress/domain/projections.dart';
import 'package:volutrainmed/features/session/domain/motor_sesion.dart';
import 'package:volutrainmed/features/voice/domain/normalizador.dart';
import 'package:volutrainmed/features/voice/domain/sesion_manos_libres.dart';
import 'package:volutrainmed/features/voice/domain/turno.dart';

import '../helpers/arnes.dart';

/// Pruebas de la máquina de estados del turno de manos libres.

StatementSegment _t(String s) => StatementSegment.text(s);
StatementSegment _q(String v, String u) => StatementSegment.qty(v, u);

/// Caso del spec: noradrenalina a 0,1 µg/kg/min, 80 kg, 100 µg/ml → 4,8 ml/h.
Variant noradrenalina([String id = 'v-nora-1']) => Variant(
      id: id,
      templateId: 'tpl-nora',
      questionId: null,
      templateVersion: 1,
      level: 2,
      exerciseTypeId: 'T1',
      exerciseTypeVersion: 1,
      skillId: 'H9',
      sectorId: 'anestesia',
      statement: [_t('Paciente simulado de '), _q('80', 'kg'), _t('. Noradrenalina a '), _q('0.1', 'µg/kg/min'), _t('. Dilución de '), _q('100', 'µg/ml'), _t('.')],
      question: '¿A cuántos mililitros por hora?',
      tts: '',
      targetTimeS: 45,
      answer: const AnswerSpec(value: '4.8', unit: 'ml/h', unitChoices: ['ml/h']),
      predictedErrors: const [PredictedError(value: '0.08', unit: 'ml/h', code: 'E1', message: 'Falta pasar de minutos a horas', deviationStep: 3)],
      steps: const [
        ExplanationStep(n: 1, text: 'Dosis por minuto', operation: '0,1 µg/kg/min × 80 kg', result: Quantity('8', 'µg/min'), cancelled: ['kg']),
        ExplanationStep(n: 2, text: 'Dosis por hora', operation: '8 µg/min × 60 min/h', result: Quantity('480', 'µg/h'), cancelled: ['min']),
        ExplanationStep(n: 3, text: 'Ritmo', operation: '480 µg/h ÷ 100 µg/ml', result: Quantity('4.8', 'ml/h'), cancelled: ['µg']),
      ],
      plausibility: '4,8 ml/h en una bomba de perfusión. Tiene sentido.',
    );

/// Dosis en mg con la unidad a elegir (niveles 4 y 5).
Variant dosisAElegir({String valor = '0.5', String unidad = 'mg', List<String> opciones = const ['mg', 'µg']}) => Variant(
      id: 'v-dosis-$valor-$unidad',
      templateId: 'tpl-dosis',
      questionId: null,
      templateVersion: 1,
      level: 4,
      exerciseTypeId: 'T1',
      exerciseTypeVersion: 1,
      skillId: 'H3',
      sectorId: 'anestesia',
      statement: [_t('Paciente simulado de '), _q('25', 'kg'), _t('. Pauta: '), _q('0.02', 'mg/kg'), _t('.')],
      question: '¿Qué dosis administras?',
      tts: '',
      targetTimeS: 30,
      answer: AnswerSpec(value: valor, unit: unidad, unitFixed: false, unitChoices: opciones),
    );

void main() {
  late ContenidoCargado c;
  setUpAll(() async => c = await cargarContenidoDePrueba());

  ContenidoCargado vacio() => ContenidoCargado(global: c.global, itinerarios: const {}, revocaciones: const Revocaciones());

  ({MotorSesion m, List<Attempt> intentos, void Function(int) avanzar}) motor(List<Variant> vs, {bool sinAnuncios = true, ContenidoCargado? contenido}) {
    var ms = 0;
    final intentos = <Attempt>[];
    final m = crearMotorManosLibres(
      contenido: contenido ?? vacio(),
      que: ContenidoManosLibres.habilidad,
      deviceId: 'd',
      relojMs: () => ms,
      ahora: () => ahoraPrueba.add(Duration(milliseconds: ms)),
      variantes: vs,
      sinAnuncios: sinAnuncios,
      azar: Random(2),
      alRegistrar: intentos.add,
    );
    return (m: m, intentos: intentos, avanzar: (d) => ms += d);
  }

  TurnoManosLibres turno(
    MotorSesion m, {
    Sintetizador? sint,
    MotorDeVoz? voz,
    String confirmacion = 'siempre',
    Map<String, String> sinonimos = const {},
    EsperarFn? esperar,
    AnuncioResuelto? Function()? cuna,
    List<Senal>? senales,
  }) =>
      TurnoManosLibres(
        motor: m,
        sintetizador: sint ?? SintetizadorFalso(),
        motorVoz: voz ?? MotorDeVozGuionado(),
        confirmacion: confirmacion,
        sinonimos: sinonimos,
        lexico: c.global.voiceLexicon,
        esperar: esperar ?? (_) async {},
        elegirCuna: cuna,
        alSenal: senales?.add,
      );

  VozTexto dice(String s, {double confianza = 0.7, List<String> alternativas = const []}) => VozTexto(s, confianza: confianza, alternativas: alternativas, ms: 420);

  const enunciadoNora = 'Paciente simulado de ochenta kilos. Noradrenalina a cero coma uno microgramos por kilo y minuto. '
      'Dilución de cien microgramos por mililitro. ¿A cuántos mililitros por hora?';

  group('hands-free-voice · turno conversacional', () {
    test('hands-free-voice · Turno completo: lee el caso, confirma «Cuatro coma ocho mililitros por hora. ¿Correcto?» y tras «sí» dice «Correcto» y pasa al siguiente', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m);
      await t.iniciar();
      expect(t.dichos.first, enunciadoNora);
      expect(t.estado, EstadoTurno.escuchando);
      await t.oir(dice('cuatro coma ocho'));
      expect(t.dichos.last, 'Cuatro coma ocho mililitros por hora. ¿Correcto?');
      expect(t.estado, EstadoTurno.confirmando);
      await t.oir(dice('sí'));
      expect(t.dichos, contains('Correcto'));
      expect(s.intentos.single.verdict, Verdict.correct);
      expect(s.m.actual!.variante.id, 'b', reason: 'pasa al ejercicio siguiente');
      expect(t.estado, EstadoTurno.escuchando);
      expect(t.dichos.last, enunciadoNora);
    });

    test('hands-free-voice · La pregunta va al final: primero los datos y en último lugar lo que se pregunta', () {
      final vs = c.fundamentos!.variants.where((v) => v.exerciseTypeId == 'T1' && v.question.isNotEmpty).take(40).toList();
      expect(vs, isNotEmpty);
      for (final v in vs) {
        final texto = textoEnunciadoHablado(v);
        final pregunta = speakText(v.question);
        expect(texto.endsWith(pregunta), isTrue, reason: texto);
        expect(texto.indexOf(pregunta), texto.length - pregunta.length);
        expect(texto.substring(0, texto.length - pregunta.length).trim(), isNotEmpty, reason: 'los datos van antes');
      }
      expect(textoEnunciadoHablado(noradrenalina()), enunciadoNora);
    });

    test('hands-free-voice · Rechazo de lo entendido: tras «no» vuelve a escuchar sin corregir la respuesta', () async {
      final s = motor([noradrenalina()]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(dice('catorce coma ocho'));
      expect(t.dichos.last, 'Catorce coma ocho mililitros por hora. ¿Correcto?');
      await t.oir(dice('no'));
      expect(t.estado, EstadoTurno.escuchando);
      expect(s.intentos, isEmpty);
      expect(s.m.resultados, isEmpty);
      expect(s.m.fase, FaseSesion.ejercicio);
    });

    test('hands-free-voice · Cifras que se confunden: al entender «sesenta» la confirmación deletrea «Sesenta: seis, cero. ¿Correcto?»', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(dice('sesenta'));
      expect(t.dichos.last, 'Sesenta: seis, cero. ¿Correcto?');
    });

    test('hands-free-voice · Confirmación abreviada: con «solo si hay duda» y confianza alta repite la cifra, espera 1,5 s un «no» y corrige', () async {
      final esperas = <Duration>[];
      var espera = Completer<void>();
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m, confirmacion: 'siHayDuda', esperar: (d) {
        esperas.add(d);
        return espera.future;
      });
      await t.iniciar();
      final f = t.oir(dice('cuatro coma ocho', confianza: 0.95));
      await pumpEventQueue();
      expect(t.dichos.last, 'Cuatro coma ocho mililitros por hora.');
      expect(esperas.single, const Duration(milliseconds: 1500));
      expect(s.intentos, isEmpty, reason: 'durante la espera aún no corrige');
      espera.complete();
      await f;
      expect(s.intentos.single.verdict, Verdict.correct);

      // Un «no» durante la espera evita la corrección.
      espera = Completer<void>();
      final g = t.oir(dice('catorce coma ocho', confianza: 0.95));
      await pumpEventQueue();
      await t.oir(dice('no'));
      espera.complete();
      await g;
      expect(s.intentos, hasLength(1));
      expect(t.estado, EstadoTurno.escuchando);
    });

    test('hands-free-voice · Unidad fija: el usuario dice solo «cuatro coma ocho» y la confirmación añade «mililitros por hora»', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      expect(t.unidadFija, 'ml/h');
      await t.oir(dice('cuatro coma ocho'));
      expect(t.entendido!.unidad, 'ml/h');
      expect(t.cifraEntendida, '4,8 ml/h');
      expect(t.dichos.last, startsWith('Cuatro coma ocho mililitros por hora'));
    });

    test('hands-free-voice · Miligramos o microgramos: si el reconocimiento duda entre ambas pregunta «¿Miligramos o microgramos?»', () async {
      final t = turno(motor([dosisAElegir()]).m);
      await t.iniciar();
      expect(t.unidadFija, isNull);
      await t.oir(dice('cero coma cinco miligramos', alternativas: ['cero coma cinco microgramos']));
      expect(t.dichos.last, '¿Miligramos o microgramos?');
      expect(t.estado, EstadoTurno.preguntando);
      await t.oir(dice('microgramos'));
      expect(t.entendido!.unidad, 'µg');
      expect(t.dichos.last, 'Cero coma cinco microgramos. ¿Correcto?');
    });

    test('hands-free-voice · Sinónimo de sector: con «gammas» activado, «doscientas gammas» se interpreta como 200 µg', () async {
      final t = turno(motor([dosisAElegir(valor: '200', unidad: 'µg', opciones: ['µg', 'mg'])]).m, sinonimos: const {'gammas': 'µg'});
      await t.iniciar();
      await t.oir(dice('doscientas gammas'));
      expect(t.entendido!.valor, '200');
      expect(t.entendido!.unidad, 'µg');
      expect(t.cifraEntendida, '200 µg');
    });
  });

  group('hands-free-voice · comandos', () {
    test('hands-free-voice · Repite: durante la escucha vuelve a leer el enunciado y abre de nuevo la escucha', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(dice('repite'));
      expect(t.dichos.where((d) => d == enunciadoNora), hasLength(2));
      expect(t.estado, EstadoTurno.escuchando);
    });

    test('hands-free-voice · Pausa y continúa: la sesión se detiene y se reanuda en el mismo punto', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m);
      await t.iniciar();
      s.avanzar(3000);
      await t.oir(dice('pausa'));
      expect(t.estado, EstadoTurno.pausa);
      expect(s.m.pausado, isTrue);
      s.avanzar(60000);
      await t.oir(dice('continúa'));
      expect(t.estado, EstadoTurno.escuchando);
      expect(s.m.actual!.variante.id, 'a', reason: 'mismo punto');
      s.avanzar(2000);
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      expect(s.intentos.single.responseMs, 5000, reason: 'la pausa no cuenta');
    });

    test('hands-free-voice · No lo sé: dice la respuesta correcta y registra el ejercicio como no acertado', () async {
      final s = motor([noradrenalina()]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(dice('no lo sé'));
      expect(t.dichos.last, 'La respuesta es cuatro coma ocho mililitros por hora.');
      expect(s.intentos.single.verdict, Verdict.dontKnow);
      expect(s.intentos.single.correct, isFalse);
    });

    test('hands-free-voice · Salir: pide confirmación antes de cerrar la sesión', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(dice('salir'));
      expect(t.estado, EstadoTurno.confirmandoSalida);
      expect(t.dichos.last, textoSalir);
      expect(t.resumen, isNull, reason: 'aún no se ha cerrado');
      await t.oir(dice('no'));
      expect(t.estado, EstadoTurno.escuchando);
      await t.oir(dice('salir'));
      await t.oir(dice('sí'));
      expect(t.estado, EstadoTurno.terminada);
      expect(t.resumen!.registro.completed, isFalse);
    });

    test('«explica» lee los pasos de la resolución', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('no'));
      await t.oir(dice('no lo sé'));
      await t.oir(dice('explica'));
      expect(t.dichos.last, contains('Paso uno: Dosis por minuto'));
      expect(t.dichos.last, contains('cuatro coma ocho mililitros por hora'));
    });
  });

  group('hands-free-voice · errores de reconocimiento', () {
    test('hands-free-voice · Tercer fallo: a la tercera dice «Te abro el teclado» y muestra el teclado numérico', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(dice('patata'));
      expect(t.dichos.last, textoRepetir);
      await t.oir(const VozNoEntendida());
      expect(t.dichos.last, textoCifraACifra);
      expect(t.cifraACifra, isTrue, reason: 'el segundo fallo pasa al dictado cifra a cifra');
      await t.oir(dice('mmm'));
      expect(t.dichos.last, textoAbroTeclado);
      expect(t.estado, EstadoTurno.teclado);
      expect(t.alTeclado, 1);
    });

    test('hands-free-voice · El fallo de reconocimiento no penaliza: tras repetir y acertar cuenta como acierto al primer intento', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(const VozNoEntendida());
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      final a = s.intentos.single;
      expect(a.attemptNumber, 1);
      expect(a.verdict, Verdict.correct);
      expect(a.points, puntosPorAcierto);
      expect(a.voiceMetrics!.recognitionFailures, 1);
    });

    test('hands-free-voice · Silencio: tras 6 s sin voz dice «No te he oído. ¿Lo repito?»', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(const VozSilencio());
      expect(t.dichos.last, textoNoTeHeOido);
      await t.oir(dice('sí'));
      expect(t.dichos.last, enunciadoNora, reason: 'un «sí» vuelve a leer el enunciado');
      expect(t.fallosReconocimiento, 0, reason: 'el silencio no es un fallo');
    });

    test('hands-free-voice · Entorno ruidoso: muestra y dice «Hay mucho ruido. Acerca el micrófono o usa los botones»', () async {
      final t = turno(motor([noradrenalina()]).m);
      await t.iniciar();
      await t.oir(const VozRuido());
      expect(t.aviso, textoRuido);
      expect(t.dichos.last, textoRuido);
      expect(textoRuido, 'Hay mucho ruido. Acerca el micrófono o usa los botones');
    });

    test('hands-free-voice · Botón de los auriculares: pausa o reanuda la sesión', () async {
      final s = motor([noradrenalina()]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(const VozBotonAuriculares());
      expect(t.estado, EstadoTurno.pausa);
      expect(s.m.pausado, isTrue);
      await t.oir(const VozBotonAuriculares());
      expect(t.estado, EstadoTurno.escuchando);
      expect(s.m.pausado, isFalse);
    });
  });

  group('hands-free-voice · datos, sin conexión y accesibilidad', () {
    test('hands-free-voice · Datos guardados de un intento por voz: valor 4,8, unidad y métricas, sin audio ni texto', () async {
      final s = motor([noradrenalina()]);
      final t = turno(s.m);
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      final a = s.intentos.single;
      expect(a.answerValue, '4.8');
      expect(a.answerUnit, 'ml/h');
      expect(a.inputMode, InputMode.voice);
      expect(a.voiceMetrics, isNotNull);
      expect(a.voiceMetrics!.asrMs, 420);
      expect(a.answerPayload, isNull);
      final json = jsonEncode(a.toJson());
      expect(json.contains('cuatro'), isFalse, reason: 'no se guarda texto transcrito');
      expect(a.toJson().keys, isNot(contains('audio')));
    });

    test('hands-free-voice · Sesión en modo avión: diez ejercicios de principio a fin con lectura, reconocimiento y corrección en el dispositivo', () async {
      final vs = c.fundamentos!.variants.where((v) => v.exerciseTypeId == 'T1' && v.level <= 2).take(10).toList();
      final guion = <EventoVoz>[
        for (final v in vs) ...[VozTexto(numberToWords(v.answer!.value), confianza: 0.6), const VozTexto('sí')],
      ];
      final voz = MotorDeVozGuionado(guion);
      final sint = SintetizadorFalso();
      final s = motor(vs, contenido: c);
      ResumenManosLibres? resumen;
      final t2 = TurnoManosLibres(motor: s.m, sintetizador: sint, motorVoz: voz, lexico: c.global.voiceLexicon, esperar: (_) async {}, alTerminar: (r) => resumen = r);
      await t2.iniciar();
      while (await t2.escucharUnaVez()) {}
      expect(s.m.fase, FaseSesion.terminada);
      expect(resumen!.ejercicios, 10);
      expect(resumen!.aciertos, 10);
      expect(resumen!.entendidasALaPrimera, 10);
      expect(s.intentos.every((a) => a.correct && a.inputMode == InputMode.voice), isTrue);
      expect(sint.dichos.where((d) => d == 'Correcto'), hasLength(10));
      expect(resumen!.registro.mode, SessionMode.handsfree);
    });

    test('hands-free-voice · Lección con un tipo no compatible: solo presenta los compatibles e indica cuántos quedan para el modo táctil', () async {
      final it = c.fundamentos!;
      final t1 = it.variants.firstWhere((v) => v.exerciseTypeId == 'T1');
      const t3 = Variant(
        id: 'v-orden',
        templateId: null,
        questionId: 'q-orden',
        templateVersion: 1,
        level: 2,
        exerciseTypeId: 'T3',
        exerciseTypeVersion: 1,
        skillId: 'H9',
        sectorId: 'comun',
        statement: [StatementSegment.text('Ordena los pasos.')],
        question: '¿En qué orden?',
        tts: '',
        targetTimeS: 40,
        orderItems: [OrderItem(id: 'a', text: 'Dosis por peso'), OrderItem(id: 'b', text: 'Por 60')],
        validOrders: [
          ['a', 'b'],
        ],
      );
      final leccion = Lesson(id: 'l-mixta', unitId: it.units.first.id, order: 1, kind: LessonKind.free, title: 'Práctica libre', estimatedMinutes: 5, slots: [
        LessonSlot(position: 1, templateId: t1.templateId, difficulty: t1.level, skillId: t1.skillId),
        const LessonSlot(position: 2, questionId: 'q-orden', difficulty: 2, skillId: 'H9'),
        LessonSlot(position: 3, templateId: t1.templateId, difficulty: t1.level, skillId: t1.skillId),
      ]);
      final it2 = ItineraryPackage(
        contentVersion: it.contentVersion,
        minAppVersion: it.minAppVersion,
        itinerary: it.itinerary,
        units: it.units,
        lessons: [leccion],
        templates: it.templates,
        variants: [...it.variants, t3],
        placement: const [],
      );
      final c2 = ContenidoCargado(global: c.global, itinerarios: {it2.itinerary.id: it2}, revocaciones: const Revocaciones());
      final m = crearMotorManosLibres(contenido: c2, que: ContenidoManosLibres.leccion, deviceId: 'd', relojMs: () => 0, ahora: () => ahoraPrueba, leccion: leccion, azar: Random(1));
      expect(m.excluidosPorVoz, 1);
      expect(m.total, 2);
      final t = turno(m);
      await t.iniciar();
      expect(t.dichos.first, 'Un ejercicio queda para el modo táctil.');
      expect(m.actual!.bloque, 'numeric_unit');
    });

    test('hands-free-voice · Sin oír: todo lo dicho aparece escrito y acierto y fallo tienen patrones hápticos distintos', () async {
      final senales = <Senal>[];
      final s = motor([noradrenalina('a'), noradrenalina('b')]);
      final t = turno(s.m, senales: senales);
      final escrito = <String>[];
      t.addListener(() => escrito.add(t.textoPantalla));
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      await t.oir(dice('cero coma cero ocho'));
      await t.oir(dice('sí'));
      expect(t.textoPantalla, 'Incorrecto. Era cuatro coma ocho mililitros por hora. Falta pasar de minutos a horas.');
      for (final d in t.dichos) {
        expect(escrito, contains(d), reason: 'cada frase dicha se ve en pantalla');
      }
      expect(senales, containsAllInOrder([Senal.acierto, Senal.fallo]));
      expect(Senal.acierto, isNot(Senal.fallo));
    });

    test('hands-free-voice · Sin hablar: responde con el teclado y avanza con los botones', () async {
      final it = c.fundamentos!;
      final opcion = it.variants.firstWhere((v) => v.exerciseTypeId == 'T2');
      final s = motor([noradrenalina('a'), opcion]);
      final t = turno(s.m, voz: const MotorDeVozPendiente());
      await t.iniciar();
      expect(await t.escucharUnaVez(), isFalse, reason: 'no hace falta hablar');
      t.abrirTeclado();
      expect(t.estado, EstadoTurno.teclado);
      await t.responderTeclado('4,8');
      expect(s.intentos.single.correct, isTrue);
      expect(s.m.actual!.variante.id, opcion.id);
      final mala = opcion.options!.firstWhere((o) => !o.correct);
      await t.responderOpcionBoton(mala.id);
      expect(t.estado, EstadoTurno.veredicto);
      await t.siguiente();
      expect(t.estado, EstadoTurno.terminada);
      expect(s.intentos, hasLength(2));
    });
  });

  group('house-ads · cuña hablada', () {
    AnuncioResuelto cunaDe(String id) {
      final sel = SelectorAnuncios(campanas: c.global.campaigns, params: c.global.adParams);
      final a = c.global.campaigns.expand((x) => x.creatives).firstWhere((x) => x.id == id);
      return sel.resolver(a, ContextoAnuncio(ahora: ahoraPrueba, impresiones: ContadorImpresiones(), modoVoz: true));
    }

    test('house-ads · Cuña tras el veredicto: tras el veredicto dice una cuña de 4 s como máximo y pasa a leer el siguiente', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')], sinAnuncios: false);
      final cuna = cunaDe('PA-04');
      final t = turno(s.m, cuna: () => cuna);
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      final i = t.dichos.indexOf('Correcto');
      expect(t.dichos[i + 1], cuna.cuna);
      expect(t.dichos[i + 2], enunciadoNora, reason: 'después lee el ejercicio siguiente');
      // A unos tres palabras por segundo, cada cuña cabe en 4 s.
      for (final a in c.global.campaigns.expand((x) => x.creatives).where((a) => a.voiceSpot != null)) {
        expect(a.voiceSpot!.split(' ').length, lessThanOrEqualTo(12), reason: a.id);
      }
      expect(s.m.tiempoAnunciosMs, 0, reason: 'el tiempo de la cuña no es práctica medida');
    });

    test('house-ads · Saltar la cuña: «siguiente» la interrumpe y empieza la lectura del ejercicio siguiente', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')], sinAnuncios: false);
      final cuna = cunaDe('PA-01');
      final sint = _SintetizadorBloqueante(cuna.cuna!);
      final t = turno(s.m, sint: sint, cuna: () => cuna);
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      final f = t.oir(dice('sí'));
      await pumpEventQueue();
      expect(t.estado, EstadoTurno.cuna);
      await t.oir(dice('siguiente'));
      expect(sint.paradas, 1);
      expect(t.estado, EstadoTurno.escuchando);
      expect(s.m.actual!.variante.id, 'b');
      expect(t.dichos.last, enunciadoNora);
      sint.soltar();
      await f;
      expect(s.m.actual!.variante.id, 'b', reason: 'no se salta dos veces');
    });

    test('house-ads · Interés sin tocar la pantalla: «más información» durante la cuña lleva el anuncio al resumen final', () async {
      final s = motor([noradrenalina('a'), noradrenalina('b')], sinAnuncios: false);
      final cuna = cunaDe('PA-03');
      final sint = _SintetizadorBloqueante(cuna.cuna!);
      final t = turno(s.m, sint: sint, cuna: () => cuna);
      await t.iniciar();
      await t.oir(dice('cuatro coma ocho'));
      final f = t.oir(dice('sí'));
      await pumpEventQueue();
      await t.oir(dice('más información'));
      expect(t.estado, EstadoTurno.cuna, reason: 'la sesión continúa');
      sint.soltar();
      await f;
      expect(t.estado, EstadoTurno.escuchando);
      await t.oir(dice('cuatro coma ocho'));
      await t.oir(dice('sí'));
      expect(t.estado, EstadoTurno.terminada);
      expect(t.resumen!.anuncio!.id, 'PA-03');
      expect(t.resumen!.anuncio!.accion, isNotEmpty);
    });
  });

  test('gamification-progress · Primera sesión manos libres: al completarla obtiene el logro y lo ve en su perfil', () async {
    final s = motor([noradrenalina('a')]);
    ResumenManosLibres? r;
    final t2 = TurnoManosLibres(motor: s.m, sintetizador: SintetizadorFalso(), motorVoz: MotorDeVozGuionado(), esperar: (_) async {}, alTerminar: (x) => r = x);
    await t2.iniciar();
    await t2.oir(const VozTexto('cuatro coma ocho'));
    await t2.oir(const VozTexto('sí'));
    expect(r!.registro.completed, isTrue);
    expect(r!.registro.mode, SessionMode.handsfree);
    final p = proyectar(attempts: s.intentos, sessions: [r!.registro], achievements: c.global.achievements, now: ahoraPrueba.add(const Duration(minutes: 5)));
    final logro = p.logros.firstWhere((l) => l.logro.condition.metric == 'handsfree_sessions');
    expect(logro.obtenido, isTrue);
    expect(logro.logro.name, 'Manos libres');
  });
}

/// Síntesis que se queda «hablando» con un texto concreto hasta soltarla.
class _SintetizadorBloqueante implements Sintetizador {
  _SintetizadorBloqueante(this.bloquear);
  final String bloquear;
  final dichos = <String>[];
  int paradas = 0;
  Completer<void>? _c;
  @override
  Future<void> decir(String texto, {double velocidad = 1.0}) {
    dichos.add(texto);
    if (texto == bloquear && _c == null) return (_c = Completer<void>()).future;
    return Future.value();
  }

  void soltar() {
    if (_c != null && !_c!.isCompleted) _c!.complete();
  }

  @override
  Future<void> parar() async {
    paradas++;
    soltar();
  }
}
