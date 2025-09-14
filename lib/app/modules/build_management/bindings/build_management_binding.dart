import 'package:get/get.dart';
import '../controllers/build_management_controller.dart';

class BuildManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BuildManagementController>(
      () => BuildManagementController(),
    );
  }
}
