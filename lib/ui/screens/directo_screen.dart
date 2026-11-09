import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../theme.dart';
import '../widgets.dart';
import 'mesas_screen.dart';

/// En directo: una tarjeta grande por mesa con la tanda abierta, la muestra
/// activa y qué catadores ya han puntuado (un punto por puesto).
class DirectoScreen extends ConsumerWidget {
  const DirectoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final k = esCompacto(context);
    final problema =
        avisoCarga(
          ref,
          que: 'Cargar el directo (mesas y tandas del día)',
          tablas: const ['mesas', 'tandas', 'tanda_muestras', 'catadores', 'puntuaciones'],
          vacio: mesas.isEmpty,
          queHacerSiVacio: 'No hay mesas en este concurso. Créalas en Mesas o revisa el concurso elegido.',
        ) ??
        (mesas.isNotEmpty && tandas.isEmpty
            ? RecuadroProblema(
                que: 'Directo sin tandas para el día seleccionado',
                error: 'mesas=${mesas.length}, tandas filtradas=0 (mira el chip de día y el resumen del inicio)',
                queHacer:
                    'Pulsa el chip del calendario y elige el día donde están las tandas (o «Todos los días»). '
                    'Si el resumen del inicio muestra 0 tandas, la tabla no está llegando desde Cloud.',
              )
            : null);
    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: Paleta.rojo, shape: BoxShape.circle),
            ),
            const Flexible(child: Text('En directo', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          const BotonRefrescar(tooltip: 'Actualizar notas'),
          if (inc > 0)
            IconButton(
              tooltip: 'Incidencias abiertas',
              onPressed: () => context.go('/incidencias'),
              icon: Badge(
                label: Text('$inc'),
                backgroundColor: Paleta.rojo,
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
              ),
            ),
          const ChipDia(),
          const ChipEntorno(),
        ],
      ),
      body:
          problema ??
          Ancho(
            max: 1100,
            child: ListaLlena(
              itemCount: mesas.length,
              gap: k ? 8 : 12,
              padding: EdgeInsets.all(k ? 10 : 14),
              altoMinimo: k ? 110 : 130,
              itemBuilder: (c, i) => FilaDirecto(mesaId: mesas[i].id),
            ),
          ),
    );
  }
}

class FilaDirecto extends ConsumerWidget {
  const FilaDirecto({super.key, required this.mesaId});
  final int mesaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesa = ref.watch(mesaPorIdProvider)[mesaId];
    if (mesa == null) return const SizedBox.shrink();
    final tandas = ref.watch(tandasDeMesaProvider(mesaId));
    final cats = ref.watch(catadoresDeMesaProvider(mesaId)).where((c) => c.presente).toList();
    final actual =
        tandas.where((t) => t.estado == 'abierta').firstOrNull ??
        tandas.where((t) => t.estado == 'pendiente').firstOrNull;
    final idx = ref.watch(puntuacionIdxProvider);
    final muestras = ref.watch(muestraPorIdProvider);
    final k = esCompacto(context);
    final cs = Theme.of(context).colorScheme;

    var completadas = 0, total = 0, incid = 0;
    String? activa;
    final puntos = <String?>[]; // estado de la nota de cada catador en la muestra activa
    if (actual != null) {
      final tms = ref.watch(muestrasDeTandaProvider(actual.id));
      total = tms.length;
      completadas = tms.where((x) => x.estado == 'completada').length;
      incid = tms.where((x) => x.conIncidencia).length;
      final a = tms.where((x) => x.estado == 'activa').firstOrNull;
      if (a != null) {
        activa = muestras[a.muestraId]?.codigo;
        for (final c in cats) {
          puntos.add(idx['${a.muestraId}|${c.id}']?.estado);
        }
      }
    }
    final estado = estadoMesa(tandas);
    final colorMesa = switch (estado) {
      'catando' => Paleta.amarillo,
      'finalizada' => Paleta.lila,
      _ => Paleta.azul,
    };
    final enviadas = puntos.where((p) => p != null).length;

    return Card(
      child: InkWell(
        onTap: actual == null ? () => context.go('/mesas/$mesaId') : () => context.go('/puntuar/${actual.id}'),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: k ? 12 : 18, vertical: k ? 10 : 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: k ? 26 : 34,
                backgroundColor: Color.alphaBlend(colorMesa.withValues(alpha: 0.22), Colors.white),
                child: Text(
                  '${mesa.numero}',
                  style: TextStyle(fontSize: k ? 22 : 28, fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
              ),
              SizedBox(width: k ? 12 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mesa.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: k ? 17 : 22, fontWeight: FontWeight.w900, color: cs.onSurface),
                          ),
                        ),
                        EtiquetaEstado(estadosMesa[estado]!),
                        if (incid > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.warning_amber_rounded, color: Paleta.rojo, size: k ? 20 : 24),
                          ),
                      ],
                    ),
                    SizedBox(height: k ? 4 : 6),
                    Text(
                      actual == null ? 'Sin tanda en curso' : actual.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: k ? 15 : 18,
                        fontWeight: FontWeight.w800,
                        color: actual == null ? cs.onSurfaceVariant : cs.onSurface,
                      ),
                    ),
                    SizedBox(height: k ? 2 : 4),
                    Text(
                      actual == null
                          ? estadosMesa[estado]!.$1
                          : activa == null
                          ? '$completadas/$total muestras · sin muestra activa'
                          : 'Activa $activa · $completadas/$total · $enviadas/${cats.length} notas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: k ? 14 : 17,
                        fontWeight: FontWeight.w800,
                        color: activa != null ? Paleta.azulOscuro : cs.onSurfaceVariant,
                      ),
                    ),
                    if (puntos.isNotEmpty) ...[
                      SizedBox(height: k ? 6 : 8),
                      Row(
                        children: [
                          for (final p in puntos)
                            Container(
                              width: k ? 14 : 18,
                              height: k ? 14 : 18,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p == null ? Colors.transparent : (estadosNota[p]?.$3 ?? Colors.blue).shade400,
                                border: Border.all(color: cs.outline, width: 1.2),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (total > 0) ...[
                      SizedBox(height: k ? 6 : 8),
                      LinearProgressIndicator(
                        value: completadas / total,
                        minHeight: k ? 7 : 10,
                        color: colorMesa,
                        backgroundColor: colorMesa.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
