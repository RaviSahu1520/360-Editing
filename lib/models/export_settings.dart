enum ExportFormat {
  jpg,
  png,
}

class ExportSettings {
  const ExportSettings({
    required this.format,
    required this.quality,
  });

  final ExportFormat format;
  final int quality;

  factory ExportSettings.initial() {
    return const ExportSettings(
      format: ExportFormat.jpg,
      quality: 85,
    );
  }

  ExportSettings copyWith({
    ExportFormat? format,
    int? quality,
  }) {
    final nextQuality = quality ?? this.quality;
    return ExportSettings(
      format: format ?? this.format,
      quality: _normalizeQuality(nextQuality),
    );
  }

  String get extension => format == ExportFormat.jpg ? 'jpg' : 'png';

  String get mimeType =>
      format == ExportFormat.jpg ? 'image/jpeg' : 'image/png';

  static int _normalizeQuality(int value) {
    if (value <= 70) {
      return 70;
    }
    if (value >= 100) {
      return 100;
    }
    return value;
  }
}
