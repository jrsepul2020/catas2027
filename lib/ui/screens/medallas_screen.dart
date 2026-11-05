import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';

class MedallasScreen extends ConsumerStatefulWidget {
  const MedallasScreen({super.key});
  @override
  ConsumerState<MedallasScreen> createState() => _MedallasScreenState();
}

class _MedallasScreenState extends ConsumerState<MedallasScreen> {
  String? _filtro;

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(resultadosProvider);
    final cata = ref.watch(cataProvider);
    final todos = res.value ?? const <Resultado>[];
    final conNota = todos.where((r) => r.nota != null).toList()..sort((a, b) => (b.nota ?? 0).compareTo(a.nota ?? 0));
    final l = _filtro == null ? conNota : conNota.where((r) => r.medalla == _filtro).toList();
    final cuenta = <String, int>{};
    for (final r in conNota) {
      cuenta[r.medalla ?? ''] = (cuenta[r.medalla ?? ''] ?? 0) + 1;
    }
    final sinNota = todos.length - conNota.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medallas'),
        bottom: res.isLoading
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
        actions: [
          IconButton(
            tooltip: 'Copiar resultados',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              final txt = StringBuffer('Código\tNombre\tBodega\tNota\tMedalla\n');
              for (final r in conNota) {
                txt.writeln(
                  '${r.codigo}\t${r.nombre ?? ''}\t${r.bodega ?? ''}\t'
                  '${r.nota?.toStringAsFixed(2)}\t${medallas[r.medalla]?.$1 ?? ''}',
                );
              }
              Clipboard.setData(ClipboardData(text: txt.toString()));
              aviso(context, 'Resultados copiados (pegar en Excel)');
            },
          ),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 1000,
        child: Column(
          children: [
            SizedBox(
              height: 76,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Todas (${conNota.length})'),
                      selected: _filtro == null,
                      onSelected: (_) => setState(() => _filtro = null),
                    ),
                  ),
                  for (final e in medallas.entries)
                    if ((cuenta[e.key] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: CircleAvatar(backgroundColor: e.value.$2),
                          label: Text('${e.value.$1} (${cuenta[e.key]})'),
                          selected: _filtro == e.key,
                          onSelected: (_) => setState(() => _filtro = e.key),
                        ),
                      ),
                ],
              ),
            ),
            if (cata != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Gran Oro ≥ ${cata.umbralGranOro} · Oro ≥ ${cata.umbralOro} · Plata ≥ ${cata.umbralPlata}'
                  '${cata.umbralBronce != null ? ' · Bronce ≥ ${cata.umbralBronce}' : ''}'
                  '${cata.descartarExtremos ? ' · sin extremos' : ''}'
                  '${sinNota > 0 ? ' · $sinNota muestras sin notas' : ''}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            Expanded(
              child: res.hasError
                  ? Vacio(icono: Icons.error, texto: '${res.error}')
                  : l.isEmpty
                  ? const Vacio(icono: Icons.military_tech, texto: 'Aún no hay resultados')
                  : RefreshIndicator(
                      onRefresh: () => ref.refresh(resultadosProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
                        itemCount: l.length,
                        itemExtent: 88,
                        itemBuilder: (c, i) {
                          final r = l[i];
                          return ListTile(
                            leading: Medalla(r.medalla, grande: true),
                            title: Text(
                              '${i + 1}. ${r.codigo}${r.nombre != null ? ' · ${r.nombre}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                r.bodega,
                                '${r.n} notas',
                                if (r.minimo != null) 'min ${r.minimo} · máx ${r.maximo}',
                                if (r.manual) 'MANUAL',
                              ].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              r.nota!.toStringAsFixed(2).replaceAll('.', ','),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                            ),
                            onTap: () => _cambiarMedalla(context, r),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarMedalla(BuildContext context, Resultado r) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Medalla de ${r.codigo}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ListTile(
              leading: const Icon(Icons.auto_mode, size: 40),
              title: const Text('Automática (por nota)'),
              onTap: () => Navigator.pop(s, 'auto'),
            ),
            for (final e in medallas.entries)
              ListTile(leading: Medalla(e.key), title: Text(e.value.$1), onTap: () => Navigator.pop(s, e.key)),
          ],
        ),
      ),
    );
    if (v == null || !context.mounted) return;
    await ejecutar(
      context,
      () => ref.read(repoProvider)!.actualizar('muestras', r.muestraId, {'medalla_manual': v == 'auto' ? null : v}),
    );
  }
}
