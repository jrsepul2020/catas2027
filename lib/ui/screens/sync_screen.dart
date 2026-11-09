import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend.dart';
import '../../core/errores.dart';
import '../../core/providers.dart';
import '../../sync/sync_service.dart';
import '../theme.dart';
import '../widgets.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});
  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  Direccion _dir = Direccion.bajar;
  bool _corriendo = false;
  final List<String> _log = [];
  ResultadoSync? _res;
  final Map<Entorno, SupabaseClient?> _cli = {};
  List<Map<String, dynamic>> _dias = [];
  int? _dia;
  bool _cuadreOk = false;

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
    await _leerCuadreLocal();
    if (mounted) setState(() {});
  }

  Future<void> _leerCuadreLocal() async {
    final local = _cli[Entorno.local];
    if (local?.auth.currentSession == null) {
      _cuadreOk = false;
      return;
    }
    try {
      final est = await local!.from('sync_estado').select('cuadre_ok').eq('id', 1).maybeSingle();
      _cuadreOk = est?['cuadre_ok'] == true;
    } catch (_) {
      _cuadreOk = false;
    }
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
    await _leerCuadreLocal();
    if (mounted) setState(() {});
  }

  SyncService? _svc() {
    final cloud = _cli[Entorno.cloud], local = _cli[Entorno.local];
    if (cloud == null || local == null) return null;
    return SyncService(cloud: cloud, local: local, prefs: ref.read(prefsProvider));
  }

  Future<void> _sincronizar() async {
    final svc = _svc();
    if (svc == null) return;

    if (_dir == Direccion.bajar) {
      if (_dia == null) {
        aviso(context, 'Elige el día a bajar', error: true);
        return;
      }
      final okPrevios = await _comprobarPreviosBajada(svc);
      if (!okPrevios) return;
    }

    setState(() {
      _corriendo = true;
      _log.clear();
      _res = null;
    });
    final res = ResultadoSync();
    final t0 = DateTime.now();
    try {
      final stream = _dir == Direccion.bajar ? svc.bajarDia(_dia!, res: res) : svc.subirDia(res: res);
      await for (final p in stream) {
        if (!mounted) return;
        setState(() {
          if (_log.isNotEmpty && _log.last.startsWith('${p.paso}:')) _log.removeLast();
          _log.add('${p.paso}: ${p.mensaje}');
        });
      }
    } catch (e) {
      res.errores.add('$e');
    }
    if (!mounted) return;
    final ms = DateTime.now().difference(t0).inMilliseconds;
    await _leerCuadreLocal();
    setState(() {
      _corriendo = false;
      _res = res;
      _log.add('Terminado en ${(ms / 1000).toStringAsFixed(1)} s');
    });

    if (res.problemasValidacion.isNotEmpty) {
      if (!mounted) return;
      await _mostrarLista(
        'No se ha bajado nada',
        'El día no cumple las reglas. Corrige en CLOUD (App 1) y vuelve a intentar:',
        res.problemasValidacion,
      );
      return;
    }
    if (!mounted) return;
    aviso(
      context,
      res.errores.isEmpty
          ? (_dir == Direccion.bajar
                ? 'Día bajado · ${res.recuentos.entries.map((e) => '${e.key}:${e.value}').join(' · ')}'
                : (res.cuadre == 'CUADRA' ? 'Subida OK · CUADRA' : 'Subida con diferencias de cuadre'))
          : 'Terminado con ${res.errores.length} errores',
      error: res.errores.isNotEmpty || (res.cuadre != null && res.cuadre != 'CUADRA'),
    );
  }

  Future<bool> _comprobarPreviosBajada(SyncService svc) async {
    final pruebas = ref.read(modoPruebasProvider);

    if (await svc.hayPuntuacionesSinSubir()) {
      if (!mounted) return false;
      if (pruebas) {
        final seg = await confirmar(
          context,
          'Hay puntuaciones en LOCAL sin subir',
          texto:
              'Modo pruebas: puedes seguir y se BORRARÁN al vaciar el LOCAL.\n'
              'En producción habría que subir primero.',
          si: 'Seguir igual',
        );
        if (!seg) return false;
      } else {
        await _mostrarLista(
          'No se puede bajar',
          'Hay puntuaciones en LOCAL sin subir (o sin cuadre OK). Sube primero el día actual.',
          const ['Ve a «Subir notas a CLOUD» y espera a que diga CUADRA.'],
        );
        return false;
      }
    }

    final cambios = await svc.cambiosLocalesDesdeBajada();
    if (!mounted) return false;
    if (cambios.isNotEmpty) {
      final ok = await confirmar(
        context,
        'Se perderán cambios locales de puestos',
        texto:
            'Desde la última bajada se han cambiado mesa, puesto o presidente en LOCAL.\n'
            'Al bajar de nuevo se BORRAN y se sustituyen por CLOUD:\n\n'
            '${cambios.map((c) => '· ${c.texto}').join('\n')}',
        si: 'Borrar y bajar',
      );
      if (!ok) return false;
    } else {
      final ok = await confirmar(
        context,
        '¿Bajar el día a LOCAL?',
        texto:
            'Se vaciará por completo el LOCAL y se cargará el día elegido '
            '(catadores aplanados + tablets recalculadas).\n'
            'No se bajan asignaciones, medallas ni días.',
        si: 'Bajar',
      );
      if (!ok) return false;
    }
    return true;
  }

  Future<void> _mostrarLista(String titulo, String intro, List<String> items) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(intro, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 12),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('· $i', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
      ),
    );
  }

  Future<void> _generarPrueba() async {
    final svc = _svc();
    if (svc == null || _dia == null) return;
    if (!ref.read(modoPruebasProvider)) {
      aviso(context, 'Activa modo pruebas (mantener pulsado el chip de entorno)', error: true);
      return;
    }
    final ok = await confirmar(
      context,
      '¿Generar asignaciones de prueba?',
      texto:
          'Crea en CLOUD las asignaciones del día (puesto 1 = presidente). '
          'No rellena mesa/puesto/rol en catadores.',
      si: 'Generar',
    );
    if (!ok || !mounted) return;
    try {
      final r = await svc.generarAsignacionesPrueba(_dia!);
      if (mounted) aviso(context, 'Asignaciones: ${r['asignaciones']} · mesas: ${r['mesas']}');
    } catch (e, st) {
      if (mounted) await registrarYMostrarError(context, e, stack: st, accion: 'Generar asignaciones de prueba');
    }
  }

  Future<void> _vaciarLocal() async {
    final svc = _svc();
    if (svc == null) return;
    if (!_cuadreOk) {
      aviso(context, 'Solo se puede vaciar cuando el cuadre ha dicho CUADRA', error: true);
      return;
    }
    final ok = await confirmar(
      context,
      '¿Vaciar LOCAL?',
      texto: 'El cuadre CUADRA. Se borrarán todos los datos de concurso del LOCAL.',
      si: 'Vaciar',
    );
    if (!ok || !mounted) return;
    try {
      await svc.vaciarLocalTrasCuadre();
      await _leerCuadreLocal();
      if (mounted) {
        setState(() {});
        aviso(context, 'LOCAL vacío');
      }
    } catch (e, st) {
      if (mounted) await registrarYMostrarError(context, e, stack: st, accion: 'Vaciar LOCAL');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = ref.read(backendsProvider);
    final listo = Entorno.values.every((e) => _cli[e]?.auth.currentSession != null);
    final pruebas = ref.watch(modoPruebasProvider);

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
      appBar: AppBar(leading: botonVolver(context), title: const Text('Sincronizar')),
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
                  child: Icon(_dir == Direccion.bajar ? Icons.arrow_forward : Icons.arrow_back, size: 40),
                ),
                tarjeta(Entorno.local),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<Direccion>(
              segments: const [
                ButtonSegment(value: Direccion.bajar, icon: Icon(Icons.download), label: Text('Bajar día')),
                ButtonSegment(value: Direccion.subir, icon: Icon(Icons.upload), label: Text('Subir notas')),
              ],
              selected: {_dir},
              onSelectionChanged: _corriendo ? null : (s) => setState(() => _dir = s.first),
            ),
            if (_dir == Direccion.bajar && _dias.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Día de cata (se baja la noche anterior)', style: TextStyle(fontWeight: FontWeight.w800)),
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
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(76)),
              onPressed: !listo || _corriendo ? null : _sincronizar,
              icon: _corriendo
                  ? const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3))
                  : Icon(_dir == Direccion.bajar ? Icons.download : Icons.upload),
              label: Text(
                _corriendo ? 'Trabajando…' : (_dir == Direccion.bajar ? 'Bajar día a LOCAL' : 'Subir notas a CLOUD'),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            if (!listo)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Inicia sesión en ambos entornos.', textAlign: TextAlign.center),
              ),
            const SizedBox(height: 12),
            Text(
              _dir == Direccion.bajar
                  ? 'Bajar: valida el día en CLOUD, vacía LOCAL y carga concurso, categorías, mesas, '
                        'tandas, muestras, catadores aplanados (mesa/puesto/rol del día) y tablets '
                        '(nº = (mesa−1)×5+puesto). No baja asignaciones, medallas ni días.'
                  : 'Subir: solo puntuaciones y registro de cambios. Nunca estructura ni catadores. '
                        'Al terminar hace cuadre automático (CUADRA o lista de faltas).',
              style: const TextStyle(fontSize: 14),
            ),
            if (pruebas) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _corriendo || _dia == null ? null : _generarPrueba,
                icon: const Icon(Icons.science),
                label: const Text('Generar asignaciones de prueba (CLOUD)'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _cuadreOk ? Paleta.rojo : null),
              onPressed: _corriendo || !_cuadreOk ? null : _vaciarLocal,
              icon: const Icon(Icons.delete_forever),
              label: Text(_cuadreOk ? 'Vaciar LOCAL (cuadre CUADRA)' : 'Vaciar LOCAL (solo si CUADRA)'),
            ),
            if (_res != null) ...[
              const SizedBox(height: 16),
              if (_res!.recuentos.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recuento · ${_res!.horaFin != null ? _fmtHora(_res!.horaFin!) : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        for (final e in _res!.recuentos.entries)
                          Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 15)),
                        if (_res!.cuadre != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _res!.cuadre == 'CUADRA' ? 'CUADRA' : 'Cuadre:\n${_res!.cuadre}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _res!.cuadre == 'CUADRA' ? Paleta.azulOscuro : Paleta.rojo,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              for (final e in _res!.errores)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(e, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              for (final e in _res!.problemasValidacion)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('· $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

  String _fmtHora(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
}
