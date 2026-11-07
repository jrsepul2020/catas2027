import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../theme.dart';
import '../widgets.dart';

/// Panel principal: todas las secciones en una pantalla, sin scroll en el teléfono.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concurso = ref.watch(concursoProvider);
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final catadores = ref.watch(catadoresProvider);
    final muestras = ref.watch(muestrasProvider);
    final punt = ref.watch(puntuacionesProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final cargando = ref.watch(cargandoProvider);
    final k = esCompacto(context);

    final abiertas = tandas.where((t) => t.estado == 'abierta').length;
    final cerradas = tandas.where((t) => t.estado == 'cerrada').length;
    final ausentes = catadores.where((c) => !c.presente).length;
    final conectados = catadores.where((c) => c.conectado).length;
    final catando = mesas.where((m) => tandas.any((t) => t.mesaId == m.id && t.estado == 'abierta')).length;

    final tiles = [
      Baldosa(
        icono: Icons.live_tv,
        texto: 'En directo',
        sub: '$catando de ${mesas.length} mesas catando',
        color: Paleta.rojo,
        onTap: () => context.go('/directo'),
      ),
      Baldosa(
        icono: Icons.table_restaurant,
        texto: 'Mesas',
        sub: '${mesas.length} mesas',
        color: Paleta.azul,
        onTap: () => context.go('/mesas'),
      ),
      Baldosa(
        icono: Icons.grid_on,
        texto: 'Puntuaciones',
        sub: '${punt.length} notas',
        color: Paleta.amarillo,
        onTap: () => context.go('/puntuar'),
      ),
      Baldosa(
        icono: Icons.format_list_numbered,
        texto: 'Tandas',
        sub: '$abiertas abiertas · $cerradas cerradas',
        color: Paleta.lila,
        onTap: () => context.go('/tandas'),
      ),
      Baldosa(
        icono: Icons.warning_amber_rounded,
        texto: 'Incidencias',
        sub: inc == 0 ? 'Sin abiertas' : '$inc abiertas',
        color: Paleta.rojo,
        badge: inc,
        onTap: () => context.go('/incidencias'),
      ),
      Baldosa(
        icono: Icons.groups,
        texto: 'Catadores',
        sub: '$conectados/${catadores.length} tablet${ausentes > 0 ? ' · $ausentes aus.' : ''}',
        color: Paleta.azul,
        onTap: () => context.go('/catadores'),
      ),
      Baldosa(
        icono: Icons.wine_bar,
        texto: 'Muestras',
        sub: '${muestras.where((m) => m.activa).length} activas',
        color: Paleta.lila,
        onTap: () => context.go('/muestras'),
      ),
      Baldosa(
        icono: Icons.military_tech,
        texto: 'Medallas',
        sub: 'Resultados',
        color: Paleta.amarillo,
        onTap: () => context.go('/medallas'),
      ),
      Baldosa(
        icono: Icons.sync,
        texto: 'Sincronizar',
        sub: 'Cloud y Local',
        color: Paleta.azul,
        onTap: () => context.push('/sync'),
      ),
    ];

    final cols = k ? 3 : (MediaQuery.sizeOf(context).width >= 1100 ? 5 : 3);

    return Scaffold(
      appBar: AppBar(
        title: Text(concurso?.nombre ?? 'Catas 2027', maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          const ChipDia(),
          if (!esAncho(context))
            IconButton(onPressed: () => context.push('/configuracion'), icon: const Icon(Icons.settings)),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 1200,
        child: LayoutBuilder(
          builder: (c, box) {
            // Las baldosas se ajustan para caber sin scroll.
            final pad = k ? 10.0 : 16.0;
            final gap = k ? 8.0 : 14.0;
            final filas = (tiles.length / cols).ceil();
            final ancho = (box.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
            final alto = ((box.maxHeight - pad * 2 - gap * (filas - 1)) / filas).clamp(90.0, ancho * 1.1);
            return GridView.count(
              padding: EdgeInsets.all(pad),
              crossAxisCount: cols,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: ancho / alto,
              children: tiles,
            );
          },
        ),
      ),
    );
  }
}
