import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'incidencias_screen.dart';

/// Lista de tandas del día: primero las abiertas.
class PuntuarScreen extends ConsumerWidget {
  const PuntuarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tandas = ref.watch(tandasProvider);
    final mesas = ref.watch(mesaPorIdProvider);
    final k = esCompacto(context);
    const peso = {'abierta': 0, 'pendiente': 1, 'cerrada': 2};
    final l = [...tandas]
      ..sort((a, b) {
        final p = (peso[a.estado] ?? 1).compareTo(peso[b.estado] ?? 1);
        if (p != 0) return p;
        final ma = mesas[a.mesaId]?.numero ?? 999, mb = mesas[b.mesaId]?.numero ?? 999;
        return ma != mb ? ma.compareTo(mb) : a.orden.compareTo(b.orden);
      });
    Widget tarjeta(Tanda t) {
      final info = infoTanda(t.estado);
      final tms = ref.watch(muestrasDeTandaProvider(t.id));
      final hechas = tms.where((x) => x.estado == 'completada').length;
      final activa = tms.where((x) => x.estado == 'activa').firstOrNull;
      final muestrasIdx = ref.watch(muestraPorIdProvider);
      final codigo = activa == null ? null : muestrasIdx[activa.muestraId]?.codigo;
      return Card(
        color: t.estado == 'abierta' ? Paleta.amarilloPastel : null,
        child: InkWell(
          onTap: () => context.go('/puntuar/${t.id}'),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: k ? 14 : 20, vertical: k ? 12 : 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: k ? 26 : 34,
                  backgroundColor: Color.alphaBlend(info.$3.shade400.withValues(alpha: 0.22), Colors.white),
                  child: Icon(info.$2, size: k ? 26 : 34, color: info.$3.shade800),
                ),
                SizedBox(width: k ? 12 : 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        mesas[t.mesaId]?.nombre ?? 'Sin mesa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: k ? 18 : 22,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: k ? 2 : 4),
                      Text(
                        t.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: k ? 16 : 19,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: k ? 2 : 4),
                      Text(
                        [info.$1, '$hechas/${tms.length} muestras', if (codigo != null) 'Activa $codigo'].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: k ? 14 : 17,
                          fontWeight: FontWeight.w800,
                          color: codigo != null ? Paleta.azulOscuro : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (tms.isNotEmpty) ...[
                        SizedBox(height: k ? 6 : 8),
                        LinearProgressIndicator(
                          value: hechas / tms.length,
                          minHeight: k ? 7 : 10,
                          color: info.$3,
                          backgroundColor: info.$3.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: k ? 28 : 34),
              ],
            ),
          ),
        ),
      );
    }

    final problema = avisoCarga(
      ref,
      que: 'Cargar puntuaciones (tandas del día)',
      tablas: const ['tandas', 'tanda_muestras', 'mesas', 'muestras', 'puntuaciones'],
      vacio: l.isEmpty,
      queHacerSiVacio:
          'No hay tandas para el día del chip. Cambia el día o elige «Todos los días». '
          'Si el panel Diagnóstico muestra tandas:0, Cloud no está devolviendo la tabla.',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Puntuaciones'), actions: const [ChipDia(), ChipEntorno()]),
      body:
          problema ??
          Ancho(
            max: 900,
            child: ListaLlena(
              itemCount: l.length,
              gap: k ? 8 : 12,
              padding: EdgeInsets.all(k ? 10 : 14),
              altoMinimo: k ? 110 : 130,
              itemBuilder: (c, i) => tarjeta(l[i]),
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
        appBar: AppBar(),
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
          final wCod = k ? 66.0 : 110.0;
          final wTot = k ? 52.0 : 80.0;
          // 16 de márgenes + 2 del borde de cada fila.
          final wCel = ((anchoMax - 18 - wCod - wTot) / cs.length).clamp(40.0, 150.0);
          final alto = k ? 46.0 : 60.0;
          final fNota = k ? 17.0 : 21.0;

          Widget cabecera() => Row(
            children: [
              SizedBox(
                width: wCod,
                child: Text(
                  'Muestra',
                  style: TextStyle(fontSize: k ? 12 : 14, color: scheme.onSurfaceVariant),
                ),
              ),
              for (final c in cs)
                SizedBox(
                  width: wCel,
                  child: Column(
                    children: [
                      Text(
                        'P${c.puesto ?? '-'}',
                        style: TextStyle(fontSize: k ? 14 : 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        c.iniciales,
                        style: TextStyle(fontSize: k ? 10.5 : 13, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: wTot,
                child: Text(
                  'Total',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: k ? 13 : 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );

          Widget fila(TandaMuestra tm) {
            final m = muestras[tm.muestraId];
            final info = infoTM(tm.estado);
            final notas = [for (final c in cs) idx['${tm.muestraId}|${c.id}']];
            final vals = notas.map((n) => n?.total).whereType<double>().toList();
            final media = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
            final activa = tm.estado == 'activa';
            return Container(
              height: alto,
              margin: const EdgeInsets.only(bottom: 4),
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
                          const SizedBox(width: 4),
                          Icon(info.$2, size: k ? 14 : 18, color: info.$3.shade700),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              m?.codigo ?? '?',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(fontSize: k ? 15 : 19, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  for (var j = 0; j < cs.length; j++)
                    _Celda(
                      ancho: wCel,
                      alto: alto - 8,
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
                      style: TextStyle(fontSize: k ? 16 : 20, fontWeight: FontWeight.w900, color: Paleta.azulOscuro),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'activar':
        await ejecutar(context, () => repo.activarMuestra(tm.id), ok: '${m?.codigo} activa');
      case 'aprobar':
        if (await confirmar(context, '¿Aprobar las notas de ${m?.codigo}?', si: 'Aprobar') && context.mounted) {
          await ejecutar(context, () => repo.aprobarMuestra(tm.id), ok: '${m?.codigo} aprobada');
        }
      case 'incidencia':
        await nuevaIncidencia(context, ref, tm: tm);
      case 'resolver':
        await resolverIncidencia(context, ref, tm);
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
    return SizedBox(
      width: ancho,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: nota == null ? Theme.of(context).colorScheme.surfaceContainer : (c ?? Colors.blue).shade100,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: alto,
              child: Center(
                child: Text(
                  _fmt(nota?.total),
                  style: TextStyle(
                    fontSize: fuente,
                    fontWeight: FontWeight.w800,
                    color: c?.shade900 ?? Theme.of(context).colorScheme.onSurface,
                    fontStyle: nota?.manual == true ? FontStyle.italic : null,
                  ),
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
  await ejecutar(context, () async {
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
  }, accion: forzar ? 'Forzar nota $codigo' : 'Editar nota $codigo');
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
