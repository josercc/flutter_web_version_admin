import 'package:get/get.dart';
import '../controllers/cache_management_controller.dart';

class CacheManagementBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CacheManagementController>(
      () => CacheManagementController(),
    );
  }
}
