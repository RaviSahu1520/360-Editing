import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../diagnostics/app_logger.dart';
import '../utils/constants.dart';
import '../utils/result.dart';
import 'storage_service.dart';

class PickedImageData {
  const PickedImageData({
    required this.originalPath,
    required this.previewBytes,
    required this.width,
    required this.height,
    required this.fileName,
    required this.mimeType,
    required this.originalFileBytes,
  });

  final String originalPath;
  final Uint8List previewBytes;
  final int width;
  final int height;
  final String fileName;
  final String mimeType;
  final int originalFileBytes;
}

class ImageIOService {
  ImageIOService(
    this._storageService,
    this._logger,
  );

  final StorageService _storageService;
  final AppLogger _logger;

  Future<Result<PickedImageData>> pickImage() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
        type: FileType.custom,
        allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      );
      if (picked == null || picked.files.isEmpty) {
        return Result.failure<PickedImageData>(
          const AppError(
              code: 'CANCELLED', message: 'Image selection cancelled'),
        );
      }
      final pickedFile = picked.files.first;
      final path = pickedFile.path;
      if (path == null) {
        return Result.failure<PickedImageData>(
          const AppError(code: 'INVALID_FILE', message: 'File path missing'),
        );
      }
      return _loadAndPrepare(path: path, explicitName: pickedFile.name);
    } catch (error, stack) {
      _logger.error(
        'image_io',
        'pickImage exception',
        data: <String, Object?>{'error': error.toString()},
      );
      return Result.failure<PickedImageData>(
        AppError(
          code: 'INVALID_FILE',
          message: 'Could not select image',
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<PickedImageData>> loadFromPath(String path) async {
    return _loadAndPrepare(path: path, explicitName: p.basename(path));
  }

  Future<Result<PickedImageData>> _loadAndPrepare({
    required String path,
    required String explicitName,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return Result.failure<PickedImageData>(
        const AppError(code: 'NOT_FOUND', message: 'Image file was not found'),
      );
    }

    try {
      final fileLength = await file.length();
      if (fileLength > AppConstants.maxUploadBytes) {
        return Result.failure<PickedImageData>(
          const AppError(
            code: 'FILE_TOO_LARGE',
            message: 'Selected file exceeds 15MB limit.',
          ),
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return Result.failure<PickedImageData>(
          const AppError(code: 'INVALID_FILE', message: 'Unable to read file'),
        );
      }

      final ext = _normalizedExtension(p.extension(explicitName));
      final prepared =
          await compute<Map<String, Object?>, Map<String, Object?>>(
        _prepareImageOnIsolate,
        <String, Object?>{
          'bytes': bytes,
          'extension': ext,
          'previewLongEdge': AppConstants.previewMaxLongEdge,
          'sourceLongEdge': AppConstants.sourceMaxLongEdge,
        },
      );
      if (prepared['ok'] != true) {
        return Result.failure<PickedImageData>(
          AppError(
            code: prepared['code']! as String,
            message: prepared['message']! as String,
          ),
        );
      }

      final original = prepared['original']! as Uint8List;
      final preview = prepared['preview']! as Uint8List;
      final width = prepared['width']! as int;
      final height = prepared['height']! as int;
      final mimeType = prepared['mimeType']! as String;

      final sourceDir = Directory(
        p.join((await _storageService.getAppDocDir()).path, 'sources'),
      );
      if (!await sourceDir.exists()) {
        await sourceDir.create(recursive: true);
      }
      final outputName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(explicitName)}.$ext';
      final outputPath = p.join(sourceDir.path, outputName);
      await File(outputPath).writeAsBytes(original, flush: true);

      _logger.info(
        'image_io',
        'image prepared',
        data: <String, Object?>{
          'name': explicitName,
          'w': width,
          'h': height,
          'src_bytes': original.lengthInBytes,
          'preview_bytes': preview.lengthInBytes,
        },
      );

      return Result.success<PickedImageData>(
        PickedImageData(
          originalPath: outputPath,
          previewBytes: preview,
          width: width,
          height: height,
          fileName: outputName,
          mimeType: mimeType,
          originalFileBytes: original.lengthInBytes,
        ),
      );
    } catch (error, stack) {
      _logger.error(
        'image_io',
        'load/prepare exception',
        data: <String, Object?>{'error': error.toString()},
      );
      return Result.failure<PickedImageData>(
        AppError(
          code: 'DECODE_FAILED',
          message: 'Unable to decode this image.',
          stackTrace: stack,
        ),
      );
    }
  }

  String _normalizedExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (ext == 'png') {
      return 'png';
    }
    return 'jpg';
  }
}

Map<String, Object?> _prepareImageOnIsolate(Map<String, Object?> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final extension = payload['extension']! as String;
  final previewLongEdge = payload['previewLongEdge']! as int;
  final sourceLongEdge = payload['sourceLongEdge']! as int;

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    return <String, Object?>{
      'ok': false,
      'code': 'DECODE_FAILED',
      'message': 'Could not decode image data',
    };
  }

  if (decoded == null) {
    return <String, Object?>{
      'ok': false,
      'code': 'UNSUPPORTED_FORMAT',
      'message': 'Could not decode image format.',
    };
  }

  var baked = img.bakeOrientation(decoded);
  final longEdge = baked.width > baked.height ? baked.width : baked.height;
  if (longEdge > sourceLongEdge) {
    final scale = sourceLongEdge / longEdge;
    baked = img.copyResize(
      baked,
      width: (baked.width * scale).round(),
      height: (baked.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  final previewScale = previewLongEdge /
      (baked.width > baked.height ? baked.width : baked.height);
  final preview = previewScale >= 1
      ? baked
      : img.copyResize(
          baked,
          width: (baked.width * previewScale).round(),
          height: (baked.height * previewScale).round(),
          interpolation: img.Interpolation.average,
        );

  final encodedOriginal = extension == 'png'
      ? Uint8List.fromList(img.encodePng(baked))
      : Uint8List.fromList(img.encodeJpg(baked, quality: 94));
  final encodedPreview =
      Uint8List.fromList(img.encodeJpg(preview, quality: 88));

  return <String, Object?>{
    'ok': true,
    'original': encodedOriginal,
    'preview': encodedPreview,
    'width': baked.width,
    'height': baked.height,
    'mimeType': extension == 'png' ? 'image/png' : 'image/jpeg',
  };
}
