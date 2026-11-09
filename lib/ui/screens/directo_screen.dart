import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';

/// En directo: tandas abiertas (en curso), no un listado de mesas.
class DirectoScreen extends ConsumerWidget {
  const DirectoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final enCurso = tandas.where((t) => t.estado == 'abierta').toList()
      ..sort((a, b) {
        final ma = ref.read(mesaPorIdProvider)[a.mesaId]?.numero ?? 999;
        final mb = ref.read(mesaPorIdProvider)[b.mesaId]?.numero ?? 999;
        return ma != mb ? ma.compareTo(mb) : a.orden.compareTo(b.orden);
      });
    final inc = ref.watch(incidenciasAbiertasProvider);
    final k = esCompacto(context);
    final problema =
        avisoCarga(
          ref,
          que: 'Cargar el directo (tandas del día)',
          tablas: const ['mesas', 'tandas', 'tanda_muestras', 'catadores', 'puntuaciones'],
          vacio: mesas.isEmpty && tandas.isEmpty,
          queHacerSiVacio: 'No hay mesas ni tandas. Revisa el concurso o sincroniza el día.',
        ) ??
        (mesas.isNotEmpty && tandas.isEmpty
            ? RecuadroProblema(
                que: 'Directo sin tandas para el día seleccionado',
                error: 'mesas=${mesas.length}, tandas filtradas=0',
                queHacer:
                    'Pulsa el chip del calendario y elige el día donde están las tandas '
                    '(o «Todos los días»).',
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
              decoration: const BoxDecoration(color: Virtus.error, shape: BoxShape.circle),
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
                backgroundColor: Virtus.error,
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
              ),
            ),
          const ChipDia(),
          const ChipEntorno(),
        ],
      ),
      body:
          problema ??
          (enCurso.isEmpty
              ? const Vacio(
                  icono: Icons.sensors_off_outlined,
                  texto: 'Ninguna tanda en curso.\nAbre una desde Tandas o Puntuaciones.',
                )
              : Ancho(
                  max: 1100,
                  child: ListView.separated(
                    padding: EdgeInsets.all(k ? 10 : 14),
                    itemCount: enCurso.length,
                    separatorBuilder: (_, _) => SizedBox(height: k ? 8 : 12),
                    itemBuilder: (c, i) => _TarjetaTandaDirecto(tanda: enCurso[i]),
                  ),
                )),
    );
  }
}

class _TarjetaTandaDirecto extends ConsumerWidget {
  const _TarjetaTandaDirecto({required this.tanda});
  final Tanda tanda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesa = ref.watch(mesaPorIdProvider)[tanda.mesaId];
    final cats = tanda.mesaId == null
        ? const <Catador>[]
        : ref.watch(catadoresDeMesaProvider(tanda.mesaId!)).where((c) => c.presente).toList();
    final tms = ref.watch(muestrasDeTandaProvider(tanda.id));
    final idx = ref.watch(puntuacionIdxProvider);
    final muestras = ref.watch(muestraPorIdProvider);
    final catsIdx = ref.watch(categoriasProvider);
    final catNombre = {for (final c in catsIdx) c.id: c.nombre};
    final k = esCompacto(context);

    final hechas = tms.where((x) => x.estado == 'completada').length;
    final incid = tms.where((x) => x.conIncidencia).length;
    final activa = tms.where((x) => x.estado == 'activa').firstOrNull;
    final muestra = activa == null ? null : muestras[activa.muestraId];
    final puntos = <String?>[];
    if (activa != null) {
      for (final c in cats) {
        puntos.add(idx['${activa.muestraId}|${c.id}']?.estado);
      }
    }
    final enviadas = puntos.where((p) => p != null).length;
    final pct = tms.isEmpty ? 0 : (hechas / tms.length * 100).round();

    return Material(
      color: Virtus.superficie,
      borderRadius: BorderRadius.circular(Virtus.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(Virtus.radio),
        onTap: () => context.go('/puntuar/${tanda.id}'),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: k ? 12 : 16, vertical: k ? 12 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Virtus.radio),
            border: Border.all(color: Virtus.borde),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: k ? 56 : 64,
                padding: EdgeInsets.symmetric(vertical: k ? 8 : 10),
                decoration: BoxDecoration(color: Virtus.marino, borderRadius: BorderRadius.circular(Virtus.radioSm)),
                child: Column(
                  children: [
                    Text('Mesa', style: VirtusTexto.tenue(size: 10, color: Colors.white70)),
                    Text(
                      '${mesa?.numero ?? '–'}',
                      style: VirtusTexto.importante(size: k ? 22 : 26, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(width: k ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tanda.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: VirtusTexto.importante(size: k ? 18 : 22),
                          ),
                        ),
                        EtiquetaEstado(infoTanda('abierta')),
                        if (incid > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.warning_amber_rounded, color: Virtus.error, size: k ? 20 : 22),
                          ),
                      ],
                    ),
                    Text(
                      [
                        mesa?.nombre,
                        if (tanda.categoriaId != null) catNombre[tanda.categoriaId],
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VirtusTexto.tenue(size: k ? 12 : 13),
                    ),
                    SizedBox(height: k ? 4 : 6),
                    Text(
                      muestra == null
                          ? 'Sin muestra activa · $hechas/${tms.length}'
                          : 'Activa ${muestra.codigo}'
                                '${muestra.codigoTexto != null && muestra.codigoTexto != muestra.codigo ? ' · ${muestra.codigoTexto}' : ''}'
                                ' · $enviadas/${cats.length} notas',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: VirtusTexto.importante(
                        size: k ? 15 : 17,
                        color: muestra != null ? Virtus.accion : Virtus.textoSecundario,
                      ),
                    ),
                    if (puntos.isNotEmpty) ...[
                      SizedBox(height: k ? 6 : 8),
                      Row(
                        children: [
                          for (final p in puntos)
                            Container(
                              width: k ? 14 : 16,
                              height: k ? 14 : 16,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p == null ? Colors.transparent : (estadosNota[p]?.$3 ?? Colors.blue).shade400,
                                border: Border.all(color: Virtus.borde, width: 1.2),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (tms.isNotEmpty) ...[
                      SizedBox(height: k ? 6 : 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: hechas / tms.length,
                                minHeight: k ? 7 : 9,
                                color: Virtus.advertencia,
                                backgroundColor: Virtus.advertenciaSuave,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('$hechas / ${tms.length} ($pct%)', style: VirtusTexto.tenue(size: k ? 11 : 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Virtus.textoTenue, size: k ? 22 : 26),
            ],
          ),
        ),
      ),
    );
  }
}
