import 'package:get/get.dart';

import 'appwrite_manager.dart';

/// 基于 Appwrite User Labels 的会话权限状态。
class AuthSession extends GetxService {
  static const adminLabel = 'admin';

  final RxnString userId = RxnString();
  final RxnString email = RxnString();
  final RxList<String> labels = <String>[].obs;
  final RxBool isAdmin = false.obs;

  Future<void> loadFromAppwrite() async {
    // 不用 Account.get()/User.fromMap：服务端 targets.expired 可能为 null，SDK 会崩
    final account = await Get.find<AppwriteManager>().getCurrentAccountMap();
    userId.value = account['\$id']?.toString();
    email.value = account['email']?.toString();

    final rawLabels = account['labels'];
    final parsed = rawLabels is List
        ? rawLabels.map((e) => e.toString()).toList()
        : <String>[];
    labels.assignAll(parsed);
    isAdmin.value = parsed.contains(adminLabel);
  }

  void clear() {
    userId.value = null;
    email.value = null;
    labels.clear();
    isAdmin.value = false;
  }

  /// admin 全开；非 admin 仅允许首页 / 远程调试 / 登录。
  bool canAccess(String route) {
    if (isAdmin.value) return true;
    return route == '/home' ||
        route == '/device-debug' ||
        route == '/login';
  }
}
