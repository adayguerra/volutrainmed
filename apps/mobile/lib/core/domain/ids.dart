import 'package:uuid/uuid.dart';

/// Identificadores UUID versión 7 creados en el dispositivo (diseño D5).
const _uuid = Uuid();

String nuevoId() => _uuid.v7();

/// Compara versiones semánticas «1.2.3». Devuelve <0, 0 o >0.
int compararVersiones(String a, String b) {
  List<int> parse(String v) => v.split('.').map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Versión de esta app, usada para `minAppVersion` de paquetes y tipos.
const appVersion = '1.0.0';
