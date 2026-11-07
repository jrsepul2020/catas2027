import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../../sync/sync_service.dart';
import '../widgets.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});
  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  Direccion _dir = Direccion.ambas;
  bool _completa = false;
  bool _corriendo = false;
  final List<String> _log = [];
  ResultadoSync? _res;
  final Map<Entorno, SupabaseClient?> _cli = {};
  List<Map<String, dynamic>> _dias = []; // días del concurso en CLOUD
  int? _dia; // día que se baja a LOCAL

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final b = ref.read(backendsProvider);
    for (final e in Entorno.values) {
      _cli[e] = await b.cliente(e);
    }
    await _cargarDias();
    if (mounted) setState(() {});
  }

  Future<void> _cargarDias() async {
    final c = _cli[Entorno.cloud];
    if (c?.auth.currentSession == null) return;
    try {
      _dias = await c!.from('dias_concurso').select('id, nombre, fecha').order('fecha');
      if (_dias.isNotEmpty && !_dias.any((d) => d['id'] == _dia)) {
        final hoy = DateTime.now().toIso8601String().substring(0, 10);
        final guardado = ref.read(prefsProvider).getInt('dia_cloud');
        _dia =
            (_dias.where((d) => d['id'] == guardado).firstOrNull ??
                    _dias.where((d) => d['fecha'] == hoy).firstOrNull ??
                    _dias.first)['id']
                as int;
      }
    } catch (_) {}
  }

  Future<void> _login(Entorno e) async {
    final c = _cli[e];
    if (c == null) return;
    final email = TextEditingController(text: ref.read(prefsProvider).getString('ultimo_email') ?? '');
    final pass = TextEditingController();
    await hojaFormulario(
      context,
      titulo: 'Entrar en ${e.largo}',
      campos: [
        Campo(email, 'Email'),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: pass,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(fontSize: 19),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
        ),
      ],
      guardar: () => c.auth.signInWithPassword(email: email.text.trim(), password: pass.text),
    );
    await _cargarDias();
    if (mounted) setState(() {});
  }

  Future<void> _sincronizar() async {
    final cloud = _cli[Entorno.cloud], local = _cli[Entorno.local];
    if (cloud == null || local == null) return;
    setState(() {
      _corriendo = true;
      _log.clear();
      _res = null;
    });
    final res = ResultadoSync();
    final svc = SyncService(cloud: cloud, local: local, prefs: ref.read(prefsProvider));
    final t0 = DateTime.now();
    try {
      await for (final p in svc.sincronizar(
        _dir,
        completa: _completa,
        diaBajar: _dir == Direccion.localACloud ? null : _dia,
        res: res,
      )) {
        if (!mounted) return;
        setState(() {
          if (_log.isNotEmpty && _log.last.startsWith('${p.tabla}:')) _log.removeLast();
          _log.add('${p.tabla}: ${p.mensaje}');
        });
      }
    } catch (e) {
      res.errores.add('$e');
    }
    if (!mounted) return;
    final ms = DateTime.now().difference(t0).inMilliseconds;
    setState(() {
      _corriendo = false;
      _res = res;
      _log.add('Terminado en ${(ms / 1000).toStringAsFixed(1)} s');
    });
    aviso(
      context,
      res.errores.isEmpty
          ? 'Sincronizado: ${res.totalLocal} → LOCAL · ${res.totalCloud} → CLOUD'
          : 'Sincronizado con ${res.errores.length} errores',
      error: res.errores.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.read(backendsProvider);
    final listo = Entorno.values.every((e) => _cli[e]?.auth.currentSession != null);

    Widget tarjeta(Entorno e) {
      final c = _cli[e];
      final ses = c?.auth.currentSession;
      final cloud = e == Entorno.cloud;
      return Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Icon(
                  cloud ? Icons.cloud : Icons.dns,
                  size: 48,
                  color: cloud ? Colors.blue.shade700 : Colors.deepPurple.shade700,
                ),
                Text(e.corto, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  b.config(e).url.isEmpty ? 'Sin configurar' : b.config(e).url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (c == null)
                  OutlinedButton(onPressed: () => context.push('/configuracion'), child: const Text('Configurar'))
                else if (ses == null)
                  FilledButton(onPressed: () => _login(e), child: const Text('Entrar'))
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.amber),
                      const SizedBox(width: 6),
                      Flexible(child: Text(ses.user.email ?? 'ok', overflow: TextOverflow.ellipsis)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizar')),
      body: Ancho(
        max: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tarjeta(Entorno.cloud),
                Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: Icon(switch (_dir) {
                    Direccion.ambas => Icons.sync_alt,
                    Direccion.cloudALocal => Icons.arrow_forward,
                    Direccion.localACloud => Icons.arrow_back,
                  }, size: 40),
                ),
                tarjeta(Entorno.local),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<Direccion>(
              segments: const [
                ButtonSegment(value: Direccion.ambas, icon: Icon(Icons.sync_alt), label: Text('Ambas')),
                ButtonSegment(value: Direccion.cloudALocal, icon: Icon(Icons.download), label: Text('Bajar')),
                ButtonSegment(value: Direccion.localACloud, icon: Icon(Icons.upload), label: Text('Subir')),
              ],
              selected: {_dir},
              onSelectionChanged: _corriendo ? null : (s) => setState(() => _dir = s.first),
            ),
            if (_dir != Direccion.localACloud && _dias.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Día de cata que se baja a LOCAL', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final d in _dias)
                    ChoiceChip(
                      label: Text('${d['nombre'] ?? ''} · ${d['fecha']}'),
                      selected: _dia == d['id'],
                      onSelected: _corriendo ? null : (_) => setState(() => _dia = d['id'] as int),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Revisión completa'),
              subtitle: const Text('Compara todas las filas, no solo los cambios recientes'),
              value: _completa,
              onChanged: _corriendo ? null : (v) => setState(() => _completa = v),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(76)),
              onPressed: !listo || _corriendo ? null : _sincronizar,
              icon: _corriendo
                  ? const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.sync),
              label: Text(_corriendo ? 'Sincronizando…' : 'Sincronizar ahora', style: const TextStyle(fontSize: 22)),
            ),
            if (!listo)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Inicia sesión en ambos entornos para sincronizar.', textAlign: TextAlign.center),
              ),
            const SizedBox(height: 8),
            const Text(
              'Bajar: trae a LOCAL solo el día elegido (sus tandas, muestras y notas) más mesas y catadores; '
              'en LOCAL no hay selector de días, se trabaja ese día. '
              'Subir: envía a CLOUD lo hecho en LOCAL. Ambas: las dos cosas. '
              'Siempre gana el cambio más reciente; los borrados también viajan; '
              'las notas se emparejan por catador + muestra. Las altas hechas en LOCAL usan ids desde 1.000.000.',
              style: TextStyle(fontSize: 14),
            ),
            if (_res != null) ...[
              const SizedBox(height: 16),
              Card(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Tabla')),
                    DataColumn(label: Text('→ LOCAL'), numeric: true),
                    DataColumn(label: Text('→ CLOUD'), numeric: true),
                  ],
                  rows: [
                    for (final e in _res!.porTabla.entries)
                      DataRow(
                        cells: [
                          DataCell(Text(e.key)),
                          DataCell(Text('${e.value.$1}')),
                          DataCell(Text('${e.value.$2}')),
                        ],
                      ),
                  ],
                ),
              ),
              for (final e in _res!.errores)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final l in _log) Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
