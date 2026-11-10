import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/backend.dart';
import '../core/providers.dart';
import '../data/repo.dart';
import 'widgets.dart';

String _msgCorto(Object e) {
  final s = e.toString();
  return s.replaceFirst(RegExp(r'^(Exception|StateError|Bad state):\s*'), '');
}

/// Vacía CLOUD y LOCAL (clave 0000). Solo modo pruebas.
Future<void> borrarTodoDemo(BuildContext context, WidgetRef ref) async {
  final ok = await confirmarConClave(
    context,
    titulo: 'Borrar TODOS los datos',
    texto:
        'Se vaciará el concurso en CLOUD y en LOCAL: mesas, catadores, tandas, '
        'muestras, notas, asignaciones y medallas.\n\n'
        'No se puede deshacer. Escribe la clave 0000 para confirmar.',
    si: 'Borrar todo',
  );
  if (!ok || !context.mounted) return;

  final activo = ref.read(entornoProvider);
  final orden = [activo, activo.otro];
  final avisos = <String>[];
  var vaciados = 0;

  final bien = await ejecutar(
    context,
    () async {
      for (final e in orden) {
        try {
          final cli = await clienteAutenticado(ref, e);
          await Repo(cli, esLocal: e == Entorno.local).demoBorrarTodo();
          avisos.add('${e.corto} vaciado');
          vaciados++;
        } catch (err) {
          avisos.add('${e.corto}: ${_msgCorto(err)}');
        }
      }
      if (vaciados == 0) {
        throw Exception(avisos.join('\n'));
      }
    },
    accion: 'Borrar datos DEMO',
    refrescar: tablasApp,
  );
  if (!context.mounted) return;
  if (bien) {
    aviso(context, avisos.join(' · '), error: vaciados < 2);
  } else if (avisos.isNotEmpty) {
    aviso(context, avisos.join(' · '), error: true);
  }
}

/// Crea día DEMO en CLOUD (clave 0000). Solo modo pruebas.
Future<void> crearDatosDemo(BuildContext context, WidgetRef ref) async {
  final ok = await confirmarConClave(
    context,
    titulo: 'Crear datos DEMO en CLOUD',
    texto:
        'Se creará en CLOUD un día completo:\n'
        '• 5 mesas y 25 catadores (5 presidentes)\n'
        '• 6 tandas de 22 muestras (132 en total)\n\n'
        'CLOUD debe estar vacío (usa «Borrar todo» antes). '
        'Después irás a Sincronizar para bajar el día a LOCAL.\n\n'
        'Escribe la clave 0000 para confirmar.',
    si: 'Crear DEMO',
  );
  if (!ok || !context.mounted) return;

  Map<String, dynamic>? creado;
  final bien = await ejecutar(
    context,
    () async {
      final cloud = await clienteAutenticado(ref, Entorno.cloud);
      creado = await Repo(cloud).demoCrearDiaCompleto();
      await ref.read(entornoProvider.notifier).cambiar(Entorno.cloud);
      final diaId = (creado!['dia_id'] as num?)?.toInt();
      final concursoId = (creado!['concurso_id'] as num?)?.toInt();
      if (diaId != null) ref.read(diaGuardadoProvider.notifier).set(diaId);
      if (concursoId != null) ref.read(concursoGuardadoProvider.notifier).set(concursoId);
    },
    ok: 'DEMO creado en CLOUD',
    accion: 'Crear datos DEMO',
    refrescar: tablasApp,
  );
  if (!bien || !context.mounted) return;
  context.push('/sync');
}
