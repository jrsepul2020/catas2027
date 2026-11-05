// Modelos ligeros (sin generación de código) para máxima velocidad de build.

typedef Json = Map<String, dynamic>;

int _i(Object? v, [int d = 0]) => v == null ? d : (v as num).toInt();
double? _d(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _t(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

bool vivo(Json r) => r['deleted_at'] == null;

class Cata {
  Cata(this.r);
  final Json r;
  String get id => r['id'];
  String get nombre => r['nombre'] ?? '';
  String? get lugar => r['lugar'];
  String? get fecha => r['fecha'];
  bool get activa => r['activa'] ?? true;
  double get umbralGranOro => _d(r['umbral_gran_oro']) ?? 92;
  double get umbralOro => _d(r['umbral_oro']) ?? 85;
  double get umbralPlata => _d(r['umbral_plata']) ?? 82;
  double? get umbralBronce => _d(r['umbral_bronce']);
  double get escalaMax => _d(r['escala_max']) ?? 100;
  bool get descartarExtremos => r['descartar_extremos'] ?? false;
}

class Mesa {
  Mesa(this.r);
  final Json r;
  String get id => r['id'];
  int get numero => _i(r['numero']);
  String get nombre => (r['nombre'] as String?)?.trim().isNotEmpty == true ? r['nombre'] : 'Mesa $numero';
  String? get sala => r['sala'];
  String get estado => r['estado'] ?? 'preparada';
}

class Catador {
  Catador(this.r);
  final Json r;
  String get id => r['id'];
  String get nombre => r['nombre'] ?? '';
  String? get apellidos => r['apellidos'];
  String get completo => [nombre, apellidos ?? ''].join(' ').trim();
  String get iniciales {
    final p = completo.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
  }

  String? get email => r['email'];
  String? get telefono => r['telefono'];
  String? get mesaId => r['mesa_id'];
  int? get puesto => r['puesto'] == null ? null : _i(r['puesto']);
  bool get esPresidente => r['es_presidente'] ?? false;
  bool get presente => r['presente'] ?? true;
}

class Muestra {
  Muestra(this.r);
  final Json r;
  String get id => r['id'];
  String get codigo => r['codigo'] ?? '';
  String? get nombre => r['nombre'];
  String? get bodega => r['bodega'];
  String? get categoria => r['categoria'];
  String? get tipo => r['tipo'];
  int? get anada => r['anada'] == null ? null : _i(r['anada']);
  String? get medallaManual => r['medalla_manual'];
  String get titulo => [codigo, if (nombre?.isNotEmpty == true) nombre].join(' · ');
}

class Tanda {
  Tanda(this.r);
  final Json r;
  String get id => r['id'];
  String? get mesaId => r['mesa_id'];
  String get nombre => (r['nombre'] as String?)?.isNotEmpty == true ? r['nombre'] : 'Tanda ${orden + 1}';
  int get orden => _i(r['orden']);
  String get estado => r['estado'] ?? 'pendiente';
  DateTime? get inicio => _t(r['inicio_at']);
  DateTime? get fin => _t(r['fin_at']);
}

class TandaMuestra {
  TandaMuestra(this.r);
  final Json r;
  String get id => r['id'];
  String get tandaId => r['tanda_id'];
  String get muestraId => r['muestra_id'];
  int get orden => _i(r['orden']);
}

class Puntuacion {
  Puntuacion(this.r);
  final Json r;
  String get id => r['id'];
  String get muestraId => r['muestra_id'];
  String get catadorId => r['catador_id'];
  String? get tandaId => r['tanda_id'];
  double? get puntos => _d(r['puntos']);
  String? get comentario => r['comentario'];
  bool get anulada => r['anulada'] ?? false;
}

class Incidencia {
  Incidencia(this.r);
  final Json r;
  String get id => r['id'];
  String get tipo => r['tipo'] ?? 'otro';
  String get prioridad => r['prioridad'] ?? 'media';
  String? get descripcion => r['descripcion'];
  String get estado => r['estado'] ?? 'abierta';
  String? get mesaId => r['mesa_id'];
  String? get tandaId => r['tanda_id'];
  String? get muestraId => r['muestra_id'];
  String? get catadorId => r['catador_id'];
  DateTime? get creada => _t(r['created_at']);
  DateTime? get resuelta => _t(r['resuelta_at']);
}

class Resultado {
  Resultado(this.r);
  final Json r;
  String get muestraId => r['muestra_id'];
  String get codigo => r['codigo'] ?? '';
  String? get nombre => r['nombre'];
  String? get bodega => r['bodega'];
  String? get categoria => r['categoria'];
  int get n => _i(r['n_puntuaciones']);
  double? get nota => _d(r['nota_final']);
  double? get media => _d(r['media']);
  double? get minimo => _d(r['minimo']);
  double? get maximo => _d(r['maximo']);
  String? get medalla => r['medalla'];
  bool get manual => r['medalla_es_manual'] ?? false;
}
