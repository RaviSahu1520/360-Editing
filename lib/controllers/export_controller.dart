import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../diagnostics/app_logger.dart';
import '../models/export_settings.dart';
import '../services/analytics/analytics_service.dart';
import '../services/local_edit_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/request_id.dart';
import '../utils/result.dart';
import 'editor_controller.dart';

class ExportController extends GetxController {
  ExportController({
    required StorageService storageService,
    required LocalEditService localEditService,
    required AnalyticsService analyticsService,
    required AppLogger logger,
  })  : _storageService = storageService,
        _localEditService = localEditService,
        _analyticsService = analyticsService,
        _logger = logger;

  final StorageService _storageService;
  final LocalEditService _localEditService;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;

  final settings = ExportSettings.initial().obs;
  final isExporting = false.obs;
  final lastExportPath = RxnString();
  final exportError = RxnString();

  void setFormat(ExportFormat format) {
    settings.value = settings.value.copyWith(format: format);
  }

  void setQuality(int quality) {
    if (!AppConstants.exportQualities.contains(quality)) {
      return;
    }
    settings.value = settings.value.copyWith(quality: quality);
  }

  Future<Result<String>> exportToLocal(
      EditorController editorController) async {
    if (isExporting.value) {
      return Result.failure<String>(
        const AppError(code: 'BUSY', message: 'Export already in progress'),
      );
    }
    exportError.value = null;
    isExporting.value = true;
    final reqId = generateRequestId('export');
    try {
      final bytes = await _resolveSourceBytes(editorController);
      if (!bytes.isSuccess) {
        return Result.failure<String>(
          bytes.error ??
              const AppError(
                  code: 'EMPTY_IMAGE', message: 'No image available to export'),
        );
      }

      final exportDir = Directory(
        p.join((await _storageService.getAppDocDir()).path, 'exports'),
      );
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final fileName =
          'edited_${DateTime.now().millisecondsSinceEpoch}.${settings.value.extension}';
      final outputPath = p.join(exportDir.path, fileName);
      await File(outputPath).writeAsBytes(bytes.data!, flush: true);
      lastExportPath.value = outputPath;

      final startedAt = editorController.uploadStartedAtMs.value;
      final now = DateTime.now().millisecondsSinceEpoch;
      _analyticsService.logEvent(
        'export_success',
        params: <String, dynamic>{
          'request_id': reqId,
          'format': settings.value.extension,
          'quality': settings.value.quality,
          'from_ai_variant': editorController.aiSelectedVariant.value != null,
          'time_to_export_ms': startedAt == null ? null : now - startedAt,
        },
      );
      _logger.info('export', 'exported', data: <String, Object?>{
        'request_id': reqId,
        'path': outputPath,
      });
      return Result.success<String>(outputPath);
    } catch (error, stack) {
      exportError.value = 'Failed to export image';
      return Result.failure<String>(
        AppError(
          code: 'EXPORT_FAILED',
          message: error.toString(),
          stackTrace: stack,
        ),
      );
    } finally {
      isExporting.value = false;
    }
  }

  Future<Result<void>> shareLastExport() async {
    final path = lastExportPath.value;
    if (path == null) {
      return Result.failure<void>(
        const AppError(
          code: 'NO_EXPORT',
          message: 'Export the image before sharing.',
        ),
      );
    }
    try {
      final result = await Share.shareXFiles(
        <XFile>[XFile(path)],
        text: 'Edited with Photo Editor MVP',
      );
      if (result.status == ShareResultStatus.unavailable) {
        return Result.failure<void>(
          const AppError(
            code: 'SHARE_UNAVAILABLE',
            message: 'Share sheet unavailable',
          ),
        );
      }
      return Result.successNoData();
    } on PlatformException catch (error, stack) {
      return Result.failure<void>(
        AppError(
          code: 'SHARE_FAILED',
          message: error.message ?? error.code,
          stackTrace: stack,
        ),
      );
    } catch (error, stack) {
      return Result.failure<void>(
        AppError(
          code: 'SHARE_FAILED',
          message: error.toString(),
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<Uint8List>> _resolveSourceBytes(
      EditorController editorController) async {
    if (editorController.aiSelectedBytes.value != null) {
      return _localEditService.transcode(
        bytes: editorController.aiSelectedBytes.value!,
        settings: settings.value,
      );
    }
    final aiPath = editorController.aiSelectedPath.value;
    if (aiPath != null) {
      try {
        final bytes = await File(aiPath).readAsBytes();
        return _localEditService.transcode(
            bytes: bytes, settings: settings.value);
      } catch (error, stack) {
        return Result.failure<Uint8List>(
          AppError(
            code: 'READ_FAILED',
            message: error.toString(),
            stackTrace: stack,
          ),
        );
      }
    }
    return editorController.renderCurrentForExport(settings.value);
  }
}
