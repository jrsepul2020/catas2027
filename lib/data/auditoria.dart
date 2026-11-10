import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import 'models.dart';

/// Un hallazgo de auditoría (SQL o comprobaciones ligeras en Dart).
class HallazgoAuditoria {
  const HallazgoAuditoria({required this.grupo, required this.texto, this.codigo});

  /// `mirar` = Hay que mirarlo · `cuenta` = Para tener en cuenta
  final String grupo;
  final String texto;
  final String? codigo;

  bool get hayQueMirarlo => grupo == 'mirar';
  bool get paraTenerEnCuenta => grupo == 'cuenta';
}

class ResultadoAuditoria {
  ResultadoAuditoria({required this.cuando, required this.hallazgos, this.error});

  final DateTime cuando;
  final List<HallazgoAuditoria> hallazgos;
  final String? error;

  List<HallazgoAuditoria> get mirar => hallazgos.where((h) => h.hayQueMirarlo).toList();
  List<HallazgoAuditoria> get cuenta => hallazgos.where((h) => h.paraTenerEnCuenta).toList();
  bool get todoCorrecto => hallazgos.isEmpty && error == null;
}

/// Comprueba estructurales ligeras (mesas, tandas, códigos…) sobre providers.
List<HallazgoAuditoria> comprobarEstructura(WidgetRef ref) {
  final mesas = ref.read(mesasProvider);
  final cats = ref.read(catadoresProvider);
  final tandas = ref.read(tandasProvider);
  final tms = ref.read(tandaMuestrasProvider);
  final muestras = ref.read(muestrasProvider);
  final porMesa = ref.read(concursoProvider)?.catadoresPorMesa ?? 5;
  final out = <HallazgoAuditoria>[];

  for (final m in mesas) {
    final enMesa = cats.where((c) => c.mesaId == m.id).toList();
    final presi = enMesa.where((c) => c.esPresidente).length;
    final puestos = enMesa.map((c) => c.puesto).whereType<int>().toList();
    final repetidos = puestos.toSet().length != puestos.length;
    if (enMesa.length != porMesa) {
      out.add(
        HallazgoAuditoria(
          grupo: 'cuenta',
          codigo: 'plantilla_mesa',
          texto: '${m.nombre}: ${enMesa.length}/$porMesa catadores (faltan o sobran puestos).',
        ),
      );
    }
    if (presi != 1) {
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'presidentes',
          texto: '${m.nombre}: hay $presi presidentes; debe haber exactamente 1.',
        ),
      );
    }
    if (repetidos) {
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'puestos_repetidos',
          texto: '${m.nombre}: hay dos catadores con el mismo puesto.',
        ),
      );
    }
    if (enMesa.any((c) => c.puesto == null)) {
      out.add(
        HallazgoAuditoria(
          grupo: 'cuenta',
          codigo: 'puesto_vacio',
          texto: '${m.nombre}: algún catador no tiene puesto asignado.',
        ),
      );
    }
  }

  final sueltos = cats.where((c) => c.mesaId == null && c.presente).length;
  if (sueltos > 0) {
    out.add(
      HallazgoAuditoria(grupo: 'cuenta', codigo: 'sin_mesa', texto: '$sueltos catadores presentes sin mesa asignada.'),
    );
  }

  for (final m in mesas) {
    final abiertas = tandas.where((t) => t.mesaId == m.id && t.estado == 'abierta').length;
    if (abiertas > 1) {
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'tandas_abiertas',
          texto: '${m.nombre}: $abiertas tandas abiertas a la vez (solo puede haber una).',
        ),
      );
    }
  }

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
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'activas',
          texto: '${t.nombre}: $activas muestras activas (las tablets solo muestran una).',
        ),
      );
    }
    final ordenes = lista.map((x) => x.orden).toList();
    final esperado = [for (var i = 1; i <= ordenes.length; i++) i];
    if (ordenes.join(',') != esperado.join(',')) {
      out.add(
        HallazgoAuditoria(
          grupo: 'cuenta',
          codigo: 'orden_muestras',
          texto: '${t.nombre}: el orden de muestras no es 1…${ordenes.length} contiguo.',
        ),
      );
    }
    if (t.categoriaId != null) {
      final otras = lista.where((tm) => muestrasPorId[tm.muestraId]?.categoriaId != t.categoriaId).length;
      if (otras > 0) {
        out.add(
          HallazgoAuditoria(
            grupo: 'mirar',
            codigo: 'categoria',
            texto: '${t.nombre}: $otras muestras de otra categoría que la de la tanda.',
          ),
        );
      }
    }
  }

  final tandasDeMuestra = <int, List<int>>{};
  for (final tm in tms) {
    if (!tandasPorId.containsKey(tm.tandaId)) continue;
    (tandasDeMuestra[tm.muestraId] ??= []).add(tm.tandaId);
  }
  for (final e in tandasDeMuestra.entries) {
    final ids = e.value.toSet();
    if (ids.length > 1) {
      final cod = muestrasPorId[e.key]?.codigo ?? '?';
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'muestra_varias_tandas',
          texto:
              'Código $cod está en ${ids.length} tandas: '
              '${ids.map((id) => tandasPorId[id]?.nombre ?? '$id').join(', ')}.',
        ),
      );
    }
  }

  final porCodigo = <String, List<Muestra>>{};
  for (final m in muestras) {
    if (m.codigo.isEmpty) continue;
    (porCodigo[m.codigo] ??= []).add(m);
  }
  for (final e in porCodigo.entries) {
    if (e.value.length > 1) {
      out.add(
        HallazgoAuditoria(
          grupo: 'mirar',
          codigo: 'codigo_duplicado',
          texto: 'Código ciego ${e.key} repetido en ${e.value.length} muestras.',
        ),
      );
    }
  }

  final libres = ref.read(tabletsLibresProvider).length;
  if (libres == 0) {
    out.add(
      const HallazgoAuditoria(
        grupo: 'cuenta',
        codigo: 'sin_reserva',
        texto: 'No hay tablets de reserva; conviene tener al menos 1–2 libres.',
      ),
    );
  }

  return out;
}

List<HallazgoAuditoria> _parseHallazgosSql(dynamic raw) {
  if (raw is! List) return const [];
  final out = <HallazgoAuditoria>[];
  for (final e in raw) {
    if (e is! Map) continue;
    final grupo = '${e['grupo'] ?? 'mirar'}';
    final texto = '${e['texto'] ?? ''}'.trim();
    if (texto.isEmpty) continue;
    out.add(
      HallazgoAuditoria(grupo: grupo == 'cuenta' ? 'cuenta' : 'mirar', texto: texto, codigo: e['codigo']?.toString()),
    );
  }
  return out;
}

/// Llama a la RPC SQL de comprobaciones pesadas del día LOCAL.
Future<List<HallazgoAuditoria>> comprobarSqlLocal(SupabaseClient local) async {
  final raw = await local.rpc('auditoria_dia_local');
  return _parseHallazgosSql(raw);
}

/// Auditoría completa: estructura (Dart) +, si hay cliente LOCAL, las 8 revisiones SQL.
Future<ResultadoAuditoria> ejecutarAuditoria({
  required WidgetRef ref,
  SupabaseClient? local,
  bool soloSqlLocal = false,
}) async {
  final cuando = DateTime.now();
  final hallazgos = <HallazgoAuditoria>[];
  String? error;

  if (!soloSqlLocal) {
    hallazgos.addAll(comprobarEstructura(ref));
  }

  if (local != null) {
    try {
      hallazgos.addAll(await comprobarSqlLocal(local));
    } catch (e) {
      error = 'No se pudieron ejecutar las comprobaciones SQL: $e';
    }
  }

  // Deduplicar textos idénticos.
  final vistos = <String>{};
  final unicos = <HallazgoAuditoria>[];
  for (final h in hallazgos) {
    if (vistos.add('${h.grupo}|${h.texto}')) unicos.add(h);
  }

  return ResultadoAuditoria(cuando: cuando, hallazgos: unicos, error: error);
}

String formatearHoraAuditoria(DateTime t) {
  final l = t.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  final ss = l.second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
