import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
}

/// Clave anon "demo" que usa siempre `supabase start` en local.
const _anonLocalDemo =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDjblYTn_I0';

class ConfigEntorno {
  const ConfigEntorno({required this.url, required this.anonKey});
  final String url;
  final String anonKey;

  bool get completa => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;

  static ConfigEntorno porDefecto(Entorno e) => switch (e) {
    Entorno.cloud => const ConfigEntorno(
      url: String.fromEnvironment('CLOUD_URL'),
      anonKey: String.fromEnvironment('CLOUD_ANON_KEY'),
    ),
    Entorno.local => ConfigEntorno(
      url: const String.fromEnvironment('LOCAL_URL').isNotEmpty
          ? const String.fromEnvironment('LOCAL_URL')
          : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? 'http://10.0.2.2:54321' // emulador Android -> Mac
                : 'http://127.0.0.1:54321'),
      anonKey: const String.fromEnvironment('LOCAL_ANON_KEY').isNotEmpty
          ? const String.fromEnvironment('LOCAL_ANON_KEY')
          : _anonLocalDemo,
    ),
  };
}

/// Mantiene un [SupabaseClient] por entorno, con la sesión persistida.
/// Ambos clientes pueden estar vivos a la vez (necesario para sincronizar).
class Backends {
  Backends(this._prefs);
  final SharedPreferences _prefs;
  final Map<Entorno, SupabaseClient> _clientes = {};
  final Map<Entorno, StreamSubscription<AuthState>> _subs = {};

  ConfigEntorno config(Entorno e) {
    final def = ConfigEntorno.porDefecto(e);
    return ConfigEntorno(
      url: _prefs.getString('url_${e.name}') ?? def.url,
      anonKey: _prefs.getString('key_${e.name}') ?? def.anonKey,
    );
  }

  Future<void> guardarConfig(Entorno e, ConfigEntorno c) async {
    await _prefs.setString('url_${e.name}', c.url.trim());
    await _prefs.setString('key_${e.name}', c.anonKey.trim());
    await _cerrar(e);
    await _prefs.remove('ses_${e.name}');
  }

  Entorno get activo => Entorno.values.byName(_prefs.getString('activo') ?? Entorno.local.name);
  Future<void> setActivo(Entorno e) => _prefs.setString('activo', e.name);

  /// Devuelve (creándolo si hace falta) el cliente del entorno.
  Future<SupabaseClient?> cliente(Entorno e) async {
    final existente = _clientes[e];
    if (existente != null) return existente;
    final cfg = config(e);
    if (!cfg.completa) return null;
    final c = SupabaseClient(
      cfg.url,
      cfg.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: true, authFlowType: AuthFlowType.implicit),
    );
    _clientes[e] = c;
    final guardada = _prefs.getString('ses_${e.name}');
    if (guardada != null) {
      try {
        await c.auth.recoverSession(guardada);
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
    });
    return c;
  }

  SupabaseClient? clienteSiExiste(Entorno e) => _clientes[e];

  Future<void> _cerrar(Entorno e) async {
    await _subs.remove(e)?.cancel();
    final c = _clientes.remove(e);
    if (c != null) await c.dispose();
  }
}
