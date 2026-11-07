import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';
import '../data/models.dart';

/// Tablas que se sincronizan, en orden de dependencias (padres primero),
/// con la columna que marca "cambiado desde".
const tablasSync = <(String, String)>[
  ('concursos', 'updated_at'),
  ('categorias', 'updated_at'),
  ('dias_concurso', 'updated_at'),
  ('mesas', 'updated_at'),
  ('catadores', 'updated_at'),
  ('muestras', 'updated_at'),
  ('tandas', 'updated_at'),
  ('tanda_muestras', 'updated_at'),
  ('puntuaciones', 'updated_at'),
  ('medallas', 'updated_at'),
  ('asignaciones', 'updated_at'),
  ('registro_cambios', 'creado_en'),
  ('sync_borrados', 'borrado_en'),
];

enum Direccion {
  ambas('Ambas'),
  cloudALocal('Bajar a LOCAL'),
  localACloud('Subir a CLOUD');

  const Direccion(this.texto);
  final String texto;
}

class ProgresoSync {
  ProgresoSync(this.tabla, this.mensaje);
  final String tabla;
  final String mensaje;
}

class ResultadoSync {
  final Map<String, (int, int)> porTabla = {}; // tabla -> (aplicadas en local, en cloud)
  final List<String> errores = [];
  int get totalLocal => porTabla.values.fold(0, (a, b) => a + b.$1);
  int get totalCloud => porTabla.values.fold(0, (a, b) => a + b.$2);
}

/// Sincronización Cloud <-> Local sobre el esquema de Catas2027.
///
/// * Incremental: lee de cada entorno solo lo cambiado desde la última marca.
/// * El servidor de destino decide (sync_aplicar): gana el `updated_at` más
///   reciente y se conserva tal cual, así no hay rebotes.
/// * Notas y muestras de tanda se emparejan por su clave natural
///   (catador+muestra, tanda+muestra), no por id.
/// * Los borrados viajan por `sync_borrados` y solo se aplican si el destino
///   no se modificó después.
/// * Tras bajar a LOCAL, sus secuencias saltan a >= 1.000.000 para que las
///   altas hechas en local nunca choquen con ids de cloud.
class SyncService {
  SyncService({required this.cloud, required this.local, required this.prefs});
  final SupabaseClient cloud;
  final SupabaseClient local;
  final SharedPreferences prefs;

  static const _pagina = 1000;
  static const _lote = 400;

  SupabaseClient _c(Entorno e) => e == Entorno.cloud ? cloud : local;

  String _kMarca(Entorno e, String t) => 'sync2_marca_${e.name}_$t';

  String? marca(Entorno e, String t) => prefs.getString(_kMarca(e, t));

  Future<void> olvidarMarcas() async {
    for (final e in Entorno.values) {
      for (final (t, _) in tablasSync) {
        await prefs.remove(_kMarca(e, t));
      }
    }
  }

  Future<List<Json>> _leer(
    Entorno e,
    String tabla,
    String col,
    String? desde, {
    PostgrestFilterBuilder<List<Json>> Function(PostgrestFilterBuilder<List<Json>>)? filtro,
  }) async {
    final out = <Json>[];
    var from = 0;
    while (true) {
      var q = _c(e).from(tabla).select();
      if (desde != null) q = q.gt(col, desde);
      if (filtro != null) q = filtro(q);
      final page = await q.order(col).order('id').range(from, from + _pagina - 1);
      out.addAll(page);
      if (page.length < _pagina) break;
      from += _pagina;
    }
    return out;
  }

  Future<int> _aplicar(Entorno destino, String tabla, List<Json> filas, ResultadoSync res) async {
    if (filas.isEmpty) return 0;
    var n = 0;
    for (var i = 0; i < filas.length; i += _lote) {
      final lote = filas.sublist(i, (i + _lote).clamp(0, filas.length));
      try {
        n += await _enviar(destino, tabla, lote);
      } catch (_) {
        // Fila a fila para aislar la que falla y seguir con el resto.
        for (final f in lote) {
          try {
            n += await _enviar(destino, tabla, [f]);
          } catch (e) {
            res.errores.add('${destino.corto} · $tabla · ${f['id']}: ${_msg(e)}');
          }
        }
      }
    }
    return n;
  }

  Future<int> _enviar(Entorno destino, String tabla, List<Json> filas) async {
    final r = tabla == 'sync_borrados'
        ? await _c(destino).rpc('sync_borrar', params: {'p_borrados': filas})
        : await _c(destino).rpc('sync_aplicar', params: {'p_tabla': tabla, 'p_filas': filas});
    return (r as num?)?.toInt() ?? 0;
  }

  static String _msg(Object e) => e is PostgrestException ? e.message : '$e';

  /// Filtro por día para lo que se BAJA de cloud: solo los datos de ese día.
  Future<Map<String, PostgrestFilterBuilder<List<Json>> Function(PostgrestFilterBuilder<List<Json>>)>> _filtrosDia(
    int dia,
  ) async {
    final tandas = (await cloud.from('tandas').select('id').eq('dia_id', dia)).map((r) => r['id'] as int).toList();
    final muestras = tandas.isEmpty
        ? <int>[]
        : (await cloud.from('tanda_muestras').select('muestra_id').inFilter('tanda_id', tandas))
              .map((r) => r['muestra_id'] as int)
              .toSet()
              .toList();
    return {
      'dias_concurso': (q) => q.eq('id', dia),
      'tandas': (q) => q.eq('dia_id', dia),
      'tanda_muestras': (q) => q.inFilter('tanda_id', tandas),
      'muestras': (q) => q.inFilter('id', muestras),
      'puntuaciones': (q) => q.inFilter('tanda_id', tandas),
      'medallas': (q) => q.inFilter('muestra_id', muestras),
      'asignaciones': (q) => q.eq('dia_id', dia),
      'registro_cambios': (q) => q.eq('dia_id', dia),
    };
  }

  /// [diaBajar]: al bajar, solo ese día (en LOCAL no hay días: se trabaja el día de cata).
  Stream<ProgresoSync> sincronizar(
    Direccion dir, {
    bool completa = false,
    int? diaBajar,
    required ResultadoSync res,
  }) async* {
    final bajar = dir != Direccion.localACloud;
    final subir = dir != Direccion.cloudALocal;
    final filtros = bajar && diaBajar != null ? await _filtrosDia(diaBajar) : const {};
    final sufijo = diaBajar == null ? '' : '@d$diaBajar';

    for (final (tabla, col) in tablasSync) {
      yield ProgresoSync(tabla, 'leyendo…');
      final mc = completa ? null : marca(Entorno.cloud, '$tabla$sufijo');
      final ml = completa ? null : marca(Entorno.local, tabla);
      final futC = bajar ? _leer(Entorno.cloud, tabla, col, mc, filtro: filtros[tabla]) : Future.value(<Json>[]);
      final futL = subir ? _leer(Entorno.local, tabla, col, ml) : Future.value(<Json>[]);
      final deCloud = await futC;
      final deLocal = await futL;

      yield ProgresoSync(tabla, 'enviando ${deCloud.length}→L · ${deLocal.length}→C…');
      final errAntes = res.errores.length;
      final nL = await _aplicar(Entorno.local, tabla, deCloud, res);
      final nC = await _aplicar(Entorno.cloud, tabla, deLocal, res);
      res.porTabla[tabla] = (nL, nC);

      // Las marcas solo avanzan si la tabla fue bien.
      if (res.errores.length == errAntes) {
        if (deCloud.isNotEmpty) {
          await prefs.setString(_kMarca(Entorno.cloud, '$tabla$sufijo'), deCloud.last[col] as String);
        }
        if (deLocal.isNotEmpty) await prefs.setString(_kMarca(Entorno.local, tabla), deLocal.last[col] as String);
      }
      yield ProgresoSync(tabla, '✓  $nL→L · $nC→C');
    }

    if (bajar) {
      try {
        await local.rpc('sync_preparar_local');
      } catch (e) {
        res.errores.add('LOCAL · secuencias: ${_msg(e)}');
      }
    }
    // Estado del servidor local (lo usa la app: en LOCAL se trabaja ese día).
    try {
      await local
          .from('sync_estado')
          .update({
            if (bajar && diaBajar != null) 'dia_id': diaBajar,
            'estado': subir && !bajar ? 'subido' : 'cargado',
            'actualizado_en': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', 1);
    } catch (e) {
      res.errores.add('LOCAL · sync_estado: ${_msg(e)}');
    }
  }
}
