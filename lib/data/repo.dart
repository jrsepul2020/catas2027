import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const _uuid = Uuid();

/// Acceso a datos. Todas las escrituras son directas a Supabase; la UI se
/// refresca sola por Realtime.
class Repo {
  Repo(this.c);
  final SupabaseClient c;

  String nuevoId() => _uuid.v4();

  Future<String> insertar(String tabla, Json datos) async {
    final id = (datos['id'] as String?) ?? nuevoId();
    await c.from(tabla).insert({...datos, 'id': id});
    return id;
  }

  Future<void> actualizar(String tabla, String id, Json datos) => c.from(tabla).update(datos).eq('id', id);

  /// Borrado lógico (se sincroniza entre entornos).
  Future<void> borrar(String tabla, String id) =>
      c.from(tabla).update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  // ------------------- operaciones de cata -------------------
  Future<void> intercambiarPuestos(String a, String b) => c.rpc('intercambiar_puestos', params: {'a': a, 'b': b});

  Future<void> moverCatador(String id, {String? mesaId, int? puesto}) =>
      c.from('catadores').update({'mesa_id': mesaId, 'puesto': puesto}).eq('id', id);

  Future<void> reordenar(String tabla, List<String> ids) => c.rpc('reordenar', params: {'tabla': tabla, 'ids': ids});

  Future<void> estadoTanda(String id, String estado) {
    final ahora = DateTime.now().toUtc().toIso8601String();
    return c
        .from('tandas')
        .update({
          'estado': estado,
          if (estado == 'en_curso') 'inicio_at': ahora,
          if (estado == 'cerrada') 'fin_at': ahora,
          if (estado == 'pendiente') ...{'inicio_at': null, 'fin_at': null},
        })
        .eq('id', id);
  }

  Future<void> puntuar({
    required String cataId,
    required String muestraId,
    required String catadorId,
    String? tandaId,
    required double? puntos,
    String? comentario,
  }) => c.from('puntuaciones').upsert({
    'cata_id': cataId,
    'muestra_id': muestraId,
    'catador_id': catadorId,
    'tanda_id': tandaId,
    'puntos': puntos,
    'comentario': ?comentario,
    'deleted_at': null,
    'anulada': false,
  }, onConflict: 'muestra_id,catador_id');

  Future<void> anadirMuestrasATanda(String cataId, String tandaId, List<String> muestraIds, int desde) async {
    if (muestraIds.isEmpty) return;
    await c.from('tanda_muestras').insert([
      for (var i = 0; i < muestraIds.length; i++)
        {'id': nuevoId(), 'cata_id': cataId, 'tanda_id': tandaId, 'muestra_id': muestraIds[i], 'orden': desde + i},
    ]);
  }

  Future<List<Resultado>> resultados(String cataId) async {
    final l = await c.from('v_resultados').select().eq('cata_id', cataId);
    return l.map(Resultado.new).toList();
  }

  Future<void> resolverIncidencia(String id, bool resuelta) => c
      .from('incidencias')
      .update({
        'estado': resuelta ? 'resuelta' : 'abierta',
        'resuelta_at': resuelta ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', id);
}
