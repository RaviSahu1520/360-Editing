import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photo_editor_auto_improve/controllers/app_controller.dart';
import 'package:photo_editor_auto_improve/controllers/auto_improve_controller.dart';
import 'package:photo_editor_auto_improve/controllers/editor_controller.dart';
import 'package:photo_editor_auto_improve/controllers/export_controller.dart';
import 'package:photo_editor_auto_improve/diagnostics/app_logger.dart';
import 'package:photo_editor_auto_improve/services/analytics/analytics_service.dart';
import 'package:photo_editor_auto_improve/services/api/gemini_enhance_api.dart';
import 'package:photo_editor_auto_improve/services/image_io_service.dart';
import 'package:photo_editor_auto_improve/services/local_edit_service.dart';
import 'package:photo_editor_auto_improve/services/storage_service.dart';

Future<void> setupTestDependencies() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  Get.reset();
  final logger = AppLogger();
  Get.put<AppLogger>(logger, permanent: true);
  final storage = Get.put(StorageService(), permanent: true);
  final analytics = Get.put(AnalyticsService(logger), permanent: true);
  final localEdit = Get.put(LocalEditService(logger), permanent: true);
  final imageIo = Get.put(ImageIOService(storage, logger), permanent: true);
  final api = Get.put(GeminiEnhanceApi(logger: logger), permanent: true);
  final app = Get.put(AppController(), permanent: true);
  Get.put(
    EditorController(
      imageIOService: imageIo,
      localEditService: localEdit,
      storageService: storage,
      analyticsService: analytics,
      logger: logger,
    ),
    permanent: true,
  );
  Get.put(
    AutoImproveController(
      api: api,
      storageService: storage,
      analyticsService: analytics,
      appController: app,
      logger: logger,
    ),
    permanent: true,
  );
  Get.put(
    ExportController(
      storageService: storage,
      localEditService: localEdit,
      analyticsService: analytics,
      logger: logger,
    ),
    permanent: true,
  );
}
