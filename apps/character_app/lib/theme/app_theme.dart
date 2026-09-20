import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette « fantasy sombre » retenue lors du brainstorming design
/// (maquette `Main.dc.html`) : fond quasi-noir, accent or, texte ivoire.
abstract final class AppTheme {
  static const background = Color(0xFF1C1712);
  static const surface = Color(0xFF26201A);
  static const border = Color(0xFF3A2F23);
  static const accent = Color(0xFFC9A227);
  static const textPrimary = Color(0xFFEDE3D0);
  static const textMuted = Color(0xFFA89676);

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      onPrimary: background,
      surface: surface,
      onSurface: textPrimary,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.workSansTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          textStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
