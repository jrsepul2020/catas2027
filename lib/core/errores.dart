import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ui/theme.dart';
import 'providers.dart';

/// Error ya traducido para el admin: título corto, pista accionable y detalle técnico.
class ErrorInterpretado {
  const ErrorInterpretado({
    required this.titulo,
    required this.pista,
    required this.tecnico,
    this.codigo,
    this.sePuedeForzar = false,
  });
  final String titulo;
  final String pista;
  final String tecnico;
  final String? codigo;

  /// Si true, la UI puede ofrecer reintentar con privilegio de admin (p. ej. reabrir nota).
  final bool sePuedeForzar;
}

/// Entrada persistida del log local de la app.
class EntradaError {
  EntradaError({
    required this.cuando,
    required this.titulo,
    required this.pista,
    required this.tecnico,
    this.codigo,
    this.accion,
    this.entorno,
  });

  final DateTime cuando;
  final String titulo;
  final String pista;
  final String tecnico;
  final String? codigo;
  final String? accion;
  final String? entorno;

  Map<String, dynamic> toJson() => {
    'cuando': cuando.toIso8601String(),
    'titulo': titulo,
    'pista': pista,
    'tecnico': tecnico,
    'codigo': ?codigo,
    'accion': ?accion,
    'entorno': ?entorno,
  };

  factory EntradaError.fromJson(Map<String, dynamic> j) => EntradaError(
    cuando: DateTime.tryParse('${j['cuando']}') ?? DateTime.now(),
    titulo: '${j['titulo'] ?? 'Error'}',
    pista: '${j['pista'] ?? ''}',
    tecnico: '${j['tecnico'] ?? ''}',
    codigo: j['codigo']?.toString(),
    accion: j['accion']?.toString(),
    entorno: j['entorno']?.toString(),
  );

  String get textoCompleto {
    final buf = StringBuffer()
      ..writeln(cuando.toIso8601String())
      ..writeln(titulo);
    if (codigo != null) buf.writeln('Código: $codigo');
    if (accion != null) buf.writeln('Acción: $accion');
    if (entorno != null) buf.writeln('Entorno: $entorno');
    buf
      ..writeln(pista)
      ..writeln('---')
      ..writeln(tecnico);
    return buf.toString();
  }
}

/// Interpreta excepciones de PostgREST/Postgres/Dart a mensajes útiles en español.
ErrorInterpretado interpretarError(Object e) {
  final tecnico = e is PostgrestException
      ? 'PostgrestException(message: ${e.message}, code: ${e.code}, details: ${e.details}, hint: ${e.hint})'
      : '$e';
  final msg = e is PostgrestException ? e.message : '$e';
  final code = e is PostgrestException ? e.code : null;
  final bajo = msg.toLowerCase();

  if (msg.contains('MUESTRA_APROBADA') || bajo.contains('ya fue aprobada')) {
    return ErrorInterpretado(
      titulo: 'Muestra ya aprobada',
      pista:
          'Las notas de esta muestra están cerradas (aprobadas). '
          'Como admin puedes forzar el cambio: se reabre la muestra y la nota pasa a «enviada».',
      tecnico: tecnico,
      codigo: code ?? 'MUESTRA_APROBADA',
      sePuedeForzar: true,
    );
  }
  if (code == '23505' || bajo.contains('duplicate key') || bajo.contains('unique constraint')) {
    if (bajo.contains('uq_asignaciones_dia_mesa_puesto') || bajo.contains('asignaciones')) {
      return ErrorInterpretado(
        titulo: 'Puesto ya ocupado ese día',
        pista:
            'En CLOUD cada mesa+puesto del día solo puede tener un catador. '
            'Si movías a alguien, el destino ya tenía persona (o el intercambio falló a mitad). '
            'Vuelve a intentar: el intercambio ahora libera el puesto antes de ocupar el otro.',
        tecnico: tecnico,
        codigo: code ?? '23505',
      );
    }
    if (bajo.contains('catador') || bajo.contains('uq_asignaciones_dia_catador')) {
      return ErrorInterpretado(
        titulo: 'Catador ya asignado ese día',
        pista: 'Ese catador ya tiene mesa/puesto en el día activo. Muévelo o intercámbialo, no lo asignes de nuevo.',
        tecnico: tecnico,
        codigo: code ?? '23505',
      );
    }
    return ErrorInterpretado(
      titulo: 'Dato duplicado',
      pista:
          'La base rechazó el cambio porque ya existe una fila con la misma clave única. '
          'Revisa que no estés creando algo que ya está (código, puesto, nota…).',
      tecnico: tecnico,
      codigo: code ?? '23505',
    );
  }
  if (code == '23503' || bajo.contains('foreign key')) {
    return ErrorInterpretado(
      titulo: 'Falta un dato relacionado',
      pista:
          'Estás enlazando algo que no existe (mesa, día, muestra, catador…). '
          'Comprueba el día activo y que el elemento destino esté cargado.',
      tecnico: tecnico,
      codigo: code ?? '23503',
    );
  }
  if (code == '42501' || bajo.contains('permission denied') || bajo.contains('row-level security')) {
    return ErrorInterpretado(
      titulo: 'Sin permiso',
      pista:
          'Hace falta sesión de gestión (authenticated). Si omitiste el login: ve a Login, entra una vez '
          'y marca «Guardar contraseña» — en pruebas se reutilizará sola. '
          'Sin sesión solo hay lectura (rol anónimo, como las tablets).',
      tecnico: tecnico,
      codigo: code ?? '42501',
    );
  }
  if (bajo.contains('jwt') || bajo.contains('not authenticated') || code == 'PGRST301') {
    return ErrorInterpretado(
      titulo: 'Sesión caducada',
      pista: 'Vuelve a iniciar sesión en Configuración / Login. El token ya no es válido.',
      tecnico: tecnico,
      codigo: code,
    );
  }
  if (bajo.contains('elige un día') || bajo.contains('sin asignación') || e is StateError) {
    return ErrorInterpretado(titulo: 'Falta contexto', pista: msg, tecnico: tecnico, codigo: 'STATE');
  }
  if (bajo.contains('failed host lookup') || bajo.contains('socket') || bajo.contains('timed out')) {
    return ErrorInterpretado(
      titulo: 'Sin conexión al servidor',
      pista: 'No se alcanza Supabase (URL, WiFi o servidor LOCAL apagado). Revisa Conexiones y Prueba.',
      tecnico: tecnico,
      codigo: code,
    );
  }

  // Prefijos propios de RPCs Virtus (CODIGO: mensaje).
  final m = RegExp(r'^([A-Z][A-Z0-9_]+):\s*(.+)$').firstMatch(msg);
  if (m != null) {
    return ErrorInterpretado(
      titulo: m.group(1)!.replaceAll('_', ' '),
      pista: m.group(2)!,
      tecnico: tecnico,
      codigo: m.group(1),
    );
  }

  return ErrorInterpretado(
    titulo: 'No se pudo completar la acción',
    pista: 'Guarda o copia el detalle técnico y revísalo en Configuración → Log de errores.',
    tecnico: tecnico,
    codigo: code,
  );
}

extension on ErrorInterpretado {
  ErrorInterpretado copyConTecnico(String t) =>
      ErrorInterpretado(titulo: titulo, pista: pista, tecnico: t, codigo: codigo, sePuedeForzar: sePuedeForzar);
}

/// Log local (SharedPreferences). El admin puede copiarlo para estudiarlo.
class LogErrores extends Notifier<List<EntradaError>> {
  static const _clave = 'log_errores_app';
  static const _max = 80;

  @override
  List<EntradaError> build() {
    final raw = ref.read(prefsProvider).getStringList(_clave) ?? const [];
    final out = <EntradaError>[];
    for (final s in raw) {
      try {
        out.add(EntradaError.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> registrar(EntradaError e) async {
    final nuevo = [e, ...state].take(_max).toList();
    state = nuevo;
    await ref.read(prefsProvider).setStringList(_clave, [for (final x in nuevo) jsonEncode(x.toJson())]);
    debugPrint('ERROR_APP ${e.titulo} | ${e.codigo} | ${e.tecnico}');
  }

  Future<void> vaciar() async {
    state = const [];
    await ref.read(prefsProvider).remove(_clave);
  }

  String exportar() => state.map((e) => e.textoCompleto).join('\n\n========\n\n');
}

final logErroresProvider = NotifierProvider<LogErrores, List<EntradaError>>(LogErrores.new);

/// Registra el error y muestra un modal con pistas (no solo un SnackBar críptico).
Future<void> registrarYMostrarError(BuildContext context, Object error, {StackTrace? stack, String? accion}) async {
  final interp = interpretarError(error);
  final tecnico = stack == null ? interp.tecnico : '${interp.tecnico}\n$stack';
  String? entorno;
  try {
    final cont = ProviderScope.containerOf(context, listen: false);
    entorno = cont.read(entornoProvider).corto;
    await cont
        .read(logErroresProvider.notifier)
        .registrar(
          EntradaError(
            cuando: DateTime.now(),
            titulo: interp.titulo,
            pista: interp.pista,
            tecnico: tecnico,
            codigo: interp.codigo,
            accion: accion,
            entorno: entorno,
          ),
        );
    // Auditoría en servidor (mejor esfuerzo; no debe tapar el error original).
    try {
      final repo = cont.read(repoProvider);
      await repo?.registrar(
        'error_ui',
        motivo: '${interp.titulo}${accion == null ? '' : ' · $accion'}: ${interp.pista}',
        registroId: interp.codigo,
      );
    } catch (_) {}
  } catch (_) {
    debugPrint('ERROR_APP (sin provider) $tecnico');
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => _DialogoError(interp: interp.copyConTecnico(tecnico), accion: accion, entorno: entorno),
  );
}

class _DialogoError extends StatelessWidget {
  const _DialogoError({required this.interp, this.accion, this.entorno});
  final ErrorInterpretado interp;
  final String? accion;
  final String? entorno;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final k = MediaQuery.sizeOf(context).shortestSide < 600;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: cs.error, size: k ? 26 : 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              interp.titulo,
              style: TextStyle(fontSize: k ? 18 : 20, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                interp.pista,
                style: TextStyle(fontSize: k ? 15 : 16, height: 1.35, color: cs.onSurface),
              ),
              if (accion != null) ...[
                const SizedBox(height: 10),
                Text('Acción: $accion', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
              if (entorno != null || interp.codigo != null) ...[
                const SizedBox(height: 4),
                Text(
                  [?entorno, if (interp.codigo != null) 'código ${interp.codigo}'].join(' · '),
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Paleta.rojoPastel.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  interp.tecnico,
                  style: TextStyle(fontSize: k ? 11.5 : 12.5, fontFamily: 'monospace', color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Queda guardado en Configuración → Log de errores.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(
                text: [
                  interp.titulo,
                  if (interp.codigo != null) 'Código: ${interp.codigo}',
                  if (accion != null) 'Acción: $accion',
                  if (entorno != null) 'Entorno: $entorno',
                  interp.pista,
                  '---',
                  interp.tecnico,
                ].join('\n'),
              ),
            );
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Detalle copiado')));
          },
          child: const Text('Copiar'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
      ],
    );
  }
}

/// Hoja con el historial local de errores (copiar / vaciar).
Future<void> mostrarLogErrores(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) {
      final k = MediaQuery.sizeOf(c).shortestSide < 600;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) {
          final lista = ref.watch(logErroresProvider);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log de errores (${lista.length})',
                        style: TextStyle(fontSize: k ? 18 : 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copiar todo',
                      onPressed: lista.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: ref.read(logErroresProvider.notifier).exportar()));
                              ScaffoldMessenger.maybeOf(context)
                                  ?.showSnackBar(const SnackBar(content: Text('Log copiado')));
                            },
                      icon: const Icon(Icons.copy_all),
                    ),
                    IconButton(
                      tooltip: 'Vaciar',
                      onPressed: lista.isEmpty
                          ? null
                          : () async {
                              await ref.read(logErroresProvider.notifier).vaciar();
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('Sin errores registrados en este dispositivo'))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: lista.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = lista[i];
                          return Card(
                            child: ListTile(
                              title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                '${e.cuando.toLocal()}\n${e.pista}',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: e.textoCompleto));
                                },
                              ),
                              onTap: () => showDialog<void>(
                                context: c,
                                builder: (d) => AlertDialog(
                                  title: Text(e.titulo),
                                  content: SingleChildScrollView(child: SelectableText(e.textoCompleto)),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: e.textoCompleto));
                                        Navigator.pop(d);
                                      },
                                      child: const Text('Copiar'),
                                    ),
                                    FilledButton(onPressed: () => Navigator.pop(d), child: const Text('Cerrar')),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
