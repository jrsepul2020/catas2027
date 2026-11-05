import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/backend.dart';
import '../data/models.dart';

/// Orden de tablas respetando claves foráneas (padres primero).
const tablasSync = [
  'catas',
  'mesas',
  'catadores',
  'muestras',
  'tandas',
  'tanda_muestras',
  'puntuaciones',
  'incidencias',
];

enum Direccion { cloudALocal, localACloud, ambas }

class ProgresoSync {
  ProgresoSync(this.tabla, this.mensaje, {this.enviadosLocal = 0, this.enviadosCloud = 0});
  final String tabla;
  final String mensaje;
  final int enviadosLocal;
  final int enviadosCloud;
}

class ResultadoSync {
  final Map<String, (int, int)> porTabla = {}; // tabla -> (a local, a cloud)
  final List<String> errores = [];
  int get totalLocal => porTabla.values.fold(0, (a, b) => a + b.$1);
  int get totalCloud => porTabla.values.fold(0, (a, b) => a + b.$2);
}

/// Sincronización Cloud <-> Local con "last write wins" sobre `updated_at`.
///
/// * Incremental: solo lee filas con `updated_at` posterior a la última marca
///   vista en cada entorno (marcas guardadas por entorno y tabla).
/// * Los borrados viajan como `deleted_at` (borrado lógico).
/// * Las puntuaciones se emparejan por (muestra_id, catador_id) para que dos
///   entornos que puntuaron lo mismo con ids distintos no colisionen.
class SyncService {
  SyncService({required this.cloud, required this.local, required this.prefs});
  final SupabaseClient cloud;
  final SupabaseClient local;
  final SharedPreferences prefs;

  static const _pagina = 1000;
  static const _lote = 500;

  SupabaseClient _c(Entorno e) => e == Entorno.cloud ? cloud : local;

  String _kMarca(Entorno e, String t) => 'sync_marca_${e.name}_$t';

  DateTime? marca(Entorno e, String t) {
    final s = prefs.getString(_kMarca(e, t));
    return s == null ? null : DateTime.parse(s);
  }

  Future<void> olvidarMarcas() async {
    for (final e in Entorno.values) {
      for (final t in tablasSync) {
        await prefs.remove(_kMarca(e, t));
      }
    }
  }

  static String _clave(String tabla, Json r) =>
      tabla == 'puntuaciones' ? '${r['muestra_id']}|${r['catador_id']}' : r['id'] as String;

  static DateTime _upd(Json r) => DateTime.parse(r['updated_at'] as String);

  Future<List<Json>> _leer(Entorno e, String tabla, DateTime? desde) async {
    final out = <Json>[];
    var from = 0;
    while (true) {
      var q = _c(e).from(tabla).select();
      if (desde != null) q = q.gt('updated_at', desde.toUtc().toIso8601String());
      final page = await q.order('updated_at').order('id').range(from, from + _pagina - 1);
      out.addAll(page);
      if (page.length < _pagina) break;
      from += _pagina;
    }
    return out;
  }

  /// Filtra [filas] dejando solo las que son más nuevas que en [destino].
  Future<List<Json>> _masNuevas(List<Json> filas, Entorno destino, String tabla) async {
    if (filas.isEmpty) return filas;
    final versiones = <String, DateTime>{};
    final esPunt = tabla == 'puntuaciones';
    final campo = esPunt ? 'muestra_id' : 'id';
    final valores = filas.map((f) => f[campo] as String).toSet().toList();
    for (var i = 0; i < valores.length; i += 150) {
      final trozo = valores.sublist(i, (i + 150).clamp(0, valores.length));
      final l = await _c(destino)
          .from(tabla)
          .select(esPunt ? 'muestra_id,catador_id,updated_at' : 'id,updated_at')
          .inFilter(campo, trozo);
      for (final r in l) {
        versiones[_clave(tabla, r)] = _upd(r);
      }
    }
    return filas.where((f) {
      final v = versiones[_clave(tabla, f)];
      return v == null || _upd(f).isAfter(v);
    }).toList();
  }

  Future<int> _escribir(Entorno destino, String tabla, List<Json> filas, ResultadoSync res) async {
    if (filas.isEmpty) return 0;
    final esPunt = tabla == 'puntuaciones';
    final payload = [for (final f in filas) esPunt ? (Map.of(f)..remove('id')) : f];
    final onConflict = esPunt ? 'muestra_id,catador_id' : 'id';
    var ok = 0;
    for (var i = 0; i < payload.length; i += _lote) {
      final lote = payload.sublist(i, (i + _lote).clamp(0, payload.length));
      try {
        await _c(destino).from(tabla).upsert(lote, onConflict: onConflict);
        ok += lote.length;
      } catch (_) {
        // Fallback fila a fila para aislar el registro problemático.
        for (final f in lote) {
          try {
            await _c(destino).from(tabla).upsert(f, onConflict: onConflict);
            ok++;
          } catch (e) {
            res.errores.add('${destino.corto} · $tabla · ${f['id'] ?? _clave(tabla, f)}: $e');
          }
        }
      }
    }
    return ok;
  }

  Stream<ProgresoSync> sincronizar(
    Direccion dir, {
    bool completa = false,
    String? soloCataId,
    required ResultadoSync res,
  }) async* {
    for (final tabla in tablasSync) {
      yield ProgresoSync(tabla, 'Leyendo $tabla…');
      final mc = completa ? null : marca(Entorno.cloud, tabla);
      final ml = completa ? null : marca(Entorno.local, tabla);

      final leerCloud = dir != Direccion.localACloud;
      final leerLocal = dir != Direccion.cloudALocal;
      final futCloud = leerCloud ? _leer(Entorno.cloud, tabla, mc) : Future.value(<Json>[]);
      final futLocal = leerLocal ? _leer(Entorno.local, tabla, ml) : Future.value(<Json>[]);
      var filasCloud = await futCloud;
      var filasLocal = await futLocal;

      bool deCata(Json r) =>
          soloCataId == null || (tabla == 'catas' ? r['id'] == soloCataId : r['cata_id'] == soloCataId);
      filasCloud = filasCloud.where(deCata).toList();
      filasLocal = filasLocal.where(deCata).toList();

      // Last-write-wins: solo se envía una fila si en el destino no existe
      // o su updated_at es más antiguo. Se consultan las versiones reales
      // del destino (no solo las cambiadas) para evitar rebotes infinitos.
      final aLocal = leerCloud ? await _masNuevas(filasCloud, Entorno.local, tabla) : <Json>[];
      final aCloud = leerLocal ? await _masNuevas(filasLocal, Entorno.cloud, tabla) : <Json>[];

      yield ProgresoSync(tabla, 'Enviando $tabla (${aLocal.length}→L, ${aCloud.length}→C)…');
      final nL = await _escribir(Entorno.local, tabla, aLocal, res);
      final nC = await _escribir(Entorno.cloud, tabla, aCloud, res);
      res.porTabla[tabla] = (nL, nC);

      // Avanzar marcas solo si no hubo errores en esta tabla.
      final errTabla = res.errores.any((e) => e.contains('· $tabla ·'));
      if (!errTabla && soloCataId == null) {
        if (filasCloud.isNotEmpty) {
          await prefs.setString(_kMarca(Entorno.cloud, tabla), _upd(filasCloud.last).toIso8601String());
        }
        if (filasLocal.isNotEmpty) {
          await prefs.setString(_kMarca(Entorno.local, tabla), _upd(filasLocal.last).toIso8601String());
        }
      }
      yield ProgresoSync(tabla, '$tabla ✓', enviadosLocal: nL, enviadosCloud: nC);
    }
  }
}
