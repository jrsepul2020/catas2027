import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
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

  @override
  void initState() {
    super.initState();
    _email.text = ref.read(prefsProvider).getString('ultimo_email') ?? '';
  }

  Future<void> _entrar({bool registro = false}) async {
    final c = await ref.read(clienteProvider.future);
    if (c == null) return;
    setState(() => _cargando = true);
    final email = _email.text.trim();
    await ref.read(prefsProvider).setString('ultimo_email', email);
    if (!mounted) return;
    await ejecutar(context, () async {
      if (registro) {
        final r = await c.auth.signUp(email: email, password: _pass.text);
        if (r.session == null && mounted) aviso(context, 'Revisa tu correo para confirmar la cuenta');
      } else {
        await c.auth.signInWithPassword(email: email, password: _pass.text);
      }
    });
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(entornoProvider);
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
                    Icon(Icons.wine_bar, size: 96, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'Virtus Catas 2027',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<Entorno>(
                      segments: const [
                        ButtonSegment(value: Entorno.local, icon: Icon(Icons.dns), label: Text('LOCAL')),
                        ButtonSegment(value: Entorno.cloud, icon: Icon(Icons.cloud), label: Text('CLOUD')),
                      ],
                      selected: {e},
                      onSelectionChanged: (s) => ref.read(entornoProvider.notifier).cambiar(s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref.read(backendsProvider).config(e).url,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(fontSize: 19),
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.person)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      style: const TextStyle(fontSize: 19),
                      onSubmitted: (_) => _entrar(),
                      decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _cargando ? null : _entrar,
                      icon: _cargando
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3))
                          : const Icon(Icons.login),
                      label: const Text('Entrar'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _cargando ? null : () => _entrar(registro: true),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => context.push('/ajustes'),
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
