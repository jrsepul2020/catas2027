import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';

class _Aviso {
  const _Aviso(this.nivel, this.titulo, this.detalle);
  final String nivel; // error | aviso | ok
  final String titulo;
  final String detalle;
  MaterialColor get color => switch (nivel) {
    'error' => Colors.red,
    'aviso' => Colors.amber,
    _ => Colors.blue,
  };
}

/// Comprueba incongruencias del día de trabajo (mesas, tandas, muestras…).
List<_Aviso> _comprobar(WidgetRef ref) {
  final mesas = ref.watch(mesasProvider);
  final cats = ref.watch(catadoresProvider);
  final tandas = ref.watch(tandasProvider);
  final tms = ref.watch(tandaMuestrasProvider);
  final muestras = ref.watch(muestrasProvider);
  final porMesa = ref.watch(concursoProvider)?.catadoresPorMesa ?? 5;
  final avisos = <_Aviso>[];

  // Mesas: plantilla y presidente.
  for (final m in mesas) {
    final enMesa = cats.where((c) => c.mesaId == m.id).toList();
    final presi = enMesa.where((c) => c.esPresidente).length;
    final puestos = enMesa.map((c) => c.puesto).whereType<int>().toList();
    final repetidos = puestos.toSet().length != puestos.length;
    if (enMesa.length != porMesa) {
      avisos.add(
        _Aviso('aviso', '${m.nombre}: ${enMesa.length}/$porMesa catadores', 'Faltan o sobran puestos en la mesa.'),
      );
    }
    if (presi != 1) {
      avisos.add(_Aviso('error', '${m.nombre}: $presi presidentes', 'Debe haber exactamente 1 presidente.'));
    }
    if (repetidos) {
      avisos.add(_Aviso('error', '${m.nombre}: puestos repetidos', 'Hay dos catadores con el mismo puesto.'));
    }
    if (enMesa.any((c) => c.puesto == null)) {
      avisos.add(_Aviso('aviso', '${m.nombre}: puesto sin número', 'Algún catador no tiene puesto asignado.'));
    }
  }

  // Catadores sin mesa.
  final sueltos = cats.where((c) => c.mesaId == null && c.presente).length;
  if (sueltos > 0) {
    avisos.add(_Aviso('aviso', '$sueltos catadores presentes sin mesa', 'Revisa la asignación de puestos.'));
  }

  // Una tanda abierta por mesa.
  for (final m in mesas) {
    final abiertas = tandas.where((t) => t.mesaId == m.id && t.estado == 'abierta').length;
    if (abiertas > 1) {
      avisos.add(_Aviso('error', '${m.nombre}: $abiertas tandas abiertas', 'Solo puede haber una tanda abierta.'));
    }
  }

  // Una muestra activa por tanda + categoría coherente + orden contiguo.
  final tandasPorId = {for (final t in tandas) t.id: t};
  final muestrasPorId = {for (final m in muestras) m.id: m};
  final porTanda = <int, List<TandaMuestra>>{};
  for (final tm in tms) {
    if (!tandasPorId.containsKey(tm.tandaId)) continue;
    (porTanda[tm.tandaId] ??= []).add(tm);
  }
  for (final e in porTanda.entries) {
    final t = tandasPorId[e.key]!;
    final lista = [...e.value]..sort((a, b) => a.orden.compareTo(b.orden));
    final activas = lista.where((x) => x.estado == 'activa').length;
    if (activas > 1) {
      avisos.add(_Aviso('error', '${t.nombre}: $activas muestras activas', 'Las tablets solo muestran una.'));
    }
    final ordenes = lista.map((x) => x.orden).toList();
    final esperado = [for (var i = 1; i <= ordenes.length; i++) i];
    if (ordenes.join(',') != esperado.join(',')) {
      avisos.add(
        _Aviso('aviso', '${t.nombre}: orden de muestras irregular', 'Debería ser 1…${ordenes.length} contiguo.'),
      );
    }
    if (t.categoriaId != null) {
      final otras = lista.where((tm) => muestrasPorId[tm.muestraId]?.categoriaId != t.categoriaId).length;
      if (otras > 0) {
        avisos.add(
          _Aviso('error', '${t.nombre}: $otras muestras de otra categoría', 'La categoría de la tanda no coincide.'),
        );
      }
    }
  }

  // Misma muestra en varias tandas del día.
  final tandasDeMuestra = <int, List<int>>{};
  for (final tm in tms) {
    if (!tandasPorId.containsKey(tm.tandaId)) continue;
    (tandasDeMuestra[tm.muestraId] ??= []).add(tm.tandaId);
  }
  for (final e in tandasDeMuestra.entries) {
    final ids = e.value.toSet();
    if (ids.length > 1) {
      final cod = muestrasPorId[e.key]?.codigo ?? '?';
      avisos.add(
        _Aviso(
          'error',
          'Código $cod en ${ids.length} tandas',
          ids.map((id) => tandasPorId[id]?.nombre ?? '$id').join(', '),
        ),
      );
    }
  }

  // Códigos ciegos duplicados.
  final porCodigo = <String, List<Muestra>>{};
  for (final m in muestras) {
    if (m.codigo.isEmpty) continue;
    (porCodigo[m.codigo] ??= []).add(m);
  }
  for (final e in porCodigo.entries) {
    if (e.value.length > 1) {
      avisos.add(_Aviso('error', 'Código ciego ${e.key} repetido', '${e.value.length} muestras con el mismo código.'));
    }
  }

  // Tablets de reserva.
  final libres = ref.watch(tabletsLibresProvider).length;
  if (libres == 0) {
    avisos.add(const _Aviso('aviso', 'Sin tablets de reserva', 'Conviene tener al menos 1–2 tablets libres.'));
  } else {
    avisos.add(_Aviso('ok', '$libres tablet${libres == 1 ? '' : 's'} de reserva', 'Listas para sustituir una rota.'));
  }

  if (avisos.where((a) => a.nivel != 'ok').isEmpty) {
    avisos.insert(0, const _Aviso('ok', 'Sin incongruencias graves', 'Mesas, tandas y muestras cuadran.'));
  }
  return avisos;
}

class AuditoriaScreen extends ConsumerWidget {
  const AuditoriaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avisos = _comprobar(ref);
    final errores = avisos.where((a) => a.nivel == 'error').length;
    final warnings = avisos.where((a) => a.nivel == 'aviso').length;
    final k = esCompacto(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría'), actions: const [ChipDia(), ChipEntorno()]),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 14, k ? 12 : 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      errores == 0 && warnings == 0
                          ? 'Todo en orden'
                          : '$errores error${errores == 1 ? '' : 'es'} · $warnings aviso${warnings == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: k ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: errores > 0 ? Paleta.rojo : (warnings > 0 ? Paleta.amarilloOscuro : Paleta.azulOscuro),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListaLlena(
                itemCount: avisos.length,
                gap: k ? 8 : 10,
                padding: EdgeInsets.fromLTRB(k ? 10 : 14, 0, k ? 10 : 14, k ? 10 : 14),
                altoMinimo: k ? 88 : 100,
                itemBuilder: (c, i) {
                  final a = avisos[i];
                  return Card(
                    color: Color.alphaBlend(a.color.shade400.withValues(alpha: 0.12), Colors.white),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: k ? 12 : 16, vertical: k ? 10 : 14),
                      child: Row(
                        children: [
                          Icon(
                            a.nivel == 'error'
                                ? Icons.error
                                : a.nivel == 'aviso'
                                ? Icons.warning_amber_rounded
                                : Icons.verified,
                            size: k ? 28 : 34,
                            color: a.color.shade800,
                          ),
                          SizedBox(width: k ? 10 : 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  a.titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: k ? 15 : 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  a.detalle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: k ? 13 : 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
