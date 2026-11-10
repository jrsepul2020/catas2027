import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../data/auditoria.dart';
import 'iconos.dart';
import 'theme.dart';
import 'widgets.dart';

/// Formatea `yyyy-mm-dd` → `24 abr 2027`.
String fechaCortaEs(String iso) {
  final p = iso.split('-');
  if (p.length < 3) return iso;
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final y = p[0], m = int.tryParse(p[1]) ?? 0, d = int.tryParse(p[2]) ?? 0;
  if (m < 1 || m > 12 || d < 1) return iso;
  return '$d ${meses[m - 1]} $y';
}

/// Último resultado de auditoría (para el tile de Inicio). Solo presentación.
class UltimaAuditoria extends Notifier<ResultadoAuditoria?> {
  @override
  ResultadoAuditoria? build() => null;
  void guardar(ResultadoAuditoria? r) => state = r;
}

final ultimaAuditoriaProvider = NotifierProvider<UltimaAuditoria, ResultadoAuditoria?>(UltimaAuditoria.new);

/// Franja ámbar fina de modo pruebas.
class FranjaModoPruebas extends ConsumerWidget {
  const FranjaModoPruebas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(modoPruebasProvider)) return const SizedBox.shrink();
    return Material(
      color: Virtus.advertenciaSuave,
      child: InkWell(
        onTap: () => context.push('/configuracion'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Iconos.laboratorio, size: VirtusIcono.chip + 4, color: Virtus.advertencia),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modo pruebas · herramientas en Ajustes',
                  style: VirtusTexto.tenue(size: 12, color: Virtus.advertencia),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera de lista en LOCAL: día cargado + contador.
class CabeceraDiaLocal extends StatelessWidget {
  const CabeceraDiaLocal({super.key, required this.fechaIso, required this.detalle});
  final String? fechaIso;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final fecha = (fechaIso == null || fechaIso!.isEmpty) ? 'sin fecha' : fechaCortaEs(fechaIso!);
    return Padding(
      padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 12, k ? 12 : 16, k ? 6 : 8),
      child: Row(
        children: [
          Expanded(
            child: Text('Día cargado · $fecha', style: VirtusTexto.tenue(size: k ? 13 : 14)),
          ),
          Text(detalle, style: VirtusTexto.tenue(size: k ? 13 : 14)),
        ],
      ),
    );
  }
}

/// Tile de resumen 2×2 (número grande + etiqueta corta).
class TileResumen extends StatelessWidget {
  const TileResumen({super.key, required this.etiqueta, required this.valor, this.alerta = false});

  final String etiqueta;
  final String valor;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: EdgeInsets.symmetric(horizontal: k ? 12 : 14, vertical: k ? 10 : 12),
      decoration: BoxDecoration(
        color: Virtus.superficie,
        borderRadius: BorderRadius.circular(Virtus.radio),
        border: Border.all(color: alerta ? Virtus.error.withValues(alpha: 0.45) : Virtus.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VirtusTexto.tenue(size: k ? 12 : 13),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VirtusTexto.numero(size: k ? 26 : 30, color: alerta ? Virtus.error : Virtus.texto),
          ),
        ],
      ),
    );
  }
}

/// Tile de acción de gestión rápida (rejilla 3×3).
class TileAccion extends StatelessWidget {
  const TileAccion({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.destacado = false,
    this.subtituloVerde = false,
    this.alerta = false,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final bool destacado;
  final bool subtituloVerde;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final fondo = destacado ? Virtus.marca : Virtus.superficie;
    final borde = destacado
        ? Virtus.marca
        : alerta
        ? Virtus.error.withValues(alpha: 0.4)
        : Virtus.borde;
    final ink = destacado ? Colors.white : Virtus.marca;
    final texto = destacado ? Colors.white : Virtus.texto;
    final sub = destacado
        ? Colors.white.withValues(alpha: 0.85)
        : subtituloVerde
        ? Virtus.enMarcha
        : alerta
        ? Virtus.error
        : Virtus.textoSecundario;

    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(Virtus.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Virtus.radio),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Virtus.radio),
            border: Border.all(color: borde),
          ),
          padding: EdgeInsets.symmetric(horizontal: k ? 8 : 10, vertical: k ? 10 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: VirtusIcono.baldosa, color: ink),
              SizedBox(height: k ? 6 : 8),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: VirtusTexto.titulo(size: k ? 12 : 13, color: texto),
              ),
              const SizedBox(height: 2),
              Text(
                subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: VirtusTexto.tenue(size: k ? 11 : 12, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de tanda (lista LOCAL / Directo): mesa | muestra activa | progreso.
class TarjetaTandaVista extends StatelessWidget {
  const TarjetaTandaVista({
    super.key,
    required this.numeroMesa,
    required this.numeroTanda,
    required this.categoria,
    required this.codigoActiva,
    required this.hechas,
    required this.total,
    required this.onTap,
    this.conIncidencia = false,
    this.cerrada = false,
  });

  final int? numeroMesa;
  final int numeroTanda;
  final String? categoria;
  final String? codigoActiva;
  final int hechas;
  final int total;
  final VoidCallback onTap;
  final bool conIncidencia;
  final bool cerrada;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final progreso = total <= 0 ? 0.0 : (hechas / total).clamp(0.0, 1.0);
    final mesaTxt = numeroMesa?.toString() ?? '—';
    final meta = ['Tanda $numeroTanda', if (categoria != null && categoria!.isNotEmpty) categoria!].join(' · ');

    return Material(
      color: Virtus.superficie,
      borderRadius: BorderRadius.circular(Virtus.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Virtus.radio),
        child: Container(
          constraints: BoxConstraints(minHeight: k ? 120 : 128),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Virtus.radio),
            border: Border.all(color: Virtus.borde),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: k ? 72 : 84,
                  color: Virtus.marca,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MESA',
                        style: VirtusTexto.tenue(size: k ? 10 : 11, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          mesaTxt,
                          style: VirtusTexto.numero(size: k ? 44 : 52, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(k ? 12 : 14, k ? 10 : 12, k ? 12 : 14, k ? 10 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: VirtusTexto.tenue(size: 13),
                              ),
                            ),
                            if (conIncidencia)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Virtus.advertenciaSuave,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Virtus.advertencia.withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Iconos.incidencias, size: VirtusIcono.chip, color: Virtus.advertencia),
                                    const SizedBox(width: 4),
                                    Text('Incidencia', style: VirtusTexto.titulo(size: 11, color: Virtus.advertencia)),
                                  ],
                                ),
                              )
                            else if (cerrada)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Virtus.neutroSuave,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Virtus.borde),
                                ),
                                child: Text(
                                  'Cerrada',
                                  style: VirtusTexto.titulo(size: 11, color: Virtus.textoSecundario),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text('MUESTRA ACTIVA', style: VirtusTexto.tenue(size: k ? 10 : 11)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                codigoActiva == null || codigoActiva!.isEmpty ? 'Sin muestra activa' : codigoActiva!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: codigoActiva == null || codigoActiva!.isEmpty
                                    ? VirtusTexto.titulo(size: k ? 16 : 18, color: Virtus.textoSecundario)
                                    : VirtusTexto.numero(size: k ? 30 : 34, color: Virtus.enMarcha),
                              ),
                            ),
                            Text('$hechas/$total', style: VirtusTexto.numero(size: k ? 20 : 22)),
                          ],
                        ),
                        SizedBox(height: k ? 8 : 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progreso,
                            minHeight: k ? 8 : 10,
                            color: Virtus.marca,
                            backgroundColor: const Color(0xFFEDE7E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de progreso del día.
class BarraProgresoDia extends StatelessWidget {
  const BarraProgresoDia({super.key, required this.hechas, required this.total});
  final int hechas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final pct = total <= 0 ? 0 : ((hechas / total) * 100).round();
    final valor = total <= 0 ? 0.0 : (hechas / total).clamp(0.0, 1.0);
    return Container(
      padding: EdgeInsets.all(k ? 12 : 14),
      decoration: BoxDecoration(
        color: Virtus.superficie,
        borderRadius: BorderRadius.circular(Virtus.radio),
        border: Border.all(color: Virtus.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Progreso del día', style: VirtusTexto.titulo(size: k ? 14 : 15)),
              ),
              Text(
                '$pct %',
                style: VirtusTexto.numero(size: k ? 22 : 26, color: Virtus.marca),
              ),
            ],
          ),
          SizedBox(height: k ? 8 : 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: valor,
              minHeight: k ? 8 : 10,
              color: Virtus.marca,
              backgroundColor: const Color(0xFFEDE7E1),
            ),
          ),
          SizedBox(height: k ? 6 : 8),
          Text(
            total == 0 ? 'Sin muestras en el día' : '$hechas de $total muestras catadas',
            style: VirtusTexto.tenue(size: k ? 12 : 13),
          ),
        ],
      ),
    );
  }
}
