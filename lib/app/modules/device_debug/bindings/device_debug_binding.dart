import 'package:get/get.dart';

import '../controllers/device_debug_controller.dart';

class DeviceDebugBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DeviceDebugController>(() => DeviceDebugController());
  }
}
