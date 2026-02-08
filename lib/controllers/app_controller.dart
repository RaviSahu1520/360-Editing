import 'package:get/get.dart';

class AppController extends GetxController {
  final enableBackgroundBlur = false.obs;
  final enableCamera = false.obs;
  final debugOverlayEnabled = false.obs;

  void toggleDebugOverlay() {
    debugOverlayEnabled.value = !debugOverlayEnabled.value;
  }
}
