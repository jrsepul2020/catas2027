import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../../data/auditoria.dart';
import '../componentes_cataris.dart';
import '../iconos.dart';
import '../marca.dart';
import '../theme.dart';
import '../widgets.dart';

/// Panel principal Cataris: conexión, resumen, progreso y gestión rápida.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final tms = ref.watch(tandaMuestrasProvider);
    final catadores = ref.watch(catadoresProvider);
    final muestras = ref.watch(muestrasProvider);
    final punt = ref.watch(puntuacionesProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final cargando = ref.watch(cargandoProvider);
    final entorno = ref.watch(entornoProvider);
    final conexion = ref.watch(estadoConexionProvider);
    final esLocal = ref.watch(esLocalProvider);
    final k = esCompacto(context);

    final abiertas = tandas.where((t) => t.estado == 'abierta').toList();
    final nAbiertas = abiertas.length;
    final conectados = catadores.where((c) => c.conectado).length;
    final catando = mesas.where((m) => abiertas.any((t) => t.mesaId == m.id)).length;
    // Progreso del día = todas las muestras del día (tanda_muestras ya filtradas).
    final muestrasTot = tms.length;
    final muestrasHechas = tms.where((tm) => tm.estado == 'completada').length;
    final conectado = conexion.maybeWhen(data: (v) => v.$1, orElse: () => false);
    final msgConexion = conexion.when(data: (v) => v.$2, loading: () => 'Comprobando…', error: (e, _) => '$e');
    final diaId = ref.watch(diaIdProvider);
    final dia = ref.watch(diasProvider).where((d) => d.id == diaId).firstOrNull;
    final fechaDia = dia?.fecha;
    final auditoria = ref.watch(ultimaAuditoriaProvider);
    final subAuditoria = () {
      if (auditoria == null) return 'Chequeos';
      final hora = formatearHoraAuditoria(auditoria.cuando);
      if (auditoria.todoCorrecto) return 'Todo correcto · $hora';
      final n = auditoria.hallazgos.length;
      return '$n hallazgo${n == 1 ? '' : 's'} · $hora';
    }();

    final acciones = [
      (Iconos.directo, 'En directo', '$catando en cata', '/directo', true, false, false),
      (Iconos.tandas, 'Tandas', '$nAbiertas abiertas', '/tandas', false, false, false),
      (Iconos.muestras, 'Muestras', '${muestras.length} hoy', '/muestras', false, false, false),
      (Iconos.mesas, 'Mesas', '${mesas.length} mesas', '/mesas', false, false, false),
      (Iconos.puntuaciones, 'Puntuaciones', '${punt.length} notas', '/puntuar', false, false, false),
      (
        Iconos.incidencias,
        'Incidencias',
        inc == 0 ? 'Ninguna' : '$inc abiertas',
        '/incidencias',
        false,
        false,
        inc > 0,
      ),
      (Iconos.catadores, 'Catadores', '$conectados conectados', '/catadores', false, false, false),
      (Iconos.medallero, 'Medallero', 'provisional', '/medallas', false, false, false),
      (
        Iconos.auditoria,
        'Auditoría',
        subAuditoria,
        '/auditoria',
        false,
        auditoria?.todoCorrecto == true,
        auditoria != null && !auditoria.todoCorrecto,
      ),
    ];

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
        title: const Text(MarcaApp.corto),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          if (!esLocal) const ChipDia(),
          const ChipEntorno(),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => context.push('/configuracion'),
            icon: const Icon(Iconos.ajustes, size: VirtusIcono.cabecera),
          ),
        ],
      ),
      body:
          problema ??
          Ancho(
            max: 1100,
            child: Column(
              children: [
                const FranjaModoPruebas(),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 14, k ? 12 : 16, k ? 16 : 24),
                    children: [
                      _TarjetaConexion(
                        entorno: entorno,
                        conectado: conectado,
                        mensaje: msgConexion,
                        fechaDia: fechaDia,
                        onReprobar: () => ref.invalidate(estadoConexionProvider),
                        onCambiar: () async {
                          final ok = await confirmar(
                            context,
                            'Cambiar a ${entorno.otro.largo}',
                            texto: 'Trabajarás con los datos de ${entorno.otro.corto}.',
                            si: 'Cambiar',
                          );
                          if (ok) ref.read(entornoProvider.notifier).cambiar(entorno.otro);
                        },
                      ),
                      SizedBox(height: k ? 12 : 14),
                      LayoutBuilder(
                        builder: (c, box) {
                          final gap = k ? 8.0 : 10.0;
                          final w = (box.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              SizedBox(
                                width: w,
                                child: TileResumen(etiqueta: 'Mesas catando', valor: '$catando / ${mesas.length}'),
                              ),
                              SizedBox(
                                width: w,
                                child: TileResumen(etiqueta: 'Tandas abiertas', valor: '$nAbiertas'),
                              ),
                              SizedBox(
                                width: w,
                                child: TileResumen(etiqueta: 'Incidencias', valor: '$inc', alerta: inc > 0),
                              ),
                              SizedBox(
                                width: w,
                                child: TileResumen(etiqueta: 'Tablets', valor: '$conectados / ${catadores.length}'),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: k ? 12 : 14),
                      BarraProgresoDia(hechas: muestrasHechas, total: muestrasTot),
                      SizedBox(height: k ? 14 : 18),
                      Text('Gestión rápida', style: VirtusTexto.titulo(size: k ? 15 : 16)),
                      SizedBox(height: k ? 8 : 10),
                      LayoutBuilder(
                        builder: (c, box) {
                          final gap = k ? 8.0 : 10.0;
                          final w = (box.maxWidth - gap * 2) / 3;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final a in acciones)
                                SizedBox(
                                  width: w,
                                  child: TileAccion(
                                    icono: a.$1,
                                    titulo: a.$2,
                                    subtitulo: a.$3,
                                    onTap: () => context.go(a.$4),
                                    destacado: a.$5,
                                    subtituloVerde: a.$6,
                                    alerta: a.$7,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _TarjetaConexion extends StatelessWidget {
  const _TarjetaConexion({
    required this.entorno,
    required this.conectado,
    required this.mensaje,
    required this.fechaDia,
    required this.onReprobar,
    required this.onCambiar,
  });
  final Entorno entorno;
  final bool conectado;
  final String mensaje;
  final String? fechaDia;
  final VoidCallback onReprobar;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final color = conectado ? Virtus.enMarcha : Virtus.error;
    final diaTxt = (fechaDia == null || fechaDia!.isEmpty) ? null : fechaCortaEs(fechaDia!);
    return Container(
      padding: EdgeInsets.all(k ? 12 : 14),
      decoration: BoxDecoration(
        color: Virtus.superficie,
        borderRadius: BorderRadius.circular(Virtus.radio),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Material(
            color: Color.lerp(Colors.white, color, 0.12),
            borderRadius: BorderRadius.circular(Virtus.radioSm),
            child: InkWell(
              onTap: onReprobar,
              borderRadius: BorderRadius.circular(Virtus.radioSm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(conectado ? Iconos.check : Iconos.aviso, color: color, size: VirtusIcono.medio),
              ),
            ),
          ),
          SizedBox(width: k ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conectado ? 'Conectado · ${entorno.corto}' : 'Sin conexión · ${entorno.corto}',
                  style: VirtusTexto.importante(size: k ? 15 : 16, color: color),
                ),
                Text(
                  [entorno.largo, mensaje, if (diaTxt != null) 'día $diaTxt'].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: VirtusTexto.tenue(size: k ? 11 : 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCambiar,
            child: Text(entorno.otro.corto, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
