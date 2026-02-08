import 'dart:developer';

abstract class CrashReporter {
  Future<void> recordError({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    Map<String, Object?> context,
  });
}

class ConsoleCrashReporter implements CrashReporter {
  @override
  Future<void> recordError({
    required Object error,
    required StackTrace stackTrace,
    required String reason,
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    log(
      '[crash] $reason error=$error context=$context',
      name: 'CrashReporter',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
