import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class StorageService {
  static const String _recentsKey = 'recent_paths';

  Future<List<String>> loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentsKey) ?? <String>[];
  }

  Future<void> addRecent(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_recentsKey) ?? <String>[];
    final next = <String>[path, ...current.where((item) => item != path)];
    final trimmed = next.take(AppConstants.recentLimit).toList();
    await prefs.setStringList(_recentsKey, trimmed);
  }

  Future<Directory> getAppCacheDir() async {
    return getTemporaryDirectory();
  }

  Future<Directory> getAppDocDir() async {
    return getApplicationDocumentsDirectory();
  }
}
