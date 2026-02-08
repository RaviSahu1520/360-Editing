import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../diagnostics/app_logger.dart';
import '../../models/auto_improve_options.dart';
import '../../models/enhance_result.dart';
import '../../utils/guarded_async.dart';
import '../../utils/request_id.dart';
import '../../utils/result.dart';

/// Local image enhancement service using image processing
/// This bypasses the backend API and performs enhancements locally
class LocalEnhanceService {
  LocalEnhanceService({
    required AppLogger logger,
  }) : _logger = logger;

  final AppLogger _logger;

  /// Enhance an image locally based on the provided options
  /// Returns multiple enhanced variants (A and B)
  Future<Result<List<EnhanceResult>>> enhanceImage({
    required Uint8List imageBytes,
    required AutoImproveOptions options,
    OperationGuard? guard,
    String? requestId,
  }) async {
    final reqId = requestId ?? generateRequestId('local_enhance');

    try {
      _logger.info('local_enhance', 'start', data: <String, Object?>{
        'request_id': reqId,
        'options': options.toJson(),
      });

      // Decode the original image
      final original = img.decodeImage(imageBytes);
      if (original == null) {
        return Result.failure<List<EnhanceResult>>(
          AppError(
            code: 'DECODE_FAILED',
            message: 'Failed to decode image',
            requestId: reqId,
          ),
        );
      }

      // Create variant A - Balanced enhancement
      final variantABytes = await _createVariantA(original, options, guard);

      if (guard?.isCancelled == true) {
        return Result.cancelled<List<EnhanceResult>>();
      }

      // Create variant B - Different enhancement style
      final variantBBytes = await _createVariantB(original, options, guard);

      if (guard?.isCancelled == true) {
        return Result.cancelled<List<EnhanceResult>>();
      }

      final results = <EnhanceResult>[
        EnhanceResult(
          variant: 'A',
          url: '',
          bytes: variantABytes,
          cachedPath: '',
        ),
        EnhanceResult(
          variant: 'B',
          url: '',
          bytes: variantBBytes,
          cachedPath: '',
        ),
      ];

      _logger.info('local_enhance', 'success', data: <String, Object?>{
        'request_id': reqId,
        'variants': results.length,
      });

      return Result.success<List<EnhanceResult>>(results);
    } catch (error, stack) {
      _logger.error('local_enhance', 'error', data: <String, Object?>{
        'error': error.toString(),
      });
      return Result.failure<List<EnhanceResult>>(
        AppError(
          code: 'LOCAL_ENHANCEMENT_FAILED',
          message: 'Local enhancement failed: $error',
          requestId: reqId,
          stackTrace: stack,
        ),
      );
    }
  }

  /// Create Variant A - Balanced enhancement
  Future<Uint8List> _createVariantA(
    img.Image original,
    AutoImproveOptions options,
    OperationGuard? guard,
  ) async {
    // Create a copy for variant A
    final variant = img.Image.from(original);

    // Apply enhancements based on options
    _applyVariantAEnhancements(variant, options);

    if (guard?.isCancelled == true) {
      throw Exception('Cancelled');
    }

    // Encode to JPEG
    return Uint8List.fromList(img.encodeJpg(variant, quality: 95));
  }

  /// Apply Variant A specific enhancements
  void _applyVariantAEnhancements(img.Image image, AutoImproveOptions options) {
    // 1. Brightness/Exposure
    if (options.lighting) {
      // Increase brightness slightly and improve contrast
      _adjustBrightness(image, 10);
      _adjustContrast(image, 1.1);
      _adjustSaturation(image, 1.05);
    }

    // 2. Skin enhancement (subtle warmth)
    if (options.skinImprovement) {
      _adjustSaturation(image, 0.97);
      _addWarmth(image, 5);
    }

    // 3. Sharpen details
    if (options.sharpenDetails) {
      _sharpen(image, strength: 0.3);
    }

    // 4. Reduce noise
    if (options.reduceNoise) {
      _smoothNoise(image, radius: 1);
    }

    // 5. Color grading
    _applyColorGrading(image, options.colorGrading, variant: 'A');
  }

  /// Create Variant B - More dramatic enhancement
  Future<Uint8List> _createVariantB(
    img.Image original,
    AutoImproveOptions options,
    OperationGuard? guard,
  ) async {
    // Create a copy for variant B
    final variant = img.Image.from(original);

    // Apply enhancements for variant B (more dramatic)
    _applyVariantBEnhancements(variant, options);

    if (guard?.isCancelled == true) {
      throw Exception('Cancelled');
    }

    // Encode to JPEG
    return Uint8List.fromList(img.encodeJpg(variant, quality: 95));
  }

  /// Apply Variant B specific enhancements (more dramatic)
  void _applyVariantBEnhancements(img.Image image, AutoImproveOptions options) {
    // Variant B is more dramatic

    if (options.lighting) {
      _adjustBrightness(image, 20);
      _adjustContrast(image, 1.2);
      _adjustSaturation(image, 1.15);
    }

    if (options.skinImprovement) {
      _adjustSaturation(image, 0.95);
      _addWarmth(image, 10);
    }

    if (options.sharpenDetails) {
      _sharpen(image, strength: 0.5);
    }

    if (options.reduceNoise) {
      _smoothNoise(image, radius: 2);
    }

    _applyColorGrading(image, options.colorGrading, variant: 'B');
  }

  /// Apply color grading based on selected grade
  void _applyColorGrading(
    img.Image image,
    String grade, {
    required String variant,
  }) {
    switch (grade) {
      case 'Warm':
        // Add warmth - boost red, slightly reduce blue
        final warmth = variant == 'A' ? 5 : 10;
        _addWarmth(image, warmth);
        if (variant == 'B') {
          _adjustSaturation(image, 1.08);
        }
        break;

      case 'Cool':
        // Add cool - boost blue, slightly reduce red
        final cool = variant == 'A' ? 5 : 10;
        _addCool(image, cool);
        if (variant == 'B') {
          _adjustSaturation(image, 1.06);
        }
        break;

      case 'Cinematic':
        // Cinematic look - teal & orange
        _applyCinematicLUT(image, variant: variant);
        break;

      case 'Natural':
      default:
        // Minimal adjustments
        break;
    }
  }

  /// Adjust brightness by adding a constant to all pixels
  void _adjustBrightness(img.Image image, int amount) {
    for (final pixel in image) {
      final r = pixel.r.clamp(0, 255);
      final g = pixel.g.clamp(0, 255);
      final b = pixel.b.clamp(0, 255);

      pixel.r = (r + amount).clamp(0, 255);
      pixel.g = (g + amount).clamp(0, 255);
      pixel.b = (b + amount).clamp(0, 255);
    }
  }

  /// Adjust contrast by scaling around midpoint (128)
  void _adjustContrast(img.Image image, double factor) {
    const midpoint = 128;
    for (final pixel in image) {
      pixel.r = ((pixel.r - midpoint) * factor + midpoint).clamp(0, 255);
      pixel.g = ((pixel.g - midpoint) * factor + midpoint).clamp(0, 255);
      pixel.b = ((pixel.b - midpoint) * factor + midpoint).clamp(0, 255);
    }
  }

  /// Adjust saturation by interpolating between grayscale and original
  void _adjustSaturation(img.Image image, double factor) {
    for (final pixel in image) {
      final gray = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).toInt();
      pixel.r = (gray + (pixel.r - gray) * factor).clamp(0, 255);
      pixel.g = (gray + (pixel.g - gray) * factor).clamp(0, 255);
      pixel.b = (gray + (pixel.b - gray) * factor).clamp(0, 255);
    }
  }

  /// Add warmth by boosting red and reducing blue
  void _addWarmth(img.Image image, int amount) {
    for (final pixel in image) {
      pixel.r = (pixel.r + amount).clamp(0, 255);
      pixel.b = (pixel.b - (amount ~/ 2)).clamp(0, 255);
    }
  }

  /// Add cool by boosting blue and reducing red
  void _addCool(img.Image image, int amount) {
    for (final pixel in image) {
      pixel.b = (pixel.b + amount).clamp(0, 255);
      pixel.r = (pixel.r - (amount ~/ 2)).clamp(0, 255);
    }
  }

  /// Apply cinematic teal & orange look
  void _applyCinematicLUT(img.Image image, {required String variant}) {
    final strength = variant == 'A' ? 0.5 : 0.7;

    for (final pixel in image) {
      // Calculate luminance
      final luminance = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;

      // Shadows get teal, highlights get orange
      if (luminance < 128) {
        // Shadows - add teal (boost blue/green, reduce red)
        final tealAmount = (1 - luminance / 128) * strength;
        pixel.r = (pixel.r * (1 - tealAmount)).clamp(0, 255);
        pixel.g = (pixel.g + 10 * tealAmount).clamp(0, 255);
        pixel.b = (pixel.b + 15 * tealAmount).clamp(0, 255);
      } else {
        // Highlights - add orange (boost red/green)
        final orangeAmount = ((luminance - 128) / 127) * strength;
        pixel.r = (pixel.r + 20 * orangeAmount).clamp(0, 255);
        pixel.g = (pixel.g + 5 * orangeAmount).clamp(0, 255);
      }
    }

    // Lower overall saturation for cinematic look
    if (variant == 'A') {
      _adjustSaturation(image, 0.9);
    } else {
      _adjustSaturation(image, 0.95);
    }
  }

  /// Sharpen image using convolution
  void _sharpen(img.Image image, {required double strength}) {
    // Create a copy for reference
    final original = img.Image.from(image);

    // Sharpen kernel
    final kernel = [
      0.0,
      -strength,
      0.0,
      -strength,
      1 + 4 * strength,
      -strength,
      0.0,
      -strength,
      0.0,
    ];

    // Apply convolution
    _convolution(image, original, kernel, 3);
  }

  /// Smooth noise using simple averaging
  void _smoothNoise(img.Image image, {required int radius}) {
    final original = img.Image.from(image);

    for (int y = radius; y < image.height - radius; y++) {
      for (int x = radius; x < image.width - radius; x++) {
        int r = 0, g = 0, b = 0, count = 0;

        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            final pixel = original.getPixel(x + dx, y + dy);
            r += pixel.r.toInt();
            g += pixel.g.toInt();
            b += pixel.b.toInt();
            count++;
          }
        }

        image.setPixelRgba(x, y, (r / count).round(), (g / count).round(), (b / count).round(), 255);
      }
    }
  }

  /// Apply convolution filter
  void _convolution(img.Image image, img.Image original, List<double> kernel, int size) {
    final half = size ~/ 2;

    for (int y = half; y < image.height - half; y++) {
      for (int x = half; x < image.width - half; x++) {
        double r = 0, g = 0, b = 0;

        int ki = 0;
        for (int ky = -half; ky <= half; ky++) {
          for (int kx = -half; kx <= half; kx++) {
            final pixel = original.getPixel(x + kx, y + ky);
            r += pixel.r * kernel[ki];
            g += pixel.g * kernel[ki];
            b += pixel.b * kernel[ki];
            ki++;
          }
        }

        image.setPixelRgba(x, y, r.clamp(0, 255).round(), g.clamp(0, 255).round(), b.clamp(0, 255).round(), 255);
      }
    }
  }
}
