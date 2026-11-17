class OutputSize {
  const OutputSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
}

/// Calculates output dimensions based on max short side constraint.
OutputSize outputSize({
  required int width,
  required int height,
  required int maxShortSide,
}) {
  final shortSide = width < height ? width : height;
  if (shortSide <= maxShortSide) {
    return OutputSize(width: width, height: height);
  }

  final scale = maxShortSide / shortSide;
  final newWidth = ((width * scale).round() ~/ 2 * 2).clamp(2, double.maxFinite.toInt());
  final newHeight = ((height * scale).round() ~/ 2 * 2).clamp(2, double.maxFinite.toInt());

  return OutputSize(
    width: newWidth,
    height: newHeight,
  );
}

/// Calculates bitrate based on output size (short side).
int bitrateKbpsFor(OutputSize size) {
  final shortSide = size.width < size.height ? size.width : size.height;
  if (shortSide >= 1000) return 8000;
  if (shortSide >= 700) return 5000;
  return 3500;
}

/// Generates a sanitized filename for an exported clip.
String clipFileName({
  required String sessionTitle,
  required int index,
  required String tag,
}) {
  // Sanitize title: letters, digits, dash, underscore only; spaces to underscores
  final sanitizedTitle = sessionTitle
      .replaceAll(RegExp(r'[^a-zA-Z0-9\-_\s]'), '')
      .replaceAll(' ', '_')
      .substring(0, sessionTitle.length.clamp(0, 40));

  // Sanitize tag similarly
  final sanitizedTag = tag
      .replaceAll(RegExp(r'[^a-zA-Z0-9\-_\s]'), '')
      .replaceAll(' ', '_');

  // Index is 1-based, padded to 2 digits
  final indexStr = index.toString().padLeft(2, '0');

  return '${sanitizedTitle}_clip_$indexStr${sanitizedTag.isNotEmpty ? "_$sanitizedTag" : ""}.mp4';
}
