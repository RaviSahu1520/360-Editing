import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';

import '../diagnostics/app_logger.dart';
import '../models/edit_state.dart';
import '../models/enhance_result.dart';
import '../models/export_settings.dart';
import '../models/history_entry.dart';
import '../services/analytics/analytics_service.dart';
import '../services/image_io_service.dart';
import '../services/local_edit_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/request_id.dart';
import '../utils/result.dart';

enum EditorTab {
  crop,
  filters,
  adjust,
  autoImprove,
}

class EditorController extends GetxController {
  EditorController({
    required ImageIOService imageIOService,
    required LocalEditService localEditService,
    required StorageService storageService,
    required AnalyticsService analyticsService,
    required AppLogger logger,
  })  : _imageIOService = imageIOService,
        _localEditService = localEditService,
        _storageService = storageService,
        _analyticsService = analyticsService,
        _logger = logger;

  final ImageIOService _imageIOService;
  final LocalEditService _localEditService;
  final StorageService _storageService;
  final AnalyticsService _analyticsService;
  final AppLogger _logger;

  final sourceImage = Rxn<PickedImageData>();
  final renderedPreview = Rxn<Uint8List>();
  final editState = EditState.initial().obs;
  final activeTab = EditorTab.crop.obs;
  final tabTransitionToken = 0.obs;
  final isLoadingImage = false.obs;
  final isRendering = false.obs;
  final isGeneratingFilterThumbs = false.obs;
  final showOriginalPreview = false.obs;
  final inlineError = RxnString();
  final recents = <String>[].obs;
  final uploadStartedAtMs = RxnInt();
  final sessionId = ''.obs;

  final aiSelectedVariant = RxnString();
  final aiSelectedPath = RxnString();
  final aiSelectedBytes = Rxn<Uint8List>();
  final filterThumbnails = <FilterPreset, Uint8List>{}.obs;

  final historyCursor = (-1).obs;
  final List<HistoryEntry> _history = <HistoryEntry>[];
  int _renderToken = 0;
  Timer? _renderDebounce;

  bool get hasImage => sourceImage.value != null;
  bool get canUndo => historyCursor.value >= 0;
  bool get canRedo => historyCursor.value < _history.length - 1;
  bool get hasAiSelection =>
      aiSelectedBytes.value != null || aiSelectedPath.value != null;

  @override
  void onInit() {
    super.onInit();
    _startNewSession();
    _loadRecents();
  }

  @override
  void onClose() {
    cancelPendingOperations();
    super.onClose();
  }

  void _startNewSession() {
    sessionId.value = generateRequestId('editor_session');
  }

  Future<void> _loadRecents() async {
    final saved = await _storageService.loadRecents();
    if (isClosed) {
      return;
    }
    recents.assignAll(saved);
  }

  Future<bool> pickImage() async {
    isLoadingImage.value = true;
    inlineError.value = null;
    _analyticsService.logEvent('upload_started');
    _logger.info('editor', 'pick image start');
    final result = await _imageIOService.pickImage();
    if (isClosed) {
      return false;
    }
    isLoadingImage.value = false;

    if (!result.isSuccess) {
      if (result.isCancelled) {
        return false;
      }
      inlineError.value = result.error?.message ?? 'Unable to open image';
      _logger.warn('editor', 'pick image failed', data: <String, Object?>{
        'code': result.error?.code ?? 'UNKNOWN',
      });
      return false;
    }

    await _setSourceImage(result.data!);
    return true;
  }

  Future<bool> loadRecent(String path) async {
    isLoadingImage.value = true;
    inlineError.value = null;
    final result = await _imageIOService.loadFromPath(path);
    if (isClosed) {
      return false;
    }
    isLoadingImage.value = false;
    if (!result.isSuccess) {
      inlineError.value = result.error?.message ?? 'Unable to open image';
      return false;
    }
    await _setSourceImage(result.data!);
    return true;
  }

  Future<void> _setSourceImage(PickedImageData image) async {
    _startNewSession();
    cancelPendingOperations();
    sourceImage.value = image;
    activeTab.value = EditorTab.crop;
    tabTransitionToken.value = 0;
    editState.value = EditState.initial();
    _history.clear();
    historyCursor.value = -1;
    aiSelectedVariant.value = null;
    aiSelectedPath.value = null;
    aiSelectedBytes.value = null;
    isGeneratingFilterThumbs.value = false;
    filterThumbnails.clear();
    renderedPreview.value = image.previewBytes;
    uploadStartedAtMs.value = DateTime.now().millisecondsSinceEpoch;
    inlineError.value = null;

    _logger.setImageMetrics(
      width: image.width,
      height: image.height,
      previewBytes: image.previewBytes.lengthInBytes,
      editedBytes: renderedPreview.value?.lengthInBytes ?? 0,
    );

    await _storageService.addRecent(image.originalPath);
    await _loadRecents();
    _analyticsService.logEvent(
      'upload_completed',
      params: <String, dynamic>{
        'width': image.width,
        'height': image.height,
      },
    );
  }

  void setTab(EditorTab tab) {
    if (activeTab.value == tab) {
      return;
    }
    activeTab.value = tab;
    tabTransitionToken.value += 1;
    if (tab == EditorTab.filters) {
      refreshFilterThumbnails();
    }
  }

  void setCompareOriginal(bool show) {
    showOriginalPreview.value = show;
  }

  Future<void> refreshFilterThumbnails() async {
    final current = renderedPreview.value ?? sourceImage.value?.previewBytes;
    if (current == null || isGeneratingFilterThumbs.value) {
      return;
    }
    final expectedSession = sessionId.value;
    isGeneratingFilterThumbs.value = true;
    final thumbs = await _localEditService.generateFilterThumbnails(
      sourcePreviewBytes: current,
    );
    if (!_canApply(expectedSession)) {
      isGeneratingFilterThumbs.value = false;
      return;
    }
    isGeneratingFilterThumbs.value = false;
    if (thumbs.isSuccess) {
      filterThumbnails.assignAll(thumbs.data!);
    }
  }

  Future<void> updateCropRatio(String ratio) async {
    final image = sourceImage.value;
    if (image == null) {
      return;
    }
    final previous = editState.value;
    final currentCrop = previous.crop;

    final ratioCrop = ratio == 'Free'
        ? currentCrop.copyWith(
            x: 0,
            y: 0,
            width: 1,
            height: 1,
            ratio: 'Free',
          )
        : EditState.centeredRectForRatio(
            ratio: ratio,
            imageWidth: image.width.toDouble(),
            imageHeight: image.height.toDouble(),
          ).copyWith(
            quarterTurns: currentCrop.quarterTurns,
            fineRotationDegrees: currentCrop.fineRotationDegrees,
            flipHorizontal: currentCrop.flipHorizontal,
            flipVertical: currentCrop.flipVertical,
          );

    await _commitState(
      previous.copyWith(crop: ratioCrop),
      type: HistoryActionType.crop,
      toolName: 'crop_ratio',
      debounceRender: false,
    );
  }

  Future<void> rotate90() async {
    final previous = editState.value;
    final crop = previous.crop;
    await _commitState(
      previous.copyWith(
        crop: crop.copyWith(quarterTurns: (crop.quarterTurns + 1) % 4),
      ),
      type: HistoryActionType.crop,
      toolName: 'rotate_90',
      debounceRender: false,
    );
  }

  Future<void> setFineRotation(double degrees) async {
    final previous = editState.value;
    await _commitState(
      previous.copyWith(
        crop: previous.crop.copyWith(fineRotationDegrees: degrees),
      ),
      type: HistoryActionType.crop,
      toolName: 'fine_rotate',
      debounceRender: true,
    );
  }

  Future<void> flipHorizontal() async {
    final previous = editState.value;
    await _commitState(
      previous.copyWith(
        crop: previous.crop.copyWith(
          flipHorizontal: !previous.crop.flipHorizontal,
        ),
      ),
      type: HistoryActionType.crop,
      toolName: 'flip_horizontal',
      debounceRender: false,
    );
  }

  Future<void> flipVertical() async {
    final previous = editState.value;
    await _commitState(
      previous.copyWith(
        crop: previous.crop.copyWith(
          flipVertical: !previous.crop.flipVertical,
        ),
      ),
      type: HistoryActionType.crop,
      toolName: 'flip_vertical',
      debounceRender: false,
    );
  }

  Future<void> setFilterPreset(FilterPreset preset) async {
    final previous = editState.value;
    final nextIntensity = preset == FilterPreset.none
        ? 0.0
        : (previous.filterIntensity == 0 ? 65.0 : previous.filterIntensity);
    await _commitState(
      previous.copyWith(
        filterPreset: preset,
        filterIntensity: nextIntensity,
      ),
      type: HistoryActionType.filter,
      toolName: 'filter_preset',
      debounceRender: false,
    );
  }

  Future<void> setFilterIntensity(double value) async {
    final previous = editState.value;
    await _commitState(
      previous.copyWith(filterIntensity: value.clamp(0, 100).toDouble()),
      type: HistoryActionType.filter,
      toolName: 'filter_intensity',
      debounceRender: true,
    );
  }

  Future<void> setAdjustment(String key, double value) async {
    final previous = editState.value;
    final a = previous.adjustments;
    final next = switch (key) {
      'brightness' => a.copyWith(brightness: value),
      'contrast' => a.copyWith(contrast: value),
      'saturation' => a.copyWith(saturation: value),
      'vibrance' => a.copyWith(vibrance: value),
      'highlights' => a.copyWith(highlights: value),
      'shadows' => a.copyWith(shadows: value),
      'sharpen' => a.copyWith(sharpen: value),
      'blur' => a.copyWith(blur: value),
      _ => a,
    };
    await _commitState(
      previous.copyWith(adjustments: next),
      type: HistoryActionType.adjust,
      toolName: key,
      debounceRender: true,
    );
  }

  Future<void> undo() async {
    if (!canUndo) {
      return;
    }
    final entry = _history[historyCursor.value];
    historyCursor.value -= 1;
    await _applyState(entry.previousState,
        renderOnly: true, debounceRender: false, showLoadingIndicator: true);
  }

  Future<void> redo() async {
    if (!canRedo) {
      return;
    }
    final nextIndex = historyCursor.value + 1;
    final entry = _history[nextIndex];
    historyCursor.value = nextIndex;
    await _applyState(entry.nextState,
        renderOnly: true, debounceRender: false, showLoadingIndicator: true);
  }

  Future<void> _commitState(
    EditState nextState, {
    required HistoryActionType type,
    required String toolName,
    required bool debounceRender,
  }) async {
    final previous = editState.value;
    if (_isSameState(previous, nextState)) {
      return;
    }

    _appendHistory(
      type: type,
      toolName: toolName,
      previous: previous,
      next: nextState,
    );
    await _applyState(nextState,
        renderOnly: false,
        debounceRender: debounceRender,
        showLoadingIndicator: !debounceRender);

    if (!debounceRender) {
      _analyticsService.logEvent(
        'tool_used',
        params: <String, dynamic>{'tool': toolName},
      );
    }
  }

  void _appendHistory({
    required HistoryActionType type,
    required String toolName,
    required EditState previous,
    required EditState next,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (historyCursor.value < _history.length - 1) {
      _history.removeRange(historyCursor.value + 1, _history.length);
    }

    if (_history.isNotEmpty) {
      final last = _history.last;
      final withinMergeWindow = now - last.timestampMs < 180;
      if (withinMergeWindow && last.toolName == toolName) {
        _history[_history.length - 1] = HistoryEntry(
          type: type,
          toolName: toolName,
          previousState: last.previousState,
          nextState: next,
          timestampMs: now,
        );
        historyCursor.value = _history.length - 1;
        return;
      }
    }

    if (_history.length >= AppConstants.historyLimit) {
      _history.removeAt(0);
      historyCursor.value = historyCursor.value - 1;
    }
    _history.add(
      HistoryEntry(
        type: type,
        toolName: toolName,
        previousState: previous,
        nextState: next,
        timestampMs: now,
      ),
    );
    historyCursor.value = _history.length - 1;
  }

  Future<void> _applyState(
    EditState nextState, {
    required bool renderOnly,
    required bool debounceRender,
    required bool showLoadingIndicator,
  }) async {
    final expectedSession = sessionId.value;
    editState.value = nextState;
    final image = sourceImage.value;
    if (image == null) {
      return;
    }

    final token = ++_renderToken;
    _renderDebounce?.cancel();
    final completer = Completer<void>();
    Future<void> run() async {
      if (!_canApply(expectedSession) || token != _renderToken) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      if (showLoadingIndicator) {
        isRendering.value = true;
      }
      try {
        final rendered = await _localEditService.applyEditsToPreview(
          previewBytes: image.previewBytes,
          state: nextState,
        );
        if (!_canApply(expectedSession) || token != _renderToken) {
          return;
        }
        if (rendered.isSuccess) {
          renderedPreview.value = rendered.data!;
          _logger.setImageMetrics(
            width: image.width,
            height: image.height,
            previewBytes: image.previewBytes.lengthInBytes,
            editedBytes: rendered.data!.lengthInBytes,
          );
          inlineError.value = null;
        } else {
          inlineError.value = rendered.error?.message ?? 'Render failed';
        }
      } finally {
        if (showLoadingIndicator &&
            _canApply(expectedSession) &&
            token == _renderToken) {
          isRendering.value = false;
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    if (debounceRender) {
      _renderDebounce = Timer(
        const Duration(milliseconds: AppConstants.renderDebounceMs),
        run,
      );
    } else {
      await run();
    }

    if (debounceRender) {
      await completer.future;
    }

    if (!renderOnly && hasAiSelection) {
      aiSelectedVariant.value = null;
      aiSelectedPath.value = null;
      aiSelectedBytes.value = null;
    }
  }

  bool _isSameState(EditState a, EditState b) {
    return a.filterPreset == b.filterPreset &&
        _sameDouble(a.filterIntensity, b.filterIntensity) &&
        _sameCrop(a.crop, b.crop) &&
        _sameAdjustments(a.adjustments, b.adjustments);
  }

  bool _sameCrop(CropParams a, CropParams b) {
    return _sameDouble(a.x, b.x) &&
        _sameDouble(a.y, b.y) &&
        _sameDouble(a.width, b.width) &&
        _sameDouble(a.height, b.height) &&
        a.ratio == b.ratio &&
        a.quarterTurns == b.quarterTurns &&
        _sameDouble(a.fineRotationDegrees, b.fineRotationDegrees) &&
        a.flipHorizontal == b.flipHorizontal &&
        a.flipVertical == b.flipVertical;
  }

  bool _sameAdjustments(AdjustmentValues a, AdjustmentValues b) {
    return _sameDouble(a.brightness, b.brightness) &&
        _sameDouble(a.contrast, b.contrast) &&
        _sameDouble(a.saturation, b.saturation) &&
        _sameDouble(a.vibrance, b.vibrance) &&
        _sameDouble(a.highlights, b.highlights) &&
        _sameDouble(a.shadows, b.shadows) &&
        _sameDouble(a.sharpen, b.sharpen) &&
        _sameDouble(a.blur, b.blur);
  }

  bool _sameDouble(double a, double b, [double epsilon = 0.0001]) {
    return (a - b).abs() <= epsilon;
  }

  Future<Result<Uint8List>> renderCurrentForAiInput() async {
    final image = sourceImage.value;
    if (image == null) {
      return Result.failure<Uint8List>(
        const AppError(code: 'NO_IMAGE', message: 'No image selected'),
      );
    }
    return _localEditService.renderForAi(
      originalPath: image.originalPath,
      state: editState.value,
      longEdgeCap: AppConstants.aiInputLongEdge,
    );
  }

  Future<Result<Uint8List>> renderCurrentForExport(
      ExportSettings settings) async {
    final image = sourceImage.value;
    if (image == null) {
      return Result.failure<Uint8List>(
        const AppError(code: 'NO_IMAGE', message: 'No image selected'),
      );
    }
    return _localEditService.renderForExport(
      originalPath: image.originalPath,
      state: editState.value,
      settings: settings,
    );
  }

  void setAiSelectedVariant(EnhanceResult result) {
    aiSelectedVariant.value = result.variant;
    aiSelectedPath.value = result.cachedPath;
    aiSelectedBytes.value = result.bytes;
  }

  void clearAiSelection() {
    aiSelectedVariant.value = null;
    aiSelectedPath.value = null;
    aiSelectedBytes.value = null;
  }

  void cancelPendingOperations() {
    _renderDebounce?.cancel();
    _renderDebounce = null;
    _renderToken++;
    isRendering.value = false;
  }

  bool _canApply(String expectedSession) {
    return !isClosed && sessionId.value == expectedSession;
  }
}
