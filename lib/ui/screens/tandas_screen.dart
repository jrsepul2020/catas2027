import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

/// Tandas del día: todas a la vista (unas 5 en curso), sin filtro por mesa.
class TandasScreen extends ConsumerWidget {
  const TandasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tandas = ref.watch(tandasProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    final k = esCompacto(context);
    const peso = {'abierta': 0, 'pendiente': 1, 'cerrada': 2};
    final l = [...tandas]
      ..sort((a, b) {
        final p = (peso[a.estado] ?? 1).compareTo(peso[b.estado] ?? 1);
        if (p != 0) return p;
        final ma = mesas[a.mesaId]?.numero ?? 999, mb = mesas[b.mesaId]?.numero ?? 999;
        return ma != mb ? ma.compareTo(mb) : a.orden.compareTo(b.orden);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tandas'),
        actions: [
          IconButton(
            tooltip: 'Nueva tanda',
            onPressed: () => editarTanda(context, ref, null, orden: tandas.length),
            icon: const Icon(Icons.add),
          ),
          const ChipDia(),
          const ChipEntorno(),
        ],
      ),
      body: l.isEmpty
          ? Vacio(
              icono: Icons.format_list_numbered,
              texto: 'Sin tandas para este día',
              accion: FilledButton.tonalIcon(
                onPressed: () => editarTanda(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Nueva tanda'),
              ),
            )
          : Ancho(
              max: 900,
              child: ListaLlena(
                itemCount: l.length,
                gap: k ? 8 : 12,
                padding: EdgeInsets.all(k ? 10 : 14),
                altoMinimo: k ? 110 : 130,
                itemBuilder: (c, i) => _TarjetaTanda(t: l[i]),
              ),
            ),
    );
  }
}

class _TarjetaTanda extends ConsumerWidget {
  const _TarjetaTanda({required this.t});
  final Tanda t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tms = ref.watch(muestrasDeTandaProvider(t.id));
    final hechas = tms.where((x) => x.estado == 'completada').length;
    final incid = tms.where((x) => x.conIncidencia).length;
    final activa = tms.where((x) => x.estado == 'activa').firstOrNull;
    final muestras = ref.watch(muestraPorIdProvider);
    final mesa = ref.watch(mesaPorIdProvider)[t.mesaId];
    final cat = ref.watch(categoriaPorIdProvider)[t.categoriaId];
    final repo = ref.read(repoProvider)!;
    final k = esCompacto(context);
    final cs = Theme.of(context).colorScheme;
    final info = infoTanda(t.estado);
    final codigoActiva = activa == null ? null : muestras[activa.muestraId]?.codigo;

    return Card(
      color: t.estado == 'abierta' ? Paleta.amarilloPastel : null,
      child: InkWell(
        onTap: () => context.go('/tandas/${t.id}'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: k ? 12 : 18, vertical: k ? 10 : 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: k ? 26 : 32,
                backgroundColor: Color.alphaBlend(info.$3.shade400.withValues(alpha: 0.22), Colors.white),
                child: Icon(info.$2, size: k ? 26 : 32, color: info.$3.shade800),
              ),
              SizedBox(width: k ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: k ? 18 : 22, fontWeight: FontWeight.w900, color: cs.onSurface),
                          ),
                        ),
                        EtiquetaEstado(info),
                      ],
                    ),
                    SizedBox(height: k ? 3 : 5),
                    Text(
                      [
                        mesa?.nombre ?? 'Sin mesa',
                        if (cat != null) cat.nombre,
                        '$hechas/${tms.length} muestras',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: k ? 14 : 17, fontWeight: FontWeight.w700, color: cs.onSurface),
                    ),
                    if (codigoActiva != null || incid > 0) ...[
                      SizedBox(height: k ? 2 : 4),
                      Text(
                        [
                          if (codigoActiva != null) 'Activa $codigoActiva',
                          if (incid > 0) '$incid incidencia${incid > 1 ? 's' : ''}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: k ? 14 : 16,
                          fontWeight: FontWeight.w800,
                          color: incid > 0 ? Paleta.rojo : Paleta.azulOscuro,
                        ),
                      ),
                    ],
                    if (tms.isNotEmpty) ...[
                      SizedBox(height: k ? 6 : 8),
                      LinearProgressIndicator(
                        value: tms.isEmpty ? 0 : hechas / tms.length,
                        minHeight: k ? 7 : 10,
                        color: info.$3,
                        backgroundColor: info.$3.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: k ? 6 : 10),
              if (t.estado == 'pendiente')
                IconButton.filled(
                  tooltip: 'Abrir tanda',
                  onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, 'abierta')),
                  icon: const Icon(Icons.play_arrow),
                )
              else if (t.estado == 'abierta')
                IconButton.filled(
                  tooltip: 'Ver notas',
                  onPressed: () => context.go('/puntuar/${t.id}'),
                  icon: const Icon(Icons.grid_on),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista reordenable (arrastrar) de las tandas de una mesa en el día de trabajo.
class TandasDeMesa extends ConsumerStatefulWidget {
  const TandasDeMesa({super.key, required this.mesaId});
  final int? mesaId;
  @override
  ConsumerState<TandasDeMesa> createState() => _TandasDeMesaState();
}

class _TandasDeMesaState extends ConsumerState<TandasDeMesa> {
  List<int>? _orden; // orden optimista mientras llega el realtime

  @override
  Widget build(BuildContext context) {
    var tandas = ref.watch(tandasDeMesaProvider(widget.mesaId));
    if (_orden != null) {
      final ids = tandas.map((t) => t.id).toList();
      if (ids.join(',') == _orden!.join(',') || ids.length != _orden!.length) {
        _orden = null;
      } else {
        final pos = {for (var i = 0; i < _orden!.length; i++) _orden![i]: i};
        tandas = [...tandas]..sort((a, b) => (pos[a.id] ?? 0).compareTo(pos[b.id] ?? 0));
      }
    }
    final repo = ref.read(repoProvider)!;
    final k = esCompacto(context);

    return Column(
      children: [
        Expanded(
          child: tandas.isEmpty
              ? const Vacio(icono: Icons.format_list_numbered, texto: 'Sin tandas en esta mesa para este día')
              : LayoutBuilder(
                  builder: (context, box) {
                    final pad = k ? 8.0 : 12.0;
                    final gap = k ? 8.0 : 10.0;
                    final n = tandas.length;
                    // Con pocas tandas, reparte la altura para no dejar hueco.
                    final llenar = n <= 8;
                    final alto = llenar
                        ? ((box.maxHeight - pad * 2) / n).clamp(k ? 88.0 : 100.0, double.infinity)
                        : (k ? 100.0 : 114.0);
                    return ReorderableListView.builder(
                      padding: EdgeInsets.all(pad),
                      itemCount: n,
                      itemExtent: alto,
                      buildDefaultDragHandles: false,
                      physics: llenar ? const NeverScrollableScrollPhysics() : null,
                      onReorderItem: (oldI, newI) async {
                        HapticFeedback.mediumImpact();
                        final l = tandas.map((t) => t.id).toList();
                        final movida = tandas[oldI];
                        l.insert(newI, l.removeAt(oldI));
                        setState(() => _orden = l);
                        final ok = await ejecutar(
                          context,
                          () => repo.reordenarTandas(l, motivo: '${movida.nombre}: posición ${oldI + 1} → ${newI + 1}'),
                        );
                        if (!ok && mounted) setState(() => _orden = null);
                      },
                      itemBuilder: (c, i) => Padding(
                        key: ValueKey(tandas[i].id),
                        padding: EdgeInsets.only(bottom: i < n - 1 ? gap : 0),
                        child: _FilaTanda(t: tandas[i], indice: i),
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
              onPressed: () => editarTanda(context, ref, null, mesaId: widget.mesaId, orden: tandas.length),
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
    final tms = ref.watch(muestrasDeTandaProvider(t.id));
    final hechas = tms.where((x) => x.estado == 'completada').length;
    final incid = tms.where((x) => x.conIncidencia).length;
    final cat = ref.watch(categoriaPorIdProvider)[t.categoriaId];
    final repo = ref.read(repoProvider)!;
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: t.estado == 'abierta' ? Colors.amber.withValues(alpha: 0.12) : null,
      child: InkWell(
        onTap: () => context.go('/tandas/${t.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: indice,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator, size: 26, color: cs.outline),
                ),
              ),
              CircleAvatar(
                radius: 20,
                child: Text('${indice + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        EtiquetaEstado(infoTanda(t.estado)),
                        Text(
                          '$hechas/${tms.length} completadas',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (cat != null) Text(cat.nombre, style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
                        if (incid > 0)
                          EtiquetaEstado((
                            '$incid incidencia${incid > 1 ? 's' : ''}',
                            Icons.warning_amber_rounded,
                            Colors.red,
                          )),
                      ],
                    ),
                  ],
                ),
              ),
              if (t.estado == 'pendiente')
                IconButton.filled(
                  tooltip: 'Abrir tanda',
                  onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, 'abierta')),
                  icon: const Icon(Icons.play_arrow),
                )
              else if (t.estado == 'abierta')
                IconButton.filled(
                  tooltip: 'Ver notas',
                  onPressed: () => context.go('/puntuar/${t.id}'),
                  icon: const Icon(Icons.grid_on),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alta / edición de tanda: número, categoría, día y mesa.
Future<void> editarTanda(BuildContext context, WidgetRef ref, Tanda? t, {int? mesaId, int orden = 0}) async {
  final repo = ref.read(repoProvider)!;
  final cats = ref.read(categoriasProvider);
  final dias = ref.read(diasProvider);
  final mesas = ref.read(mesasProvider);
  final maxNum = ref.read(todasTandasProvider).fold<int>(0, (a, b) => b.numero > a ? b.numero : a);
  final numero = TextEditingController(text: '${t?.numero ?? maxNum + 1}');
  int? categoria = t?.categoriaId ?? (cats.isNotEmpty ? cats.first.id : null);
  int? dia = t?.diaId ?? ref.read(diaIdProvider);
  int? mesa = t?.mesaId ?? mesaId;
  await hojaFormulario(
    context,
    titulo: t == null ? 'Nueva tanda' : t.nombre,
    campos: [
      Campo(numero, 'Número de tanda', numero: true),
      StatefulBuilder(
        builder: (c, set) {
          final estilo = TextStyle(fontSize: 19, color: Theme.of(c).colorScheme.onSurface);
          return Column(
            children: [
              DropdownButtonFormField<int?>(
                initialValue: mesa,
                isExpanded: true,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Mesa'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin mesa')),
                  for (final m in mesas) DropdownMenuItem(value: m.id, child: Text(m.nombre)),
                ],
                onChanged: (v) => set(() => mesa = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: categoria,
                isExpanded: true,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [for (final x in cats) DropdownMenuItem(value: x.id, child: Text(x.nombre))],
                onChanged: (v) => set(() => categoria = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int?>(
                initialValue: dias.any((d) => d.id == dia) ? dia : null,
                isExpanded: true,
                style: estilo,
                decoration: const InputDecoration(labelText: 'Día'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin día')),
                  for (final d in dias) DropdownMenuItem(value: d.id, child: Text('${d.nombre} · ${d.fecha}')),
                ],
                onChanged: (v) => set(() => dia = v),
              ),
              const SizedBox(height: 14),
            ],
          );
        },
      ),
    ],
    borrar: t == null ? null : () => repo.borrar('tandas', t.id),
    guardar: () async {
      final d = {
        'numero': int.tryParse(numero.text) ?? maxNum + 1,
        'categoria_id': categoria,
        'dia_id': dia,
        'mesa_id': mesa,
      };
      if (t == null) {
        final id = await repo.insertar('tandas', {...d, 'estado': 'pendiente', 'orden': orden});
        if (context.mounted) context.go('/tandas/$id');
      } else {
        await repo.actualizar('tandas', t.id, d);
      }
    },
  );
}

// ============================ DETALLE ============================

class TandaDetalleScreen extends ConsumerStatefulWidget {
  const TandaDetalleScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<TandaDetalleScreen> createState() => _TandaDetalleScreenState();
}

class _TandaDetalleScreenState extends ConsumerState<TandaDetalleScreen> {
  List<int>? _orden;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tandaPorIdProvider)[widget.id];
    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ref.watch(cargandoProvider)
            ? const Center(child: CircularProgressIndicator())
            : const Vacio(icono: Icons.hourglass_empty, texto: 'Tanda no encontrada'),
      );
    }
    final repo = ref.read(repoProvider)!;
    final mesa = ref.watch(mesaPorIdProvider)[t.mesaId];
    final cat = ref.watch(categoriaPorIdProvider)[t.categoriaId];
    final muestras = ref.watch(muestraPorIdProvider);
    final idx = ref.watch(puntuacionIdxProvider);
    final cats = t.mesaId == null ? const <Catador>[] : ref.watch(catadoresDeMesaProvider(t.mesaId!));
    var tms = ref.watch(muestrasDeTandaProvider(t.id));
    if (_orden != null) {
      final ids = tms.map((e) => e.id).toList();
      if (ids.join(',') == _orden!.join(',') || ids.length != _orden!.length) {
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
          IconButton(
            tooltip: 'Editar tanda',
            onPressed: () => editarTanda(context, ref, t),
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            tooltip: 'Incidencia',
            onPressed: () => nuevaIncidencia(context, ref, tandaId: t.id),
            icon: const Icon(Icons.add_alert),
          ),
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
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      EtiquetaEstado(infoTanda(t.estado)),
                      Text(
                        mesa?.nombre ?? 'Sin mesa',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (cat != null) Text(cat.nombre, style: const TextStyle(fontSize: 18)),
                      Text('${tms.length} muestras', style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (t.estado == 'pendiente') accion('abierta', Icons.play_arrow, 'Abrir tanda'),
                      if (t.estado == 'abierta') ...[
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
                            onPressed: () => context.go('/puntuar/${t.id}'),
                            icon: const Icon(Icons.grid_on),
                            label: const Text('Notas'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        accion('cerrada', Icons.lock, 'Cerrar'),
                      ],
                      if (t.estado == 'cerrada') accion('abierta', Icons.lock_open, 'Reabrir'),
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
                      padding: const EdgeInsets.all(8),
                      buildDefaultDragHandles: false,
                      itemCount: tms.length,
                      onReorderItem: (oldI, newI) async {
                        HapticFeedback.mediumImpact();
                        final l = tms.map((e) => e.id).toList();
                        l.insert(newI, l.removeAt(oldI));
                        setState(() => _orden = l);
                        if (!await ejecutar(context, () => repo.reordenarMuestras(t.id, l)) && mounted) {
                          setState(() => _orden = null);
                        }
                      },
                      itemBuilder: (c, i) {
                        final tm = tms[i];
                        final m = muestras[tm.muestraId];
                        final notas = cats.where((x) => idx['${tm.muestraId}|${x.id}'] != null).length;
                        final info = infoTM(tm.estado);
                        return Card(
                          key: ValueKey(tm.id),
                          margin: const EdgeInsets.only(bottom: 10),
                          color: tm.estado == 'activa'
                              ? Colors.amber.withValues(alpha: 0.14)
                              : tm.conIncidencia
                              ? Colors.red.withValues(alpha: 0.14)
                              : null,
                          child: ListTile(
                            leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator)),
                            title: Text(
                              '${i + 1}.  ${m?.codigo ?? '?'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              [info.$1, '$notas/${cats.length} notas', if (tm.motivo != null) tm.motivo!].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(info.$2, color: info.$3),
                            onTap: () => _accionesMuestra(context, t, tm, m),
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

  Future<void> _accionesMuestra(BuildContext context, Tanda t, TandaMuestra tm, Muestra? m) async {
    final repo = ref.read(repoProvider)!;
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Muestra ${m?.codigo ?? '?'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(infoTM(tm.estado).$1),
            const SizedBox(height: 8),
            if (tm.estado != 'activa')
              AccionHoja(
                icono: Icons.play_circle_fill,
                color: Paleta.amarillo,
                titulo: 'Poner como ACTIVA',
                subtitulo: 'Es la que ven las tablets de la mesa',
                onTap: () => Navigator.pop(s, 'activar'),
              ),
            AccionHoja(
              icono: Icons.verified,
              color: Paleta.lila,
              titulo: 'Aprobar notas y completar',
              onTap: () => Navigator.pop(s, 'aprobar'),
            ),
            if (tm.conIncidencia)
              AccionHoja(
                icono: Icons.build_circle,
                color: Paleta.rojo,
                titulo: 'Resolver incidencia',
                onTap: () => Navigator.pop(s, 'resolver'),
              )
            else
              AccionHoja(
                icono: Icons.add_alert,
                color: Paleta.rojo,
                titulo: 'Marcar incidencia',
                onTap: () => Navigator.pop(s, 'incidencia'),
              ),
            AccionHoja(
              icono: Icons.remove_circle,
              color: Theme.of(s).colorScheme.error,
              titulo: 'Quitar de la tanda',
              onTap: () => Navigator.pop(s, 'quitar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'activar':
        await ejecutar(context, () => repo.activarMuestra(tm.id), ok: 'Muestra ${m?.codigo} activa');
      case 'aprobar':
        if (await confirmar(
              context,
              '¿Aprobar las notas de ${m?.codigo}?',
              texto: 'Las notas aprobadas ya no se pueden cambiar desde las tablets.',
              si: 'Aprobar',
            ) &&
            context.mounted) {
          var n = 0;
          final ok = await ejecutar(context, () async => n = await repo.aprobarMuestra(tm.id));
          if (ok && context.mounted) aviso(context, '$n notas aprobadas');
        }
      case 'incidencia':
        await nuevaIncidencia(context, ref, tm: tm);
      case 'resolver':
        await resolverIncidencia(context, ref, tm);
      case 'quitar':
        if (await confirmar(
              context,
              '¿Quitar ${m?.codigo} de la tanda?',
              texto: 'Se borran sus notas (quedan en el registro) y la muestra se desactiva.',
              si: 'Quitar',
            ) &&
            context.mounted) {
          await ejecutar(
            context,
            () => repo.resolverIncidencia(tm.id, 'quitar_de_tanda', motivo: 'Quitada desde la app'),
          );
        }
    }
  }

  Future<void> _anadirMuestras(BuildContext context, Tanda t, int desde) async {
    final asignadas = ref.read(tandaMuestrasProvider).map((e) => e.muestraId).toSet();
    final disponibles = ref
        .read(muestrasProvider)
        .where(
          (m) => m.activa && !asignadas.contains(m.id) && (t.categoriaId == null || m.categoriaId == t.categoriaId),
        )
        .toList();
    if (disponibles.isEmpty) {
      aviso(context, 'No quedan muestras activas de esta categoría sin tanda');
      return;
    }
    final sel = <int>{};
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
              const Text('Muestras sin tanda', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: disponibles.length,
                  itemBuilder: (c, i) {
                    final m = disponibles[i];
                    final k = esCompacto(c);
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: k ? 20 : 28, vertical: k ? 6 : 10),
                      value: sel.contains(m.id),
                      onChanged: (v) => set(() => v! ? sel.add(m.id) : sel.remove(m.id)),
                      title: Text(
                        m.codigo,
                        style: TextStyle(fontSize: k ? 18 : 20, fontWeight: FontWeight.w800),
                      ),
                      subtitle: m.codigoTexto == null ? null : Text(m.codigoTexto!),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
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
    await ejecutar(context, () => ref.read(repoProvider)!.anadirMuestrasATanda(t.id, orden, desde));
  }
}
