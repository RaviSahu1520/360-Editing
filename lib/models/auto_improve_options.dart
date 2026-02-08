class AutoImproveOptions {
  const AutoImproveOptions({
    required this.lighting,
    required this.skinImprovement,
    required this.sharpenDetails,
    required this.reduceNoise,
    required this.backgroundBlur,
    required this.colorGrading,
  });

  final bool lighting;
  final bool skinImprovement;
  final bool sharpenDetails;
  final bool reduceNoise;
  final bool backgroundBlur;
  final String colorGrading;

  factory AutoImproveOptions.initial() {
    return const AutoImproveOptions(
      lighting: true,
      skinImprovement: true,
      sharpenDetails: false,
      reduceNoise: false,
      backgroundBlur: false,
      colorGrading: 'Natural',
    );
  }

  AutoImproveOptions copyWith({
    bool? lighting,
    bool? skinImprovement,
    bool? sharpenDetails,
    bool? reduceNoise,
    bool? backgroundBlur,
    String? colorGrading,
  }) {
    return AutoImproveOptions(
      lighting: lighting ?? this.lighting,
      skinImprovement: skinImprovement ?? this.skinImprovement,
      sharpenDetails: sharpenDetails ?? this.sharpenDetails,
      reduceNoise: reduceNoise ?? this.reduceNoise,
      backgroundBlur: backgroundBlur ?? this.backgroundBlur,
      colorGrading: colorGrading ?? this.colorGrading,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'lighting': lighting,
      'skin_improvement': skinImprovement,
      'sharpen_details': sharpenDetails,
      'reduce_noise': reduceNoise,
      'background_blur': backgroundBlur,
      'color_grading': colorGrading,
    };
  }
}
