import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../controllers/editor_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_tokens.dart';
import '../shared/inline_banner.dart';
import '../shared/version_debug_label.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;
  late final Animation<double> _listFade;
  late final Animation<Offset> _listSlide;
  late final Animation<double> _headerFade;

  EditorController get _editor => Get.find<EditorController>();

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppMotion.slower,
    );

    // Hero: 0-40% of animation
    _heroFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.00, 0.40, curve: AppMotion.defaultCurve),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.00, 0.40, curve: AppMotion.defaultCurve),
      ),
    );

    // Header: 25-55% of animation
    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.25, 0.55, curve: AppMotion.defaultCurve),
    );

    // List: 40-100% of animation
    _listFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 1.00, curve: AppMotion.defaultCurve),
    );
    _listSlide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 1.00, curve: AppMotion.defaultCurve),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndOpenEditor() async {
    final success = await _editor.pickImage();
    if (success) {
      Get.toNamed(AppRoutes.editor);
    }
  }

  Future<void> _openRecent(String path) async {
    final success = await _editor.loadRecent(path);
    if (success) {
      Get.toNamed(AppRoutes.editor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Obx(
          () => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Hero upload card
                FadeTransition(
                  opacity: _heroFade,
                  child: SlideTransition(
                    position: _heroSlide,
                    child: _buildHeroCard(context, scheme),
                  ),
                ),
                if (_editor.inlineError.value != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: InlineBanner(message: _editor.inlineError.value!),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FadeTransition(
                  opacity: _headerFade,
                  child: _buildRecentHeader(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: FadeTransition(
                    opacity: _listFade,
                    child: SlideTransition(
                      position: _listSlide,
                      child: _editor.recents.isEmpty
                          ? _buildEmpty(context)
                          : ListView.separated(
                              itemCount: _editor.recents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final path = _editor.recents[index];
                                return _buildRecentItem(context, path, index);
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.photo_library_rounded,
            size: 48,
            color: scheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Photo Editor',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Upload a photo to start editing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _editor.isLoadingImage.value ? null : _pickAndOpenEditor,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.rMedium)),
            ),
            child: _editor.isLoadingImage.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Upload Photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          Icons.history,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Recent',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const Spacer(),
        const VersionDebugLabel(),
      ],
    );
  }

  Widget _buildRecentItem(BuildContext context, String path, int index) {
    final scheme = Theme.of(context).colorScheme;
    final fileName = p.basenameWithoutExtension(path);

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(path),
      tween: Tween<double>(begin: 0, end: 1),
      curve: AppMotion.defaultCurve,
      duration: AppMotion.default_ +
          Duration(milliseconds: (index * 40).clamp(0, 200)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 12),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () => _openRecent(path),
        borderRadius: AppRadius.allMedium,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: scheme.surfaceVariant.withValues(alpha: 0.2),
            borderRadius: AppRadius.allMedium,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.image_outlined,
                size: 40,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      _formatPath(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPath(String path) {
    final parts = p.split(path).where((item) => item.isNotEmpty).toList();
    if (parts.length <= 2) return path;
    return p.join(parts[parts.length - 2], parts.last);
  }

  Widget _buildEmpty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No recent photos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
