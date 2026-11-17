import 'package:material_ui/material_ui.dart';

import '../themes/app_colors.dart';

/// A compact pill showing a coloured dot beside the tag name.
class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forTag(tag);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          tag,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color == AppColors.ink ? AppColors.ink : color,
          ),
        ),
      ],
    );
  }
}
