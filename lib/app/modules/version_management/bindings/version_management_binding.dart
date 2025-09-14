import 'package:get/get.dart';

import '../controllers/version_management_controller.dart';

class VersionManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VersionManagementController>(
      () => VersionManagementController(),
    );
  }
}
