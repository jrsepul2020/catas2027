# Virtus · Gestión de Catas 2027 (Flutter + Supabase)

App de **gestión** móvil-primero (también web/escritorio) para coordinar en directo el concurso
sobre la base de datos **Catas2027** que ya usan las tablets de los catadores: mesas, tandas,
catadores y puestos, muestras, notas, incidencias y medallas. Trabaja contra **Supabase Cloud**
o **Supabase Local** y sincroniza ambos.

> La app se adapta al esquema existente (concursos, dias_concurso, categorias, mesas, catadores,
> muestras, tandas, tanda_muestras, puntuaciones, medallas, registro_cambios…). Solo le añade
> columnas, triggers, permisos y funciones; no borra ni renombra nada.

## Puesta en marcha

### 1. Supabase Cloud (Catas2027)
Ya tiene aplicadas las migraciones de la app (`supabase/migrations/2026110600*`).
Si en el futuro usas el CLI contra ese proyecto, marca la base como ya aplicada para no reaplicarla:
```bash
supabase link --project-ref mdqgfkpbqydctpjukpuw
supabase migration repair --status applied 20260607000000
```
**Importante:** desactiva el registro público (*Authentication → Sign In / Providers → Allow new users to sign up*)
y crea a mano los usuarios de gestión (*Authentication → Users*). Las políticas dan permiso de
edición a cualquier usuario con sesión.

### 2. Supabase Local (servidor en la sede, necesita Docker / OrbStack)
```bash
supabase start          # crea la base idéntica a Catas2027 (migraciones de supabase/migrations)
supabase status         # muestra API URL y anon key
```
El usuario admin ya debe existir en CLOUD y en LOCAL (Studio local: http://127.0.0.1:54323 → Authentication). La app no crea cuentas.
Luego, en la app → Sincronizar → **Bajar** para traer el concurso desde CLOUD.

### 3. Configuración de conexiones

Hay dos formas, y se pueden combinar:

**a) Incluida en la APK (recomendado): la app abre lista para usar.**
1. Rellena `config/entornos.json` (está en `.gitignore`; plantilla en `config/entornos.example.json`):
   ```json
   {
     "CLOUD_URL": "https://TU-PROYECTO.supabase.co",
     "CLOUD_ANON_KEY": "anon o publishable key",
     "LOCAL_URL": "http://192.168.1.50:54321",
     "LOCAL_ANON_KEY": "salida de supabase status",
     "ENTORNO_INICIAL": "cloud"
   }
   ```
   `LOCAL_URL` debe ser la IP del ordenador que corre `supabase start` en la WiFi de la cata
   (`ipconfig getifaddr en0` en Mac). En el emulador Android: `http://10.0.2.2:54321`.
2. Compila:
   ```bash
   ./tool/build_apk.sh
   ```
   → `build/app/outputs/flutter-apk/app-release.apk`. Para desarrollo:
   `flutter run --dart-define-from-file=config/entornos.json` (ya configurado en `.vscode/launch.json`).

**b) Desde la app: pantalla Configuración** (engranaje, o «Configurar conexiones» en el login).
- Una tarjeta por entorno con URL, clave, **Probar** (comprueba URL y clave sin iniciar sesión) y **Guardar**.
- Indica el origen: *Incluida en la app*, *Editada en este dispositivo*, *Valor por defecto* o *Sin configurar*.
- Lo editado en el móvil manda sobre lo incluido; **Restaurar** vuelve a lo incluido en la APK.
- Menú ⋯ → **Copiar / Pegar configuración** (mismo JSON que `config/entornos.json`) para pasarla a otro móvil sin recompilar.

La app nunca se queda bloqueada al arrancar: si un servidor no responde, sigue y muestra el login o la configuración.
La APK incluye permiso de Internet y permite HTTP sin cifrar (necesario para el Supabase local en la red).
La anon key es pública por diseño; la seguridad la dan el login y las políticas RLS.

### 4. Ejecutar
```bash
flutter run --dart-define-from-file=config/entornos.json            # móvil / emulador
flutter run -d chrome --dart-define-from-file=config/entornos.json  # web
```

## Google Play
Paquete (applicationId) `virtus.apk`, fijado por la ficha de Play Console. `./tool/build_aab.sh` genera el `.aab` firmado
(clave de subida en `android/key.properties`, fuera de git). Guía paso a paso: [docs/GOOGLE_PLAY.md](docs/GOOGLE_PLAY.md).

> Contexto técnico completo para asistentes de código (Cursor…): [AGENTS.md](AGENTS.md).

## Funciones
| Pantalla | Qué hace |
|---|---|
| Inicio | Baldosas grandes + en directo por mesa: tanda abierta, muestra ACTIVA y cuántas notas lleva, incidencias |
| Día (chip 📅) | Elige el día del concurso; filtra tandas en todas las pantallas |
| Mesas | Estado (según sus tandas), **puestos**: toca dos catadores para intercambiarlos; avisos de puesto repetido, nº de presidentes y catadores previstos; tablet conectada |
| Tandas | Arrastrar para **reordenar** (orden de trabajo), abrir / cerrar / reabrir, editar (número, categoría, día, mesa); muestras de la tanda: reordenar (orden 1..n de las tablets), **activar**, aprobar, incidencia, quitar |
| Catadores | Alta/edición, mover de mesa/puesto (intercambia si está ocupado), ausente/presente, presidente (uno por mesa) |
| Muestras | Código ciego / de texto, categoría, activa; filtro por categoría |
| Puntuaciones | Muestra · 5 puestos · total, con el estado (borrador/enviada/aprobada) de cada nota de las tablets; tocar una nota abre una ventana para cambiarla (fichas en papel); tocar la muestra: activar, aprobar, incidencia |
| Incidencias | Marcar una muestra con motivo (iconos grandes); resolver con tus funciones: **recatar**, **pasar al final**, **quitar de la tanda** o continuar; historial de `registro_cambios` |
| Medallas | Vista `v_resultados_gestion`: media de notas enviadas/aprobadas, medalla propuesta por umbrales del concurso (códigos < 1000 no premian), **medalla oficial** en `medallas`, oficializar en bloque, copiar a Excel |
| Sincronizar | Bajar (Cloud→Local), Subir (Local→Cloud) o Ambas |

Todo se actualiza en tiempo real entre dispositivos (Supabase Realtime).
Las acciones delicadas (puestos, orden, incidencias, aprobación) se hacen por RPC y quedan en `registro_cambios`.

## Sincronización
- `updated_at` en todas las tablas (trigger) y `sync_borrados` (registro de borrados por trigger).
- Incremental: lee de cada entorno lo cambiado desde la última marca; «Revisión completa» lo ignora.
- El destino aplica con `sync_aplicar`: **gana el `updated_at` más reciente** y se conserva, sin rebotes.
- Notas por `(catador_id, muestra_id)` y muestras de tanda por `(tanda_id, muestra_id)`, no por id.
- Borrados con `sync_borrar`, solo si el destino no cambió después.
- Tras **Bajar**, las secuencias de LOCAL saltan a 1.000.000: las altas hechas en local nunca chocan con ids de cloud.
- Requiere sesión iniciada en ambos entornos (se pide en la pantalla de sincronizar).

## Estructura
```
lib/core/      backend.dart (config de entornos, clientes cloud/local, sesión), providers.dart (Riverpod)
config/        entornos.example.json (plantilla) · entornos.json (tu configuración, no se sube)
tool/          build_apk.sh
lib/data/      models.dart, repo.dart
lib/sync/      sync_service.dart
lib/ui/        theme.dart, widgets.dart, screens/
supabase/      migrations/ (base Catas2027 + añadidos de la app: sync, permisos, RPCs, vista de medallas)
test/          pantallas_test.dart (todas las pantallas en móvil y escritorio)
```
