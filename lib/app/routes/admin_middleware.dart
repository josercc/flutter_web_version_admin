import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../commons/auth_session.dart';

/// 非 admin 访问管理页时重定向回首页。
class AdminMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthSession>();
    if (!auth.canAccess(route ?? '')) {
      return const RouteSettings(name: '/home');
    }
    return null;
  }
}
