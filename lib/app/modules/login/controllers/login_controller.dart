import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  final RxBool isPasswordVisible = false.obs;

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void login({required String email, required String password}) async {
    // 实现Appwrite登录逻辑
    try {
      final client = Client()
          .setEndpoint('https://your-appwrite-endpoint')
          .setProject('your-project-id');

      final account = Account(client);
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      // 登录成功处理
      Get.offAllNamed('/home');
    } catch (e) {
      Get.snackbar('登录失败', e.toString());
    }
  }
}
