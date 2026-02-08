import 'dart:math';

String generateRequestId(String prefix) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
  return '${prefix}_${now}_$random';
}
