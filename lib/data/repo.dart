import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/sync_service.dart';
import '../sync/validacion_dia.dart';
import 'models.dart';

/// Acceso a datos sobre el esquema de Catas2027. La UI se refresca sola por
/// Realtime; las operaciones delicadas van por RPC (atómicas y auditadas en
/// registro_cambios).
class Repo {
  Repo(this.c, {this.esLocal = false, this.diaId});
  final SupabaseClient c;

  /// true = servidor LOCAL de la sede (catadores aplanados + dispositivos).
  final bool esLocal;

  /// Día activo en CLOUD (para escribir asignaciones en modo pruebas).
  final int? diaId;

  Future<int> insertar(String tabla, Json datos) async {
    final r = await c.from(tabla).insert(datos).select('id').single();
    return (r['id'] as num).toInt();
  }

  Future<void> actualizar(String tabla, int id, Json datos) => c.from(tabla).update(datos).eq('id', id);

  Future<void> borrar(String tabla, int id) => c.from(tabla).delete().eq('id', id);

  Future<void> registrar(String accion, {String? tabla, String? registroId, String? motivo, int? diaId}) => c
      .from('registro_cambios')
      .insert({'accion': accion, 'tabla': ?tabla, 'registro_id': ?registroId, 'motivo': ?motivo, 'dia_id': ?diaId});

  // ------------------- catadores y puestos (solo LOCAL / pruebas) -------------------

  Future<Map<int, int>> _mapaNumeroMesa() async {
    final mesas = await c.from('mesas').select('id, numero');
    return {for (final m in mesas) (m['id'] as num).toInt(): (m['numero'] as num).toInt()};
  }

  Future<Json?> _catador(int id) => c.from('catadores').select().eq('id', id).maybeSingle();

  /// Tras mover gente, revalida la(s) mesa(s) y devuelve avisos (no bloquea).
  Future<List<String>> _avisosMesas(Iterable<int?> mesaIds) async {
    final nums = await _mapaNumeroMesa();
    final avisos = <String>[];
    for (final mid in mesaIds.whereType<int>().toSet()) {
      final filas = await c.from('catadores').select().eq('mesa_id', mid);
      final cats = filas.map((r) => Catador(Map<String, dynamic>.from(r as Map))).toList();
      final nombre = 'Mesa ${nums[mid] ?? mid}';
      avisos.addAll(avisosMesaLocal(cats, nombreMesa: nombre));
    }
    return avisos;
  }

  Future<List<String>> intercambiarPuestos(int a, int b, {String? motivo}) async {
    if (!esLocal) {
      return _intercambiarAsignaciones(a, b, motivo: motivo);
    }
    final ca = await _catador(a);
    final cb = await _catador(b);
    if (ca == null || cb == null) throw StateError('Catador no encontrado');
    final nums = await _mapaNumeroMesa();
    final mesaA = (ca['mesa_id'] as num?)?.toInt();
    final mesaB = (cb['mesa_id'] as num?)?.toInt();
    final puestoA = (ca['puesto'] as num?)?.toInt();
    final puestoB = (cb['puesto'] as num?)?.toInt();
    final numA = mesaA == null ? null : nums[mesaA];
    final numB = mesaB == null ? null : nums[mesaB];

    await c.from('catadores').update({'mesa_id': mesaB, 'mesa': numB, 'puesto': puestoB}).eq('id', a);
    await c.from('catadores').update({'mesa_id': mesaA, 'mesa': numA, 'puesto': puestoA}).eq('id', b);

    await SyncService.recalcularAsientos(
      c,
      asientos: [(numeroMesa: numB, puesto: puestoB, catadorId: a), (numeroMesa: numA, puesto: puestoA, catadorId: b)],
    );
    await registrar(
      'cambio_puesto',
      tabla: 'catadores',
      registroId: '$a,$b',
      motivo: motivo ?? 'Intercambio de puestos (LOCAL)',
    );
    return _avisosMesas([mesaA, mesaB]);
  }

  Future<List<String>> moverCatador(int id, int mesaId, int puesto, {String? motivo}) async {
    if (!esLocal) {
      return _moverAsignacion(id, mesaId, puesto, motivo: motivo);
    }
    final nums = await _mapaNumeroMesa();
    final yo = await _catador(id);
    if (yo == null) throw StateError('Catador no encontrado');
    final mesaAntes = (yo['mesa_id'] as num?)?.toInt();
    final puestoAntes = (yo['puesto'] as num?)?.toInt();
    final numAntes = mesaAntes == null ? null : nums[mesaAntes];
    final numNuevo = nums[mesaId];

    // Si el destino está ocupado, intercambia
    final ocupante = await c
        .from('catadores')
        .select('id')
        .eq('mesa_id', mesaId)
        .eq('puesto', puesto)
        .neq('id', id)
        .maybeSingle();
    if (ocupante != null) {
      return intercambiarPuestos(id, (ocupante['id'] as num).toInt(), motivo: motivo);
    }

    await c.from('catadores').update({'mesa_id': mesaId, 'mesa': numNuevo, 'puesto': puesto}).eq('id', id);

    await SyncService.recalcularAsientos(
      c,
      asientos: [
        if (numAntes != null && puestoAntes != null) (numeroMesa: numAntes, puesto: puestoAntes, catadorId: null),
        (numeroMesa: numNuevo, puesto: puesto, catadorId: id),
      ],
    );
    await registrar(
      'cambio_puesto',
      tabla: 'catadores',
      registroId: '$id',
      motivo: motivo ?? '${yo['nombre']} → mesa $numNuevo puesto $puesto',
    );
    return _avisosMesas([mesaAntes, mesaId]);
  }

  Future<List<String>> quitarDeMesa(int id) async {
    if (!esLocal) {
      final dia = diaId;
      if (dia == null) throw StateError('Elige un día para quitar la asignación');
      final a = await c.from('asignaciones').select().eq('dia_id', dia).eq('catador_id', id).maybeSingle();
      if (a == null) return [];
      final mesaAntes = (a['mesa_id'] as num?)?.toInt();
      await c.from('asignaciones').delete().eq('id', a['id']);
      await c.from('catadores').update({'presente': false}).eq('id', id);
      return _avisosMesasCloud(dia, [mesaAntes]);
    }
    final yo = await _catador(id);
    if (yo == null) return [];
    final mesaAntes = (yo['mesa_id'] as num?)?.toInt();
    final puestoAntes = (yo['puesto'] as num?)?.toInt();
    final nums = await _mapaNumeroMesa();
    final numAntes = mesaAntes == null ? null : nums[mesaAntes];

    await c
        .from('catadores')
        .update({'mesa_id': null, 'mesa': null, 'puesto': null, 'rol': 'catador', 'presente': false})
        .eq('id', id);

    if (numAntes != null && puestoAntes != null) {
      await SyncService.recalcularAsientos(c, asientos: [(numeroMesa: numAntes, puesto: puestoAntes, catadorId: null)]);
    }
    await registrar(
      'catador_ausente',
      tabla: 'catadores',
      registroId: '$id',
      motivo: '${yo['nombre']} quitado de mesa (no ha venido)',
    );
    return _avisosMesas([mesaAntes]);
  }

  Future<List<String>> fijarPresidente(int id, {required bool presidente}) async {
    if (!esLocal) {
      final dia = diaId;
      if (dia == null) throw StateError('Elige un día');
      final a = await c.from('asignaciones').select().eq('dia_id', dia).eq('catador_id', id).maybeSingle();
      if (a == null) throw StateError('Sin asignación ese día');
      final mesaId = (a['mesa_id'] as num).toInt();
      if (presidente) {
        await c
            .from('asignaciones')
            .update({'rol': 'catador'})
            .eq('dia_id', dia)
            .eq('mesa_id', mesaId)
            .eq('rol', 'presidente');
      }
      await c.from('asignaciones').update({'rol': presidente ? 'presidente' : 'catador'}).eq('id', a['id']);
      return _avisosMesasCloud(dia, [mesaId]);
    }
    final yo = await _catador(id);
    if (yo == null) return [];
    final mesaId = (yo['mesa_id'] as num?)?.toInt();
    if (presidente && mesaId != null) {
      await c.from('catadores').update({'rol': 'catador'}).eq('mesa_id', mesaId).eq('rol', 'presidente');
    }
    await c.from('catadores').update({'rol': presidente ? 'presidente' : 'catador'}).eq('id', id);
    return _avisosMesas([mesaId]);
  }

  Future<List<String>> _intercambiarAsignaciones(int a, int b, {String? motivo}) async {
    final dia = diaId;
    if (dia == null) throw StateError('Elige un día');
    final aa = await c.from('asignaciones').select().eq('dia_id', dia).eq('catador_id', a).maybeSingle();
    final bb = await c.from('asignaciones').select().eq('dia_id', dia).eq('catador_id', b).maybeSingle();
    if (aa == null || bb == null) throw StateError('Falta asignación de uno de los catadores');
    final mesaA = (aa['mesa_id'] as num?)?.toInt();
    final mesaB = (bb['mesa_id'] as num?)?.toInt();
    try {
      await c.rpc('intercambiar_asignaciones', params: {'p_a': a, 'p_b': b, 'p_dia': dia, 'p_motivo': motivo});
    } on PostgrestException catch (e) {
      final faltaFn =
          (e.code == 'PGRST202') ||
          e.message.toLowerCase().contains('could not find') ||
          e.message.toLowerCase().contains('intercambiar_asignaciones');
      if (!faltaFn) rethrow;
      // Fallback si la migración aún no está aplicada: liberar A (NULL) antes del swap.
      final puestoA = aa['puesto'];
      final rolA = aa['rol'];
      final puestoB = bb['puesto'];
      final rolB = bb['rol'];
      await c.from('asignaciones').update({'mesa_id': null, 'puesto': null}).eq('id', aa['id']);
      await c.from('asignaciones').update({'mesa_id': mesaA, 'puesto': puestoA, 'rol': rolA}).eq('id', bb['id']);
      await c.from('asignaciones').update({'mesa_id': mesaB, 'puesto': puestoB, 'rol': rolB}).eq('id', aa['id']);
      await registrar('cambio_puesto', tabla: 'asignaciones', registroId: '$a,$b', motivo: motivo);
    }
    return _avisosMesasCloud(dia, [mesaA, mesaB]);
  }

  Future<List<String>> _moverAsignacion(int id, int mesaId, int puesto, {String? motivo}) async {
    final dia = diaId;
    if (dia == null) throw StateError('Elige un día');
    final mia = await c.from('asignaciones').select().eq('dia_id', dia).eq('catador_id', id).maybeSingle();
    final ocup = await c
        .from('asignaciones')
        .select()
        .eq('dia_id', dia)
        .eq('mesa_id', mesaId)
        .eq('puesto', puesto)
        .neq('catador_id', id)
        .maybeSingle();
    if (ocup != null) {
      return _intercambiarAsignaciones(id, (ocup['catador_id'] as num).toInt(), motivo: motivo);
    }
    if (mia == null) {
      await c.from('asignaciones').insert({
        'dia_id': dia,
        'catador_id': id,
        'mesa_id': mesaId,
        'puesto': puesto,
        'rol': puesto == 1 ? 'presidente' : 'catador',
      });
    } else {
      await c.from('asignaciones').update({'mesa_id': mesaId, 'puesto': puesto}).eq('id', mia['id']);
    }
    await registrar('cambio_puesto', tabla: 'asignaciones', registroId: '$id', motivo: motivo);
    return _avisosMesasCloud(dia, [(mia?['mesa_id'] as num?)?.toInt(), mesaId]);
  }

  Future<List<String>> _avisosMesasCloud(int dia, Iterable<int?> mesaIds) async {
    final nums = await _mapaNumeroMesa();
    final avisos = <String>[];
    for (final mid in mesaIds.whereType<int>().toSet()) {
      final filas = await c.from('asignaciones').select().eq('dia_id', dia).eq('mesa_id', mid);
      final cats = [
        for (final r in filas)
          Catador({
            'id': r['catador_id'],
            'nombre': 'P${r['puesto']}',
            'mesa_id': mid,
            'puesto': r['puesto'],
            'rol': r['rol'],
            'presente': true,
          }),
      ];
      avisos.addAll(avisosMesaLocal(cats, nombreMesa: 'Mesa ${nums[mid] ?? mid}'));
    }
    return avisos;
  }

  /// Desvincula la tablet del catador (p. ej. tablet rota) y la deja libre para una reserva.
  Future<void> liberarTablet(int catadorId) async {
    await c.from('dispositivos').update({'catador_id': null}).eq('catador_id', catadorId);
    await c.from('catadores').update({'activo': false}).eq('id', catadorId);
  }

  /// Asigna una tablet libre (reserva) a un catador. Si el catador ya tenía otra, la libera.
  Future<void> asignarTablet(int dispositivoId, int catadorId) async {
    await c.from('dispositivos').update({'catador_id': null}).eq('catador_id', catadorId);
    await c
        .from('dispositivos')
        .update({'catador_id': catadorId, 'ultima_vez': DateTime.now().toUtc().toIso8601String()})
        .eq('id', dispositivoId);
    await c.from('catadores').update({'activo': true}).eq('id', catadorId);
  }

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

  /// Borra todas las notas de la muestra en su tanda y la deja en `pendiente`.
  Future<int> reiniciarMuestra(int tmId) async {
    try {
      return ((await c.rpc('reiniciar_muestra_admin', params: {'p_tm': tmId})) as num?)?.toInt() ?? 0;
    } catch (e) {
      // Si la migración nueva aún no está en el servidor, cae al plan B (RPCs ya existentes).
      final msg = e.toString().toLowerCase();
      if (!msg.contains('could not find') && !msg.contains('pgrst202') && !msg.contains('404')) rethrow;
    }
    final tm = await c.from('tanda_muestras').select('id,tanda_id,muestra_id').eq('id', tmId).maybeSingle();
    if (tm == null) throw StateError('Muestra de tanda no encontrada');
    final tandaId = tm['tanda_id'] as int;
    final muestraId = tm['muestra_id'] as int;
    final notas = await c.from('puntuaciones').select('id').eq('tanda_id', tandaId).eq('muestra_id', muestraId) as List;
    for (final n in notas) {
      final id = n['id'] as int;
      try {
        await c.rpc('borrar_puntuacion_admin', params: {'p_id': id});
      } catch (_) {
        await c.from('puntuaciones').delete().eq('id', id);
      }
    }
    await c.from('tanda_muestras').update({'estado': 'pendiente', 'incidencia_motivo': null}).eq('id', tmId);
    await registrar(
      'reiniciar_muestra',
      tabla: 'tanda_muestras',
      registroId: tmId.toString(),
      motivo: 'Admin reinició muestra (cliente): ${notas.length} notas',
    );
    return notas.length;
  }

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
  Future<void> puntuarManual({
    required int muestraId,
    required int catadorId,
    required int tandaId,
    required double total,
    bool forzar = false,
  }) async {
    if (forzar) {
      await c.rpc(
        'puntuar_manual_admin',
        params: {'p_muestra': muestraId, 'p_catador': catadorId, 'p_tanda': tandaId, 'p_total': total},
      );
      return;
    }
    await c.from('puntuaciones').upsert({
      'muestra_id': muestraId,
      'catador_id': catadorId,
      'tanda_id': tandaId,
      'total': total,
      'scores': {'manual': true, 'total': total},
      'estado': 'enviada',
    }, onConflict: 'catador_id,muestra_id');
  }

  Future<void> borrarPuntuacion(int id, {bool forzar = false}) async {
    if (forzar) {
      await c.rpc('borrar_puntuacion_admin', params: {'p_id': id});
      return;
    }
    await c.from('puntuaciones').delete().eq('id', id);
  }

  // ------------------- medallas -------------------
  Future<List<Resultado>> resultados(int? concursoId) async {
    var q = c.from('v_resultados_gestion').select();
    if (concursoId != null) q = q.eq('concurso_id', concursoId);
    final l = await q;
    return l.map(Resultado.new).toList();
  }

  Future<void> fijarMedalla(int muestraId, String? medalla, double media) =>
      c.rpc('fijar_medalla', params: {'p_muestra': muestraId, 'p_medalla': medalla, 'p_media': media});

  /// Vacía concurso/catadores/notas en este servidor (RPC `demo_borrar_todo`).
  Future<Json> demoBorrarTodo() async {
    final r = await c.rpc('demo_borrar_todo');
    return Map<String, dynamic>.from(r as Map);
  }

  /// Crea el día DEMO en CLOUD (5 mesas, 25 catadores, 6×22 muestras).
  Future<Json> demoCrearDiaCompleto() async {
    final r = await c.rpc('demo_crear_dia_completo');
    return Map<String, dynamic>.from(r as Map);
  }
}
