import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../marca.dart';
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
    final reservas = ref.watch(tabletsLibresProvider).length;

    final tiles = [
      Baldosa(
        icono: Icons.live_tv_outlined,
        texto: 'En directo',
        sub: '$catando de ${mesas.length} mesas catando',
        color: Virtus.error,
        onTap: () => context.go('/directo'),
      ),
      Baldosa(
        icono: Icons.table_restaurant_outlined,
        texto: 'Mesas',
        sub: '${mesas.length} mesas',
        color: Virtus.accion,
        onTap: () => context.go('/mesas'),
      ),
      Baldosa(
        icono: Icons.grid_view_outlined,
        texto: 'Puntuaciones',
        sub: '${punt.length} notas',
        color: Virtus.advertencia,
        onTap: () => context.go('/puntuar'),
      ),
      Baldosa(
        icono: Icons.format_list_numbered_outlined,
        texto: 'Tandas',
        sub: '$abiertas abiertas · $cerradas cerradas',
        color: Virtus.exito,
        onTap: () => context.go('/tandas'),
      ),
      Baldosa(
        icono: Icons.warning_amber_outlined,
        texto: 'Incidencias',
        sub: inc == 0 ? 'Sin abiertas' : '$inc abiertas',
        color: Virtus.error,
        badge: inc,
        onTap: () => context.go('/incidencias'),
      ),
      Baldosa(
        icono: Icons.groups_outlined,
        texto: 'Catadores',
        sub: '$conectados/${catadores.length} tablet${ausentes > 0 ? ' · $ausentes aus.' : ''}',
        color: Virtus.accion,
        onTap: () => context.go('/catadores'),
      ),
      Baldosa(
        icono: Icons.wine_bar_outlined,
        texto: 'Muestras',
        sub: '${muestras.where((m) => m.activa).length} activas',
        color: Virtus.marino,
        onTap: () => context.go('/muestras'),
      ),
      Baldosa(
        icono: Icons.military_tech_outlined,
        texto: 'Medallas',
        sub: 'Resultados',
        color: Virtus.advertencia,
        onTap: () => context.go('/medallas'),
      ),
      Baldosa(
        icono: Icons.fact_check_outlined,
        texto: 'Auditoría',
        sub: reservas > 0 ? 'Chequeos · $reservas reserva${reservas == 1 ? '' : 's'}' : 'Incongruencias del día',
        color: Virtus.textoSecundario,
        onTap: () => context.go('/auditoria'),
      ),
      // Sincronizar: engranaje de la barra / rail (mantiene 9 baldosas sin scroll en el Redmi).
    ];

    final cols = k ? 3 : (MediaQuery.sizeOf(context).width >= 1100 ? 5 : 3);
    final problema = avisoCarga(
      ref,
      que: 'Cargar el panel de inicio',
      tablas: const ['mesas', 'tandas', 'catadores', 'muestras', 'puntuaciones', 'tanda_muestras'],
      vacio: !cargando && mesas.isEmpty && tandas.isEmpty && catadores.isEmpty,
      queHacerSiVacio: 'No hay mesas, tandas ni catadores. Elige el concurso correcto o sincroniza / revisa CLOUD.',
    );

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.only(left: 12), child: IconoCataris(tamano: 32, fondoOscuro: true)),
        leadingWidth: 48,
        title: Text(concurso?.nombre ?? MarcaApp.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          const ChipDia(),
          if (!esAncho(context)) ...[
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: () => context.push('/sync'),
              icon: const Icon(Icons.sync_outlined),
            ),
            IconButton(
              tooltip: 'Ajustes',
              onPressed: () => context.push('/configuracion'),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => cerrarSesion(context, ref),
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
          const ChipEntorno(),
        ],
      ),
      body:
          problema ??
          Ancho(
            max: 1200,
            child: LayoutBuilder(
              builder: (c, box) {
                // Las baldosas se ajustan para caber sin scroll.
                final pad = k ? 10.0 : 16.0;
                final gap = k ? 8.0 : 14.0;
                final filas = (tiles.length / cols).ceil();
                final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
                final h = box.maxHeight.isFinite ? box.maxHeight : 600.0;
                final ancho = (w - pad * 2 - gap * (cols - 1)) / cols;
                final alto = ((h - pad * 2 - gap * (filas - 1)) / filas).clamp(90.0, ancho * 1.1);
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
