import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/auto_improve_controller.dart';
import '../../controllers/editor_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_tokens.dart';
import '../shared/inline_banner.dart';
import 'panels/adjust_panel.dart';
import 'panels/auto_improve_panel.dart';
import 'panels/crop_panel.dart';
import 'panels/filters_panel.dart';
import 'widgets/editor_canvas.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorController _editorController;
  late final AutoImproveController _autoController;

  @override
  void initState() {
    super.initState();
    _editorController = Get.find<EditorController>();
    _autoController = Get.find<AutoImproveController>();
  }

  @override
  void dispose() {
    _editorController.cancelPendingOperations();
    _autoController.cancelGeneration();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _editorController.cancelPendingOperations();
        _autoController.cancelGeneration();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          // Use hasImage separately to avoid unnecessary rebuilds
          final hasImage = _editorController.hasImage;

          if (!hasImage) {
            return Scaffold(
              appBar: AppBar(title: const Text('Editor')),
              body: const Center(child: Text('No image loaded')),
            );
          }

          return Scaffold(
            appBar: _buildAppBar(context),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                    AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                child: isWide
                    ? _buildWideLayout(context)
                    : _buildCompactLayout(context),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Editor'),
      leading: _AppBarButton(
        icon: Icons.arrow_back,
        onPressed: () {
          _editorController.cancelPendingOperations();
          _autoController.cancelGeneration();
          Get.back();
        },
      ),
      leadingWidth: 56,
      actions: <Widget>[
        // Scope reactivity to only undo/redo state
        _UndoRedoButtons(
          editorController: _editorController,
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        // Scoped reactivity for error banner only
        _ErrorBanner(editorController: _editorController),
        Expanded(
          flex: 6,
          child: EditorCanvas(),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Scoped reactivity for tab selector
        _ReactiveTabSelector(
          tabs: EditorTab.values,
          editorController: _editorController,
          autoController: _autoController,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Scoped reactivity for panel content
        Expanded(
          flex: 4,
          child: _ReactivePanelContent(
            editorController: _editorController,
            scheme: scheme,
            isCompact: true,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: () => Get.toNamed(AppRoutes.export),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.rMedium)),
            ),
            child: const Text('Export'),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Expanded(
          flex: 8,
          child: Column(
            children: <Widget>[
              _ErrorBanner(editorController: _editorController),
              const Expanded(child: EditorCanvas()),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Get.toNamed(AppRoutes.export),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.rMedium)),
                  ),
                  child: const Text('Export'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: AppRadius.allLarge,
              color: scheme.surfaceVariant.withValues(alpha: 0.4),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: <Widget>[
                _ReactiveTabSelector(
                  tabs: EditorTab.values,
                  editorController: _editorController,
                  autoController: _autoController,
                ),
                const Divider(height: AppSpacing.lg),
                Expanded(
                  child: _ReactivePanelContent(
                    editorController: _editorController,
                    scheme: scheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _panelForTab(EditorTab tab) {
    return switch (tab) {
      EditorTab.crop => const CropPanel(),
      EditorTab.filters => const FiltersPanel(),
      EditorTab.adjust => const AdjustPanel(),
      EditorTab.autoImprove => const AutoImprovePanel(),
    };
  }
}

/// Clean tab selector with underline indicator
class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.tabs,
    required this.selectedTab,
    required this.onTabSelected,
  });

  final List<EditorTab> tabs;
  final EditorTab selectedTab;
  final ValueChanged<EditorTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: AppRadius.allMedium,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: tabs.map((tab) {
          final active = tab == selectedTab;
          return Expanded(
            child: _PressableTap(
              onTap: () {
                HapticFeedback.selectionClick();
                onTabSelected(tab);
              },
              child: AnimatedContainer(
                duration: AppMotion.default_,
                curve: AppMotion.defaultCurve,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? scheme.surface : Colors.transparent,
                  borderRadius: AppRadius.allSmall,
                ),
                child: Text(
                  _tabLabel(tab),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _tabLabel(EditorTab tab) {
    return switch (tab) {
      EditorTab.crop => 'Crop',
      EditorTab.filters => 'Filters',
      EditorTab.adjust => 'Adjust',
      EditorTab.autoImprove => 'Auto',
    };
  }
}

/// App bar button with press feedback
class _AppBarButton extends StatefulWidget {
  const _AppBarButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_AppBarButton> createState() => _AppBarButtonState();
}

class _AppBarButtonState extends State<_AppBarButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.defaultCurve,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? scheme.onSurface.withValues(alpha: 0.06)
                : scheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(AppRadius.rSmall),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: isEnabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Pressable wrapper for tap feedback
class _PressableTap extends StatefulWidget {
  const _PressableTap({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_PressableTap> createState() => _PressableTapState();
}

class _PressableTapState extends State<_PressableTap> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
        child: widget.child,
      ),
    );
  }
}

/// Undo/Redo buttons with scoped reactivity
class _UndoRedoButtons extends StatelessWidget {
  const _UndoRedoButtons({
    required this.editorController,
  });

  final EditorController editorController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _AppBarButton(
            icon: Icons.undo_rounded,
            onPressed:
                editorController.canUndo ? editorController.undo : null,
          ),
          _AppBarButton(
            icon: Icons.redo_rounded,
            onPressed:
                editorController.canRedo ? editorController.redo : null,
          ),
        ],
      );
    });
  }
}

/// Error banner with scoped reactivity
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.editorController,
  });

  final EditorController editorController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final error = editorController.inlineError.value;
      if (error == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InlineBanner(message: error),
      );
    });
  }
}

/// Tab selector with scoped reactivity
class _ReactiveTabSelector extends StatelessWidget {
  const _ReactiveTabSelector({
    required this.tabs,
    required this.autoController,
    required this.editorController,
  });

  final List<EditorTab> tabs;
  final AutoImproveController autoController;
  final EditorController editorController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tab = editorController.activeTab.value;
      return _TabSelector(
        tabs: tabs,
        selectedTab: tab,
        onTabSelected: (tab) {
          editorController.setTab(tab);
          if (tab == EditorTab.autoImprove) {
            autoController.markOpened();
          }
        },
      );
    });
  }
}

/// Panel content with scoped reactivity
class _ReactivePanelContent extends StatelessWidget {
  const _ReactivePanelContent({
    required this.editorController,
    required this.scheme,
    this.isCompact = false,
  });

  final EditorController editorController;
  final ColorScheme scheme;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tab = editorController.activeTab.value;
      final tabKey = ValueKey<String>(
        '${tab.name}_${editorController.tabTransitionToken.value}',
      );

      final panelContent = _panelForTab(tab);

      // For wide layout, return panel content directly without wrapper
      if (!isCompact) {
        return AnimatedSwitcher(
          duration: AppMotion.default_,
          switchInCurve: AppMotion.defaultCurve,
          switchOutCurve: AppMotion.defaultCurve,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.defaultCurve,
                )),
                child: child,
              ),
            );
          },
          child: Container(
            key: tabKey,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: panelContent,
          ),
        );
      }

      // For compact layout, include the container decoration
      return AnimatedSwitcher(
        duration: AppMotion.default_,
        switchInCurve: AppMotion.defaultCurve,
        switchOutCurve: AppMotion.defaultCurve,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: AppMotion.defaultCurve,
              )),
              child: child,
            ),
          );
        },
        child: Container(
          key: tabKey,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allLarge,
            color: scheme.surfaceVariant.withValues(alpha: 0.4),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: panelContent,
        ),
      );
    });
  }

  Widget _panelForTab(EditorTab tab) {
    return switch (tab) {
      EditorTab.crop => const CropPanel(),
      EditorTab.filters => const FiltersPanel(),
      EditorTab.adjust => const AdjustPanel(),
      EditorTab.autoImprove => const AutoImprovePanel(),
    };
  }
}
