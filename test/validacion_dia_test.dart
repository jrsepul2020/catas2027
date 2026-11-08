import 'package:flutter_test/flutter_test.dart';
import 'package:virtus_catas/data/models.dart';
import 'package:virtus_catas/sync/validacion_dia.dart';

void main() {
  test('numeroTablet: mesa 1 puesto 1 → 1; mesa 2 puesto 3 → 8', () {
    expect(numeroTablet(numeroMesa: 1, puesto: 1), 1);
    expect(numeroTablet(numeroMesa: 1, puesto: 5), 5);
    expect(numeroTablet(numeroMesa: 2, puesto: 3), 8);
    expect(numeroTablet(numeroMesa: 3, puesto: 1), 11);
  });

  test('validarDiaParaBajar: día coherente sin problemas', () {
    final mesas = [
      for (var i = 1; i <= 2; i++) Mesa({'id': i, 'numero': i, 'nombre': 'Mesa $i', 'concurso_id': 1}),
    ];
    final asigs = [
      for (var i = 1; i <= 10; i++)
        {
          'dia_id': 1,
          'catador_id': i,
          'mesa_id': (i - 1) ~/ 5 + 1,
          'puesto': (i - 1) % 5 + 1,
          'rol': i % 5 == 1 ? 'presidente' : 'catador',
        },
    ];
    final tandas = [
      Tanda({'id': 1, 'mesa_id': 1, 'numero': 1, 'dia_id': 1, 'categoria_id': 1, 'estado': 'pendiente'}),
    ];
    final tms = [
      TandaMuestra({'id': 1, 'tanda_id': 1, 'muestra_id': 10, 'orden': 1, 'estado': 'pendiente'}),
    ];
    final muestras = [
      Muestra({'id': 10, 'codigo_ciego': '2001', 'categoria_id': 1, 'activo': true}),
    ];
    final cats = [
      Categoria({'id': 1, 'codigo': 'vt', 'nombre': 'Vinos', 'ficha': {}}),
    ];
    final p = validarDiaParaBajar(
      diaId: 1,
      mesas: mesas,
      asignaciones: asigs,
      tandas: tandas,
      tandaMuestras: tms,
      muestras: muestras,
      categorias: cats,
    );
    expect(p, isEmpty);
  });

  test('validarDiaParaBajar: detecta dos presidentes y muestra duplicada', () {
    final mesas = [
      Mesa({'id': 1, 'numero': 1, 'nombre': 'Mesa 1', 'concurso_id': 1}),
    ];
    final asigs = [
      for (var i = 1; i <= 5; i++)
        {'dia_id': 1, 'catador_id': i, 'mesa_id': 1, 'puesto': i, 'rol': i <= 2 ? 'presidente' : 'catador'},
    ];
    final tandas = [
      Tanda({'id': 1, 'mesa_id': 1, 'numero': 1, 'dia_id': 1, 'categoria_id': 1, 'estado': 'pendiente'}),
      Tanda({'id': 2, 'mesa_id': 1, 'numero': 2, 'dia_id': 1, 'categoria_id': 1, 'estado': 'pendiente'}),
    ];
    final tms = [
      TandaMuestra({'id': 1, 'tanda_id': 1, 'muestra_id': 10, 'orden': 1, 'estado': 'pendiente'}),
      TandaMuestra({'id': 2, 'tanda_id': 2, 'muestra_id': 10, 'orden': 1, 'estado': 'pendiente'}),
    ];
    final muestras = [
      Muestra({'id': 10, 'codigo_ciego': '2001', 'categoria_id': 1, 'activo': true}),
    ];
    final cats = [
      Categoria({'id': 1, 'codigo': 'vt', 'nombre': 'Vinos', 'ficha': {}}),
    ];
    final p = validarDiaParaBajar(
      diaId: 1,
      mesas: mesas,
      asignaciones: asigs,
      tandas: tandas,
      tandaMuestras: tms,
      muestras: muestras,
      categorias: cats,
    );
    expect(p.any((x) => x.contains('presidentes')), isTrue);
    expect(p.any((x) => x.contains('dos tandas')), isTrue);
  });
}
