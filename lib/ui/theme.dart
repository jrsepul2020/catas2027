import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Paleta: azules, rojos, amarillos y lila con sus tonos pastel.
abstract final class Paleta {
  static const azul = Color(0xFF2F64B0);
  static const azulOscuro = Color(0xFF15365F);
  static const azulPastel = Color(0xFFDCE8F8);
  static const rojo = Color(0xFFC63A45);
  static const rojoOscuro = Color(0xFF5E1219);
  static const rojoPastel = Color(0xFFF9DDE0);
  static const amarillo = Color(0xFFE7B416);
  static const amarilloOscuro = Color(0xFF6B4E00);
  static const amarilloPastel = Color(0xFFFFF2C6);
  static const lila = Color(0xFF7E5FC0);
  static const lilaOscuro = Color(0xFF2E1A52);
  static const lilaPastel = Color(0xFFECE4F9);
  static const fondo = Color(0xFFF7F8FC);
  static const texto = Color(0xFF1B1D29);
  static const textoSuave = Color(0xFF4C5065);
}

/// [compacto]: teléfono (lado corto < 600). Tablet usa el tamaño grande.
ThemeData tema({bool compacto = false}) {
  final cs = ColorScheme.fromSeed(seedColor: Paleta.azul, brightness: Brightness.light).copyWith(
    primary: Paleta.azul,
    onPrimary: Colors.white,
    primaryContainer: Paleta.azulPastel,
    onPrimaryContainer: Paleta.azulOscuro,
    secondary: Paleta.rojo,
    onSecondary: Colors.white,
    secondaryContainer: Paleta.rojoPastel,
    onSecondaryContainer: Paleta.rojoOscuro,
    tertiary: Paleta.lila,
    onTertiary: Colors.white,
    tertiaryContainer: Paleta.lilaPastel,
    onTertiaryContainer: Paleta.lilaOscuro,
    error: Paleta.rojo,
    errorContainer: Paleta.rojoPastel,
    onErrorContainer: Paleta.rojoOscuro,
    surface: Paleta.fondo,
    onSurface: Paleta.texto,
    onSurfaceVariant: Paleta.textoSuave,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF2F4FB),
    surfaceContainer: const Color(0xFFECEFF8),
    surfaceContainerHigh: const Color(0xFFE6EAF6),
    surfaceContainerHighest: const Color(0xFFDFE4F3),
    outline: const Color(0xFF7A7F94),
    outlineVariant: const Color(0xFFC8CDDD),
  );

  // Medidas: en teléfono todo más contenido para no hacer scroll.
  final boton = compacto ? 48.0 : 64.0;
  final icono = compacto ? 24.0 : 28.0;
  final fBoton = compacto ? 16.0 : 18.0;
  final rad = RoundedRectangleBorder(borderRadius: BorderRadius.circular(compacto ? 14 : 18));
  final txtBoton = TextStyle(fontSize: fBoton, fontWeight: FontWeight.w600);
  final base = ThemeData(useMaterial3: true, colorScheme: cs);
  final tt = base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

  return base.copyWith(
    textTheme: tt,
    scaffoldBackgroundColor: cs.surface,
    visualDensity: compacto ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: compacto ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
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
      toolbarHeight: compacto ? 54 : 68,
      backgroundColor: Paleta.azulOscuro,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: compacto ? 20 : 24, fontWeight: FontWeight.w800, color: Colors.white),
      iconTheme: IconThemeData(color: Colors.white, size: compacto ? 24 : 28),
      actionsIconTheme: IconThemeData(color: Colors.white, size: compacto ? 24 : 28),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: Size(boton, boton), shape: rad, textStyle: txtBoton, iconSize: icono),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(boton, boton),
        shape: rad,
        textStyle: txtBoton,
        iconSize: icono,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(boton, boton),
        shape: rad,
        textStyle: txtBoton,
        iconSize: icono,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: Size(compacto ? 44 : 56, compacto ? 44 : 56), textStyle: txtBoton),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: Size(compacto ? 44 : 56, compacto ? 44 : 56),
        iconSize: compacto ? 26 : 30,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      sizeConstraints: BoxConstraints.tightFor(width: compacto ? 60 : 76, height: compacto ? 60 : 76),
      extendedSizeConstraints: BoxConstraints(minHeight: compacto ? 52 : 72, minWidth: 52),
      extendedTextStyle: TextStyle(fontSize: compacto ? 17 : 20, fontWeight: FontWeight.w700, color: cs.onPrimary),
      iconSize: compacto ? 26 : 34,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: compacto ? 64 : 84,
      backgroundColor: Paleta.azulOscuro,
      indicatorColor: Paleta.azul,
      surfaceTintColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: compacto ? 26 : 32,
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: compacto ? 12 : 14,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Colors.white : Colors.white70,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Paleta.azulOscuro,
      indicatorColor: Paleta.azul,
      selectedIconTheme: const IconThemeData(size: 32, color: Colors.white),
      unselectedIconTheme: const IconThemeData(size: 30, color: Colors.white70),
      selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
      unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70),
      labelType: NavigationRailLabelType.all,
    ),
    // Colores explícitos: sin ellos los textos de listas salían blancos.
    listTileTheme: ListTileThemeData(
      minVerticalPadding: compacto ? 6 : 14,
      dense: compacto,
      contentPadding: EdgeInsets.symmetric(horizontal: compacto ? 14 : 20, vertical: compacto ? 0 : 4),
      textColor: cs.onSurface,
      iconColor: cs.primary,
      titleTextStyle: TextStyle(fontSize: compacto ? 16 : 19, fontWeight: FontWeight.w600, color: cs.onSurface),
      subtitleTextStyle: TextStyle(fontSize: compacto ? 13 : 15, color: cs.onSurfaceVariant),
      leadingAndTrailingTextStyle: TextStyle(fontSize: compacto ? 14 : 16, color: cs.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: compacto ? 14 : 20),
      labelStyle: TextStyle(fontSize: compacto ? 16 : 18, color: cs.onSurfaceVariant),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: cs.primaryContainer,
      side: BorderSide(color: cs.outlineVariant),
      labelStyle: TextStyle(fontSize: compacto ? 14 : 16, fontWeight: FontWeight.w600, color: cs.onSurface),
      secondaryLabelStyle: TextStyle(
        fontSize: compacto ? 14 : 16,
        fontWeight: FontWeight.w700,
        color: cs.onPrimaryContainer,
      ),
      checkmarkColor: cs.onPrimaryContainer,
      padding: EdgeInsets.symmetric(horizontal: compacto ? 4 : 10, vertical: compacto ? 4 : 10),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: Size(44, compacto ? 44 : 56),
        textStyle: TextStyle(fontSize: compacto ? 14 : 17, fontWeight: FontWeight.w700, color: cs.onSurface),
        foregroundColor: cs.onSurface,
        selectedForegroundColor: cs.onPrimaryContainer,
        selectedBackgroundColor: cs.primaryContainer,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: cs.primary,
      unselectedLabelColor: cs.onSurfaceVariant,
      indicatorColor: cs.primary,
      labelStyle: TextStyle(fontSize: compacto ? 15 : 18, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compacto ? 14 : 22),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: cs.surfaceContainerLowest,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: compacto ? 20 : 24, fontWeight: FontWeight.w800, color: cs.onSurface),
      contentTextStyle: TextStyle(fontSize: compacto ? 16 : 18, color: cs.onSurface),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surfaceContainerLowest,
      textStyle: TextStyle(fontSize: 16, color: cs.onSurface),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: cs.outlineVariant),
  );
}
