import 'package:get/get.dart';

import '../ui/editor/editor_screen.dart';
import '../ui/export/export_screen.dart';
import '../ui/home/home_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String editor = '/editor';
  static const String export = '/export';
}

class AppPages {
  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<dynamic>(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage<dynamic>(
      name: AppRoutes.editor,
      page: () => const EditorScreen(),
      transition: Transition.cupertino,
    ),
    GetPage<dynamic>(
      name: AppRoutes.export,
      page: () => const ExportScreen(),
      transition: Transition.downToUp,
    ),
  ];
}
