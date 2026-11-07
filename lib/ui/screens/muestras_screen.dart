import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';

class MuestrasScreen extends ConsumerStatefulWidget {
  const MuestrasScreen({super.key});
  @override
  ConsumerState<MuestrasScreen> createState() => _MuestrasScreenState();
}

class _MuestrasScreenState extends ConsumerState<MuestrasScreen> {
  String _q = '';
  int? _categoria;

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(muestrasProvider);
    final cats = ref.watch(categoriasProvider);
    final enTanda = <int, TandaMuestra>{for (final tm in ref.watch(tandaMuestrasProvider)) tm.muestraId: tm};
    final tandas = ref.watch(tandaPorIdProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    final q = _q.toLowerCase();
    final l = todas.where((m) {
      if (_categoria != null && m.categoriaId != _categoria) return false;
      if (q.isEmpty) return true;
      return m.codigo.toLowerCase().contains(q) || (m.codigoTexto?.toLowerCase().contains(q) ?? false);
    }).toList();
    final catNombre = {for (final c in cats) c.id: c.nombre};

    final k = esCompacto(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Muestras (${l.length}/${todas.length})'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Categoría',
            icon: Icon(Icons.filter_list, color: _categoria == null ? null : cs.primary),
            onSelected: (v) => setState(() => _categoria = v == -1 ? null : v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: -1, checked: _categoria == null, child: const Text('Todas')),
              for (final c in cats)
                CheckedPopupMenuItem(value: c.id, checked: _categoria == c.id, child: Text(c.nombre)),
            ],
          ),
          IconButton(
            tooltip: 'Nueva muestra',
            onPressed: () => editarMuestra(context, ref, null),
            icon: const Icon(Icons.add),
          ),
          const ChipEntorno(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(10, k ? 4 : 10, 10, k ? 6 : 10),
            child: SearchBar(
              hintText: _categoria == null ? 'Código ciego o de texto…' : 'Buscar en ${catNombre[_categoria]}',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
              constraints: BoxConstraints(minHeight: k ? 44 : 56),
              textStyle: WidgetStatePropertyAll(TextStyle(fontSize: k ? 16 : 19, color: cs.onSurface)),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            // Rejilla compacta: el máximo de muestras por pantalla.
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: k ? 96 : 130,
                mainAxisExtent: k ? 58 : 72,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: l.length,
              itemBuilder: (c, i) {
                final m = l[i];
                final tm = enTanda[m.id];
                final t = tandas[tm?.tandaId];
                final info = tm == null ? null : infoTM(tm.estado);
                final color = !m.activa ? Colors.grey : (info?.$3 ?? Colors.blue);
                return Material(
                  color: tm == null ? Colors.white : color.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: color.shade200),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => editarMuestra(context, ref, m),
                    onLongPress: () => aviso(
                      context,
                      [
                        m.titulo,
                        catNombre[m.categoriaId],
                        if (t != null) '${mesas[t.mesaId]?.nombre ?? ''} · ${t.nombre} · ${info!.$1}',
                        if (m.noPremia) 'no premia',
                      ].whereType<String>().join(' · '),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m.codigo,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: k ? 17 : 21,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              decoration: m.activa ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (info != null) Icon(info.$2, size: k ? 11 : 14, color: color.shade700),
                              if (info != null) const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  t == null ? 'sin tanda' : 'T${t.numero}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: k ? 11 : 13, color: cs.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> editarMuestra(BuildContext context, WidgetRef ref, Muestra? m) async {
  final repo = ref.read(repoProvider)!;
  final cats = ref.read(categoriasProvider);
  final codigo = TextEditingController(text: m?.codigo ?? '');
  final texto = TextEditingController(text: m?.codigoTexto ?? '');
  int? categoria = m?.categoriaId ?? (cats.isNotEmpty ? cats.first.id : null);
  var activa = m?.activa ?? true;
  await hojaFormulario(
    context,
    titulo: m == null ? 'Nueva muestra' : 'Muestra ${m.codigo}',
    campos: [
      Campo(codigo, 'Código ciego (1–9999)', numero: true, autofocus: m == null),
      Campo(texto, 'Código de texto / referencia'),
      StatefulBuilder(
        builder: (c, set) => Column(
          children: [
            DropdownButtonFormField<int?>(
              initialValue: categoria,
              isExpanded: true,
              style: TextStyle(fontSize: 19, color: Theme.of(c).colorScheme.onSurface),
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [for (final x in cats) DropdownMenuItem(value: x.id, child: Text(x.nombre))],
              onChanged: (v) => set(() => categoria = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              subtitle: const Text('Las inactivas no se catan'),
              value: activa,
              onChanged: (v) => set(() => activa = v),
            ),
          ],
        ),
      ),
    ],
    borrar: m == null ? null : () => repo.borrar('muestras', m.id),
    guardar: () async {
      final d = {
        'codigo_ciego': codigo.text.trim(),
        'codigo_texto': texto.text.trim().isEmpty ? codigo.text.trim() : texto.text.trim(),
        'categoria_id': categoria,
        'activo': activa,
      };
      m == null
          ? await repo.insertar('muestras', {...d, 'concurso_id': ref.read(concursoIdProvider)})
          : await repo.actualizar('muestras', m.id, d);
    },
  );
}
