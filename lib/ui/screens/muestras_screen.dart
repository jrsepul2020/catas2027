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

/// Modal de muestra: puntuaciones de la mesa, total, medalla y observaciones.
class _HojaMuestra extends ConsumerStatefulWidget {
  const _HojaMuestra({required this.muestraId});
  final int muestraId;
  @override
  ConsumerState<_HojaMuestra> createState() => _HojaMuestraState();
}

class _HojaMuestraState extends ConsumerState<_HojaMuestra> {
  late final TextEditingController _obs;
  var _iniciado = false;

  @override
  void dispose() {
    if (_iniciado) _obs.dispose();
    super.dispose();
  }

  static String _fmt(double? v) {
    if (v == null) return '–';
    final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(muestraPorIdProvider)[widget.muestraId];
    if (m == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Text('Muestra no encontrada'));
    }
    if (!_iniciado) {
      _obs = TextEditingController(text: m.observaciones ?? '');
      _iniciado = true;
    }
    final repo = ref.read(repoProvider)!;
    final cats = ref.watch(categoriasProvider);
    final catNombre = {for (final c in cats) c.id: c.nombre};
    final tm = ref.watch(tandaMuestrasProvider).where((x) => x.muestraId == m.id).firstOrNull;
    final tanda = tm == null ? null : ref.watch(tandaPorIdProvider)[tm.tandaId];
    final mesa = tanda == null ? null : ref.watch(mesaPorIdProvider)[tanda.mesaId];
    final notas = ref.watch(puntuacionesProvider).where((p) => p.muestraId == m.id).toList();
    final porCatador = {for (final n in notas) n.catadorId: n};
    final catadoresIdx = ref.watch(catadorPorIdProvider);
    final deMesa = tanda?.mesaId == null ? const <Catador>[] : ref.watch(catadoresDeMesaProvider(tanda!.mesaId!));
    // Filas: puestos de la mesa; si no hay mesa, los catadores que ya puntuaron.
    final filas = deMesa.isNotEmpty
        ? deMesa
        : [
            for (final n
                in [...notas]..sort((a, b) {
                  final pa = catadoresIdx[a.catadorId]?.puesto ?? 999;
                  final pb = catadoresIdx[b.catadorId]?.puesto ?? 999;
                  return pa.compareTo(pb);
                }))
              catadoresIdx[n.catadorId],
          ].whereType<Catador>().toList();
    final resultado = ref.watch(resultadosProvider).where((r) => r.muestraId == m.id).firstOrNull;
    final k = esCompacto(context);
    final info = tm == null ? null : infoTM(tm.estado);
    final media = resultado?.media;
    final medallaClave = resultado?.medalla;

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
              style: TextStyle(fontSize: k ? 42 : 52, fontWeight: FontWeight.w900, height: 1.05, color: Virtus.marino),
            ),
            if (m.codigoTexto != null && m.codigoTexto != m.codigo)
              Text(
                m.codigoTexto!,
                textAlign: TextAlign.center,
                style: VirtusTexto.titulo(size: k ? 15 : 17),
              ),
            if (catNombre[m.categoriaId] != null)
              Text(
                catNombre[m.categoriaId]!,
                textAlign: TextAlign.center,
                style: VirtusTexto.tenue(size: k ? 12 : 13),
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
                    style: VirtusTexto.titulo(size: 15),
                  )
                else
                  Text('Sin tanda', style: VirtusTexto.titulo(size: 15)),
              ],
            ),
            if (notas.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Puntuaciones', style: VirtusTexto.titulo(size: k ? 15 : 17)),
                  ),
                  if (media != null)
                    Text(
                      'Total ${_fmt(media)}',
                      style: VirtusTexto.importante(size: k ? 18 : 20, color: Virtus.marino),
                    ),
                  if (medallaClave != null) ...[const SizedBox(width: 10), Medalla(medallaClave)],
                ],
              ),
              if (medallaClave != null) ...[
                const SizedBox(height: 4),
                Text(
                  resultado?.oficial != null
                      ? 'Medalla oficial: ${medallas[resultado!.oficial]?.$1 ?? resultado.oficial}'
                      : 'Medalla propuesta: ${medallas[resultado?.propuesta]?.$1 ?? resultado?.propuesta ?? ''}',
                  style: VirtusTexto.tenue(size: k ? 11 : 12),
                  textAlign: TextAlign.end,
                ),
              ],
              const SizedBox(height: 8),
              CajaBorde(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < filas.length; i++) ...[
                      if (i > 0) const SeparadorFino(),
                      _FilaNota(catador: filas[i], nota: porCatador[filas[i].id], fmt: _fmt),
                    ],
                    if (filas.isEmpty)
                      for (final n in notas) ...[
                        if (n != notas.first) const SeparadorFino(),
                        _FilaNota(catador: catadoresIdx[n.catadorId], nota: n, fmt: _fmt),
                      ],
                  ],
                ),
              ),
            ],
            if (tm != null) ...[
              const SizedBox(height: 14),
              Text('Acciones de cata', style: VirtusTexto.titulo(size: k ? 15 : 17)),
              const SizedBox(height: 6),
              if (tm.estado != 'activa')
                AccionHoja(
                  icono: Icons.play_circle_outline,
                  color: Virtus.advertencia,
                  titulo: 'Abrir para cata',
                  subtitulo: 'La pone como ACTIVA (la ven las tablets)',
                  onTap: () async {
                    final ok = await ejecutar(context, () => repo.activarMuestra(tm.id), ok: '${m.codigo} activa');
                    if (ok && context.mounted) Navigator.pop(context);
                  },
                ),
              AccionHoja(
                icono: Icons.replay_outlined,
                color: Virtus.accion,
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
                color: Virtus.marino,
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
            const SizedBox(height: 14),
            Text('Observaciones', style: VirtusTexto.titulo(size: k ? 15 : 17)),
            const SizedBox(height: 6),
            Campo(_obs, 'Nota del coordinador', lineas: 3),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: Size(0, k ? 52 : 60)),
              onPressed: () async {
                final texto = _obs.text.trim();
                final ok = await ejecutar(
                  context,
                  () => repo.actualizar('muestras', m.id, {'observaciones': texto.isEmpty ? null : texto}),
                  ok: 'Observaciones guardadas',
                  accion: 'Guardar observaciones de muestra',
                  refrescar: const ['muestras'],
                );
                if (ok && context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('Guardar observaciones'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaNota extends StatelessWidget {
  const _FilaNota({required this.catador, required this.nota, required this.fmt});
  final Catador? catador;
  final Puntuacion? nota;
  final String Function(double?) fmt;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final puesto = catador?.puesto;
    final nombre = catador?.nombre ?? 'Catador ${nota?.catadorId ?? ''}';
    final estado = nota == null ? null : estadosNota[nota!.estado];
    final total = nota?.total;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: k ? 12 : 14, vertical: k ? 10 : 12),
      child: Row(
        children: [
          Container(
            width: k ? 32 : 36,
            height: k ? 32 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: catador?.esPresidente == true ? Virtus.exitoSuave : Virtus.accionSuave,
              borderRadius: BorderRadius.circular(Virtus.radioSm),
            ),
            child: Text(
              puesto?.toString() ?? '–',
              style: VirtusTexto.importante(size: k ? 14 : 15, color: Virtus.marino),
            ),
          ),
          SizedBox(width: k ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VirtusTexto.titulo(size: k ? 13 : 14),
                ),
                Text(
                  [
                    if (catador?.esPresidente == true) 'Presidente',
                    if (estado != null) estado.$1,
                    if (nota == null) 'Sin nota',
                  ].whereType<String>().join(' · '),
                  style: VirtusTexto.tenue(size: k ? 11 : 12),
                ),
              ],
            ),
          ),
          Text(
            fmt(total),
            style: VirtusTexto.importante(size: k ? 18 : 20, color: total == null ? Virtus.textoTenue : Virtus.texto),
          ),
        ],
      ),
    );
  }
}
