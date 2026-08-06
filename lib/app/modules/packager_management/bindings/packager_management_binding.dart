import 'package:get/get.dart';
import '../controllers/packager_management_controller.dart';

class PackagerManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PackagerManagementController>(
      () => PackagerManagementController(),
    );
  }
}
