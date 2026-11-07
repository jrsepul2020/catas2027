// Modelos sobre el esquema real de Catas2027 (ids enteros).

typedef Json = Map<String, dynamic>;

int _i(Object? v, [int d = 0]) => v == null ? d : (v as num).toInt();
int? _in(Object? v) => v == null ? null : (v as num).toInt();
double? _d(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _t(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

class Concurso {
  Concurso(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get nombre => r['nombre'] ?? '';
  bool get activo => r['activo'] ?? true;
  double get granOro => _d(r['gran_oro']) ?? 92;
  double get oro => _d(r['oro']) ?? 85;
  double get plata => _d(r['plata']) ?? 82;
  int get catadoresPorMesa => _i(r['catadores_por_mesa'], 5);
  String? get fechaInicio => r['fecha_inicio'];
  String? get fechaFin => r['fecha_fin'];
}

class Categoria {
  Categoria(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get codigo => r['codigo'] ?? '';
  String get nombre => r['nombre'] ?? '';
}

class Dia {
  Dia(this.r);
  final Json r;
  int get id => _i(r['id']);
  int get concursoId => _i(r['concurso_id']);
  String get fecha => r['fecha'] ?? '';
  String get nombre => (r['nombre'] as String?)?.isNotEmpty == true ? r['nombre'] : fecha;
}

class Mesa {
  Mesa(this.r);
  final Json r;
  int get id => _i(r['id']);
  int? get concursoId => _in(r['concurso_id']);
  int get numero => _i(r['numero']);
  String get nombre => (r['nombre'] as String?)?.trim().isNotEmpty == true ? r['nombre'] : 'Mesa $numero';
}

class Catador {
  Catador(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get nombre => r['nombre'] ?? '';
  String get completo => [if ((r['titulo'] as String?)?.isNotEmpty == true) r['titulo'], nombre].join(' ');
  String get iniciales {
    final p = nombre.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
  }

  String get rol => r['rol'] ?? 'catador';
  bool get esPresidente => rol == 'presidente';
  int? get mesaId => _in(r['mesa_id']);
  int? get puesto => _in(r['puesto']);
  String? get pais => (r['pais_codigo'] as String?) ?? (r['pais'] as String?);
  bool get presente => r['presente'] ?? true;

  /// "activo" lo gestiona la app de tablets (catador conectado).
  bool get conectado => r['activo'] ?? false;
}

class Muestra {
  Muestra(this.r);
  final Json r;
  int get id => _i(r['id']);
  int? get concursoId => _in(r['concurso_id']);
  int? get categoriaId => _in(r['categoria_id']);
  String get codigo => r['codigo_ciego'] ?? '';
  String? get codigoTexto => r['codigo_texto'];
  bool get activa => r['activo'] ?? true;

  /// Códigos numéricos < 1000: muestras manuales, se catan pero no premian.
  bool get noPremia {
    final n = int.tryParse(codigo);
    return n != null && n < 1000;
  }

  String get titulo => codigoTexto != null && codigoTexto != codigo ? '$codigo · $codigoTexto' : codigo;
}

class Tanda {
  Tanda(this.r);
  final Json r;
  int get id => _i(r['id']);
  int? get mesaId => _in(r['mesa_id']);
  int get numero => _i(r['numero']);
  String get nombre => 'Tanda $numero';
  String get estado => r['estado'] ?? 'pendiente';
  int? get categoriaId => _in(r['categoria_id']);
  int? get diaId => _in(r['dia_id']);
  int get orden => _in(r['orden']) ?? numero;
}

class TandaMuestra {
  TandaMuestra(this.r);
  final Json r;
  int get id => _i(r['id']);
  int get tandaId => _i(r['tanda_id']);
  int get muestraId => _i(r['muestra_id']);
  int get orden => _i(r['orden']);
  String get estado => r['estado'] ?? 'pendiente';
  String? get motivo => r['incidencia_motivo'];
  bool get conIncidencia => estado == 'incidencia';
}

class Puntuacion {
  Puntuacion(this.r);
  final Json r;
  int get id => _i(r['id']);
  int get muestraId => _i(r['muestra_id']);
  int get catadorId => _i(r['catador_id']);
  int get tandaId => _i(r['tanda_id']);
  double? get total => _d(r['total']);
  String get estado => r['estado'] ?? 'borrador';
  bool get manual => (r['scores'] is Map) && (r['scores'] as Map)['manual'] == true;
  bool get aprobada => estado == 'aprobada';
}

class Cambio {
  Cambio(this.r);
  final Json r;
  String get id => r['id'];
  String get accion => r['accion'] ?? '';
  String? get tabla => r['tabla'];
  String? get registroId => r['registro_id'];
  String? get motivo => r['motivo'];
  int? get diaId => _in(r['dia_id']);
  DateTime? get fecha => _t(r['creado_en']);
}

class Resultado {
  Resultado(this.r);
  final Json r;
  int get muestraId => _i(r['muestra_id']);
  int? get categoriaId => _in(r['categoria_id']);
  String get codigo => r['codigo_ciego'] ?? '';
  String? get codigoTexto => r['codigo_texto'];
  int get n => _i(r['n_notas']);
  int get nAprobadas => _i(r['n_aprobadas']);
  double? get media => _d(r['media']);
  double? get minimo => _d(r['minimo']);
  double? get maximo => _d(r['maximo']);
  bool get noPremia => r['no_premia'] ?? false;
  String? get propuesta => r['medalla_propuesta'];
  String? get oficial => r['medalla_oficial'];
  String? get medalla => oficial ?? propuesta;
}
