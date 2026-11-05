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

  @override
  Widget build(BuildContext context) {
    final todas = ref.watch(muestrasProvider);
    final enTanda = {for (final tm in ref.watch(tandaMuestrasProvider)) tm.muestraId: tm.tandaId};
    final tandas = {for (final t in ref.watch(tandasProvider)) t.id: t};
    final mesas = ref.watch(mesaPorIdProvider);
    final q = _q.toLowerCase();
    final l = q.isEmpty
        ? todas
        : todas
              .where(
                (m) => [m.codigo, m.nombre, m.bodega, m.categoria].any((s) => s?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    return Scaffold(
      appBar: AppBar(title: Text('Muestras (${todas.length})'), actions: const [ChipEntorno()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarMuestra(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Muestra'),
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SearchBar(
                hintText: 'Código, nombre, bodega…',
                leading: const Icon(Icons.search),
                constraints: const BoxConstraints(minHeight: 60),
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 19)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: l.length,
                itemExtent: 84,
                itemBuilder: (c, i) {
                  final m = l[i];
                  final t = tandas[enTanda[m.id]];
                  return ListTile(
                    leading: Container(
                      width: 72,
                      alignment: Alignment.center,
                      child: Text(m.codigo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ),
                    title: Text(m.nombre ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        m.categoria,
                        m.anada?.toString(),
                        t == null ? 'Sin tanda' : '${mesas[t.mesaId]?.nombre ?? ''} · ${t.nombre}',
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => editarMuestra(context, ref, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> editarMuestra(BuildContext context, WidgetRef ref, Muestra? m) async {
  final repo = ref.read(repoProvider)!;
  final n = ref.read(muestrasProvider).length + 1;
  final codigo = TextEditingController(text: m?.codigo ?? 'M${n.toString().padLeft(3, '0')}');
  final nombre = TextEditingController(text: m?.nombre ?? '');
  final bodega = TextEditingController(text: m?.bodega ?? '');
  final cat = TextEditingController(text: m?.categoria ?? '');
  final tipo = TextEditingController(text: m?.tipo ?? '');
  final anada = TextEditingController(text: m?.anada?.toString() ?? '');
  String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
  await hojaFormulario(
    context,
    titulo: m == null ? 'Nueva muestra' : 'Muestra ${m.codigo}',
    campos: [
      Campo(codigo, 'Código anónimo'),
      Campo(nombre, 'Nombre del vino', autofocus: m == null),
      Campo(bodega, 'Bodega'),
      Row(
        children: [
          Expanded(child: Campo(cat, 'Categoría')),
          const SizedBox(width: 10),
          Expanded(child: Campo(tipo, 'Tipo')),
        ],
      ),
      Campo(anada, 'Añada', numero: true),
    ],
    borrar: m == null ? null : () => repo.borrar('muestras', m.id),
    guardar: () async {
      final d = {
        'codigo': codigo.text.trim(),
        'nombre': t(nombre),
        'bodega': t(bodega),
        'categoria': t(cat),
        'tipo': t(tipo),
        'anada': int.tryParse(anada.text.trim()),
      };
      m == null
          ? await repo.insertar('muestras', {...d, 'cata_id': ref.read(cataIdProvider)})
          : await repo.actualizar('muestras', m.id, d);
    },
  );
}
