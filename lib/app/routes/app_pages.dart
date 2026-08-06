import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/version_management/bindings/version_management_binding.dart';
import '../modules/version_management/views/version_management_view.dart';
import '../modules/cache_management/bindings/cache_management_binding.dart';
import '../modules/cache_management/views/cache_management_view.dart';
import '../modules/build_management/bindings/build_management_binding.dart';
import '../modules/build_management/views/build_management_view.dart';
import '../modules/log_management/bindings/log_management_binding.dart';
import '../modules/log_management/views/log_management_view.dart';
import '../modules/packager_management/bindings/packager_management_binding.dart';
import '../modules/packager_management/views/packager_management_view.dart';
import '../modules/device_debug/bindings/device_debug_binding.dart';
import '../modules/device_debug/views/device_debug_view.dart';
import 'admin_middleware.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN;

  static final _adminOnly = [AdminMiddleware()];

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.VERSION_MANAGEMENT,
      page: () => const VersionManagementView(),
      binding: VersionManagementBinding(),
      middlewares: _adminOnly,
    ),
    GetPage(
      name: _Paths.CACHE_MANAGEMENT,
      page: () => const CacheManagementView(),
      binding: CacheManagementBinding(),
      middlewares: _adminOnly,
    ),
    GetPage(
      name: _Paths.BUILD_MANAGEMENT,
      page: () => const BuildManagementView(),
      binding: BuildManagementBinding(),
      middlewares: _adminOnly,
    ),
    GetPage(
      name: _Paths.LOG_MANAGEMENT,
      page: () => const LogManagementView(),
      binding: LogManagementBinding(),
      middlewares: _adminOnly,
    ),
    GetPage(
      name: _Paths.PACKAGER_MANAGEMENT,
      page: () => const PackagerManagementView(),
      binding: PackagerManagementBinding(),
      middlewares: _adminOnly,
    ),
    GetPage(
      name: _Paths.DEVICE_DEBUG,
      page: () => const DeviceDebugView(),
      binding: DeviceDebugBinding(),
    ),
  ];
}
