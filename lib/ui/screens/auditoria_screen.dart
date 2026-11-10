import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../../data/auditoria.dart';
import '../componentes_cataris.dart';
import '../theme.dart';
import '../widgets.dart';

/// Auditoría del día: comprobaciones estructurales + (en LOCAL) revisiones SQL.
class AuditoriaScreen extends ConsumerStatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  ConsumerState<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends ConsumerState<AuditoriaScreen> {
  ResultadoAuditoria? _res;
  bool _cargando = false;
  String? _avisoEntorno;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ejecutar());
  }

  Future<SupabaseClient?> _clienteLocal() async {
    try {
      return await ref.read(backendsProvider).cliente(Entorno.local);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ejecutar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _avisoEntorno = null;
    });
    final esLocal = ref.read(esLocalProvider);
    SupabaseClient? local;
    if (esLocal) {
      local = await _clienteLocal();
      if (local == null) {
        _avisoEntorno = 'No hay cliente LOCAL: solo se muestran las comprobaciones estructurales.';
      }
    } else {
      _avisoEntorno =
          'Estás en CLOUD: se muestran las comprobaciones estructurales. '
          'Cambia a LOCAL (día cargado) para las 8 revisiones SQL del día.';
    }
    final res = await ejecutarAuditoria(ref: ref, local: local);
    if (!mounted) return;
    ref.read(ultimaAuditoriaProvider.notifier).guardar(res);
    setState(() {
      _res = res;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final res = _res;
    final mirar = res?.mirar ?? const [];
    final cuenta = res?.cuenta ?? const [];
    final hora = res == null ? null : formatearHoraAuditoria(res.cuando);

    return Scaffold(
      appBar: AppBar(
        leading: botonVolver(context),
        title: const Text('Auditoría'),
        actions: [
          if (hora != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'Última: $hora',
                  style: TextStyle(fontSize: k ? 12 : 14, fontWeight: FontWeight.w700, color: Paleta.texto),
                ),
              ),
            ),
          const ChipDia(),
          const ChipEntorno(),
        ],
      ),
      body: Ancho(
        max: 900,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 14, k ? 12 : 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      res == null
                          ? 'Comprobando…'
                          : res.todoCorrecto
                          ? 'Todo correcto'
                          : '${mirar.length} a mirar · ${cuenta.length} a tener en cuenta',
                      style: TextStyle(
                        fontSize: k ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: res == null
                            ? Paleta.texto
                            : res.todoCorrecto
                            ? Paleta.azulOscuro
                            : (mirar.isNotEmpty ? Paleta.rojo : Paleta.amarilloOscuro),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _cargando ? null : _ejecutar,
                    icon: _cargando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          )
                        : const Icon(Icons.fact_check),
                    label: Text(_cargando ? '…' : 'Comprobar'),
                  ),
                ],
              ),
            ),
            if (_avisoEntorno != null)
              Padding(
                padding: EdgeInsets.fromLTRB(k ? 12 : 16, 0, k ? 12 : 16, 8),
                child: _AvisoBanda(texto: _avisoEntorno!, color: Colors.amber),
              ),
            if (res?.error != null)
              Padding(
                padding: EdgeInsets.fromLTRB(k ? 12 : 16, 0, k ? 12 : 16, 8),
                child: _AvisoBanda(texto: res!.error!, color: Colors.red),
              ),
            Expanded(
              child: res == null && _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : res == null
                  ? const Vacio(icono: Icons.fact_check_outlined, texto: 'Pulsa Comprobar para auditar el día.')
                  : res.todoCorrecto
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, size: k ? 48 : 64, color: Paleta.azul),
                            const SizedBox(height: 12),
                            Text(
                              'Todo correcto',
                              style: TextStyle(
                                fontSize: k ? 20 : 24,
                                fontWeight: FontWeight.w900,
                                color: Paleta.azulOscuro,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Comprobado a las $hora',
                              style: TextStyle(fontSize: k ? 14 : 16, fontWeight: FontWeight.w600, color: Paleta.texto),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(k ? 10 : 14, 0, k ? 10 : 14, k ? 14 : 20),
                      children: [
                        if (mirar.isNotEmpty) ...[
                          _CabeceraBloque(titulo: 'Hay que mirarlo', color: Colors.red, k: k),
                          for (final h in mirar) _FilaHallazgo(h: h, color: Colors.red, k: k),
                          SizedBox(height: k ? 12 : 16),
                        ],
                        if (cuenta.isNotEmpty) ...[
                          _CabeceraBloque(titulo: 'Para tener en cuenta', color: Colors.amber, k: k),
                          for (final h in cuenta) _FilaHallazgo(h: h, color: Colors.amber, k: k),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisoBanda extends StatelessWidget {
  const _AvisoBanda({required this.texto, required this.color});
  final String texto;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color.shade900),
      ),
    );
  }
}

class _CabeceraBloque extends StatelessWidget {
  const _CabeceraBloque({required this.titulo, required this.color, required this.k});
  final String titulo;
  final MaterialColor color;
  final bool k;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: k ? 6 : 8, top: 4),
      child: Text(
        titulo,
        style: TextStyle(fontSize: k ? 15 : 17, fontWeight: FontWeight.w900, color: color.shade800),
      ),
    );
  }
}

class _FilaHallazgo extends StatelessWidget {
  const _FilaHallazgo({required this.h, required this.color, required this.k});
  final HallazgoAuditoria h;
  final MaterialColor color;
  final bool k;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: k ? 6 : 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.shade400.withValues(alpha: 0.10), Colors.white),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: k ? 10 : 14, vertical: k ? 9 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                h.hayQueMirarlo ? Icons.error_outline : Icons.info_outline,
                size: k ? 22 : 26,
                color: color.shade800,
              ),
              SizedBox(width: k ? 8 : 12),
              Expanded(
                child: Text(
                  h.texto,
                  style: TextStyle(
                    fontSize: k ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Paleta.texto,
                    height: 1.25,
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
