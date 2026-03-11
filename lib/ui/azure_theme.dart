import 'package:flutter/material.dart';

class AzureTheme {
  static const Color azure = Color(0xFF1279FF);
  static const Color azureDark = Color(0xFF0A4FC3);
  static const Color sky = Color(0xFF6BD7FF);
  static const Color ink = Color(0xFF081A33);
  static const Color mist = Color(0xFFF2F8FF);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color glass = Color(0xB8FFFFFF);
  static const Color glassStrong = Color(0xD9FFFFFF);
  static const Color glassStroke = Color(0x85FFFFFF);
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
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: glassStroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: glassStroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x99FFFFFF), width: 1.2),
        ),
        labelStyle: const TextStyle(color: ink),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: glass,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: glassStroke),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: glassStrong,
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(56),
          disabledBackgroundColor: glass,
          disabledForegroundColor: ink.withValues(alpha: 0.45),
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: glassStroke),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: glass,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: glassStroke),
          disabledForegroundColor: ink.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return azure;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return azure.withValues(alpha: 0.55);
          }
          return const Color(0x5FFFFFFF);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => const Color(0x55FFFFFF),
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: azure,
        inactiveTrackColor: Color(0x66FFFFFF),
        thumbColor: azure,
        overlayColor: Color(0x14FFFFFF),
        valueIndicatorColor: Color(0xD9FFFFFF),
        valueIndicatorTextStyle: TextStyle(color: ink),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        selectedColor: glassStrong,
        backgroundColor: glass,
        side: const BorderSide(color: glassStroke),
        labelStyle: const TextStyle(color: ink),
        checkmarkColor: ink,
      ),
    );
  }
}
