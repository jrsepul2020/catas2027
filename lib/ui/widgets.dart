import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/backend.dart';
import '../core/providers.dart';
import 'theme.dart';

bool esAncho(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

/// Teléfono (Redmi Note 12 Pro: ~393×873 lógicos). La tablet de 11" no es compacta.
bool esCompacto(BuildContext c) => MediaQuery.sizeOf(c).shortestSide < 600;

void aviso(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 17)),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      duration: Duration(seconds: error ? 5 : 2),
    ),
  );
}

/// Cierra la sesión del entorno activo y vuelve al login.
Future<void> cerrarSesion(BuildContext context, WidgetRef ref) async {
  final e = ref.read(entornoProvider);
  final ok = await confirmar(
    context,
    '¿Cerrar sesión?',
    texto: 'Saldrás de ${e.largo}. Las conexiones URL/clave se quedan en este dispositivo.',
    si: 'Cerrar sesión',
  );
  if (!ok || !context.mounted) return;
  await ejecutar(context, () async {
    final c = await ref.read(clienteProvider.future);
    await c?.auth.signOut();
  });
  if (context.mounted) context.go('/login');
}

/// Ejecuta una acción mostrando el error si falla. Devuelve true si fue bien.
Future<bool> ejecutar(BuildContext context, Future<void> Function() f, {String? ok}) async {
  HapticFeedback.selectionClick();
  try {
    await f();
    if (ok != null && context.mounted) aviso(context, ok);
    return true;
  } catch (e) {
    if (context.mounted) aviso(context, 'Error: $e', error: true);
    return false;
  }
}

Future<bool> confirmar(BuildContext context, String titulo, {String? texto, String si = 'Sí'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: texto == null ? null : Text(texto, style: const TextStyle(fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(si)),
      ],
    ),
  );
  return r ?? false;
}

/// Baldosa gigante para el panel principal.
class Baldosa extends StatelessWidget {
  const Baldosa({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.color,
    this.badge,
    this.sub,
  });
  final IconData icono;
  final String texto;
  final String? sub;
  final VoidCallback onTap;
  final Color? color;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    final k = esCompacto(context);
    return Card(
      color: Color.alphaBlend(c.withValues(alpha: 0.13), Colors.white),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(k ? 10 : 16),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: k ? 30 : 52, color: c),
                  const Spacer(),
                  Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: k ? 16 : 22, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      maxLines: k ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: k ? 11.5 : 15, height: 1.15, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              if ((badge ?? 0) > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Badge(
                    largeSize: k ? 24 : 34,
                    backgroundColor: cs.error,
                    padding: EdgeInsets.symmetric(horizontal: k ? 7 : 10),
                    label: Text(
                      '$badge',
                      style: TextStyle(fontSize: k ? 14 : 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador del entorno activo (CLOUD / LOCAL). Pulsar para cambiar.
class ChipEntorno extends ConsumerWidget {
  const ChipEntorno({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(entornoProvider);
    final cloud = e == Entorno.cloud;
    final color = cloud ? Colors.blue.shade700 : Colors.deepPurple.shade500;
    Future<void> cambiar() async {
      final ok = await confirmar(
        context,
        'Cambiar a ${e.otro.largo}',
        texto: 'Trabajarás con los datos de ${e.otro.corto}. Puede pedirte iniciar sesión.',
        si: 'Cambiar',
      );
      if (ok) ref.read(entornoProvider.notifier).cambiar(e.otro);
    }

    Future<void> toggleDiagnostico() async {
      final nuevo = !ref.read(modoPruebasProvider);
      await ref.read(verDiagnosticoProvider.notifier).set(nuevo);
      if (context.mounted) {
        aviso(context, nuevo ? 'Diagnóstico de datos: visible' : 'Diagnóstico de datos: oculto');
      }
    }

    if (esCompacto(context)) {
      // En teléfono solo el icono coloreado: deja sitio al título.
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: '${e.largo} · mantén pulsado: diagnóstico',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: cambiar,
            onLongPress: toggleDiagnostico,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: color,
              child: Icon(cloud ? Icons.cloud : Icons.dns, color: Colors.white, size: 19),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onLongPress: toggleDiagnostico,
        child: Material(
          color: color,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: cambiar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cloud ? Icons.cloud : Icons.dns, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    e.corto,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "En directo" para las barras de título.
class BotonDirecto extends StatelessWidget {
  const BotonDirecto({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'En directo',
    onPressed: () => GoRouter.of(context).go('/directo'),
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.live_tv, color: Theme.of(context).colorScheme.secondary),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Día de concurso con el que se trabaja (filtra tandas). Pulsar para cambiar.
class ChipDia extends ConsumerWidget {
  const ChipDia({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dias = ref.watch(diasProvider);
    // En LOCAL solo existe el día sincronizado: no hay selector.
    if (dias.isEmpty || ref.watch(esLocalProvider)) return const SizedBox.shrink();
    final sel = ref.watch(diaIdProvider);
    final d = dias.where((x) => x.id == sel).firstOrNull;
    final k = esCompacto(context);
    final etiqueta = d == null ? 'Todos' : (k ? 'D${dias.indexOf(d) + 1}' : d.nombre);
    return Padding(
      padding: EdgeInsets.only(right: k ? 2 : 6),
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.45))),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () async {
            final r = await showModalBottomSheet<int>(
              context: context,
              showDragHandle: true,
              constraints: const BoxConstraints(maxWidth: 720),
              builder: (s) {
                final cs = Theme.of(s).colorScheme;
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Día de trabajo',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
                      ),
                      for (final x in dias)
                        AccionHoja(
                          icono: x.id == sel ? Icons.radio_button_checked : Icons.radio_button_off,
                          titulo: x.nombre,
                          subtitulo: x.fecha,
                          onTap: () => Navigator.pop(s, x.id),
                        ),
                      AccionHoja(
                        icono: sel == null ? Icons.radio_button_checked : Icons.radio_button_off,
                        titulo: 'Todos los días',
                        onTap: () => Navigator.pop(s, -1),
                      ),
                    ],
                  ),
                );
              },
            );
            if (r != null) ref.read(diaGuardadoProvider.notifier).set(r);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: k ? 10 : 14, vertical: k ? 6 : 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, size: k ? 18 : 22, color: Colors.white),
                SizedBox(width: k ? 4 : 6),
                Text(
                  etiqueta,
                  style: TextStyle(fontSize: k ? 13 : 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.icono, required this.texto, this.accion});
  final IconData icono;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, color: Theme.of(context).colorScheme.onSurface),
          ),
          if (accion != null) ...[const SizedBox(height: 24), accion!],
        ],
      ),
    ),
  );
}

/// Recuadro legible cuando una carga falla o llega vacía (nunca pantalla gris muda).
class RecuadroProblema extends StatelessWidget {
  const RecuadroProblema({
    super.key,
    required this.que,
    this.error,
    required this.queHacer,
    this.icono = Icons.warning_amber_rounded,
  });
  final String que;
  final String? error;
  final String queHacer;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: Paleta.rojoPastel,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(icono, color: Paleta.rojoOscuro, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          que,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Paleta.rojoOscuro),
                        ),
                      ),
                    ],
                  ),
                  if (error != null && error!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Error',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      error!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Paleta.texto),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Qué hacer',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    queHacer,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Paleta.texto),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Si hay error en alguna [tablas] o [vacio], devuelve el recuadro; si no, null.
Widget? avisoCarga(
  WidgetRef ref, {
  required String que,
  required List<String> tablas,
  bool vacio = false,
  required String queHacerSiVacio,
  String queHacerSiError =
      'Revisa la conexión CLOUD/LOCAL, que la sesión siga abierta y pulsa de nuevo la pantalla. '
      'Si el error menciona una columna, el esquema Local puede estar desfasado: vuelve a aplicar el SQL completo.',
}) {
  final errores = ref.watch(erroresTablasProvider);
  for (final t in tablas) {
    final e = errores[t];
    if (e != null) {
      return RecuadroProblema(que: '$que (tabla $t)', error: e, queHacer: queHacerSiError);
    }
  }
  if (vacio) {
    return RecuadroProblema(que: que, error: null, icono: Icons.inbox_outlined, queHacer: queHacerSiVacio);
  }
  return null;
}

/// Contador de filas recibidas por tabla (solo modo pruebas).
class PanelDiagnostico extends ConsumerWidget {
  const PanelDiagnostico({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(modoPruebasProvider)) return const SizedBox.shrink();
    final conteos = ref.watch(conteoTablasProvider);
    final errores = ref.watch(erroresTablasProvider);
    final dia = ref.watch(diaIdProvider);
    final conc = ref.watch(concursoIdProvider);
    final tandas = ref.watch(tandasProvider).length;
    final texto = [
      'Diagnóstico · concurso=$conc · día=${dia ?? "todos"} · tandasFiltro=$tandas',
      for (final e in conteos.entries) '${e.key}:${e.value}${errores.containsKey(e.key) ? "!" : ""}',
    ].join(' · ');
    return Material(
      color: Paleta.amarilloPastel,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            texto,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Paleta.amarilloOscuro),
          ),
        ),
      ),
    );
  }
}

/// Contenedor centrado con ancho máximo y altura acotada (para listas con Expanded).
class Ancho extends StatelessWidget {
  const Ancho({super.key, required this.child, this.max = 1100});
  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth.clamp(0.0, max) : max;
        // Importante: acotar también la altura. Un SizedBox(width: infinity) sin altura
        // generaba restricciones inválidas y las listas salían con altura 0 (pantalla gris).
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: w, height: c.hasBoundedHeight ? c.maxHeight : null, child: child),
        );
      },
    );
  }
}

/// Lista vertical que reparte la altura entre pocos ítems (sin huecos vacíos).
/// Si hay más de [maxSinScroll], hace scroll con altura mínima por ítem.
class ListaLlena extends StatelessWidget {
  const ListaLlena({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxSinScroll = 8,
    this.gap = 8,
    this.padding = const EdgeInsets.all(10),
    this.altoMinimo = 100,
  });
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int maxSinScroll;
  final double gap;
  final EdgeInsetsGeometry padding;
  final double altoMinimo;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final puedeExpandir = c.hasBoundedHeight && itemCount <= maxSinScroll;
        if (puedeExpandir) {
          return Padding(
            padding: padding,
            child: Column(
              children: [
                for (var i = 0; i < itemCount; i++) ...[
                  if (i > 0) SizedBox(height: gap),
                  Expanded(child: itemBuilder(context, i)),
                ],
              ],
            ),
          );
        }
        return ListView.separated(
          padding: padding,
          itemCount: itemCount,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (ctx, i) => SizedBox(height: altoMinimo, child: itemBuilder(ctx, i)),
        );
      },
    );
  }
}

/// Rejilla que reparte filas/columnas para llenar el espacio disponible.
class RejillaLlena extends StatelessWidget {
  const RejillaLlena({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.columnas,
    this.gap = 8,
    this.padding = const EdgeInsets.all(10),
    this.altoMinimo = 96,
  });
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int columnas;
  final double gap;
  final EdgeInsetsGeometry padding;
  final double altoMinimo;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final pad = padding.resolve(Directionality.of(context));
        final filas = (itemCount / columnas).ceil().clamp(1, 999);
        final altoDisp = box.maxHeight - pad.vertical - gap * (filas - 1);
        final alto = (altoDisp / filas).clamp(altoMinimo, double.infinity);
        final cabe = altoDisp >= altoMinimo * filas && itemCount <= columnas * filas + columnas;
        return GridView.builder(
          padding: padding,
          physics: cabe ? const NeverScrollableScrollPhysics() : null,
          itemCount: itemCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: alto.isFinite ? alto : altoMinimo,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

// ------------------- etiquetas y colores de dominio -------------------
typedef InfoEstado = (String, IconData, MaterialColor);

/// Estado de la mesa, derivado de sus tandas.
const estadosMesa = <String, InfoEstado>{
  'preparada': ('Preparada', Icons.event_seat, Colors.blue),
  'catando': ('Catando', Icons.wine_bar, Colors.amber),
  'finalizada': ('Finalizada', Icons.check_circle, Colors.deepPurple),
};

/// tandas.estado
const estadosTanda = <String, InfoEstado>{
  'pendiente': ('Pendiente', Icons.schedule, Colors.blue),
  'abierta': ('Abierta', Icons.play_circle_fill, Colors.amber),
  'cerrada': ('Cerrada', Icons.lock, Colors.deepPurple),
};
InfoEstado infoTanda(String e) => estadosTanda[e] ?? (e, Icons.help_outline, Colors.grey);

/// tanda_muestras.estado
const estadosTM = <String, InfoEstado>{
  'pendiente': ('Pendiente', Icons.schedule, Colors.blue),
  'activa': ('Activa', Icons.play_circle_fill, Colors.amber),
  'en_curso': ('En curso', Icons.play_circle_fill, Colors.amber),
  'completada': ('Completada', Icons.check_circle, Colors.deepPurple),
  'incidencia': ('Incidencia', Icons.warning_amber_rounded, Colors.red),
  'pospuesta': ('Pospuesta', Icons.update, Colors.deepPurple),
};
InfoEstado infoTM(String e) => estadosTM[e] ?? (e, Icons.help_outline, Colors.grey);

/// puntuaciones.estado
const estadosNota = <String, InfoEstado>{
  'borrador': ('Borrador', Icons.edit, Colors.grey),
  'enviada': ('Enviada', Icons.send, Colors.blue),
  'aprobada': ('Aprobada', Icons.verified, Colors.deepPurple),
};

const medallas = {
  'gran_oro': ('Gran Oro', Color(0xFFB8860B)),
  'oro': ('Oro', Color(0xFFE0B000)),
  'plata': ('Plata', Color(0xFF9AA4AE)),
  'sin_medalla': ('Sin medalla', Color(0xFF8C8C8C)),
};

/// Motivos rápidos de incidencia (se guardan como texto en incidencia_motivo).
const motivosIncidencia = <(String, IconData)>[
  ('Corcho / TCA', Icons.wine_bar),
  ('Temperatura incorrecta', Icons.thermostat),
  ('Muestra defectuosa', Icons.report_problem),
  ('Botella rota', Icons.broken_image),
  ('Error de servicio', Icons.local_drink),
  ('Copa equivocada', Icons.swap_horiz),
  ('Catador ausente', Icons.person_off),
  ('Abierta por error', Icons.undo),
  ('Otro motivo', Icons.more_horiz),
];

/// Acciones del registro de cambios -> (texto, icono)
const accionesCambio = <String, (String, IconData)>{
  'incidencia': ('Incidencia', Icons.warning_amber_rounded),
  'incidencia_resuelta': ('Incidencia cerrada', Icons.check_circle),
  'recatar': ('Recatar', Icons.replay),
  'pasar_al_final': ('Pasada al final', Icons.low_priority),
  'quitar_de_tanda': ('Quitada de la tanda', Icons.remove_circle),
  'cambio_puesto': ('Cambio de puesto', Icons.swap_horiz),
  'cambio_orden_tandas': ('Orden de tandas', Icons.swap_vert),
  'cambio_orden_muestras': ('Orden de muestras', Icons.swap_vert),
  'aprobar_muestra': ('Muestra aprobada', Icons.verified),
  'catador_ausente': ('Catador ausente', Icons.person_off),
  'catador_presente': ('Catador presente', Icons.person),
};

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.info, {super.key});
  final (String, IconData, MaterialColor) info;
  @override
  Widget build(BuildContext context) {
    final (t, i, c) = info;
    final k = esCompacto(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: k ? 7 : 10, vertical: k ? 3 : 6),
      decoration: BoxDecoration(
        color: c.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: k ? 15 : 20, color: c.shade700),
          SizedBox(width: k ? 3 : 6),
          Flexible(
            child: Text(
              t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.shade900, fontSize: k ? 12 : 15),
            ),
          ),
        ],
      ),
    );
  }
}

class Medalla extends StatelessWidget {
  const Medalla(this.clave, {super.key, this.grande = false});
  final String? clave;
  final bool grande;
  @override
  Widget build(BuildContext context) {
    final m = medallas[clave];
    if (m == null) return const SizedBox.shrink();
    final (t, c) = m;
    final s = grande ? 56.0 : 40.0;
    return Tooltip(
      message: t,
      child: CircleAvatar(
        radius: s / 2,
        backgroundColor: c,
        child: Icon(clave == 'sin_medalla' ? Icons.remove : Icons.military_tech, color: Colors.white, size: s * 0.62),
      ),
    );
  }
}

/// Campo de texto grande con etiqueta.
class Campo extends StatelessWidget {
  const Campo(this.ctrl, this.label, {super.key, this.numero = false, this.autofocus = false, this.lineas = 1});
  final TextEditingController ctrl;
  final String label;
  final bool numero;
  final bool autofocus;
  final int lineas;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: ctrl,
      autofocus: autofocus,
      minLines: lineas,
      maxLines: lineas == 1 ? 1 : lineas + 2,
      style: const TextStyle(fontSize: 19),
      keyboardType: numero ? const TextInputType.numberWithOptions(decimal: true) : null,
      textInputAction: lineas == 1 ? TextInputAction.next : TextInputAction.newline,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

/// Acción grande en hojas inferiores (modales de acciones).
class AccionHoja extends StatelessWidget {
  const AccionHoja({super.key, required this.titulo, required this.onTap, this.subtitulo, this.icono, this.color});
  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: k ? 20 : 28, vertical: k ? 10 : 14),
      minVerticalPadding: k ? 12 : 16,
      leading: icono == null ? null : Icon(icono, size: k ? 34 : 40, color: c),
      title: Text(
        titulo,
        style: TextStyle(fontSize: k ? 18 : 21, fontWeight: FontWeight.w800, color: cs.onSurface),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: TextStyle(fontSize: k ? 14 : 16, color: cs.onSurfaceVariant),
            ),
      onTap: onTap,
    );
  }
}

/// Hoja inferior con formulario y botón Guardar gigante.
Future<bool> hojaFormulario(
  BuildContext context, {
  required String titulo,
  required List<Widget> campos,
  required Future<void> Function() guardar,
  Future<void> Function()? borrar,
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (c) {
      final k = esCompacto(c);
      final alto = k ? 56.0 : 68.0;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: k ? 22 : 26,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(c).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              ...campos,
              const SizedBox(height: 12),
              Row(
                children: [
                  if (borrar != null) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(c).colorScheme.error,
                        minimumSize: Size(0, alto),
                        textStyle: TextStyle(fontSize: k ? 16 : 18, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () async {
                        if (await confirmar(c, '¿Eliminar?', si: 'Eliminar') && c.mounted) {
                          if (await ejecutar(c, borrar) && c.mounted) Navigator.pop(c, true);
                        }
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Eliminar'),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: Size(0, alto),
                        textStyle: TextStyle(fontSize: k ? 17 : 20, fontWeight: FontWeight.w800),
                      ),
                      onPressed: () async {
                        if (await ejecutar(c, guardar) && c.mounted) Navigator.pop(c, true);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return r ?? false;
}

/// Selector rápido en hoja inferior: lista de opciones grandes.
Future<T?> elegir<T>(
  BuildContext context, {
  required String titulo,
  required List<T> opciones,
  required String Function(T) texto,
  String? Function(T)? sub,
  Widget Function(T)? leading,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 720),
  builder: (c) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.6,
    maxChildSize: 0.95,
    builder: (c, sc) {
      final k = esCompacto(c);
      final cs = Theme.of(c).colorScheme;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              itemCount: opciones.length,
              itemBuilder: (c, i) {
                final o = opciones[i];
                final s = sub?.call(o);
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: k ? 20 : 28, vertical: k ? 10 : 14),
                  minVerticalPadding: k ? 12 : 16,
                  leading: leading?.call(o),
                  title: Text(
                    texto(o),
                    style: TextStyle(fontSize: k ? 18 : 21, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                  subtitle: s == null
                      ? null
                      : Text(
                          s,
                          style: TextStyle(fontSize: k ? 14 : 16, color: cs.onSurfaceVariant),
                        ),
                  onTap: () => Navigator.pop(c, o),
                );
              },
            ),
          ),
        ],
      );
    },
  ),
);
