import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../widgets.dart';

/// Elección de concurso (solo aparece si hay varios).
class CatasScreen extends ConsumerWidget {
  const CatasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filas = ref.watch(filasProvider('concursos'));
    final l = ref.watch(concursosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige el concurso'),
        actions: [
          IconButton(onPressed: () => context.push('/sync'), icon: const Icon(Icons.sync)),
          IconButton(onPressed: () => context.push('/configuracion'), icon: const Icon(Icons.settings)),
          const ChipEntorno(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarConcurso(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Concurso'),
      ),
      body: filas.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filas.hasError
          ? Vacio(icono: Icons.error, texto: '${filas.error}')
          : l.isEmpty
          ? const Vacio(
              icono: Icons.emoji_events,
              texto: 'No hay concursos.\nCrea uno o sincroniza desde el otro entorno.',
            )
          : Ancho(
              max: 760,
              child: ListaLlena(
                itemCount: l.length,
                gap: 12,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                altoMinimo: 110,
                itemBuilder: (c, i) => Card(
                  child: InkWell(
                    onTap: () {
                      ref.read(concursoGuardadoProvider.notifier).set(l[i].id);
                      context.go('/');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.emoji_events, size: 44, color: l[i].activo ? null : Colors.grey),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(l[i].nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (!l[i].activo) 'Inactivo',
                                    'Gran Oro ≥ ${numCorto(l[i].granOro)} · Oro ≥ ${numCorto(l[i].oro)} · Plata ≥ ${numCorto(l[i].plata)}',
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

String numCorto(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v'.replaceAll('.', ',');

/// Formulario de concurso: nombre, fechas, umbrales de medalla.
Future<void> editarConcurso(BuildContext context, WidgetRef ref, Concurso? c) async {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  final nombre = TextEditingController(text: c?.nombre ?? '');
  final ini = TextEditingController(text: c?.fechaInicio ?? '');
  final fin = TextEditingController(text: c?.fechaFin ?? '');
  final go = TextEditingController(text: numCorto(c?.granOro ?? 92));
  final o = TextEditingController(text: numCorto(c?.oro ?? 85));
  final p = TextEditingController(text: numCorto(c?.plata ?? 82));
  final porMesa = TextEditingController(text: '${c?.catadoresPorMesa ?? 5}');
  var activo = c?.activo ?? true;
  double? n(TextEditingController x) => double.tryParse(x.text.replaceAll(',', '.'));
  String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();

  await hojaFormulario(
    context,
    titulo: c == null ? 'Nuevo concurso' : 'Concurso',
    campos: [
      Campo(nombre, 'Nombre', autofocus: c == null),
      Row(
        children: [
          Expanded(child: Campo(ini, 'Inicio (AAAA-MM-DD)')),
          const SizedBox(width: 10),
          Expanded(child: Campo(fin, 'Fin (AAAA-MM-DD)')),
        ],
      ),
      Row(
        children: [
          Expanded(child: Campo(go, 'Gran Oro ≥', numero: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(o, 'Oro ≥', numero: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(p, 'Plata ≥', numero: true)),
        ],
      ),
      Campo(porMesa, 'Catadores por mesa', numero: true),
      StatefulBuilder(
        builder: (cx, set) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Concurso activo'),
          value: activo,
          onChanged: (v) => set(() => activo = v),
        ),
      ),
    ],
    guardar: () async {
      final datos = {
        'nombre': nombre.text.trim(),
        'fecha_inicio': t(ini),
        'fecha_fin': t(fin),
        'gran_oro': n(go) ?? 92,
        'oro': n(o) ?? 85,
        'plata': n(p) ?? 82,
        'catadores_por_mesa': int.tryParse(porMesa.text) ?? 5,
        'activo': activo,
      };
      if (c == null) {
        final id = await repo.insertar('concursos', datos);
        ref.read(concursoGuardadoProvider.notifier).set(id);
      } else {
        await repo.actualizar('concursos', c.id, datos);
      }
    },
  );
}
