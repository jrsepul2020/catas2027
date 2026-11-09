import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
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
    final problema = avisoCarga(
      ref,
      que: 'Cargar catadores',
      tablas: const ['catadores', 'mesas'],
      vacio: todos.isEmpty,
      queHacerSiVacio: 'No hay catadores. Sincroniza desde Cloud o revisa el concurso.',
    );
    return Scaffold(
      appBar: AppBar(title: Text('Catadores (${todos.length})'), actions: const [ChipEntorno()]),
      body:
          problema ??
          Ancho(
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
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: l.length,
                    itemExtent: 62,
                    itemBuilder: (c, i) {
                      final x = l[i];
                      final mesa = mesas[x.mesaId];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundColor: !x.presente
                              ? Theme.of(context).colorScheme.errorContainer
                              : x.esPresidente
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : null,
                          child: Text(x.iniciales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(x.completo, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            mesa == null ? 'Sin mesa' : '${mesa.nombre} · puesto ${x.puesto ?? '–'}',
                            if (x.esPresidente) 'Presidente',
                            if (x.pais != null) x.pais!,
                            if (!x.presente) 'AUSENTE',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          x.conectado ? Icons.tablet_android : Icons.more_vert,
                          size: 30,
                          color: x.conectado ? Colors.amber.shade700 : null,
                        ),
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

Future<void> editarCatador(BuildContext context, WidgetRef ref, Catador c) async {
  final repo = ref.read(repoProvider)!;
  final nombre = TextEditingController(text: c.nombre);
  final titulo = TextEditingController(text: c.r['titulo'] ?? '');
  final pais = TextEditingController(text: c.r['pais_codigo'] ?? '');
  String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
  await hojaFormulario(
    context,
    titulo: 'Editar catador',
    campos: [
      Campo(nombre, 'Nombre y apellidos', autofocus: true),
      Campo(titulo, 'Título (opcional, p. ej. Dr.)'),
      Campo(pais, 'País (código, p. ej. ES)'),
    ],
    borrar: () => repo.borrar('catadores', c.id),
    guardar: () async {
      await repo.actualizar('catadores', c.id, {
        'nombre': nombre.text.trim(),
        'titulo': t(titulo),
        'pais_codigo': t(pais)?.toUpperCase(),
      });
    },
  );
}

/// Acciones rápidas sobre un catador (cambio de mesa/puesto, ausencia…).
Future<void> opcionesCatador(BuildContext context, WidgetRef ref, Catador c) async {
  final repo = ref.read(repoProvider)!;
  final editarPuestos = ref.read(puedeEditarPuestosProvider);
  final esLocal = ref.read(esLocalProvider);
  final accion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.completo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (!editarPuestos)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'En CLOUD los puestos los gestiona la App 1. Activa modo pruebas para forzar cambios.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ),
          const SizedBox(height: 8),
          if (editarPuestos)
            AccionHoja(
              icono: Icons.event_seat,
              titulo: 'Cambiar mesa / puesto',
              onTap: () => Navigator.pop(s, 'mover'),
            ),
          AccionHoja(
            icono: c.presente ? Icons.person_off : Icons.person,
            color: c.presente ? Paleta.rojo : Paleta.azul,
            titulo: c.presente ? 'Marcar AUSENTE' : 'Marcar presente',
            onTap: () => Navigator.pop(s, 'presente'),
          ),
          if (editarPuestos)
            AccionHoja(
              icono: Icons.star,
              color: Paleta.lila,
              titulo: c.esPresidente ? 'Pasar a catador' : 'Hacer presidente de mesa',
              onTap: () => Navigator.pop(s, 'presidente'),
            ),
          if (esLocal && c.conectado)
            AccionHoja(
              icono: Icons.phonelink_erase,
              color: Paleta.rojo,
              titulo: 'Liberar tablet (rota)',
              subtitulo: 'Desvincula el dispositivo; queda libre para una reserva',
              onTap: () => Navigator.pop(s, 'liberar'),
            ),
          if (esLocal)
            AccionHoja(
              icono: Icons.tablet_android,
              color: Paleta.azul,
              titulo: 'Asignar tablet de reserva',
              subtitulo: 'Usa una de las tablets libres',
              onTap: () => Navigator.pop(s, 'asignar'),
            ),
          if (editarPuestos && c.mesaId != null)
            AccionHoja(
              icono: Icons.logout,
              titulo: 'Quitar de la mesa (no ha venido)',
              onTap: () => Navigator.pop(s, 'quitar'),
            ),
          AccionHoja(icono: Icons.edit, titulo: 'Editar datos', onTap: () => Navigator.pop(s, 'editar')),
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
        await registrarCambio(
          ref,
          c.presente ? 'catador_ausente' : 'catador_presente',
          tabla: 'catadores',
          registroId: '${c.id}',
          motivo: '${c.nombre}${c.puesto != null ? ' (mesa ${c.r['mesa'] ?? '?'}, puesto ${c.puesto})' : ''}',
        );
      }, refrescar: const ['catadores']);
    case 'presidente':
      await ejecutarConAvisos(
        context,
        () => repo.fijarPresidente(c.id, presidente: !c.esPresidente),
        ok: c.esPresidente ? 'Ahora es catador' : 'Ahora es presidente',
        refrescar: tablasPuestos,
      );
    case 'liberar':
      if (await confirmar(
            context,
            '¿Liberar la tablet de ${c.nombre}?',
            texto: 'La tablet queda libre. Enciende una de reserva y asígnala a este catador.',
            si: 'Liberar',
          ) &&
          context.mounted) {
        await ejecutar(
          context,
          () async {
            await repo.liberarTablet(c.id);
            await registrarCambio(ref, 'liberar_tablet', tabla: 'catadores', registroId: '${c.id}', motivo: c.nombre);
          },
          ok: 'Tablet liberada',
          refrescar: const ['dispositivos', 'catadores'],
        );
      }
    case 'asignar':
      await _asignarTabletReserva(context, ref, c);
    case 'quitar':
      await ejecutarConAvisos(
        context,
        () => repo.quitarDeMesa(c.id),
        ok: 'Quitado de la mesa',
        refrescar: tablasPuestos,
      );
    case 'editar':
      await editarCatador(context, ref, c);
  }
}

Future<void> _asignarTabletReserva(BuildContext context, WidgetRef ref, Catador c) async {
  final libres = ref.read(tabletsLibresProvider);
  if (libres.isEmpty) {
    aviso(context, 'No hay tablets de reserva libres', error: true);
    return;
  }
  final d = await elegir(
    context,
    titulo: 'Tablet de reserva para ${c.nombre}',
    opciones: libres,
    texto: (x) => 'Reserva ${x.corto}',
    sub: (x) => x.ultimaVez == null ? 'Sin uso reciente' : 'Última: ${x.ultimaVez}',
  );
  if (d == null || !context.mounted) return;
  await ejecutar(
    context,
    () async {
      await ref.read(repoProvider)!.asignarTablet(d.id, c.id);
      await registrarCambio(
        ref,
        'asignar_tablet',
        tabla: 'dispositivos',
        registroId: '${d.id}',
        motivo: '${c.nombre} ← ${d.deviceId}',
      );
    },
    ok: 'Tablet asignada',
    refrescar: const ['dispositivos', 'catadores'],
  );
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
  final porMesa = ref.read(concursoProvider)?.catadoresPorMesa ?? 5;
  final maxP = [porMesa, ...ocupantes.keys.whereType<int>().map((p) => p + 1)].reduce((a, b) => a > b ? a : b);
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
            Text('Puesto en ${mesa.nombre}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
  await ejecutarConAvisos(
    context,
    () => ref.read(repoProvider)!.moverCatador(c.id, mesa.id, puesto),
    ok: 'Movido a ${mesa.nombre} · puesto $puesto',
    refrescar: tablasPuestos,
  );
}
