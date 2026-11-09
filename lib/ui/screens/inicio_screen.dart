import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../marca.dart';
import '../theme.dart';
import '../widgets.dart';

/// Acentos pastel de cada sección del menú.
abstract final class _Seccion {
  static const directo = Virtus.error;
  static const mesas = Virtus.accion;
  static const puntuar = Virtus.advertencia;
  static const tandas = Virtus.exito;
  static const incidencias = Virtus.error;
  static const catadores = Color(0xFF7C3AED);
  static const muestras = Color(0xFFC2410C);
  static const medallero = Color(0xFFCA8A04);
  static const auditoria = Virtus.textoSecundario;
}

/// Panel principal: resumen neutro + botones pastel compactos.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final concurso = ref.watch(concursoProvider);
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final catadores = ref.watch(catadoresProvider);
    final muestras = ref.watch(muestrasProvider);
    final punt = ref.watch(puntuacionesProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final cargando = ref.watch(cargandoProvider);
    final dia = ref.watch(diaIdProvider);
    final dias = ref.watch(diasProvider);
    final conteos = ref.watch(conteoTablasProvider);
    final errores = ref.watch(erroresTablasProvider);
    final avisos = ref.watch(avisosTablasProvider);
    final k = esCompacto(context);

    final abiertas = tandas.where((t) => t.estado == 'abierta').length;
    final cerradas = tandas.where((t) => t.estado == 'cerrada').length;
    final ausentes = catadores.where((c) => !c.presente).length;
    final conectados = catadores.where((c) => c.conectado).length;
    final catando = mesas.where((m) => tandas.any((t) => t.mesaId == m.id && t.estado == 'abierta')).length;
    final reservas = ref.watch(tabletsLibresProvider).length;
    final nombreDia = dia == null
        ? 'Todos'
        : (dias.where((d) => d.id == dia).map((d) => d.nombre).firstOrNull ?? 'Día $dia');
    final tablasMal = errores.length + avisos.length;
    final filasDatos = conteos.values.where((v) => v != '…' && v != 'ERR').fold<int>(0, (a, v) {
      return a + (int.tryParse(v) ?? 0);
    });

    final resumen = [
      TarjetaResumen(
        titulo: 'Catando',
        valor: '$catando/${mesas.length}',
        icono: Icons.live_tv_outlined,
        alerta: catando > 0,
      ),
      TarjetaResumen(titulo: 'Abiertas', valor: '$abiertas', icono: Icons.format_list_numbered_outlined),
      TarjetaResumen(titulo: 'Alertas', valor: '$inc', icono: Icons.warning_amber_outlined, alerta: inc > 0),
      TarjetaResumen(titulo: 'Tablets', valor: '$conectados/${catadores.length}', icono: Icons.tablet_android_outlined),
      TarjetaResumen(titulo: 'Día', valor: nombreDia, icono: Icons.calendar_today_outlined),
      TarjetaResumen(
        titulo: tablasMal > 0 ? 'Datos · aviso' : 'Datos',
        valor: '$filasDatos',
        icono: tablasMal > 0 ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
        alerta: tablasMal > 0,
      ),
    ];

    final tiles = [
      Baldosa(
        icono: Icons.live_tv_outlined,
        texto: 'En directo',
        sub: '$catando de ${mesas.length} mesas',
        color: _Seccion.directo,
        onTap: () => context.go('/directo'),
      ),
      Baldosa(
        icono: Icons.table_restaurant_outlined,
        texto: 'Mesas',
        sub: '${mesas.length} mesas',
        color: _Seccion.mesas,
        onTap: () => context.go('/mesas'),
      ),
      Baldosa(
        icono: Icons.grid_view_outlined,
        texto: 'Puntuaciones',
        sub: '${punt.length} notas',
        color: _Seccion.puntuar,
        onTap: () => context.go('/puntuar'),
      ),
      Baldosa(
        icono: Icons.format_list_numbered_outlined,
        texto: 'Tandas',
        sub: '$abiertas ab. · $cerradas cer.',
        color: _Seccion.tandas,
        onTap: () => context.go('/tandas'),
      ),
      Baldosa(
        icono: Icons.warning_amber_outlined,
        texto: 'Incidencias',
        sub: inc == 0 ? 'Sin abiertas' : '$inc abiertas',
        color: _Seccion.incidencias,
        badge: inc,
        onTap: () => context.go('/incidencias'),
      ),
      Baldosa(
        icono: Icons.groups_outlined,
        texto: 'Catadores',
        sub: '$conectados/${catadores.length}${ausentes > 0 ? ' · $ausentes aus.' : ''}',
        color: _Seccion.catadores,
        onTap: () => context.go('/catadores'),
      ),
      Baldosa(
        icono: Icons.wine_bar_outlined,
        texto: 'Muestras',
        sub: '${muestras.where((m) => m.activa).length} activas',
        color: _Seccion.muestras,
        onTap: () => context.go('/muestras'),
      ),
      Baldosa(
        icono: Icons.military_tech_outlined,
        texto: 'Medallero Provisional',
        sub: 'Resultados del día',
        color: _Seccion.medallero,
        onTap: () => context.go('/medallas'),
      ),
      Baldosa(
        icono: Icons.fact_check_outlined,
        texto: 'Auditoría',
        sub: reservas > 0 ? '$reservas reserva${reservas == 1 ? '' : 's'}' : 'Chequeos del día',
        color: _Seccion.auditoria,
        onTap: () => context.go('/auditoria'),
      ),
    ];

    final cols = k ? 3 : (MediaQuery.sizeOf(context).width >= 1100 ? 5 : 3);
    final problema = avisoCarga(
      ref,
      que: 'Cargar el panel de inicio',
      tablas: const ['mesas', 'tandas', 'catadores', 'muestras', 'puntuaciones', 'tanda_muestras'],
      vacio: !cargando && mesas.isEmpty && tandas.isEmpty && catadores.isEmpty,
      queHacerSiVacio: 'No hay mesas, tandas ni catadores. Elige el concurso correcto o sincroniza / revisa CLOUD.',
    );

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.only(left: 12), child: IconoCataris(tamano: 32, fondoOscuro: true)),
        leadingWidth: 48,
        title: Text(concurso?.nombre ?? MarcaApp.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          const ChipDia(),
          if (!esAncho(context)) ...[
            IconButton(
              tooltip: 'Sincronizar',
              onPressed: () => context.push('/sync'),
              icon: const Icon(Icons.sync_outlined),
            ),
            IconButton(
              tooltip: 'Ajustes',
              onPressed: () => context.push('/configuracion'),
              icon: const Icon(Icons.settings_outlined),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => cerrarSesion(context, ref),
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
          const ChipEntorno(),
        ],
      ),
      body:
          problema ??
          Ancho(
            max: 1200,
            child: LayoutBuilder(
              builder: (c, box) {
                final pad = k ? 10.0 : 16.0;
                final gap = k ? 6.0 : 10.0;
                final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
                final h = box.maxHeight.isFinite ? box.maxHeight : 600.0;
                final kpiCols = k ? 3 : 6;
                final kpiFilas = (resumen.length / kpiCols).ceil();
                final kpiGap = k ? 6.0 : 8.0;
                final kpiAlto = k ? 64.0 : 76.0;
                final kpiBloque = kpiFilas * kpiAlto + (kpiFilas - 1) * kpiGap + (k ? 8.0 : 10.0);
                final filas = (tiles.length / cols).ceil();
                final ancho = (w - pad * 2 - gap * (cols - 1)) / cols;
                final altoDisp = (h - pad * 2 - kpiBloque - gap * (filas - 1)) / filas;
                // Botones más bajos / compactos.
                final alto = altoDisp.clamp(k ? 78.0 : 88.0, k ? 96.0 : 110.0);
                return Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    children: [
                      SizedBox(
                        height: kpiFilas * kpiAlto + (kpiFilas - 1) * kpiGap,
                        child: GridView.count(
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: kpiCols,
                          mainAxisSpacing: kpiGap,
                          crossAxisSpacing: kpiGap,
                          childAspectRatio: ((w - pad * 2 - kpiGap * (kpiCols - 1)) / kpiCols) / kpiAlto,
                          children: resumen,
                        ),
                      ),
                      SizedBox(height: k ? 8 : 10),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            crossAxisCount: cols,
                            mainAxisSpacing: gap,
                            crossAxisSpacing: gap,
                            childAspectRatio: ancho / alto,
                            children: tiles,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
    );
  }
}
