import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

import 'package:photo_editor_auto_improve/controllers/app_controller.dart';
import 'package:photo_editor_auto_improve/controllers/auto_improve_controller.dart';
import 'package:photo_editor_auto_improve/controllers/editor_controller.dart';
import 'package:photo_editor_auto_improve/controllers/export_controller.dart';
import 'package:photo_editor_auto_improve/diagnostics/app_logger.dart';
import 'package:photo_editor_auto_improve/main.dart';
import 'package:photo_editor_auto_improve/models/auto_improve_options.dart';
import 'package:photo_editor_auto_improve/models/enhance_result.dart';
import 'package:photo_editor_auto_improve/routes/app_routes.dart';
import 'package:photo_editor_auto_improve/services/analytics/analytics_service.dart';
import 'package:photo_editor_auto_improve/services/api/gemini_enhance_api.dart';
import 'package:photo_editor_auto_improve/services/image_io_service.dart';
import 'package:photo_editor_auto_improve/services/storage_service.dart';
import 'package:photo_editor_auto_improve/utils/constants.dart';
import 'package:photo_editor_auto_improve/utils/guarded_async.dart';
import 'package:photo_editor_auto_improve/utils/result.dart';

import '../test/test_bootstrap.dart';

class _FakeApi extends GeminiEnhanceApi {
  _FakeApi(this.completer, AppLogger logger) : super(logger: logger);

  Completer<Result<EnhanceResponse>> completer;

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

Future<Uint8List> _sampleJpg({required int width, required int height}) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(125, 88, 46));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('upload large image path downscales safely', (tester) async {
    await setupTestDependencies();
    final io = Get.find<ImageIOService>();
    final bytes = await _sampleJpg(width: 5200, height: 3400);
    final tmp = File('${Directory.systemTemp.path}/large_test.jpg');
    await tmp.writeAsBytes(bytes, flush: true);

    final result = await io.loadFromPath(tmp.path);
    expect(result.isSuccess, isTrue);
    expect(result.data!.width <= AppConstants.sourceMaxLongEdge, isTrue);
  });

  testWidgets('rapid editor tab switch remains stable', (tester) async {
    await setupTestDependencies();
    final editor = Get.find<EditorController>();
    final bytes = await _sampleJpg(width: 240, height: 240);
    editor.sourceImage.value = PickedImageData(
      originalPath: 'in-memory',
      previewBytes: bytes,
      width: 240,
      height: 240,
      fileName: 'rapid.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: bytes.lengthInBytes,
    );
    editor.renderedPreview.value = bytes;

    await tester.pumpWidget(const PhotoEditorMvpApp());
    Get.toNamed(AppRoutes.editor);
    await tester.pumpAndSettle();

    for (final tab in <String>[
      'Filters',
      'Adjust',
      'Auto',
      'Crop',
      'Filters',
      'Auto'
    ]) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pumpAndSettle();

    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('auto improve cancel and retry is stable', (tester) async {
    await setupTestDependencies();
    final logger = Get.find<AppLogger>();
    final editor = Get.find<EditorController>();
    final storage = Get.find<StorageService>();
    final analytics = Get.find<AnalyticsService>();
    final appController = Get.find<AppController>();
    final temp = await Directory.systemTemp.createTemp('ai_retry');
    final sourceBytes = await _sampleJpg(width: 320, height: 220);
    final sourceFile = File('${temp.path}/source.jpg');
    await sourceFile.writeAsBytes(sourceBytes, flush: true);

    editor.sourceImage.value = PickedImageData(
      originalPath: sourceFile.path,
      previewBytes: sourceBytes,
      width: 320,
      height: 220,
      fileName: 'source.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: sourceBytes.lengthInBytes,
    );
    editor.renderedPreview.value = sourceBytes;

    final firstCompleter = Completer<Result<EnhanceResponse>>();
    final fakeApi = _FakeApi(firstCompleter, logger);
    Get.delete<AutoImproveController>(force: true);
    final auto = Get.put(
      AutoImproveController(
        api: fakeApi,
        storageService: storage,
        analyticsService: analytics,
        appController: appController,
        logger: logger,
      ),
    );

    unawaited(auto.generate(editor));
    await tester.pump(const Duration(milliseconds: 30));
    expect(auto.status.value, AutoImproveStatus.generating);
    auto.cancelGeneration();
    expect(auto.status.value, AutoImproveStatus.idle);

    final secondCompleter = Completer<Result<EnhanceResponse>>();
    fakeApi.completer = secondCompleter;
    unawaited(auto.generate(editor));
    secondCompleter.complete(
      Result.success<EnhanceResponse>(
        EnhanceResponse(
          results: <EnhanceResult>[
            EnhanceResult(variant: 'A', url: ''),
            EnhanceResult(variant: 'B', url: ''),
          ],
          model: 'fake-model',
          latencyMs: 1000,
          requestId: 'req_test',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(auto.status.value, AutoImproveStatus.success);
    expect(auto.results.length, 2);
  });

  testWidgets('export and share call do not crash', (tester) async {
    await setupTestDependencies();
    final editor = Get.find<EditorController>();
    final export = Get.find<ExportController>();
    final temp = await Directory.systemTemp.createTemp('export_test');
    final bytes = await _sampleJpg(width: 400, height: 280);
    final source = File('${temp.path}/source.jpg');
    await source.writeAsBytes(bytes, flush: true);

    editor.sourceImage.value = PickedImageData(
      originalPath: source.path,
      previewBytes: bytes,
      width: 400,
      height: 280,
      fileName: 'source.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: bytes.lengthInBytes,
    );
    editor.renderedPreview.value = bytes;

    final saved = await export.exportToLocal(editor);
    expect(saved.isSuccess, isTrue);

    final shared = await export.shareLastExport();
    expect(shared.isSuccess || shared.isFailure, isTrue);
  });
}
