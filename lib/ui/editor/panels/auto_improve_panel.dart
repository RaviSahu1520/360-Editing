import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/app_controller.dart';
import '../../../controllers/auto_improve_controller.dart';
import '../../../controllers/editor_controller.dart';
import '../../../models/enhance_result.dart';
import '../../../theme/app_tokens.dart';
import '../../../utils/constants.dart';
import '../../shared/inline_banner.dart';
import '../compare/swipe_compare_screen.dart';

class AutoImprovePanel extends StatelessWidget {
  const AutoImprovePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final autoController = Get.find<AutoImproveController>();
    final editorController = Get.find<EditorController>();
    final appController = Get.find<AppController>();
    final scheme = Theme.of(context).colorScheme;

    return Obx(
      () {
        final options = autoController.options.value;
        final isGenerating =
            autoController.status.value == AutoImproveStatus.generating;

        return Column(
          children: <Widget>[
            // Options section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: AppRadius.allMedium,
                      ),
                      child: Column(
                        children: <Widget>[
                          _OptionTile(
                            title: 'Lighting',
                            value: options.lighting,
                            onChanged: autoController.toggleLighting,
                          ),
                          _OptionTile(
                            title: 'Skin enhancement',
                            value: options.skinImprovement,
                            onChanged: autoController.toggleSkin,
                          ),
                          _OptionTile(
                            title: 'Sharpen details',
                            value: options.sharpenDetails,
                            onChanged: autoController.toggleSharpen,
                          ),
                          _OptionTile(
                            title: 'Reduce noise',
                            value: options.reduceNoise,
                            onChanged: autoController.toggleNoise,
                          ),
                          if (appController.enableBackgroundBlur.value)
                            _OptionTile(
                              title: 'Background blur',
                              value: options.backgroundBlur,
                              onChanged: autoController.toggleBlur,
                            ),
                          const SizedBox(height: AppSpacing.sm),
                          _GradeDropdown(
                            value: options.colorGrading,
                            grades: AppConstants.grades,
                            onChanged: autoController.setGrade,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Generate button
                    _GenerateButton(
                      isGenerating: isGenerating,
                      onPressed: isGenerating
                          ? null
                          : () => autoController.generate(editorController),
                    ),

                    if (isGenerating) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      const LinearProgressIndicator(),
                    ],

                    // Error banner
                    if (autoController.status.value ==
                            AutoImproveStatus.error &&
                        autoController.errorMessage.value != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: InlineBanner(
                          message:
                              '${autoController.errorCode.value ?? 'ERROR'}: ${autoController.errorMessage.value}',
                          onRetry: () =>
                              autoController.generate(editorController),
                        ),
                      ),

                    // Results section
                    if (autoController.results.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'AI Variants',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...autoController.results.map(
                        (result) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _VariantCard(
                            result: result,
                            isSelected:
                                autoController.selectedVariant.value ==
                                    result.variant,
                            before: editorController.renderedPreview.value,
                            onSelect: () => autoController.selectVariant(
                                result.variant, editorController),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Simple option tile
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (_) => onChanged(!value),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// Clean dropdown for color grading
class _GradeDropdown extends StatelessWidget {
  const _GradeDropdown({
    required this.value,
    required this.grades,
    required this.onChanged,
  });

  final String value;
  final List<String> grades;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('Color grading'),
      subtitle: Text(value),
      trailing: const Icon(Icons.arrow_drop_down),
      contentPadding: EdgeInsets.zero,
      onTap: () => _showGradePicker(context),
    );
  }

  void _showGradePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: grades
                .map(
                  (grade) => ListTile(
                    title: Text(grade),
                    selected: grade == value,
                    onTap: () {
                      onChanged(grade);
                      Get.back();
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// Generate button with loading state
class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.isGenerating,
    required this.onPressed,
  });

  final bool isGenerating;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(isGenerating ? 'Generating...' : 'Generate'),
      ),
    );
  }
}

/// Variant card with before/after preview
class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.result,
    required this.isSelected,
    required this.before,
    required this.onSelect,
  });

  final EnhanceResult result;
  final bool isSelected;
  final Uint8List? before;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final afterBytes = result.bytes;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? scheme.primary : Colors.transparent,
          width: 2,
        ),
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Variant ${result.variant}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: scheme.primary,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: AppRadius.allSmall,
              child: _buildImage(afterBytes, scheme),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: (before != null && afterBytes != null)
                      ? () {
                          Get.to(
                            () => SwipeCompareScreen(
                              title: 'Variant ${result.variant}',
                              before: before!,
                              after: afterBytes,
                            ),
                          );
                        }
                      : null,
                  child: const Text('Compare'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: onSelect,
                  child: Text(isSelected ? 'Applied' : 'Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Uint8List? afterBytes, ColorScheme scheme) {
    if (afterBytes != null) {
      return Image.memory(afterBytes, fit: BoxFit.cover);
    }
    if (_isHttpUrl(result.url)) {
      return Image.network(result.url, fit: BoxFit.cover);
    }
    return Container(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  bool _isHttpUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasAuthority) {
      return false;
    }
    return uri.scheme == 'https' || uri.scheme == 'http';
  }
}
