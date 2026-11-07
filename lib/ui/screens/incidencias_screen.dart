import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';

final _hora = DateFormat('dd/MM HH:mm');

/// Deja constancia en registro_cambios de una acción hecha desde la app.
Future<void> registrarCambio(WidgetRef ref, String accion, {String? tabla, String? registroId, String? motivo}) async {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  await repo.registrar(accion, tabla: tabla, registroId: registroId, motivo: motivo, diaId: ref.read(diaIdProvider));
}

/// Marca una muestra de tanda con incidencia: motivo con iconos grandes + texto opcional.
/// Si no se indica [tm], primero se elige la tanda y la muestra.
Future<void> nuevaIncidencia(BuildContext context, WidgetRef ref, {TandaMuestra? tm, int? tandaId}) async {
  tm ??= await _elegirMuestraDeTanda(context, ref, tandaId: tandaId);
  if (tm == null || !context.mounted) return;
  final codigo = ref.read(muestraPorIdProvider)[tm.muestraId]?.codigo ?? '?';

  final motivo = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Incidencia · muestra $codigo', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final (texto, icono) in motivosIncidencia)
                  Card(
                    color: Theme.of(s).colorScheme.secondaryContainer,
                    child: InkWell(
                      onTap: () => Navigator.pop(s, texto),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icono),
                          const SizedBox(height: 6),
                          Text(
                            texto,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
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
  if (motivo == null || !context.mounted) return;
  final detalle = TextEditingController();
  await hojaFormulario(
    context,
    titulo: motivo,
    campos: [
      Text(
        'Muestra $codigo pasará a estado INCIDENCIA hasta que decidas qué hacer.',
        style: const TextStyle(fontSize: 17),
      ),
      const SizedBox(height: 14),
      Campo(detalle, 'Detalle (opcional)', lineas: 2),
    ],
    guardar: () => ref
        .read(repoProvider)!
        .marcarIncidencia(tm!.id, detalle.text.trim().isEmpty ? motivo : '$motivo: ${detalle.text.trim()}'),
  );
}

Future<TandaMuestra?> _elegirMuestraDeTanda(BuildContext context, WidgetRef ref, {int? tandaId}) async {
  final mesas = ref.read(mesaPorIdProvider);
  if (tandaId == null) {
    const peso = {'abierta': 0, 'pendiente': 1, 'cerrada': 2};
    final tandas = [...ref.read(tandasProvider)]..sort((a, b) => (peso[a.estado] ?? 1).compareTo(peso[b.estado] ?? 1));
    final t = await elegir<Tanda>(
      context,
      titulo: '¿En qué tanda?',
      opciones: tandas,
      texto: (t) => '${t.nombre} · ${mesas[t.mesaId]?.nombre ?? 'sin mesa'}',
      sub: (t) => infoTanda(t.estado).$1,
      leading: (t) => Icon(infoTanda(t.estado).$2, color: infoTanda(t.estado).$3),
    );
    if (t == null) return null;
    tandaId = t.id;
  }
  if (!context.mounted) return null;
  final muestras = ref.read(muestraPorIdProvider);
  final tms = ref.read(muestrasDeTandaProvider(tandaId));
  return elegir<TandaMuestra>(
    context,
    titulo: '¿Qué muestra?',
    opciones: tms,
    texto: (x) => '${x.orden}. ${muestras[x.muestraId]?.codigo ?? '?'}',
    sub: (x) => infoTM(x.estado).$1,
    leading: (x) => Icon(infoTM(x.estado).$2, color: infoTM(x.estado).$3),
  );
}

/// Decide qué hacer con una muestra con incidencia (usa las funciones de la base).
Future<void> resolverIncidencia(BuildContext context, WidgetRef ref, TandaMuestra tm) async {
  final codigo = ref.read(muestraPorIdProvider)[tm.muestraId]?.codigo ?? '?';
  final notas = ref
      .read(puntuacionesProvider)
      .where((p) => p.muestraId == tm.muestraId && p.tandaId == tm.tandaId)
      .length;
  const acciones = [
    ('continuar', Icons.play_arrow, 'Continuar sin cambios', 'Cierra la incidencia; la muestra sigue pendiente.'),
    ('recatar', Icons.replay, 'Recatar desde cero', 'Borra sus notas (quedan en el registro) y vuelve a pendiente.'),
    ('pasar_al_final', Icons.low_priority, 'Pasar al final', 'Borra sus notas y la coloca la última de la tanda.'),
    (
      'quitar_de_tanda',
      Icons.remove_circle,
      'Quitar de la tanda',
      'Borra sus notas, la saca de la tanda y la desactiva.',
    ),
  ];
  final accion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (s) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Muestra $codigo', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (tm.motivo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(tm.motivo!, style: const TextStyle(fontSize: 17), textAlign: TextAlign.center),
            ),
          Text('$notas notas registradas', style: TextStyle(color: Theme.of(s).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final (k, icono, titulo, sub) in acciones)
            AccionHoja(
              icono: icono,
              color: k == 'quitar_de_tanda' ? Theme.of(s).colorScheme.error : null,
              titulo: titulo,
              subtitulo: sub,
              onTap: () => Navigator.pop(s, k),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (accion == null || !context.mounted) return;
  if (accion != 'continuar' &&
      !await confirmar(
        context,
        '¿Seguro?',
        texto: notas > 0 ? 'Se borrarán $notas notas (se guardan en el registro de cambios).' : null,
        si: 'Confirmar',
      )) {
    return;
  }
  if (!context.mounted) return;
  String? msg;
  final ok = await ejecutar(context, () async {
    msg = await ref.read(repoProvider)!.resolverIncidencia(tm.id, accion, motivo: tm.motivo);
  });
  if (ok && context.mounted && msg != null && msg!.isNotEmpty) aviso(context, msg!);
}

class IncidenciasScreen extends ConsumerStatefulWidget {
  const IncidenciasScreen({super.key});
  @override
  ConsumerState<IncidenciasScreen> createState() => _IncidenciasScreenState();
}

class _IncidenciasScreenState extends ConsumerState<IncidenciasScreen> {
  bool _historial = false;

  @override
  Widget build(BuildContext context) {
    final abiertas = ref.watch(incidenciasAbiertasListaProvider);
    final cambios = ref.watch(cambiosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias'), actions: const [ChipEntorno()]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        onPressed: () => nuevaIncidencia(context, ref),
        icon: const Icon(Icons.add_alert),
        label: const Text('Nueva'),
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text('Abiertas (${abiertas.length})')),
                  const ButtonSegment(value: true, label: Text('Historial')),
                ],
                selected: {_historial},
                onSelectionChanged: (s) => setState(() => _historial = s.first),
              ),
            ),
            Expanded(
              child: _historial
                  ? (cambios.isEmpty
                        ? const Vacio(icono: Icons.history, texto: 'Sin cambios registrados')
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 120),
                            itemCount: cambios.length,
                            itemBuilder: (c, i) => _FilaCambio(cambios[i]),
                          ))
                  : (abiertas.isEmpty
                        ? const Vacio(icono: Icons.verified, texto: 'Ninguna incidencia abierta 👍')
                        : ListaLlena(
                            itemCount: abiertas.length,
                            gap: 10,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                            altoMinimo: 100,
                            itemBuilder: (c, i) => _TarjetaIncidencia(abiertas[i]),
                          )),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaIncidencia extends ConsumerWidget {
  const _TarjetaIncidencia(this.tm);
  final TandaMuestra tm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muestra = ref.watch(muestraPorIdProvider)[tm.muestraId];
    final tanda = ref.watch(tandaPorIdProvider)[tm.tandaId];
    final mesa = ref.watch(mesaPorIdProvider)[tanda?.mesaId];
    final k = esCompacto(context);
    return Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 8, color: Colors.red.shade700),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 14, k ? 10 : 14, k ? 10 : 14),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: k ? 32 : 38, color: Colors.red.shade700),
                  SizedBox(width: k ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Muestra ${muestra?.codigo ?? '?'}',
                          style: TextStyle(fontSize: k ? 18 : 20, fontWeight: FontWeight.w800),
                        ),
                        if (tm.motivo != null)
                          Text(
                            tm.motivo!,
                            style: TextStyle(fontSize: k ? 15 : 17, fontWeight: FontWeight.w700),
                          ),
                        Text(
                          [mesa?.nombre, tanda?.nombre, 'posición ${tm.orden}'].whereType<String>().join(' · '),
                          style: TextStyle(
                            fontSize: k ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: Size(k ? 88 : 100, k ? 52 : 60)),
                    onPressed: () => resolverIncidencia(context, ref, tm),
                    child: const Text('Resolver'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCambio extends StatelessWidget {
  const _FilaCambio(this.c);
  final Cambio c;
  @override
  Widget build(BuildContext context) {
    final info = accionesCambio[c.accion] ?? (c.accion, Icons.history);
    return ListTile(
      leading: Icon(info.$2),
      title: Text(info.$1),
      subtitle: Text(
        [if (c.fecha != null) _hora.format(c.fecha!), if (c.motivo?.isNotEmpty == true) c.motivo!].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
