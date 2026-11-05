import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtus_catas/core/providers.dart';
import 'package:virtus_catas/data/models.dart';
import 'package:virtus_catas/data/repo.dart';
import 'package:virtus_catas/ui/screens/catadores_screen.dart';
import 'package:virtus_catas/ui/screens/incidencias_screen.dart';
import 'package:virtus_catas/ui/screens/inicio_screen.dart';
import 'package:virtus_catas/ui/screens/medallas_screen.dart';
import 'package:virtus_catas/ui/screens/mesas_screen.dart';
import 'package:virtus_catas/ui/screens/puntuar_screen.dart';
import 'package:virtus_catas/ui/screens/tandas_screen.dart';
import 'package:virtus_catas/ui/theme.dart';

const cata = 'c1';
final repoFalso = Repo(
  SupabaseClient('http://localhost:1', 'x', authOptions: const AuthClientOptions(autoRefreshToken: false)),
);
String mid(int i) => 'mesa$i';
String tid(int m, int t) => 't$m-$t';

final datos = <String, List<Json>>{
  'mesas': [
    for (var i = 1; i <= 3; i++)
      {'id': mid(i), 'cata_id': cata, 'numero': i, 'estado': i == 1 ? 'catando' : 'preparada'},
  ],
  'catadores': [
    for (var i = 0; i < 15; i++)
      {
        'id': 'cat$i',
        'cata_id': cata,
        'nombre': 'Catador',
        'apellidos': 'Apellido Largo Número $i',
        'mesa_id': mid(i ~/ 5 + 1),
        'puesto': i % 5 + 1,
        'presente': i != 3,
      },
  ],
  'muestras': [
    for (var i = 0; i < 18; i++)
      {'id': 'mu$i', 'cata_id': cata, 'codigo': 'M${i.toString().padLeft(3, '0')}', 'nombre': 'Vino $i'},
  ],
  'tandas': [
    for (var m = 1; m <= 3; m++)
      for (var t = 0; t < 2; t++)
        {'id': tid(m, t), 'cata_id': cata, 'mesa_id': mid(m), 'orden': t, 'estado': t == 0 ? 'en_curso' : 'pendiente'},
  ],
  'tanda_muestras': [
    for (var i = 0; i < 18; i++)
      {'id': 'tm$i', 'cata_id': cata, 'tanda_id': tid(i ~/ 6 + 1, (i % 6) ~/ 3), 'muestra_id': 'mu$i', 'orden': i % 3},
  ],
  'puntuaciones': [
    {'id': 'p1', 'cata_id': cata, 'muestra_id': 'mu0', 'catador_id': 'cat0', 'puntos': 88.5},
    {'id': 'p2', 'cata_id': cata, 'muestra_id': 'mu0', 'catador_id': 'cat1', 'puntos': 90},
  ],
  'incidencias': [
    {
      'id': 'i1',
      'cata_id': cata,
      'tipo': 'corcho',
      'prioridad': 'alta',
      'estado': 'abierta',
      'mesa_id': mid(1),
      'descripcion': 'Muestra con TCA',
      'created_at': '2027-03-15T10:00:00Z',
    },
  ],
};

Future<void> montar(WidgetTester tester, Widget pantalla, Size size) async {
  SharedPreferences.setMockInitialValues({'cata_local': cata});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        repoProvider.overrideWithValue(repoFalso),
        filasProvider.overrideWith((ref, k) => Stream.value(datos[k.$1] ?? const [])),
        catasProvider.overrideWith(
          (ref) => Stream.value([
            Cata({'id': cata, 'nombre': 'Catas Virtus 2027', 'lugar': 'Sede', 'fecha': '2027-03-15'}),
          ]),
        ),
        resultadosProvider.overrideWith(
          (ref) async => [
            Resultado({
              'muestra_id': 'mu0',
              'codigo': 'M000',
              'nombre': 'Vino 0',
              'n_puntuaciones': 2,
              'nota_final': 89.25,
              'medalla': 'oro',
              'minimo': 88.5,
              'maximo': 90,
            }),
          ],
        ),
      ],
      child: MaterialApp(theme: tema(Brightness.light), home: pantalla),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  final pantallas = <String, Widget>{
    'inicio': const InicioScreen(),
    'mesas': const MesasScreen(),
    'mesa detalle': MesaDetalleScreen(id: mid(1)),
    'tandas': const TandasScreen(),
    'tanda detalle': TandaDetalleScreen(id: tid(1, 0)),
    'catadores': const CatadoresScreen(),
    'puntuar': const PuntuarScreen(),
    'hoja puntuación': HojaPuntuacionScreen(tandaId: tid(1, 0)),
    'medallas': const MedallasScreen(),
    'incidencias': const IncidenciasScreen(),
  };
  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    for (final e in pantallas.entries) {
      testWidgets('${e.key} @ ${size.width.toInt()}', (tester) async {
        await montar(tester, e.value, size);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('teclado de puntuación muestra lo tecleado', (tester) async {
    await montar(tester, HojaPuntuacionScreen(tandaId: tid(1, 0)), const Size(375, 812));
    expect(find.text('88,5'), findsOneWidget); // nota existente
    await tester.tap(find.widgetWithText(FilledButton, '8'));
    await tester.tap(find.widgetWithText(FilledButton, '7'));
    await tester.pump();
    expect(find.text('87'), findsWidgets);
  });
}
