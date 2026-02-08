import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../utils/constants.dart';

class VersionDebugLabel extends StatelessWidget {
  const VersionDebugLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final appController = Get.find<AppController>();
    return GestureDetector(
      onLongPress: appController.toggleDebugOverlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          AppConstants.appVersion,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
