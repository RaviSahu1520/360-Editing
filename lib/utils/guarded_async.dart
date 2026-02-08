import 'dart:async';

import 'result.dart';

typedef SessionProvider = String Function();
typedef VoidAsync = Future<void> Function();

class OperationGuard {
  bool _isCancelled = false;
  final List<void Function()> _onCancel = <void Function()>[];

  bool get isCancelled => _isCancelled;

  void registerCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
      return;
    }
    _onCancel.add(callback);
  }

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    for (final callback in _onCancel) {
      callback();
    }
    _onCancel.clear();
  }
}

class GuardedAsync {
  static Future<Result<T>> run<T>({
    required String operationName,
    required String sessionId,
    required SessionProvider currentSession,
    required Future<Result<T>> Function() task,
    OperationGuard? guard,
  }) async {
    if (guard?.isCancelled == true || currentSession() != sessionId) {
      return Result.cancelled<T>(message: '$operationName cancelled');
    }
    final result = await task();
    if (guard?.isCancelled == true || currentSession() != sessionId) {
      return Result.cancelled<T>(
          message: '$operationName stale result ignored');
    }
    return result;
  }

  static Future<void> runFireAndForget({
    required VoidAsync task,
  }) async {
    try {
      await task();
    } catch (_) {
      // Intentionally swallowed for non-critical diagnostics tasks.
    }
  }
}
