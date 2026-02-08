import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/editor_controller.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/constants.dart';

class CropPanel extends StatelessWidget {
  const CropPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditorController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      final crop = controller.editState.value.crop;
      return ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // Aspect Ratio Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Aspect Ratio',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.cropRatios.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (_, index) {
                final ratio = AppConstants.cropRatios[index];
                final selected = crop.ratio == ratio;
                return _RatioChip(
                  label: ratio,
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.updateCropRatio(ratio);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Transform Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _TransformButton(
                    icon: Icons.rotate_90_degrees_ccw,
                    label: 'Rotate',
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      controller.rotate90();
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _TransformButton(
                    icon: Icons.flip,
                    label: 'Flip H',
                    onTap: controller.flipHorizontal,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _TransformButton(
                    icon: Icons.flip,
                    label: 'Flip V',
                    onTap: controller.flipVertical,
                    vertical: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Fine Rotation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Text(
                  'Fine Rotation',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${crop.fineRotationDegrees.toStringAsFixed(1)} deg',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: crop.fineRotationDegrees,
                min: -15,
                max: 15,
                onChanged: controller.setFineRotation,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _RatioChip extends StatefulWidget {
  const _RatioChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RatioChip> createState() => _RatioChipState();
}

class _RatioChipState extends State<_RatioChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.defaultCurve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.accent
                : scheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: AppRadius.allSmall,
            border: Border.all(
              color: widget.selected
                  ? AppColors.accent
                  : scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: widget.selected ? Colors.white : scheme.onSurface,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class _TransformButton extends StatefulWidget {
  const _TransformButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.vertical = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool vertical;

  @override
  State<_TransformButton> createState() => _TransformButtonState();
}

class _TransformButtonState extends State<_TransformButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.defaultCurve,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surfaceVariant.withValues(alpha: 0.4),
            borderRadius: AppRadius.allMedium,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Transform.rotate(
                angle: widget.vertical ? 1.5708 : 0,
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
