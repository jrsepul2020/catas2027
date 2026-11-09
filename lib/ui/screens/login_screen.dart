import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/errores.dart';
import '../../core/providers.dart';
import '../marca.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _cargando = false;
  bool _guardarPass = false;
  bool _verPass = false;

  @override
  void initState() {
    super.initState();
    _cargarGuardados();
  }

  void _cargarGuardados() {
    final prefs = ref.read(prefsProvider);
    final b = ref.read(backendsProvider);
    final e = ref.read(entornoProvider);
    _email.text = prefs.getString('ultimo_email') ?? '';
    _guardarPass = b.recordarPass(e);
    _pass.text = b.passGuardada(e) ?? '';
  }

  Future<void> _entrar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      if (mounted) {
        setState(() => _cargando = false);
        aviso(context, 'Escribe email y contraseña', error: true);
      }
      return;
    }
    final e = ref.read(entornoProvider);
    final b = ref.read(backendsProvider);
    try {
      // Preferir cliente ya creado; no esperar un login silencioso colgado.
      var c = b.clienteSiExiste(e) ?? ref.read(clienteProvider).value;
      c ??= await ref.read(clienteProvider.future).timeout(const Duration(seconds: 10));
      if (c == null) {
        if (mounted) {
          aviso(context, 'Primero configura la URL y la clave en Conexiones', error: true);
          context.push('/configuracion');
        }
        return;
      }
      final cliente = c;
      await ref.read(prefsProvider).setString('ultimo_email', email);
      if (!mounted) return;
      final ok = await ejecutar(context, () async {
        await cliente.auth.signInWithPassword(email: email, password: pass).timeout(const Duration(seconds: 12));
        await b.setRecordarPass(e, recordar: _guardarPass, pass: pass);
        // Guarda conexiones en el usuario (Cloud/Local) y trae las del otro entorno.
        try {
          await b.aplicarConexionesDelUsuario(cliente, e).timeout(const Duration(seconds: 6));
          await b.subirConexionesAlUsuario(cliente).timeout(const Duration(seconds: 6));
        } catch (_) {
          // El login ya fue bien; la sync de conexiones no debe bloquear.
        }
      }, accion: 'Iniciar sesión');
      if (!mounted) return;
      if (ok) {
        // Ir al menú ya (con omitir-login el redirect a veces no reacciona al instante).
        context.go('/');
      }
    } catch (err, st) {
      if (mounted) await registrarYMostrarError(context, err, stack: st, accion: 'Iniciar sesión');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(entornoProvider);
    final cfg = ref.watch(backendsProvider).config(e);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const LogoCataris(tamano: 112),
                    const SizedBox(height: 28),
                    SegmentedButton<Entorno>(
                      segments: const [
                        ButtonSegment(value: Entorno.local, icon: Icon(Icons.dns), label: Text('LOCAL')),
                        ButtonSegment(value: Entorno.cloud, icon: Icon(Icons.cloud), label: Text('CLOUD')),
                      ],
                      selected: {e},
                      onSelectionChanged: (s) {
                        ref.read(entornoProvider.notifier).cambiar(s.first);
                        setState(_cargarGuardados);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cfg.completa ? cfg.urlLimpia : 'Sin conexión configurada',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cfg.completa ? cs.onSurfaceVariant : Paleta.rojo, fontSize: 13),
                    ),
                    Text(
                      'Origen: ${cfg.origen.texto}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: TextStyle(fontSize: 19, color: cs.onSurface),
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass,
                      obscureText: !_verPass,
                      autofillHints: const [AutofillHints.password],
                      style: TextStyle(fontSize: 19, color: cs.onSurface),
                      onSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _verPass = !_verPass),
                          icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _guardarPass,
                      onChanged: (v) => setState(() => _guardarPass = v ?? false),
                      title: Text(
                        'Guardar contraseña en este dispositivo',
                        style: TextStyle(fontSize: 15, color: cs.onSurface),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _cargando ? null : _entrar,
                      icon: _cargando
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                          : const Icon(Icons.login),
                      label: const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.push('/configuracion'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Configurar conexiones'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
