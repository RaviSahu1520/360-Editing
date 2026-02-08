import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../diagnostics/app_logger.dart';
import '../../models/auto_improve_options.dart';
import '../../models/enhance_result.dart';
import '../../utils/constants.dart';
import '../../utils/guarded_async.dart';
import '../../utils/request_id.dart';
import '../../utils/result.dart';

class UploadResponse {
  const UploadResponse({
    required this.fileId,
    required this.url,
    required this.width,
    required this.height,
    required this.requestId,
  });

  final String fileId;
  final String url;
  final int width;
  final int height;
  final String requestId;
}

class GeminiEnhanceApi {
  GeminiEnhanceApi({
    required AppLogger logger,
    String? baseUrl,
  })  : baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _logger = logger;

  final String baseUrl;
  final AppLogger _logger;

  Future<Result<UploadResponse>> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
    OperationGuard? guard,
    String? requestId,
  }) async {
    final reqId = requestId ?? generateRequestId('upload');
    return _runWithRetry<UploadResponse>(
      operation: 'api_upload',
      requestId: reqId,
      run: () async {
        final client = http.Client();
        guard?.registerCancel(client.close);
        try {
          final uri = Uri.parse('$baseUrl/api/upload');
          final request = http.MultipartRequest('POST', uri)
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: fileName,
              ),
            )
            ..fields['mime_type'] = mimeType
            ..headers['x-request-id'] = reqId;

          _logger.info('api', 'upload start', data: <String, Object?>{
            'request_id': reqId,
            'bytes': bytes.lengthInBytes,
          });
          final streamed = await client.send(request).timeout(_timeout);
          final body = await streamed.stream.bytesToString();
          if (guard?.isCancelled == true) {
            return Result.cancelled<UploadResponse>();
          }
          if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
            return Result.failure<UploadResponse>(
              _parseError(body, streamed.statusCode, reqId),
            );
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          _logger.info('api', 'upload success', data: <String, Object?>{
            'request_id': reqId,
          });
          return Result.success<UploadResponse>(
            UploadResponse(
              fileId: decoded['file_id'] as String? ?? '',
              url: decoded['url'] as String? ?? '',
              width: (decoded['width'] as num?)?.toInt() ?? 0,
              height: (decoded['height'] as num?)?.toInt() ?? 0,
              requestId: reqId,
            ),
          );
        } on TimeoutException {
          return Result.failure<UploadResponse>(
            AppError(
              code: 'NETWORK_TIMEOUT',
              message: 'Upload timed out',
              requestId: reqId,
            ),
          );
        } catch (error, stack) {
          return Result.failure<UploadResponse>(
            AppError(
              code: 'NETWORK',
              message: error.toString(),
              requestId: reqId,
              stackTrace: stack,
            ),
          );
        } finally {
          client.close();
        }
      },
    );
  }

  Future<Result<EnhanceResponse>> enhance({
    required String fileId,
    required AutoImproveOptions options,
    int longEdgeCap = AppConstants.aiInputLongEdge,
    OperationGuard? guard,
    String? requestId,
  }) async {
    final reqId = requestId ?? generateRequestId('enhance');
    return _runWithRetry<EnhanceResponse>(
      operation: 'api_enhance',
      requestId: reqId,
      run: () async {
        final client = http.Client();
        guard?.registerCancel(client.close);
        try {
          final uri = Uri.parse('$baseUrl/api/ai/enhance');
          final payload = <String, dynamic>{
            'file_id': fileId,
            'options': options.toJson(),
            'variants': <String>['A', 'B'],
            'long_edge_cap': longEdgeCap,
          };
          _logger.info('api', 'enhance start', data: <String, Object?>{
            'request_id': reqId,
            'file_id': fileId,
          });
          final response = await client
              .post(
                uri,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'x-request-id': reqId,
                },
                body: jsonEncode(payload),
              )
              .timeout(_timeout);
          if (guard?.isCancelled == true) {
            return Result.cancelled<EnhanceResponse>();
          }
          if (response.statusCode < 200 || response.statusCode >= 300) {
            return Result.failure<EnhanceResponse>(
              _parseError(response.body, response.statusCode, reqId),
            );
          }

          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final resultsRaw =
              decoded['results'] as List<dynamic>? ?? <dynamic>[];
          final results = resultsRaw
              .map((item) =>
                  EnhanceResult.fromJson(item as Map<String, dynamic>))
              .toList();
          final meta =
              decoded['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
          _logger.info('api', 'enhance success', data: <String, Object?>{
            'request_id': reqId,
            'latency_ms': (meta['latency_ms'] as num?)?.toInt() ?? 0,
          });
          return Result.success<EnhanceResponse>(
            EnhanceResponse(
              results: results,
              model: meta['model'] as String? ?? 'unknown',
              latencyMs: (meta['latency_ms'] as num?)?.toInt() ?? 0,
              requestId: meta['request_id'] as String? ?? reqId,
            ),
          );
        } on TimeoutException {
          return Result.failure<EnhanceResponse>(
            AppError(
              code: 'AI_TIMEOUT',
              message: 'AI processing timed out',
              requestId: reqId,
            ),
          );
        } catch (error, stack) {
          return Result.failure<EnhanceResponse>(
            AppError(
              code: 'NETWORK',
              message: error.toString(),
              requestId: reqId,
              stackTrace: stack,
            ),
          );
        } finally {
          client.close();
        }
      },
    );
  }

  Future<Result<EnhanceResponse>> uploadAndEnhance({
    required Uint8List imageBytes,
    required String fileName,
    required AutoImproveOptions options,
    String mimeType = 'image/jpeg',
    OperationGuard? guard,
    String? requestId,
  }) async {
    final reqId = requestId ?? generateRequestId('enhance');
    final upload = await uploadImage(
      bytes: imageBytes,
      fileName: fileName,
      mimeType: mimeType,
      guard: guard,
      requestId: reqId,
    );
    if (!upload.isSuccess) {
      if (upload.isCancelled) {
        return Result.cancelled<EnhanceResponse>();
      }
      return Result.failure<EnhanceResponse>(upload.error!);
    }
    return enhance(
      fileId: upload.data!.fileId,
      options: options,
      guard: guard,
      requestId: reqId,
    );
  }

  Future<Result<String>> requestExportUrl({
    required String fileId,
    required String format,
    required int quality,
    OperationGuard? guard,
  }) async {
    final reqId = generateRequestId('export');
    return _runWithRetry<String>(
      operation: 'api_export',
      requestId: reqId,
      run: () async {
        final client = http.Client();
        guard?.registerCancel(client.close);
        try {
          final uri = Uri.parse('$baseUrl/api/export');
          final response = await client
              .post(
                uri,
                headers: <String, String>{
                  'Content-Type': 'application/json',
                  'x-request-id': reqId,
                },
                body: jsonEncode(
                  <String, dynamic>{
                    'file_id': fileId,
                    'format': format,
                    'quality': quality,
                  },
                ),
              )
              .timeout(_timeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            return Result.failure<String>(
              _parseError(response.body, response.statusCode, reqId),
            );
          }
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return Result.success<String>(
              decoded['download_url'] as String? ?? '');
        } catch (error, stack) {
          return Result.failure<String>(
            AppError(
              code: 'NETWORK',
              message: error.toString(),
              requestId: reqId,
              stackTrace: stack,
            ),
          );
        } finally {
          client.close();
        }
      },
    );
  }

  Future<Result<T>> _runWithRetry<T>({
    required String operation,
    required String requestId,
    required Future<Result<T>> Function() run,
  }) async {
    const maxAttempts = AppConstants.networkRetryCount + 1;
    Result<T> lastResult = Result.cancelled<T>();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final result = await run();
      if (result.isSuccess ||
          result.isCancelled ||
          !_shouldRetry(result.error)) {
        return result;
      }
      lastResult = result;
      _logger.warn(
        'api',
        '$operation retry',
        data: <String, Object?>{
          'attempt': attempt,
          'request_id': requestId,
          'code': result.error?.code ?? 'UNKNOWN',
          'next_delay_ms': attempt < maxAttempts ? _retryDelayMs(attempt) : 0,
        },
      );
      if (attempt < maxAttempts) {
        await Future<void>.delayed(
          Duration(milliseconds: _retryDelayMs(attempt)),
        );
      }
    }
    return lastResult;
  }

  int _retryDelayMs(int attempt) {
    final delay = 250 * (1 << (attempt - 1));
    if (delay > 2000) {
      return 2000;
    }
    return delay;
  }

  bool _shouldRetry(AppError? error) {
    if (error == null) {
      return false;
    }
    return <String>{
      'NETWORK',
      'NETWORK_TIMEOUT',
      'AI_TIMEOUT',
    }.contains(error.code);
  }

  AppError _parseError(String body, int statusCode, String requestId) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error =
          decoded['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return AppError(
        code: error['code'] as String? ?? 'INTERNAL',
        message: error['message'] as String? ?? 'Unexpected API error.',
        requestId: error['request_id'] as String? ?? requestId,
        statusCode: statusCode,
      );
    } catch (_) {
      return AppError(
        code: 'INTERNAL',
        message: 'Unexpected API error.',
        requestId: requestId,
        statusCode: statusCode,
      );
    }
  }

  Duration get _timeout =>
      const Duration(milliseconds: AppConstants.networkTimeoutMs);
}
