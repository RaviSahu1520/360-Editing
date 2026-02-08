import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/editor_controller.dart';
import '../../controllers/export_controller.dart';
import '../../models/export_settings.dart';
import '../../theme/app_tokens.dart';
import '../../utils/constants.dart';
import '../shared/inline_banner.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exportController = Get.find<ExportController>();
    final editorController = Get.find<EditorController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: SafeArea(
        child: Obx(
          () {
            final exportSettings = exportController.settings.value;
            final preview = editorController.aiSelectedBytes.value ??
                editorController.renderedPreview.value;
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (preview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.memory(preview, fit: BoxFit.cover),
                      ),
                    )
                  else
                    const SizedBox(
                      height: 220,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black12),
                        child: Center(child: Text('No preview available')),
                      ),
                    ),
                  if (exportController.exportError.value != null)
                    InlineBanner(message: exportController.exportError.value!),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Format',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SegmentedButton<ExportFormat>(
                    segments: const <ButtonSegment<ExportFormat>>[
                      ButtonSegment<ExportFormat>(
                        value: ExportFormat.jpg,
                        label: Text('JPG'),
                        icon: Icon(Icons.image_outlined),
                      ),
                      ButtonSegment<ExportFormat>(
                        value: ExportFormat.png,
                        label: Text('PNG'),
                        icon: Icon(Icons.image),
                      ),
                    ],
                    selected: <ExportFormat>{exportSettings.format},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        exportController.setFormat(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Quality',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: AppConstants.exportQualities
                        .map(
                          (quality) => ChoiceChip(
                            label: Text('$quality'),
                            selected: exportSettings.quality == quality,
                            onSelected: (_) =>
                                exportController.setQuality(quality),
                          ),
                        )
                        .toList(),
                  ),
                  const Spacer(),
                  if (exportController.lastExportPath.value != null)
                    Text(
                      'Last export: ${exportController.lastExportPath.value}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton.icon(
                    onPressed: exportController.isExporting.value
                        ? null
                        : () => _export(exportController, editorController),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      exportController.isExporting.value
                          ? 'Exporting...'
                          : 'Download',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton.icon(
                    onPressed: exportController.isExporting.value
                        ? null
                        : () => _share(exportController, editorController),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _export(
    ExportController exportController,
    EditorController editorController,
  ) async {
    final result = await exportController.exportToLocal(editorController);
    if (!result.isSuccess) {
      Get.snackbar('Export failed', result.error?.message ?? 'Try again');
      return;
    }
    Get.snackbar('Exported', result.data ?? 'Saved');
  }

  Future<void> _share(
    ExportController exportController,
    EditorController editorController,
  ) async {
    if (exportController.lastExportPath.value == null) {
      final export = await exportController.exportToLocal(editorController);
      if (!export.isSuccess) {
        Get.snackbar('Share failed', export.error?.message ?? 'Export failed');
        return;
      }
    }
    final share = await exportController.shareLastExport();
    if (!share.isSuccess) {
      Get.snackbar('Share failed', share.error?.message ?? 'Unable to share');
    }
  }
}
