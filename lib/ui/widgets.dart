import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backend.dart';
import '../core/providers.dart';

bool esAncho(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

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
    return Card(
      color: Color.alphaBlend(c.withValues(alpha: 0.14), cs.surface),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icono, size: 52, color: c),
                  const Spacer(),
                  Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
              if ((badge ?? 0) > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Badge(
                    largeSize: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    label: Text('$badge', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
    final color = cloud ? Colors.blue.shade700 : Colors.teal.shade700;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(cloud ? Icons.cloud : Icons.dns, color: Colors.white, size: 22),
        label: Text(
          e.corto,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        backgroundColor: color,
        side: BorderSide.none,
        onPressed: () async {
          final ok = await confirmar(
            context,
            'Cambiar a ${e.otro.largo}',
            texto: 'Trabajarás con los datos de ${e.otro.corto}. Puede pedirte iniciar sesión.',
            si: 'Cambiar',
          );
          if (ok) ref.read(entornoProvider.notifier).cambiar(e.otro);
        },
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
          Icon(icono, size: 96, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
          if (accion != null) ...[const SizedBox(height: 24), accion!],
        ],
      ),
    ),
  );
}

/// Contenedor centrado con ancho máximo: en ordenador no se estira.
class Ancho extends StatelessWidget {
  const Ancho({super.key, required this.child, this.max = 1100});
  final Widget child;
  final double max;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max),
      child: child,
    ),
  );
}

// ------------------- etiquetas y colores de dominio -------------------
const estadosMesa = {
  'preparada': ('Preparada', Icons.event_seat, Colors.blueGrey),
  'catando': ('Catando', Icons.wine_bar, Colors.green),
  'pausa': ('Pausa', Icons.pause_circle, Colors.orange),
  'finalizada': ('Finalizada', Icons.check_circle, Colors.indigo),
};

const estadosTanda = {
  'pendiente': ('Pendiente', Icons.schedule, Colors.blueGrey),
  'en_curso': ('En curso', Icons.play_circle_fill, Colors.green),
  'cerrada': ('Cerrada', Icons.lock, Colors.indigo),
};

const medallas = {
  'gran_oro': ('Gran Oro', Color(0xFFB8860B)),
  'oro': ('Oro', Color(0xFFE0B000)),
  'plata': ('Plata', Color(0xFF9AA4AE)),
  'bronce': ('Bronce', Color(0xFFB0703C)),
  'sin_medalla': ('Sin medalla', Color(0xFF8C8C8C)),
};

const tiposIncidencia = {
  'corcho': ('Corcho', Icons.wine_bar),
  'temperatura': ('Temperatura', Icons.thermostat),
  'muestra_defectuosa': ('Muestra defectuosa', Icons.report_problem),
  'botella_rota': ('Botella rota', Icons.broken_image),
  'catador_ausente': ('Catador ausente', Icons.person_off),
  'cambio_puesto': ('Cambio de puesto', Icons.swap_horiz),
  'cambio_orden': ('Cambio de orden', Icons.swap_vert),
  'error_puntuacion': ('Error puntuación', Icons.edit_note),
  'otro': ('Otro', Icons.more_horiz),
};

class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.info, {super.key});
  final (String, IconData, MaterialColor) info;
  @override
  Widget build(BuildContext context) {
    final (t, i, c) = info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 20, color: c.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              t,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, color: c.shade800, fontSize: 15),
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
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            ...campos,
            const SizedBox(height: 8),
            Row(
              children: [
                if (borrar != null) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
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
    ),
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
    builder: (c, sc) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: ListView.builder(
            controller: sc,
            itemCount: opciones.length,
            itemBuilder: (c, i) {
              final o = opciones[i];
              final s = sub?.call(o);
              return ListTile(
                leading: leading?.call(o),
                title: Text(texto(o)),
                subtitle: s == null ? null : Text(s),
                onTap: () => Navigator.pop(c, o),
              );
            },
          ),
        ),
      ],
    ),
  ),
);
