# Publicar en Google Play · Prueba interna

App: **Virtus Catas** · paquete (applicationId) **`virtus.apk`** — lo fija la ficha de Play Console; no cambiar.

## 0. Archivos

| Archivo | Para qué | ¿En git? |
|---|---|---|
| `build/app/outputs/bundle/release/app-release.aab` | **El que se sube** a Play Console | No (se genera) |
| `android/upload-keystore.jks` | Clave de subida (firma) | **No** |
| `android/key.properties` | Contraseña y alias de esa clave | **No** |

> ⚠️ **Haz copia de seguridad YA** de `android/upload-keystore.jks` y `android/key.properties`
> (gestor de contraseñas, unidad cifrada…). Sin ellos no podrás subir actualizaciones. Si se pierden,
> con *Play App Signing* se puede pedir a Google un reseteo de la clave de subida, pero tarda días.

Generar el bundle (cada vez):

```bash
./tool/build_aab.sh
```

Antes de **cada nueva subida** incrementa el número tras `+` en `pubspec.yaml`
(`version: 1.0.0+1` → `1.0.0+2` …). Play rechaza un `versionCode` repetido.

## 1. Crear la app en Play Console (una vez)

1. <https://play.google.com/console> → **Crear aplicación**.
2. Nombre: `Virtus Catas` · Idioma: Español (España) · Tipo: **Aplicación** · **Gratuita**.
3. Acepta las declaraciones y crea.

## 2. Subir a prueba interna

1. Menú izquierdo → **Probar y publicar → Pruebas → Prueba interna**.
2. Pestaña **Testers** → **Crear lista de correo** → añade tu email (y el de quien vaya a usarla) →
   Guardar. Copia el **enlace de participación** (lo usarás en el móvil).
3. **Crear nueva versión**.
4. *Firma de aplicaciones de Google Play*: acepta/continúa (Google guarda la clave de firma final;
   nuestra `upload-keystore.jks` es solo la clave de **subida**).
5. **Subir** → `app-release.aab`.
6. Nombre de la versión: `1.0.0 (2)` (o el que corresponda) · Notas: `Primera versión de prueba interna.`
7. **Siguiente → Guardar → Publicar en prueba interna** (o «Enviar cambios a revisión» si lo pide).

En el móvil: abre el **enlace de participación** con la misma cuenta de Google que añadiste como
tester → **Aceptar** → **Descargar en Google Play**. Suele estar disponible en minutos.

## 3. Lo que Play te pedirá completar («Configura tu aplicación» → Contenido de la aplicación)

Respuestas sugeridas para esta app (revisa que se ajustan a tu caso):

| Sección | Respuesta |
|---|---|
| **Política de privacidad** | URL pública. Puedes publicar el texto de `docs/POLITICA_PRIVACIDAD.md` (p. ej. en tu web). |
| **Acceso a la aplicación** | «Todas o algunas funciones están restringidas» → indica que requiere cuenta de gestión y facilita un usuario de prueba **solo si** Google lo exige para revisión. |
| **Anuncios** | No contiene anuncios. |
| **Clasificación de contenido** | Cuestionario: categoría *Utilidad/Productividad*; sin violencia, sexo, drogas… Menciona que gestiona un concurso de **vinos y aceites** (no vende alcohol ni lo promociona). |
| **Público objetivo** | **18 años o más**. |
| **Seguridad de los datos** | Recopila: **email** (gestión de cuenta) y datos de la app (puntuaciones, nombres de catadores) — finalidad *funcionalidad de la app*; **cifrados en tránsito** (HTTPS hacia Supabase Cloud); no se comparten con terceros; el usuario puede pedir su eliminación. |
| **Apps gubernamentales / financieras / salud** | No. |

La **ficha de Play Store** (iconos 512 px, capturas, gráfico de funciones) no es necesaria para la
prueba interna; sí para pruebas cerradas/abiertas y producción.

## 4. Notas

- **Cuentas de desarrollador personales nuevas**: para pasar a **producción** Google exige antes una
  **prueba cerrada con al menos 12 testers durante 14 días**. La prueba interna no tiene ese requisito.
- La app usa HTTP sin cifrar **solo** para el Supabase LOCAL en la WiFi de la sede
  (`usesCleartextTraffic`). Si Play lo marca en el informe previo al lanzamiento, es esperado.
- Huella SHA-256 del certificado de **subida**:
  `03:1D:AB:82:F9:8E:12:3C:8C:0B:FE:C9:AA:23:14:9B:40:DB:1A:BC:0E:56:25:D1:FC:86:7F:F2:9B:63:EB:EE`
  (Play Console → Integridad de la aplicación → Firma de aplicaciones, para comprobar).
- Para instalar sin Play (APK directa) sigue sirviendo `./tool/build_apk.sh`.
