import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../diagnostics/app_logger.dart';
import '../models/auto_improve_options.dart';
import '../models/enhance_result.dart';
import '../services/analytics/analytics_service.dart';
import '../services/api/gemini_enhance_api.dart';
import '../services/local/enhance_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/guarded_async.dart';
import '../utils/request_id.dart';
import '../utils/result.dart';
import 'app_controller.dart';
import 'editor_controller.dart';

enum AutoImproveStatus {
  idle,
  generating,
  success,
  error,
}

class AutoImproveController extends GetxController {
  AutoImproveController({
    required GeminiEnhanceApi api,
    required StorageService storageService,
    required AnalyticsService analyticsService,
    required AppController appController,
    required AppLogger logger,
    LocalEnhanceService? localEnhanceService,
  })  : _api = api,
        _storageService = storageService,
        _analyticsService = analyticsService,
        _appController = appController,
        _logger = logger,
        _localEnhanceService = localEnhanceService ?? LocalEnhanceService(logger: logger);

  final GeminiEnhanceApi _api;
  final StorageService _storageService;
  final AnalyticsService _analyticsService;
  final AppController _appController;
  final AppLogger _logger;
  final LocalEnhanceService _localEnhanceService;

  final options = AutoImproveOptions.initial().obs;
  final status = AutoImproveStatus.idle.obs;
  final results = <EnhanceResult>[].obs;
  final selectedVariant = RxnString();
  final errorCode = RxnString();
  final errorMessage = RxnString();
  final requestId = RxnString();
  final lastLatencyMs = RxnInt();
  final lastModel = RxnString();

  OperationGuard? _guard;
  bool _isGenerateInFlight = false;

  @override
  void onClose() {
    cancelGeneration();
    super.onClose();
  }

  void markOpened() {
    _analyticsService.logEvent('auto_improve_opened');
  }

  void toggleLighting(bool value) {
    options.value = options.value.copyWith(lighting: value);
  }

  void toggleSkin(bool value) {
    options.value = options.value.copyWith(skinImprovement: value);
  }

  void toggleSharpen(bool value) {
    options.value = options.value.copyWith(sharpenDetails: value);
  }

  void toggleNoise(bool value) {
    options.value = options.value.copyWith(reduceNoise: value);
  }

  void toggleBlur(bool value) {
    if (!_appController.enableBackgroundBlur.value) {
      return;
    }
    options.value = options.value.copyWith(backgroundBlur: value);
  }

  void setGrade(String value) {
    options.value = options.value.copyWith(colorGrading: value);
  }

  Future<void> generate(EditorController editorController) async {
    if (_isGenerateInFlight || status.value == AutoImproveStatus.generating) {
      return;
    }
    _isGenerateInFlight = true;
    cancelGeneration();
    _guard = OperationGuard();
    status.value = AutoImproveStatus.generating;
    results.clear();
    selectedVariant.value = null;
    errorCode.value = null;
    errorMessage.value = null;

    try {
      final aiInput = await editorController.renderCurrentForAiInput();
      if (_guard?.isCancelled == true) {
        status.value = AutoImproveStatus.idle;
        return;
      }
      if (!aiInput.isSuccess) {
        status.value = AutoImproveStatus.error;
        errorCode.value = aiInput.error?.code ?? 'NO_IMAGE';
        errorMessage.value = aiInput.error?.message ?? 'Upload an image first.';
        return;
      }

      final reqId = generateRequestId('enhance');
      requestId.value = reqId;

      _analyticsService.logEvent(
        'auto_improve_generate_clicked',
        params: <String, dynamic>{
          ...options.value.toJson(),
          'request_id': reqId,
        },
      );
      _logger.info('auto_improve', 'generate start', data: <String, Object?>{
        'request_id': reqId,
        ...options.value.toJson(),
      });

      final effectiveOptions = _appController.enableBackgroundBlur.value
          ? options.value
          : options.value.copyWith(backgroundBlur: false);

      final started = DateTime.now().millisecondsSinceEpoch;
      final response = await _api.uploadAndEnhance(
        imageBytes: aiInput.data!,
        fileName: 'edited_input.jpg',
        options: effectiveOptions,
        mimeType: 'image/jpeg',
        guard: _guard,
        requestId: reqId,
      );
      final ended = DateTime.now().millisecondsSinceEpoch;
      lastLatencyMs.value = ended - started;

      if (response.isCancelled || _guard?.isCancelled == true) {
        status.value = AutoImproveStatus.idle;
        return;
      }

      if (!response.isSuccess) {
        // If API fails, try local enhancement fallback
        if (AppConstants.useLocalEnhancementFallback) {
          _logger.info('auto_improve', 'api failed, trying local fallback',
              data: <String, Object?>{
                'error_code': response.error?.code,
              });
          final localResult = await _tryLocalEnhancement(
            aiInput.data!,
            effectiveOptions,
            reqId,
          );
          if (localResult.isSuccess) {
            results.assignAll(localResult.data!);
            status.value = AutoImproveStatus.success;
            lastModel.value = 'local-fallback';
            _analyticsService.logEvent(
              'auto_improve_fallback_success',
              params: <String, dynamic>{'request_id': reqId},
            );
            return;
          }
        }

        status.value = AutoImproveStatus.error;
        errorCode.value = response.error?.code;
        errorMessage.value = response.error?.message;
        _analyticsService.logEvent(
          'auto_improve_fail',
          params: <String, dynamic>{
            'request_id': reqId,
            'error_code': response.error?.code ?? 'UNKNOWN',
          },
        );
        return;
      }

      final data = response.data!;
      lastModel.value = data.model;
      lastLatencyMs.value =
          data.latencyMs > 0 ? data.latencyMs : lastLatencyMs.value;
      final hydrated = await _cacheResults(
        data.results,
        guard: _guard,
      );
      if (hydrated.isCancelled || _guard?.isCancelled == true) {
        status.value = AutoImproveStatus.idle;
        return;
      }
      if (!hydrated.isSuccess) {
        status.value = AutoImproveStatus.error;
        errorCode.value = hydrated.error?.code;
        errorMessage.value = hydrated.error?.message;
        return;
      }

      results.assignAll(hydrated.data!);
      status.value = AutoImproveStatus.success;

      _analyticsService.logEvent(
        'auto_improve_success',
        params: <String, dynamic>{
          'request_id': reqId,
          'latency_ms': lastLatencyMs.value ?? 0,
          'model': data.model,
        },
      );
    } catch (error, stack) {
      status.value = AutoImproveStatus.error;
      errorCode.value = 'AUTO_IMPROVE_FAILED';
      errorMessage.value = 'Unable to generate AI variants';
      _logger.error(
        'auto_improve',
        'generate exception',
        data: <String, Object?>{
          'error': error.toString(),
          'stack': stack.toString(),
          'request_id': requestId.value,
        },
      );
    } finally {
      _isGenerateInFlight = false;
    }
  }

  Future<Result<List<EnhanceResult>>> _cacheResults(
    List<EnhanceResult> source, {
    OperationGuard? guard,
  }) async {
    final client = http.Client();
    guard?.registerCancel(client.close);
    try {
      final cacheDir = await _storageService.getAppCacheDir();
      final outputs = <EnhanceResult>[];
      for (final item in source) {
        if (guard?.isCancelled == true) {
          return Result.cancelled<List<EnhanceResult>>();
        }
        if (item.url.isEmpty) {
          outputs.add(item);
          continue;
        }
        if (!_isSafeRemoteImageUrl(item.url)) {
          _logger.warn(
            'auto_improve',
            'skip unsafe result url',
            data: <String, Object?>{'url': item.url},
          );
          outputs.add(item);
          continue;
        }
        try {
          final response = await client
              .get(Uri.parse(item.url))
              .timeout(const Duration(seconds: 15));
          if (guard?.isCancelled == true) {
            return Result.cancelled<List<EnhanceResult>>();
          }
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final bytes = response.bodyBytes;
            final path = p.join(
              cacheDir.path,
              'ai_${item.variant}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await File(path).writeAsBytes(bytes, flush: true);
            outputs.add(
              EnhanceResult(
                variant: item.variant,
                url: item.url,
                cachedPath: path,
                bytes: Uint8List.fromList(bytes),
              ),
            );
            continue;
          }
        } catch (_) {
          // Keep URL fallback if cache fails.
        }
        outputs.add(item);
      }
      return Result.success<List<EnhanceResult>>(outputs);
    } catch (_, stack) {
      return Result.failure<List<EnhanceResult>>(
        AppError(
          code: 'CACHE_FAILED',
          message: 'Unable to cache AI variants',
          stackTrace: stack,
        ),
      );
    } finally {
      client.close();
    }
  }

  bool _isSafeRemoteImageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasAuthority) {
      return false;
    }
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  void selectVariant(String variant, EditorController editorController) {
    final match = results.firstWhereOrNull((item) => item.variant == variant);
    if (match == null) {
      return;
    }
    selectedVariant.value = variant;
    editorController.setAiSelectedVariant(match);
    _analyticsService.logEvent(
      'variant_selected',
      params: <String, dynamic>{
        'variant': variant,
        'request_id': requestId.value,
      },
    );
  }

  void clearSelection(EditorController editorController) {
    selectedVariant.value = null;
    editorController.clearAiSelection();
  }

  void cancelGeneration() {
    _guard?.cancel();
    _guard = null;
    _isGenerateInFlight = false;
    if (status.value == AutoImproveStatus.generating) {
      status.value = AutoImproveStatus.idle;
    }
  }

  /// Local enhancement fallback when API is unavailable
  /// Uses LocalEnhanceService to actually enhance the image
  Future<Result<List<EnhanceResult>>> _tryLocalEnhancement(
    Uint8List imageBytes,
    AutoImproveOptions options,
    String reqId,
  ) async {
    try {
      _logger.info('auto_improve', 'local enhancement start',
          data: <String, Object?>{
        'request_id': reqId,
        'options': options.toJson(),
      });

      // Use LocalEnhanceService to actually enhance the image
      final result = await _localEnhanceService.enhanceImage(
        imageBytes: imageBytes,
        options: options,
        guard: _guard,
        requestId: reqId,
      );

      if (result.isCancelled || _guard?.isCancelled == true) {
        return Result.cancelled<List<EnhanceResult>>();
      }

      if (!result.isSuccess) {
        return Result.failure<List<EnhanceResult>>(result.error!);
      }

      // Cache the enhanced images locally
      final cachedResults = await _cacheResults(result.data!, guard: _guard);
      if (cachedResults.isCancelled || _guard?.isCancelled == true) {
        return Result.cancelled<List<EnhanceResult>>();
      }
      if (!cachedResults.isSuccess) {
        return Result.failure<List<EnhanceResult>>(cachedResults.error!);
      }

      _logger.info('auto_improve', 'local enhancement success',
          data: <String, Object?>{
        'request_id': reqId,
        'variants': cachedResults.data!.length,
      });

      return Result.success<List<EnhanceResult>>(cachedResults.data!);
    } catch (error, stack) {
      return Result.failure<List<EnhanceResult>>(
        AppError(
          code: 'LOCAL_ENHANCEMENT_FAILED',
          message: 'Local enhancement failed: $error',
          requestId: reqId,
          stackTrace: stack,
        ),
      );
    }
  }
}
