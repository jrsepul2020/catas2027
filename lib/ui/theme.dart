import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const vino = Color(0xFF7B1E3A);

ThemeData tema(Brightness b) {
  final cs = ColorScheme.fromSeed(seedColor: vino, brightness: b);
  const big = Size(64, 64);
  final rad = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  const txt = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // Transiciones rápidas: prima la velocidad.
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
      toolbarHeight: 68,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cs.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: big, shape: rad, textStyle: txt, iconSize: 28),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(minimumSize: big, shape: rad, textStyle: txt, iconSize: 28),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: big, shape: rad, textStyle: txt, iconSize: 28),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(56, 56), textStyle: txt),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(56, 56), iconSize: 30)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      sizeConstraints: BoxConstraints.tightFor(width: 76, height: 76),
      extendedSizeConstraints: BoxConstraints(minHeight: 72, minWidth: 72),
      extendedTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      iconSize: 34,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 84,
      iconTheme: WidgetStateProperty.all(const IconThemeData(size: 32)),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      selectedIconTheme: IconThemeData(size: 32),
      unselectedIconTheme: IconThemeData(size: 30),
      labelType: NavigationRailLabelType.all,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 14,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
      subtitleTextStyle: TextStyle(fontSize: 15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      labelStyle: const TextStyle(fontSize: 18),
    ),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(56, 56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
