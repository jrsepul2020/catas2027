import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'ui/screens/ajustes_screen.dart';
import 'ui/screens/auditoria_screen.dart';
import 'ui/screens/catadores_screen.dart';
import 'ui/screens/catas_screen.dart';
import 'ui/screens/incidencias_screen.dart';
import 'ui/screens/directo_screen.dart';
import 'ui/screens/inicio_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/medallas_screen.dart';
import 'ui/screens/mesas_screen.dart';
import 'ui/screens/muestras_screen.dart';
import 'ui/screens/puntuar_screen.dart';
import 'ui/screens/shell.dart';
import 'ui/screens/sync_screen.dart';
import 'ui/screens/tandas_screen.dart';
import 'ui/theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refrescar = ValueNotifier(0);
  ref.listen(sesionProvider, (_, _) => refrescar.value++);
  ref.listen(concursoIdProvider, (_, _) => refrescar.value++);
  ref.listen(concursosCargadosProvider, (_, _) => refrescar.value++);
  ref.listen(clienteProvider, (_, _) => refrescar.value++);
  ref.onDispose(refrescar.dispose);

  const libres = {'/configuracion', '/login'};

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refrescar,
    redirect: (context, st) {
      final loc = st.matchedLocation;
      final cli = ref.read(clienteProvider);
      final ses = ref.read(sesionProvider);
      final sinLogin = ref.read(omitirLoginProvider);
      if (cli.isLoading || (!sinLogin && ses.isLoading)) return loc == '/carga' ? null : '/carga';
      if (cli.value == null) return loc == '/configuracion' ? null : '/configuracion';
      if (!sinLogin && ses.value == null) return libres.contains(loc) ? null : '/login';
      // Con omitir-login se puede abrir /login para autenticarse (RLS).
      // Solo salir de /login cuando ya hay sesión.
      if (loc == '/carga') return '/';
      if (loc == '/login' && ses.value != null) return '/';
      // Varios concursos y ninguno elegido: pantalla de elección.
      final sinConcurso = ref.read(concursosCargadosProvider) && ref.read(concursoIdProvider) == null;
      if (sinConcurso && !{'/catas', '/configuracion', '/sync'}.contains(loc)) return '/catas';
      return null;
    },
    routes: [
      GoRoute(
        path: '/carga',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/configuracion', builder: (_, _) => const AjustesScreen()),
      GoRoute(path: '/catas', builder: (_, _) => const CatasScreen()),
      GoRoute(path: '/sync', builder: (_, _) => const SyncScreen()),
      ShellRoute(
        builder: (_, st, child) => Shell(ubicacion: st.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const InicioScreen()),
          GoRoute(path: '/directo', builder: (_, _) => const DirectoScreen()),
          GoRoute(
            path: '/mesas',
            builder: (_, _) => const MesasScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => MesaDetalleScreen(id: int.tryParse(s.pathParameters['id']!) ?? 0),
              ),
            ],
          ),
          GoRoute(
            path: '/tandas',
            builder: (_, _) => const TandasScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => TandaDetalleScreen(id: int.tryParse(s.pathParameters['id']!) ?? 0),
              ),
            ],
          ),
          GoRoute(path: '/catadores', builder: (_, _) => const CatadoresScreen()),
          GoRoute(path: '/muestras', builder: (_, _) => const MuestrasScreen()),
          GoRoute(
            path: '/puntuar',
            builder: (_, _) => const PuntuarScreen(),
            routes: [
              GoRoute(
                path: ':tanda',
                builder: (_, s) => HojaPuntuacionScreen(tandaId: int.tryParse(s.pathParameters['tanda']!) ?? 0),
              ),
            ],
          ),
          GoRoute(path: '/medallas', builder: (_, _) => const MedallasScreen()),
          GoRoute(path: '/auditoria', builder: (_, _) => const AuditoriaScreen()),
          GoRoute(path: '/incidencias', builder: (_, _) => const IncidenciasScreen()),
        ],
      ),
    ],
  );
});

class VirtusCatasApp extends ConsumerWidget {
  const VirtusCatasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'CATARIS',
    debugShowCheckedModeBanner: false,
    // Siempre tema claro (paleta fija) y compacto en teléfono.
    theme: tema(),
    themeMode: ThemeMode.light,
    builder: (context, child) {
      final compacto = MediaQuery.sizeOf(context).shortestSide < 600;
      return Theme(
        data: tema(compacto: compacto),
        child: child!,
      );
    },
    routerConfig: ref.watch(routerProvider),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  );
}
