import 'package:get/get.dart';

import '../controllers/hotfix_controller.dart';

class HotfixBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HotfixController>(
      () => HotfixController(),
    );
  }
}
