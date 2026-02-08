import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../diagnostics/app_logger.dart';
import '../models/edit_state.dart';
import '../models/export_settings.dart';
import '../utils/constants.dart';
import '../utils/result.dart';

class LocalEditService {
  LocalEditService(this._logger);

  final AppLogger _logger;

  Future<Result<Uint8List>> applyEditsToPreview({
    required Uint8List previewBytes,
    required EditState state,
  }) async {
    return _safeRender(
      op: 'preview_render',
      payload: <String, Object?>{
        'bytes': previewBytes,
        'state': state.toJson(),
        'maxLongEdge': AppConstants.previewMaxLongEdge,
        'format': 'jpg',
        'quality': 90,
      },
    );
  }

  Future<Result<Uint8List>> renderForAi({
    required String originalPath,
    required EditState state,
    int longEdgeCap = AppConstants.aiInputLongEdge,
  }) async {
    try {
      final bytes = await File(originalPath).readAsBytes();
      return _safeRender(
        op: 'ai_render',
        payload: <String, Object?>{
          'bytes': bytes,
          'state': state.toJson(),
          'maxLongEdge': longEdgeCap,
          'format': 'jpg',
          'quality': 92,
        },
      );
    } catch (error, stack) {
      return Result.failure<Uint8List>(
        AppError(
          code: 'READ_FAILED',
          message: 'Could not read source image for AI input',
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<Uint8List>> renderForExport({
    required String originalPath,
    required EditState state,
    required ExportSettings settings,
  }) async {
    try {
      final bytes = await File(originalPath).readAsBytes();
      return _safeRender(
        op: 'export_render',
        payload: <String, Object?>{
          'bytes': bytes,
          'state': state.toJson(),
          'maxLongEdge': null,
          'format': settings.extension,
          'quality': settings.quality,
        },
      );
    } catch (error, stack) {
      return Result.failure<Uint8List>(
        AppError(
          code: 'READ_FAILED',
          message: 'Could not read source image for export',
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<Uint8List>> transcode({
    required Uint8List bytes,
    required ExportSettings settings,
  }) async {
    try {
      final encoded = await compute<Map<String, Object?>, Uint8List>(
        _transcodeOnIsolate,
        <String, Object?>{
          'bytes': bytes,
          'format': settings.extension,
          'quality': settings.quality,
        },
      );
      return Result.success<Uint8List>(encoded);
    } catch (error, stack) {
      return Result.failure<Uint8List>(
        AppError(
          code: 'TRANSCODE_FAILED',
          message: 'Could not transcode image',
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<Map<FilterPreset, Uint8List>>> generateFilterThumbnails({
    required Uint8List sourcePreviewBytes,
  }) async {
    try {
      final payload = <String, Object?>{
        'bytes': sourcePreviewBytes,
        'edge': AppConstants.filterThumbEdge,
        'presets': FilterPreset.values.map((e) => e.name).toList(),
      };
      final output =
          await compute<Map<String, Object?>, Map<String, Uint8List>>(
        _generateFilterThumbsOnIsolate,
        payload,
      );
      final parsed = <FilterPreset, Uint8List>{};
      for (final preset in FilterPreset.values) {
        final bytes = output[preset.name];
        if (bytes != null) {
          parsed[preset] = bytes;
        }
      }
      return Result.success<Map<FilterPreset, Uint8List>>(parsed);
    } catch (error, stack) {
      _logger.warn(
        'local_edit',
        'thumbnail generation failed',
        data: <String, Object?>{'error': error.toString()},
      );
      return Result.failure<Map<FilterPreset, Uint8List>>(
        AppError(
          code: 'THUMBNAIL_FAILED',
          message: 'Unable to generate filter previews',
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<Uint8List>> _safeRender({
    required String op,
    required Map<String, Object?> payload,
  }) async {
    try {
      final rendered = await compute<Map<String, Object?>, Uint8List>(
        _renderImageOnIsolate,
        payload,
      );
      return Result.success<Uint8List>(rendered);
    } catch (error, stack) {
      _logger.error(
        'local_edit',
        '$op failed',
        data: <String, Object?>{'error': error.toString()},
      );
      return Result.failure<Uint8List>(
        AppError(
          code: 'RENDER_FAILED',
          message: 'Unable to render image',
          stackTrace: stack,
        ),
      );
    }
  }
}

Uint8List _transcodeOnIsolate(Map<String, Object?> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final format = payload['format']! as String;
  final quality = (payload['quality']! as num).toInt();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }
  if (format == 'png') {
    return Uint8List.fromList(img.encodePng(decoded));
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
}

Uint8List _renderImageOnIsolate(Map<String, Object?> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final format = payload['format']! as String;
  final quality = (payload['quality']! as num).toInt();
  final maxLongEdge = (payload['maxLongEdge'] as num?)?.toInt();
  final stateJson = payload['state']! as Map<String, dynamic>;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  var working = decoded;
  final state = EditState.fromJson(stateJson);
  working = _applyCropAndTransforms(working, state.crop);
  _applyFilterInPlace(working, state.filterPreset, state.filterIntensity / 100);
  working = _applyAdjustments(working, state.adjustments);

  if (maxLongEdge != null) {
    final longEdge = math.max(working.width, working.height);
    if (longEdge > maxLongEdge) {
      final scale = maxLongEdge / longEdge;
      working = img.copyResize(
        working,
        width: math.max(1, (working.width * scale).round()),
        height: math.max(1, (working.height * scale).round()),
        interpolation: img.Interpolation.average,
      );
    }
  }

  // TODO(native-opt): replace CPU image operations with native GPU acceleration.
  if (format == 'png') {
    return Uint8List.fromList(img.encodePng(working));
  }
  return Uint8List.fromList(img.encodeJpg(working, quality: quality));
}

Map<String, Uint8List> _generateFilterThumbsOnIsolate(
    Map<String, Object?> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final edge = payload['edge']! as int;
  final presetNames = payload['presets']! as List<dynamic>;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return <String, Uint8List>{};
  }

  final square = _centerCropSquare(decoded);
  final baseThumb = img.copyResize(
    square,
    width: edge,
    height: edge,
    interpolation: img.Interpolation.average,
  );

  final output = <String, Uint8List>{};
  for (final raw in presetNames) {
    final name = raw as String;
    final preset = FilterPreset.values.firstWhere(
      (item) => item.name == name,
      orElse: () => FilterPreset.none,
    );
    final working = img.Image.from(baseThumb);
    _applyFilterInPlace(
        working, preset, preset == FilterPreset.none ? 0 : 0.65);
    output[name] = Uint8List.fromList(img.encodeJpg(working, quality: 82));
  }
  return output;
}

img.Image _centerCropSquare(img.Image source) {
  final edge = math.min(source.width, source.height);
  final x = ((source.width - edge) / 2).round();
  final y = ((source.height - edge) / 2).round();
  return img.copyCrop(source, x: x, y: y, width: edge, height: edge);
}

img.Image _applyCropAndTransforms(img.Image image, CropParams crop) {
  var working = image;
  final x =
      (crop.x * working.width).round().clamp(0, math.max(0, working.width - 1))
          as int;
  final y = (crop.y * working.height)
      .round()
      .clamp(0, math.max(0, working.height - 1)) as int;
  final width = (crop.width * working.width)
      .round()
      .clamp(1, math.max(1, working.width - x)) as int;
  final height = (crop.height * working.height)
      .round()
      .clamp(1, math.max(1, working.height - y)) as int;
  working = img.copyCrop(
    working,
    x: x,
    y: y,
    width: width,
    height: height,
  );

  final turns = crop.quarterTurns % 4;
  for (var i = 0; i < turns; i++) {
    working = img.copyRotate(working, angle: 90);
  }
  if (crop.fineRotationDegrees.abs() > 0.1) {
    working = img.copyRotate(working, angle: crop.fineRotationDegrees);
  }
  if (crop.flipHorizontal) {
    working = img.flipHorizontal(working);
  }
  if (crop.flipVertical) {
    working = img.flipVertical(working);
  }
  return working;
}

void _applyFilterInPlace(
    img.Image image, FilterPreset preset, double intensity) {
  if (preset == FilterPreset.none || intensity <= 0) {
    return;
  }
  final t = intensity.clamp(0.0, 1.0);
  for (final pixel in image) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();

    var fr = r;
    var fg = g;
    var fb = b;

    switch (preset) {
      case FilterPreset.none:
        break;
      case FilterPreset.warm:
        fr = r * 1.08 + 6;
        fg = g * 1.02;
        fb = b * 0.92;
      case FilterPreset.cool:
        fr = r * 0.92;
        fg = g * 0.99;
        fb = b * 1.08 + 5;
      case FilterPreset.bw:
      case FilterPreset.mono:
        final luma = 0.299 * r + 0.587 * g + 0.114 * b;
        fr = luma;
        fg = luma;
        fb = luma;
      case FilterPreset.vintage:
        fr = (r * 0.9) + 18;
        fg = (g * 0.82) + 10;
        fb = b * 0.7;
      case FilterPreset.cinematic:
        fr = r * 1.04 + 4;
        fg = g * 0.95;
        fb = b * 0.88 + 8;
      case FilterPreset.pop:
        final mean = (r + g + b) / 3;
        fr = mean + (r - mean) * 1.3;
        fg = mean + (g - mean) * 1.3;
        fb = mean + (b - mean) * 1.3;
      case FilterPreset.fade:
        fr = r * 0.92 + 20;
        fg = g * 0.92 + 20;
        fb = b * 0.92 + 20;
      case FilterPreset.clarity:
        fr = ((r - 128) * 1.08) + 128;
        fg = ((g - 128) * 1.08) + 128;
        fb = ((b - 128) * 1.08) + 128;
      case FilterPreset.sunset:
        fr = r * 1.1 + 10;
        fg = g * 0.96;
        fb = b * 0.88;
    }

    pixel
      ..r = _mixChannel(r, fr, t)
      ..g = _mixChannel(g, fg, t)
      ..b = _mixChannel(b, fb, t);
  }
}

img.Image _applyAdjustments(img.Image image, AdjustmentValues adjustments) {
  if (adjustments.isDefault) {
    return image;
  }
  var working = image;

  final brightnessDelta = adjustments.brightness * 0.9;
  final contrastFactor = 1 + (adjustments.contrast / 100) * 0.75;
  final saturationFactor = 1 + (adjustments.saturation / 100) * 0.85;
  final vibranceFactor = adjustments.vibrance / 100;
  final highlightAdjust = adjustments.highlights / 100;
  final shadowAdjust = adjustments.shadows / 100;

  for (final pixel in working) {
    var r = pixel.r.toDouble();
    var g = pixel.g.toDouble();
    var b = pixel.b.toDouble();

    if (brightnessDelta != 0) {
      r += brightnessDelta;
      g += brightnessDelta;
      b += brightnessDelta;
    }

    if (contrastFactor != 1) {
      r = ((r - 128) * contrastFactor) + 128;
      g = ((g - 128) * contrastFactor) + 128;
      b = ((b - 128) * contrastFactor) + 128;
    }

    final gray = 0.299 * r + 0.587 * g + 0.114 * b;
    if (saturationFactor != 1) {
      r = gray + (r - gray) * saturationFactor;
      g = gray + (g - gray) * saturationFactor;
      b = gray + (b - gray) * saturationFactor;
    }

    if (vibranceFactor != 0) {
      final maxCh = math.max(r, math.max(g, b));
      final avg = (r + g + b) / 3;
      final amt = ((maxCh - avg) / 255) * (-vibranceFactor * 1.5);
      r += (maxCh - r) * amt;
      g += (maxCh - g) * amt;
      b += (maxCh - b) * amt;
    }

    final luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    if (shadowAdjust != 0 && luma < 0.5) {
      final lift = (0.5 - luma) * shadowAdjust * 120;
      r += lift;
      g += lift;
      b += lift;
    }
    if (highlightAdjust != 0 && luma > 0.5) {
      final recover = (luma - 0.5) * highlightAdjust * 120;
      r -= recover;
      g -= recover;
      b -= recover;
    }

    pixel
      ..r = _clamp255(r)
      ..g = _clamp255(g)
      ..b = _clamp255(b);
  }

  if (adjustments.blur > 0) {
    final radius = (adjustments.blur / 25).round().clamp(1, 4);
    working = img.gaussianBlur(working, radius: radius);
  }

  if (adjustments.sharpen > 0) {
    final amount = (adjustments.sharpen / 100).clamp(0.0, 1.0);
    final blurred = img.gaussianBlur(
      img.copyResize(working, width: working.width, height: working.height),
      radius: 1,
    );
    for (var y = 0; y < working.height; y++) {
      for (var x = 0; x < working.width; x++) {
        final o = working.getPixel(x, y);
        final b = blurred.getPixel(x, y);
        working.setPixelRgba(
          x,
          y,
          _clamp255(o.r + (o.r - b.r) * amount),
          _clamp255(o.g + (o.g - b.g) * amount),
          _clamp255(o.b + (o.b - b.b) * amount),
          o.a,
        );
      }
    }
  }

  return working;
}

num _mixChannel(double original, double effected, double t) {
  return _clamp255(original + (effected - original) * t);
}

num _clamp255(num value) {
  if (value < 0) {
    return 0;
  }
  if (value > 255) {
    return 255;
  }
  return value;
}
