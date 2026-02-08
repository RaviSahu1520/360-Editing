import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../controllers/editor_controller.dart';
import '../../../theme/app_tokens.dart';

class AdjustPanel extends StatelessWidget {
  const AdjustPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    final controller = Get.find<EditorController>();

    return Obx(() {
      final values = controller.editState.value.adjustments;
      return ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _AdjustmentSlider(
            label: 'Brightness',
            value: values.brightness,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('brightness', v),
            onReset: () => controller.setAdjustment('brightness', 0),
          ),
          _AdjustmentSlider(
            label: 'Contrast',
            value: values.contrast,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('contrast', v),
            onReset: () => controller.setAdjustment('contrast', 0),
          ),
          _AdjustmentSlider(
            label: 'Saturation',
            value: values.saturation,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('saturation', v),
            onReset: () => controller.setAdjustment('saturation', 0),
          ),
          _AdjustmentSlider(
            label: 'Vibrance',
            value: values.vibrance,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('vibrance', v),
            onReset: () => controller.setAdjustment('vibrance', 0),
          ),
          _AdjustmentSlider(
            label: 'Highlights',
            value: values.highlights,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('highlights', v),
            onReset: () => controller.setAdjustment('highlights', 0),
          ),
          _AdjustmentSlider(
            label: 'Shadows',
            value: values.shadows,
            min: -100,
            max: 100,
            onChanged: (v) => controller.setAdjustment('shadows', v),
            onReset: () => controller.setAdjustment('shadows', 0),
          ),
          _AdjustmentSlider(
            label: 'Sharpen',
            value: values.sharpen,
            min: 0,
            max: 100,
            onChanged: (v) => controller.setAdjustment('sharpen', v),
            onReset: () => controller.setAdjustment('sharpen', 0),
          ),
          if (appController.enableBackgroundBlur.value)
            _AdjustmentSlider(
              label: 'Blur',
              value: values.blur,
              min: 0,
              max: 100,
              onChanged: (v) => controller.setAdjustment('blur', v),
              onReset: () => controller.setAdjustment('blur', 0),
            ),
        ],
      );
    });
  }
}

class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (value.abs() > 0.5)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                  ),
                  child: const Text('Reset'),
                ),
              Text(
                '${value.round()}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                if (v.round() % 10 == 0) {
                  HapticFeedback.selectionClick();
                }
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
