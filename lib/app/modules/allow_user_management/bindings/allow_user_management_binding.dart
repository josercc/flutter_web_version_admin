import 'package:get/get.dart';
import '../controllers/allow_user_management_controller.dart';

class AllowUserManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AllowUserManagementController>(
      () => AllowUserManagementController(),
    );
  }
}
