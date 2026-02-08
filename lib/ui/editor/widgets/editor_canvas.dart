import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/editor_controller.dart';

class EditorCanvas extends StatelessWidget {
  const EditorCanvas({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditorController>();
    return Obx(() {
      final source = controller.sourceImage.value;
      // Show AI selected variant if available, otherwise show edited/original preview
      final displayBytes = controller.showOriginalPreview.value
          ? source?.previewBytes
          : (controller.aiSelectedBytes.value ?? controller.renderedPreview.value);

      if (displayBytes == null) {
        return const Center(
          child: Text('Upload an image to start editing'),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Container(color: Colors.black),
            GestureDetector(
              onLongPressStart: (_) => controller.setCompareOriginal(true),
              onLongPressEnd: (_) => controller.setCompareOriginal(false),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 6,
                panEnabled: true,
                child: Center(
                  child: Image.memory(
                    displayBytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _labelChip(
                context,
                controller.showOriginalPreview.value
                    ? 'Original'
                    : (controller.aiSelectedVariant.value != null
                        ? 'AI Variant ${controller.aiSelectedVariant.value}'
                        : 'Edited'),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _labelChip(context, 'Hold to Compare'),
            ),
            if (controller.isRendering.value)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x3A000000),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.2)),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _labelChip(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
