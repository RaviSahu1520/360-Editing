import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static const String appName = 'Photo Editor + Auto Improve';
  static const String appVersion = 'v0.1.0';

  /// API base URL for backend calls.
  ///
  /// Priority: .env file > dart-define > default
  static String get apiBaseUrl {
    // Try .env first
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl;
    }

    // Try dart-define
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

  /// Gemini API key for direct AI calls
  ///
  /// Priority: .env file > dart-define > default (empty)
  static String get geminiApiKey {
    // Try .env first
    final envKey = dotenv.env['GEMINI_API_KEY'];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    // Try dart-define
    const dartDefineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (dartDefineKey.isNotEmpty) {
      return dartDefineKey;
    }

    // No fallback
    return '';
  }

  /// Supabase Configuration
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabasePublishableKey =>
      dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
  static String get supabaseSecretKey =>
      dotenv.env['SUPABASE_SECRET_KEY'] ?? '';
  static String get supabaseJwtSecret =>
      dotenv.env['SUPABASE_JWT_SECRET'] ?? '';
  static String get supabaseStorageBucket =>
      dotenv.env['SUPABASE_STORAGE_BUCKET'] ?? 'fitcheck-images';

  /// Pinecone Configuration
  static String get pineconeApiKey =>
      dotenv.env['PINECONE_API_KEY'] ?? '';
  static String get pineconeIndexName =>
      dotenv.env['PINECONE_INDEX_NAME'] ?? 'fitcheck-items';
  static String get pineconeEnvironment =>
      dotenv.env['PINECONE_ENVIRONMENT'] ?? 'production';
  static String get pineconeDimension =>
      dotenv.env['PINECONE_DIMENSION'] ?? '768';

  /// AI Provider Configuration
  static String get aiDefaultProvider =>
      dotenv.env['AI_DEFAULT_PROVIDER'] ?? 'custom';

  /// Gemini AI Configuration
  static String get aiGeminiApiUrl =>
      dotenv.env['AI_GEMINI_API_URL'] ?? 'https://generativelanguage.googleapis.com/v1beta';
  static String get aiGeminiApiKey =>
      dotenv.env['AI_GEMINI_API_KEY'] ?? geminiApiKey;
  static String get aiGeminiChatModel =>
      dotenv.env['AI_GEMINI_CHAT_MODEL'] ?? 'gemini-3-flash-preview';
  static String get aiGeminiImageModel =>
      dotenv.env['AI_GEMINI_IMAGE_MODEL'] ?? 'gemini-3-pro-image-preview';

  /// OpenAI Configuration
  static String get aiOpenaiApiUrl =>
      dotenv.env['AI_OPENAI_API_URL'] ?? 'https://api.openai.com/v1';
  static String get aiOpenaiApiKey =>
      dotenv.env['AI_OPENAI_API_KEY'] ?? '';
  static String get aiOpenaiChatModel =>
      dotenv.env['AI_OPENAI_CHAT_MODEL'] ?? 'gpt-4o';

  /// Custom AI Provider Configuration
  static String get aiCustomApiUrl =>
      dotenv.env['AI_CUSTOM_API_URL'] ?? 'http://localhost:8317/v1';
  static String get aiCustomApiKey =>
      dotenv.env['AI_CUSTOM_API_KEY'] ?? '';
  static String get aiCustomChatModel =>
      dotenv.env['AI_CUSTOM_CHAT_MODEL'] ?? 'gemini-3-flash-preview';

  /// Weather API
  static String get weatherApiKey =>
      dotenv.env['WEATHER_API_KEY'] ?? '';

  /// Debug Mode
  static bool get isDebug {
    final debug = dotenv.env['DEBUG'];
    if (debug != null) {
      return debug.toLowerCase() == 'true';
    }
    // Check dart-define
    const debugDefine = String.fromEnvironment('DEBUG');
    if (debugDefine.isNotEmpty) {
      return debugDefine.toLowerCase() == 'true';
    }
    return false;
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
  static const int networkTimeoutMs = 30000;
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
