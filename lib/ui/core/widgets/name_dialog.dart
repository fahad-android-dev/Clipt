import 'package:material_ui/material_ui.dart';

import '../themes/app_colors.dart';

/// Shows a dialog for entering a name.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String confirmLabel,
  String initialText = '',
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initialText: initialText,
      allowEmpty: allowEmpty,
    ),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initialText,
    required this.allowEmpty,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final String initialText;
  final bool allowEmpty;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (value) => _confirm(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (_, value, _) {
            final canConfirm =
                widget.allowEmpty || value.text.trim().isNotEmpty;
            return FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: canConfirm ? AppColors.accent : AppColors.line,
              ),
              onPressed: canConfirm
                  ? () => _confirm(context, _controller.text)
                  : null,
              child: Text(widget.confirmLabel),
            );
          },
        ),
      ],
    );
  }

  void _confirm(BuildContext context, String value) {
    Navigator.pop(context, value.trim());
  }
}
