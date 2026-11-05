import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../widgets.dart';

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ses = ref.watch(sesionProvider).value;
    final cata = ref.watch(cataProvider);
    final e = ref.watch(entornoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes'), actions: const [ChipEntorno()]),
      body: Ancho(
        max: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Entorno activo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SegmentedButton<Entorno>(
              segments: const [
                ButtonSegment(value: Entorno.local, icon: Icon(Icons.dns), label: Text('LOCAL')),
                ButtonSegment(value: Entorno.cloud, icon: Icon(Icons.cloud), label: Text('CLOUD')),
              ],
              selected: {e},
              onSelectionChanged: (s) => ref.read(entornoProvider.notifier).cambiar(s.first),
            ),
            const SizedBox(height: 20),
            for (final en in Entorno.values) ...[_TarjetaEntorno(en), const SizedBox(height: 16)],
            if (ses != null) ...[
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle, size: 36),
                      title: Text(ses.user.email ?? ses.user.id),
                      subtitle: Text('Sesión en ${e.largo}'),
                    ),
                    if (cata != null)
                      ListTile(
                        leading: const Icon(Icons.swap_horiz, size: 36),
                        title: const Text('Cambiar de cata'),
                        subtitle: Text(cata.nombre),
                        onTap: () {
                          ref.read(cataIdProvider.notifier).set(null);
                          context.go('/catas');
                        },
                      ),
                    if (cata != null)
                      ListTile(
                        leading: const Icon(Icons.tune, size: 36),
                        title: const Text('Umbrales de medallas'),
                        subtitle: Text(
                          'Gran Oro ≥ ${cata.umbralGranOro} · Oro ≥ ${cata.umbralOro} · Plata ≥ ${cata.umbralPlata}'
                          '${cata.umbralBronce != null ? ' · Bronce ≥ ${cata.umbralBronce}' : ''}',
                        ),
                        onTap: () => editarCata(context, ref, cata.r),
                      ),
                    ListTile(
                      leading: Icon(Icons.logout, size: 36, color: Theme.of(context).colorScheme.error),
                      title: const Text('Cerrar sesión'),
                      onTap: () async {
                        final c = await ref.read(clienteProvider.future);
                        await c?.auth.signOut();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaEntorno extends ConsumerStatefulWidget {
  const _TarjetaEntorno(this.e);
  final Entorno e;
  @override
  ConsumerState<_TarjetaEntorno> createState() => _TarjetaEntornoState();
}

class _TarjetaEntornoState extends ConsumerState<_TarjetaEntorno> {
  late final _url = TextEditingController();
  late final _key = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = ref.read(backendsProvider).config(widget.e);
    _url.text = c.url;
    _key.text = c.anonKey;
  }

  @override
  Widget build(BuildContext context) {
    final cloud = widget.e == Entorno.cloud;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(cloud ? Icons.cloud : Icons.dns, size: 34),
                const SizedBox(width: 10),
                Text(widget.e.largo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cloud ? 'Project URL y anon/publishable key de tu proyecto (Settings → API).' : 'Salida de `supabase status`. En móvil físico usa la IP del ordenador (http://192.168.x.x:54321); en emulador Android http://10.0.2.2:54321.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Campo(_url, 'URL'),
            Campo(_key, 'Anon / publishable key'),
            FilledButton.tonalIcon(
              onPressed: () async {
                await ref
                    .read(backendsProvider)
                    .guardarConfig(widget.e, ConfigEntorno(url: _url.text, anonKey: _key.text));
                ref.read(revisionProvider.notifier).subir();
                if (context.mounted) aviso(context, '${widget.e.corto} guardado');
              },
              icon: const Icon(Icons.save),
              label: const Text('Guardar conexión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulario de cata (también lo usa la pantalla de catas).
Future<void> editarCata(BuildContext context, WidgetRef ref, Map<String, dynamic>? r) async {
  final repo = ref.read(repoProvider);
  if (repo == null) return;
  String s(String k) => r?[k]?.toString() ?? '';
  final nombre = TextEditingController(text: r == null ? 'Catas Virtus 2027' : s('nombre'));
  final lugar = TextEditingController(text: s('lugar'));
  final fecha = TextEditingController(text: s('fecha'));
  final go = TextEditingController(text: r == null ? '92' : s('umbral_gran_oro'));
  final o = TextEditingController(text: r == null ? '85' : s('umbral_oro'));
  final p = TextEditingController(text: r == null ? '82' : s('umbral_plata'));
  final b = TextEditingController(text: s('umbral_bronce'));
  var extremos = r?['descartar_extremos'] == true;
  double? n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  await hojaFormulario(
    context,
    titulo: r == null ? 'Nueva cata' : 'Editar cata',
    campos: [
      Campo(nombre, 'Nombre', autofocus: r == null),
      Campo(lugar, 'Lugar'),
      Campo(fecha, 'Fecha (AAAA-MM-DD)'),
      Row(
        children: [
          Expanded(child: Campo(go, 'Gran Oro ≥', numero: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(o, 'Oro ≥', numero: true)),
        ],
      ),
      Row(
        children: [
          Expanded(child: Campo(p, 'Plata ≥', numero: true)),
          const SizedBox(width: 10),
          Expanded(child: Campo(b, 'Bronce ≥ (opcional)', numero: true)),
        ],
      ),
      StatefulBuilder(
        builder: (c, set) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Descartar nota más alta y más baja'),
          subtitle: const Text('Solo con 5 o más puntuaciones'),
          value: extremos,
          onChanged: (v) => set(() => extremos = v),
        ),
      ),
    ],
    guardar: () async {
      final datos = {
        'nombre': nombre.text.trim(),
        'lugar': lugar.text.trim().isEmpty ? null : lugar.text.trim(),
        'fecha': fecha.text.trim().isEmpty ? null : fecha.text.trim(),
        'umbral_gran_oro': n(go) ?? 92,
        'umbral_oro': n(o) ?? 85,
        'umbral_plata': n(p) ?? 82,
        'umbral_bronce': n(b),
        'descartar_extremos': extremos,
      };
      if (r == null) {
        final id = await repo.insertar('catas', datos);
        ref.read(cataIdProvider.notifier).set(id);
      } else {
        await repo.actualizar('catas', r['id'], datos);
      }
    },
  );
}
