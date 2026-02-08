import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

enum LogLevel {
  info,
  warn,
  error,
}

class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.scope,
    required this.message,
    required this.data,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String scope;
  final String message;
  final Map<String, Object?> data;
}

class AppLogger extends GetxService {
  AppLogger({this.capacity = 50});

  final int capacity;
  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();

  final logs = <LogEntry>[].obs;
  final avgBuildFrameMs = 0.0.obs;
  final avgRasterFrameMs = 0.0.obs;
  final currentImageWidth = 0.obs;
  final currentImageHeight = 0.obs;
  final currentPreviewBytes = 0.obs;
  final currentEditedBytes = 0.obs;
  bool _frameCallbackInstalled = false;

  void startFrameMetrics() {
    if (_frameCallbackInstalled) {
      return;
    }
    _frameCallbackInstalled = true;
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void setImageMetrics({
    required int width,
    required int height,
    required int previewBytes,
    required int editedBytes,
  }) {
    currentImageWidth.value = width;
    currentImageHeight.value = height;
    currentPreviewBytes.value = previewBytes;
    currentEditedBytes.value = editedBytes;
  }

  void info(String scope, String message,
      {Map<String, Object?> data = const <String, Object?>{}}) {
    _add(LogLevel.info, scope, message, data);
  }

  void warn(String scope, String message,
      {Map<String, Object?> data = const <String, Object?>{}}) {
    _add(LogLevel.warn, scope, message, data);
  }

  void error(String scope, String message,
      {Map<String, Object?> data = const <String, Object?>{}}) {
    _add(LogLevel.error, scope, message, data);
  }

  void _add(
    LogLevel level,
    String scope,
    String message,
    Map<String, Object?> data,
  ) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      scope: scope,
      message: message,
      data: data,
    );
    if (_entries.length >= capacity) {
      _entries.removeFirst();
    }
    _entries.addLast(entry);
    logs.assignAll(_entries.toList(growable: false));
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) {
      return;
    }
    final buildAvg = timings
            .map((timing) => timing.buildDuration.inMicroseconds / 1000.0)
            .reduce((a, b) => a + b) /
        timings.length;
    final rasterAvg = timings
            .map((timing) => timing.rasterDuration.inMicroseconds / 1000.0)
            .reduce((a, b) => a + b) /
        timings.length;
    avgBuildFrameMs.value = (avgBuildFrameMs.value * 0.8) + (buildAvg * 0.2);
    avgRasterFrameMs.value = (avgRasterFrameMs.value * 0.8) + (rasterAvg * 0.2);
  }
}
