/// Export resolution and watermark settings.
class ExportLimits {
  const ExportLimits({
    required this.maxShortSide,
    required this.watermark,
  });

  final int maxShortSide;
  final bool watermark;

  static const free = ExportLimits(maxShortSide: 720, watermark: true);
  static const pro = ExportLimits(maxShortSide: 1080, watermark: false);
}
