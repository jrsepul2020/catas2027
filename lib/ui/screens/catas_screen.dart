import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
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
      body: filas.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filas.hasError
          ? Vacio(icono: Icons.error, texto: '${filas.error}')
          : l.isEmpty
          ? const Vacio(
              icono: Icons.emoji_events,
              texto: 'No hay concursos.\nSincroniza desde Cloud o revisa la conexión.',
            )
          : Ancho(
              max: 760,
              child: ListaLlena(
                itemCount: l.length,
                gap: 12,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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

double? _numCampo(TextEditingController x) => double.tryParse(x.text.replaceAll(',', '.'));

/// Guarda umbrales Gran Oro / Oro / Plata en CLOUD y LOCAL (mismo id de concurso).
Future<List<String>> guardarUmbralesMedallas(
  WidgetRef ref,
  int concursoId, {
  required double granOro,
  required double oro,
  required double plata,
}) async {
  if (!(granOro >= oro && oro >= plata && plata > 0 && granOro <= 100)) {
    throw Exception('Los umbrales deben cumplir Gran Oro ≥ Oro ≥ Plata (y entre 0 y 100).');
  }
  final datos = {'gran_oro': granOro, 'oro': oro, 'plata': plata};
  final avisos = <String>[];
  var ok = 0;
  for (final e in Entorno.values) {
    try {
      final cli = await clienteAutenticado(ref, e);
      await cli.from('concursos').update(datos).eq('id', concursoId);
      avisos.add('${e.corto} actualizado');
      ok++;
    } catch (err) {
      avisos.add('${e.corto}: ${'$err'.replaceFirst(RegExp(r'^Exception:\s*'), '')}');
    }
  }
  if (ok == 0) throw Exception(avisos.join('\n'));
  return avisos;
}

/// Solo umbrales de medalla (pensado para Medallero). Escribe en CLOUD y LOCAL.
Future<void> editarUmbralesMedallas(BuildContext context, WidgetRef ref, Concurso c) async {
  final go = TextEditingController(text: numCorto(c.granOro));
  final o = TextEditingController(text: numCorto(c.oro));
  final p = TextEditingController(text: numCorto(c.plata));

  await hojaFormulario(
    context,
    titulo: 'Umbrales de medalla',
    campos: [
      Text(
        'Se guardan a la vez en CLOUD y LOCAL para que coincidan.\n'
        'Gran Oro ≥ Oro ≥ Plata. Códigos ciegos < 1000 no premian.',
        style: VirtusTexto.tenue(size: 13),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Campo(go, 'Gran Oro ≥', numero: true, autofocus: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(o, 'Oro ≥', numero: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(p, 'Plata ≥', numero: true)),
        ],
      ),
    ],
    guardar: () async {
      final avisos = await guardarUmbralesMedallas(
        ref,
        c.id,
        granOro: _numCampo(go) ?? 92,
        oro: _numCampo(o) ?? 85,
        plata: _numCampo(p) ?? 82,
      );
      if (context.mounted) aviso(context, avisos.join(' · '));
    },
  );
}

/// Formulario de concurso existente: nombre, fechas, umbrales de medalla.
Future<void> editarConcurso(BuildContext context, WidgetRef ref, Concurso c) async {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  final nombre = TextEditingController(text: c.nombre);
  final ini = TextEditingController(text: c.fechaInicio ?? '');
  final fin = TextEditingController(text: c.fechaFin ?? '');
  final go = TextEditingController(text: numCorto(c.granOro));
  final o = TextEditingController(text: numCorto(c.oro));
  final p = TextEditingController(text: numCorto(c.plata));
  final porMesa = TextEditingController(text: '${c.catadoresPorMesa}');
  var activo = c.activo;
  String? t(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();

  await hojaFormulario(
    context,
    titulo: 'Concurso',
    campos: [
      Campo(nombre, 'Nombre', autofocus: true),
      Row(
        children: [
          Expanded(child: Campo(ini, 'Inicio (AAAA-MM-DD)')),
          const SizedBox(width: 10),
          Expanded(child: Campo(fin, 'Fin (AAAA-MM-DD)')),
        ],
      ),
      Text('Umbrales (se sincronizan en CLOUD y LOCAL):', style: VirtusTexto.tenue(size: 12)),
      const SizedBox(height: 6),
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
      final granOro = _numCampo(go) ?? 92;
      final oro = _numCampo(o) ?? 85;
      final plata = _numCampo(p) ?? 82;
      // Resto de campos solo en el entorno activo.
      await repo.actualizar('concursos', c.id, {
        'nombre': nombre.text.trim(),
        'fecha_inicio': t(ini),
        'fecha_fin': t(fin),
        'catadores_por_mesa': int.tryParse(porMesa.text) ?? 5,
        'activo': activo,
      });
      // Umbrales en ambos para que el medallero coincida.
      final avisos = await guardarUmbralesMedallas(ref, c.id, granOro: granOro, oro: oro, plata: plata);
      if (context.mounted) aviso(context, avisos.join(' · '));
    },
  );
}
