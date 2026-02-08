import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';

import 'bindings/app_bindings.dart';
import 'diagnostics/app_logger.dart';
import 'diagnostics/crash_reporter.dart';
import 'diagnostics/debug_overlay.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

Future<void> main() async {
  // Initialize binding BEFORE runZonedGuarded to avoid zone mismatch
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file is optional - fall back to dart-define or defaults
    print('Note: .env file not found or could not be loaded: $e');
  }

  // Initialize logger and crash reporter before error handlers
  final logger = AppLogger();
  final crashReporter = ConsoleCrashReporter();

  // Register core services before bindings
  Get.put<AppLogger>(logger, permanent: true);
  Get.put<CrashReporter>(crashReporter, permanent: true);

  runZonedGuarded(
    () {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        crashReporter.recordError(
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.current,
          reason: 'flutter_error',
          context: <String, Object?>{
            'library': details.library,
            'context': details.context?.toDescription(),
          },
        );
        logger.error(
          'crash',
          'FlutterError',
          data: <String, Object?>{
            'error': details.exceptionAsString(),
          },
        );
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        crashReporter.recordError(
          error: error,
          stackTrace: stack,
          reason: 'platform_dispatcher',
        );
        logger.error(
          'crash',
          'PlatformDispatcher',
          data: <String, Object?>{'error': error.toString()},
        );
        return true;
      };
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return Material(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Something went wrong.\nPlease reopen the editor.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade200),
              ),
            ),
          ),
        );
      };

      runApp(const PhotoEditorMvpApp());
    },
    (Object error, StackTrace stack) {
      crashReporter.recordError(
        error: error,
        stackTrace: stack,
        reason: 'run_zoned_guarded',
      );
      logger.error(
        'crash',
        'Zone uncaught',
        data: <String, Object?>{'error': error.toString()},
      );
    },
  );
}

class PhotoEditorMvpApp extends StatelessWidget {
  const PhotoEditorMvpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      initialBinding: AppBindings(),
      getPages: AppPages.pages,
      themeMode: ThemeMode.system,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) {
        return Stack(
          children: <Widget>[
            child ?? const SizedBox.shrink(),
            const DebugOverlay(),
          ],
        );
      },
    );
  }
}
