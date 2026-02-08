import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import 'package:photo_editor_auto_improve/controllers/auto_improve_controller.dart';
import 'package:photo_editor_auto_improve/controllers/editor_controller.dart';
import 'package:photo_editor_auto_improve/main.dart';
import 'package:photo_editor_auto_improve/routes/app_routes.dart';
import 'package:photo_editor_auto_improve/services/image_io_service.dart';

import '../test_bootstrap.dart';

void main() {
  Future<Uint8List> sampleBytes() async {
    final picture = img.Image(width: 128, height: 128);
    img.fill(picture, color: img.ColorRgb8(180, 120, 90));
    return Uint8List.fromList(img.encodeJpg(picture));
  }

  testWidgets('rapid tab switch does not crash', (WidgetTester tester) async {
    await setupTestDependencies();
    final editor = Get.find<EditorController>();
    final bytes = await sampleBytes();
    editor.sourceImage.value = PickedImageData(
      originalPath: 'in-memory',
      previewBytes: bytes,
      width: 128,
      height: 128,
      fileName: 'sample.jpg',
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
      'Filters'
    ]) {
      await tester.tap(find.text(tab));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('editor error banner appears', (WidgetTester tester) async {
    await setupTestDependencies();
    final editor = Get.find<EditorController>();
    final bytes = await sampleBytes();
    editor.sourceImage.value = PickedImageData(
      originalPath: 'in-memory',
      previewBytes: bytes,
      width: 128,
      height: 128,
      fileName: 'sample.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: bytes.lengthInBytes,
    );
    editor.renderedPreview.value = bytes;
    editor.inlineError.value = 'Synthetic render error';

    await tester.pumpWidget(const PhotoEditorMvpApp());
    Get.toNamed(AppRoutes.editor);
    await tester.pumpAndSettle();

    expect(find.textContaining('Synthetic render error'), findsOneWidget);
  });

  testWidgets('tab change updates visible panel state',
      (WidgetTester tester) async {
    await setupTestDependencies();
    final editor = Get.find<EditorController>();
    final bytes = await sampleBytes();
    editor.sourceImage.value = PickedImageData(
      originalPath: 'in-memory',
      previewBytes: bytes,
      width: 128,
      height: 128,
      fileName: 'sample.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: bytes.lengthInBytes,
    );
    editor.renderedPreview.value = bytes;

    await tester.pumpWidget(const PhotoEditorMvpApp());
    Get.toNamed(AppRoutes.editor);
    await tester.pumpAndSettle();

    expect(editor.activeTab.value, EditorTab.crop);

    await tester.tap(find.text('Filters'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(editor.activeTab.value, EditorTab.filters);

    await tester.tap(find.text('Adjust'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(editor.activeTab.value, EditorTab.adjust);

    await tester.tap(find.text('Auto'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(editor.activeTab.value, EditorTab.autoImprove);

    await tester.tap(find.text('Crop'));
    await tester.pump(const Duration(milliseconds: 260));
    expect(editor.activeTab.value, EditorTab.crop);
  });

  testWidgets('generate A/B handles render failure without layout crash',
      (WidgetTester tester) async {
    await setupTestDependencies();
    final auto = Get.find<AutoImproveController>();
    final editor = Get.find<EditorController>();
    final bytes = await sampleBytes();
    editor.sourceImage.value = PickedImageData(
      originalPath: 'missing_source.jpg',
      previewBytes: bytes,
      width: 128,
      height: 128,
      fileName: 'sample.jpg',
      mimeType: 'image/jpeg',
      originalFileBytes: bytes.lengthInBytes,
    );
    editor.renderedPreview.value = bytes;

    await tester.pumpWidget(const PhotoEditorMvpApp());
    Get.toNamed(AppRoutes.editor);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auto'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.ensureVisible(find.text('Generate'));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('Generate'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      auto.status.value == AutoImproveStatus.error ||
          auto.status.value == AutoImproveStatus.generating ||
          auto.status.value == AutoImproveStatus.success,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
