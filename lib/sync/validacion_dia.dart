import '../data/models.dart';

/// Comprueba que un día en CLOUD está listo para bajar a LOCAL.
/// Devuelve lista vacía si todo OK; si no, los problemas (en español).
List<String> validarDiaParaBajar({
  required int diaId,
  required List<Mesa> mesas,
  required List<Json> asignaciones,
  required List<Tanda> tandas,
  required List<TandaMuestra> tandaMuestras,
  required List<Muestra> muestras,
  required List<Categoria> categorias,
  int catadoresPorMesa = 5,
}) {
  final problemas = <String>[];
  final cats = {for (final c in categorias) c.id: c};
  final muestrasIdx = {for (final m in muestras) m.id: m};

  final asigsDia = asignaciones.where((a) => (a['dia_id'] as num?)?.toInt() == diaId).toList();
  final tandasDia = tandas.where((t) => t.diaId == diaId).toList();
  // previstos del concurso: se aceptan 4 o 5; se menciona si el concurso pide otro número
  final previstos = catadoresPorMesa;

  // Catador en dos mesas el mismo día
  final vistos = <int>{};
  for (final a in asigsDia) {
    final cid = (a['catador_id'] as num?)?.toInt();
    if (cid == null) continue;
    if (!vistos.add(cid)) {
      problemas.add('Catador $cid asignado a más de una mesa el mismo día');
    }
  }

  for (final mesa in mesas) {
    final deMesa = asigsDia.where((a) => (a['mesa_id'] as num?)?.toInt() == mesa.id).toList();
    final n = deMesa.length;
    final tieneTandas = tandas.where((t) => t.diaId == diaId && t.mesaId == mesa.id).isNotEmpty;
    if (n == 0 && !tieneTandas) continue;
    if (n != 4 && n != 5) {
      problemas.add(
        '${mesa.nombre}: $n catadores asignados (deben ser 4 o 5'
        '${previstos != 5 ? '; el concurso prevé $previstos' : ''})',
      );
    }
    final presi = deMesa.where((a) => a['rol'] == 'presidente').length;
    if (n > 0 && presi != 1) {
      problemas.add('${mesa.nombre}: $presi presidentes (debe haber exactamente 1)');
    }
    final puestos = <int>{};
    for (final a in deMesa) {
      final p = (a['puesto'] as num?)?.toInt();
      if (p == null) {
        problemas.add('${mesa.nombre}: hay un puesto vacío');
        continue;
      }
      if (!puestos.add(p)) {
        problemas.add('${mesa.nombre}: puesto $p repetido');
      }
    }
  }

  // Mesas sin asignación pero con tandas ese día
  for (final t in tandasDia) {
    if (t.mesaId == null) {
      problemas.add('${t.nombre}: sin mesa');
    }
    final tms = tandaMuestras.where((x) => x.tandaId == t.id).toList();
    if (tms.isEmpty) {
      problemas.add('${t.nombre}: sin muestras');
    }
  }

  // Muestra en dos tandas del mismo día
  final muestraTanda = <int, int>{};
  for (final t in tandasDia) {
    for (final tm in tandaMuestras.where((x) => x.tandaId == t.id)) {
      final prev = muestraTanda[tm.muestraId];
      if (prev != null && prev != t.id) {
        final cod = muestrasIdx[tm.muestraId]?.codigo ?? '${tm.muestraId}';
        problemas.add('Muestra $cod en dos tandas del mismo día');
      }
      muestraTanda[tm.muestraId] = t.id;
    }
  }

  // Tandas AOVE solo con muestras AOVE
  bool esAove(Categoria? c) {
    if (c == null) return false;
    final t = '${c.codigo} ${c.nombre}'.toLowerCase();
    return t.contains('aove') || t.contains('aceite');
  }

  for (final t in tandasDia) {
    final catT = cats[t.categoriaId];
    if (!esAove(catT)) continue;
    for (final tm in tandaMuestras.where((x) => x.tandaId == t.id)) {
      final m = muestrasIdx[tm.muestraId];
      final catM = cats[m?.categoriaId];
      if (!esAove(catM)) {
        problemas.add(
          '${t.nombre} (AOVE) incluye muestra ${m?.codigo ?? tm.muestraId} '
          'de categoría ${catM?.nombre ?? 'desconocida'}',
        );
      }
    }
  }

  for (final mesa in mesas) {
    final n = asigsDia.where((a) => (a['mesa_id'] as num?)?.toInt() == mesa.id).length;
    final tieneTandas = tandasDia.any((t) => t.mesaId == mesa.id);
    if (tieneTandas && n == 0) {
      problemas.add('${mesa.nombre}: tiene tandas pero ningún catador asignado');
    }
  }

  return problemas.toSet().toList();
}

/// Comprueba una mesa en LOCAL tras un cambio de última hora (no bloquea).
List<String> avisosMesaLocal(List<Catador> deMesa, {required String nombreMesa, int previstos = 5}) {
  final avisos = <String>[];
  final n = deMesa.length;
  if (n != 4 && n != 5 && n != previstos) {
    avisos.add('$nombreMesa: $n catadores (previstos 4 o 5)');
  }
  final presi = deMesa.where((c) => c.esPresidente).length;
  if (presi != 1) avisos.add('$nombreMesa: $presi presidentes (debe haber 1)');
  final puestos = <int>{};
  for (final c in deMesa) {
    final p = c.puesto;
    if (p == null) {
      avisos.add('$nombreMesa: ${c.nombre} sin puesto');
    } else if (!puestos.add(p)) {
      avisos.add('$nombreMesa: puesto $p repetido');
    }
  }
  return avisos;
}

/// Número de tablet física para un asiento: (nº mesa − 1) × 5 + puesto.
int numeroTablet({required int numeroMesa, required int puesto}) => (numeroMesa - 1) * 5 + puesto;
