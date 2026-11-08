import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../widgets.dart';

class _Dest {
  const _Dest(this.ruta, this.icono, this.texto, {this.movil = true});
  final String ruta;
  final IconData icono;
  final String texto;
  final bool movil;
}

const _destinos = [
  _Dest('/', Icons.home, 'Inicio'),
  _Dest('/directo', Icons.live_tv, 'Directo'),
  _Dest('/mesas', Icons.table_restaurant, 'Mesas'),
  _Dest('/puntuar', Icons.grid_on, 'Puntuac.'),
  _Dest('/incidencias', Icons.warning_amber_rounded, 'Incidencias'),
  _Dest('/medallas', Icons.military_tech, 'Medallas', movil: false),
  _Dest('/tandas', Icons.format_list_numbered, 'Tandas', movil: false),
  _Dest('/catadores', Icons.groups, 'Catadores', movil: false),
  _Dest('/muestras', Icons.wine_bar, 'Muestras', movil: false),
];

/// Estructura adaptativa: barra inferior en móvil, rail lateral en ordenador.
class Shell extends ConsumerWidget {
  const Shell({super.key, required this.ubicacion, required this.child});
  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ancho = esAncho(context);
    final lista = ancho ? _destinos : _destinos.where((d) => d.movil).toList();
    var sel = 0;
    for (var i = 1; i < lista.length; i++) {
      if (ubicacion.startsWith(lista[i].ruta)) sel = i;
    }
    final inc = ref.watch(incidenciasAbiertasProvider);

    Widget icono(_Dest d, {bool sel = false}) {
      final i = Icon(d.icono);
      if (d.ruta == '/incidencias' && inc > 0) {
        return Badge(label: Text('$inc'), child: i);
      }
      return i;
    }

    if (ancho) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: sel,
              onDestinationSelected: (i) => context.go(lista[i].ruta),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.wine_bar, size: 40, color: Colors.white),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Sincronizar',
                          color: Colors.white,
                          onPressed: () => context.push('/sync'),
                          icon: const Icon(Icons.sync),
                        ),
                        IconButton(
                          tooltip: 'Ajustes',
                          color: Colors.white,
                          onPressed: () => context.push('/configuracion'),
                          icon: const Icon(Icons.settings),
                        ),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          color: Colors.white,
                          onPressed: () => cerrarSesion(context, ref),
                          icon: const Icon(Icons.logout),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [for (final d in lista) NavigationRailDestination(icon: icono(d), label: Text(d.texto))],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: child),
                  const PanelDiagnostico(),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: child),
          const PanelDiagnostico(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: sel,
        onDestinationSelected: (i) => context.go(lista[i].ruta),
        destinations: [for (final d in lista) NavigationDestination(icon: icono(d), label: d.texto)],
      ),
    );
  }
}
