import 'package:get/get.dart';
import '../controllers/log_management_controller.dart';

class LogManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LogManagementController>(
      () => LogManagementController(),
    );
  }
}
