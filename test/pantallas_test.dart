import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtus_catas/core/providers.dart';
import 'package:virtus_catas/data/models.dart';
import 'package:virtus_catas/data/repo.dart';
import 'package:virtus_catas/ui/screens/auditoria_screen.dart';
import 'package:virtus_catas/ui/screens/catadores_screen.dart';
import 'package:virtus_catas/ui/screens/catas_screen.dart';
import 'package:virtus_catas/ui/screens/directo_screen.dart';
import 'package:virtus_catas/ui/screens/incidencias_screen.dart';
import 'package:virtus_catas/ui/screens/inicio_screen.dart';
import 'package:virtus_catas/ui/screens/medallas_screen.dart';
import 'package:virtus_catas/ui/screens/mesas_screen.dart';
import 'package:virtus_catas/ui/screens/muestras_screen.dart';
import 'package:virtus_catas/ui/screens/puntuar_screen.dart';
import 'package:virtus_catas/ui/screens/tandas_screen.dart';
import 'package:virtus_catas/ui/theme.dart';

final repoFalso = Repo(
  SupabaseClient('http://localhost:1', 'x', authOptions: const AuthClientOptions(autoRefreshToken: false)),
);

// Datos con la misma forma que Catas2027.
final datos = <String, List<Json>>{
  'concursos': [
    {
      'id': 1,
      'nombre': 'La Rábida 2027',
      'gran_oro': 93,
      'oro': 89,
      'plata': 85,
      'catadores_por_mesa': 5,
      'activo': true,
    },
  ],
  'categorias': [
    {'id': 1, 'codigo': 'vt', 'nombre': 'Vinos Tranquilos', 'ficha': {}},
    {'id': 4, 'codigo': 'ao', 'nombre': 'Aceites de Oliva Virgen Extra', 'ficha': {}},
  ],
  'dias_concurso': [
    {'id': 1, 'concurso_id': 1, 'fecha': '2027-04-01', 'nombre': 'Día 1'},
    {'id': 2, 'concurso_id': 1, 'fecha': '2027-04-02', 'nombre': 'Día 2'},
  ],
  'mesas': [
    for (var i = 1; i <= 3; i++)
      {'id': i, 'concurso_id': 1, 'numero': i, 'nombre': i == 3 ? 'Mesa 3 - AOVEs' : 'Mesa $i'},
  ],
  'catadores': [
    for (var i = 1; i <= 15; i++)
      {
        'id': i,
        'nombre': 'Catador con nombre largo $i',
        'rol': i % 5 == 1 ? 'presidente' : 'catador',
        'mesa_id': (i - 1) ~/ 5 + 1,
        'mesa': (i - 1) ~/ 5 + 1,
        'puesto': (i - 1) % 5 + 1,
        'activo': i < 4,
        'pais_codigo': 'ES',
        'presente': i != 3,
      },
  ],
  'muestras': [
    for (var i = 1; i <= 18; i++)
      {
        'id': i,
        'concurso_id': 1,
        'categoria_id': 1,
        'codigo_ciego': '${2000 + i}',
        'codigo_texto': 'REF-$i',
        'activo': true,
      },
  ],
  'tandas': [
    {'id': 1, 'mesa_id': 1, 'numero': 901, 'estado': 'abierta', 'categoria_id': 1, 'dia_id': 1, 'orden': 0},
    {'id': 2, 'mesa_id': 1, 'numero': 902, 'estado': 'pendiente', 'categoria_id': 1, 'dia_id': 1, 'orden': 1},
    {'id': 3, 'mesa_id': 2, 'numero': 903, 'estado': 'pendiente', 'categoria_id': 1, 'dia_id': 1, 'orden': 0},
  ],
  'tanda_muestras': [
    for (var i = 1; i <= 9; i++)
      {
        'id': i,
        'tanda_id': (i - 1) ~/ 3 + 1,
        'muestra_id': i,
        'orden': (i - 1) % 3 + 1,
        'estado': i == 1 ? 'completada' : (i == 2 ? 'activa' : (i == 3 ? 'incidencia' : 'pendiente')),
        'incidencia_motivo': i == 3 ? 'Corcho / TCA' : null,
      },
  ],
  'puntuaciones': [
    for (var c = 1; c <= 5; c++)
      {'id': c, 'catador_id': c, 'muestra_id': 1, 'tanda_id': 1, 'scores': {}, 'total': 85 + c, 'estado': 'aprobada'},
    {'id': 6, 'catador_id': 1, 'muestra_id': 2, 'tanda_id': 1, 'scores': {}, 'total': 88.5, 'estado': 'enviada'},
  ],
  'medallas': [],
  'dispositivos': [
    for (var i = 1; i <= 13; i++)
      {'id': i, 'device_id': 'TAB-$i', 'catador_id': i, 'ultima_vez': '2027-04-01T10:00:00Z'},
    {'id': 14, 'device_id': 'RESERVA-1', 'catador_id': null, 'ultima_vez': '2027-04-01T08:00:00Z'},
    {'id': 15, 'device_id': 'RESERVA-2', 'catador_id': null, 'ultima_vez': '2027-04-01T08:00:00Z'},
  ],
  'registro_cambios': [
    {
      'id': 'a',
      'accion': 'cambio_puesto',
      'tabla': 'catadores',
      'motivo': 'Intercambio de puestos',
      'creado_en': '2027-04-01T09:00:00Z',
    },
  ],
};

Future<void> montar(WidgetTester tester, Widget pantalla, Size size) async {
  SharedPreferences.setMockInitialValues({'dia_cloud': 1, 'activo': 'cloud'});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        repoProvider.overrideWithValue(repoFalso),
        filasProvider.overrideWith((ref, tabla) => Stream.value(datos[tabla] ?? const [])),
        resultadosProvider.overrideWith(
          (ref) => [
            Resultado({
              'muestra_id': 1,
              'categoria_id': 1,
              'codigo_ciego': '2001',
              'codigo_texto': 'REF-1',
              'n_notas': 5,
              'n_aprobadas': 5,
              'media': 88.0,
              'minimo': 86,
              'maximo': 90,
              'no_premia': false,
              'medalla_propuesta': 'plata',
            }),
          ],
        ),
        // Tabletas: 13 emparejadas + 2 de reserva.
        // (filasProvider ya cubre 'dispositivos' vía datos si se añade)
      ],
      child: MaterialApp(
        theme: tema(compacto: size.shortestSide < 600),
        home: pantalla,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final pantallas = <String, Widget>{
    'inicio': const InicioScreen(),
    'en directo': const DirectoScreen(),
    'concursos': const CatasScreen(),
    'mesas': const MesasScreen(),
    'mesa detalle': const MesaDetalleScreen(id: 1),
    'tandas': const TandasScreen(),
    'tanda detalle': const TandaDetalleScreen(id: 1),
    'catadores': const CatadoresScreen(),
    'muestras': const MuestrasScreen(),
    'notas': const PuntuarScreen(),
    'hoja de notas': const HojaPuntuacionScreen(tandaId: 1),
    'medallas': const MedallasScreen(),
    'auditoria': const AuditoriaScreen(),
    'incidencias': const IncidenciasScreen(),
  };
  for (final size in const [Size(393, 873), Size(800, 1280), Size(1280, 800)]) {
    for (final e in pantallas.entries) {
      testWidgets('${e.key} @ ${size.width.toInt()}', (tester) async {
        await montar(tester, e.value, size);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('puntuaciones: muestra notas y edita en ventana modal', (tester) async {
    await montar(tester, const HojaPuntuacionScreen(tandaId: 1), const Size(393, 873));
    expect(find.text('88,5'), findsNWidgets(2)); // nota de tablet + total de la fila
    expect(find.text('2001'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    // Celda vacía de la muestra 2002 (puesto 2) -> abre la ventana de nota.
    await tester.tap(find.text('88,5').first);
    await tester.pumpAndSettle();
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '9'));
    await tester.tap(find.widgetWithText(FilledButton, '1'));
    await tester.pump();
    expect(find.text('91'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Guardar'), findsNothing);
  });

  testWidgets('inicio: las 9 baldosas caben sin scroll en el Redmi', (tester) async {
    await montar(tester, const InicioScreen(), const Size(393, 873));
    for (final t in [
      'En directo',
      'Mesas',
      'Puntuaciones',
      'Tandas',
      'Incidencias',
      'Catadores',
      'Muestras',
      'Medallas',
      'Auditoría',
    ]) {
      expect(find.text(t).hitTestable(), findsOneWidget, reason: t);
    }
  });

  testWidgets('incidencias: lista la muestra con incidencia abierta', (tester) async {
    await montar(tester, const IncidenciasScreen(), const Size(375, 812));
    expect(find.text('Muestra 2003'), findsOneWidget);
    expect(find.text('Corcho / TCA'), findsOneWidget);
  });

  testWidgets('mesa detalle: presidente y ausente', (tester) async {
    await montar(tester, const MesaDetalleScreen(id: 1), const Size(1280, 800));
    expect(find.text('Presidente'), findsOneWidget);
    expect(find.text('Ausente'), findsOneWidget);
  });
}
