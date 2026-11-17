import 'package:material_ui/material_ui.dart';

import '../themes/app_colors.dart';
import '../themes/app_spacing.dart';

/// A sticky bottom bar with a summary label on the left and a primary
/// [FilledButton] on the right, padded for safe area.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.summaryText,
    required this.buttonLabel,
    required this.onPressed,
    this.disabledHint,
  });

  final String summaryText;
  final String buttonLabel;

  /// Null = disabled. Provide a tooltip hint when disabled.
  final VoidCallback? onPressed;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summaryText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Tooltip(
                message: onPressed == null ? (disabledHint ?? '') : '',
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onPressed,
                  child: Text(buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

