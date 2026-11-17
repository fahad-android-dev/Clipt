import 'package:material_ui/material_ui.dart';

import '../themes/app_colors.dart';

class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}
