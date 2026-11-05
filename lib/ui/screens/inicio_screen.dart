import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../widgets.dart';

class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cata = ref.watch(cataProvider);
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final catadores = ref.watch(catadoresProvider);
    final muestras = ref.watch(muestrasProvider);
    final punt = ref.watch(puntuacionesProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final cargando = ref.watch(cargandoProvider);

    final enCurso = tandas.where((t) => t.estado == 'en_curso').length;
    final cerradas = tandas.where((t) => t.estado == 'cerrada').length;
    final ausentes = catadores.where((c) => !c.presente).length;
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1300
        ? 5
        : w >= 900
        ? 4
        : w >= 600
        ? 3
        : 2;

    final tiles = [
      Baldosa(
        icono: Icons.table_restaurant,
        texto: 'Mesas',
        sub: '${mesas.where((m) => m.estado == 'catando').length} catando de ${mesas.length}',
        onTap: () => context.go('/mesas'),
      ),
      Baldosa(
        icono: Icons.format_list_numbered,
        texto: 'Tandas',
        sub: '$enCurso en curso · $cerradas cerradas',
        color: Colors.deepPurple,
        onTap: () => context.go('/tandas'),
      ),
      Baldosa(
        icono: Icons.edit_note,
        texto: 'Puntuar',
        sub: '${punt.length} notas',
        color: Colors.green.shade700,
        onTap: () => context.go('/puntuar'),
      ),
      Baldosa(
        icono: Icons.warning_amber_rounded,
        texto: 'Incidencias',
        sub: inc == 0 ? 'Sin abiertas' : '$inc abiertas',
        color: Colors.orange.shade800,
        badge: inc,
        onTap: () => context.go('/incidencias'),
      ),
      Baldosa(
        icono: Icons.groups,
        texto: 'Catadores',
        sub: '${catadores.length}${ausentes > 0 ? ' · $ausentes ausentes' : ''}',
        color: Colors.blue.shade700,
        onTap: () => context.go('/catadores'),
      ),
      Baldosa(
        icono: Icons.wine_bar,
        texto: 'Muestras',
        sub: '${muestras.length}',
        color: Colors.red.shade800,
        onTap: () => context.go('/muestras'),
      ),
      Baldosa(
        icono: Icons.military_tech,
        texto: 'Medallas',
        sub: 'Resultados',
        color: const Color(0xFFB8860B),
        onTap: () => context.go('/medallas'),
      ),
      Baldosa(
        icono: Icons.sync,
        texto: 'Sincronizar',
        sub: 'Cloud ⇄ Local',
        color: Colors.teal.shade700,
        onTap: () => context.push('/sync'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cata?.nombre ?? 'Catas'),
            if (cata?.lugar != null || cata?.fecha != null)
              Text(
                [cata?.fecha, cata?.lugar].whereType<String>().join(' · '),
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
        actions: [
          if (!esAncho(context))
            IconButton(onPressed: () => context.push('/ajustes'), icon: const Icon(Icons.settings)),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 1400,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid.count(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: tiles,
              ),
            ),
            if (mesas.isNotEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('En directo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList.separated(
                itemCount: mesas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (c, i) => _MesaEnDirecto(mesaId: mesas[i].id),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MesaEnDirecto extends ConsumerWidget {
  const _MesaEnDirecto({required this.mesaId});
  final String mesaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesa = ref.watch(mesaPorIdProvider)[mesaId]!;
    final tandas = ref.watch(tandasDeMesaProvider(mesaId));
    final cats = ref.watch(catadoresDeMesaProvider(mesaId)).where((c) => c.presente).toList();
    final actual =
        tandas.where((t) => t.estado == 'en_curso').firstOrNull ??
        tandas.where((t) => t.estado == 'pendiente').firstOrNull;
    final idx = ref.watch(puntuacionIdxProvider);
    var hechas = 0, total = 0;
    if (actual != null) {
      final ms = ref.watch(muestrasDeTandaProvider(actual.id));
      total = ms.length * cats.length;
      for (final m in ms) {
        for (final c in cats) {
          if (idx['${m.muestraId}|${c.id}']?.puntos != null) hechas++;
        }
      }
    }
    final cerr = tandas.where((t) => t.estado == 'cerrada').length;
    return Card(
      child: InkWell(
        onTap: () => context.go('/mesas/$mesaId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                child: Text('${mesa.numero}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(mesa.nombre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        EtiquetaEstado(estadosMesa[mesa.estado]!),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      actual == null
                          ? 'Todas las tandas cerradas ($cerr/${tandas.length})'
                          : '${actual.nombre} · ${estadosTanda[actual.estado]!.$1} · $hechas/$total notas · tandas $cerr/${tandas.length}',
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: hechas / total,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ],
                ),
              ),
              if (actual != null)
                IconButton.filledTonal(
                  tooltip: 'Puntuar',
                  onPressed: () => context.go('/puntuar/${actual.id}'),
                  icon: const Icon(Icons.edit_note),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
