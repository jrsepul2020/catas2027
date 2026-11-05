import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

/// Mesa elegida en la pantalla de tandas (persistente durante la sesión).
class _MesaFiltro extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final _mesaFiltroProvider = NotifierProvider<_MesaFiltro, String?>(_MesaFiltro.new);

class TandasScreen extends ConsumerWidget {
  const TandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final hayHuerfanas = ref.watch(tandasDeMesaProvider(null)).isNotEmpty;
    var sel = ref.watch(_mesaFiltroProvider);
    if (sel == null || (sel != '-' && !mesas.any((m) => m.id == sel))) {
      sel = mesas.isNotEmpty ? mesas.first.id : '-';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tandas'), actions: const [ChipEntorno()]),
      body: Column(
        children: [
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                for (final m in mesas)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(m.nombre),
                      selected: sel == m.id,
                      onSelected: (_) => ref.read(_mesaFiltroProvider.notifier).set(m.id),
                    ),
                  ),
                if (hayHuerfanas || mesas.isEmpty)
                  ChoiceChip(
                    label: const Text('Sin mesa'),
                    selected: sel == '-',
                    onSelected: (_) => ref.read(_mesaFiltroProvider.notifier).set('-'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TandasDeMesa(key: ValueKey(sel), mesaId: sel == '-' ? null : sel),
          ),
        ],
      ),
    );
  }
}

/// Lista reordenable (arrastrar) de las tandas de una mesa.
class TandasDeMesa extends ConsumerStatefulWidget {
  const TandasDeMesa({super.key, required this.mesaId});
  final String? mesaId;
  @override
  ConsumerState<TandasDeMesa> createState() => _TandasDeMesaState();
}

class _TandasDeMesaState extends ConsumerState<TandasDeMesa> {
  List<String>? _orden; // orden optimista mientras llega el realtime

  @override
  Widget build(BuildContext context) {
    var tandas = ref.watch(tandasDeMesaProvider(widget.mesaId));
    if (_orden != null) {
      final ids = tandas.map((t) => t.id).toList();
      if (ids.join() == _orden!.join() || ids.length != _orden!.length) {
        _orden = null;
      } else {
        final pos = {for (var i = 0; i < _orden!.length; i++) _orden![i]: i};
        tandas = [...tandas]..sort((a, b) => (pos[a.id] ?? 0).compareTo(pos[b.id] ?? 0));
      }
    }
    final repo = ref.read(repoProvider)!;

    return Column(
      children: [
        Expanded(
          child: tandas.isEmpty
              ? const Vacio(icono: Icons.format_list_numbered, texto: 'Sin tandas en esta mesa')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: tandas.length,
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldI, newI) async {
                    HapticFeedback.mediumImpact();
                    final l = tandas.map((t) => t.id).toList();
                    final movida = tandas[oldI];
                    l.insert(newI, l.removeAt(oldI));
                    setState(() => _orden = l);
                    final ok = await ejecutar(context, () async {
                      await repo.reordenar('tandas', l);
                      await registrarIncidenciaAuto(
                        ref,
                        tipo: 'cambio_orden',
                        mesaId: widget.mesaId,
                        tandaId: movida.id,
                        descripcion: '${movida.nombre}: posición ${oldI + 1} → ${newI + 1}',
                      );
                    });
                    if (!ok && mounted) setState(() => _orden = null);
                  },
                  itemBuilder: (c, i) => Padding(
                    key: ValueKey(tandas[i].id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FilaTanda(t: tandas[i], indice: i),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                final id = await repo.insertar('tandas', {
                  'cata_id': ref.read(cataIdProvider),
                  'mesa_id': widget.mesaId,
                  'orden': tandas.length,
                  'nombre': 'Tanda ${tandas.length + 1}',
                });
                if (context.mounted) context.go('/tandas/$id');
              },
              icon: const Icon(Icons.add),
              label: const Text('Nueva tanda'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaTanda extends ConsumerWidget {
  const _FilaTanda({required this.t, required this.indice});
  final Tanda t;
  final int indice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(muestrasDeTandaProvider(t.id)).length;
    final repo = ref.read(repoProvider)!;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: t.estado == 'en_curso' ? Colors.green.withValues(alpha: 0.12) : null,
      child: InkWell(
        onTap: () => context.go('/tandas/${t.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: indice,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.drag_indicator, size: 34, color: cs.outline),
                ),
              ),
              CircleAvatar(
                radius: 24,
                child: Text('${indice + 1}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        EtiquetaEstado(estadosTanda[t.estado]!),
                        Text('$n muestras', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              if (t.estado == 'pendiente')
                IconButton.filled(
                  tooltip: 'Iniciar',
                  onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, 'en_curso')),
                  icon: const Icon(Icons.play_arrow),
                )
              else if (t.estado == 'en_curso')
                IconButton.filled(
                  tooltip: 'Puntuar',
                  onPressed: () => context.go('/puntuar/${t.id}'),
                  icon: const Icon(Icons.edit_note),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================ DETALLE ============================

class TandaDetalleScreen extends ConsumerStatefulWidget {
  const TandaDetalleScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<TandaDetalleScreen> createState() => _TandaDetalleScreenState();
}

class _TandaDetalleScreenState extends ConsumerState<TandaDetalleScreen> {
  List<String>? _orden;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tandasProvider).where((x) => x.id == widget.id).firstOrNull;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Vacio(icono: Icons.hourglass_empty, texto: 'Tanda no encontrada'),
      );
    }
    final repo = ref.read(repoProvider)!;
    final mesa = ref.watch(mesaPorIdProvider)[t.mesaId];
    final muestras = ref.watch(muestraPorIdProvider);
    var tms = ref.watch(muestrasDeTandaProvider(t.id));
    if (_orden != null) {
      final ids = tms.map((e) => e.id).toList();
      if (ids.join() == _orden!.join() || ids.length != _orden!.length) {
        _orden = null;
      } else {
        final pos = {for (var i = 0; i < _orden!.length; i++) _orden![i]: i};
        tms = [...tms]..sort((a, b) => (pos[a.id] ?? 0).compareTo(pos[b.id] ?? 0));
      }
    }

    Widget accion(String estado, IconData i, String txt) => Expanded(
      child: FilledButton.icon(
        onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, estado)),
        icon: Icon(i),
        label: Text(txt),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.nombre),
        actions: [
          PopupMenuButton<String>(
            iconSize: 32,
            onSelected: (v) async {
              switch (v) {
                case 'nombre':
                  final c = TextEditingController(text: t.r['nombre'] ?? '');
                  await hojaFormulario(
                    context,
                    titulo: 'Renombrar tanda',
                    campos: [Campo(c, 'Nombre', autofocus: true)],
                    guardar: () => repo.actualizar('tandas', t.id, {'nombre': c.text.trim()}),
                  );
                case 'mesa':
                  final ms = ref.read(mesasProvider);
                  final m = await elegir(context, titulo: 'Mover a mesa', opciones: ms, texto: (m) => m.nombre);
                  if (m != null && context.mounted) {
                    final n = ref.read(tandasDeMesaProvider(m.id)).length;
                    await ejecutar(context, () async {
                      await repo.actualizar('tandas', t.id, {'mesa_id': m.id, 'orden': n});
                      await registrarIncidenciaAuto(
                        ref,
                        tipo: 'cambio_orden',
                        mesaId: m.id,
                        tandaId: t.id,
                        descripcion: '${t.nombre} movida de ${mesa?.nombre ?? 'sin mesa'} a ${m.nombre}',
                      );
                    }, ok: 'Tanda movida a ${m.nombre}');
                  }
                case 'incidencia':
                  await nuevaIncidencia(context, ref, mesaId: t.mesaId, tandaId: t.id);
                case 'borrar':
                  if (await confirmar(context, '¿Eliminar ${t.nombre}?', si: 'Eliminar') && context.mounted) {
                    await ejecutar(context, () => repo.borrar('tandas', t.id));
                    if (context.mounted) context.pop();
                  }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'nombre',
                child: ListTile(leading: Icon(Icons.edit), title: Text('Renombrar')),
              ),
              PopupMenuItem(
                value: 'mesa',
                child: ListTile(leading: Icon(Icons.move_up), title: Text('Mover a otra mesa')),
              ),
              PopupMenuItem(
                value: 'incidencia',
                child: ListTile(leading: Icon(Icons.add_alert), title: Text('Incidencia')),
              ),
              PopupMenuItem(
                value: 'borrar',
                child: ListTile(leading: Icon(Icons.delete), title: Text('Eliminar')),
              ),
            ],
          ),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EtiquetaEstado(estadosTanda[t.estado]!),
                      Text(
                        mesa?.nombre ?? 'Sin mesa',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text('${tms.length} muestras', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (t.estado == 'pendiente') accion('en_curso', Icons.play_arrow, 'Iniciar'),
                      if (t.estado == 'en_curso') ...[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                            onPressed: () => context.go('/puntuar/${t.id}'),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Puntuar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        accion('cerrada', Icons.lock, 'Cerrar'),
                      ],
                      if (t.estado == 'cerrada') accion('en_curso', Icons.lock_open, 'Reabrir'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tms.isEmpty
                  ? const Vacio(icono: Icons.wine_bar, texto: 'Añade muestras a esta tanda')
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(12),
                      buildDefaultDragHandles: false,
                      itemCount: tms.length,
                      onReorderItem: (oldI, newI) async {
                        HapticFeedback.mediumImpact();
                        final l = tms.map((e) => e.id).toList();
                        l.insert(newI, l.removeAt(oldI));
                        setState(() => _orden = l);
                        if (!await ejecutar(context, () => repo.reordenar('tanda_muestras', l)) && mounted) {
                          setState(() => _orden = null);
                        }
                      },
                      itemBuilder: (c, i) {
                        final tm = tms[i];
                        final m = muestras[tm.muestraId];
                        return Dismissible(
                          key: ValueKey(tm.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: const Icon(Icons.remove_circle, size: 36),
                          ),
                          confirmDismiss: (_) => confirmar(context, '¿Quitar ${m?.codigo} de la tanda?', si: 'Quitar'),
                          onDismissed: (_) => ejecutar(context, () => repo.borrar('tanda_muestras', tm.id)),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_indicator, size: 34),
                              ),
                              title: Text(
                                '${i + 1}.  ${m?.codigo ?? '?'}',
                                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                [m?.nombre, m?.categoria, m?.anada?.toString()].whereType<String>().join(' · '),
                              ),
                              trailing: IconButton(
                                tooltip: 'Incidencia',
                                icon: const Icon(Icons.add_alert),
                                onPressed: () => nuevaIncidencia(
                                  context,
                                  ref,
                                  mesaId: t.mesaId,
                                  tandaId: t.id,
                                  muestraId: tm.muestraId,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _anadirMuestras(context, t, tms.length),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir muestras'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _anadirMuestras(BuildContext context, Tanda t, int desde) async {
    final asignadas = ref.read(tandaMuestrasProvider).map((e) => e.muestraId).toSet();
    final disponibles = ref.read(muestrasProvider).where((m) => !asignadas.contains(m.id)).toList();
    if (disponibles.isEmpty) {
      aviso(context, 'Todas las muestras ya están en alguna tanda');
      return;
    }
    final sel = <String>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (c) => StatefulBuilder(
        builder: (c, set) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (c, sc) => Column(
            children: [
              const Text('Muestras sin tanda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: disponibles.length,
                  itemBuilder: (c, i) {
                    final m = disponibles[i];
                    return CheckboxListTile(
                      value: sel.contains(m.id),
                      onChanged: (v) => set(() => v! ? sel.add(m.id) : sel.remove(m.id)),
                      title: Text(m.codigo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      subtitle: Text([m.nombre, m.categoria].whereType<String>().join(' · ')),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: sel.isEmpty ? null : () => Navigator.pop(c, true),
                    icon: const Icon(Icons.check),
                    label: Text('Añadir ${sel.length}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final orden = disponibles.where((m) => sel.contains(m.id)).map((m) => m.id).toList();
    await ejecutar(
      context,
      () => ref.read(repoProvider)!.anadirMuestrasATanda(ref.read(cataIdProvider)!, t.id, orden, desde),
    );
  }
}
