import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
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
        leading: botonVolver(context),
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

Future<void> editarMuestra(BuildContext context, WidgetRef ref, Muestra m) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => _HojaMuestra(muestraId: m.id),
  );
}

/// Modal de muestra existente: código grande, estado, notas y acciones de tanda.
class _HojaMuestra extends ConsumerStatefulWidget {
  const _HojaMuestra({required this.muestraId});
  final int muestraId;
  @override
  ConsumerState<_HojaMuestra> createState() => _HojaMuestraState();
}

class _HojaMuestraState extends ConsumerState<_HojaMuestra> {
  late final TextEditingController _texto;
  late int? _categoria;
  late bool _activa;
  var _iniciado = false;

  @override
  void dispose() {
    if (_iniciado) _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(muestraPorIdProvider)[widget.muestraId];
    if (m == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('Muestra no encontrada'));
    }
    if (!_iniciado) {
      _texto = TextEditingController(text: m.codigoTexto ?? '');
      _categoria = m.categoriaId;
      _activa = m.activa;
      _iniciado = true;
    }
    final repo = ref.read(repoProvider)!;
    final cats = ref.watch(categoriasProvider);
    final tm = ref.watch(tandaMuestrasProvider).where((x) => x.muestraId == m.id).firstOrNull;
    final tanda = tm == null ? null : ref.watch(tandaPorIdProvider)[tm.tandaId];
    final mesa = tanda == null ? null : ref.watch(mesaPorIdProvider)[tanda.mesaId];
    final notas = ref.watch(puntuacionesProvider).where((p) => p.muestraId == m.id).toList()
      ..sort((a, b) => a.catadorId.compareTo(b.catadorId));
    final catadores = ref.watch(catadorPorIdProvider);
    final k = esCompacto(context);
    final info = tm == null ? null : infoTM(tm.estado);
    final conTotal = notas.where((n) => n.total != null).toList();
    final mediaFinal = conTotal.isEmpty
        ? null
        : conTotal.map((n) => n.total!).reduce((a, b) => a + b) / conTotal.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              m.codigo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: k ? 42 : 52,
                fontWeight: FontWeight.w900,
                height: 1.05,
                color: Paleta.azulOscuro,
              ),
            ),
            if (m.codigoTexto != null && m.codigoTexto != m.codigo)
              Text(
                m.codigoTexto!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: k ? 16 : 18, fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (info != null) EtiquetaEstado(info),
                if (tanda != null)
                  Text(
                    [mesa?.nombre, tanda.nombre].whereType<String>().join(' · '),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  )
                else
                  const Text('Sin tanda', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (mediaFinal != null)
                  Text(
                    'Media ${mediaFinal.toStringAsFixed(1).replaceAll('.', ',')}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.azulOscuro),
                  ),
              ],
            ),
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Puntuaciones',
                style: TextStyle(fontSize: k ? 15 : 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in notas)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: (estadosNota[n.estado]?.$3 ?? Colors.blue).shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'P${catadores[n.catadorId]?.puesto ?? '–'} '
                        '${n.total?.toStringAsFixed(n.total == n.total!.roundToDouble() ? 0 : 1).replaceAll('.', ',') ?? '–'}'
                        ' · ${estadosNota[n.estado]?.$1 ?? n.estado}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ],
            if (tm != null) ...[
              const SizedBox(height: 14),
              Text(
                'Acciones de cata',
                style: TextStyle(fontSize: k ? 15 : 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (tm.estado != 'activa')
                AccionHoja(
                  icono: Icons.play_circle_fill,
                  color: Paleta.amarillo,
                  titulo: 'Abrir para cata',
                  subtitulo: 'La pone como ACTIVA (la ven las tablets)',
                  onTap: () async {
                    final ok = await ejecutar(context, () => repo.activarMuestra(tm.id), ok: '${m.codigo} activa');
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
              AccionHoja(
                icono: Icons.replay,
                color: Paleta.lila,
                titulo: 'Recatar desde cero',
                subtitulo: 'Borra notas (quedan en el registro) y vuelve a pendiente',
                onTap: () async {
                  if (!await confirmar(
                    context,
                    '¿Recatar ${m.codigo}?',
                    texto: 'Se borran las notas actuales (quedan en el registro) y la muestra queda pendiente.',
                    si: 'Recatar',
                  )) {
                    return;
                  }
                  if (!context.mounted) return;
                  final ok = await ejecutar(
                    context,
                    () => repo.resolverIncidencia(tm.id, 'recatar', motivo: 'Recatar desde muestras'),
                  );
                  if (ok && context.mounted) Navigator.pop(context);
                },
              ),
              AccionHoja(
                icono: Icons.low_priority,
                color: Paleta.azul,
                titulo: 'Pasar al final de la tanda',
                subtitulo: 'Borra notas y la coloca la última',
                onTap: () async {
                  if (!await confirmar(
                    context,
                    '¿Pasar ${m.codigo} al final?',
                    texto: 'Se borran las notas y la muestra pasa al final de su tanda.',
                    si: 'Pasar',
                  )) {
                    return;
                  }
                  if (!context.mounted) return;
                  final ok = await ejecutar(
                    context,
                    () => repo.resolverIncidencia(tm.id, 'pasar_al_final', motivo: 'Pasar al final desde muestras'),
                  );
                  if (ok && context.mounted) Navigator.pop(context);
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Datos',
              style: TextStyle(fontSize: k ? 15 : 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Campo(_texto, 'Código de texto / referencia'),
            DropdownButtonFormField<int?>(
              initialValue: _categoria,
              isExpanded: true,
              style: TextStyle(fontSize: 19, color: Theme.of(context).colorScheme.onSurface),
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [for (final x in cats) DropdownMenuItem(value: x.id, child: Text(x.nombre))],
              onChanged: (v) => setState(() => _categoria = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activa'),
              subtitle: const Text('Las inactivas no se catan'),
              value: _activa,
              onChanged: (v) => setState(() => _activa = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () async {
                    if (await confirmar(context, '¿Eliminar muestra ${m.codigo}?', si: 'Eliminar') && context.mounted) {
                      if (await ejecutar(context, () => repo.borrar('muestras', m.id)) && context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Eliminar'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: Size(0, k ? 52 : 60)),
                    onPressed: () async {
                      final ok = await ejecutar(context, () async {
                        await repo.actualizar('muestras', m.id, {
                          'codigo_texto': _texto.text.trim().isEmpty ? m.codigo : _texto.text.trim(),
                          'categoria_id': _categoria,
                          'activo': _activa,
                        });
                      });
                      if (ok && context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
