import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'catas_screen.dart';

class MedallasScreen extends ConsumerStatefulWidget {
  const MedallasScreen({super.key});
  @override
  ConsumerState<MedallasScreen> createState() => _MedallasScreenState();
}

class _MedallasScreenState extends ConsumerState<MedallasScreen> {
  String? _filtro;
  int? _categoria;

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(resultadosProvider);
    final concurso = ref.watch(concursoProvider);
    final cats = ref.watch(categoriasProvider);
    final catNombre = {for (final c in cats) c.id: c.nombre};
    final todos = (res.value ?? const <Resultado>[]).where((r) => _categoria == null || r.categoriaId == _categoria);
    final conNota = todos.where((r) => r.media != null).toList()
      ..sort((a, b) => (b.media ?? 0).compareTo(a.media ?? 0));
    final l = _filtro == null ? conNota : conNota.where((r) => r.medalla == _filtro).toList();
    final cuenta = <String, int>{};
    for (final r in conNota) {
      cuenta[r.medalla ?? ''] = (cuenta[r.medalla ?? ''] ?? 0) + 1;
    }
    final pendientesOficial = conNota
        .where((r) => r.oficial == null && !r.noPremia && const {'gran_oro', 'oro', 'plata'}.contains(r.propuesta))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medallas'),
        bottom: res.isLoading
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
        actions: [
          IconButton(
            tooltip: 'Copiar resultados (Excel)',
            icon: const Icon(Icons.copy_all),
            onPressed: () {
              final txt = StringBuffer('Código\tTexto\tCategoría\tNotas\tMedia\tPropuesta\tOficial\n');
              for (final r in conNota) {
                txt.writeln(
                  '${r.codigo}\t${r.codigoTexto ?? ''}\t${catNombre[r.categoriaId] ?? ''}\t${r.n}\t'
                  '${r.media?.toStringAsFixed(2).replaceAll('.', ',')}\t${medallas[r.propuesta]?.$1 ?? ''}\t'
                  '${medallas[r.oficial]?.$1 ?? ''}',
                );
              }
              Clipboard.setData(ClipboardData(text: txt.toString()));
              aviso(context, 'Resultados copiados (pegar en Excel)');
            },
          ),
          const ChipEntorno(),
        ],
      ),
      floatingActionButton: pendientesOficial.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _aprobarTodas(context, pendientesOficial),
              icon: const Icon(Icons.verified),
              label: Text('Oficializar ${pendientesOficial.length}'),
            ),
      body: Ancho(
        max: 1000,
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todas las categorías'),
                      selected: _categoria == null,
                      onSelected: (_) => setState(() => _categoria = null),
                    ),
                  ),
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.nombre),
                        selected: _categoria == c.id,
                        onSelected: (_) => setState(() => _categoria = c.id),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            if (concurso != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Gran Oro ≥ ${numCorto(concurso.granOro)} · Oro ≥ ${numCorto(concurso.oro)} · '
                  'Plata ≥ ${numCorto(concurso.plata)} · códigos < 1000 no premian',
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
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
                        itemCount: l.length,
                        itemExtent: 66,
                        itemBuilder: (c, i) {
                          final r = l[i];
                          return ListTile(
                            leading: Medalla(r.medalla, grande: true),
                            title: Text(
                              '${i + 1}. ${r.codigo}${r.codigoTexto != null && r.codigoTexto != r.codigo ? ' · ${r.codigoTexto}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                catNombre[r.categoriaId],
                                '${r.n} notas (${r.nAprobadas} aprob.)',
                                if (r.oficial != null) 'OFICIAL' else if (r.propuesta != null) 'propuesta',
                                if (r.noPremia) 'no premia',
                              ].whereType<String>().join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              r.media!.toStringAsFixed(2).replaceAll('.', ','),
                              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
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

  Future<void> _aprobarTodas(BuildContext context, List<Resultado> l) async {
    if (!await confirmar(
      context,
      'Oficializar ${l.length} medallas',
      texto: 'Se guardan en la tabla de medallas con la media actual.',
      si: 'Oficializar',
    )) {
      return;
    }
    if (!context.mounted) return;
    final repo = ref.read(repoProvider)!;
    await ejecutar(context, () async {
      for (final r in l) {
        await repo.fijarMedalla(r.muestraId, r.propuesta, r.media!);
      }
    }, ok: '${l.length} medallas oficiales');
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
            Text('Medalla oficial de ${r.codigo}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text('Media ${r.media?.toStringAsFixed(2)} · propuesta: ${medallas[r.propuesta]?.$1 ?? '—'}'),
            for (final e in medallas.entries)
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: esCompacto(s) ? 20 : 28,
                  vertical: esCompacto(s) ? 10 : 14,
                ),
                leading: Medalla(e.key),
                title: Text(
                  e.value.$1,
                  style: TextStyle(fontSize: esCompacto(s) ? 18 : 21, fontWeight: FontWeight.w800),
                ),
                trailing: r.oficial == e.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(s, e.key),
              ),
            if (r.oficial != null)
              AccionHoja(icono: Icons.undo, titulo: 'Quitar medalla oficial', onTap: () => Navigator.pop(s, '')),
          ],
        ),
      ),
    );
    if (v == null || !context.mounted) return;
    await ejecutar(
      context,
      () => ref.read(repoProvider)!.fijarMedalla(r.muestraId, v.isEmpty ? null : v, r.media ?? 0),
    );
  }
}
