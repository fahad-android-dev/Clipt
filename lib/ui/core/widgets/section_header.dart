import 'package:material_ui/material_ui.dart';

import '../themes/app_colors.dart';

/// A small, all-caps muted label used to head sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted,
      ),
    );
  }
}

