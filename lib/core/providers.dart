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
  return c == null ? null : Repo(c);
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

// ---------------- Tablas en tiempo real ----------------
final filasProvider = StreamProvider.family<List<Json>, String>((ref, tabla) async* {
  final c = await ref.watch(clienteProvider.future);
  if (c == null || ref.watch(usuarioIdProvider) == null) {
    yield const [];
    return;
  }
  if (tabla == 'registro_cambios') {
    yield* c.from(tabla).stream(primaryKey: ['id']).order('creado_en').limit(300);
  } else {
    yield* c.from(tabla).stream(primaryKey: ['id']).order('id', ascending: true);
  }
});

List<T> _lista<T>(Ref ref, String tabla, T Function(Json) f, [int Function(T, T)? cmp]) {
  final l = (ref.watch(filasProvider(tabla)).value ?? const []).map(f).toList();
  if (cmp != null) l.sort(cmp);
  return l;
}

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

final catadoresProvider = Provider<List<Catador>>(
  (ref) => _lista(ref, 'catadores', Catador.new, (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
);

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

/// Resultados/medallas (vista SQL). Se recalcula cuando cambian notas o medallas.
final resultadosProvider = FutureProvider<List<Resultado>>((ref) async {
  ref.watch(puntuacionesProvider);
  ref.watch(filasProvider('medallas'));
  ref.watch(concursoProvider);
  final repo = ref.watch(repoProvider);
  if (repo == null || ref.watch(usuarioIdProvider) == null) return const [];
  return repo.resultados(ref.watch(concursoIdProvider));
});
