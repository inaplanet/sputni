import 'package:flutter/material.dart';

class AzureTheme {
  static const Color azure = Color(0xFF1279FF);
  static const Color azureDark = Color(0xFF0A4FC3);
  static const Color sky = Color(0xFF6BD7FF);
  static const Color ink = Color(0xFF081A33);
  static const Color mist = Color(0xFFF2F8FF);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF1CBA72);
  static const Color warning = Color(0xFFFFB020);

  static ThemeData theme() {
    const colorScheme = ColorScheme.light(
      primary: azure,
      secondary: sky,
      surface: panel,
      error: Color(0xFFD7263D),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: azure,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: Color(0xFFD6E7FF)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return azure;
          }
          return const Color(0xFFB7D5FF);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => Colors.transparent,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return azure.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: azure,
        thumbColor: azure,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        selectedColor: azure.withValues(alpha: 0.14),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFD7E8FF)),
        labelStyle: const TextStyle(color: ink),
      ),
    );
  }
}
