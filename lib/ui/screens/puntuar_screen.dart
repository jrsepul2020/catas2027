import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

/// Lista de tandas para puntuar: primero las que están en curso.
class PuntuarScreen extends ConsumerWidget {
  const PuntuarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tandas = ref.watch(tandasProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    const peso = {'en_curso': 0, 'pendiente': 1, 'cerrada': 2};
    final l = [...tandas]
      ..sort((a, b) {
        final p = (peso[a.estado] ?? 1).compareTo(peso[b.estado] ?? 1);
        if (p != 0) return p;
        final ma = mesas[a.mesaId]?.numero ?? 999, mb = mesas[b.mesaId]?.numero ?? 999;
        return ma != mb ? ma.compareTo(mb) : a.orden.compareTo(b.orden);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Puntuar'), actions: const [ChipEntorno()]),
      body: l.isEmpty
          ? const Vacio(icono: Icons.edit_note, texto: 'No hay tandas. Créalas en Mesas o Tandas.')
          : Ancho(
              max: 900,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: l.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (c, i) {
                  final t = l[i];
                  return Card(
                    color: t.estado == 'en_curso' ? Colors.green.withValues(alpha: 0.13) : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Icon(estadosTanda[t.estado]!.$2, size: 40, color: estadosTanda[t.estado]!.$3),
                      title: Text('${mesas[t.mesaId]?.nombre ?? 'Sin mesa'} · ${t.nombre}'),
                      subtitle: Text(estadosTanda[t.estado]!.$1),
                      trailing: const Icon(Icons.chevron_right, size: 36),
                      onTap: () => context.go('/puntuar/${t.id}'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

/// Hoja de puntuación: rejilla muestras × catadores + teclado numérico gigante.
class HojaPuntuacionScreen extends ConsumerStatefulWidget {
  const HojaPuntuacionScreen({super.key, required this.tandaId});
  final String tandaId;
  @override
  ConsumerState<HojaPuntuacionScreen> createState() => _HojaPuntuacionScreenState();
}

class _HojaPuntuacionScreenState extends ConsumerState<HojaPuntuacionScreen> {
  int _fila = 0; // muestra
  int _col = 0; // catador
  String _entrada = '';
  final Map<String, double?> _pendientes = {}; // optimista
  final _foco = FocusNode();

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  String _k(String m, String c) => '$m|$c';

  void _tecla(String t) {
    HapticFeedback.selectionClick();
    setState(() {
      if (t == '⌫') {
        if (_entrada.isNotEmpty) _entrada = _entrada.substring(0, _entrada.length - 1);
      } else if (t == ',') {
        if (!_entrada.contains(',')) _entrada = _entrada.isEmpty ? '0,' : '$_entrada,';
      } else if (_entrada.length < 6) {
        final dec = _entrada.split(',');
        if (dec.length == 2 && dec[1].length >= 2) return;
        _entrada += t;
      }
    });
  }

  Future<void> _guardar(List<TandaMuestra> ms, List<Catador> cs, {bool borrar = false}) async {
    if (ms.isEmpty || cs.isEmpty) return;
    final cata = ref.read(cataProvider);
    final max = cata?.escalaMax ?? 100;
    double? v;
    if (!borrar) {
      if (_entrada.isEmpty) {
        _avanzar(ms.length, cs.length);
        return;
      }
      v = double.tryParse(_entrada.replaceAll(',', '.'));
      if (v == null || v < 0 || v > max) {
        aviso(context, 'Nota fuera de rango (0–${max.toStringAsFixed(0)})', error: true);
        return;
      }
    }
    final m = ms[_fila].muestraId;
    final c = cs[_col].id;
    final key = _k(m, c);
    setState(() {
      _pendientes[key] = v;
      _entrada = '';
      if (!borrar) _avanzar(ms.length, cs.length);
    });
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(repoProvider)!
          .puntuar(cataId: ref.read(cataIdProvider)!, muestraId: m, catadorId: c, tandaId: widget.tandaId, puntos: v);
    } catch (e) {
      if (mounted) {
        setState(() => _pendientes.remove(key));
        aviso(context, 'No se guardó: $e', error: true);
      }
    }
  }

  void _avanzar(int nFilas, int nCols) {
    if (_col < nCols - 1) {
      _col++;
    } else if (_fila < nFilas - 1) {
      _col = 0;
      _fila++;
    }
  }

  KeyEventResult _teclado(KeyEvent e, List<TandaMuestra> ms, List<Catador> cs) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final ch = e.character;
    final k = e.logicalKey;
    if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
      _tecla(ch);
    } else if (ch == ',' || ch == '.') {
      _tecla(',');
    } else if (k == LogicalKeyboardKey.backspace) {
      _tecla('⌫');
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.tab) {
      _guardar(ms, cs);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      setState(() => _col = (_col + 1).clamp(0, cs.length - 1));
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      setState(() => _col = (_col - 1).clamp(0, cs.length - 1));
    } else if (k == LogicalKeyboardKey.arrowDown) {
      setState(() => _fila = (_fila + 1).clamp(0, ms.length - 1));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      setState(() => _fila = (_fila - 1).clamp(0, ms.length - 1));
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tandasProvider).where((x) => x.id == widget.tandaId).firstOrNull;
    if (t == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final mesa = ref.watch(mesaPorIdProvider)[t.mesaId];
    final ms = ref.watch(muestrasDeTandaProvider(t.id));
    final cs = t.mesaId == null
        ? <Catador>[]
        : ref.watch(catadoresDeMesaProvider(t.mesaId!)).where((c) => c.presente).toList();
    final muestras = ref.watch(muestraPorIdProvider);
    final idx = ref.watch(puntuacionIdxProvider);

    // Limpia pendientes ya confirmados por realtime.
    _pendientes.removeWhere((k, v) => idx[k]?.puntos == v);
    double? valor(String m, String c) {
      final k = _k(m, c);
      return _pendientes.containsKey(k) ? _pendientes[k] : idx[k]?.puntos;
    }

    if (ms.isNotEmpty) _fila = _fila.clamp(0, ms.length - 1);
    if (cs.isNotEmpty) _col = _col.clamp(0, cs.length - 1);
    final cerrada = t.estado == 'cerrada';
    final cscheme = Theme.of(context).colorScheme;

    var hechas = 0;
    for (final m in ms) {
      for (final c in cs) {
        if (valor(m.muestraId, c.id) != null) hechas++;
      }
    }
    final total = ms.length * cs.length;

    final rejilla = (ms.isEmpty || cs.isEmpty)
        ? Vacio(
            icono: Icons.grid_off,
            texto: ms.isEmpty ? 'La tanda no tiene muestras' : 'La mesa no tiene catadores presentes',
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(76),
                columnWidths: const {0: FixedColumnWidth(112)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    children: [
                      const SizedBox(height: 64),
                      for (var j = 0; j < cs.length; j++)
                        InkWell(
                          onTap: () => setState(() => _col = j),
                          child: SizedBox(
                            height: 64,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'P${cs[j].puesto ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: j == _col ? cscheme.primary : null,
                                  ),
                                ),
                                Text(cs[j].iniciales, style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      const Center(
                        child: Text('Media', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ],
                  ),
                  for (var i = 0; i < ms.length; i++)
                    TableRow(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _fila = i),
                          onLongPress: () => nuevaIncidencia(
                            context,
                            ref,
                            mesaId: t.mesaId,
                            tandaId: t.id,
                            muestraId: ms[i].muestraId,
                          ),
                          child: Container(
                            height: 68,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              muestras[ms[i].muestraId]?.codigo ?? '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: i == _fila ? cscheme.primary : null,
                              ),
                            ),
                          ),
                        ),
                        for (var j = 0; j < cs.length; j++)
                          _Celda(
                            texto: (i == _fila && j == _col && _entrada.isNotEmpty)
                                ? _entrada
                                : _fmt(valor(ms[i].muestraId, cs[j].id)),
                            activa: i == _fila && j == _col,
                            escribiendo: i == _fila && j == _col && _entrada.isNotEmpty,
                            pendiente: _pendientes.containsKey(_k(ms[i].muestraId, cs[j].id)),
                            onTap: cerrada
                                ? null
                                : () => setState(() {
                                    _fila = i;
                                    _col = j;
                                    _entrada = '';
                                    _foco.requestFocus();
                                  }),
                          ),
                        Center(
                          child: Builder(
                            builder: (_) {
                              final vs = [for (final c in cs) valor(ms[i].muestraId, c.id)]
                                  .whereType<double>()
                                  .toList();
                              if (vs.isEmpty) return const Text('–');
                              final media = vs.reduce((a, b) => a + b) / vs.length;
                              return Text(
                                media.toStringAsFixed(1).replaceAll('.', ','),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );

    final teclado = cerrada
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tanda cerrada', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => ejecutar(context, () => ref.read(repoProvider)!.estadoTanda(t.id, 'en_curso')),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reabrir para corregir'),
                ),
              ],
            ),
          )
        : _Teclado(
            titulo: ms.isEmpty || cs.isEmpty
                ? ''
                : '${muestras[ms[_fila].muestraId]?.codigo} · P${cs[_col].puesto ?? '-'} ${cs[_col].nombre}',
            entrada: _entrada,
            onTecla: _tecla,
            onOk: () => _guardar(ms, cs),
            onBorrar: () => _guardar(ms, cs, borrar: true),
          );

    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: (_, e) => cerrada ? KeyEventResult.ignored : _teclado(e, ms, cs),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${mesa?.nombre ?? ''} · ${t.nombre}'),
              Text(
                '$hechas / $total notas',
                style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: total == 0 ? 0 : hechas / total, minHeight: 6),
          ),
          actions: [
            if (t.estado == 'en_curso' && total > 0 && hechas == total)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ejecutar(
                    context,
                    () => ref.read(repoProvider)!.estadoTanda(t.id, 'cerrada'),
                    ok: 'Tanda cerrada',
                  ),
                  icon: const Icon(Icons.lock),
                  label: const Text('Cerrar'),
                ),
              ),
            if (t.estado == 'pendiente')
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ejecutar(context, () => ref.read(repoProvider)!.estadoTanda(t.id, 'en_curso')),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar'),
                ),
              ),
            IconButton(
              tooltip: 'Incidencia',
              onPressed: () => nuevaIncidencia(context, ref, mesaId: t.mesaId, tandaId: t.id),
              icon: const Icon(Icons.add_alert),
            ),
          ],
        ),
        body: esAncho(context)
            ? Row(
                children: [
                  Expanded(child: rejilla),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 380, child: SingleChildScrollView(child: teclado)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: rejilla),
                  Material(
                    elevation: 8,
                    color: cscheme.surfaceContainer,
                    child: SafeArea(top: false, child: teclado),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({
    required this.texto,
    required this.activa,
    required this.escribiendo,
    required this.pendiente,
    required this.onTap,
  });
  final String texto;
  final bool activa;
  final bool escribiendo;
  final bool pendiente;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: activa
            ? cs.primary
            : texto.isEmpty
            ? cs.surfaceContainerHighest
            : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 62,
            child: Center(
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontStyle: pendiente ? FontStyle.italic : null,
                  color: activa ? cs.onPrimary : cs.onSecondaryContainer,
                  decoration: escribiendo ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Teclado extends StatelessWidget {
  const _Teclado({
    required this.titulo,
    required this.entrada,
    required this.onTecla,
    required this.onOk,
    required this.onBorrar,
  });
  final String titulo;
  final String entrada;
  final void Function(String) onTecla;
  final VoidCallback onOk;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height < 700 ? 54.0 : 64.0;
    Widget tecla(String t) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: Size(0, alto), padding: EdgeInsets.zero),
          onPressed: () => onTecla(t),
          child: t == '⌫'
              ? const Icon(Icons.backspace_outlined)
              : Text(t, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              Text(entrada.isEmpty ? '—' : entrada, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
            ],
          ),
          for (final fila in const [
            ['7', '8', '9'],
            ['4', '5', '6'],
            ['1', '2', '3'],
            [',', '0', '⌫'],
          ])
            Row(children: [for (final t in fila) tecla(t)]),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: Size(0, alto)),
                    onPressed: onBorrar,
                    child: const Text('Borrar nota'),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: Size(0, alto)),
                    onPressed: onOk,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('OK'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
