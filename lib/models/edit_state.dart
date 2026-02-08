import 'dart:math' as math;

enum FilterPreset {
  none,
  warm,
  cool,
  bw,
  vintage,
  cinematic,
  pop,
  fade,
  clarity,
  sunset,
  mono,
}

class CropParams {
  const CropParams({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.ratio,
    required this.quarterTurns,
    required this.fineRotationDegrees,
    required this.flipHorizontal,
    required this.flipVertical,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final String ratio;
  final int quarterTurns;
  final double fineRotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;

  factory CropParams.initial() {
    return const CropParams(
      x: 0,
      y: 0,
      width: 1,
      height: 1,
      ratio: 'Free',
      quarterTurns: 0,
      fineRotationDegrees: 0,
      flipHorizontal: false,
      flipVertical: false,
    );
  }

  CropParams copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? ratio,
    int? quarterTurns,
    double? fineRotationDegrees,
    bool? flipHorizontal,
    bool? flipVertical,
  }) {
    return CropParams(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      ratio: ratio ?? this.ratio,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      fineRotationDegrees: fineRotationDegrees ?? this.fineRotationDegrees,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'ratio': ratio,
      'quarterTurns': quarterTurns,
      'fineRotationDegrees': fineRotationDegrees,
      'flipHorizontal': flipHorizontal,
      'flipVertical': flipVertical,
    };
  }

  factory CropParams.fromJson(Map<String, dynamic> json) {
    return CropParams(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 1,
      ratio: json['ratio'] as String? ?? 'Free',
      quarterTurns: (json['quarterTurns'] as num?)?.toInt() ?? 0,
      fineRotationDegrees:
          (json['fineRotationDegrees'] as num?)?.toDouble() ?? 0,
      flipHorizontal: json['flipHorizontal'] as bool? ?? false,
      flipVertical: json['flipVertical'] as bool? ?? false,
    );
  }
}

class AdjustmentValues {
  const AdjustmentValues({
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.vibrance,
    required this.highlights,
    required this.shadows,
    required this.sharpen,
    required this.blur,
  });

  final double brightness;
  final double contrast;
  final double saturation;
  final double vibrance;
  final double highlights;
  final double shadows;
  final double sharpen;
  final double blur;

  factory AdjustmentValues.initial() {
    return const AdjustmentValues(
      brightness: 0,
      contrast: 0,
      saturation: 0,
      vibrance: 0,
      highlights: 0,
      shadows: 0,
      sharpen: 0,
      blur: 0,
    );
  }

  AdjustmentValues copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? vibrance,
    double? highlights,
    double? shadows,
    double? sharpen,
    double? blur,
  }) {
    return AdjustmentValues(
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      vibrance: vibrance ?? this.vibrance,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      sharpen: sharpen ?? this.sharpen,
      blur: blur ?? this.blur,
    );
  }

  bool get isDefault {
    return brightness == 0 &&
        contrast == 0 &&
        saturation == 0 &&
        vibrance == 0 &&
        highlights == 0 &&
        shadows == 0 &&
        sharpen == 0 &&
        blur == 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'brightness': brightness,
      'contrast': contrast,
      'saturation': saturation,
      'vibrance': vibrance,
      'highlights': highlights,
      'shadows': shadows,
      'sharpen': sharpen,
      'blur': blur,
    };
  }

  factory AdjustmentValues.fromJson(Map<String, dynamic> json) {
    return AdjustmentValues(
      brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
      contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
      saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
      vibrance: (json['vibrance'] as num?)?.toDouble() ?? 0,
      highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
      shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
      sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0,
      blur: (json['blur'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EditState {
  const EditState({
    required this.crop,
    required this.filterPreset,
    required this.filterIntensity,
    required this.adjustments,
  });

  final CropParams crop;
  final FilterPreset filterPreset;
  final double filterIntensity;
  final AdjustmentValues adjustments;

  factory EditState.initial() {
    return EditState(
      crop: CropParams.initial(),
      filterPreset: FilterPreset.none,
      filterIntensity: 0,
      adjustments: AdjustmentValues.initial(),
    );
  }

  EditState copyWith({
    CropParams? crop,
    FilterPreset? filterPreset,
    double? filterIntensity,
    AdjustmentValues? adjustments,
  }) {
    return EditState(
      crop: crop ?? this.crop,
      filterPreset: filterPreset ?? this.filterPreset,
      filterIntensity: filterIntensity ?? this.filterIntensity,
      adjustments: adjustments ?? this.adjustments,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'crop': crop.toJson(),
      'filterPreset': filterPreset.name,
      'filterIntensity': filterIntensity,
      'adjustments': adjustments.toJson(),
    };
  }

  factory EditState.fromJson(Map<String, dynamic> json) {
    return EditState(
      crop: CropParams.fromJson(json['crop'] as Map<String, dynamic>? ?? {}),
      filterPreset: FilterPreset.values.firstWhere(
        (value) => value.name == json['filterPreset'],
        orElse: () => FilterPreset.none,
      ),
      filterIntensity: (json['filterIntensity'] as num?)?.toDouble() ?? 0,
      adjustments: AdjustmentValues.fromJson(
        json['adjustments'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  static CropParams centeredRectForRatio({
    required String ratio,
    required double imageWidth,
    required double imageHeight,
  }) {
    if (ratio == 'Free') {
      return CropParams.initial();
    }

    final parts = ratio.split(':');
    if (parts.length != 2) {
      return CropParams.initial().copyWith(ratio: ratio);
    }

    final ratioW = double.tryParse(parts.first) ?? 1;
    final ratioH = double.tryParse(parts.last) ?? 1;
    final target = ratioW / ratioH;
    final current = imageWidth / imageHeight;

    double cropW;
    double cropH;
    if (current > target) {
      cropH = imageHeight;
      cropW = cropH * target;
    } else {
      cropW = imageWidth;
      cropH = cropW / target;
    }

    final x = ((imageWidth - cropW) / 2) / imageWidth;
    final y = ((imageHeight - cropH) / 2) / imageHeight;
    final w = cropW / imageWidth;
    final h = cropH / imageHeight;

    return CropParams.initial().copyWith(
      x: math.max(0, x),
      y: math.max(0, y),
      width: w.clamp(0.0, 1.0),
      height: h.clamp(0.0, 1.0),
      ratio: ratio,
    );
  }
}
