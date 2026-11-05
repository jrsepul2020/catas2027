import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../widgets.dart';
import 'ajustes_screen.dart';

class CatasScreen extends ConsumerWidget {
  const CatasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catas = ref.watch(catasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige la cata'),
        actions: [
          IconButton(onPressed: () => context.push('/sync'), icon: const Icon(Icons.sync)),
          IconButton(onPressed: () => context.push('/ajustes'), icon: const Icon(Icons.settings)),
          const ChipEntorno(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editarCata(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cata'),
      ),
      body: catas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Vacio(icono: Icons.error, texto: '$e'),
        data: (l) => l.isEmpty
            ? const Vacio(
                icono: Icons.wine_bar,
                texto: 'No hay catas todavía.\nCrea una o sincroniza desde el otro entorno.',
              )
            : Ancho(
                max: 760,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: l.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (c, i) => Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      leading: const Icon(Icons.wine_bar, size: 44),
                      title: Text(l[i].nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      subtitle: Text([l[i].fecha, l[i].lugar].whereType<String>().join(' · ')),
                      trailing: const Icon(Icons.chevron_right, size: 36),
                      onTap: () {
                        ref.read(cataIdProvider.notifier).set(l[i].id);
                        context.go('/');
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
