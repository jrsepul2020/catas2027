import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/actualizacion.dart';
import '../../core/backend.dart';
import '../../core/errores.dart';
import '../../core/providers.dart';
import '../widgets.dart';
import 'catas_screen.dart';

/// Configuración: conexiones a Supabase Cloud y Local + sesión y cata.
class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ses = ref.watch(sesionProvider).value;
    final cli = ref.watch(clienteProvider).value;
    final cata = ref.watch(concursoProvider);
    final varios = ref.watch(concursosProvider).length > 1;
    final e = ref.watch(entornoProvider);
    final backends = ref.read(backendsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: [
          PopupMenuButton<String>(
            iconSize: 30,
            tooltip: 'Copiar / pegar configuración',
            onSelected: (v) => v == 'copiar' ? _copiar(context, backends) : _pegar(context, ref),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'copiar',
                child: ListTile(leading: Icon(Icons.copy), title: Text('Copiar configuración')),
              ),
              PopupMenuItem(
                value: 'pegar',
                child: ListTile(leading: Icon(Icons.paste), title: Text('Pegar configuración')),
              ),
            ],
          ),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (ses == null && cli != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: Text('Continuar a iniciar sesión (${e.corto})'),
                ),
              ),
            Text(
              'Entorno de trabajo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Las URL y claves se guardan en este dispositivo al pulsar Guardar. '
              'Si estás logueado, también se guardan en tu usuario Auth para recuperarlas en otro aparato.',
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 10),
            SegmentedButton<Entorno>(
              segments: const [
                ButtonSegment(value: Entorno.local, icon: Icon(Icons.dns), label: Text('LOCAL')),
                ButtonSegment(value: Entorno.cloud, icon: Icon(Icons.cloud), label: Text('CLOUD')),
              ],
              selected: {e},
              onSelectionChanged: (s) => ref.read(entornoProvider.notifier).cambiar(s.first),
            ),
            const SizedBox(height: 20),
            const TarjetaActualizacion(),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Badge(
                  isLabelVisible: ref.watch(logErroresProvider).isNotEmpty,
                  label: Text('${ref.watch(logErroresProvider).length}'),
                  child: const Icon(Icons.bug_report_outlined),
                ),
                title: const Text('Log de errores'),
                subtitle: Text(
                  ref.watch(logErroresProvider).isEmpty
                      ? 'Sin fallos registrados en este dispositivo'
                      : 'Último: ${ref.watch(logErroresProvider).first.titulo}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => mostrarLogErrores(context, ref),
              ),
            ),
            const SizedBox(height: 16),
            for (final en in Entorno.values) ...[_TarjetaEntorno(en), const SizedBox(height: 16)],
            if (ses != null) ...[
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: Text(ses.user.email ?? ses.user.id),
                      subtitle: Text('Sesión en ${e.largo}'),
                    ),
                    if (cata != null && varios)
                      ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: const Text('Cambiar de concurso'),
                        subtitle: Text(cata.nombre),
                        onTap: () {
                          ref.read(concursoGuardadoProvider.notifier).set(null);
                          context.go('/catas');
                        },
                      ),
                    if (cata != null)
                      ListTile(
                        leading: const Icon(Icons.tune),
                        title: Text('Concurso: ${cata.nombre}'),
                        subtitle: Text(
                          'Gran Oro ≥ ${cata.granOro} · Oro ≥ ${cata.oro} · Plata ≥ ${cata.plata} · '
                          '${cata.catadoresPorMesa} catadores por mesa',
                        ),
                        onTap: () => editarConcurso(context, ref, cata),
                      ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => cerrarSesion(context, ref),
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copiar(BuildContext context, Backends b) {
    Clipboard.setData(ClipboardData(text: b.exportar()));
    aviso(context, 'Configuración copiada. Pégala en otro dispositivo.');
  }

  Future<void> _pegar(BuildContext context, WidgetRef ref) async {
    final txt = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final ctrl = TextEditingController(text: txt);
    if (!context.mounted) return;
    await hojaFormulario(
      context,
      titulo: 'Pegar configuración',
      campos: [
        const Text(
          'JSON con CLOUD_URL, CLOUD_ANON_KEY, LOCAL_URL, LOCAL_ANON_KEY (mismo formato que config/entornos.json).',
        ),
        const SizedBox(height: 12),
        Campo(ctrl, 'Configuración', lineas: 6),
      ],
      guardar: () async {
        final hechos = await ref.read(backendsProvider).importar(ctrl.text);
        ref.invalidate(entornoProvider);
        ref.read(revisionProvider.notifier).subir();
        if (context.mounted) aviso(context, 'Importado: ${hechos.map((e) => e.corto).join(' y ')}');
      },
    );
  }
}

class _TarjetaEntorno extends ConsumerStatefulWidget {
  const _TarjetaEntorno(this.e);
  final Entorno e;
  @override
  ConsumerState<_TarjetaEntorno> createState() => _TarjetaEntornoState();
}

class _TarjetaEntornoState extends ConsumerState<_TarjetaEntorno> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _verClave = false;
  bool _probando = false;
  ResultadoPrueba? _prueba;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final c = ref.read(backendsProvider).config(widget.e);
    _url.text = c.url;
    _key.text = c.anonKey;
    _prueba = null;
  }

  ConfigEntorno get _actual => ConfigEntorno(url: _url.text, anonKey: _key.text);

  Future<void> _probar() async {
    setState(() => _probando = true);
    final r = await probarConexion(_actual);
    if (mounted) {
      setState(() {
        _probando = false;
        _prueba = r;
      });
    }
  }

  Future<void> _guardar() async {
    final b = ref.read(backendsProvider);
    if (!_actual.completa) {
      aviso(context, 'Revisa la URL (http:// o https://) y la clave', error: true);
      return;
    }
    await b.guardarConfig(widget.e, _actual);
    // Si hay sesión, también deja las conexiones en el perfil Auth (para otros dispositivos).
    final c = ref.read(clienteProvider).value;
    if (c?.auth.currentUser != null) {
      try {
        await b.subirConexionesAlUsuario(c!);
      } catch (_) {}
    }
    ref.read(revisionProvider.notifier).subir();
    if (!mounted) return;
    setState(() => _cargar());
    aviso(
      context,
      c?.auth.currentUser != null
          ? '${widget.e.corto} guardado en este dispositivo y en tu usuario'
          : '${widget.e.corto} guardado en este dispositivo',
    );
    _probar();
  }

  Future<void> _restaurar() async {
    await ref.read(backendsProvider).restaurar(widget.e);
    ref.read(revisionProvider.notifier).subir();
    if (!mounted) return;
    setState(() => _cargar());
    aviso(context, '${widget.e.corto}: configuración de fábrica');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(revisionProvider);
    final cfg = ref.read(backendsProvider).config(widget.e);
    final cloud = widget.e == Entorno.cloud;
    final cs = Theme.of(context).colorScheme;
    final colorOrigen = switch (cfg.origen) {
      OrigenConfig.build => Colors.amber.shade700,
      OrigenConfig.dispositivo => Colors.blue.shade700,
      OrigenConfig.porDefecto => Colors.red.shade800,
      OrigenConfig.vacia => cs.error,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(cloud ? Icons.cloud : Icons.dns),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.e.largo,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: Icon(Icons.circle, size: 14, color: colorOrigen),
                label: Text(cfg.origen.texto),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              cloud
                  ? 'En Supabase: Project Settings > API > Project URL y anon / publishable key.'
                  : 'Salida de `supabase status`. En un móvil usa la IP del ordenador en la WiFi '
                        '(http://192.168.x.x:54321); en el emulador Android, http://10.0.2.2:54321.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: const TextStyle(fontSize: 19),
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: cloud ? 'https://xxxx.supabase.co' : 'http://192.168.1.50:54321',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _key,
                obscureText: !_verClave,
                autocorrect: false,
                style: const TextStyle(fontSize: 19),
                decoration: InputDecoration(
                  labelText: 'Anon / publishable key',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _verClave = !_verClave),
                    icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
              ),
            ),
            if (_prueba != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      _prueba!.ok ? Icons.check_circle : Icons.error,
                      color: _prueba!.ok ? Colors.amber.shade700 : cs.error,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_prueba!.mensaje, style: const TextStyle(fontSize: 16))),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _probando ? null : _probar,
                    icon: _probando
                        ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Probar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _guardar,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
            if (cfg.origen == OrigenConfig.dispositivo)
              TextButton.icon(
                onPressed: _restaurar,
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar la incluida en la app'),
              ),
          ],
        ),
      ),
    );
  }
}
