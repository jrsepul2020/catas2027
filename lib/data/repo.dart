import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Acceso a datos sobre el esquema de Catas2027. La UI se refresca sola por
/// Realtime; las operaciones delicadas van por RPC (atómicas y auditadas en
/// registro_cambios).
class Repo {
  Repo(this.c);
  final SupabaseClient c;

  Future<int> insertar(String tabla, Json datos) async {
    final r = await c.from(tabla).insert(datos).select('id').single();
    return (r['id'] as num).toInt();
  }

  Future<void> actualizar(String tabla, int id, Json datos) => c.from(tabla).update(datos).eq('id', id);

  Future<void> borrar(String tabla, int id) => c.from(tabla).delete().eq('id', id);

  Future<void> registrar(String accion, {String? tabla, String? registroId, String? motivo, int? diaId}) => c
      .from('registro_cambios')
      .insert({'accion': accion, 'tabla': ?tabla, 'registro_id': ?registroId, 'motivo': ?motivo, 'dia_id': ?diaId});

  // ------------------- catadores y puestos -------------------
  Future<void> intercambiarPuestos(int a, int b, {String? motivo}) =>
      c.rpc('intercambiar_puestos', params: {'a': a, 'b': b, 'p_motivo': motivo});

  Future<void> moverCatador(int id, int mesaId, int puesto, {String? motivo}) =>
      c.rpc('mover_catador', params: {'p_catador': id, 'p_mesa': mesaId, 'p_puesto': puesto, 'p_motivo': motivo});

  Future<void> quitarDeMesa(int id) =>
      c.from('catadores').update({'mesa_id': null, 'mesa': null, 'puesto': null}).eq('id', id);

  // ------------------- tandas -------------------
  Future<void> reordenarTandas(List<int> ids, {String? motivo}) =>
      c.rpc('reordenar_tandas', params: {'ids': ids, 'p_motivo': motivo});

  Future<void> reordenarMuestras(int tandaId, List<int> ids) =>
      c.rpc('reordenar_muestras', params: {'p_tanda': tandaId, 'ids': ids});

  Future<void> estadoTanda(int id, String estado) => c.from('tandas').update({'estado': estado}).eq('id', id);

  Future<void> anadirMuestrasATanda(int tandaId, List<int> muestraIds, int desde) async {
    if (muestraIds.isEmpty) return;
    await c.from('tanda_muestras').insert([
      for (var i = 0; i < muestraIds.length; i++)
        {'tanda_id': tandaId, 'muestra_id': muestraIds[i], 'orden': desde + i + 1, 'estado': 'pendiente'},
    ]);
  }

  Future<void> activarMuestra(int tmId) => c.rpc('activar_muestra', params: {'p_tm': tmId});

  Future<int> aprobarMuestra(int tmId) async =>
      ((await c.rpc('aprobar_muestra', params: {'p_tm': tmId})) as num?)?.toInt() ?? 0;

  // ------------------- incidencias -------------------
  Future<void> marcarIncidencia(int tmId, String motivo) =>
      c.rpc('marcar_incidencia', params: {'p_tm': tmId, 'p_motivo': motivo});

  /// accion: recatar | pasar_al_final | quitar_de_tanda | continuar
  Future<String> resolverIncidencia(int tmId, String accion, {String? motivo}) async =>
      (await c.rpc(
        'resolver_incidencia',
        params: {'p_tm': tmId, 'p_accion': accion, 'p_motivo': motivo},
      ))?.toString() ??
      '';

  // ------------------- puntuaciones -------------------
  /// Nota manual (p. ej. de una ficha en papel). Las tablets envían el desglose.
  Future<void> puntuarManual({
    required int muestraId,
    required int catadorId,
    required int tandaId,
    required double total,
  }) => c.from('puntuaciones').upsert({
    'muestra_id': muestraId,
    'catador_id': catadorId,
    'tanda_id': tandaId,
    'total': total,
    'scores': {'manual': true, 'total': total},
    'estado': 'enviada',
  }, onConflict: 'catador_id,muestra_id');

  Future<void> borrarPuntuacion(int id) => c.from('puntuaciones').delete().eq('id', id);

  // ------------------- medallas -------------------
  Future<List<Resultado>> resultados(int? concursoId) async {
    var q = c.from('v_resultados_gestion').select();
    if (concursoId != null) q = q.eq('concurso_id', concursoId);
    final l = await q;
    return l.map(Resultado.new).toList();
  }

  Future<void> fijarMedalla(int muestraId, String? medalla, double media) =>
      c.rpc('fijar_medalla', params: {'p_muestra': muestraId, 'p_medalla': medalla, 'p_media': media});
}
