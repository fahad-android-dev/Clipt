import 'package:material_ui/material_ui.dart';

/// "Paper" style: warm off-white, near-black ink, one vermilion accent.
abstract final class AppColors {
  static const paper = Color(0xFFF5F2EA);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B1B1B);
  static const muted = Color(0xFF7A756A);
  static const accent = Color(0xFFE4572E);
  static const line = Color(0xFFE3DFD4);

  // Tag colours
  /// Vermilion – used for "Clutch" (matches accent).
  static const tagClutch = Color(0xFFE4572E);

  /// Warm gold – used for "Funny".
  static const tagFunny = Color(0xFFD4A017);

  /// Muted blue-grey – used for "Fail".
  static const tagFail = Color(0xFF7A93A8);

  /// Light tint for selected/active chip backgrounds.
  static const surfaceTint = Color(0xFFFEEDE8);

  /// Returns the colour for a known tag, or [ink] as a safe default.
  static Color forTag(String tag) {
    switch (tag.toLowerCase()) {
      case 'clutch':
        return tagClutch;
      case 'funny':
        return tagFunny;
      case 'fail':
        return tagFail;
      default:
        return ink;
    }
  }
}
