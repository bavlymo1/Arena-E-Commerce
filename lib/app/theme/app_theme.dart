import 'package:flutter/material.dart';

/// Builds the ArenaPass Material 3 theme calibrated to the design prototype tokens.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;

  final bg = isDark ? const Color(0xFF09090B) : const Color(0xFFF7F5F6);
  final surface = isDark ? const Color(0xFF1B1A1E) : const Color(0xFFFFFFFF);
  final raised = isDark ? const Color(0xFF26242B) : const Color(0xFFEEE9ED);
  final text = isDark ? const Color(0xFFF5F3F5) : const Color(0xFF211B21);
  final muted = isDark ? const Color(0xFFBBB5BF) : const Color(0xFF665C68);
  final subtle = isDark ? const Color(0xFF8F8795) : const Color(0xFF766C7A);
  final line = isDark ? const Color(0xFF3A353F) : const Color(0xFFC7BAC5);
  final accent = isDark ? const Color(0xFFFF668E) : const Color(0xFFB92350);
  final onAccent = isDark ? const Color(0xFF260B14) : const Color(0xFFFFFFFF);
  final good = isDark ? const Color(0xFF7ED9AD) : const Color(0xFF18734D);
  final onGood = isDark ? const Color(0xFF09251A) : const Color(0xFFFFFFFF);
  final danger = isDark ? const Color(0xFFFFACB6) : const Color(0xFFA51F36);
  final onDanger = isDark ? const Color(0xFF3B0A13) : const Color(0xFFFFFFFF);

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    primaryContainer: isDark
        ? const Color(0xFF4B1628)
        : const Color(0xFFF9DCE6),
    onPrimaryContainer: isDark
        ? const Color(0xFFFFD9E2)
        : const Color(0xFF892547),
    secondary: good,
    onSecondary: onGood,
    secondaryContainer: raised,
    onSecondaryContainer: text,
    error: danger,
    onError: onDanger,
    errorContainer: isDark ? const Color(0xFF521824) : const Color(0xFFFCE8EC),
    onErrorContainer: isDark
        ? const Color(0xFFFFD9DE)
        : const Color(0xFF6E1122),
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: raised,
    outline: subtle,
    outlineVariant: line,
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(13),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: line),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: raised,
      contentTextStyle: TextStyle(color: text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        side: BorderSide(color: line),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        shape: buttonShape,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
