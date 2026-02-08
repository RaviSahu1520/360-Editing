class AppError {
  const AppError({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
    this.stackTrace,
  });

  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;
  final StackTrace? stackTrace;
}

enum ResultState {
  success,
  failure,
  cancelled,
}

class Result<T> {
  const Result._({
    required this.state,
    this.data,
    this.error,
  });

  final T? data;
  final AppError? error;
  final ResultState state;

  bool get isSuccess => state == ResultState.success;
  bool get isFailure => state == ResultState.failure;
  bool get isCancelled => state == ResultState.cancelled;

  static Result<T> success<T>(T data) {
    return Result<T>._(state: ResultState.success, data: data);
  }

  static Result<void> successNoData() {
    return const Result<void>._(state: ResultState.success);
  }

  static Result<T> failure<T>(AppError error) {
    return Result<T>._(state: ResultState.failure, error: error);
  }

  static Result<T> cancelled<T>({String message = 'Operation cancelled'}) {
    return Result<T>._(
      state: ResultState.cancelled,
      error: AppError(code: 'CANCELLED', message: message),
    );
  }
}
