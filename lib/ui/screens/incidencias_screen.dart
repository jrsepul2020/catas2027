import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';

final _hora = DateFormat('HH:mm');

/// Deja constancia automática de un cambio hecho durante la cata.
Future<void> registrarIncidenciaAuto(
  WidgetRef ref, {
  required String tipo,
  String? mesaId,
  String? tandaId,
  String? muestraId,
  String? catadorId,
  required String descripcion,
  bool resuelta = true,
}) async {
  final repo = ref.read(repoProvider);
  final cataId = ref.read(cataIdProvider);
  if (repo == null || cataId == null) return;
  await repo.insertar('incidencias', {
    'cata_id': cataId,
    'tipo': tipo,
    'mesa_id': mesaId,
    'tanda_id': tandaId,
    'muestra_id': muestraId,
    'catador_id': catadorId,
    'descripcion': descripcion,
    'prioridad': 'baja',
    'estado': resuelta ? 'resuelta' : 'abierta',
    if (resuelta) 'resuelta_at': DateTime.now().toUtc().toIso8601String(),
  });
}

/// Alta rápida: rejilla de iconos grandes -> descripción opcional -> guardar.
Future<void> nuevaIncidencia(
  BuildContext context,
  WidgetRef ref, {
  String? mesaId,
  String? tandaId,
  String? muestraId,
  String? catadorId,
}) async {
  final tipo = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Qué ha pasado?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final e in tiposIncidencia.entries)
                  Card(
                    color: Theme.of(s).colorScheme.secondaryContainer,
                    child: InkWell(
                      onTap: () => Navigator.pop(s, e.key),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(e.value.$2, size: 42),
                          const SizedBox(height: 6),
                          Text(
                            e.value.$1,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (tipo == null || !context.mounted) return;

  final desc = TextEditingController();
  var prioridad = tipo == 'botella_rota' || tipo == 'muestra_defectuosa' ? 'alta' : 'media';
  var mesa = mesaId;
  final mesas = ref.read(mesasProvider);
  final repo = ref.read(repoProvider)!;
  await hojaFormulario(
    context,
    titulo: tiposIncidencia[tipo]!.$1,
    campos: [
      StatefulBuilder(
        builder: (c, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'baja', label: Text('Baja')),
                ButtonSegment(value: 'media', label: Text('Media')),
                ButtonSegment(value: 'alta', label: Text('Alta')),
              ],
              selected: {prioridad},
              onSelectionChanged: (v) => set(() => prioridad = v.first),
            ),
            const SizedBox(height: 14),
            if (mesas.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: mesa,
                isExpanded: true,
                style: TextStyle(fontSize: 19, color: Theme.of(c).colorScheme.onSurface),
                decoration: const InputDecoration(labelText: 'Mesa'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('General')),
                  for (final m in mesas) DropdownMenuItem(value: m.id, child: Text(m.nombre)),
                ],
                onChanged: (v) => set(() => mesa = v),
              ),
            const SizedBox(height: 14),
          ],
        ),
      ),
      Campo(desc, 'Descripción (opcional)', lineas: 2),
    ],
    guardar: () => repo.insertar('incidencias', {
      'cata_id': ref.read(cataIdProvider),
      'tipo': tipo,
      'prioridad': prioridad,
      'descripcion': desc.text.trim().isEmpty ? null : desc.text.trim(),
      'mesa_id': mesa,
      'tanda_id': tandaId,
      'muestra_id': muestraId,
      'catador_id': catadorId,
    }),
  );
}

class IncidenciasScreen extends ConsumerStatefulWidget {
  const IncidenciasScreen({super.key});
  @override
  ConsumerState<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends ConsumerState<IncidenciasScreen> {
  String _filtro = 'abierta';

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(incidenciasProvider);
    final l = _filtro == 'todas' ? todas : todas.where((i) => i.estado == _filtro).toList();
    if (_filtro == 'abierta') {
      const p = {'alta': 0, 'media': 1, 'baja': 2};
      l.sort((a, b) => (p[a.prioridad] ?? 1).compareTo(p[b.prioridad] ?? 1));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias'), actions: const [ChipEntorno()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        onPressed: () => nuevaIncidencia(context, ref),
        icon: const Icon(Icons.add_alert),
        label: const Text('Nueva'),
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'abierta',
                    label: Text('Abiertas (${todas.where((i) => i.estado == 'abierta').length})'),
                  ),
                  const ButtonSegment(value: 'resuelta', label: Text('Resueltas')),
                  const ButtonSegment(value: 'todas', label: Text('Todas')),
                ],
                selected: {_filtro},
                onSelectionChanged: (s) => setState(() => _filtro = s.first),
              ),
            ),
            Expanded(
              child: l.isEmpty
                  ? const Vacio(icono: Icons.verified, texto: 'Nada por aquí 👍')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                      itemCount: l.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (c, i) => _TarjetaIncidencia(l[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaIncidencia extends ConsumerWidget {
  const _TarjetaIncidencia(this.i);
  final Incidencia i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesa = ref.watch(mesaPorIdProvider)[i.mesaId];
    final muestra = ref.watch(muestraPorIdProvider)[i.muestraId];
    final catador = ref.watch(catadorPorIdProvider)[i.catadorId];
    final tipo = tiposIncidencia[i.tipo] ?? tiposIncidencia['otro']!;
    final abierta = i.estado == 'abierta';
    final color = switch (i.prioridad) {
      'alta' => Colors.red.shade700,
      'media' => Colors.orange.shade700,
      _ => Colors.blueGrey,
    };
    final repo = ref.read(repoProvider)!;
    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 8, color: abierta ? color : Colors.transparent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Icon(tipo.$2, size: 40, color: abierta ? color : Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipo.$1, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          if (i.descripcion != null) Text(i.descripcion!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (i.creada != null) _hora.format(i.creada!),
                              mesa?.nombre,
                              muestra?.codigo,
                              catador?.completo,
                              if (!abierta && i.resuelta != null) 'resuelta ${_hora.format(i.resuelta!)}',
                            ].whereType<String>().join(' · '),
                            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    abierta
                        ? FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
                            onPressed: () =>
                                ejecutar(context, () => repo.resolverIncidencia(i.id, true), ok: 'Resuelta'),
                            child: const Icon(Icons.check),
                          )
                        : IconButton(
                            tooltip: 'Reabrir',
                            onPressed: () => ejecutar(context, () => repo.resolverIncidencia(i.id, false)),
                            icon: const Icon(Icons.undo),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
