import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auditoria.dart';
import '../data/models.dart';
import 'validacion_dia.dart';

enum Direccion {
  bajar('Bajar día a LOCAL'),
  subir('Subir notas a CLOUD');

  const Direccion(this.texto);
  final String texto;
}

class ProgresoSync {
  ProgresoSync(this.paso, this.mensaje);
  final String paso;
  final String mensaje;
}

class ResultadoSync {
  final Map<String, int> recuentos = {};
  final List<String> errores = [];
  final List<String> avisos = [];
  final List<String> problemasValidacion = [];
  String? cuadre;
  DateTime? horaFin;

  /// Auditoría informativa (nunca bloquea bajar/subir).
  ResultadoAuditoria? auditoria;
  bool get ok => errores.isEmpty && problemasValidacion.isEmpty;
}

class CambioLocalPuesto {
  CambioLocalPuesto(this.texto);
  final String texto;
}

/// Sincronización Cloud ↔ Local con asignaciones por día.
///
/// BAJAR: valida el día, vacía LOCAL y carga estructura + catadores aplanados.
/// SUBIR: solo puntuaciones y registro_cambios; nunca catadores ni asignaciones.
class SyncService {
  SyncService({required this.cloud, required this.local, required this.prefs});
  final SupabaseClient cloud;
  final SupabaseClient local;
  final SharedPreferences prefs;

  static const _pagina = 1000;
  static const _lote = 300;
  static const kSnapshot = 'sync_snapshot_puestos';

  static String _msg(Object e) => e is PostgrestException ? e.message : '$e';

  Future<List<Json>> _leer(
    SupabaseClient c,
    String tabla, {
    String? eqCol,
    Object? eqVal,
    String? inCol,
    List<int>? inVals,
  }) async {
    if (inCol != null && (inVals == null || inVals.isEmpty)) return [];
    final out = <Json>[];
    if (inCol != null && inVals != null) {
      for (var i = 0; i < inVals.length; i += 200) {
        final trozo = inVals.sublist(i, (i + 200).clamp(0, inVals.length));
        final page = await c.from(tabla).select().inFilter(inCol, trozo).order('id');
        out.addAll(page.map((r) => Map<String, dynamic>.from(r as Map)));
      }
      return out;
    }
    var from = 0;
    while (true) {
      var q = c.from(tabla).select();
      if (eqCol != null && eqVal != null) q = q.eq(eqCol, eqVal);
      final page = await q.order('id').range(from, from + _pagina - 1);
      out.addAll(page.map((r) => Map<String, dynamic>.from(r as Map)));
      if (page.length < _pagina) break;
      from += _pagina;
    }
    return out;
  }

  Future<int> _insertarLotes(SupabaseClient c, String tabla, List<Json> filas) async {
    if (filas.isEmpty) return 0;
    var n = 0;
    for (var i = 0; i < filas.length; i += _lote) {
      final lote = filas.sublist(i, (i + _lote).clamp(0, filas.length));
      await c.from(tabla).upsert(lote);
      n += lote.length;
    }
    return n;
  }

  // ---------------------------------------------------------------------------
  // Comprobaciones previas a la bajada
  // ---------------------------------------------------------------------------

  /// Hay notas en LOCAL que todavía no se han subido con cuadre OK.
  Future<bool> hayPuntuacionesSinSubir() async {
    final notas = await local.from('puntuaciones').select('id').limit(1);
    if (notas.isEmpty) return false;
    final est = await local.from('sync_estado').select('estado, cuadre_ok').eq('id', 1).maybeSingle();
    final estado = est?['estado'] as String? ?? 'vacio';
    if (estado == 'subido' || estado == 'verificado') {
      return est?['cuadre_ok'] != true;
    }
    // cargado / vacio con notas residuales → hay que subir o confirmar en pruebas
    return true;
  }

  /// Diferencias de mesa/puesto/rol respecto al snapshot de la última bajada.
  Future<List<CambioLocalPuesto>> cambiosLocalesDesdeBajada() async {
    final raw = prefs.getString(kSnapshot);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> snap = jsonDecode(raw) as List<dynamic>;
    final antes = {
      for (final e in snap)
        (e as Map)['id'] as int: {
          'mesa_id': e['mesa_id'],
          'puesto': e['puesto'],
          'rol': e['rol'],
          'nombre': e['nombre'],
        },
    };
    final ahora = await _leer(local, 'catadores');
    final out = <CambioLocalPuesto>[];
    for (final c in ahora) {
      final id = (c['id'] as num).toInt();
      final prev = antes[id];
      if (prev == null) {
        out.add(CambioLocalPuesto('${c['nombre']}: nuevo en LOCAL'));
        continue;
      }
      final cambios = <String>[];
      if (prev['mesa_id'] != c['mesa_id']) {
        cambios.add('mesa ${prev['mesa_id'] ?? '–'} → ${c['mesa_id'] ?? '–'}');
      }
      if (prev['puesto'] != c['puesto']) {
        cambios.add('puesto ${prev['puesto'] ?? '–'} → ${c['puesto'] ?? '–'}');
      }
      if (prev['rol'] != c['rol']) {
        cambios.add('rol ${prev['rol']} → ${c['rol']}');
      }
      if (cambios.isNotEmpty) {
        out.add(CambioLocalPuesto('${c['nombre']}: ${cambios.join(', ')}'));
      }
    }
    for (final id in antes.keys) {
      if (!ahora.any((c) => (c['id'] as num).toInt() == id)) {
        out.add(CambioLocalPuesto('${antes[id]!['nombre']}: ya no está en LOCAL'));
      }
    }
    return out;
  }

  Future<List<String>> validarDiaCloud(int diaId) async {
    final dia = await cloud.from('dias_concurso').select().eq('id', diaId).maybeSingle();
    if (dia == null) return ['El día $diaId no existe en CLOUD'];
    final concursoId = (dia['concurso_id'] as num).toInt();
    final concurso = await cloud.from('concursos').select().eq('id', concursoId).maybeSingle();
    final porMesa = (concurso?['catadores_por_mesa'] as num?)?.toInt() ?? 5;

    final mesas = (await _leer(cloud, 'mesas', eqCol: 'concurso_id', eqVal: concursoId)).map(Mesa.new).toList();
    final asignaciones = await _leer(cloud, 'asignaciones', eqCol: 'dia_id', eqVal: diaId);
    final tandas = (await _leer(cloud, 'tandas', eqCol: 'dia_id', eqVal: diaId)).map(Tanda.new).toList();
    final tandaIds = tandas.map((t) => t.id).toList();
    final tms = (await _leer(
      cloud,
      'tanda_muestras',
      inCol: 'tanda_id',
      inVals: tandaIds,
    )).map(TandaMuestra.new).toList();
    final muestraIds = tms.map((t) => t.muestraId).toSet().toList();
    final muestras = (await _leer(cloud, 'muestras', inCol: 'id', inVals: muestraIds)).map(Muestra.new).toList();
    final categorias = (await _leer(cloud, 'categorias')).map(Categoria.new).toList();

    return validarDiaParaBajar(
      diaId: diaId,
      mesas: mesas,
      asignaciones: asignaciones,
      tandas: tandas,
      tandaMuestras: tms,
      muestras: muestras,
      categorias: categorias,
      catadoresPorMesa: porMesa,
    );
  }

  // ---------------------------------------------------------------------------
  // BAJAR
  // ---------------------------------------------------------------------------

  Stream<ProgresoSync> bajarDia(int diaId, {required ResultadoSync res}) async* {
    yield ProgresoSync('validar', 'Validando día en CLOUD…');
    final problemas = await validarDiaCloud(diaId);
    if (problemas.isNotEmpty) {
      res.problemasValidacion.addAll(problemas);
      yield ProgresoSync('validar', 'Validación fallida: ${problemas.length} problema(s)');
      return;
    }
    yield ProgresoSync('validar', 'Día OK');

    yield ProgresoSync('vaciar', 'Vaciando LOCAL…');
    try {
      await local.rpc('sync_vaciar_local');
    } catch (e) {
      res.errores.add('Vaciar LOCAL: ${_msg(e)}');
      return;
    }

    try {
      yield* _cargarDiaEnLocal(diaId, res);
    } catch (e) {
      res.errores.add('Carga: ${_msg(e)}');
      return;
    }

    try {
      await local.rpc('sync_preparar_local');
    } catch (e) {
      res.avisos.add('Secuencias LOCAL: ${_msg(e)}');
    }

    final ahora = DateTime.now().toUtc();
    try {
      await local
          .from('sync_estado')
          .update({
            'dia_id': diaId,
            'estado': 'cargado',
            'cuadre_ok': false,
            'ultima_bajada': ahora.toIso8601String(),
            'actualizado_en': ahora.toIso8601String(),
            'snapshot_puestos': jsonDecode(prefs.getString(kSnapshot) ?? '[]'),
          })
          .eq('id', 1);
    } catch (e) {
      res.avisos.add('sync_estado: ${_msg(e)}');
    }

    yield* _auditarLocal(res, motivo: 'tras bajar');

    res.horaFin = DateTime.now();
    yield ProgresoSync('fin', 'Bajada terminada a las ${_hora(res.horaFin!)}');
  }

  /// Auditoría SQL del LOCAL: informa, nunca bloquea ni lanza.
  Stream<ProgresoSync> _auditarLocal(ResultadoSync res, {required String motivo}) async* {
    yield ProgresoSync('auditoria', 'Auditoría $motivo…');
    try {
      final cuando = DateTime.now();
      final hallazgos = await comprobarSqlLocal(local);
      res.auditoria = ResultadoAuditoria(cuando: cuando, hallazgos: hallazgos);
      if (hallazgos.isEmpty) {
        yield ProgresoSync('auditoria', 'Todo correcto (${formatearHoraAuditoria(cuando)})');
      } else {
        final nMirar = hallazgos.where((h) => h.hayQueMirarlo).length;
        final nCuenta = hallazgos.length - nMirar;
        yield ProgresoSync('auditoria', 'Auditoría: $nMirar a mirar · $nCuenta a tener en cuenta');
      }
    } catch (e) {
      res.avisos.add('Auditoría (no bloquea): ${_msg(e)}');
      yield ProgresoSync('auditoria', 'Auditoría omitida (no bloquea)');
    }
  }

  Stream<ProgresoSync> _cargarDiaEnLocal(int diaId, ResultadoSync res) async* {
    final dia = await cloud.from('dias_concurso').select().eq('id', diaId).single();
    final concursoId = (dia['concurso_id'] as num).toInt();

    yield ProgresoSync('concursos', 'Leyendo concurso…');
    final concursos = await _leer(cloud, 'concursos', eqCol: 'id', eqVal: concursoId);
    res.recuentos['concursos'] = await _insertarLotes(local, 'concursos', concursos);
    yield ProgresoSync('concursos', '${res.recuentos['concursos']} filas');

    yield ProgresoSync('categorias', 'Leyendo categorías…');
    final categorias = await _leer(cloud, 'categorias');
    res.recuentos['categorias'] = await _insertarLotes(local, 'categorias', categorias);
    yield ProgresoSync('categorias', '${res.recuentos['categorias']} filas');

    yield ProgresoSync('mesas', 'Leyendo mesas…');
    final mesas = await _leer(cloud, 'mesas', eqCol: 'concurso_id', eqVal: concursoId);
    res.recuentos['mesas'] = await _insertarLotes(local, 'mesas', mesas);
    yield ProgresoSync('mesas', '${res.recuentos['mesas']} filas');
    final mesaNum = {for (final m in mesas) (m['id'] as num).toInt(): (m['numero'] as num).toInt()};

    yield ProgresoSync('tandas', 'Leyendo tandas del día…');
    final tandas = await _leer(cloud, 'tandas', eqCol: 'dia_id', eqVal: diaId);
    res.recuentos['tandas'] = await _insertarLotes(local, 'tandas', tandas);
    yield ProgresoSync('tandas', '${res.recuentos['tandas']} filas');
    final tandaIds = tandas.map((t) => (t['id'] as num).toInt()).toList();

    yield ProgresoSync('tanda_muestras', 'Leyendo muestras de tanda…');
    final tms = await _leer(cloud, 'tanda_muestras', inCol: 'tanda_id', inVals: tandaIds);
    res.recuentos['tanda_muestras'] = await _insertarLotes(local, 'tanda_muestras', tms);
    yield ProgresoSync('tanda_muestras', '${res.recuentos['tanda_muestras']} filas');
    final muestraIds = tms.map((t) => (t['muestra_id'] as num).toInt()).toSet().toList();

    yield ProgresoSync('muestras', 'Leyendo muestras…');
    final muestras = await _leer(cloud, 'muestras', inCol: 'id', inVals: muestraIds);
    res.recuentos['muestras'] = await _insertarLotes(local, 'muestras', muestras);
    yield ProgresoSync('muestras', '${res.recuentos['muestras']} filas');

    yield ProgresoSync('asignaciones', 'Aplanando catadores del día…');
    final asigs = await _leer(cloud, 'asignaciones', eqCol: 'dia_id', eqVal: diaId);
    final catIds = asigs.map((a) => (a['catador_id'] as num).toInt()).toSet().toList();
    final personas = await _leer(cloud, 'catadores', inCol: 'id', inVals: catIds);
    final porId = {for (final p in personas) (p['id'] as num).toInt(): p};

    final aplanados = <Json>[];
    final snapshot = <Json>[];
    for (final a in asigs) {
      final cid = (a['catador_id'] as num).toInt();
      final mesaId = (a['mesa_id'] as num).toInt();
      final puesto = (a['puesto'] as num).toInt();
      final rol = (a['rol'] as String?) ?? 'catador';
      final base = Map<String, dynamic>.from(porId[cid] ?? {'id': cid, 'nombre': 'Catador $cid'});
      base['mesa_id'] = mesaId;
      base['mesa'] = mesaNum[mesaId];
      base['puesto'] = puesto;
      base['rol'] = rol;
      base['activo'] = false;
      base['presente'] = base['presente'] ?? true;
      aplanados.add(base);
      snapshot.add({'id': cid, 'nombre': base['nombre'], 'mesa_id': mesaId, 'puesto': puesto, 'rol': rol});
    }
    res.recuentos['catadores'] = await _insertarLotes(local, 'catadores', aplanados);
    await prefs.setString(kSnapshot, jsonEncode(snapshot));
    yield ProgresoSync('catadores', '${res.recuentos['catadores']} aplanados (sin bajar asignaciones)');

    yield ProgresoSync('dispositivos', 'Recalculando tablets…');
    final nDisp = await recalcularDispositivos(local, aplanados, mesaNum);
    res.recuentos['dispositivos'] = nDisp;
    yield ProgresoSync('dispositivos', '$nDisp asientos vinculados');
  }

  /// Vincula cada asiento a su tablet: nº = (mesa − 1) × 5 + puesto.
  /// Todo el trabajo masivo va por RPC SQL (PostgREST no admite UPDATE sin filtro).
  static Future<int> recalcularDispositivos(SupabaseClient c, List<Json> catadores, Map<int, int> mesaIdANumero) async {
    final vinculos = <Json>[];
    for (final cat in catadores) {
      final mesaId = (cat['mesa_id'] as num?)?.toInt();
      final puesto = (cat['puesto'] as num?)?.toInt();
      final catId = (cat['id'] as num).toInt();
      if (mesaId == null || puesto == null) continue;
      final numMesa = mesaIdANumero[mesaId] ?? (cat['mesa'] as num?)?.toInt();
      if (numMesa == null) continue;
      vinculos.add({'tablet': numeroTablet(numeroMesa: numMesa, puesto: puesto), 'catador_id': catId});
    }
    final r = await c.rpc('sync_recalcular_dispositivos', params: {'p_vinculos': vinculos});
    return (r as num?)?.toInt() ?? vinculos.length;
  }

  /// Recalcula tablets solo de los asientos indicados (cambios de última hora).
  static Future<void> recalcularAsientos(
    SupabaseClient c, {
    required List<({int? numeroMesa, int? puesto, int? catadorId})> asientos,
  }) async {
    final payload = <Json>[
      for (final a in asientos)
        if (a.numeroMesa != null && a.puesto != null)
          {'tablet': numeroTablet(numeroMesa: a.numeroMesa!, puesto: a.puesto!), 'catador_id': a.catadorId},
    ];
    if (payload.isEmpty) return;
    await c.rpc('sync_aplicar_asientos', params: {'p_asientos': payload});
  }

  // ---------------------------------------------------------------------------
  // SUBIR
  // ---------------------------------------------------------------------------

  Stream<ProgresoSync> subirDia({required ResultadoSync res}) async* {
    final est = await local.from('sync_estado').select('dia_id').eq('id', 1).maybeSingle();
    final diaId = (est?['dia_id'] as num?)?.toInt();
    if (diaId == null) {
      res.errores.add('LOCAL no tiene día bajado (sync_estado.dia_id vacío)');
      return;
    }

    // Informativa: nunca impide subir.
    yield* _auditarLocal(res, motivo: 'antes de subir');

    yield ProgresoSync('puntuaciones', 'Leyendo notas LOCAL…');
    final notas = await _leer(local, 'puntuaciones');
    // Solo las de tandas del día (por si quedara basura)
    final tandasDia = await _leer(local, 'tandas'); // en local solo hay del día
    final tandaIds = tandasDia.map((t) => (t['id'] as num).toInt()).toSet();
    final filas = [
      for (final p in notas)
        if (tandaIds.contains((p['tanda_id'] as num?)?.toInt()))
          {
            'catador_id': p['catador_id'],
            'muestra_id': p['muestra_id'],
            'tanda_id': p['tanda_id'],
            'scores': p['scores'],
            'total': p['total'],
            'estado': p['estado'],
            'updated_at': p['updated_at'],
          },
    ];

    yield ProgresoSync('puntuaciones', 'Subiendo ${filas.length} notas…');
    var nNotas = 0;
    for (var i = 0; i < filas.length; i += _lote) {
      final lote = filas.sublist(i, (i + _lote).clamp(0, filas.length));
      try {
        final r = await cloud.rpc('sync_upsert_puntuaciones', params: {'p_filas': lote});
        nNotas += (r as num?)?.toInt() ?? lote.length;
      } catch (e) {
        // Fallback: upsert directo
        try {
          await cloud.from('puntuaciones').upsert(lote, onConflict: 'catador_id,muestra_id');
          nNotas += lote.length;
        } catch (e2) {
          res.errores.add('puntuaciones: ${_msg(e2)}');
        }
      }
    }
    res.recuentos['puntuaciones'] = nNotas;
    yield ProgresoSync('puntuaciones', '$nNotas notas en CLOUD');

    yield ProgresoSync('registro_cambios', 'Subiendo registro…');
    final cambios = await _leer(local, 'registro_cambios');
    final delDia = [
      for (final c in cambios)
        if ((c['dia_id'] as num?)?.toInt() == diaId || c['dia_id'] == null) c,
    ];
    var nCambios = 0;
    for (var i = 0; i < delDia.length; i += _lote) {
      final lote = delDia.sublist(i, (i + _lote).clamp(0, delDia.length));
      try {
        // No duplicar por id
        await cloud.from('registro_cambios').upsert(lote);
        nCambios += lote.length;
      } catch (e) {
        for (final f in lote) {
          try {
            await cloud.from('registro_cambios').insert(f);
            nCambios++;
          } catch (_) {
            // ya existe
          }
        }
      }
    }
    res.recuentos['registro_cambios'] = nCambios;
    yield ProgresoSync('registro_cambios', '$nCambios cambios');

    yield ProgresoSync('cuadre', 'Cuadrando…');
    res.cuadre = await cuadrar(diaId);
    yield ProgresoSync('cuadre', res.cuadre!);

    final ahora = DateTime.now().toUtc();
    final cuadra = res.cuadre == 'CUADRA';
    try {
      await local
          .from('sync_estado')
          .update({
            'estado': cuadra ? 'verificado' : 'subido',
            'cuadre_ok': cuadra,
            'ultima_subida': ahora.toIso8601String(),
            'actualizado_en': ahora.toIso8601String(),
          })
          .eq('id', 1);
    } catch (e) {
      res.avisos.add('sync_estado: ${_msg(e)}');
    }

    res.horaFin = DateTime.now();
    yield ProgresoSync('fin', 'Subida terminada a las ${_hora(res.horaFin!)}');
  }

  /// Compara muestras y notas del día entre LOCAL y CLOUD.
  Future<String> cuadrar(int diaId) async {
    final faltas = <String>[];

    final tandasL = await _leer(local, 'tandas');
    final tandaIdsL = tandasL.map((t) => (t['id'] as num).toInt()).toList();
    final tmsL = await _leer(local, 'tanda_muestras', inCol: 'tanda_id', inVals: tandaIdsL);
    final muestrasL = tmsL.map((t) => (t['muestra_id'] as num).toInt()).toSet();
    final notasL = await _leer(local, 'puntuaciones');
    final notasLDia = notasL.where((p) => tandaIdsL.contains((p['tanda_id'] as num?)?.toInt())).toList();

    final tandasC = await _leer(cloud, 'tandas', eqCol: 'dia_id', eqVal: diaId);
    final tandaIdsC = tandasC.map((t) => (t['id'] as num).toInt()).toList();
    final tmsC = await _leer(cloud, 'tanda_muestras', inCol: 'tanda_id', inVals: tandaIdsC);
    final muestrasC = tmsC.map((t) => (t['muestra_id'] as num).toInt()).toSet();
    final notasC = await _leer(cloud, 'puntuaciones', inCol: 'tanda_id', inVals: tandaIdsC);

    if (muestrasL.length != muestrasC.length) {
      faltas.add('Muestras en tandas: LOCAL ${muestrasL.length} ≠ CLOUD ${muestrasC.length}');
    }
    final soloL = muestrasL.difference(muestrasC);
    final soloC = muestrasC.difference(muestrasL);
    if (soloL.isNotEmpty) faltas.add('Muestras solo en LOCAL: ${soloL.take(10).join(', ')}');
    if (soloC.isNotEmpty) faltas.add('Muestras solo en CLOUD: ${soloC.take(10).join(', ')}');

    if (notasLDia.length != notasC.length) {
      faltas.add('Notas: LOCAL ${notasLDia.length} ≠ CLOUD ${notasC.length}');
    }
    String clave(Json p) => '${p['muestra_id']}|${p['catador_id']}';
    final setL = notasLDia.map(clave).toSet();
    final setC = notasC.map(clave).toSet();
    final faltanCloud = setL.difference(setC);
    final faltanLocal = setC.difference(setL);
    if (faltanCloud.isNotEmpty) {
      faltas.add('Notas en LOCAL que faltan en CLOUD: ${faltanCloud.take(15).join(', ')}');
    }
    if (faltanLocal.isNotEmpty) {
      faltas.add('Notas en CLOUD que no están en LOCAL: ${faltanLocal.take(15).join(', ')}');
    }

    return faltas.isEmpty ? 'CUADRA' : faltas.join('\n');
  }

  Future<void> vaciarLocalTrasCuadre() async {
    final est = await local.from('sync_estado').select('cuadre_ok').eq('id', 1).maybeSingle();
    if (est?['cuadre_ok'] != true) {
      throw StateError('No se puede vaciar: el cuadre no ha dicho CUADRA');
    }
    await local.rpc('sync_vaciar_local');
    await prefs.remove(kSnapshot);
  }

  Future<Json> generarAsignacionesPrueba(int diaId) async {
    final r = await cloud.rpc('generar_asignaciones_prueba', params: {'p_dia_id': diaId});
    return Map<String, dynamic>.from(r as Map);
  }

  static String _hora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
