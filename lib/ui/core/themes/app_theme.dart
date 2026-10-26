import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  /// Monospace style used for timers and timestamps.
  static TextStyle mono({
    double size = 16,
    FontWeight? weight,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.dmMono(fontSize: size, fontWeight: weight, color: color);
  }

  static ThemeData get light {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    final text = GoogleFonts.bricolageGrotesqueTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.paper,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        surface: AppColors.card,
        onSurface: AppColors.ink,
        outline: AppColors.line,
      ),
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      dividerColor: AppColors.line,
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
    );
  }
}