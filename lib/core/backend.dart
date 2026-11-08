import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Los dos entornos que gestiona la app.
enum Entorno {
  cloud('CLOUD', 'Supabase Cloud'),
  local('LOCAL', 'Supabase Local');

  const Entorno(this.corto, this.largo);
  final String corto;
  final String largo;

  Entorno get otro => this == Entorno.cloud ? Entorno.local : Entorno.cloud;

  /// Claves usadas en config/entornos.json y en --dart-define.
  String get claveUrl => '${corto}_URL';
  String get claveKey => '${corto}_ANON_KEY';
}

/// Clave anon "demo" que usa siempre `supabase start` en local.
const _anonLocalDemo =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDjblYTn_I0';

/// Valores incrustados al compilar con
/// `--dart-define-from-file=config/entornos.json` (ver tool/build_apk.sh).
abstract final class ConfigBuild {
  static const cloudUrl = String.fromEnvironment('CLOUD_URL');
  static const cloudKey = String.fromEnvironment('CLOUD_ANON_KEY');
  static const localUrl = String.fromEnvironment('LOCAL_URL');
  static const localKey = String.fromEnvironment('LOCAL_ANON_KEY');
  static const entornoInicial = String.fromEnvironment('ENTORNO_INICIAL');
}

enum OrigenConfig {
  build('Incluida en la app'),
  dispositivo('Editada en este dispositivo'),
  porDefecto('Valor por defecto'),
  vacia('Sin configurar');

  const OrigenConfig(this.texto);
  final String texto;
}

class ConfigEntorno {
  const ConfigEntorno({required this.url, required this.anonKey, this.origen = OrigenConfig.dispositivo});
  final String url;
  final String anonKey;
  final OrigenConfig origen;

  String get urlLimpia => url.trim().replaceAll(RegExp(r'/+$'), '');

  bool get completa {
    final u = Uri.tryParse(urlLimpia);
    return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty && anonKey.trim().isNotEmpty;
  }

  /// Configuración de fábrica: la del build y, si no hay, un valor razonable.
  static ConfigEntorno deFabrica(Entorno e) {
    switch (e) {
      case Entorno.cloud:
        return ConfigEntorno(
          url: ConfigBuild.cloudUrl,
          anonKey: ConfigBuild.cloudKey,
          origen: ConfigBuild.cloudUrl.isEmpty ? OrigenConfig.vacia : OrigenConfig.build,
        );
      case Entorno.local:
        if (ConfigBuild.localUrl.isNotEmpty) {
          return ConfigEntorno(
            url: ConfigBuild.localUrl,
            anonKey: ConfigBuild.localKey.isNotEmpty ? ConfigBuild.localKey : _anonLocalDemo,
            origen: OrigenConfig.build,
          );
        }
        return ConfigEntorno(
          url: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? 'http://10.0.2.2:54321' // emulador Android -> ordenador
              : 'http://127.0.0.1:54321',
          anonKey: _anonLocalDemo,
          origen: OrigenConfig.porDefecto,
        );
    }
  }
}

class ResultadoPrueba {
  const ResultadoPrueba(this.ok, this.mensaje);
  final bool ok;
  final String mensaje;
}

/// Comprueba que la URL responde y que la clave es válida (sin iniciar sesión).
Future<ResultadoPrueba> probarConexion(ConfigEntorno c) async {
  if (!c.completa) return const ResultadoPrueba(false, 'URL o clave vacías / URL no válida');
  final t0 = DateTime.now();
  try {
    final r = await http
        .get(Uri.parse('${c.urlLimpia}/auth/v1/settings'), headers: {'apikey': c.anonKey.trim()})
        .timeout(const Duration(seconds: 6));
    final ms = DateTime.now().difference(t0).inMilliseconds;
    if (r.statusCode == 200) return ResultadoPrueba(true, 'Conectado ($ms ms)');
    if (r.statusCode == 401 || r.statusCode == 403) {
      return const ResultadoPrueba(false, 'El servidor responde pero la clave no es válida');
    }
    return ResultadoPrueba(false, 'El servidor respondió ${r.statusCode}');
  } on TimeoutException {
    return const ResultadoPrueba(false, 'Sin respuesta en 6 s. ¿Misma red WiFi? ¿Está arrancado?');
  } catch (_) {
    return const ResultadoPrueba(
      false,
      'No se pudo conectar. Revisa la URL, que el servidor esté arrancado y que estés en la misma red WiFi.',
    );
  }
}

/// Mantiene un [SupabaseClient] por entorno, con la sesión persistida.
/// Ambos clientes pueden estar vivos a la vez (necesario para sincronizar).
class Backends {
  Backends(this._prefs);
  final SharedPreferences _prefs;
  final Map<Entorno, SupabaseClient> _clientes = {};
  final Map<Entorno, StreamSubscription<AuthState>> _subs = {};

  /// Config efectiva: lo editado en el dispositivo manda sobre la de fábrica.
  ConfigEntorno config(Entorno e) {
    final url = _prefs.getString('url_${e.name}');
    final key = _prefs.getString('key_${e.name}');
    if (url == null && key == null) return ConfigEntorno.deFabrica(e);
    final fab = ConfigEntorno.deFabrica(e);
    return ConfigEntorno(url: url ?? fab.url, anonKey: key ?? fab.anonKey, origen: OrigenConfig.dispositivo);
  }

  /// Guarda URL/clave en este dispositivo. Solo reinicia el cliente si cambian.
  Future<void> guardarConfig(Entorno e, ConfigEntorno c, {bool reiniciarCliente = true}) async {
    final antes = config(e);
    await _prefs.setString('url_${e.name}', c.urlLimpia);
    await _prefs.setString('key_${e.name}', c.anonKey.trim());
    final cambio = antes.urlLimpia != c.urlLimpia || antes.anonKey.trim() != c.anonKey.trim();
    if (reiniciarCliente && cambio) await _reiniciar(e);
  }

  /// Vuelve a la configuración incluida en la app.
  Future<void> restaurar(Entorno e) async {
    await _prefs.remove('url_${e.name}');
    await _prefs.remove('key_${e.name}');
    await _reiniciar(e);
  }

  Future<void> _reiniciar(Entorno e) async {
    await _cerrar(e);
    await _prefs.remove('ses_${e.name}');
  }

  // ---------- Contraseña recordada en este dispositivo ----------
  bool recordarPass(Entorno e) => _prefs.getBool('guardar_pass_${e.name}') ?? false;

  String? passGuardada(Entorno e) => recordarPass(e) ? _prefs.getString('pass_${e.name}') : null;

  Future<void> setRecordarPass(Entorno e, {required bool recordar, String? pass}) async {
    await _prefs.setBool('guardar_pass_${e.name}', recordar);
    if (recordar && pass != null && pass.isNotEmpty) {
      await _prefs.setString('pass_${e.name}', pass);
    } else {
      await _prefs.remove('pass_${e.name}');
    }
  }

  /// Sube CLOUD/LOCAL (URL + anon) al perfil Auth del usuario logueado.
  Future<void> subirConexionesAlUsuario(SupabaseClient c) async {
    if (c.auth.currentUser == null) return;
    final cfg = <String, dynamic>{
      for (final e in Entorno.values)
        if (config(e).completa) e.name: {'url': config(e).urlLimpia, 'key': config(e).anonKey.trim()},
    };
    if (cfg.isEmpty) return;
    final data = Map<String, dynamic>.from(c.auth.currentUser!.userMetadata ?? {});
    data['virtus_conexiones'] = cfg;
    await c.auth.updateUser(UserAttributes(data: data));
  }

  /// Tras el login: trae al dispositivo las conexiones del usuario.
  /// No reinicia el entorno de la sesión actual (evitar perder el login).
  Future<bool> aplicarConexionesDelUsuario(SupabaseClient c, Entorno entornoSesion) async {
    final raw = c.auth.currentUser?.userMetadata?['virtus_conexiones'];
    if (raw is! Map) return false;
    var cambio = false;
    for (final e in Entorno.values) {
      final m = raw[e.name];
      if (m is! Map) continue;
      final url = m['url']?.toString().trim() ?? '';
      final key = m['key']?.toString().trim() ?? '';
      if (url.isEmpty || key.isEmpty) continue;
      final actual = config(e);
      if (actual.urlLimpia == url && actual.anonKey.trim() == key) continue;
      // El entorno con sesión: solo actualiza prefs si es idéntico (ya filtrado) o distinto
      // sin matar el cliente; el resto sí se reinicia.
      await guardarConfig(
        e,
        ConfigEntorno(url: url, anonKey: key),
        reiniciarCliente: e != entornoSesion,
      );
      cambio = true;
    }
    return cambio;
  }

  /// JSON con el mismo formato que config/entornos.json (para copiar a otro móvil).
  String exportar() => const JsonEncoder.withIndent('  ').convert({
    for (final e in Entorno.values) ...{e.claveUrl: config(e).urlLimpia, e.claveKey: config(e).anonKey.trim()},
    'ENTORNO_INICIAL': activo.name,
  });

  /// Importa un JSON exportado. Devuelve los entornos actualizados.
  Future<List<Entorno>> importar(String texto) async {
    final m = jsonDecode(texto.trim());
    if (m is! Map) throw const FormatException('No es un objeto JSON');
    final hechos = <Entorno>[];
    for (final e in Entorno.values) {
      final url = m[e.claveUrl], key = m[e.claveKey];
      if (url is String && key is String && url.trim().isNotEmpty) {
        await guardarConfig(e, ConfigEntorno(url: url, anonKey: key));
        hechos.add(e);
      }
    }
    final ini = m['ENTORNO_INICIAL'];
    if (ini is String && Entorno.values.any((e) => e.name == ini)) await setActivo(Entorno.values.byName(ini));
    if (hechos.isEmpty) throw const FormatException('No contiene CLOUD_URL/LOCAL_URL con su clave');
    return hechos;
  }

  Entorno get activo {
    final guardado = _prefs.getString('activo') ?? ConfigBuild.entornoInicial;
    return Entorno.values.where((e) => e.name == guardado).firstOrNull ??
        (config(Entorno.cloud).origen == OrigenConfig.build ? Entorno.cloud : Entorno.local);
  }

  Future<void> setActivo(Entorno e) => _prefs.setString('activo', e.name);

  /// Devuelve (creándolo si hace falta) el cliente del entorno.
  /// Nunca bloquea el arranque: si el servidor no responde, sigue sin sesión.
  Future<SupabaseClient?> cliente(Entorno e) async {
    final existente = _clientes[e];
    if (existente != null) return existente;
    final cfg = config(e);
    if (!cfg.completa) return null;
    final SupabaseClient c;
    try {
      c = SupabaseClient(
        cfg.urlLimpia,
        cfg.anonKey.trim(),
        authOptions: const AuthClientOptions(autoRefreshToken: true, authFlowType: AuthFlowType.implicit),
      );
    } catch (_) {
      return null;
    }
    _clientes[e] = c;
    final guardada = _prefs.getString('ses_${e.name}');
    if (guardada != null) {
      try {
        await c.auth.recoverSession(guardada).timeout(const Duration(seconds: 5));
      } on TimeoutException {
        // Servidor inalcanzable: se conserva la sesión para reintentar luego.
      } on AuthRetryableFetchException {
        // Error de red: ídem.
      } catch (_) {
        await _prefs.remove('ses_${e.name}');
      }
    }
    _subs[e] = c.auth.onAuthStateChange.listen((s) {
      final ses = s.session;
      if (ses != null) {
        _prefs.setString('ses_${e.name}', jsonEncode(ses.toJson()));
      } else if (s.event == AuthChangeEvent.signedOut) {
        _prefs.remove('ses_${e.name}');
      }
    }, onError: (_) {});
    return c;
  }

  SupabaseClient? clienteSiExiste(Entorno e) => _clientes[e];

  Future<void> _cerrar(Entorno e) async {
    await _subs.remove(e)?.cancel();
    final c = _clientes.remove(e);
    if (c != null) await c.dispose();
  }
}
