import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

class CatadoresScreen extends ConsumerStatefulWidget {
  const CatadoresScreen({super.key});
  @override
  ConsumerState<CatadoresScreen> createState() => _CatadoresScreenState();
}

class _CatadoresScreenState extends ConsumerState<CatadoresScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(catadoresProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    final q = _q.toLowerCase();
    final l = q.isEmpty ? todos : todos.where((c) => c.completo.toLowerCase().contains(q)).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Catadores (${todos.length})'), actions: const [ChipEntorno()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarCatador(context, ref, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Catador'),
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SearchBar(
                hintText: 'Buscar catador',
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
                  final x = l[i];
                  final mesa = mesas[x.mesaId];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: x.presente ? null : Theme.of(context).colorScheme.errorContainer,
                      child: Text(x.iniciales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(x.completo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        mesa == null ? 'Sin mesa' : '${mesa.nombre} · puesto ${x.puesto ?? '–'}',
                        if (x.esPresidente) 'Presidente',
                        if (!x.presente) 'AUSENTE',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.more_vert, size: 30),
                    onTap: () => opcionesCatador(context, ref, x),
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

Future<void> editarCatador(BuildContext context, WidgetRef ref, Catador? c) async {
  final repo = ref.read(repoProvider)!;
  final nombre = TextEditingController(text: c?.nombre ?? '');
  final ape = TextEditingController(text: c?.apellidos ?? '');
  final email = TextEditingController(text: c?.email ?? '');
  final tel = TextEditingController(text: c?.telefono ?? '');
  String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
  await hojaFormulario(
    context,
    titulo: c == null ? 'Nuevo catador' : 'Editar catador',
    campos: [
      Campo(nombre, 'Nombre', autofocus: c == null),
      Campo(ape, 'Apellidos'),
      Campo(email, 'Email'),
      Campo(tel, 'Teléfono'),
    ],
    borrar: c == null ? null : () => repo.borrar('catadores', c.id),
    guardar: () async {
      final d = {'nombre': nombre.text.trim(), 'apellidos': t(ape), 'email': t(email), 'telefono': t(tel)};
      c == null
          ? await repo.insertar('catadores', {...d, 'cata_id': ref.read(cataIdProvider)})
          : await repo.actualizar('catadores', c.id, d);
    },
  );
}

/// Acciones rápidas sobre un catador (cambio de mesa/puesto, ausencia…).
Future<void> opcionesCatador(BuildContext context, WidgetRef ref, Catador c) async {
  final repo = ref.read(repoProvider)!;
  final accion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.completo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.event_seat, size: 34),
            title: const Text('Cambiar mesa / puesto'),
            onTap: () => Navigator.pop(s, 'mover'),
          ),
          ListTile(
            leading: Icon(c.presente ? Icons.person_off : Icons.person, size: 34),
            title: Text(c.presente ? 'Marcar AUSENTE' : 'Marcar presente'),
            onTap: () => Navigator.pop(s, 'presente'),
          ),
          ListTile(
            leading: const Icon(Icons.star, size: 34),
            title: Text(c.esPresidente ? 'Quitar presidente' : 'Hacer presidente de mesa'),
            onTap: () => Navigator.pop(s, 'presidente'),
          ),
          if (c.mesaId != null)
            ListTile(
              leading: const Icon(Icons.logout, size: 34),
              title: const Text('Quitar de la mesa'),
              onTap: () => Navigator.pop(s, 'quitar'),
            ),
          ListTile(
            leading: const Icon(Icons.edit, size: 34),
            title: const Text('Editar datos'),
            onTap: () => Navigator.pop(s, 'editar'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (accion == null || !context.mounted) return;
  switch (accion) {
    case 'mover':
      await _moverCatador(context, ref, c);
    case 'presente':
      await ejecutar(context, () async {
        await repo.actualizar('catadores', c.id, {'presente': !c.presente});
        if (c.presente) {
          await registrarIncidenciaAuto(
            ref,
            tipo: 'catador_ausente',
            mesaId: c.mesaId,
            catadorId: c.id,
            resuelta: false,
            descripcion: '${c.completo} ausente',
          );
        }
      });
    case 'presidente':
      await ejecutar(context, () => repo.actualizar('catadores', c.id, {'es_presidente': !c.esPresidente}));
    case 'quitar':
      await ejecutar(context, () => repo.moverCatador(c.id));
    case 'editar':
      await editarCatador(context, ref, c);
  }
}

Future<void> _moverCatador(BuildContext context, WidgetRef ref, Catador c) async {
  final mesas = ref.read(mesasProvider);
  final mesa = await elegir(
    context,
    titulo: 'Mesa de destino',
    opciones: mesas,
    texto: (m) => m.nombre,
    sub: (m) => '${ref.read(catadoresDeMesaProvider(m.id)).length} catadores',
    leading: (m) => CircleAvatar(child: Text('${m.numero}')),
  );
  if (mesa == null || !context.mounted) return;
  final ocupantes = {for (final x in ref.read(catadoresDeMesaProvider(mesa.id))) x.puesto: x};
  final maxP = [8, ...ocupantes.keys.whereType<int>().map((p) => p + 1)].reduce((a, b) => a > b ? a : b);
  final puesto = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Puesto en ${mesa.nombre}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const Text('Si está ocupado, se intercambian.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var p = 1; p <= maxP; p++)
                  SizedBox(
                    width: 96,
                    height: 84,
                    child: (ocupantes[p] == null ? FilledButton.new : FilledButton.tonal)(
                      onPressed: () => Navigator.pop(s, p),
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$p', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          if (ocupantes[p] != null) Text(ocupantes[p]!.iniciales, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (puesto == null || !context.mounted) return;
  final repo = ref.read(repoProvider)!;
  final otro = ocupantes[puesto];
  await ejecutar(context, () async {
    if (otro != null && otro.id != c.id) {
      // Intercambio atómico: el otro pasa al sitio original de c.
      await repo.intercambiarPuestos(c.id, otro.id);
    } else {
      await repo.moverCatador(c.id, mesaId: mesa.id, puesto: puesto);
    }
    await registrarIncidenciaAuto(
      ref,
      tipo: 'cambio_puesto',
      mesaId: mesa.id,
      catadorId: c.id,
      descripcion:
          '${c.completo} → ${mesa.nombre}, puesto $puesto'
          '${otro != null && otro.id != c.id ? ' (intercambio con ${otro.completo})' : ''}',
    );
  }, ok: 'Movido a ${mesa.nombre} · puesto $puesto');
}
