// Modelos sobre el esquema real de Catas2027 (ids enteros).

typedef Json = Map<String, dynamic>;

int _i(Object? v, [int d = 0]) {
  if (v == null) return d;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? d;
}

int? _in(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _d(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _t(Object? v) => v == null ? null : DateTime.parse(v.toString()).toLocal();

/// Texto seguro: en Cloud/web `codigo_ciego` a veces llega como int (p. ej. 3991).
String _s(Object? v, [String d = '']) => v == null ? d : v.toString();
String? _sn(Object? v) => v?.toString();

class Concurso {
  Concurso(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get nombre => _s(r['nombre']);
  bool get activo => r['activo'] ?? true;
  double get granOro => _d(r['gran_oro']) ?? 92;
  double get oro => _d(r['oro']) ?? 85;
  double get plata => _d(r['plata']) ?? 82;
  int get catadoresPorMesa => _i(r['catadores_por_mesa'], 5);
  String? get fechaInicio => _sn(r['fecha_inicio']);
  String? get fechaFin => _sn(r['fecha_fin']);
}

class Categoria {
  Categoria(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get codigo => _s(r['codigo']);
  String get nombre => _s(r['nombre']);
}

class Dia {
  Dia(this.r);
  final Json r;
  int get id => _i(r['id']);
  int get concursoId => _i(r['concurso_id']);
  String get fecha => _s(r['fecha']);
  String get nombre => _s(r['nombre']).isNotEmpty ? _s(r['nombre']) : fecha;
}

class Mesa {
  Mesa(this.r);
  final Json r;
  int get id => _i(r['id']);
  int? get concursoId => _in(r['concurso_id']);
  int get numero => _i(r['numero']);
  String get nombre => _s(r['nombre']).trim().isNotEmpty ? _s(r['nombre']).trim() : 'Mesa $numero';
}

class Catador {
  Catador(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get nombre => _s(r['nombre']);
  String get completo => [if (_s(r['titulo']).isNotEmpty) _s(r['titulo']), nombre].join(' ');
  String get iniciales {
    final p = nombre.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
  }

  String get rol => _s(r['rol'], 'catador');
  bool get esPresidente => rol == 'presidente';
  int? get mesaId => _in(r['mesa_id']);
  int? get puesto => _in(r['puesto']);
  String? get pais => _sn(r['pais_codigo']) ?? _sn(r['pais']);
  bool get presente => r['presente'] ?? true;

  /// Si false, sus notas no cuentan en la media (recordatorio de auditoría).
  bool get puntosActivos => r['puntos_activos'] ?? true;

  /// "activo" lo gestiona la app de tablets (catador conectado).
  bool get conectado => r['activo'] ?? false;
}

/// Asignación de un catador a mesa/puesto/rol en un día (solo CLOUD).
class Asignacion {
  Asignacion(this.r);
  final Json r;
  int get id => _i(r['id']);
  int get diaId => _i(r['dia_id']);
  int get catadorId => _i(r['catador_id']);
  int get mesaId => _i(r['mesa_id']);
  int get puesto => _i(r['puesto']);
  String get rol => _s(r['rol'], 'catador');
  int? get tabletId => _in(r['tablet_id']);
}

class Muestra {
  Muestra(this.r);
  final Json r;
  int get id => _i(r['id']);
  int? get concursoId => _in(r['concurso_id']);
  int? get categoriaId => _in(r['categoria_id']);
  // En Cloud puede ser text o int (p. ej. 3991 vía JS/JSON).
  String get codigo => _s(r['codigo_ciego']);
  String? get codigoTexto => _sn(r['codigo_texto']);
  bool get activa => r['activo'] ?? true;

  /// Nota libre del coordinador (columna aditiva `observaciones`).
  String? get observaciones => _sn(r['observaciones']);

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
  String get estado => _s(r['estado'], 'pendiente');
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
  String get estado => _s(r['estado'], 'pendiente');
  String? get motivo => _sn(r['incidencia_motivo']);
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
  String get estado => _s(r['estado'], 'borrador');
  bool get manual => (r['scores'] is Map) && (r['scores'] as Map)['manual'] == true;
  bool get aprobada => estado == 'aprobada';
}

class Cambio {
  Cambio(this.r);
  final Json r;
  String get id => _s(r['id']);
  String get accion => _s(r['accion']);
  String? get tabla => _sn(r['tabla']);
  String? get registroId => _sn(r['registro_id']);
  String? get motivo => _sn(r['motivo']);
  int? get diaId => _in(r['dia_id']);
  DateTime? get fecha => _t(r['creado_en']);
}

class Resultado {
  Resultado(this.r);
  final Json r;
  int get muestraId => _i(r['muestra_id']);
  int? get categoriaId => _in(r['categoria_id']);
  String get codigo => _s(r['codigo_ciego']);
  String? get codigoTexto => _sn(r['codigo_texto']);
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

/// Tablet emparejada con un catador (tabla dispositivos).
class Dispositivo {
  Dispositivo(this.r);
  final Json r;
  int get id => _i(r['id']);
  String get deviceId => r['device_id'] ?? '';
  int? get catadorId => _in(r['catador_id']);
  DateTime? get ultimaVez => _t(r['ultima_vez']);
  bool get libre => catadorId == null;
  String get corto {
    final d = deviceId;
    if (d.length <= 8) return d;
    return '…${d.substring(d.length - 6)}';
  }
}

/// Calcula resultados/medallas en la app (sirve en CLOUD y LOCAL sin depender de la vista SQL).
List<Resultado> calcularResultados({
  required List<Muestra> muestras,
  required List<Puntuacion> puntuaciones,
  required List<Json> medallas,
  required Concurso? concurso,
}) {
  final granOro = concurso?.granOro ?? 92;
  final oro = concurso?.oro ?? 85;
  final plata = concurso?.plata ?? 82;
  final porMuestra = <int, List<Puntuacion>>{};
  for (final p in puntuaciones) {
    if (p.estado != 'enviada' && p.estado != 'aprobada') continue;
    if (p.total == null) continue;
    (porMuestra[p.muestraId] ??= []).add(p);
  }
  final oficial = <int, Json>{
    for (final m in medallas)
      if (m['muestra_id'] != null) _i(m['muestra_id']): m,
  };
  final out = <Resultado>[];
  for (final m in muestras) {
    final ns = porMuestra[m.id] ?? const <Puntuacion>[];
    final vals = [for (final n in ns) n.total!];
    final media = vals.isEmpty ? null : vals.reduce((a, b) => a + b) / vals.length;
    final mediaR = media == null ? null : (media * 100).round() / 100;
    String? propuesta;
    if (mediaR != null) {
      if (m.noPremia) {
        propuesta = 'sin_medalla';
      } else if (mediaR >= granOro) {
        propuesta = 'gran_oro';
      } else if (mediaR >= oro) {
        propuesta = 'oro';
      } else if (mediaR >= plata) {
        propuesta = 'plata';
      } else {
        propuesta = 'sin_medalla';
      }
    }
    final of = oficial[m.id];
    out.add(
      Resultado({
        'muestra_id': m.id,
        'concurso_id': m.concursoId,
        'categoria_id': m.categoriaId,
        'codigo_ciego': m.codigo,
        'codigo_texto': m.codigoTexto,
        'activo': m.activa,
        'n_notas': ns.length,
        'n_aprobadas': ns.where((n) => n.aprobada).length,
        'media': mediaR,
        'minimo': vals.isEmpty ? null : vals.reduce((a, b) => a < b ? a : b),
        'maximo': vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b),
        'no_premia': m.noPremia,
        'medalla_propuesta': propuesta,
        'medalla_oficial': of?['medalla'],
        'media_oficial': of?['media_final'],
      }),
    );
  }
  return out;
}
