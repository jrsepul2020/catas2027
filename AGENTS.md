# AGENTS.md · Virtus Gestión Catas 2027

Guía para asistentes de código (Cursor, Claude, Copilot…) y desarrolladores. Explica **qué es la app,
cómo está construida, qué reglas seguir y dónde está cada cosa**. Léela entera antes de cambiar código.

---

## 1. Qué es

App **Flutter** de **gestión/coordinación en directo** de un concurso de cata (vinos, espirituosos,
espumosos y AOVE) — edición *La Rábida 2027*.

- La usa **el coordinador**, no los catadores. Los catadores puntúan con **otra app de tablets** (no está
  en este repo) que escribe en la **misma base de datos** Supabase **Catas2027**.
- Dispositivos objetivo: **Redmi Note 12 Pro** (1080×2400, ~393×873 lógicos) y **tablet de 11"**
  (~800×1280). También web/escritorio para pruebas.
- Prioridades del cliente, en orden: **velocidad**, **mínimo scroll en el móvil**, **botones/iconos
  grandes y claros**, colores **azul, rojo, amarillo, lila y sus pastel**.
- Idioma: todo en **español** (UI, nombres de clases/variables, comentarios, SQL).

## 2. Stack

| Pieza | Versión / detalle |
|---|---|
| Flutter | 3.47 (Dart 3.x, usa records, patterns, `?valor` en mapas) |
| Estado | `flutter_riverpod` **3.x** (Provider/Notifier sin generación de código) |
| Navegación | `go_router` 18 (ShellRoute + redirect) |
| Backend | `supabase_flutter` 2.x — **dos clientes a la vez** (CLOUD y LOCAL) |
| Otros | `shared_preferences`, `http`, `intl`, `uuid` |
| Base de datos | Postgres de Supabase (Cloud: proyecto `mdqgfkpbqydctpjukpuw`, eu-north-1) |

Sin `build_runner`, sin freezed, sin json_serializable: **modelos a mano** sobre `Map<String, dynamic>`.

## 3. Comandos

```bash
flutter pub get
flutter analyze                         # debe dar "No issues found!"
flutter test                            # ~49 tests; deben pasar todos
flutter run --dart-define-from-file=config/entornos.json            # móvil/emulador
flutter run -d chrome --dart-define-from-file=config/entornos.json  # web
./tool/build_apk.sh                     # APK release con las conexiones incluidas
./tool/build_aab.sh                     # App Bundle firmado para Google Play
dart format lib test                    # ancho de línea 120 (analysis_options.yaml)
```

`config/entornos.json` (NO en git; plantilla `config/entornos.example.json`) lleva
`CLOUD_URL`, `CLOUD_ANON_KEY`, `LOCAL_URL`, `LOCAL_ANON_KEY`, `ENTORNO_INICIAL` y se inyecta con
`--dart-define-from-file`. La anon key es pública por diseño; la seguridad la dan login + RLS.

## 4. Estructura

```
lib/
  main.dart                 Arranque: SharedPreferences + ProviderScope
  app.dart                  GoRouter (redirect: carga → configuración → login → concurso) y MaterialApp
                            (tema claro fijo; compacto si shortestSide < 600)
  core/
    backend.dart            Entornos CLOUD/LOCAL: ConfigBuild (dart-define), ConfigEntorno, Backends
                            (un SupabaseClient por entorno, sesión persistida en prefs, nunca bloquea
                            el arranque: timeouts), probarConexion(), exportar/importar config JSON
    providers.dart          TODOS los providers Riverpod (ver §6)
  data/
    models.dart             Concurso, Categoria, Dia, Mesa, Catador, Muestra, Tanda, TandaMuestra,
                            Puntuacion, Cambio, Resultado — envoltorios ligeros de Json (ids int)
    repo.dart               Repo: escrituras directas y llamadas RPC (ver §8)
  sync/
    sync_service.dart       Sincronización CLOUD ⇄ LOCAL (ver §9)
  ui/
    theme.dart              Paleta + tema(compacto:) — ÚNICO sitio para colores/tamaños base
    widgets.dart            Widgets y helpers comunes + catálogos de estados (ver §10)
    screens/
      shell.dart            Barra inferior (móvil) / NavigationRail (≥900 px)
      inicio_screen.dart    9 baldosas que caben sin scroll
      directo_screen.dart   En directo: una fila por mesa (tanda abierta, muestra activa, notas)
      mesas_screen.dart     Lista de mesas + detalle: puestos con arrastre (DragTarget) y tandas
      tandas_screen.dart    Tandas reordenables + detalle (muestras: activar, aprobar, incidencia)
      puntuar_screen.dart   "Puntuaciones": lista de tandas + hoja (muestra × puestos × total)
                            con ventana modal para editar una nota
      catadores_screen.dart Alta/edición, mover de mesa/puesto, ausente, presidente
      muestras_screen.dart  Rejilla compacta de muestras
      medallas_screen.dart  Resultados (vista SQL) y medalla oficial
      incidencias_screen.dart  Marcar/resolver incidencias + historial (registro_cambios)
      sync_screen.dart      Sincronizar (Bajar día / Subir / Ambas)
      ajustes_screen.dart   "Configuración": conexiones CLOUD/LOCAL, sesión, concurso
      catas_screen.dart     Elegir concurso (solo si hay varios) + editarConcurso()
      login_screen.dart     Email/contraseña + selector de entorno
supabase/migrations/        Esquema (ver §7)
test/                       pantallas_test.dart (todas las pantallas a 393×873, 800×1280, 1280×800),
                            configuracion_test.dart
tool/                       build_apk.sh, build_aab.sh
android/                    applicationId virtus.apk (Play); namespace com.virtus.gestioncatas; firma en android/key.properties
```

## 5. Modelo de dominio (esquema REAL de Catas2027)

> La base **ya existía** y la usan las tablets. La app se **adaptó** a ella. **Nunca** renombrar ni
> borrar tablas/columnas existentes; solo cambios **aditivos** en migraciones nuevas.

| Tabla | Claves | Notas |
|---|---|---|
| `concursos` | id int | `gran_oro`, `oro`, `plata` (umbrales), `catadores_por_mesa`, `activo` |
| `categorias` | id int, `codigo` único | `ficha` jsonb = criterios de puntuación de las tablets |
| `dias_concurso` | id int | `concurso_id`, `fecha`, `nombre` |
| `mesas` | id int | `numero`, `nombre`, `concurso_id` |
| `catadores` | id int | `nombre` (completo), `rol` ('catador'/'presidente'), `mesa_id`, `mesa` (= número de mesa, mantener coherente), `puesto` smallint, `activo` (**tablet conectada**, lo gestiona la app de tablets), `presente` (añadido), `pais_codigo`, `titulo` |
| `dispositivos` | id int | tablet ↔ catador (no se toca desde esta app) |
| `muestras` | id int, `codigo_ciego` único | `codigo_texto`, `categoria_id`, `activo`. Códigos numéricos **< 1000 no premian** |
| `tandas` | id int | `numero` (p. ej. 901), `estado` 'pendiente'/'abierta'/'cerrada', `mesa_id`, `categoria_id`, `dia_id`, `orden` (añadido: orden de trabajo) |
| `tanda_muestras` | id int, único (`tanda_id`,`muestra_id`) | `orden` **1..n contiguo** (lo usan las tablets), `estado` 'pendiente'/'activa'/'completada'/'incidencia'/'pospuesta', `incidencia_motivo` |
| `puntuaciones` | id int, único (`catador_id`,`muestra_id`) | `scores` jsonb (desglose de la ficha; las manuales llevan `{"manual":true}`), `total` numeric, `estado` 'borrador'/'enviada'/'aprobada' |
| `medallas` | id int, único `muestra_id` | medalla **oficial**: 'gran_oro'/'oro'/'plata'/'sin_medalla' |
| `asignaciones` | id int | asignación por día (no se usa aún en la UI) |
| `registro_cambios` | uuid | auditoría: `accion`, `tabla`, `registro_id`, `antes`, `despues`, `motivo`, `dia_id` |
| `sync_estado` | id = 1 | en LOCAL: `dia_id` = día bajado; `estado` 'vacio'/'cargado'/'subido'/'verificado' |
| `sync_borrados` | bigint | (añadido) borrados registrados por trigger para la sincronización |

Reglas de negocio importantes:
- **Una sola muestra `activa` por tanda** (la que muestran las tablets) → usar RPC `activar_muestra`.
- **Una tanda abierta por mesa**; **un presidente por mesa**; `catadores_por_mesa` del concurso.
- Notas **aprobadas no se pueden modificar**: lo impide el trigger `bloquear_puntuacion_aprobada`
  (solo se salta con `set_config('virtus.reabrir','on')`, que usa la sincronización).
- Una muestra solo en **una** tanda del día; la categoría de la tanda = la de sus muestras.
- La función `auditoria()` (preexistente, solo editor SQL) lista estas comprobaciones.

## 6. Providers (lib/core/providers.dart)

- `entornoProvider` (CLOUD/LOCAL), `clienteProvider` (SupabaseClient del entorno activo),
  `sesionProvider`, `usuarioIdProvider`, `repoProvider`.
- `filasProvider.family<List<Json>, String>(tabla)`: **stream realtime** de la tabla completa
  (`registro_cambios`: últimos 300). Las tablas son pequeñas: se leen enteras.
- Listas tipadas y ordenadas: `mesasProvider`, `catadoresProvider`, `muestrasProvider`,
  `todasTandasProvider`, `tandasProvider` (filtradas por día), `tandaMuestrasProvider`,
  `puntuacionesProvider`, `cambiosProvider`, `categoriasProvider`, `diasProvider`, `concursosProvider`.
- Índices: `mesaPorIdProvider`, `muestraPorIdProvider`, `catadorPorIdProvider`, `tandaPorIdProvider`,
  `puntuacionIdxProvider` (clave `"muestraId|catadorId"`).
- Derivados por familia: `tandasDeMesaProvider(mesaId)`, `muestrasDeTandaProvider(tandaId)`,
  `catadoresDeMesaProvider(mesaId)` (ordenados por puesto).
- Selección: `concursoIdProvider` (auto si solo hay uno), `diaIdProvider`:
  - CLOUD: día elegido (`diaGuardadoProvider`, -1 = todos), si no el de hoy, si no el primero.
  - **LOCAL** (`esLocalProvider`): siempre `diaLocalProvider` = `sync_estado.dia_id`. **En LOCAL no
    hay selector de días** (`ChipDia` se oculta) y `muestrasProvider` filtra a las del día.
- `resultadosProvider`: FutureProvider sobre la vista `v_resultados_gestion`.
- `incidenciasAbiertasListaProvider` = `tanda_muestras` con estado `incidencia`.

Patrón: las pantallas hacen `ref.watch(...)` de providers derivados; **no** consultan Supabase
directamente. Las escrituras van por `ref.read(repoProvider)!` dentro de `ejecutar(context, ...)`,
y la UI se actualiza sola por realtime (reordenaciones usan un orden **optimista** local).

## 7. Migraciones (supabase/migrations)

| Archivo | Qué hace |
|---|---|
| `20260607000000_base_catas2027.sql` | Copia **idempotente** del esquema original de Catas2027 (tablas, funciones `pasar_al_final`, `recatar_muestra`, `quitar_de_tanda`, `_retirar_notas`, trigger de aprobadas, RLS original). Sirve para crear el Supabase LOCAL. En cloud ya existe: `supabase migration repair --status applied 20260607000000` |
| `20261106000000_app_gestion.sql` | Aditiva: `updated_at` + trigger `tg_sync_touch` en todas las tablas sincronizables, `sync_borrados` + trigger `tg_sync_borrado`, `tandas.orden`, `catadores.presente`, políticas `gestion_autenticados` (escritura **solo authenticated**), realtime, RPCs de gestión, vista `v_resultados_gestion`, `sync_aplicar`, `sync_borrar`, `sync_preparar_local` |
| `20261106000100_app_gestion_seguridad.sql` | `search_path` fijo en las funciones nuevas; trigger de borrados no ejecutable por API |
| `20261106000200_app_gestion_permisos.sql` | `resolver_incidencia` y `reordenar_muestras` como SECURITY DEFINER (llaman a funciones internas que solo puede ejecutar el propietario) |

Las tres últimas **ya están aplicadas en cloud**. Cambios nuevos → **nuevo archivo** con timestamp
posterior, siempre aditivo e idempotente (`if not exists`, `create or replace`, `drop policy if exists`).
Las tablets usan el rol `anon`: no quitarle permisos que ya tiene.

## 8. RPCs que usa la app (lib/data/repo.dart)

| RPC | Uso |
|---|---|
| `intercambiar_puestos(a, b, p_motivo)` | Swap de mesa/puesto entre dos catadores (arrastre en Puestos) |
| `mover_catador(p_catador, p_mesa, p_puesto, p_motivo)` | Mover; si el puesto está ocupado, intercambia |
| `reordenar_tandas(ids[], p_motivo)` | Orden de trabajo de tandas (`orden` 0..n) |
| `reordenar_muestras(p_tanda, ids[], p_motivo)` | Orden 1..n de las muestras de una tanda |
| `marcar_incidencia(p_tm, p_motivo)` | tanda_muestra → estado `incidencia` |
| `resolver_incidencia(p_tm, p_accion, p_motivo)` | `continuar` / `recatar` / `pasar_al_final` / `quitar_de_tanda` (estas tres borran notas guardándolas en `registro_cambios`) |
| `activar_muestra(p_tm)` | Única activa de su tanda |
| `aprobar_muestra(p_tm)` | Notas → `aprobada`, tanda_muestra → `completada` |
| `fijar_medalla(p_muestra, p_medalla, p_media)` | Upsert/borrado en `medallas` |
| `sync_aplicar`, `sync_borrar`, `sync_preparar_local` | Sincronización |

Escrituras directas (tablas con política): `estadoTanda`, `puntuarManual` (upsert por
`catador_id,muestra_id`), CRUD de concursos/mesas/catadores/muestras/tandas, `registrar()` en
`registro_cambios`. Todas las acciones delicadas quedan en `registro_cambios`.

## 9. Sincronización CLOUD ⇄ LOCAL

Escenario: en la sede hay un **Supabase LOCAL** (Docker, `supabase start`) en la WiFi; las tablets y
esta app trabajan contra él; antes se **baja** un día desde cloud y después se **sube**.

- `SyncService.sincronizar(Direccion, {completa, diaBajar})`. Direcciones: `cloudALocal` (Bajar),
  `localACloud` (Subir), `ambas`.
- **Bajar solo un día** (`diaBajar`): `_filtrosDia()` limita tandas, tanda_muestras, muestras,
  puntuaciones, medallas, asignaciones, registro_cambios y dias_concurso a ese día; mesas, catadores,
  categorías y concursos van completos. Al terminar escribe `sync_estado.dia_id` en LOCAL.
- Incremental por marcas (`updated_at` / `creado_en` / `borrado_en`) guardadas en prefs por
  entorno+tabla(+día). «Revisión completa» las ignora.
- El **destino decide** con `sync_aplicar(tabla, filas)`: insert … on conflict … **solo si
  `excluded.updated_at` es más nuevo** (last-write-wins sin rebotes; el trigger respeta el
  `updated_at` que llega). Claves naturales: puntuaciones (`catador_id`,`muestra_id`),
  tanda_muestras (`tanda_id`,`muestra_id`), medallas (`muestra_id`).
- Borrados vía `sync_borrados` → `sync_borrar` (solo si el destino no cambió después).
- Tras bajar, `sync_preparar_local()` sube las secuencias LOCAL a ≥ 1.000.000 para que las altas
  locales no choquen con ids de cloud.
- **Nunca** borrar datos de otros días en LOCAL: generaría borrados que viajarían a cloud.

## 10. UI: reglas de diseño (IMPORTANTE)

- **Tema claro fijo** (`themeMode: light`). Colores SOLO de `Paleta` (theme.dart) o de los
  `MaterialColor` `Colors.blue / red / amber / deepPurple` (lila). Nada de verde, naranja ni teal.
  - azul = pendiente/preparada/enviada · amarillo = abierta/activa/catando · lila = cerrada/
    completada/aprobada/presidente · rojo = incidencias/errores/ausente.
- **Compacto en teléfono**: `esCompacto(context)` (shortestSide < 600). El tema ya reduce tamaños
  (`tema(compacto: true)`); en widgets propios usa `final k = esCompacto(context);` y elige tamaños
  (`k ? 15 : 20`). La tablet (11") usa tamaños grandes.
- **Mínimo scroll en el Redmi (393×873)**: Inicio, Puestos de mesa y 5 mesas deben verse sin scroll;
  muestras en rejilla densa. Comprueba con los tests a 393×873.
- **Siempre texto con color explícito** en estilos de temas/listas (se arregló un fallo de texto
  blanco sobre fondo claro por `TextStyle` sin `color`).
- Edición de valores = **ventana modal** (`showDialog` / `hojaFormulario`), no paneles fijos.
- Helpers en `widgets.dart`: `aviso()`, `ejecutar()` (try/catch + háptica + snackbar),
  `confirmar()`, `hojaFormulario()`, `elegir()`, `Campo`, `Baldosa`, `EtiquetaEstado`, `Medalla`,
  `ChipEntorno`, `ChipDia`, `BotonDirecto`, `Vacio`, `Ancho`, `esAncho()`, `esCompacto()`.
- Catálogos: `estadosMesa`, `estadosTanda`/`infoTanda()`, `estadosTM`/`infoTM()`, `estadosNota`,
  `medallas`, `motivosIncidencia`, `accionesCambio`.
- Rutas: `/`, `/directo`, `/mesas`, `/mesas/:id`, `/tandas`, `/tandas/:id`, `/catadores`,
  `/muestras`, `/puntuar`, `/puntuar/:tanda`, `/medallas`, `/incidencias` (dentro del Shell);
  `/login`, `/configuracion`, `/catas`, `/sync`, `/carga` (fuera).

## 11. Tests

- `test/pantallas_test.dart`: monta cada pantalla con datos falsos (misma forma que Catas2027)
  sobreescribiendo `filasProvider`, `repoProvider` y `resultadosProvider`, a 393×873, 800×1280 y
  1280×800, y falla si hay **overflow**. Añade cada pantalla nueva a esa lista.
- `test/configuracion_test.dart`: prioridad build/dispositivo, importar/exportar, prueba de conexión.
- SQL: no hay Docker en el Mac de desarrollo; las migraciones se prueban en un Postgres temporal
  (`initdb` + `pg_ctl`, quitando `with (security_invoker = true)` porque es PG14).

## 12. Seguridad (pendiente/avisos)

- En cloud el **registro público de usuarios está activado**: desactivarlo en Supabase Auth; cualquier
  usuario autenticado puede editar la configuración.
- Preexistente (no tocado): `demo_reiniciar_muestra` ejecutable por `anon`; catadores, puntuaciones y
  tanda_muestras escribibles por `anon` (lo necesitan las tablets).
- Nunca subir `config/entornos.json`, `android/key.properties` ni `android/upload-keystore.jks`.

## 13. Publicación Android

- `applicationId` **virtus.apk** (fijado por la ficha de Play Console; NO cambiar). El `namespace`/paquete Kotlin es `com.virtus.gestioncatas` (independiente). Versión en `pubspec.yaml`
  (`version: X.Y.Z+N`): **subir N en cada subida** a Google Play.
- `./tool/build_aab.sh` → `build/app/outputs/bundle/release/app-release.aab`, firmado con la clave de
  subida (`android/key.properties`). Guía completa: `docs/GOOGLE_PLAY.md`.
