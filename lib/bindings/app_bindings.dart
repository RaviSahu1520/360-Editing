import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../controllers/auto_improve_controller.dart';
import '../controllers/editor_controller.dart';
import '../controllers/export_controller.dart';
import '../diagnostics/app_logger.dart';
import '../diagnostics/crash_reporter.dart';
import '../services/analytics/analytics_service.dart';
import '../services/api/gemini_enhance_api.dart';
import '../services/image_io_service.dart';
import '../services/local/enhance_service.dart';
import '../services/local_edit_service.dart';
import '../services/storage_service.dart';

/// Global application bindings for dependency injection.
///
/// This class manages all service and controller dependencies in one place,
/// making it easier to manage the application's dependency graph.
///
/// Usage:
/// ```dart
/// GetMaterialApp(
///   initialBinding: AppBindings(),
///   ...
/// )
/// ```
class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Core services (permanent, never disposed)
    _injectCoreServices();

    // Controllers (lazy-loaded, fenix = recreate on resubscription)
    _injectControllers();
  }

  void _injectCoreServices() {
    // Diagnostics
    if (!Get.isRegistered<AppLogger>()) {
      Get.put<AppLogger>(AppLogger(), permanent: true);
    }
    final logger = Get.find<AppLogger>();
    logger.startFrameMetrics();

    if (!Get.isRegistered<CrashReporter>()) {
      Get.put<CrashReporter>(ConsoleCrashReporter(), permanent: true);
    }

    // Data & business logic services
    if (!Get.isRegistered<StorageService>()) {
      Get.put<StorageService>(StorageService(), permanent: true);
    }
    if (!Get.isRegistered<AnalyticsService>()) {
      Get.put<AnalyticsService>(
        AnalyticsService(Get.find<AppLogger>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LocalEditService>()) {
      Get.put<LocalEditService>(
        LocalEditService(Get.find<AppLogger>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<ImageIOService>()) {
      Get.put<ImageIOService>(
        ImageIOService(Get.find<StorageService>(), Get.find<AppLogger>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<GeminiEnhanceApi>()) {
      Get.put<GeminiEnhanceApi>(
        GeminiEnhanceApi(logger: Get.find<AppLogger>()),
        permanent: true,
      );
    }
    if (!Get.isRegistered<LocalEnhanceService>()) {
      Get.put<LocalEnhanceService>(
        LocalEnhanceService(logger: Get.find<AppLogger>()),
        permanent: true,
      );
    }
  }

  void _injectControllers() {
    // AppController - global app state and feature flags
    Get.lazyPut<AppController>(
      AppController.new,
      fenix: true,
    );

    // EditorController - main editing state and operations
    Get.lazyPut<EditorController>(
      () => EditorController(
        imageIOService: Get.find<ImageIOService>(),
        localEditService: Get.find<LocalEditService>(),
        storageService: Get.find<StorageService>(),
        analyticsService: Get.find<AnalyticsService>(),
        logger: Get.find<AppLogger>(),
      ),
      fenix: true,
    );

    // AutoImproveController - AI enhancement workflow
    Get.lazyPut<AutoImproveController>(
      () => AutoImproveController(
        api: Get.find<GeminiEnhanceApi>(),
        storageService: Get.find<StorageService>(),
        analyticsService: Get.find<AnalyticsService>(),
        appController: Get.find<AppController>(),
        logger: Get.find<AppLogger>(),
        localEnhanceService: Get.find<LocalEnhanceService>(),
      ),
      fenix: true,
    );

    // ExportController - export settings and operations
    Get.lazyPut<ExportController>(
      () => ExportController(
        storageService: Get.find<StorageService>(),
        localEditService: Get.find<LocalEditService>(),
        analyticsService: Get.find<AnalyticsService>(),
        logger: Get.find<AppLogger>(),
      ),
      fenix: true,
    );
  }
}
