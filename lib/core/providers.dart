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

// ---------------- Cata seleccionada ----------------
class CataSel extends Notifier<String?> {
  @override
  String? build() {
    final e = ref.watch(entornoProvider);
    return ref.read(prefsProvider).getString('cata_${e.name}');
  }

  void set(String? id) {
    final e = ref.read(entornoProvider);
    final p = ref.read(prefsProvider);
    id == null ? p.remove('cata_${e.name}') : p.setString('cata_${e.name}', id);
    state = id;
  }
}

final cataIdProvider = NotifierProvider<CataSel, String?>(CataSel.new);

final catasProvider = StreamProvider<List<Cata>>((ref) async* {
  final c = await ref.watch(clienteProvider.future);
  if (c == null || ref.watch(usuarioIdProvider) == null) {
    yield const [];
    return;
  }
  yield* c
      .from('catas')
      .stream(primaryKey: ['id'])
      .order('fecha', ascending: false)
      .map((l) => l.where(vivo).map(Cata.new).toList());
});

final cataProvider = Provider<Cata?>((ref) {
  final id = ref.watch(cataIdProvider);
  final l = ref.watch(catasProvider).value ?? const [];
  for (final c in l) {
    if (c.id == id) return c;
  }
  return null;
});

/// Stream en tiempo real de una tabla filtrada por cata. (tabla, cataId)
final filasProvider = StreamProvider.family<List<Json>, (String, String)>((ref, k) async* {
  final c = await ref.watch(clienteProvider.future);
  if (c == null || ref.watch(usuarioIdProvider) == null) {
    yield const [];
    return;
  }
  yield* c.from(k.$1).stream(primaryKey: ['id']).eq('cata_id', k.$2).map((l) => l.where(vivo).toList(growable: false));
});

AsyncValue<List<Json>> _tabla(Ref ref, String tabla) {
  final id = ref.watch(cataIdProvider);
  if (id == null) return const AsyncData([]);
  return ref.watch(filasProvider((tabla, id)));
}

List<T> _lista<T>(Ref ref, String tabla, T Function(Json) f, [int Function(T, T)? cmp]) {
  final l = (_tabla(ref, tabla).value ?? const []).map(f).toList();
  if (cmp != null) l.sort(cmp);
  return l;
}

final cargandoProvider = Provider<bool>((ref) {
  for (final t in const ['mesas', 'catadores', 'muestras', 'tandas']) {
    if (_tabla(ref, t).isLoading) return true;
  }
  return false;
});

final mesasProvider = Provider<List<Mesa>>(
  (ref) => _lista(ref, 'mesas', Mesa.new, (a, b) => a.numero.compareTo(b.numero)),
);

final catadoresProvider = Provider<List<Catador>>(
  (ref) =>
      _lista(ref, 'catadores', Catador.new, (a, b) => a.completo.toLowerCase().compareTo(b.completo.toLowerCase())),
);

final muestrasProvider = Provider<List<Muestra>>(
  (ref) => _lista(ref, 'muestras', Muestra.new, (a, b) => a.codigo.compareTo(b.codigo)),
);

final tandasProvider = Provider<List<Tanda>>(
  (ref) => _lista(ref, 'tandas', Tanda.new, (a, b) => a.orden.compareTo(b.orden)),
);

final tandaMuestrasProvider = Provider<List<TandaMuestra>>(
  (ref) => _lista(ref, 'tanda_muestras', TandaMuestra.new, (a, b) => a.orden.compareTo(b.orden)),
);

final puntuacionesProvider = Provider<List<Puntuacion>>((ref) => _lista(ref, 'puntuaciones', Puntuacion.new));

final incidenciasProvider = Provider<List<Incidencia>>(
  (ref) => _lista(
    ref,
    'incidencias',
    Incidencia.new,
    (a, b) => (b.creada ?? DateTime(0)).compareTo(a.creada ?? DateTime(0)),
  ),
);

// ---------- Índices derivados (memoizados por Riverpod) ----------
final mesaPorIdProvider = Provider<Map<String, Mesa>>((ref) => {for (final m in ref.watch(mesasProvider)) m.id: m});
final muestraPorIdProvider = Provider<Map<String, Muestra>>(
  (ref) => {for (final m in ref.watch(muestrasProvider)) m.id: m},
);
final catadorPorIdProvider = Provider<Map<String, Catador>>(
  (ref) => {for (final c in ref.watch(catadoresProvider)) c.id: c},
);

final tandasDeMesaProvider = Provider.family<List<Tanda>, String?>(
  (ref, mesaId) => ref.watch(tandasProvider).where((t) => t.mesaId == mesaId).toList(),
);

final muestrasDeTandaProvider = Provider.family<List<TandaMuestra>, String>(
  (ref, tandaId) => ref.watch(tandaMuestrasProvider).where((t) => t.tandaId == tandaId).toList(),
);

final catadoresDeMesaProvider = Provider.family<List<Catador>, String>((ref, mesaId) {
  final l = ref.watch(catadoresProvider).where((c) => c.mesaId == mesaId).toList();
  l.sort((a, b) => (a.puesto ?? 999).compareTo(b.puesto ?? 999));
  return l;
});

/// puntuación por "muestraId|catadorId"
final puntuacionIdxProvider = Provider<Map<String, Puntuacion>>(
  (ref) => {for (final p in ref.watch(puntuacionesProvider)) '${p.muestraId}|${p.catadorId}': p},
);

final incidenciasAbiertasProvider = Provider<int>(
  (ref) => ref.watch(incidenciasProvider).where((i) => i.estado == 'abierta').length,
);

/// Resultados/medallas (vista SQL). Se recalcula cuando cambian las puntuaciones.
final resultadosProvider = FutureProvider<List<Resultado>>((ref) async {
  ref.watch(puntuacionesProvider);
  ref.watch(muestrasProvider);
  ref.watch(cataProvider);
  final repo = ref.watch(repoProvider);
  final id = ref.watch(cataIdProvider);
  if (repo == null || id == null) return const [];
  return repo.resultados(id);
});
