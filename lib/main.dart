import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:flutter_web_version_admin/app/commons/auth_session.dart';

import 'package:get/get.dart';

import 'app/routes/app_pages.dart';

void main() {
  Get.lazyPut<AppwriteManager>(() => AppwriteManager());
  Get.lazyPut<AuthSession>(() => AuthSession());
  runApp(
    GetMaterialApp(
      title: "Application",
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      builder: FlutterSmartDialog.init(),
    ),
  );
}
