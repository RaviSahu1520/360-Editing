import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/editor_controller.dart';
import '../../../models/edit_state.dart';
import '../../../theme/app_tokens.dart';
import '../../shared/skeleton_box.dart';

class FiltersPanel extends StatelessWidget {
  const FiltersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<EditorController>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      final current = controller.editState.value;
      final intensity = current.filterIntensity;

      return ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 118,
            child: controller.isGeneratingFilterThumbs.value &&
                    controller.filterThumbnails.isEmpty
                ? ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, __) => const Column(
                      children: <Widget>[
                        SkeletonBox(width: 78, height: 78),
                        SizedBox(height: 6),
                        SkeletonBox(width: 64, height: 12),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    scrollDirection: Axis.horizontal,
                    itemCount: FilterPreset.values.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (_, index) {
                      final preset = FilterPreset.values[index];
                      final thumb = controller.filterThumbnails[preset];
                      final selected = current.filterPreset == preset;
                      return _FilterItem(
                        thumb: thumb,
                        selected: selected,
                        label: _labelFor(preset),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.setFilterPreset(preset);
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
            child: Row(
              children: <Widget>[
                Text(
                  'Intensity',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (current.filterPreset != FilterPreset.none)
                  TextButton(
                    onPressed: () => controller.setFilterIntensity(0),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Reset'),
                  ),
                Text(
                  '${intensity.round()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: intensity,
                max: 100,
                onChanged: current.filterPreset == FilterPreset.none
                    ? null
                    : (value) {
                        controller.setFilterIntensity(value);
                      },
              ),
            ),
          ),
        ],
      );
    });
  }

  String _labelFor(FilterPreset preset) {
    final raw = preset.name;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _FilterItem extends StatefulWidget {
  const _FilterItem({
    required this.thumb,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Uint8List? thumb;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  State<_FilterItem> createState() => _FilterItemState();
}

class _FilterItemState extends State<_FilterItem> {
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
        child: Column(
          children: <Widget>[
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                borderRadius: AppRadius.allSmall,
                border: Border.all(
                  color: widget.selected
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: widget.thumb != null
                    ? Image.memory(widget.thumb!, fit: BoxFit.cover)
                    : Container(
                        color: scheme.onSurface.withValues(alpha: 0.06),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.filter_alt_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: widget.selected
                        ? AppColors.accent
                        : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
