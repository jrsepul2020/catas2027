import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'iconos.dart';

/// Sistema de diseño CATARIS Gestión 2027.
///
/// Identidad: granate de marca, verde solo «en marcha», ámbar solo avisos.
/// Fondo cálido, tarjetas blancas con borde suave. Sin degradados ni sombras fuertes.
abstract final class Virtus {
  // —— Marca ——
  static const marca = Color(0xFF970119);
  static const marcaOscura = Color(0xFF6B0A18);
  static const fondo = Color(0xFFF6F2EE);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF1E1B19);
  static const textoSecundario = Color(0xFF6B655F);
  static const textoTenue = Color(0xFF8A837C);
  static const borde = Color(0xFFE6DED8);
  static const separador = Color(0xFFE6DED8);

  // —— Estados (únicos colores fuera de la marca) ——
  /// Verde: solo «en marcha» (conectado, muestra activa, todo correcto).
  static const enMarcha = Color(0xFF1F7A4D);
  static const advertencia = Color(0xFFB4621A);
  static const error = Color(0xFFB42318);

  // Alias de compatibilidad con código anterior.
  static const marino = marcaOscura;
  static const accion = marca;
  static const exito = enMarcha;

  // —— Suaves ——
  static const marcaSuave = Color(0xFFF8E9EC);
  static const enMarchaSuave = Color(0xFFE8F4EE);
  static const advertenciaSuave = Color(0xFFFBF0E6);
  static const errorSuave = Color(0xFFF8E9E8);
  static const neutroSuave = Color(0xFFF1EEEA);

  // Alias legacy.
  static const accionSuave = marcaSuave;
  static const marinoSuave = marcaSuave;
  static const exitoSuave = enMarchaSuave;

  static const radio = 12.0;
  static const radioSm = 8.0;
  static const elevacion = 0.0;
  static const grosorBorde = 1.0;

  /// MaterialColor semántico (compat. con chips/estados que usan shade50…900).
  static MaterialColor material(Color base) {
    Color mezclar(double t) => Color.lerp(Colors.white, base, t)!;
    Color oscurecer(double t) => Color.lerp(base, const Color(0xFF1E1B19), t)!;
    return MaterialColor(base.toARGB32(), {
      50: mezclar(0.08),
      100: mezclar(0.14),
      200: mezclar(0.28),
      300: mezclar(0.42),
      400: mezclar(0.58),
      500: base,
      600: oscurecer(0.12),
      700: oscurecer(0.22),
      800: oscurecer(0.34),
      900: oscurecer(0.48),
    });
  }

  static final mcAccion = material(marca);
  static final mcAdvertencia = material(advertencia);
  static final mcExito = material(enMarcha);
  static final mcError = material(error);
  static final mcNeutro = material(textoSecundario);
  static final mcMarino = material(marcaOscura);
}

/// Tipografía de jerarquía: Inter (google_fonts) + fallback de sistema.
/// Los números usan siempre [FontFeature.tabularFigures].
abstract final class VirtusTexto {
  static const _fallback = <String>['Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'];
  static const _tabulares = <FontFeature>[FontFeature.tabularFigures()];

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    Color color = Virtus.texto,
    double? height,
    double? letterSpacing,
    bool tabular = false,
  }) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontFamilyFallback: _fallback,
      fontFeatures: tabular ? _tabulares : null,
    );
    try {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: tabular ? _tabulares : null,
      ).copyWith(fontFamilyFallback: _fallback);
    } catch (_) {
      return base;
    }
  }

  static TextStyle importante({double size = 20, Color color = Virtus.texto}) =>
      _inter(size: size, weight: FontWeight.w800, color: color, letterSpacing: -0.3, height: 1.15);

  static TextStyle titulo({double size = 16, Color color = Virtus.texto}) =>
      _inter(size: size, weight: FontWeight.w700, color: color, letterSpacing: -0.2, height: 1.2);

  static TextStyle cuerpo({double size = 14, Color color = Virtus.texto}) =>
      _inter(size: size, weight: FontWeight.w400, color: color, height: 1.35);

  static TextStyle tenue({double size = 13, Color color = Virtus.textoSecundario}) =>
      _inter(size: size, weight: FontWeight.w400, color: color, height: 1.3);

  /// Contadores, progreso, códigos de muestra, puntuaciones.
  static TextStyle numero({double size = 22, Color color = Virtus.texto, FontWeight weight = FontWeight.w800}) =>
      _inter(size: size, weight: weight, color: color, height: 1.1, letterSpacing: -0.4, tabular: true);
}

/// Alias de compatibilidad con el código existente.
abstract final class Paleta {
  static const azul = Virtus.marca;
  static const azulOscuro = Virtus.marcaOscura;
  static const azulPastel = Virtus.marcaSuave;
  static const rojo = Virtus.error;
  static const rojoOscuro = Color(0xFF7A160F);
  static const rojoPastel = Virtus.errorSuave;
  static const amarillo = Virtus.advertencia;
  static const amarilloOscuro = Color(0xFF8A4A14);
  static const amarilloPastel = Virtus.advertenciaSuave;
  static const lila = Virtus.enMarcha;
  static const lilaOscuro = Color(0xFF145A38);
  static const lilaPastel = Virtus.enMarchaSuave;
  static const fondo = Virtus.fondo;
  static const texto = Virtus.texto;
  static const textoSuave = Virtus.textoSecundario;
}

TextTheme _textoInter(ColorScheme cs, {required bool compacto}) {
  TextTheme base;
  try {
    base = GoogleFonts.interTextTheme().apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  } catch (_) {
    base = ThemeData(useMaterial3: true).textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  }
  final escala = compacto ? 0.95 : 1.0;
  TextStyle escalar(TextStyle? s, {FontWeight? w, double? size, Color? color}) {
    final t = s ?? const TextStyle();
    return t.copyWith(
      fontWeight: w ?? t.fontWeight,
      fontSize: size != null ? size * escala : (t.fontSize == null ? null : t.fontSize! * escala),
      letterSpacing: t.letterSpacing ?? -0.1,
      height: t.height ?? 1.25,
      color: color ?? t.color ?? cs.onSurface,
      fontFamilyFallback: VirtusTexto._fallback,
      fontFeatures: VirtusTexto._tabulares,
    );
  }

  return base.copyWith(
    displayLarge: escalar(base.displayLarge, w: FontWeight.w800, size: 32),
    displayMedium: escalar(base.displayMedium, w: FontWeight.w800, size: 28),
    displaySmall: escalar(base.displaySmall, w: FontWeight.w800, size: 24),
    headlineLarge: escalar(base.headlineLarge, w: FontWeight.w800, size: 22),
    headlineMedium: escalar(base.headlineMedium, w: FontWeight.w700, size: 20),
    headlineSmall: escalar(base.headlineSmall, w: FontWeight.w700, size: 18),
    titleLarge: escalar(base.titleLarge, w: FontWeight.w700, size: 18),
    titleMedium: escalar(base.titleMedium, w: FontWeight.w700, size: 16),
    titleSmall: escalar(base.titleSmall, w: FontWeight.w600, size: 14),
    bodyLarge: escalar(base.bodyLarge, w: FontWeight.w400, size: 16),
    bodyMedium: escalar(base.bodyMedium, w: FontWeight.w400, size: 14),
    bodySmall: escalar(base.bodySmall, w: FontWeight.w400, size: 12, color: cs.onSurfaceVariant),
    labelLarge: escalar(base.labelLarge, w: FontWeight.w600, size: 14),
    labelMedium: escalar(base.labelMedium, w: FontWeight.w500, size: 12),
    labelSmall: escalar(base.labelSmall, w: FontWeight.w400, size: 11, color: Virtus.textoTenue),
  );
}

/// [compacto]: teléfono (lado corto < 600). Tablet usa el tamaño grande.
ThemeData tema({bool compacto = false}) {
  final cs = const ColorScheme(
    brightness: Brightness.light,
    primary: Virtus.marca,
    onPrimary: Colors.white,
    primaryContainer: Virtus.marcaSuave,
    onPrimaryContainer: Virtus.marcaOscura,
    secondary: Virtus.marcaOscura,
    onSecondary: Colors.white,
    secondaryContainer: Virtus.marcaSuave,
    onSecondaryContainer: Virtus.marcaOscura,
    tertiary: Virtus.enMarcha,
    onTertiary: Colors.white,
    tertiaryContainer: Virtus.enMarchaSuave,
    onTertiaryContainer: Color(0xFF145A38),
    error: Virtus.error,
    onError: Colors.white,
    errorContainer: Virtus.errorSuave,
    onErrorContainer: Color(0xFF7A160F),
    surface: Virtus.fondo,
    onSurface: Virtus.texto,
    onSurfaceVariant: Virtus.textoSecundario,
    outline: Color(0xFF9A938C),
    outlineVariant: Virtus.borde,
    surfaceContainerLowest: Virtus.superficie,
    surfaceContainerLow: Color(0xFFFBF9F7),
    surfaceContainer: Color(0xFFF3EEE9),
    surfaceContainerHigh: Color(0xFFEDE7E1),
    surfaceContainerHighest: Color(0xFFE6DED8),
    inverseSurface: Virtus.marcaOscura,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFFE8A0AB),
    shadow: Color(0xFF1E1B19),
    scrim: Color(0xFF1E1B19),
  );

  final botonH = compacto ? 48.0 : 52.0;
  final fBoton = compacto ? 15.0 : 16.0;
  final rad = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Virtus.radio),
    side: const BorderSide(color: Virtus.borde, width: Virtus.grosorBorde),
  );
  final txtBoton = VirtusTexto.titulo(size: fBoton);
  final textTheme = _textoInter(cs, compacto: compacto);
  String? familiaInter;
  try {
    familiaInter = GoogleFonts.inter().fontFamily;
  } catch (_) {
    familiaInter = null;
  }

  return ThemeData(
    useMaterial3: true,
    fontFamily: familiaInter,
    colorScheme: cs,
    textTheme: textTheme,
    primaryTextTheme: textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    scaffoldBackgroundColor: Virtus.fondo,
    visualDensity: compacto ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkRipple.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: compacto ? 56 : 64,
      backgroundColor: Virtus.marcaOscura,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: VirtusTexto.importante(size: compacto ? 18 : 20, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white, size: VirtusIcono.cabecera),
      actionsIconTheme: const IconThemeData(color: Colors.white, size: VirtusIcono.cabecera),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
        textStyle: txtBoton,
        iconSize: VirtusIcono.medio,
        backgroundColor: Virtus.marca,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: rad,
        textStyle: txtBoton,
        iconSize: VirtusIcono.medio,
        elevation: 0,
        backgroundColor: Virtus.superficie,
        foregroundColor: Virtus.marcaOscura,
        shadowColor: Colors.transparent,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
        textStyle: txtBoton,
        iconSize: VirtusIcono.medio,
        foregroundColor: Virtus.marcaOscura,
        backgroundColor: Virtus.superficie,
        side: const BorderSide(color: Virtus.borde, width: Virtus.grosorBorde),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: txtBoton, foregroundColor: Virtus.marca),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        iconSize: VirtusIcono.cabecera,
        foregroundColor: null,
      ),
    ),
    iconTheme: const IconThemeData(size: VirtusIcono.medio, color: Virtus.marcaOscura),
    primaryIconTheme: const IconThemeData(size: VirtusIcono.cabecera, color: Colors.white),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Virtus.marca,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
      sizeConstraints: BoxConstraints.tightFor(width: compacto ? 56 : 64, height: compacto ? 56 : 64),
      extendedSizeConstraints: BoxConstraints(minHeight: compacto ? 48 : 56, minWidth: 48),
      extendedTextStyle: VirtusTexto.titulo(size: compacto ? 15 : 16, color: Colors.white),
      iconSize: VirtusIcono.medio,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: compacto ? 64 : 72,
      backgroundColor: Virtus.superficie,
      indicatorColor: Virtus.marcaSuave,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: VirtusIcono.nav,
          color: s.contains(WidgetState.selected) ? Virtus.marca : Virtus.textoSecundario,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => VirtusTexto.tenue(
          size: compacto ? 11 : 12,
          color: s.contains(WidgetState.selected) ? Virtus.marca : Virtus.textoSecundario,
        ).copyWith(fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Virtus.marcaOscura,
      indicatorColor: Colors.white.withValues(alpha: 0.18),
      selectedIconTheme: const IconThemeData(size: VirtusIcono.nav, color: Colors.white),
      unselectedIconTheme: const IconThemeData(size: VirtusIcono.nav, color: Colors.white70),
      selectedLabelTextStyle: VirtusTexto.titulo(size: 12, color: Colors.white),
      unselectedLabelTextStyle: VirtusTexto.tenue(size: 12, color: Colors.white70),
      labelType: NavigationRailLabelType.all,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: compacto ? 8 : 12,
      dense: compacto,
      contentPadding: EdgeInsets.symmetric(horizontal: compacto ? 14 : 16, vertical: compacto ? 0 : 2),
      textColor: Virtus.texto,
      iconColor: Virtus.marcaOscura,
      titleTextStyle: VirtusTexto.titulo(size: compacto ? 15 : 16),
      subtitleTextStyle: VirtusTexto.tenue(size: compacto ? 13 : 14),
      leadingAndTrailingTextStyle: VirtusTexto.cuerpo(size: compacto ? 13 : 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radioSm),
        side: const BorderSide(color: Virtus.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Virtus.superficie,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        borderSide: const BorderSide(color: Virtus.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        borderSide: const BorderSide(color: Virtus.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        borderSide: const BorderSide(color: Virtus.marca, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compacto ? 14 : 16),
      labelStyle: VirtusTexto.tenue(size: compacto ? 14 : 15),
      hintStyle: VirtusTexto.tenue(size: compacto ? 14 : 15, color: Virtus.textoTenue),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Virtus.superficie,
      selectedColor: Virtus.marcaSuave,
      side: const BorderSide(color: Virtus.borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radioSm)),
      labelStyle: VirtusTexto.titulo(size: compacto ? 13 : 14),
      secondaryLabelStyle: VirtusTexto.titulo(size: compacto ? 13 : 14, color: Virtus.marcaOscura),
      checkmarkColor: Virtus.marca,
      padding: EdgeInsets.symmetric(horizontal: compacto ? 6 : 8, vertical: compacto ? 4 : 6),
      iconTheme: const IconThemeData(size: VirtusIcono.chip, color: Virtus.marcaOscura),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: VirtusTexto.titulo(size: compacto ? 13 : 14),
        foregroundColor: Virtus.texto,
        selectedForegroundColor: Virtus.marcaOscura,
        selectedBackgroundColor: Virtus.marcaSuave,
        side: const BorderSide(color: Virtus.borde),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Virtus.marca,
      unselectedLabelColor: Virtus.textoSecundario,
      indicatorColor: Virtus.marca,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: VirtusTexto.titulo(size: compacto ? 14 : 15),
      unselectedLabelStyle: VirtusTexto.cuerpo(size: compacto ? 14 : 15),
    ),
    cardTheme: CardThemeData(
      color: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        side: const BorderSide(color: Virtus.borde, width: Virtus.grosorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Virtus.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      showDragHandle: true,
      dragHandleColor: Virtus.separador,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        side: const BorderSide(color: Virtus.borde),
      ),
      titleTextStyle: VirtusTexto.importante(size: compacto ? 18 : 20),
      contentTextStyle: VirtusTexto.tenue(size: compacto ? 14 : 15).copyWith(height: 1.4),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radioSm),
        side: const BorderSide(color: Virtus.borde),
      ),
      textStyle: VirtusTexto.cuerpo(size: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Virtus.marcaOscura,
      contentTextStyle: VirtusTexto.cuerpo(size: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radioSm)),
    ),
    dividerTheme: const DividerThemeData(color: Virtus.separador, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Virtus.marca,
      linearTrackColor: Color(0xFFEDE7E1),
      circularTrackColor: Color(0xFFEDE7E1),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: Virtus.error, textColor: Colors.white),
  );
}
