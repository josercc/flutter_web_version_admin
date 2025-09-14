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

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN;

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
    ),
    GetPage(
      name: _Paths.CACHE_MANAGEMENT,
      page: () => const CacheManagementView(),
      binding: CacheManagementBinding(),
    ),
    GetPage(
      name: _Paths.BUILD_MANAGEMENT,
      page: () => const BuildManagementView(),
      binding: BuildManagementBinding(),
    ),
    GetPage(
      name: _Paths.LOG_MANAGEMENT,
      page: () => const LogManagementView(),
      binding: LogManagementBinding(),
    ),
  ];
}
