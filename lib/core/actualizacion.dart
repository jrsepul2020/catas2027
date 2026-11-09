import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Solo Android instalado desde Play (también Prueba interna).
bool get actualizacionSoportada => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<String> versionAppTexto() async {
  final p = await PackageInfo.fromPlatform();
  return '${p.version}+${p.buildNumber}';
}

class EstadoActualizacion {
  const EstadoActualizacion({required this.hayUpdate, this.codigoDisponible, this.error, this.inmediataOk = false});
  final bool hayUpdate;
  final int? codigoDisponible;
  final String? error;
  final bool inmediataOk;
}

Future<EstadoActualizacion> comprobarActualizacionPlay() async {
  if (!actualizacionSoportada) {
    return const EstadoActualizacion(
      hayUpdate: false,
      error: 'Las actualizaciones in-app solo funcionan en Android instalado desde Play',
    );
  }
  try {
    final info = await InAppUpdate.checkForUpdate();
    final hay = info.updateAvailability == UpdateAvailability.updateAvailable;
    return EstadoActualizacion(
      hayUpdate: hay,
      codigoDisponible: info.availableVersionCode,
      inmediataOk: info.immediateUpdateAllowed,
    );
  } catch (e) {
    // En debug / sideload Play responde ERROR_API_NOT_AVAILABLE.
    return EstadoActualizacion(hayUpdate: false, error: '$e');
  }
}

/// Flujo inmediato de Play: descarga, instala y reinicia la app.
Future<String?> aplicarActualizacionInmediata() async {
  if (!actualizacionSoportada) return 'No disponible en esta plataforma';
  try {
    final r = await InAppUpdate.performImmediateUpdate();
    return switch (r) {
      AppUpdateResult.success => null, // Play suele reiniciar antes de volver
      AppUpdateResult.userDeniedUpdate => 'Actualización cancelada',
      AppUpdateResult.inAppUpdateFailed =>
        'No se pudo actualizar. Tiene que estar instalada desde Google Play (Prueba interna).',
    };
  } catch (e) {
    return '$e';
  }
}

final versionAppProvider = FutureProvider<String>((ref) => versionAppTexto());

final actualizacionPlayProvider = FutureProvider<EstadoActualizacion>((ref) => comprobarActualizacionPlay());

/// Banner compacto si Play tiene una build más nueva.
class AvisoActualizacionDisponible extends ConsumerWidget {
  const AvisoActualizacionDisponible({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!actualizacionSoportada) return const SizedBox.shrink();
    final async = ref.watch(actualizacionPlayProvider);
    final est = async.asData?.value;
    if (est == null || !est.hayUpdate) return const SizedBox.shrink();

    return Material(
      color: Paleta.azulPastel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: Paleta.azulOscuro),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  est.codigoDisponible == null
                      ? 'Hay una versión nueva en Play'
                      : 'Hay una versión nueva en Play (código ${est.codigoDisponible})',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.azulOscuro),
                ),
              ),
              FilledButton(onPressed: () => _actualizar(context, ref), child: const Text('Actualizar')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actualizar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      '¿Actualizar ahora?',
      texto: 'Play descargará la nueva versión y reiniciará la app.',
      si: 'Actualizar',
    );
    if (!ok || !context.mounted) return;
    final err = await aplicarActualizacionInmediata();
    if (err != null && context.mounted) aviso(context, err, error: true);
  }
}

/// Bloque en Configuración: versión instalada + comprobar / actualizar.
class TarjetaActualizacion extends ConsumerWidget {
  const TarjetaActualizacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ver = ref.watch(versionAppProvider);
    final act = ref.watch(actualizacionPlayProvider);
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Versión de la app',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              ver.when(data: (v) => 'Instalada: $v', loading: () => 'Instalada: …', error: (_, _) => 'Instalada: ?'),
              style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (!actualizacionSoportada)
              Text(
                'Las actualizaciones automáticas solo están en el móvil Android instalado desde Play.',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              )
            else ...[
              if (act.isLoading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 3))
              else if (act.hasError)
                Text('${act.error}', style: TextStyle(color: cs.error))
              else if (act.value!.hayUpdate) ...[
                Text(
                  act.value!.codigoDisponible == null
                      ? 'Hay una versión nueva disponible en Play.'
                      : 'Play tiene el código ${act.value!.codigoDisponible}.',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Paleta.azulOscuro),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _actualizar(context, ref),
                  icon: const Icon(Icons.system_update),
                  label: const Text('Actualizar y reiniciar'),
                ),
              ] else ...[
                Text(
                  act.value!.error != null && act.value!.error!.contains('API_NOT_AVAILABLE')
                      ? 'Sin novedades (o esta instalación no es de Play).'
                      : 'Estás al día con Play.',
                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    ref.invalidate(actualizacionPlayProvider);
                    await ref.read(actualizacionPlayProvider.future);
                    if (context.mounted) {
                      final e = ref.read(actualizacionPlayProvider).value;
                      if (e?.hayUpdate == true) {
                        aviso(context, 'Hay una versión nueva');
                      } else if (e?.error != null && !e!.error!.contains('API_NOT_AVAILABLE')) {
                        aviso(context, e.error!, error: true);
                      } else {
                        aviso(context, 'No hay actualizaciones');
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Comprobar en Play'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _actualizar(BuildContext context, WidgetRef ref) async {
    final ok = await confirmar(
      context,
      '¿Actualizar ahora?',
      texto: 'Play descargará e instalará la nueva versión y reiniciará la app.',
      si: 'Actualizar',
    );
    if (!ok || !context.mounted) return;
    final err = await aplicarActualizacionInmediata();
    if (err != null && context.mounted) aviso(context, err, error: true);
  }
}
