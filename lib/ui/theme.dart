import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño Virtus Gestión 2027 (FASE 1).
///
/// Tokens semánticos + alias históricos de [Paleta] (las pantallas aún los usan).
/// Los pastel se han suavizado: dejan de ser fondos decorativos intensos.
abstract final class Virtus {
  // —— Núcleo (brief rediseño) ——
  static const marino = Color(0xFF173456);
  static const accion = Color(0xFF2563EB);
  static const fondo = Color(0xFFF7F8FA);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF172033);
  static const textoSecundario = Color(0xFF64748B);
  static const borde = Color(0xFFE2E8F0);
  static const exito = Color(0xFF15803D);
  static const advertencia = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);

  // —— Tonos de apoyo (contenedores / chips) ——
  static const accionSuave = Color(0xFFEFF6FF);
  static const marinoSuave = Color(0xFFE8EEF5);
  static const exitoSuave = Color(0xFFF0FDF4);
  static const advertenciaSuave = Color(0xFFFFFBEB);
  static const errorSuave = Color(0xFFFEF2F2);
  static const neutroSuave = Color(0xFFF1F5F9);

  static const radio = 12.0;
  static const radioSm = 8.0;
  static const elevacion = 0.5;
}

/// Alias de compatibilidad con el código existente.
/// No usar nombres nuevos en pantallas hasta FASE 2+; aquí se redirigen al sistema nuevo.
abstract final class Paleta {
  static const azul = Virtus.accion;
  static const azulOscuro = Virtus.marino;
  static const azulPastel = Virtus.accionSuave;
  static const rojo = Virtus.error;
  static const rojoOscuro = Color(0xFF991B1B);
  static const rojoPastel = Virtus.errorSuave;
  static const amarillo = Virtus.advertencia;
  static const amarilloOscuro = Color(0xFF92400E);
  static const amarilloPastel = Virtus.advertenciaSuave;

  /// Antes lila decorativo → ahora éxito / cerrado / presidente (semántico).
  static const lila = Virtus.exito;
  static const lilaOscuro = Color(0xFF14532D);
  static const lilaPastel = Virtus.exitoSuave;
  static const fondo = Virtus.fondo;
  static const texto = Virtus.texto;
  static const textoSuave = Virtus.textoSecundario;
}

TextTheme _textoInter(ColorScheme cs, {required bool compacto}) {
  final base = GoogleFonts.interTextTheme().apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  // Escala sobria: menos saltos extremos entre móvil y tablet.
  final escala = compacto ? 0.95 : 1.0;
  TextStyle escalar(TextStyle? s, {FontWeight? w, double? size}) {
    final t = s ?? const TextStyle();
    return t.copyWith(
      fontWeight: w ?? t.fontWeight,
      fontSize: size != null ? size * escala : (t.fontSize == null ? null : t.fontSize! * escala),
      letterSpacing: t.letterSpacing ?? -0.1,
      height: t.height ?? 1.25,
      color: t.color ?? cs.onSurface,
    );
  }

  return base.copyWith(
    displayLarge: escalar(base.displayLarge, w: FontWeight.w700, size: 32),
    displayMedium: escalar(base.displayMedium, w: FontWeight.w700, size: 28),
    displaySmall: escalar(base.displaySmall, w: FontWeight.w700, size: 24),
    headlineLarge: escalar(base.headlineLarge, w: FontWeight.w700, size: 22),
    headlineMedium: escalar(base.headlineMedium, w: FontWeight.w700, size: 20),
    headlineSmall: escalar(base.headlineSmall, w: FontWeight.w600, size: 18),
    titleLarge: escalar(base.titleLarge, w: FontWeight.w700, size: 18),
    titleMedium: escalar(base.titleMedium, w: FontWeight.w600, size: 16),
    titleSmall: escalar(base.titleSmall, w: FontWeight.w600, size: 14),
    bodyLarge: escalar(base.bodyLarge, w: FontWeight.w400, size: 16),
    bodyMedium: escalar(base.bodyMedium, w: FontWeight.w400, size: 14),
    bodySmall: escalar(base.bodySmall, w: FontWeight.w400, size: 12).copyWith(color: cs.onSurfaceVariant),
    labelLarge: escalar(base.labelLarge, w: FontWeight.w600, size: 14),
    labelMedium: escalar(base.labelMedium, w: FontWeight.w600, size: 12),
    labelSmall: escalar(base.labelSmall, w: FontWeight.w600, size: 11).copyWith(color: cs.onSurfaceVariant),
  );
}

/// [compacto]: teléfono (lado corto < 600). Tablet usa el tamaño grande.
ThemeData tema({bool compacto = false}) {
  final cs = const ColorScheme(
    brightness: Brightness.light,
    primary: Virtus.accion,
    onPrimary: Colors.white,
    primaryContainer: Virtus.accionSuave,
    onPrimaryContainer: Virtus.marino,
    secondary: Virtus.marino,
    onSecondary: Colors.white,
    secondaryContainer: Virtus.marinoSuave,
    onSecondaryContainer: Virtus.marino,
    tertiary: Virtus.exito,
    onTertiary: Colors.white,
    tertiaryContainer: Virtus.exitoSuave,
    onTertiaryContainer: Color(0xFF14532D),
    error: Virtus.error,
    onError: Colors.white,
    errorContainer: Virtus.errorSuave,
    onErrorContainer: Color(0xFF991B1B),
    surface: Virtus.fondo,
    onSurface: Virtus.texto,
    onSurfaceVariant: Virtus.textoSecundario,
    outline: Color(0xFF94A3B8),
    outlineVariant: Virtus.borde,
    surfaceContainerLowest: Virtus.superficie,
    surfaceContainerLow: Color(0xFFF8FAFC),
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerHigh: Color(0xFFE2E8F0),
    surfaceContainerHighest: Color(0xFFCBD5E1),
    inverseSurface: Virtus.marino,
    onInverseSurface: Colors.white,
    inversePrimary: Color(0xFF93C5FD),
    shadow: Color(0xFF0F172A),
    scrim: Color(0xFF0F172A),
  );

  final botonH = compacto ? 48.0 : 52.0;
  final icono = compacto ? 22.0 : 24.0;
  final fBoton = compacto ? 15.0 : 16.0;
  final rad = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio));
  final txtBoton = GoogleFonts.inter(fontSize: fBoton, fontWeight: FontWeight.w600);
  final textTheme = _textoInter(cs, compacto: compacto);

  return ThemeData(
    useMaterial3: true,
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
      scrolledUnderElevation: 0.5,
      toolbarHeight: compacto ? 56 : 64,
      backgroundColor: Virtus.marino,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: compacto ? 18 : 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: compacto ? 22 : 24),
      actionsIconTheme: IconThemeData(color: Colors.white, size: compacto ? 22 : 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: rad,
        textStyle: txtBoton,
        iconSize: icono,
        backgroundColor: Virtus.accion,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: rad,
        textStyle: txtBoton,
        iconSize: icono,
        elevation: Virtus.elevacion,
        backgroundColor: Virtus.superficie,
        foregroundColor: Virtus.marino,
        shadowColor: Virtus.marino.withValues(alpha: 0.08),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: rad,
        textStyle: txtBoton,
        iconSize: icono,
        foregroundColor: Virtus.marino,
        side: const BorderSide(color: Virtus.borde),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: txtBoton, foregroundColor: Virtus.accion),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        iconSize: compacto ? 22 : 24,
        foregroundColor: null, // hereda del AppBar / contexto
      ),
    ),
    iconTheme: IconThemeData(size: compacto ? 22 : 24, color: Virtus.textoSecundario),
    primaryIconTheme: const IconThemeData(size: 24, color: Colors.white),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Virtus.accion,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
      sizeConstraints: BoxConstraints.tightFor(width: compacto ? 56 : 64, height: compacto ? 56 : 64),
      extendedSizeConstraints: BoxConstraints(minHeight: compacto ? 48 : 56, minWidth: 48),
      extendedTextStyle: GoogleFonts.inter(
        fontSize: compacto ? 15 : 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconSize: compacto ? 22 : 24,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: compacto ? 64 : 72,
      backgroundColor: Virtus.marino,
      indicatorColor: Virtus.accion.withValues(alpha: 0.35),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: compacto ? 22 : 24,
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => GoogleFonts.inter(
          fontSize: compacto ? 11 : 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Virtus.marino,
      indicatorColor: Virtus.accion.withValues(alpha: 0.35),
      selectedIconTheme: const IconThemeData(size: 24, color: Colors.white),
      unselectedIconTheme: const IconThemeData(size: 24, color: Colors.white70),
      selectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12),
      unselectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 12),
      labelType: NavigationRailLabelType.all,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: compacto ? 8 : 12,
      dense: compacto,
      contentPadding: EdgeInsets.symmetric(horizontal: compacto ? 14 : 16, vertical: compacto ? 0 : 2),
      textColor: Virtus.texto,
      iconColor: Virtus.textoSecundario,
      titleTextStyle: GoogleFonts.inter(fontSize: compacto ? 15 : 16, fontWeight: FontWeight.w600, color: Virtus.texto),
      subtitleTextStyle: GoogleFonts.inter(fontSize: compacto ? 13 : 14, color: Virtus.textoSecundario),
      leadingAndTrailingTextStyle: GoogleFonts.inter(fontSize: compacto ? 13 : 14, color: Virtus.texto),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radioSm)),
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
        borderSide: const BorderSide(color: Virtus.accion, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compacto ? 14 : 16),
      labelStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, color: Virtus.textoSecundario),
      hintStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, color: Virtus.textoSecundario),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Virtus.superficie,
      selectedColor: Virtus.accionSuave,
      side: const BorderSide(color: Virtus.borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radioSm)),
      labelStyle: GoogleFonts.inter(fontSize: compacto ? 13 : 14, fontWeight: FontWeight.w600, color: Virtus.texto),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: compacto ? 13 : 14,
        fontWeight: FontWeight.w600,
        color: Virtus.marino,
      ),
      checkmarkColor: Virtus.accion,
      padding: EdgeInsets.symmetric(horizontal: compacto ? 6 : 8, vertical: compacto ? 4 : 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: GoogleFonts.inter(fontSize: compacto ? 13 : 14, fontWeight: FontWeight.w600),
        foregroundColor: Virtus.texto,
        selectedForegroundColor: Virtus.marino,
        selectedBackgroundColor: Virtus.accionSuave,
        side: const BorderSide(color: Virtus.borde),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: Virtus.accion,
      unselectedLabelColor: Virtus.textoSecundario,
      indicatorColor: Virtus.accion,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: Virtus.elevacion,
      shadowColor: Virtus.marino.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radio),
        side: const BorderSide(color: Virtus.borde),
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
      dragHandleColor: Virtus.borde,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
      titleTextStyle: GoogleFonts.inter(fontSize: compacto ? 18 : 20, fontWeight: FontWeight.w700, color: Virtus.texto),
      contentTextStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, color: Virtus.texto, height: 1.4),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Virtus.radioSm),
        side: const BorderSide(color: Virtus.borde),
      ),
      textStyle: GoogleFonts.inter(fontSize: 14, color: Virtus.texto),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Virtus.marino,
      contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radioSm)),
    ),
    dividerTheme: const DividerThemeData(color: Virtus.borde, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Virtus.accion,
      linearTrackColor: Virtus.borde,
      circularTrackColor: Virtus.borde,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: Virtus.error, textColor: Colors.white),
  );
}
