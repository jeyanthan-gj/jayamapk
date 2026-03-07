import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors mapped from index.css
  static const Color primary = Color(0xFFF59E0B); // HSL 38, 92%, 50%
  static const Color background = Color(0xFFF1F5F9); // HSL 220, 20%, 97%
  static const Color foreground = Color(0xFF1E293B); // HSL 220, 25%, 10%
  static const Color card = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFFE2E8F0);
  static const Color mutedForeground = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkForeground = Color(0xFFF1F5F9);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkMuted = Color(0xFF1E293B);
  static const Color darkMutedForeground = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        background: background,
        surface: card,
        onBackground: foreground,
        onSurface: foreground,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: foreground),
        displayMedium: GoogleFonts.spaceGrotesk(color: foreground),
        displaySmall: GoogleFonts.spaceGrotesk(color: foreground),
        headlineLarge: GoogleFonts.spaceGrotesk(color: foreground),
        headlineMedium: GoogleFonts.spaceGrotesk(color: foreground),
        headlineSmall: GoogleFonts.spaceGrotesk(color: foreground),
        titleLarge: GoogleFonts.spaceGrotesk(color: foreground),
        titleMedium: GoogleFonts.spaceGrotesk(color: foreground),
        titleSmall: GoogleFonts.spaceGrotesk(color: foreground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        background: darkBackground,
        surface: darkCard,
        onBackground: darkForeground,
        onSurface: darkForeground,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.spaceGrotesk(color: darkForeground),
        displayMedium: GoogleFonts.spaceGrotesk(color: darkForeground),
        displaySmall: GoogleFonts.spaceGrotesk(color: darkForeground),
        headlineLarge: GoogleFonts.spaceGrotesk(color: darkForeground),
        headlineMedium: GoogleFonts.spaceGrotesk(color: darkForeground),
        headlineSmall: GoogleFonts.spaceGrotesk(color: darkForeground),
        titleLarge: GoogleFonts.spaceGrotesk(color: darkForeground),
        titleMedium: GoogleFonts.spaceGrotesk(color: darkForeground),
        titleSmall: GoogleFonts.spaceGrotesk(color: darkForeground),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
