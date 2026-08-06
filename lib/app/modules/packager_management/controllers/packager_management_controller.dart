import 'package:appwrite/models.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';

class PackagerManagementController extends GetxController {
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();

  final packagerList = <Document>[].obs;
  final isLoading = false.obs;
  final updatingIds = <String>{}.obs;

  @override
  void onReady() {
    super.onReady();
    loadPackagerList();
  }

  Future<void> loadPackagerList() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      final result = await _appwriteManager.getPackagerList();
      packagerList.assignAll(result.documents);
    } catch (error) {
      Get.snackbar('错误', '加载打包机列表失败: $error');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshPackagerList() async {
    await loadPackagerList();
  }

  Future<void> toggleActive(int index) async {
    if (index < 0 || index >= packagerList.length) return;

    final document = packagerList[index];
    final documentId = document.$id;
    if (updatingIds.contains(documentId)) return;

    final currentActive = document.data['active'] == true;
    final nextActive = !currentActive;

    try {
      updatingIds.add(documentId);
      await _appwriteManager.updatePackagerActive(
        documentId: documentId,
        active: nextActive,
      );
      packagerList[index].data['active'] = nextActive;
      packagerList.refresh();
      Get.snackbar('成功', nextActive ? '已启用打包机' : '已停用打包机');
    } catch (error) {
      Get.snackbar('失败', '更新状态失败: $error');
    } finally {
      updatingIds.remove(documentId);
    }
  }

  int get activeCount =>
      packagerList.where((doc) => doc.data['active'] == true).length;

  int get onlineCount =>
      packagerList.where((doc) => doc.data['online'] == true).length;
}
