import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'backend.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError());

final backendsProvider = Provider<Backends>((ref) => Backends(ref.watch(prefsProvider)));

/// Entorno activo (CLOUD / LOCAL) con el que trabaja la app.
class EntornoNotifier extends Notifier<Entorno> {
  @override
  Entorno build() => ref.watch(backendsProvider).activo;

  Future<void> cambiar(Entorno e) async {
    await ref.read(backendsProvider).setActivo(e);
    state = e;
  }
}

final entornoProvider = NotifierProvider<EntornoNotifier, Entorno>(EntornoNotifier.new);

/// Se incrementa al cambiar la configuración de un entorno para recrear clientes.
class Revision extends Notifier<int> {
  @override
  int build() => 0;
  void subir() => state++;
}

final revisionProvider = NotifierProvider<Revision, int>(Revision.new);

final clienteProvider = FutureProvider<SupabaseClient?>((ref) {
  ref.watch(revisionProvider);
  return ref.watch(backendsProvider).cliente(ref.watch(entornoProvider));
});

final sesionProvider = StreamProvider<Session?>((ref) async* {
  final c = await ref.watch(clienteProvider.future);
  if (c == null) {
    yield null;
    return;
  }
  yield c.auth.currentSession;
  yield* c.auth.onAuthStateChange.map((s) => s.session);
});

final usuarioIdProvider = Provider<String?>((ref) => ref.watch(sesionProvider.select((s) => s.value?.user.id)));

final repoProvider = Provider<Repo?>((ref) {
  final c = ref.watch(clienteProvider).value;
  if (c == null) return null;
  final local = ref.watch(entornoProvider) == Entorno.local;
  // diaId solo para CLOUD (asignaciones). En LOCAL los puestos van en catadores.
  final dia = local ? null : ref.watch(diaIdProvider);
  return Repo(c, esLocal: local, diaId: dia);
});

// ---------------- Selección persistente (por entorno) ----------------
class SelInt extends Notifier<int?> {
  SelInt(this.clave);
  final String clave;

  @override
  int? build() {
    final e = ref.watch(entornoProvider);
    return ref.read(prefsProvider).getInt('${clave}_${e.name}');
  }

  void set(int? v) {
    final k = '${clave}_${ref.read(entornoProvider).name}';
    final p = ref.read(prefsProvider);
    v == null ? p.remove(k) : p.setInt(k, v);
    state = v;
  }
}

final concursoGuardadoProvider = NotifierProvider<SelInt, int?>(() => SelInt('concurso'));
final diaGuardadoProvider = NotifierProvider<SelInt, int?>(() => SelInt('dia'));

/// Tablas que la app escucha en realtime (y muestra en el panel de diagnóstico).
const tablasApp = [
  'concursos',
  'categorias',
  'dias_concurso',
  'mesas',
  'catadores',
  'asignaciones',
  'muestras',
  'tandas',
  'tanda_muestras',
  'puntuaciones',
  'medallas',
  'dispositivos',
  'registro_cambios',
  'sync_estado',
];

// ---------------- Tablas en tiempo real ----------------
/// Tablas del directo/puestos/notas. El resto solo Realtime + refresco a demanda.
const tablasCalientes = {'puntuaciones', 'tanda_muestras', 'tandas', 'dispositivos', 'catadores', 'asignaciones'};

/// Contador global: al subir, cada [filasProvider] hace un REST sin tumbar el socket.
class PedidoRefresco extends Notifier<({int n, Set<String>? tablas})> {
  @override
  ({int n, Set<String>? tablas}) build() => (n: 0, tablas: null);

  void pedir({Iterable<String>? tablas}) => state = (n: state.n + 1, tablas: tablas?.toSet());
}

final pedidoRefrescoProvider = NotifierProvider<PedidoRefresco, ({int n, Set<String>? tablas})>(PedidoRefresco.new);

/// Carga REST primero. Realtime al vuelo. Poll REST solo en tablas calientes y solo
/// si el canal lleva ≥15 s sin evento (si Realtime va bien, no hay tráfico extra).
final filasProvider = StreamProvider.family<List<Json>, String>((ref, tabla) async* {
  final c = await ref.watch(clienteProvider.future);
  if (c == null || ref.watch(usuarioIdProvider) == null) {
    yield const [];
    return;
  }

  Future<List<Json>> cargarRest() async {
    final List<dynamic> rows = tabla == 'registro_cambios'
        ? await c.from(tabla).select().order('creado_en').limit(300)
        : await c.from(tabla).select().order('id', ascending: true);
    return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
  }

  List<Json> actual;
  try {
    actual = await cargarRest();
  } catch (e, st) {
    // Solo el fallo REST inicial es fatal para la UI.
    yield* Stream.error(e, st);
    return;
  }
  yield actual;

  final ctrl = StreamController<List<Json>>();
  StreamSubscription<List<Map<String, dynamic>>>? sub;
  var reabrirRt = false;
  var refrescando = false;
  DateTime? ultimoEventoRt;
  final esCaliente = tablasCalientes.contains(tabla);

  void emitir(List<Json> rows) {
    if (!ctrl.isClosed) ctrl.add(rows);
  }

  Future<void> restSilencioso() async {
    if (refrescando) return;
    refrescando = true;
    try {
      actual = await cargarRest();
      emitir(actual);
    } catch (_) {
    } finally {
      refrescando = false;
    }
  }

  void suscribirRt() {
    sub?.cancel();
    final crudo = tabla == 'registro_cambios'
        ? c.from(tabla).stream(primaryKey: ['id']).order('creado_en').limit(300)
        : c.from(tabla).stream(primaryKey: ['id']).order('id', ascending: true);
    sub = crudo.listen(
      (rows) {
        ultimoEventoRt = DateTime.now();
        actual = [for (final r in rows) Map<String, dynamic>.from(r as Map)];
        emitir(actual);
      },
      onError: (_) {
        reabrirRt = true;
      },
      onDone: () {
        reabrirRt = true;
      },
      cancelOnError: false,
    );
  }

  suscribirRt();

  // Solo tablas calientes: red de seguridad si Realtime se queda mudo.
  // Tablas frías: Realtime + botón Actualizar + refresco tras escritura.
  Timer? timer;
  if (esCaliente) {
    timer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final silencio =
          ultimoEventoRt == null || DateTime.now().difference(ultimoEventoRt!) >= const Duration(seconds: 15);
      if (silencio || reabrirRt) await restSilencioso();
      if (reabrirRt) {
        reabrirRt = false;
        suscribirRt();
      }
    });
  }

  ref.listen(pedidoRefrescoProvider, (_, next) {
    final filtro = next.tablas;
    if (filtro == null || filtro.contains(tabla)) unawaited(restSilencioso());
  });

  ref.onDispose(() {
    timer?.cancel();
    sub?.cancel();
    unawaited(ctrl.close());
  });

  await for (final rows in ctrl.stream) {
    yield rows;
  }
});

/// Fuerza una recarga REST de las tablas indicadas (o las calientes del directo).
void refrescarDatos(WidgetRef ref, {Iterable<String>? tablas}) {
  ref.read(pedidoRefrescoProvider.notifier).pedir(tablas: tablas ?? tablasCalientes);
}

/// Tras mover puestos / roles / notas: tablas que la UI de mesa necesita al instante.
const tablasPuestos = ['asignaciones', 'catadores', 'dispositivos'];
const tablasNotas = ['puntuaciones', 'tanda_muestras', 'tandas'];

List<T> _lista<T>(Ref ref, String tabla, T Function(Json) f, [int Function(T, T)? cmp]) {
  final async = ref.watch(filasProvider(tabla));
  // Preferir el último valor aunque el AsyncValue diga error (Realtime 401, etc.).
  final l = (async.value ?? const []).map(f).toList();
  if (cmp != null) l.sort(cmp);
  return l;
}

/// Errores que bloquean la UI: solo si la tabla no tiene ningún dato cargado.
final erroresTablasProvider = Provider<Map<String, String>>((ref) {
  final m = <String, String>{};
  for (final t in tablasApp) {
    final a = ref.watch(filasProvider(t));
    if (a.hasError && !a.hasValue) m[t] = a.error.toString();
  }
  return m;
});

/// Avisos no bloqueantes (p. ej. Realtime 401 con datos REST ya cargados).
final avisosTablasProvider = Provider<Map<String, String>>((ref) {
  final m = <String, String>{};
  for (final t in tablasApp) {
    final a = ref.watch(filasProvider(t));
    if (a.hasError && a.hasValue) m[t] = a.error.toString();
  }
  return m;
});

/// Filas recibidas por tabla (null = aún cargando / sin valor).
final conteoTablasProvider = Provider<Map<String, String>>((ref) {
  final m = <String, String>{};
  for (final t in tablasApp) {
    final a = ref.watch(filasProvider(t));
    if (a.isLoading && !a.hasValue) {
      m[t] = '…';
    } else if (a.hasError && !a.hasValue) {
      m[t] = 'ERR';
    } else {
      m[t] = '${a.value?.length ?? 0}';
    }
  }
  return m;
});

/// Preferencia local que fuerza mostrar/ocultar el panel de diagnóstico.
class VerDiagnostico extends Notifier<bool?> {
  @override
  bool? build() => ref.read(prefsProvider).getBool('ver_diagnostico');

  Future<void> set(bool v) async {
    await ref.read(prefsProvider).setBool('ver_diagnostico', v);
    state = v;
  }
}

final verDiagnosticoProvider = NotifierProvider<VerDiagnostico, bool?>(VerDiagnostico.new);

/// Modo pruebas: panel de diagnóstico. Preferencia local o sync_estado.modo_pruebas.
final modoPruebasProvider = Provider<bool>((ref) {
  final forzado = ref.watch(verDiagnosticoProvider);
  if (forzado != null) return forzado;
  final l = ref.watch(filasProvider('sync_estado')).value ?? const [];
  if (l.isEmpty) return true; // sin fila aún: útil al montar el LOCAL
  return l.first['modo_pruebas'] == true;
});

final cargandoProvider = Provider<bool>((ref) {
  for (final t in const ['mesas', 'catadores', 'muestras', 'tandas', 'tanda_muestras']) {
    if (ref.watch(filasProvider(t)).isLoading) return true;
  }
  return false;
});

final concursosProvider = Provider<List<Concurso>>((ref) => _lista(ref, 'concursos', Concurso.new));
final concursosCargadosProvider = Provider<bool>((ref) => ref.watch(filasProvider('concursos')).hasValue);

/// Concurso seleccionado; si solo hay uno (o uno activo) se elige solo.
final concursoIdProvider = Provider<int?>((ref) {
  final guardado = ref.watch(concursoGuardadoProvider);
  final l = ref.watch(concursosProvider);
  if (l.any((c) => c.id == guardado)) return guardado;
  final activos = l.where((c) => c.activo).toList();
  if (activos.length == 1) return activos.first.id;
  if (l.length == 1) return l.first.id;
  return null;
});

final concursoProvider = Provider<Concurso?>((ref) {
  final id = ref.watch(concursoIdProvider);
  return ref.watch(concursosProvider).where((c) => c.id == id).firstOrNull;
});

bool _delConcurso(Ref ref, int? concursoId) {
  final id = ref.watch(concursoIdProvider);
  return concursoId == null || id == null || concursoId == id;
}

final categoriasProvider = Provider<List<Categoria>>((ref) => _lista(ref, 'categorias', Categoria.new));
final categoriaPorIdProvider = Provider<Map<int, Categoria>>(
  (ref) => {for (final c in ref.watch(categoriasProvider)) c.id: c},
);

final diasProvider = Provider<List<Dia>>(
  (ref) => _lista(
    ref,
    'dias_concurso',
    Dia.new,
    (a, b) => a.fecha.compareTo(b.fecha),
  ).where((d) => _delConcurso(ref, d.concursoId)).toList(),
);

/// Día de trabajo: el elegido, o el de hoy, o el primero. -1 = todos los días.
/// true si se trabaja contra el servidor LOCAL de la sede.
final esLocalProvider = Provider<bool>((ref) => ref.watch(entornoProvider) == Entorno.local);

/// En CLOUD solo se editan puestos en modo pruebas (App 1 es la dueña de asignaciones).
final puedeEditarPuestosProvider = Provider<bool>((ref) {
  if (ref.watch(esLocalProvider)) return true;
  return ref.watch(modoPruebasProvider);
});

/// En LOCAL: día bajado en la última sincronización (sync_estado.dia_id).
final diaLocalProvider = Provider<int?>((ref) {
  final l = ref.watch(filasProvider('sync_estado')).value ?? const [];
  final v = l.isEmpty ? null : l.first['dia_id'];
  return v == null ? null : (v as num).toInt();
});

final diaIdProvider = Provider<int?>((ref) {
  // LOCAL: solo existe el día de cata sincronizado.
  if (ref.watch(esLocalProvider)) return ref.watch(diaLocalProvider);
  final dias = ref.watch(diasProvider);
  if (dias.isEmpty) return null;
  final guardado = ref.watch(diaGuardadoProvider);
  if (guardado == -1) return null;
  if (dias.any((d) => d.id == guardado)) return guardado;
  final hoy = DateTime.now().toIso8601String().substring(0, 10);
  return dias.where((d) => d.fecha == hoy).firstOrNull?.id ?? dias.first.id;
});

final mesasProvider = Provider<List<Mesa>>(
  (ref) => _lista(
    ref,
    'mesas',
    Mesa.new,
    (a, b) => a.numero.compareTo(b.numero),
  ).where((m) => _delConcurso(ref, m.concursoId)).toList(),
);

final asignacionesProvider = Provider<List<Asignacion>>(
  (ref) => _lista(ref, 'asignaciones', Asignacion.new, (a, b) => a.id.compareTo(b.id)),
);

/// Catadores con mesa/puesto/rol efectivos del día.
/// LOCAL: ya vienen aplanados en la tabla. CLOUD: se cruzan con asignaciones del día
/// (las columnas mesa/puesto/rol de catadores en Cloud se ignoran).
final catadoresProvider = Provider<List<Catador>>((ref) {
  final personas = _lista(
    ref,
    'catadores',
    Catador.new,
    (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
  );
  if (ref.watch(esLocalProvider)) return personas;

  final dia = ref.watch(diaIdProvider);
  if (dia == null) {
    // Sin día: solo persona (sin mesa)
    return [
      for (final c in personas) Catador({...c.r, 'mesa_id': null, 'mesa': null, 'puesto': null, 'rol': 'catador'}),
    ];
  }
  final asigs = {for (final a in ref.watch(asignacionesProvider).where((a) => a.diaId == dia)) a.catadorId: a};
  final mesas = ref.watch(mesaPorIdProvider);
  return [
    for (final c in personas)
      if (asigs[c.id] != null)
        Catador({
          ...c.r,
          'mesa_id': asigs[c.id]!.mesaId,
          'mesa': mesas[asigs[c.id]!.mesaId]?.numero,
          'puesto': asigs[c.id]!.puesto,
          'rol': asigs[c.id]!.rol,
        })
      else
        Catador({...c.r, 'mesa_id': null, 'mesa': null, 'puesto': null, 'rol': 'catador'}),
  ];
});

final muestrasProvider = Provider<List<Muestra>>((ref) {
  final l = _lista(
    ref,
    'muestras',
    Muestra.new,
    (a, b) => a.codigo.compareTo(b.codigo),
  ).where((m) => _delConcurso(ref, m.concursoId));
  // LOCAL: solo las muestras del día de cata.
  final dia = ref.watch(diaIdProvider);
  if (!ref.watch(esLocalProvider) || dia == null) return l.toList();
  final tandasDia = ref.watch(tandasProvider).map((t) => t.id).toSet();
  final delDia = {
    for (final tm in ref.watch(tandaMuestrasProvider))
      if (tandasDia.contains(tm.tandaId)) tm.muestraId,
  };
  return l.where((m) => delDia.contains(m.id)).toList();
});

/// Todas las tandas (de cualquier día), por orden de trabajo.
final todasTandasProvider = Provider<List<Tanda>>(
  (ref) => _lista(ref, 'tandas', Tanda.new, (a, b) {
    final o = a.orden.compareTo(b.orden);
    return o != 0 ? o : a.numero.compareTo(b.numero);
  }),
);

/// Tandas del día de trabajo seleccionado.
final tandasProvider = Provider<List<Tanda>>((ref) {
  final dia = ref.watch(diaIdProvider);
  final l = ref.watch(todasTandasProvider);
  return dia == null ? l : l.where((t) => t.diaId == dia || t.diaId == null).toList();
});

final tandaMuestrasProvider = Provider<List<TandaMuestra>>(
  (ref) => _lista(ref, 'tanda_muestras', TandaMuestra.new, (a, b) => a.orden.compareTo(b.orden)),
);

final puntuacionesProvider = Provider<List<Puntuacion>>((ref) => _lista(ref, 'puntuaciones', Puntuacion.new));

final cambiosProvider = Provider<List<Cambio>>(
  (ref) =>
      _lista(ref, 'registro_cambios', Cambio.new, (a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0))),
);

// ---------- Índices derivados (memoizados por Riverpod) ----------
final mesaPorIdProvider = Provider<Map<int, Mesa>>((ref) => {for (final m in ref.watch(mesasProvider)) m.id: m});
final muestraPorIdProvider = Provider<Map<int, Muestra>>(
  (ref) => {for (final m in ref.watch(muestrasProvider)) m.id: m},
);
final catadorPorIdProvider = Provider<Map<int, Catador>>(
  (ref) => {for (final c in ref.watch(catadoresProvider)) c.id: c},
);
final tandaPorIdProvider = Provider<Map<int, Tanda>>(
  (ref) => {for (final t in ref.watch(todasTandasProvider)) t.id: t},
);

final tandasDeMesaProvider = Provider.family<List<Tanda>, int?>(
  (ref, mesaId) => ref.watch(tandasProvider).where((t) => t.mesaId == mesaId).toList(),
);

final muestrasDeTandaProvider = Provider.family<List<TandaMuestra>, int>(
  (ref, tandaId) => ref.watch(tandaMuestrasProvider).where((t) => t.tandaId == tandaId).toList(),
);

final catadoresDeMesaProvider = Provider.family<List<Catador>, int>((ref, mesaId) {
  final l = ref.watch(catadoresProvider).where((c) => c.mesaId == mesaId).toList();
  l.sort((a, b) => (a.puesto ?? 999).compareTo(b.puesto ?? 999));
  return l;
});

/// Puntuación por "muestraId|catadorId" (única en la base).
final puntuacionIdxProvider = Provider<Map<String, Puntuacion>>(
  (ref) => {for (final p in ref.watch(puntuacionesProvider)) '${p.muestraId}|${p.catadorId}': p},
);

/// Muestras con incidencia abierta (tanda_muestras en estado "incidencia").
final incidenciasAbiertasListaProvider = Provider<List<TandaMuestra>>(
  (ref) => ref.watch(tandaMuestrasProvider).where((t) => t.conIncidencia).toList(),
);
final incidenciasAbiertasProvider = Provider<int>((ref) => ref.watch(incidenciasAbiertasListaProvider).length);

/// Resultados/medallas calculados en la app (no depende de la vista SQL → funciona en LOCAL).
final resultadosProvider = Provider<List<Resultado>>((ref) {
  final medallas = ref.watch(filasProvider('medallas')).value ?? const [];
  return calcularResultados(
    muestras: ref.watch(muestrasProvider),
    puntuaciones: ref.watch(puntuacionesProvider),
    medallas: medallas,
    concurso: ref.watch(concursoProvider),
  );
});

final dispositivosProvider = Provider<List<Dispositivo>>(
  (ref) => _lista(ref, 'dispositivos', Dispositivo.new, (a, b) => a.id.compareTo(b.id)),
);

final dispositivoDeCatadorProvider = Provider<Map<int, Dispositivo>>((ref) {
  final m = <int, Dispositivo>{};
  for (final d in ref.watch(dispositivosProvider)) {
    if (d.catadorId != null) m[d.catadorId!] = d;
  }
  return m;
});

final tabletsLibresProvider = Provider<List<Dispositivo>>(
  (ref) => ref.watch(dispositivosProvider).where((d) => d.libre).toList(),
);
