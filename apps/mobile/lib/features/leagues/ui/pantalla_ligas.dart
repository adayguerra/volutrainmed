import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../app/adaptativo.dart';
import '../../../app/dependencias.dart';
import '../../../app/estado/estado_app.dart';
import '../../../app/router.dart';
import '../../../app/tema.dart';
import '../../../app/widgets/comunes.dart';
import '../../../core/data/api_client.dart';
import '../../progress/domain/projections.dart';
import '../data/repositorio_liga.dart';
import '../domain/league.dart';

/// Pestaña Ligas (M52) con la liga semanal por alias y los logros (M53).
class PantallaLigas extends StatelessWidget {
  const PantallaLigas({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ligas'),
            actions: const [Padding(padding: EdgeInsets.only(right: 12), child: DistintivoSinConexion())],
            bottom: const TabBar(tabs: [Tab(text: 'Liga'), Tab(text: 'Logros')]),
          ),
          body: const TabBarView(children: [PestanaLiga(), PestanaLogros()]),
        ),
      );
}

class PestanaLiga extends ConsumerWidget {
  const PestanaLiga({super.key});

  Future<void> _participar(BuildContext context, WidgetRef ref, bool v, {String? alias}) async {
    final m = ScaffoldMessenger.of(context);
    try {
      await cambiarParticipacion(ref, v, alias: alias);
    } on ApiException catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } on SinConexionException {
      m.showSnackBar(const SnackBar(content: Text('Para cambiar tu participación hace falta conexión')));
    }
  }

  Future<void> _cambiarAlias(BuildContext context, WidgetRef ref, String actual) async {
    final ctrl = TextEditingController(text: actual);
    String? error;
    final alias = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Tu alias en las ligas'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Usa un seudónimo: nunca mostramos tu nombre ni tu correo.'),
            const SizedBox(height: 12),
            TextField(key: const ValueKey('campo-alias'), controller: ctrl, decoration: InputDecoration(labelText: 'Alias', errorText: error)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final e = validarAlias(ctrl.text);
                if (e != null) return set(() => error = e);
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (alias != null && context.mounted) await _participar(context, ref, true, alias: alias);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ligaProvider);
    final ahora = ref.watch(dependenciasProvider).reloj.ahora();
    final alias = ref.watch(usuarioProvider).value?.perfil?.alias ?? '';
    return estado.when(
      loading: () => const Esqueleto(),
      error: (e, _) => Center(child: Text('$e')),
      data: (e) {
        final hijos = <Widget>[];
        if (e.sinCuenta) {
          hijos.addAll([
            Tarjeta(
              tinte: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(textoLigaSinCuenta, style: context.textos.bodyMedium),
                const SizedBox(height: 12),
                FilledButton(onPressed: () => context.push(Rutas.cuenta), child: const Text('Crear mi cuenta')),
              ]),
            ),
          ]);
        } else if (e.clasificacion == null) {
          hijos.add(Text(e.error ?? 'Conéctate para ver tu liga por primera vez.', style: context.textos.bodyMedium));
        } else if (!e.clasificacion!.participating) {
          hijos.addAll([
            Tarjeta(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Symbols.visibility_off, color: context.vtm.atenuado),
                  const SizedBox(width: 12),
                  Expanded(child: Text(textoNoParticipas, key: const ValueKey('no-participas'), style: context.textos.titleMedium)),
                ]),
                const SizedBox(height: 8),
                Text('No apareces en ninguna clasificación. Puedes volver cuando quieras.', style: context.textos.bodyMedium),
                const SizedBox(height: 12),
                FilledButton(key: const ValueKey('volver-a-participar'), onPressed: () => _participar(context, ref, true), child: const Text('Volver a participar')),
              ]),
            ),
          ]);
        } else {
          hijos.addAll(_clasificacion(context, ref, e, e.clasificacion!, ahora, alias));
        }
        if (e.privadas.isNotEmpty) {
          hijos.addAll([const SizedBox(height: 24), const TituloSeccion('Ligas de tu organización')]);
          for (final p in e.privadas) {
            hijos.add(Tarjeta(
              key: ValueKey('liga-privada-${p.id}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(p.nombre, style: context.textos.titleMedium),
                const SizedBox(height: 8),
                for (final f in p.filas) _Fila(fila: f),
              ]),
            ));
            hijos.add(const SizedBox(height: 8));
          }
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(ligaProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [AnchoMaximo(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos))],
          ),
        );
      },
    );
  }

  List<Widget> _clasificacion(BuildContext context, WidgetRef ref, EstadoLiga e, ClasificacionLiga c, DateTime ahora, String alias) {
    final n = c.standings.length;
    final out = <Widget>[
      Text('Liga ${c.division ?? ''}'.trim(), style: context.textos.headlineSmall),
      Text('Quedan ${c.diasRestantes(ahora)} días', style: context.textos.bodyMedium?.copyWith(color: context.vtm.atenuado)),
      if (e.desdeCache) ...[
        const SizedBox(height: 8),
        Etiqueta(textoAntiguedad(c.computedAt, ahora), key: const ValueKey('antiguedad-liga'), icono: Symbols.history),
      ],
      if (e.puntosPendientes > 0) ...[
        const SizedBox(height: 8),
        Text('${e.puntosPendientes} puntos pendientes de sumar', key: const ValueKey('puntos-pendientes'), style: context.textos.titleSmall),
      ],
      const SizedBox(height: 12),
      Text(textoReglaLiga, style: context.textos.bodySmall),
      const SizedBox(height: 12),
    ];
    for (final f in c.standings) {
      if (n > c.promote + c.relegate && f.position == n - c.relegate + 1) {
        out.add(_Separador('Zona de descenso · bajan los ${c.relegate} últimos'));
      }
      out.add(_Fila(fila: f, zona: c.zonaDe(f)));
      if (f.position == c.promote && n > c.promote) out.add(_Separador('Zona de ascenso · suben los ${c.promote} primeros'));
    }
    out.addAll([
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => _cambiarAlias(context, ref, alias), icon: const Icon(Symbols.badge), label: const Text('Cambiar alias')),
        TextButton(key: const ValueKey('dejar-ligas'), onPressed: () => _participar(context, ref, false), child: const Text('Dejar de participar')),
      ]),
    ]);
    return out;
  }
}

class _Separador extends StatelessWidget {
  const _Separador(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(child: Divider(color: context.vtm.borde)),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(texto, textAlign: TextAlign.center, style: context.textos.labelMedium?.copyWith(color: context.vtm.atenuado)),
            ),
          ),
          Expanded(child: Divider(color: context.vtm.borde)),
        ]),
      );
}

class _Fila extends StatelessWidget {
  const _Fila({required this.fila, this.zona});
  final FilaLiga fila;
  final ZonaLiga? zona;

  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final f = fila;
    return Semantics(
      container: true,
      label: etiquetaFila(f),
      excludeSemantics: true,
      child: Container(
        key: ValueKey('fila-${f.position}'),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: f.me ? c.primarioTinte : c.superficie,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: f.me ? c.primario : c.borde),
        ),
        child: Row(children: [
          SizedBox(width: 28, child: Text('${f.position}', style: estiloCifra(context, size: 16))),
          CircleAvatar(radius: 14, backgroundColor: c.superficie2, child: Text(f.alias.isEmpty ? '?' : f.alias.characters.first.toUpperCase(), style: context.textos.labelMedium)),
          const SizedBox(width: 10),
          Expanded(child: Text(f.me ? '${f.alias} (tú)' : f.alias, style: context.textos.bodyMedium?.copyWith(fontWeight: f.me ? FontWeight.w700 : null))),
          if (zona == ZonaLiga.ascenso) Icon(Symbols.arrow_upward, size: 18, color: c.exito),
          if (zona == ZonaLiga.descenso) Icon(Symbols.arrow_downward, size: 18, color: c.errorFuerte),
          const SizedBox(width: 6),
          Text('${f.points}', style: estiloCifra(context, size: 16)),
        ]),
      ),
    );
  }
}

const _categorias = {'constancia': 'Constancia', 'precision': 'Precisión', 'agilidad': 'Agilidad', 'dominio': 'Dominio'};

const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// Logros (M53): se evalúan en el dispositivo, también sin conexión.
class PestanaLogros extends ConsumerWidget {
  const PestanaLogros({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(proyeccionProvider);
    final c = ref.watch(contenidoProvider).value;
    if (p == null || c == null) return const Esqueleto();
    final logros = p.logros;
    final ocultos = c.global.achievements.where((a) => a.secret && !logros.any((l) => l.logro.id == a.id)).length;
    final grupos = <String, List<LogroEstado>>{};
    for (final l in logros) {
      grupos.putIfAbsent(l.logro.category, () => []).add(l);
    }
    final orden = [..._categorias.keys.where(grupos.containsKey), ...grupos.keys.where((k) => !_categorias.containsKey(k))];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnchoMaximo(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final k in orden) ...[
                TituloSeccion(_categorias[k] ?? k),
                for (final l in grupos[k]!) ...[_Logro(l), const SizedBox(height: 8)],
              ],
              if (ocultos > 0) Text(ocultos == 1 ? '1 logro secreto por descubrir' : '$ocultos logros secretos por descubrir', style: context.textos.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _Logro extends StatelessWidget {
  const _Logro(this.l);
  final LogroEstado l;
  @override
  Widget build(BuildContext context) {
    final c = context.vtm;
    final f = l.fecha?.toLocal();
    final estado = l.obtenido ? 'Obtenido${f == null ? '' : ' el ${f.day} ${_meses[f.month - 1]}'}' : '${(l.progreso * 100).round()} %';
    return Tarjeta(
      key: ValueKey('logro-${l.logro.id}'),
      semantica: '${l.logro.name}. ${l.logro.description}. $estado',
      child: Row(children: [
        Icon(l.obtenido ? Symbols.military_tech : Symbols.lock_clock, fill: l.obtenido ? 1 : 0, color: l.obtenido ? c.acento : c.atenuado, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.logro.name, style: context.textos.titleSmall),
            Text(l.logro.description, style: context.textos.bodySmall?.copyWith(color: c.atenuado)),
            const SizedBox(height: 6),
            if (l.obtenido)
              Etiqueta(estado, tono: TonoEtiqueta.exito, icono: Symbols.check)
            else
              Row(children: [
                Expanded(child: LinearProgressIndicator(value: l.progreso, minHeight: 6, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(estado, style: estiloCifra(context, size: 14)),
              ]),
          ]),
        ),
      ]),
    );
  }
}
