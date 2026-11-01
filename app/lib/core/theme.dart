import 'package:flutter/material.dart';

/// Azul institucional da UFJF com acento âmbar.
const azulUfjf = Color(0xFF0B3D91);
const ambarUfjf = Color(0xFFF2A900);

ThemeData construirTema(Brightness brilho) {
  final esquema = ColorScheme.fromSeed(
    seedColor: azulUfjf,
    brightness: brilho,
    secondary: brilho == Brightness.light ? const Color(0xFF8A5A00) : ambarUfjf,
  );
  final base = ThemeData(
    colorScheme: esquema,
    useMaterial3: true,
    brightness: brilho,
  );
  return base.copyWith(
    scaffoldBackgroundColor: brilho == Brightness.light
        ? const Color(0xFFF6F7FB)
        : esquema.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: brilho == Brightness.light
          ? Colors.white
          : esquema.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: esquema.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: brilho == Brightness.light
          ? Colors.white
          : esquema.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: esquema.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brilho == Brightness.light
          ? Colors.white
          : esquema.surfaceContainerHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: brilho == Brightness.light
          ? Colors.white
          : esquema.surface,
      indicatorColor: esquema.primaryContainer,
    ),
  );
}

/// Pontos de quebra do layout responsivo (RNF13).
extension Breakpoints on BuildContext {
  double get largura => MediaQuery.sizeOf(this).width;
  bool get isMobile => largura < 700;
  bool get isDesktop => largura >= 1100;
}
