class AppConstants {
  static const String appName = 'Photo Editor + Auto Improve';
  static const String appVersion = 'v0.1.0';

  /// API base URL for backend calls.
  ///
  /// Supported dart-define keys:
  /// 1) PHOTO_EDITOR_API_URL (project-native)
  /// 2) API_BASE_URL (compatible with common .env setups)
  ///
  /// Example:
  /// flutter run --dart-define=API_BASE_URL=https://api.fitcheckaiapp.com
  static String get apiBaseUrl {
    const projectUrl = String.fromEnvironment('PHOTO_EDITOR_API_URL');
    if (projectUrl.isNotEmpty) {
      return projectUrl;
    }

    const genericUrl = String.fromEnvironment('API_BASE_URL');
    if (genericUrl.isNotEmpty) {
      return genericUrl;
    }

    // Default to user's backend API
    return 'https://api.fitcheckaiapp.com';
  }

  /// Gemini API key for direct AI calls (fallback)
  ///
  /// IMPORTANT: Set this via dart-define for production:
  /// flutter run --dart-define=GEMINI_API_KEY=your_actual_key
  static String get geminiApiKey {
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }
    // No fallback - API key must be provided via dart-define
    return '';
  }

  static const int maxUploadBytes = 15 * 1024 * 1024;
  static const int previewMaxLongEdge = 1600;
  static const int sourceMaxLongEdge = 4096;
  static const int filterThumbEdge = 140;
  static const int aiInputLongEdge = 2048;
  static const int minHistoryActions = 10;
  static const int historyLimit = 30;
  static const int recentLimit = 5;
  static const int renderDebounceMs = 50;
  static const int networkTimeoutMs = 30000; // Increased timeout
  static const int networkRetryCount = 2;

  static const List<String> cropRatios = <String>[
    'Free',
    '1:1',
    '4:5',
    '16:9',
    '9:16',
  ];

  static const List<String> grades = <String>[
    'Natural',
    'Warm',
    'Cool',
    'Cinematic',
  ];

  static const List<int> exportQualities = <int>[70, 85, 100];

  /// Use local enhancement fallback when API is unavailable
  static const bool useLocalEnhancementFallback = true;
}
