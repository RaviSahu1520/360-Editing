import '../../diagnostics/app_logger.dart';

class AnalyticsService {
  AnalyticsService(this._logger);

  final AppLogger _logger;

  void logEvent(String eventName, {Map<String, dynamic>? params}) {
    _logger.info(
      'analytics',
      eventName,
      data: <String, Object?>{
        ...?params,
      },
    );
  }
}
