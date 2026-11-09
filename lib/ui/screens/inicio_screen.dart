import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend.dart';
import '../../core/providers.dart';
import '../../data/repo.dart';
import '../iconos.dart';
import '../marca.dart';
import '../theme.dart';
import '../widgets.dart';

/// Panel principal (referencia maqueta VIRTUS): KPIs, gestión rápida y sistema.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesas = ref.watch(mesasProvider);
    final tandas = ref.watch(tandasProvider);
    final catadores = ref.watch(catadoresProvider);
    final muestras = ref.watch(muestrasProvider);
    final punt = ref.watch(puntuacionesProvider);
    final inc = ref.watch(incidenciasAbiertasProvider);
    final cargando = ref.watch(cargandoProvider);
    final entorno = ref.watch(entornoProvider);
    final conexion = ref.watch(estadoConexionProvider);
    final k = esCompacto(context);

    final abiertas = tandas.where((t) => t.estado == 'abierta').length;
    final cerradas = tandas.where((t) => t.estado == 'cerrada').length;
    final ausentes = catadores.where((c) => !c.presente).length;
    final conectados = catadores.where((c) => c.conectado).length;
    final catando = mesas.where((m) => tandas.any((t) => t.mesaId == m.id && t.estado == 'abierta')).length;
    final reservas = ref.watch(tabletsLibresProvider).length;
    final hechas = tandas.isEmpty ? 0 : (cerradas / tandas.length * 100).round();
    final conectado = conexion.maybeWhen(data: (v) => v.$1, orElse: () => false);
    final msgConexion = conexion.when(data: (v) => v.$2, loading: () => 'Comprobando…', error: (e, _) => '$e');

    final kpis = [
      _Kpi(Iconos.directo, 'Mesas catando', '$catando', 'de ${mesas.length}', Virtus.accion, catando > 0),
      _Kpi(Iconos.tandas, 'Tandas abiertas', '$abiertas', '$cerradas cerradas', Virtus.marino, abiertas > 0),
      _Kpi(Iconos.incidencias, 'Alertas', '$inc', inc == 0 ? 'Sin abiertas' : 'Abiertas', Virtus.error, inc > 0),
      _Kpi(
        Iconos.tablet,
        'Tablets',
        '$conectados',
        'de ${catadores.length}${ausentes > 0 ? ' · $ausentes aus.' : ''}',
        Virtus.accion,
        false,
      ),
      _Kpi(Iconos.puntuaciones, 'Notas', '${punt.length}', 'del día', Virtus.marino, false),
    ];

    final acciones = [
      _Accion(Iconos.directo, 'En directo', '$catando en cata', '/directo', destacado: true),
      _Accion(Iconos.mesas, 'Mesas', '${mesas.length} mesas', '/mesas'),
      _Accion(Iconos.puntuaciones, 'Puntuaciones', '${punt.length} notas', '/puntuar'),
      _Accion(Iconos.tandas, 'Tandas', '$abiertas abiertas', '/tandas'),
      _Accion(
        Iconos.incidencias,
        'Incidencias',
        inc == 0 ? 'Ninguna' : '$inc abiertas',
        '/incidencias',
        alerta: inc > 0,
      ),
      _Accion(Iconos.catadores, 'Catadores', '$conectados conectados', '/catadores'),
      _Accion(Iconos.muestras, 'Muestras', '${muestras.where((m) => m.activa).length} activas', '/muestras'),
      _Accion(Iconos.medallero, 'Medallero Provisional', 'Resultados', '/medallas'),
      _Accion(Iconos.auditoria, 'Auditoría', reservas > 0 ? '$reservas reservas' : 'Chequeos', '/auditoria'),
    ];

    final problema = avisoCarga(
      ref,
      que: 'Cargar el panel de inicio',
      tablas: const ['mesas', 'tandas', 'catadores', 'muestras', 'puntuaciones', 'tanda_muestras'],
      vacio: !cargando && mesas.isEmpty && tandas.isEmpty && catadores.isEmpty,
      queHacerSiVacio: 'No hay mesas, tandas ni catadores. Elige el concurso correcto o sincroniza / revisa CLOUD.',
    );

    return Scaffold(
      appBar: AppBar(
        leading: const Padding(padding: EdgeInsets.only(left: 12), child: IconoCataris(tamano: 32, fondoOscuro: true)),
        leadingWidth: 48,
        title: const Text(MarcaApp.corto),
        bottom: cargando
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
        actions: [
          const ChipDia(),
          ChipEntorno(ampliado: !k),
          if (!esAncho(context)) ...[
            IconButton(tooltip: 'Sincronizar', onPressed: () => context.push('/sync'), icon: const Icon(Iconos.sync)),
            IconButton(
              tooltip: 'Ajustes',
              onPressed: () => context.push('/configuracion'),
              icon: const Icon(Iconos.ajustes),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () => cerrarSesion(context, ref),
              icon: const Icon(Iconos.logout),
            ),
          ],
        ],
      ),
      body:
          problema ??
          Ancho(
            max: 1100,
            child: ListView(
              padding: EdgeInsets.fromLTRB(k ? 12 : 16, k ? 10 : 14, k ? 12 : 16, k ? 16 : 24),
              children: [
                // —— Conexión visible (además del chip de la barra) ——
                _TarjetaSistema(
                  entorno: entorno,
                  conectado: conectado,
                  mensaje: msgConexion,
                  onReprobar: () => ref.invalidate(estadoConexionProvider),
                  onCambiar: () async {
                    final ok = await confirmar(
                      context,
                      'Cambiar a ${entorno.otro.largo}',
                      texto: 'Trabajarás con los datos de ${entorno.otro.corto}.',
                      si: 'Cambiar',
                    );
                    if (ok) ref.read(entornoProvider.notifier).cambiar(entorno.otro);
                  },
                ),
                SizedBox(height: k ? 12 : 16),
                // —— KPIs ——
                Text('Resumen', style: VirtusTexto.titulo(size: k ? 15 : 16)),
                SizedBox(height: k ? 8 : 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < kpis.length; i++) ...[
                        if (i > 0) SizedBox(width: k ? 8 : 10),
                        _KpiCard(kpis[i], ancho: k ? 118 : 136),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: k ? 14 : 18),
                // —— Progreso breve ——
                CajaBorde(
                  padding: EdgeInsets.symmetric(horizontal: k ? 12 : 14, vertical: k ? 10 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Progreso del día', style: VirtusTexto.titulo(size: k ? 14 : 15)),
                          ),
                          Text(
                            '$hechas%',
                            style: VirtusTexto.importante(size: k ? 18 : 20, color: Virtus.accion),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: tandas.isEmpty ? 0 : cerradas / tandas.length,
                          minHeight: k ? 8 : 10,
                          color: Virtus.accion,
                          backgroundColor: Virtus.accionSuave,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$cerradas de ${tandas.length} tandas cerradas · $abiertas abiertas',
                        style: VirtusTexto.tenue(size: k ? 11 : 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: k ? 14 : 18),
                Text('Gestión rápida', style: VirtusTexto.titulo(size: k ? 15 : 16)),
                SizedBox(height: k ? 8 : 10),
                LayoutBuilder(
                  builder: (c, box) {
                    final cols = k ? 3 : (box.maxWidth >= 900 ? 5 : 4);
                    final gap = k ? 8.0 : 10.0;
                    final ancho = (box.maxWidth - gap * (cols - 1)) / cols;
                    final alto = k ? 96.0 : 108.0;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final a in acciones) SizedBox(width: ancho, height: alto, child: _BotonGestion(a)),
                      ],
                    );
                  },
                ),
                SizedBox(height: k ? 14 : 18),
                Text('Datos DEMO', style: VirtusTexto.titulo(size: k ? 15 : 16)),
                SizedBox(height: k ? 8 : 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Virtus.error,
                          side: const BorderSide(color: Virtus.error),
                          padding: EdgeInsets.symmetric(vertical: k ? 12 : 14),
                        ),
                        onPressed: () => _borrarTodoDemo(context, ref),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Borrar todo'),
                      ),
                    ),
                    SizedBox(width: k ? 8 : 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(vertical: k ? 12 : 14)),
                        onPressed: () => _crearDatosDemo(context, ref),
                        icon: const Icon(Iconos.mas),
                        label: const Text('Crear DEMO'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'DEMO: 5 mesas · 25 catadores · 6 tandas × 22 muestras. Clave 0000.',
                  style: VirtusTexto.tenue(size: k ? 10 : 11),
                ),
              ],
            ),
          ),
    );
  }
}

/// Cliente con sesión authenticated. Reutiliza la contraseña recordada de
/// cualquiera de los dos entornos (suele ser la misma cuenta).
Future<SupabaseClient> _clienteAutenticado(WidgetRef ref, Entorno e) async {
  final b = ref.read(backendsProvider);
  final c = await b.cliente(e);
  if (c == null) {
    throw Exception('${e.corto} sin configurar (URL/clave en Configuración)');
  }
  if (c.auth.currentSession != null) return c;

  final email = ref.read(prefsProvider).getString('ultimo_email')?.trim();
  final claves = [b.passGuardada(e), b.passGuardada(e.otro)].whereType<String>().where((p) => p.isNotEmpty).toSet();

  if (email != null && email.isNotEmpty) {
    for (final pass in claves) {
      try {
        await c.auth.signInWithPassword(email: email, password: pass).timeout(const Duration(seconds: 10));
        if (c.auth.currentSession != null) return c;
      } catch (_) {}
    }
  }
  throw Exception(
    'Sin sesión en ${e.corto}. Abre Configuración, inicia sesión en ${e.corto} '
    'y marca «recordar contraseña».',
  );
}

String _msgCorto(Object e) {
  final s = e.toString();
  return s.replaceFirst(RegExp(r'^(Exception|StateError|Bad state):\s*'), '');
}

Future<void> _borrarTodoDemo(BuildContext context, WidgetRef ref) async {
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

  // Primero el entorno activo (el que estás viendo), luego el otro.
  final activo = ref.read(entornoProvider);
  final orden = [activo, activo.otro];
  final avisos = <String>[];
  var vaciados = 0;

  final bien = await ejecutar(
    context,
    () async {
      for (final e in orden) {
        try {
          final cli = await _clienteAutenticado(ref, e);
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

Future<void> _crearDatosDemo(BuildContext context, WidgetRef ref) async {
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
      final cloud = await _clienteAutenticado(ref, Entorno.cloud);
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

class _Kpi {
  const _Kpi(this.icono, this.titulo, this.valor, this.sub, this.color, this.alerta);
  final IconData icono;
  final String titulo;
  final String valor;
  final String sub;
  final Color color;
  final bool alerta;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(this.k, {required this.ancho});
  final _Kpi k;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final compacto = esCompacto(context);
    return Container(
      width: ancho,
      padding: EdgeInsets.all(compacto ? 10 : 12),
      decoration: BoxDecoration(
        color: Virtus.superficie,
        borderRadius: BorderRadius.circular(Virtus.radio),
        border: Border.all(color: k.alerta ? k.color.withValues(alpha: 0.55) : Virtus.borde),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compacto ? 26 : 30,
            height: compacto ? 26 : 30,
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, k.color, 0.12),
              borderRadius: BorderRadius.circular(Virtus.radioSm),
            ),
            child: Icon(k.icono, size: compacto ? 15 : 17, color: k.color),
          ),
          SizedBox(height: compacto ? 8 : 10),
          Text(
            k.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VirtusTexto.tenue(size: compacto ? 10 : 11),
          ),
          Text(
            k.valor,
            style: VirtusTexto.importante(size: compacto ? 18 : 22, color: Virtus.texto),
          ),
          Text(
            k.sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VirtusTexto.tenue(size: compacto ? 10 : 11),
          ),
        ],
      ),
    );
  }
}

class _Accion {
  const _Accion(this.icono, this.titulo, this.sub, this.ruta, {this.destacado = false, this.alerta = false});
  final IconData icono;
  final String titulo;
  final String sub;
  final String ruta;
  final bool destacado;
  final bool alerta;
}

class _BotonGestion extends StatelessWidget {
  const _BotonGestion(this.a);
  final _Accion a;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final fondo = a.destacado
        ? Virtus.accion
        : a.alerta
        ? Virtus.errorSuave
        : Virtus.superficie;
    final borde = a.destacado
        ? Virtus.accion
        : a.alerta
        ? Virtus.error.withValues(alpha: 0.35)
        : Virtus.borde;
    final ink = a.destacado ? Colors.white : (a.alerta ? Virtus.error : Virtus.accion);
    final texto = a.destacado ? Colors.white : Virtus.texto;
    final tenue = a.destacado ? Colors.white70 : Virtus.textoSecundario;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(Virtus.radio),
      child: InkWell(
        onTap: () => context.go(a.ruta),
        borderRadius: BorderRadius.circular(Virtus.radio),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Virtus.radio),
            border: Border.all(color: borde),
          ),
          padding: EdgeInsets.all(k ? 8 : 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(a.icono, size: k ? 26 : 28, color: ink),
                SizedBox(height: k ? 4 : 6),
                Text(
                  a.titulo,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: VirtusTexto.titulo(size: k ? 12 : 13).copyWith(color: texto),
                ),
                Text(
                  a.sub,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: VirtusTexto.tenue(size: k ? 10 : 11).copyWith(color: tenue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaSistema extends StatelessWidget {
  const _TarjetaSistema({
    required this.entorno,
    required this.conectado,
    required this.mensaje,
    required this.onReprobar,
    required this.onCambiar,
  });
  final Entorno entorno;
  final bool conectado;
  final String mensaje;
  final VoidCallback onReprobar;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final k = esCompacto(context);
    final color = conectado ? Virtus.exito : Virtus.error;
    return CajaBorde(
      padding: EdgeInsets.all(k ? 12 : 14),
      colorBorde: color.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: k ? 40 : 44,
            height: k ? 40 : 44,
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, color, 0.12),
              borderRadius: BorderRadius.circular(Virtus.radioSm),
            ),
            child: Icon(conectado ? Iconos.check : Iconos.aviso, color: color, size: k ? 22 : 24),
          ),
          SizedBox(width: k ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conectado ? 'Conectado · ${entorno.corto}' : 'Sin conexión · ${entorno.corto}',
                  style: VirtusTexto.importante(size: k ? 15 : 16, color: color),
                ),
                Text(
                  '${entorno.largo} · $mensaje',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VirtusTexto.tenue(size: k ? 11 : 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Reprobar conexión',
            onPressed: onReprobar,
            icon: const Icon(Iconos.sync, color: Virtus.marino),
          ),
          TextButton(
            onPressed: onCambiar,
            child: Text(entorno.otro.corto, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
