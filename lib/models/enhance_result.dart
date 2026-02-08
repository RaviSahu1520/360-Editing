import 'dart:typed_data';

class EnhanceResult {
  EnhanceResult({
    required this.variant,
    required this.url,
    this.cachedPath,
    this.bytes,
  });

  final String variant;
  final String url;
  String? cachedPath;
  Uint8List? bytes;

  factory EnhanceResult.fromJson(Map<String, dynamic> json) {
    return EnhanceResult(
      variant: json['variant'] as String? ?? '',
      url: json['url'] as String? ?? '',
      cachedPath: json['cached_path'] as String?,
    );
  }
}

class EnhanceResponse {
  const EnhanceResponse({
    required this.results,
    required this.model,
    required this.latencyMs,
    required this.requestId,
  });

  final List<EnhanceResult> results;
  final String model;
  final int latencyMs;
  final String? requestId;
}
