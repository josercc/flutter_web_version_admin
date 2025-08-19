import 'package:appwrite/appwrite.dart';
import 'package:easy_dialog/easy_dialog.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginController extends GetxController {
  final RxBool isPasswordVisible = false.obs;

  @override
  void onReady() {
    super.onReady();
    SharedPreferences.getInstance().then((e) {
      String? email = e.getString('email');
      String? password = e.getString('password');
      if (email != null && password != null) {
        login(email: email, password: password);
      }
    });
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void login({required String email, required String password}) async {
    // 实现Appwrite登录逻辑
    SmartDialog.showLoading();
    try {
      final appwriteManager = Get.find<AppwriteManager>();
      await appwriteManager.login(email: email, password: password);
      SmartDialog.dismiss();
      // 登录成功处理
      Get.offAllNamed('/home');
      SharedPreferences.getInstance().then((e) {
        e.setString('email', email);
        e.setString('password', password);
      });
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast(e.toString());
      rethrow;
    }
  }
}
