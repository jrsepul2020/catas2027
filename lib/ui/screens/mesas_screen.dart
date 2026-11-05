import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'catadores_screen.dart';
import 'incidencias_screen.dart';
import 'tandas_screen.dart';

class MesasScreen extends ConsumerWidget {
  const MesasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1300
        ? 4
        : w >= 900
        ? 3
        : w >= 560
        ? 2
        : 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesas'), actions: const [ChipEntorno()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarMesa(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Mesa'),
      ),
      body: mesas.isEmpty
          ? const Vacio(icono: Icons.table_restaurant, texto: 'Sin mesas. Pulsa + para crear la primera.')
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 196,
              ),
              itemCount: mesas.length,
              itemBuilder: (c, i) => _TarjetaMesa(mesas[i]),
            ),
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
    final enCurso = tandas.where((t) => t.estado == 'en_curso').firstOrNull;
    return Card(
      child: InkWell(
        onTap: () => context.go('/mesas/${m.id}'),
        onLongPress: () => editarMesa(context, ref, m),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text('${m.numero}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  EtiquetaEstado(estadosMesa[m.estado]!),
                ],
              ),
              const Spacer(),
              Text(
                '${cats.length} catadores · ${tandas.length} tandas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17),
              ),
              Text(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                enCurso == null ? 'Ninguna tanda en curso' : 'En curso: ${enCurso.nombre}',
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> editarMesa(BuildContext context, WidgetRef ref, Mesa? m) async {
  final repo = ref.read(repoProvider)!;
  final cataId = ref.read(cataIdProvider)!;
  final siguiente = ref.read(mesasProvider).fold<int>(0, (a, b) => b.numero > a ? b.numero : a) + 1;
  final numero = TextEditingController(text: '${m?.numero ?? siguiente}');
  final nombre = TextEditingController(text: m?.r['nombre'] ?? '');
  final sala = TextEditingController(text: m?.sala ?? '');
  await hojaFormulario(
    context,
    titulo: m == null ? 'Nueva mesa' : 'Editar mesa',
    campos: [Campo(numero, 'Número', numero: true), Campo(nombre, 'Nombre (opcional)'), Campo(sala, 'Sala (opcional)')],
    borrar: m == null ? null : () => repo.borrar('mesas', m.id),
    guardar: () async {
      final d = {
        'numero': int.tryParse(numero.text) ?? siguiente,
        'nombre': nombre.text.trim().isEmpty ? null : nombre.text.trim(),
        'sala': sala.text.trim().isEmpty ? null : sala.text.trim(),
      };
      m == null ? await repo.insertar('mesas', {...d, 'cata_id': cataId}) : await repo.actualizar('mesas', m.id, d);
    },
  );
}

// ============================ DETALLE ============================

class MesaDetalleScreen extends ConsumerStatefulWidget {
  const MesaDetalleScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<MesaDetalleScreen> createState() => _MesaDetalleScreenState();
}

class _MesaDetalleScreenState extends ConsumerState<MesaDetalleScreen> {
  String? _seleccionado; // catador marcado para intercambio

  Future<void> _tocarPuesto(Catador c) async {
    HapticFeedback.selectionClick();
    if (_seleccionado == null) {
      setState(() => _seleccionado = c.id);
      return;
    }
    if (_seleccionado == c.id) {
      setState(() => _seleccionado = null);
      return;
    }
    final a = _seleccionado!;
    setState(() => _seleccionado = null);
    final repo = ref.read(repoProvider)!;
    final porId = ref.read(catadorPorIdProvider);
    await ejecutar(context, () async {
      await repo.intercambiarPuestos(a, c.id);
      await registrarIncidenciaAuto(
        ref,
        tipo: 'cambio_puesto',
        mesaId: widget.id,
        descripcion: 'Intercambio de puestos: ${porId[a]?.completo} ⇄ ${c.completo}',
      );
    }, ok: 'Puestos intercambiados');
  }

  @override
  Widget build(BuildContext context) {
    final mesa = ref.watch(mesaPorIdProvider)[widget.id];
    if (mesa == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final cats = ref.watch(catadoresDeMesaProvider(widget.id));
    final repo = ref.read(repoProvider)!;

    final puestosRepetidos = <int>{};
    final vistos = <int>{};
    for (final c in cats) {
      if (c.puesto != null && !vistos.add(c.puesto!)) puestosRepetidos.add(c.puesto!);
    }

    final estados = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final e in estadosMesa.entries)
          ChoiceChip(
            avatar: Icon(e.value.$2, color: e.value.$3),
            label: Text(e.value.$1),
            selected: mesa.estado == e.key,
            onSelected: (_) => ejecutar(context, () => repo.actualizar('mesas', mesa.id, {'estado': e.key})),
          ),
      ],
    );

    final puestos = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Puestos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            TextButton.icon(
              onPressed: () => _asignarCatador(context, mesa),
              icon: const Icon(Icons.person_add),
              label: const Text('Añadir'),
            ),
          ],
        ),
        Text(
          _seleccionado == null
              ? 'Toca un catador y luego otro para intercambiar sus puestos. Mantén pulsado para opciones.'
              : 'Ahora toca el catador con el que intercambiar…',
          style: TextStyle(
            fontSize: 16,
            color: _seleccionado == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.primary,
            fontWeight: _seleccionado == null ? null : FontWeight.w700,
          ),
        ),
        if (puestosRepetidos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '⚠ Puesto repetido: ${puestosRepetidos.join(', ')}',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        const SizedBox(height: 12),
        if (cats.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Sin catadores asignados')),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in cats)
              _Asiento(
                c: c,
                seleccionado: _seleccionado == c.id,
                repetido: puestosRepetidos.contains(c.puesto),
                onTap: () => _tocarPuesto(c),
                onLongPress: () => opcionesCatador(context, ref, c),
              ),
          ],
        ),
      ],
    );

    final tandas = TandasDeMesa(mesaId: mesa.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(mesa.nombre),
        actions: [
          IconButton(onPressed: () => editarMesa(context, ref, mesa), icon: const Icon(Icons.edit)),
          IconButton(
            tooltip: 'Nueva incidencia',
            onPressed: () => nuevaIncidencia(context, ref, mesaId: mesa.id),
            icon: const Icon(Icons.add_alert),
          ),
          const ChipEntorno(),
        ],
      ),
      body: esAncho(context)
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [estados, const SizedBox(height: 24), puestos],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tandas),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Puestos', height: 56),
                      Tab(text: 'Tandas', height: 56),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [estados, const SizedBox(height: 24), puestos],
                        ),
                        tandas,
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _asignarCatador(BuildContext context, Mesa mesa) async {
    final libres = ref.read(catadoresProvider).where((c) => c.mesaId != mesa.id).toList();
    final mesas = ref.read(mesaPorIdProvider);
    final c = await elegir(
      context,
      titulo: 'Añadir catador a ${mesa.nombre}',
      opciones: libres,
      texto: (c) => c.completo,
      sub: (c) => c.mesaId == null ? 'Sin mesa' : 'Ahora en ${mesas[c.mesaId]?.nombre ?? '?'}',
    );
    if (c == null || !context.mounted) return;
    final ocupados = ref.read(catadoresDeMesaProvider(mesa.id)).map((e) => e.puesto).toSet();
    var p = 1;
    while (ocupados.contains(p)) {
      p++;
    }
    await ejecutar(context, () => ref.read(repoProvider)!.moverCatador(c.id, mesaId: mesa.id, puesto: p));
  }
}

class _Asiento extends StatelessWidget {
  const _Asiento({
    required this.c,
    required this.seleccionado,
    required this.repetido,
    required this.onTap,
    required this.onLongPress,
  });
  final Catador c;
  final bool seleccionado;
  final bool repetido;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fondo = seleccionado
        ? cs.primary
        : !c.presente
        ? cs.surfaceContainerHighest
        : cs.primaryContainer;
    final texto = seleccionado ? cs.onPrimary : cs.onPrimaryContainer;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: repetido ? cs.error : Colors.transparent, width: 3),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  c.puesto == null ? '–' : '${c.puesto}',
                  style: TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w900, color: texto),
                ),
                Text(
                  c.completo,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, height: 1.15, fontWeight: FontWeight.w700, color: texto),
                ),
                if (c.esPresidente || !c.presente)
                  Text(
                    c.esPresidente ? 'Presidente' : 'Ausente',
                    style: TextStyle(fontSize: 13, color: texto, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
