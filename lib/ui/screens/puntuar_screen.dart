import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

/// Lista de tandas del día: primero las abiertas. Filtro activas / inactivas.
class PuntuarScreen extends ConsumerStatefulWidget {
  const PuntuarScreen({super.key});
  @override
  ConsumerState<PuntuarScreen> createState() => _PuntuarScreenState();
}

class _PuntuarScreenState extends ConsumerState<PuntuarScreen> {
  /// null = todas · true = abiertas · false = pendientes/cerradas
  bool? _soloActivas = true;

  @override
  Widget build(BuildContext context) {
    final tandas = ref.watch(tandasProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    final repo = ref.read(repoProvider)!;
    final k = esCompacto(context);
    const peso = {'abierta': 0, 'pendiente': 1, 'cerrada': 2};
    final filtradas =
        tandas.where((t) {
          if (_soloActivas == null) return true;
          return _soloActivas! ? t.estado == 'abierta' : t.estado != 'abierta';
        }).toList()..sort((a, b) {
          final p = (peso[a.estado] ?? 1).compareTo(peso[b.estado] ?? 1);
          if (p != 0) return p;
          final ma = mesas[a.mesaId]?.numero ?? 999, mb = mesas[b.mesaId]?.numero ?? 999;
          return ma != mb ? ma.compareTo(mb) : a.orden.compareTo(b.orden);
        });

    final problema = avisoCarga(
      ref,
      que: 'Cargar puntuaciones (tandas del día)',
      tablas: const ['tandas', 'tanda_muestras', 'mesas', 'muestras', 'puntuaciones'],
      vacio: tandas.isEmpty,
      queHacerSiVacio:
          'No hay tandas para el día del chip. Cambia el día o elige «Todos los días». '
          'Si el resumen del inicio muestra 0 tandas, Cloud no está devolviendo la tabla.',
    );

    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context),
        title: const Text('Puntuaciones'),
        actions: const [ChipDia(), ChipEntorno()],
      ),
      body:
          problema ??
          Ancho(
            max: 900,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(k ? 10 : 14, k ? 8 : 10, k ? 10 : 14, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool?>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('Activas'), icon: Icon(Icons.play_arrow, size: 18)),
                            ButtonSegment(value: false, label: Text('Inactivas'), icon: Icon(Icons.pause, size: 18)),
                            ButtonSegment(value: null, label: Text('Todas')),
                          ],
                          selected: {_soloActivas},
                          onSelectionChanged: (s) => setState(() => _soloActivas = s.first),
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStatePropertyAll(
                              TextStyle(fontSize: k ? 12 : 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtradas.isEmpty
                      ? Vacio(
                          icono: Icons.table_chart_outlined,
                          texto: _soloActivas == true
                              ? 'No hay tandas activas'
                              : _soloActivas == false
                              ? 'No hay tandas inactivas'
                              : 'No hay tandas',
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(k ? 10 : 14),
                          itemCount: filtradas.length,
                          separatorBuilder: (_, _) => SizedBox(height: k ? 8 : 10),
                          itemBuilder: (c, i) {
                            final t = filtradas[i];
                            final info = infoTanda(t.estado);
                            final tms = ref.watch(muestrasDeTandaProvider(t.id));
                            final hechas = tms.where((x) => x.estado == 'completada').length;
                            final activa = tms.where((x) => x.estado == 'activa').firstOrNull;
                            final muestrasIdx = ref.watch(muestraPorIdProvider);
                            final muestra = activa == null ? null : muestrasIdx[activa.muestraId];
                            final paso = activa?.orden;
                            final abierta = t.estado == 'abierta';
                            final borde = abierta ? Virtus.advertencia.withValues(alpha: 0.55) : Virtus.borde;

                            return Material(
                              color: Virtus.superficie,
                              borderRadius: BorderRadius.circular(Virtus.radioSm),
                              child: InkWell(
                                onTap: () => context.go('/puntuar/${t.id}'),
                                borderRadius: BorderRadius.circular(Virtus.radioSm),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(k ? 12 : 14, k ? 10 : 12, k ? 8 : 10, k ? 10 : 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(Virtus.radioSm),
                                    border: Border.all(color: borde, width: abierta ? 1.6 : 1),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              t.nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: VirtusTexto.importante(size: k ? 20 : 24),
                                            ),
                                            SizedBox(height: k ? 2 : 4),
                                            Text(
                                              muestra == null ? 'Sin muestra activa' : 'Activa ${muestra.codigo}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: VirtusTexto.importante(
                                                size: k ? 16 : 18,
                                                color: muestra != null ? Virtus.accion : Virtus.textoSecundario,
                                              ),
                                            ),
                                            SizedBox(height: k ? 2 : 3),
                                            Text(
                                              [
                                                mesas[t.mesaId]?.nombre ?? 'Sin mesa',
                                                if (paso != null) 'Paso $paso/${tms.length}',
                                                if (muestra?.codigoTexto != null &&
                                                    muestra!.codigoTexto != muestra.codigo)
                                                  'Ref. ${muestra.codigoTexto}',
                                                if (paso == null) '$hechas/${tms.length}',
                                                info.$1,
                                              ].join(' · '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: VirtusTexto.importante(
                                                size: k ? 13 : 15,
                                                color: Virtus.textoSecundario,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: k ? 6 : 8),
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: abierta ? Virtus.exitoSuave : Virtus.accionSuave,
                                          foregroundColor: abierta ? Virtus.exito : Virtus.accion,
                                          padding: EdgeInsets.symmetric(horizontal: k ? 10 : 12, vertical: k ? 8 : 10),
                                          minimumSize: Size(k ? 88 : 100, k ? 40 : 44),
                                          textStyle: TextStyle(fontSize: k ? 12 : 13, fontWeight: FontWeight.w800),
                                        ),
                                        onPressed: () async {
                                          if (abierta) {
                                            final ok = await confirmar(
                                              context,
                                              '¿Desactivar ${t.nombre}?',
                                              texto: 'La tanda pasará a pendiente (ya no estará en curso).',
                                              si: 'Desactivar',
                                            );
                                            if (!ok || !context.mounted) return;
                                            await ejecutar(
                                              context,
                                              () => repo.estadoTanda(t.id, 'pendiente'),
                                              ok: '${t.nombre} desactivada',
                                              accion: 'Desactivar tanda',
                                              refrescar: const ['tandas'],
                                            );
                                          } else {
                                            await ejecutar(
                                              context,
                                              () => repo.estadoTanda(t.id, 'abierta'),
                                              ok: '${t.nombre} activada',
                                              accion: 'Activar tanda',
                                              refrescar: const ['tandas'],
                                            );
                                          }
                                        },
                                        child: Text(abierta ? 'Activa' : 'Activar'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
    );
  }
}

String _fmt(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Puntuaciones de una tanda: muestra · un puesto por columna · total (media).
/// Pulsa una nota para cambiarla en una ventana; pulsa la muestra para sus acciones.
class HojaPuntuacionScreen extends ConsumerWidget {
  const HojaPuntuacionScreen({super.key, required this.tandaId});
  final int tandaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tandaPorIdProvider)[tandaId];
    if (t == null) {
      return Scaffold(
        appBar: AppBar(leading: botonVolver(context, destino: '/puntuar')),
        body: ref.watch(cargandoProvider)
            ? const Center(child: CircularProgressIndicator())
            : const Vacio(icono: Icons.hourglass_empty, texto: 'Tanda no encontrada'),
      );
    }
    final mesa = ref.watch(mesaPorIdProvider)[t.mesaId];
    final ms = ref.watch(muestrasDeTandaProvider(t.id));
    final cs = t.mesaId == null
        ? <Catador>[]
        : ref.watch(catadoresDeMesaProvider(t.mesaId!)).where((c) => c.presente).toList();
    final muestras = ref.watch(muestraPorIdProvider);
    final idx = ref.watch(puntuacionIdxProvider);
    final repo = ref.read(repoProvider)!;
    final scheme = Theme.of(context).colorScheme;
    final k = esCompacto(context);
    final cerrada = t.estado == 'cerrada';

    var hechas = 0;
    for (final m in ms) {
      for (final c in cs) {
        if (idx['${m.muestraId}|${c.id}'] != null) hechas++;
      }
    }
    final total = ms.length * cs.length;

    Widget cuerpo;
    if (ms.isEmpty || cs.isEmpty) {
      cuerpo = Vacio(
        icono: Icons.grid_off,
        texto: ms.isEmpty ? 'La tanda no tiene muestras' : 'La mesa no tiene catadores presentes',
      );
    } else {
      cuerpo = LayoutBuilder(
        builder: (context, box) {
          final anchoMax = box.maxWidth.clamp(0.0, 900.0);
          final wCod = k ? 78.0 : 120.0;
          final wTot = k ? 64.0 : 92.0;
          final ladoCel = k ? 42.0 : 52.0;
          final huecoCeldas = anchoMax - 18 - wCod - wTot;
          final wCel = (huecoCeldas / cs.length).clamp(ladoCel, ladoCel + 8);
          final alto = k ? 52.0 : 64.0;
          final fNota = k ? 20.0 : 24.0;

          Widget cabecera() => Row(
            children: [
              SizedBox(
                width: wCod,
                child: Text(
                  'Código',
                  style: TextStyle(fontSize: k ? 13 : 15, fontWeight: FontWeight.w800, color: Virtus.texto),
                ),
              ),
              for (final c in cs)
                SizedBox(
                  width: wCel,
                  child: Column(
                    children: [
                      Text(
                        'P${c.puesto ?? '-'}',
                        style: TextStyle(fontSize: k ? 13 : 15, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        c.iniciales,
                        style: TextStyle(fontSize: k ? 10 : 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: wTot,
                child: Text(
                  'Total',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: k ? 14 : 17, fontWeight: FontWeight.w900, color: Virtus.texto),
                ),
              ),
            ],
          );

          Widget fila(TandaMuestra tm) {
            final m = muestras[tm.muestraId];
            final notas = [for (final c in cs) idx['${tm.muestraId}|${c.id}']];
            final vals = notas.map((n) => n?.total).whereType<double>().toList();
            final media = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
            final activa = tm.estado == 'activa' || tm.estado == 'en_curso';
            return Container(
              height: alto,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(
                color: activa
                    ? Paleta.amarilloPastel
                    : tm.conIncidencia
                    ? Paleta.rojoPastel
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: activa ? Paleta.amarillo : scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _accionesMuestra(context, ref, tm, m),
                    child: SizedBox(
                      width: wCod,
                      height: alto,
                      child: Row(
                        children: [
                          const SizedBox(width: 6),
                          IconoEstadoTM(estado: tm.estado, tamano: k ? 22 : 26),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              m?.codigo ?? '?',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontSize: k ? 17 : 21, fontWeight: FontWeight.w900, color: Virtus.texto),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (var j = 0; j < cs.length; j++)
                    _Celda(
                      ancho: wCel,
                      alto: ladoCel,
                      fuente: fNota,
                      nota: notas[j],
                      onTap: cerrada
                          ? null
                          : () => editarNota(context, ref, tanda: t, tm: tm, catador: cs[j], actual: notas[j]),
                    ),
                  SizedBox(
                    width: wTot,
                    child: Text(
                      media == null ? '–' : media.toStringAsFixed(1).replaceAll('.', ','),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: k ? 19 : 24, fontWeight: FontWeight.w900, color: Paleta.azulOscuro),
                    ),
                  ),
                ],
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: anchoMax,
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 4), child: cabecera()),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      children: [for (final tm in ms) fila(tm)],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Wrap(
                      spacing: 12,
                      children: [
                        for (final e in estadosNota.entries)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.square_rounded, size: 14, color: e.value.$3.shade200),
                              const SizedBox(width: 3),
                              Text(e.value.$1, style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        Text(
                          'Toca una nota para cambiarla',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context, destino: '/puntuar'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${mesa?.nombre ?? ''} · ${t.nombre}', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${infoTanda(t.estado).$1} · $hechas/$total notas',
              style: TextStyle(fontSize: k ? 12 : 15, color: Colors.white70),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : hechas / total,
            minHeight: 4,
            color: Paleta.amarillo,
            backgroundColor: Paleta.amarilloPastel,
          ),
        ),
        actions: [
          const BotonRefrescar(
            tooltip: 'Actualizar notas',
            tablas: ['puntuaciones', 'tanda_muestras', 'tandas', 'catadores'],
          ),
          if (t.estado == 'pendiente')
            IconButton(
              tooltip: 'Abrir tanda',
              onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, 'abierta')),
              icon: const Icon(Icons.play_arrow),
            ),
          if (t.estado == 'abierta')
            IconButton(
              tooltip: 'Cerrar tanda',
              onPressed: () async {
                if (hechas < total &&
                    !await confirmar(
                      context,
                      '¿Cerrar la tanda?',
                      texto: 'Faltan ${total - hechas} notas.',
                      si: 'Cerrar',
                    )) {
                  return;
                }
                if (context.mounted) {
                  await ejecutar(context, () => repo.estadoTanda(t.id, 'cerrada'), ok: 'Tanda cerrada');
                }
              },
              icon: const Icon(Icons.lock),
            ),
          if (cerrada)
            IconButton(
              tooltip: 'Reabrir',
              onPressed: () => ejecutar(context, () => repo.estadoTanda(t.id, 'abierta')),
              icon: const Icon(Icons.lock_open),
            ),
          IconButton(
            tooltip: 'Incidencia',
            onPressed: () => nuevaIncidencia(context, ref, tandaId: t.id),
            icon: const Icon(Icons.add_alert),
          ),
        ],
      ),
      body: cuerpo,
    );
  }

  Future<void> _accionesMuestra(BuildContext context, WidgetRef ref, TandaMuestra tm, Muestra? m) async {
    final repo = ref.read(repoProvider)!;
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (s) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Muestra ${m?.codigo ?? '?'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(infoTM(tm.estado).$1 + (tm.motivo != null ? ' · ${tm.motivo}' : '')),
            if (tm.estado != 'activa')
              AccionHoja(
                icono: Icons.play_circle_fill,
                color: Paleta.amarillo,
                titulo: 'Poner como ACTIVA',
                subtitulo: 'La que ven las tablets',
                onTap: () => Navigator.pop(s, 'activar'),
              ),
            AccionHoja(
              icono: Icons.verified,
              color: Paleta.lila,
              titulo: 'Aprobar notas y completar',
              onTap: () => Navigator.pop(s, 'aprobar'),
            ),
            AccionHoja(
              icono: Icons.add_alert,
              color: Paleta.rojo,
              titulo: tm.conIncidencia ? 'Resolver incidencia' : 'Marcar incidencia',
              onTap: () => Navigator.pop(s, tm.conIncidencia ? 'resolver' : 'incidencia'),
            ),
            AccionHoja(
              icono: Icons.restart_alt,
              color: Virtus.error,
              titulo: 'Eliminar puntuaciones y dejar pendiente',
              subtitulo: 'Borra todas las notas de esta muestra y quita el estado activa/completada',
              onTap: () => Navigator.pop(s, 'reiniciar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'activar':
        await ejecutar(
          context,
          () => repo.activarMuestra(tm.id),
          ok: '${m?.codigo} activa',
          refrescar: const ['tanda_muestras', 'tandas'],
        );
      case 'aprobar':
        if (await confirmar(context, '¿Aprobar las notas de ${m?.codigo}?', si: 'Aprobar') && context.mounted) {
          await ejecutar(
            context,
            () => repo.aprobarMuestra(tm.id),
            ok: '${m?.codigo} aprobada',
            refrescar: tablasNotas,
          );
        }
      case 'incidencia':
        await nuevaIncidencia(context, ref, tm: tm);
      case 'resolver':
        await resolverIncidencia(context, ref, tm);
      case 'reiniciar':
        if (await confirmar(
              context,
              '¿Eliminar puntuaciones de ${m?.codigo}?',
              texto:
                  'Se borrarán TODAS las notas de esta muestra en la tanda y pasará a estado pendiente '
                  '(deja de estar activa/completada). Esta acción no se puede deshacer desde la app.',
              si: 'Eliminar y dejar pendiente',
              destructivo: true,
            ) &&
            context.mounted) {
          var n = 0;
          final ok = await ejecutar(
            context,
            () async => n = await repo.reiniciarMuestra(tm.id),
            accion: 'Reiniciar muestra ${m?.codigo}',
            refrescar: tablasNotas,
          );
          if (ok && context.mounted) aviso(context, '${m?.codigo}: $n notas borradas · pendiente');
        }
    }
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.ancho, required this.alto, required this.fuente, required this.nota, this.onTap});
  final double ancho;
  final double alto;
  final double fuente;
  final Puntuacion? nota;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = estadosNota[nota?.estado]?.$3;
    final lado = alto.clamp(36.0, ancho - 4);
    return SizedBox(
      width: ancho,
      child: Center(
        child: Material(
          color: nota == null ? Virtus.neutroSuave : (c ?? Colors.blue).shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              width: lado,
              height: lado,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (c ?? Virtus.mcNeutro).shade300, width: 1),
              ),
              child: Text(
                _fmt(nota?.total),
                style: TextStyle(
                  fontSize: fuente,
                  fontWeight: FontWeight.w900,
                  color: c?.shade900 ?? Virtus.texto,
                  fontStyle: nota?.manual == true ? FontStyle.italic : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ventana para poner/cambiar/borrar la nota de un catador en una muestra.
Future<void> editarNota(
  BuildContext context,
  WidgetRef ref, {
  required Tanda tanda,
  required TandaMuestra tm,
  required Catador catador,
  Puntuacion? actual,
}) async {
  final codigo = ref.read(muestraPorIdProvider)[tm.muestraId]?.codigo ?? '?';
  final notasMuestra = ref
      .read(puntuacionesProvider)
      .where((p) => p.muestraId == tm.muestraId && p.tandaId == tanda.id)
      .toList();
  final bloqueada = actual?.aprobada == true || tm.estado == 'completada' || notasMuestra.any((p) => p.aprobada);
  var forzar = false;
  if (bloqueada) {
    final ok = await confirmar(
      context,
      'Muestra $codigo bloqueada',
      texto:
          'Hay notas aprobadas (o la muestra está completada). '
          'Como admin puedes forzar el cambio: se reabre la muestra y la nota pasa a «enviada».',
      si: 'Forzar cambio',
    );
    if (!ok || !context.mounted) return;
    forzar = true;
  }
  final r = await showDialog<(bool, double?)>(
    context: context,
    builder: (c) => _DialogoNota(
      titulo: '$codigo · P${catador.puesto ?? '-'} ${catador.nombre}',
      inicial: actual?.total,
      puedeBorrar: actual != null,
    ),
  );
  if (r == null || !context.mounted) return;
  final (borrar, valor) = r;
  final repo = ref.read(repoProvider)!;
  await ejecutar(
    context,
    () async {
      if (borrar) {
        await repo.borrarPuntuacion(actual!.id, forzar: forzar);
      } else if (valor != null) {
        await repo.puntuarManual(
          muestraId: tm.muestraId,
          catadorId: catador.id,
          tandaId: tanda.id,
          total: valor,
          forzar: forzar,
        );
      }
    },
    accion: forzar ? 'Forzar nota $codigo' : 'Editar nota $codigo',
    refrescar: tablasNotas,
  );
}

class _DialogoNota extends StatefulWidget {
  const _DialogoNota({required this.titulo, required this.inicial, required this.puedeBorrar});
  final String titulo;
  final double? inicial;
  final bool puedeBorrar;
  @override
  State<_DialogoNota> createState() => _DialogoNotaState();
}

class _DialogoNotaState extends State<_DialogoNota> {
  late String _e = widget.inicial == null ? '' : _fmt(widget.inicial);
  bool _nuevo = true; // la primera tecla sustituye el valor actual

  void _tecla(String t) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_nuevo && t != '⌫') _e = '';
      _nuevo = false;
      if (t == '⌫') {
        if (_e.isNotEmpty) _e = _e.substring(0, _e.length - 1);
      } else if (t == ',') {
        if (!_e.contains(',')) _e = _e.isEmpty ? '0,' : '$_e,';
      } else if (_e.length < 5) {
        final d = _e.split(',');
        if (d.length == 2 && d[1].isNotEmpty) return;
        _e += t;
      }
    });
  }

  double? get _valor => double.tryParse(_e.replaceAll(',', '.'));
  bool get _valido => _valor != null && _valor! >= 0 && _valor! <= 100;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tecla(String t) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: EdgeInsets.zero,
            backgroundColor: Paleta.azulPastel,
            foregroundColor: Paleta.azulOscuro,
          ),
          onPressed: () => _tecla(t),
          child: t == '⌫'
              ? const Icon(Icons.backspace_outlined)
              : Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
      ),
    );
    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        final ch = e.character;
        if (ch != null && RegExp(r'^[0-9]$').hasMatch(ch)) {
          _tecla(ch);
        } else if (ch == ',' || ch == '.') {
          _tecla(',');
        } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
          _tecla('⌫');
        } else if (e.logicalKey == LogicalKeyboardKey.enter && _valido) {
          Navigator.pop(context, (false, _valor));
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        title: Text(widget.titulo, maxLines: 2, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Paleta.amarilloPastel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _valido || _e.isEmpty ? Paleta.amarillo : cs.error, width: 1.5),
                ),
                child: Text(
                  _e.isEmpty ? '—' : _e,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: _nuevo ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (final fila in const [
                ['7', '8', '9'],
                ['4', '5', '6'],
                ['1', '2', '3'],
                [',', '0', '⌫'],
              ])
                Row(children: [for (final t in fila) tecla(t)]),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        actions: [
          if (widget.puedeBorrar)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => Navigator.pop(context, (true, null)),
              child: const Text('Borrar'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: _valido ? () => Navigator.pop(context, (false, _valor)) : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
