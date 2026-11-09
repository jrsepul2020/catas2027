import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtus_catas/core/errores.dart';

void main() {
  test('interpreta MUESTRA_APROBADA como forzable', () {
    final e = interpretarError(
      const PostgrestException(
        message: 'MUESTRA_APROBADA: esta muestra ya fue aprobada y no admite cambios',
        code: 'P0001',
      ),
    );
    expect(e.titulo, contains('aprobada'));
    expect(e.sePuedeForzar, isTrue);
    expect(e.pista, contains('forzar'));
  });

  test('interpreta unicidad de asignaciones', () {
    final e = interpretarError(
      const PostgrestException(
        message: 'duplicate key value violates unique constraint "uq_asignaciones_dia_mesa_puesto"',
        code: '23505',
      ),
    );
    expect(e.codigo, '23505');
    expect(e.titulo.toLowerCase(), contains('puesto'));
    expect(e.pista, contains('mesa'));
  });

  test('StateError de día se entiende', () {
    final e = interpretarError(StateError('Elige un día para quitar la asignación'));
    expect(e.titulo, contains('contexto'));
    expect(e.pista, contains('Elige un día'));
  });
}
