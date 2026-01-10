import 'package:flutter/material.dart';

const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF4ADE80), // scan accent
  onPrimary: Color(0xFF06210F),
  secondary: Color(0xFF38BDF8),
  onSecondary: Color(0xFF061A24),
  error: Color(0xFFEF4444),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFF0F1115),
  onSurface: Color(0xFFE7EAF0),
  surfaceContainerHighest: Color(0xFF1A1D23),
  onSurfaceVariant: Color(0xFFB6BECA),
  outline: Color(0xFF2B3240),
  outlineVariant: Color(0xFF242B38),
);

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: darkColorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: darkColorScheme.surface,
      foregroundColor: darkColorScheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: darkColorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
  );
}
