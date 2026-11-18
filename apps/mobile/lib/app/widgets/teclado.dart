import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/plataforma/plataforma.dart';
import '../adaptativo.dart';
import '../tema.dart';

/// Entrada numérica del teclado propio (exercise-session, «Teclado numérico
/// propio»): cifras, una sola coma decimal y borrado. No usa el teclado del
/// sistema. Con teclado físico, «.» y «,» escriben la coma e Intro envía.
class EntradaNumerica extends ChangeNotifier {
  EntradaNumerica({this.maxCifras = 9, this.alRechazo});
  final int maxCifras;

  /// Se llama al rechazar una pulsación (segunda coma): señal háptica breve.
  VoidCallback? alRechazo;
  String _texto = '';

  /// Texto tal como se ve, con coma decimal («4,8»).
  String get texto => _texto;
  bool get vacia => _texto.isEmpty;

  /// Pulsa una tecla: '0'…'9', ',' o '⌫'. Devuelve false si se rechaza.
  bool pulsar(String tecla) {
    if (tecla == '⌫') {
      if (_texto.isEmpty) return false;
      _texto = _texto.substring(0, _texto.length - 1);
      notifyListeners();
      return true;
    }
    if (tecla == ',' || tecla == '.') {
      if (_texto.contains(',')) {
        alRechazo?.call();
        return false;
      }
      _texto = '$_texto,';
      notifyListeners();
      return true;
    }
    if (!RegExp(r'^\d$').hasMatch(tecla)) return false;
    if (_texto.replaceAll(',', '').length >= maxCifras) return false;
    _texto += tecla;
    notifyListeners();
    return true;
  }

  void escribir(String texto) {
    _texto = '';
    for (final c in texto.split('')) {
      pulsar(c);
    }
    notifyListeners();
  }

  void limpiar() {
    if (_texto.isEmpty) return;
    _texto = '';
    notifyListeners();
  }
}

/// Teclado numérico propio: 3 columnas, teclas de 56 dp como mínimo y 420 dp
/// de ancho máximo en tablet.
class TecladoNumerico extends StatelessWidget {
  const TecladoNumerico({super.key, required this.entrada, this.senales, this.habilitado = true, this.altoTecla = 56});
  final EntradaNumerica entrada;
  final Senales? senales;
  final bool habilitado;
  final double altoTecla;

  static const teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];

  void _pulsar(String t) {
    final ok = entrada.pulsar(t);
    if (ok) senales?.emitir(Senal.tecla);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    return AnchoMaximo(
      ancho: anchoTeclado,
      child: LayoutBuilder(builder: (context, cs) {
        const sep = 8.0;
        final ancho = (cs.maxWidth - 2 * sep) / 3;
        return Wrap(
          spacing: sep,
          runSpacing: sep,
          children: [
            for (final t in teclas)
              SizedBox(
                width: ancho,
                height: altoTecla,
                child: Semantics(
                  button: true,
                  label: switch (t) { ',' => 'coma', '⌫' => 'borrar', _ => t },
                  excludeSemantics: true,
                  child: Material(
                    color: t == ',' || t == '⌫' ? c.superficie2 : c.superficie,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: t == ',' || t == '⌫' ? Colors.transparent : c.borde),
                    ),
                    child: InkWell(
                      key: ValueKey('tecla-$t'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: habilitado ? () => _pulsar(t) : null,
                      onLongPress: habilitado && t == '⌫' ? entrada.limpiar : null,
                      child: Center(
                        child: t == '⌫'
                            ? Icon(Symbols.backspace, color: c.texto)
                            : Text(t, style: estiloCifra(context, size: t == ',' ? 30 : 24, weight: t == ',' ? FontWeight.w700 : FontWeight.w500)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Atiende el teclado físico (tablet): cifras, «.» o «,» como coma, borrar e
/// Intro para comprobar.
class TecladoFisico extends StatelessWidget {
  const TecladoFisico({super.key, required this.entrada, required this.child, this.alEnviar, this.autofocus = true, this.senales});
  final EntradaNumerica entrada;
  final Widget child;
  final VoidCallback? alEnviar;
  final bool autofocus;
  final Senales? senales;

  @override
  Widget build(BuildContext context) => Focus(
        autofocus: autofocus,
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
            alEnviar?.call();
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.backspace) {
            entrada.pulsar('⌫');
            return KeyEventResult.handled;
          }
          final ch = e.character;
          if (ch != null && RegExp(r'^[0-9.,]$').hasMatch(ch)) {
            if (entrada.pulsar(ch)) senales?.emitir(Senal.tecla);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      );
}

/// Campo de respuesta: cifra en Space Mono alineada a la derecha y unidad como
/// sufijo fijo (niveles 1 a 3) o elegida.
class CampoRespuesta extends StatelessWidget {
  const CampoRespuesta({super.key, required this.entrada, this.unidad, this.estado = EstadoCampo.normal, this.etiqueta = 'Tu respuesta'});
  final EntradaNumerica entrada;
  final String? unidad;
  final EstadoCampo estado;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final (borde, fondo) = switch (estado) {
      EstadoCampo.normal => (c.primario, c.superficie),
      EstadoCampo.correcto => (c.exito, c.exitoTinte),
      EstadoCampo.incorrecto => (c.error, c.errorTinte),
      EstadoCampo.observacion => (c.aviso, c.avisoTinte),
    };
    return ListenableBuilder(
      listenable: entrada,
      builder: (context, _) => Semantics(
        label: etiqueta,
        value: entrada.vacia ? 'vacío' : '${entrada.texto} ${unidad ?? ''}'.trim(),
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16), border: Border.all(color: borde, width: 2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    entrada.vacia ? '0' : entrada.texto,
                    key: const ValueKey('campo-respuesta'),
                    style: estiloCifra(context, size: 36, color: entrada.vacia ? c.borde : c.texto),
                  ),
                ),
              ),
              if (unidad != null && unidad!.isNotEmpty) ...[
                const SizedBox(width: 10),
                Text(unidad!, style: estiloCifra(context, size: 20, weight: FontWeight.w400, color: c.atenuado)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum EstadoCampo { normal, correcto, incorrecto, observacion }
