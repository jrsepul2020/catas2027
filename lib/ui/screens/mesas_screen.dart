import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'catadores_screen.dart';
import 'tandas_screen.dart';

/// Estado de la mesa a partir de sus tandas del día.
String estadoMesa(List<Tanda> tandas) {
  if (tandas.any((t) => t.estado == 'abierta')) return 'catando';
  if (tandas.isNotEmpty && tandas.every((t) => t.estado == 'cerrada')) return 'finalizada';
  return 'preparada';
}

class MesasScreen extends ConsumerWidget {
  const MesasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final w = MediaQuery.sizeOf(context).width;
    final k = esCompacto(context);
    final cols = k
        ? 1
        : (w >= 1300
              ? 4
              : w >= 900
              ? 3
              : 2);
    final problema = avisoCarga(
      ref,
      que: 'Cargar mesas',
      tablas: const ['mesas', 'tandas', 'catadores'],
      vacio: mesas.isEmpty,
      queHacerSiVacio: 'Sin mesas en este concurso. Revisa el concurso elegido o sincroniza desde Cloud.',
    );
    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context),
        title: const Text('Mesas'),
        actions: const [ChipDia(), ChipEntorno()],
      ),
      body:
          problema ??
          (cols == 1
              ? ListaLlena(
                  itemCount: mesas.length,
                  gap: k ? 8 : 12,
                  padding: EdgeInsets.all(k ? 10 : 14),
                  altoMinimo: k ? 110 : 140,
                  itemBuilder: (c, i) => _TarjetaMesa(mesas[i]),
                )
              : RejillaLlena(
                  itemCount: mesas.length,
                  columnas: cols,
                  gap: k ? 10 : 14,
                  padding: EdgeInsets.all(k ? 10 : 16),
                  altoMinimo: k ? 112 : 150,
                  itemBuilder: (c, i) => _TarjetaMesa(mesas[i]),
                )),
    );
  }
}

class _TarjetaMesa extends ConsumerWidget {
  const _TarjetaMesa(this.m);
  final Mesa m;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catadoresDeMesaProvider(m.id));
    final tandas = ref.watch(tandasDeMesaProvider(m.id));
    final abierta = tandas.where((t) => t.estado == 'abierta').firstOrNull;
    final porMesa = ref.watch(concursoProvider)?.catadoresPorMesa ?? 5;
    final presentes = cats.where((c) => c.presente).length;
    final presi = cats.where((c) => c.esPresidente).firstOrNull;
    final k = esCompacto(context);
    final cs = Theme.of(context).colorScheme;
    final estado = estadoMesa(tandas);
    return Card(
      child: InkWell(
        onTap: () => context.go('/mesas/${m.id}'),
        onLongPress: () => editarMesa(context, ref, m),
        child: Padding(
          padding: EdgeInsets.all(k ? 10 : 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: k ? 28 : 34,
                backgroundColor: switch (estado) {
                  'catando' => Paleta.amarilloPastel,
                  'finalizada' => Paleta.lilaPastel,
                  _ => Paleta.azulPastel,
                },
                child: Text(
                  '${m.numero}',
                  style: TextStyle(fontSize: k ? 22 : 28, fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
              ),
              SizedBox(width: k ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: k ? 18 : 22, fontWeight: FontWeight.w900, color: cs.onSurface),
                          ),
                        ),
                        EtiquetaEstado(estadosMesa[estado]!),
                      ],
                    ),
                    SizedBox(height: k ? 4 : 6),
                    Text(
                      '$presentes/${cats.length} catadores${cats.length != porMesa ? ' (prev. $porMesa)' : ''}'
                      '${presi != null ? ' · Pres. ${presi.nombre.split(' ').first}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: k ? 14 : 17,
                        fontWeight: FontWeight.w700,
                        color: cats.length != porMesa ? Paleta.rojo : cs.onSurface,
                      ),
                    ),
                    Text(
                      abierta == null
                          ? '${tandas.length} tandas · ninguna abierta'
                          : 'Abierta: ${abierta.nombre} · ${tandas.length} tandas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: k ? 14 : 17,
                        fontWeight: FontWeight.w700,
                        color: abierta != null ? Paleta.azulOscuro : cs.onSurfaceVariant,
                      ),
                    ),
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

Future<void> editarMesa(BuildContext context, WidgetRef ref, Mesa m) async {
  final repo = ref.read(repoProvider)!;
  final numero = TextEditingController(text: '${m.numero}');
  final nombre = TextEditingController(text: m.r['nombre'] ?? '');
  await hojaFormulario(
    context,
    titulo: 'Editar mesa',
    campos: [Campo(numero, 'Número', numero: true), Campo(nombre, 'Nombre (opcional)')],
    borrar: () => repo.borrar('mesas', m.id),
    guardar: () async {
      final n = int.tryParse(numero.text) ?? m.numero;
      final d = {'numero': n, 'nombre': nombre.text.trim().isEmpty ? 'Mesa $n' : nombre.text.trim()};
      await repo.actualizar('mesas', m.id, d);
    },
  );
}

// ============================ DETALLE ============================

class MesaDetalleScreen extends ConsumerWidget {
  const MesaDetalleScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesa = ref.watch(mesaPorIdProvider)[id];
    if (mesa == null) {
      return Scaffold(
        appBar: AppBar(leading: botonVolver(context, destino: '/mesas')),
        body: ref.watch(cargandoProvider)
            ? const Center(child: CircularProgressIndicator())
            : const Vacio(icono: Icons.table_restaurant, texto: 'Mesa no encontrada'),
      );
    }
    final puestos = PuestosMesa(mesa: mesa);
    final tandas = TandasDeMesa(mesaId: mesa.id);

    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context, destino: '/mesas'),
        title: Text(mesa.nombre),
        actions: [
          const BotonRefrescar(
            tooltip: 'Actualizar',
            tablas: ['puntuaciones', 'tanda_muestras', 'tandas', 'catadores', 'asignaciones'],
          ),
          IconButton(onPressed: () => editarMesa(context, ref, mesa), icon: const Icon(Icons.edit)),
          const ChipDia(),
        ],
      ),
      body: esAncho(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: puestos),
                const VerticalDivider(width: 1),
                Expanded(child: tandas),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: 'Puestos', height: esCompacto(context) ? 42 : 56),
                      Tab(text: 'Tandas', height: esCompacto(context) ? 42 : 56),
                    ],
                  ),
                  Expanded(child: TabBarView(children: [puestos, tandas])),
                ],
              ),
            ),
    );
  }
}

/// Puestos de la mesa. Arrastra un catador sobre otro para intercambiarlos;
/// tócalo para más opciones. Reparte el espacio entre los ~5 asientos.
class PuestosMesa extends ConsumerWidget {
  const PuestosMesa({super.key, required this.mesa});
  final Mesa mesa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(catadoresDeMesaProvider(mesa.id));
    final porMesa = ref.watch(concursoProvider)?.catadoresPorMesa ?? 5;
    final cs = Theme.of(context).colorScheme;
    final k = esCompacto(context);

    final repetidos = <int>{};
    final vistos = <int>{};
    for (final c in cats) {
      if (c.puesto != null && !vistos.add(c.puesto!)) repetidos.add(c.puesto!);
    }
    final presidentes = cats.where((c) => c.esPresidente).length;
    final avisos = [
      if (repetidos.isNotEmpty) 'Puesto repetido: ${repetidos.join(', ')}',
      if (presidentes != 1) '$presidentes presidentes (debe haber 1)',
      if (cats.length != porMesa) '${cats.length} catadores (previstos $porMesa)',
    ];

    Widget asiento(Catador c, {bool fila = false}) => _AsientoArrastrable(
      c: c,
      fila: fila,
      repetido: repetidos.contains(c.puesto),
      onSoltar: (otro) {
        if (!ref.read(puedeEditarPuestosProvider)) {
          aviso(context, 'En CLOUD los puestos los gestiona la App 1');
          return;
        }
        ejecutarConAvisos(
          context,
          () => ref.read(repoProvider)!.intercambiarPuestos(otro, c.id),
          ok: 'Puestos intercambiados',
          refrescar: tablasPuestos,
        );
      },
      onTap: () => opcionesCatador(context, ref, c),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(k ? 10 : 16, k ? 6 : 12, k ? 10 : 16, k ? 10 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Arrastra para intercambiar · toca para opciones',
                  style: TextStyle(fontSize: k ? 13 : 16, color: cs.onSurfaceVariant),
                ),
              ),
              if (ref.watch(puedeEditarPuestosProvider))
                TextButton.icon(
                  onPressed: () => _asignarCatador(context, ref),
                  icon: const Icon(Icons.person_search, size: 20),
                  label: const Text('Asignar'),
                ),
            ],
          ),
          for (final a in avisos)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '⚠ $a',
                style: TextStyle(color: cs.error, fontSize: k ? 13 : 16, fontWeight: FontWeight.w700),
              ),
            ),
          SizedBox(height: k ? 4 : 8),
          if (cats.isEmpty)
            const Expanded(child: Center(child: Text('Sin catadores asignados')))
          else if (!k && cats.length <= 6)
            // Tablet / ancho: una fila de asientos que llena la altura.
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < cats.length; i++) ...[
                    if (i > 0) SizedBox(width: k ? 8 : 12),
                    Expanded(child: asiento(cats[i])),
                  ],
                ],
              ),
            )
          else
            // Móvil: columna de asientos grandes sin huecos.
            Expanded(
              child: ListaLlena(
                itemCount: cats.length,
                gap: k ? 8 : 10,
                padding: EdgeInsets.zero,
                altoMinimo: k ? 88 : 110,
                itemBuilder: (c, i) => asiento(cats[i], fila: true),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _asignarCatador(BuildContext context, WidgetRef ref) async {
    final porMesa = ref.read(concursoProvider)?.catadoresPorMesa ?? 5;
    final enMesa = ref.read(catadoresDeMesaProvider(mesa.id));
    if (enMesa.length >= porMesa) {
      aviso(context, 'La mesa ya tiene $porMesa catadores. Quita a alguien o usa intercambiar.', error: true);
      return;
    }
    // Solo sin mesa: quien ya está en otra se mueve con «Cambiar mesa/puesto».
    final libres = ref.read(catadoresProvider).where((c) => c.mesaId == null).toList();
    if (libres.isEmpty) {
      aviso(
        context,
        'No hay catadores sin mesa. Para traer a alguien de otra mesa: tócalo → Cambiar mesa/puesto.',
        error: true,
      );
      return;
    }
    final c = await elegir(
      context,
      titulo: 'Asignar a ${mesa.nombre} (sin mesa)',
      opciones: libres,
      texto: (c) => c.completo,
      sub: (c) => [if (c.pais != null) c.pais!, 'Sin mesa'].join(' · '),
    );
    if (c == null || !context.mounted) return;
    final ocupados = enMesa.map((e) => e.puesto).whereType<int>().toSet();
    var p = 1;
    while (ocupados.contains(p)) {
      p++;
    }
    if (p > porMesa) {
      aviso(context, 'No queda puesto libre (1–$porMesa)', error: true);
      return;
    }
    await ejecutarConAvisos(
      context,
      () => ref.read(repoProvider)!.moverCatador(c.id, mesa.id, p),
      ok: 'Asignado a ${mesa.nombre} · puesto $p',
      refrescar: tablasPuestos,
    );
  }
}

class _AsientoArrastrable extends StatelessWidget {
  const _AsientoArrastrable({
    required this.c,
    required this.repetido,
    required this.onSoltar,
    required this.onTap,
    this.fila = false,
  });
  final Catador c;
  final bool fila;
  final bool repetido;
  final void Function(int otroId) onSoltar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget asiento({bool resaltado = false, bool fantasma = false}) =>
        _Asiento(c: c, fila: fila, repetido: repetido, resaltado: resaltado, fantasma: fantasma);
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != c.id,
      onAcceptWithDetails: (d) {
        HapticFeedback.mediumImpact();
        onSoltar(d.data);
      },
      builder: (context, candidatos, _) => Draggable<int>(
        data: c.id,
        onDragStarted: HapticFeedback.selectionClick,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: fila ? 280 : 120,
            height: fila ? 88 : 140,
            child: Transform.scale(scale: 1.05, child: asiento(resaltado: true)),
          ),
        ),
        childWhenDragging: asiento(fantasma: true),
        child: GestureDetector(
          onTap: onTap,
          child: asiento(resaltado: candidatos.isNotEmpty),
        ),
      ),
    );
  }
}

class _Asiento extends StatelessWidget {
  const _Asiento({
    required this.c,
    required this.repetido,
    this.fila = false,
    this.resaltado = false,
    this.fantasma = false,
  });
  final Catador c;
  final bool fila;
  final bool repetido;
  final bool resaltado;
  final bool fantasma;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = esCompacto(context);
    final fondo = resaltado
        ? Paleta.amarilloPastel
        : !c.presente
        ? cs.surfaceContainerHighest
        : c.esPresidente
        ? Paleta.lilaPastel
        : Paleta.azulPastel;
    final borde = repetido
        ? cs.error
        : resaltado
        ? Paleta.amarillo
        : c.esPresidente
        ? Paleta.lila
        : Paleta.azul.withValues(alpha: 0.35);
    return Opacity(
      opacity: fantasma ? 0.35 : 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final alto = box.maxHeight.isFinite ? box.maxHeight : (fila ? 88.0 : 140.0);
          final fPuesto = (alto * (fila ? 0.38 : 0.28)).clamp(k ? 22.0 : 28.0, fila ? 36.0 : 48.0);
          final fNombre = (alto * (fila ? 0.20 : 0.14)).clamp(k ? 13.0 : 15.0, fila ? 18.0 : 20.0);
          return Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: fila ? 12 : 8, vertical: k ? 6 : 10),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(k ? 14 : 20),
              border: Border.all(color: borde, width: repetido || resaltado ? 2.5 : 1.2),
            ),
            child: Stack(
              children: [
                if (fila)
                  Row(
                    children: [
                      SizedBox(
                        width: fPuesto * 1.4,
                        child: Text(
                          c.puesto == null ? '–' : '${c.puesto}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fPuesto,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: fNombre,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            if (c.esPresidente || !c.presente)
                              Text(
                                !c.presente ? 'Ausente' : 'Presidente',
                                style: TextStyle(
                                  fontSize: (fNombre * 0.85).clamp(11, 15),
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  color: !c.presente ? cs.error : Paleta.lilaOscuro,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        c.conectado ? Icons.tablet_android : Icons.tablet_outlined,
                        size: k ? 22 : 26,
                        color: c.conectado ? Paleta.azul : cs.outline.withValues(alpha: 0.5),
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        c.puesto == null ? '–' : '${c.puesto}',
                        style: TextStyle(
                          fontSize: fPuesto,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                        ),
                      ),
                      SizedBox(height: alto > 120 ? 6 : 2),
                      Text(
                        c.nombre,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: fNombre,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      if (c.esPresidente || !c.presente)
                        Text(
                          !c.presente ? 'Ausente' : 'Presidente',
                          style: TextStyle(
                            fontSize: (fNombre * 0.85).clamp(11, 15),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                            color: !c.presente ? cs.error : Paleta.lilaOscuro,
                          ),
                        ),
                    ],
                  ),
                if (!fila)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                      c.conectado ? Icons.tablet_android : Icons.tablet_outlined,
                      size: k ? 16 : 20,
                      color: c.conectado ? Paleta.azul : cs.outline.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
