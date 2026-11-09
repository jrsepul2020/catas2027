import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño CATARIS Gestión 2027 (FASE 3 · filosofía maqueta VIRTUS).
///
/// Reglas:
/// - **Importante**: tipografía grande y negrita ([VirtusTexto.importante]).
/// - **Secundario**: peso fino y color tenue ([VirtusTexto.tenue]).
/// - **Un color de marca** (marino/azul) + pasteles/degradados para chrome y botones.
/// - **Verde / rojo** solo para estados positivos / negativos (avisos).
/// - Bordes visibles en tarjetas y botones; sin sombras pesadas.
/// - Separadores: raya fina gris claro ([SeparadorFino] en widgets).
abstract final class Virtus {
  // —— Marca (un solo color + tonos) ——
  static const marino = Color(0xFF1A3158);
  static const accion = Color(0xFF2563EB);
  static const fondo = Color(0xFFF4F7F9);
  static const superficie = Color(0xFFFFFFFF);
  static const texto = Color(0xFF172033);
  static const textoSecundario = Color(0xFF7B8798);
  static const textoTenue = Color(0xFF9AA3B2);
  static const borde = Color(0xFFE3E8EF);
  static const separador = Color(0xFFE8ECF1);

  // —— Estados (únicos colores fuera de la marca) ——
  static const exito = Color(0xFF22A45D);
  static const advertencia = Color(0xFFD97706);
  static const error = Color(0xFFDC3545);

  // —— Pasteles de marca / estado ——
  static const accionSuave = Color(0xFFEFF5FF);
  static const marinoSuave = Color(0xFFE8EEF5);
  static const exitoSuave = Color(0xFFECF9F1);
  static const advertenciaSuave = Color(0xFFFFF8EB);
  static const errorSuave = Color(0xFFFDECEC);
  static const neutroSuave = Color(0xFFF1F4F8);

  static const radio = 12.0;
  static const radioSm = 8.0;
  static const elevacion = 0.0;
  static const grosorBorde = 1.0;

  /// MaterialColor semántico (compat. con chips/estados que usan shade50…900).
  static MaterialColor material(Color base) {
    Color mezclar(double t) => Color.lerp(Colors.white, base, t)!;
    Color oscurecer(double t) => Color.lerp(base, const Color(0xFF0F172A), t)!;
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

  static final mcAccion = material(accion);
  static final mcAdvertencia = material(advertencia);
  static final mcExito = material(exito);
  static final mcError = material(error);
  static final mcNeutro = material(textoSecundario);
  static final mcMarino = material(marino);
}

/// Tipografía de jerarquía (maqueta): importante vs tenue.
abstract final class VirtusTexto {
  static TextStyle importante({double size = 20, Color color = Virtus.texto}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3, height: 1.15);

  static TextStyle titulo({double size = 16, Color color = Virtus.texto}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.2, height: 1.2);

  static TextStyle cuerpo({double size = 14, Color color = Virtus.texto}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w400, color: color, height: 1.35);

  static TextStyle tenue({double size = 13, Color color = Virtus.textoSecundario}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w300, color: color, height: 1.3);
}

/// Alias de compatibilidad con el código existente.
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
  static const lila = Virtus.exito;
  static const lilaOscuro = Color(0xFF14532D);
  static const lilaPastel = Virtus.exitoSuave;
  static const fondo = Virtus.fondo;
  static const texto = Virtus.texto;
  static const textoSuave = Virtus.textoSecundario;
}

TextTheme _textoInter(ColorScheme cs, {required bool compacto}) {
  final base = GoogleFonts.interTextTheme().apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
  final escala = compacto ? 0.95 : 1.0;
  TextStyle escalar(TextStyle? s, {FontWeight? w, double? size, Color? color}) {
    final t = s ?? const TextStyle();
    return t.copyWith(
      fontWeight: w ?? t.fontWeight,
      fontSize: size != null ? size * escala : (t.fontSize == null ? null : t.fontSize! * escala),
      letterSpacing: t.letterSpacing ?? -0.1,
      height: t.height ?? 1.25,
      color: color ?? t.color ?? cs.onSurface,
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
    bodySmall: escalar(base.bodySmall, w: FontWeight.w300, size: 12, color: cs.onSurfaceVariant),
    labelLarge: escalar(base.labelLarge, w: FontWeight.w600, size: 14),
    labelMedium: escalar(base.labelMedium, w: FontWeight.w500, size: 12),
    labelSmall: escalar(base.labelSmall, w: FontWeight.w300, size: 11, color: Virtus.textoTenue),
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
  final rad = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Virtus.radio),
    side: const BorderSide(color: Virtus.borde, width: Virtus.grosorBorde),
  );
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
      scrolledUnderElevation: 0,
      toolbarHeight: compacto ? 56 : 64,
      backgroundColor: Virtus.marino,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: compacto ? 18 : 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: compacto ? 22 : 24),
      actionsIconTheme: IconThemeData(color: Colors.white, size: compacto ? 22 : 24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
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
        elevation: 0,
        backgroundColor: Virtus.superficie,
        foregroundColor: Virtus.marino,
        shadowColor: Colors.transparent,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(48, botonH),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Virtus.radio)),
        textStyle: txtBoton,
        iconSize: icono,
        foregroundColor: Virtus.marino,
        backgroundColor: Virtus.superficie,
        side: const BorderSide(color: Virtus.borde, width: Virtus.grosorBorde),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48), textStyle: txtBoton, foregroundColor: Virtus.accion),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), iconSize: compacto ? 22 : 24, foregroundColor: null),
    ),
    iconTheme: IconThemeData(size: compacto ? 22 : 24, color: Virtus.marino),
    primaryIconTheme: const IconThemeData(size: 24, color: Colors.white),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Virtus.accion,
      foregroundColor: Colors.white,
      elevation: 0,
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
      indicatorColor: Virtus.accion.withValues(alpha: 0.4),
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
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w300,
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Virtus.marino,
      indicatorColor: Virtus.accion.withValues(alpha: 0.4),
      selectedIconTheme: const IconThemeData(size: 24, color: Colors.white),
      unselectedIconTheme: const IconThemeData(size: 24, color: Colors.white70),
      selectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 12),
      unselectedLabelTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w300, color: Colors.white70, fontSize: 12),
      labelType: NavigationRailLabelType.all,
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: compacto ? 8 : 12,
      dense: compacto,
      contentPadding: EdgeInsets.symmetric(horizontal: compacto ? 14 : 16, vertical: compacto ? 0 : 2),
      textColor: Virtus.texto,
      iconColor: Virtus.marino,
      titleTextStyle: GoogleFonts.inter(fontSize: compacto ? 15 : 16, fontWeight: FontWeight.w700, color: Virtus.texto),
      subtitleTextStyle: GoogleFonts.inter(
        fontSize: compacto ? 13 : 14,
        fontWeight: FontWeight.w300,
        color: Virtus.textoSecundario,
      ),
      leadingAndTrailingTextStyle: GoogleFonts.inter(fontSize: compacto ? 13 : 14, color: Virtus.texto),
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
        borderSide: const BorderSide(color: Virtus.accion, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compacto ? 14 : 16),
      labelStyle: GoogleFonts.inter(
        fontSize: compacto ? 14 : 15,
        fontWeight: FontWeight.w300,
        color: Virtus.textoSecundario,
      ),
      hintStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, fontWeight: FontWeight.w300, color: Virtus.textoTenue),
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
      unselectedLabelStyle: GoogleFonts.inter(fontSize: compacto ? 14 : 15, fontWeight: FontWeight.w300),
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
      titleTextStyle: GoogleFonts.inter(fontSize: compacto ? 18 : 20, fontWeight: FontWeight.w800, color: Virtus.texto),
      contentTextStyle: GoogleFonts.inter(
        fontSize: compacto ? 14 : 15,
        fontWeight: FontWeight.w300,
        color: Virtus.textoSecundario,
        height: 1.4,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Virtus.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
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
    dividerTheme: const DividerThemeData(color: Virtus.separador, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Virtus.accion,
      linearTrackColor: Virtus.separador,
      circularTrackColor: Virtus.separador,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: Virtus.error, textColor: Colors.white),
  );
}
