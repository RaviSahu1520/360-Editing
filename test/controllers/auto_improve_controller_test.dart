import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:photo_editor_auto_improve/controllers/app_controller.dart';
import 'package:photo_editor_auto_improve/controllers/auto_improve_controller.dart';
import 'package:photo_editor_auto_improve/controllers/editor_controller.dart';
import 'package:photo_editor_auto_improve/diagnostics/app_logger.dart';
import 'package:photo_editor_auto_improve/models/auto_improve_options.dart';
import 'package:photo_editor_auto_improve/models/enhance_result.dart';
import 'package:photo_editor_auto_improve/services/analytics/analytics_service.dart';
import 'package:photo_editor_auto_improve/services/api/gemini_enhance_api.dart';
import 'package:photo_editor_auto_improve/services/image_io_service.dart';
import 'package:photo_editor_auto_improve/services/local_edit_service.dart';
import 'package:photo_editor_auto_improve/services/storage_service.dart';
import 'package:photo_editor_auto_improve/utils/guarded_async.dart';
import 'package:photo_editor_auto_improve/utils/result.dart';

class _FakeGeminiEnhanceApi extends GeminiEnhanceApi {
  _FakeGeminiEnhanceApi(this.completer, AppLogger logger)
      : super(logger: logger);

  final Completer<Result<EnhanceResponse>> completer;

  @override
  Future<Result<EnhanceResponse>> uploadAndEnhance({
    required Uint8List imageBytes,
    required String fileName,
    required AutoImproveOptions options,
    String mimeType = 'image/jpeg',
    OperationGuard? guard,
    String? requestId,
  }) {
    return completer.future;
  }
}

class _TestEditorController extends EditorController {
  _TestEditorController(AppLogger logger)
      : super(
          imageIOService: ImageIOService(StorageService(), logger),
          localEditService: LocalEditService(logger),
          storageService: StorageService(),
          analyticsService: AnalyticsService(logger),
          logger: logger,
        );

  @override
  Future<Result<Uint8List>> renderCurrentForAiInput() async {
    return Result.success<Uint8List>(Uint8List.fromList(<int>[1, 2, 3]));
  }
}

void main() {
  test('cancelGeneration returns controller to idle', () async {
    final logger = AppLogger();
    final completer = Completer<Result<EnhanceResponse>>();
    final api = _FakeGeminiEnhanceApi(completer, logger);
    final controller = AutoImproveController(
      api: api,
      storageService: StorageService(),
      analyticsService: AnalyticsService(logger),
      appController: AppController(),
      logger: logger,
    );
    final editor = _TestEditorController(logger);

    unawaited(controller.generate(editor));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.status.value, AutoImproveStatus.generating);

    controller.cancelGeneration();
    expect(controller.status.value, AutoImproveStatus.idle);
  });
}
