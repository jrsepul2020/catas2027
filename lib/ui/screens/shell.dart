import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/actualizacion.dart';
import '../../core/providers.dart';
import '../iconos.dart';
import '../marca.dart';
import '../widgets.dart';

class _Dest {
  const _Dest(this.ruta, this.icono, this.texto, {this.movil = true});
  final String ruta;
  final IconData icono;
  final String texto;
  final bool movil;
}

const _destinos = [
  _Dest('/', Iconos.inicio, 'Inicio'),
  _Dest('/directo', Iconos.directo, 'Directo'),
  _Dest('/mesas', Iconos.mesas, 'Mesas'),
  _Dest('/puntuar', Iconos.puntuaciones, 'Puntuac.'),
  _Dest('/incidencias', Iconos.incidencias, 'Incidencias'),
  _Dest('/medallas', Iconos.medallero, 'Medallero', movil: false),
  _Dest('/tandas', Iconos.tandas, 'Tandas', movil: false),
  _Dest('/catadores', Iconos.catadores, 'Catadores', movil: false),
  _Dest('/muestras', Iconos.muestras, 'Muestras', movil: false),
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
                child: IconoCataris(tamano: 40, fondoOscuro: true),
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
                          icon: const Icon(Iconos.sync),
                        ),
                        IconButton(
                          tooltip: 'Ajustes',
                          color: Colors.white,
                          onPressed: () => context.push('/configuracion'),
                          icon: const Icon(Iconos.ajustes),
                        ),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          color: Colors.white,
                          onPressed: () => cerrarSesion(context, ref),
                          icon: const Icon(Iconos.logout),
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
                  const AvisoActualizacionDisponible(),
                  const AvisoSesionGestion(),
                  Expanded(child: child),
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
          const AvisoActualizacionDisponible(),
          const AvisoSesionGestion(),
          Expanded(child: child),
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
