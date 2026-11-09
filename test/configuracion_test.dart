import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:virtus_catas/core/backend.dart';

Future<Backends> nuevo([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return Backends(await SharedPreferences.getInstance());
}

void main() {
  test('sin ajustes en dispositivo: usa valores por defecto de fábrica', () async {
    final b = await nuevo();
    expect(b.config(Entorno.cloud).origen, OrigenConfig.build);
    expect(b.config(Entorno.cloud).completa, isTrue);
    expect(b.config(Entorno.cloud).url, contains('mdqgfkpbqydctpjukpuw'));
    expect(b.config(Entorno.local).origen, OrigenConfig.build);
    expect(b.config(Entorno.local).completa, isTrue);
    expect(b.config(Entorno.local).url, contains(':8000'));
    expect(b.activo, Entorno.cloud);
  });

  test('lo editado en el dispositivo manda y se puede restaurar', () async {
    final b = await nuevo();
    await b.guardarConfig(Entorno.cloud, const ConfigEntorno(url: 'https://abc.supabase.co/', anonKey: ' k '));
    final c = b.config(Entorno.cloud);
    expect(c.origen, OrigenConfig.dispositivo);
    expect(c.url, 'https://abc.supabase.co'); // sin barra final
    expect(c.anonKey, 'k');
    await b.restaurar(Entorno.cloud);
    expect(b.config(Entorno.cloud).origen, OrigenConfig.build);
    expect(b.config(Entorno.cloud).completa, isTrue);
  });

  test('exportar e importar entre dispositivos', () async {
    final a = await nuevo();
    await a.guardarConfig(Entorno.cloud, const ConfigEntorno(url: 'https://x.supabase.co', anonKey: 'kc'));
    await a.guardarConfig(Entorno.local, const ConfigEntorno(url: 'http://192.168.0.10:54321', anonKey: 'kl'));
    await a.setActivo(Entorno.cloud);
    final json = a.exportar();

    final b = await nuevo();
    final hechos = await b.importar(json);
    expect(hechos, containsAll(Entorno.values));
    expect(b.config(Entorno.cloud).url, 'https://x.supabase.co');
    expect(b.config(Entorno.local).anonKey, 'kl');
    expect(b.activo, Entorno.cloud);
  });

  test('importar rechaza texto inválido', () async {
    final b = await nuevo();
    expect(() => b.importar('hola'), throwsFormatException);
    expect(() => b.importar('{"OTRA": 1}'), throwsFormatException);
  });

  test('URL inválida no se considera completa y no crea cliente', () async {
    final b = await nuevo({'url_cloud': 'supabase.co', 'key_cloud': 'k'});
    expect(b.config(Entorno.cloud).completa, isFalse);
    expect(await b.cliente(Entorno.cloud), isNull);
  });

  test('probarConexion informa de servidor inalcanzable sin colgarse', () async {
    final r = await probarConexion(const ConfigEntorno(url: 'http://127.0.0.1:1', anonKey: 'k'));
    expect(r.ok, isFalse);
  });
}
