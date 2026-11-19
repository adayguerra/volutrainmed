import 'package:flutter_test/flutter_test.dart';
import 'package:volutrainmed/core/plataforma/plataforma.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VozSistema v(String nombre, String locale, {String calidad = '', bool red = false}) =>
      VozSistema.deMapa({'name': nombre, 'locale': locale, 'quality': calidad, if (red) 'network_required': '1'});

  group('Elección de la voz de lectura', () {
    test('prefiere la voz de mejor calidad en español de España, no la primera de la lista', () {
      final voces = [
        v('Eddy (Spanish (Spain))', 'es-ES'),
        v('Mónica', 'es-ES', calidad: 'default'),
        v('Paulina', 'es-MX', calidad: 'premium'),
        v('Mónica (Enhanced)', 'es-ES', calidad: 'enhanced'),
        v('Samantha', 'en-US', calidad: 'premium'),
      ];
      expect(elegirVoz(voces)!.nombre, 'Mónica (Enhanced)');
    });

    test('con calidad claramente superior gana aunque no sea de España', () {
      final voces = [v('Mónica', 'es-ES', calidad: 'default'), v('Paulina (Premium)', 'es_MX', calidad: 'premium')];
      expect(elegirVoz(voces)!.nombre, 'Paulina (Premium)');
    });

    test('nunca elige una voz que necesita red: la lectura funciona sin conexión', () {
      final voces = [v('es-es-x-eea-network', 'es-ES', calidad: 'very high', red: true), v('es-es-x-eea-local', 'es-ES', calidad: 'normal')];
      expect(elegirVoz(voces)!.nombre, 'es-es-x-eea-local');
      expect(vocesEnEspanol(voces).map((x) => x.nombre), ['es-es-x-eea-local']);
    });

    test('descarta las voces de novedad, las de otros idiomas y las remotas de Chrome', () {
      final voces = [v('Eddy (Spanish (Spain))', 'es-ES'), v('Google español', 'es-ES'), v('Marisol (Premium)', 'es-ES'), v('Mónica', 'es-ES'), v('Google UK English Female', 'en-GB')];
      final l = vocesEnEspanol(voces);
      expect(l.first.nombre, 'Marisol (Premium)');
      expect(l.map((x) => x.nombre), isNot(contains('Google español')));
      expect(l.map((x) => x.nombre), ['Marisol (Premium)', 'Mónica']);
      // Si solo hay voces de novedad, se ofrecen: mejor una voz rara que ninguna.
      expect(vocesEnEspanol([v('Eddy (Spanish (Spain))', 'es-ES')]).single.etiqueta, 'Eddy');
    });

    test('respeta la voz elegida por el usuario mientras siga instalada', () {
      final voces = [v('Mónica (Enhanced)', 'es-ES', calidad: 'enhanced'), v('Jorge', 'es-ES', calidad: 'default')];
      expect(elegirVoz(voces, preferida: 'Jorge')!.nombre, 'Jorge');
      expect(elegirVoz(voces, preferida: 'Desinstalada')!.nombre, 'Mónica (Enhanced)');
    });

    test('sin voces en español no elige ninguna', () {
      expect(elegirVoz([v('Samantha', 'en-US')]), isNull);
    });
  });

  group('Ritmo de la lectura', () {
    test('el caso y la pregunta se leen como frases separadas, sin partir los decimales', () {
      expect(frasesParaLeer('Paciente simulado de 70 kg. Pauta: 0,5 mg/kg.  ¿Cuántos mg son?'), ['Paciente simulado de 70 kg.', 'Pauta:', '0,5 mg/kg.', '¿Cuántos mg son?']);
      expect(frasesParaLeer('Tienes 1.000 mg'), ['Tienes 1.000 mg']);
      expect(frasesParaLeer('   '), isEmpty);
    });

    test('en el navegador la velocidad normal es 1,0 y en iOS y Android 0,5', () {
      expect(SintetizadorSistema(esWeb: true).velocidadMotor(1.0), 1.0);
      expect(SintetizadorSistema(esWeb: true).velocidadMotor(1.5), 1.5);
      expect(SintetizadorSistema(esWeb: false).velocidadMotor(1.0), 0.5);
      expect(SintetizadorSistema(esWeb: false).velocidadMotor(1.5), 0.75);
    });
  });
}
