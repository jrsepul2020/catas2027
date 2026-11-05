# Virtus · Gestión de Catas 2027 (Flutter + Supabase)

App móvil-primero (también web/escritorio) para gestionar en directo una cata:
mesas, tandas, catadores, muestras, puntuaciones, medallas e incidencias, contra
**Supabase Cloud** o **Supabase Local**, con sincronización entre ambos.

## Puesta en marcha

### 1. Supabase Local (necesita Docker / OrbStack)
```bash
supabase start          # levanta el stack y aplica supabase/migrations + seed.sql
supabase status         # muestra API URL y anon key
```
El seed crea la cata demo «Catas Virtus 2027» (4 mesas, 20 catadores, 48 muestras, 12 tandas).
En la app pulsa **Crear cuenta** (en local no hace falta confirmar el email).

### 2. Supabase Cloud
```bash
supabase link --project-ref <ref>
supabase db push        # aplica la misma migración en cloud
```
Crea el usuario en *Authentication → Users* y **desactiva el registro público**
(las políticas RLS dan acceso total a cualquier usuario autenticado).

### 3. App
```bash
flutter run                       # móvil / emulador
flutter run -d chrome             # web
flutter run -d macos              # escritorio
```
Las conexiones se configuran en **Ajustes** (o con `--dart-define=CLOUD_URL=… --dart-define=CLOUD_ANON_KEY=…`).
- Emulador Android → `http://10.0.2.2:54321`
- Móvil físico → `http://<IP-del-ordenador>:54321`

## Funciones
| Pantalla | Qué hace |
|---|---|
| Inicio | Panel con baldosas grandes + estado en directo de cada mesa (tanda actual, % de notas) |
| Mesas | Estado de mesa, **puestos**: toca dos catadores para intercambiarlos (RPC atómica) |
| Tandas | Arrastrar para **reordenar**, iniciar/cerrar, mover a otra mesa, añadir/quitar/reordenar muestras |
| Catadores | Alta, mover de mesa/puesto (intercambia si está ocupado), ausente/presente, presidente |
| Puntuar | Rejilla muestras × catadores + **teclado numérico gigante**; OK avanza a la siguiente celda. En escritorio: números + Enter + flechas |
| Medallas | Vista SQL `v_resultados` (media o sin extremos, umbrales por cata), medalla manual, copiar a Excel |
| Incidencias | Alta en 2 toques con iconos; prioridades; resolver/reabrir. Los cambios de puesto y de orden quedan registrados automáticamente |
| Sincronizar | Cloud ⇄ Local, Cloud→Local o Local→Cloud; solo la cata actual o todo |

Todo se actualiza en tiempo real entre dispositivos (Supabase Realtime).

## Sincronización
- Mismo esquema en ambos entornos, PK `uuid`, `updated_at` por trigger y borrado lógico (`deleted_at`).
- **Last-write-wins**: una fila solo se envía si el destino no la tiene o la tiene más antigua.
- Incremental: guarda la última marca `updated_at` vista por entorno y tabla; «Revisión completa» lo ignora.
- Puntuaciones emparejadas por `(muestra_id, catador_id)`.
- Requiere sesión iniciada en ambos entornos (se pide en la pantalla de sincronizar).

## Estructura
```
lib/core/      backend.dart (clientes cloud/local + sesión), providers.dart (Riverpod)
lib/data/      models.dart, repo.dart
lib/sync/      sync_service.dart
lib/ui/        theme.dart, widgets.dart, screens/
supabase/      migrations/ (esquema, vista de medallas, RPCs, RLS, realtime), seed.sql
test/          pantallas_test.dart (todas las pantallas en móvil y escritorio)
```
