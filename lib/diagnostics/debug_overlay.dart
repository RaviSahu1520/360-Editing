import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import 'app_logger.dart';

class DebugOverlay extends StatelessWidget {
  const DebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final logger = Get.find<AppLogger>();

    return Obx(() {
      if (!appController.debugOverlayEnabled.value) {
        return const SizedBox.shrink();
      }
      return IgnorePointer(
        ignoring: false,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 360, maxWidth: 900),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        const Text(
                          'Debug Overlay',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: appController.toggleDebugOverlay,
                          color: Colors.white,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _chip(
                              'Build ${logger.avgBuildFrameMs.value.toStringAsFixed(1)}ms'),
                          _chip(
                              'Raster ${logger.avgRasterFrameMs.value.toStringAsFixed(1)}ms'),
                          _chip(
                            'Img ${logger.currentImageWidth.value}x${logger.currentImageHeight.value}',
                          ),
                          _chip(
                              'Preview ${_formatBytes(logger.currentPreviewBytes.value)}'),
                          _chip(
                              'Edited ${_formatBytes(logger.currentEditedBytes.value)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: logger.logs.length,
                        itemBuilder: (context, index) {
                          final entry =
                              logger.logs[logger.logs.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '[${entry.level.name}] ${entry.scope}: ${entry.message} ${entry.data}',
                              style: TextStyle(
                                color: _colorFor(entry.level),
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }

  Color _colorFor(LogLevel level) {
    return switch (level) {
      LogLevel.info => Colors.white,
      LogLevel.warn => Colors.orange.shade200,
      LogLevel.error => Colors.red.shade200,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0B';
    }
    if (bytes < 1024) {
      return '${bytes}B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
