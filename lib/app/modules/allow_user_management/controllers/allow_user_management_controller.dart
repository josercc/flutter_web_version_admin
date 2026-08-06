import 'package:flutter/material.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:flutter_web_version_admin/app/commons/error_dialog.dart';
import 'package:get/get.dart';

class AllowUserManagementController extends GetxController {
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();

  final TextEditingController userIdController = TextEditingController();

  final allowUserIds = <String>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final searchKeyword = ''.obs;

  List<String> get filteredUserIds {
    final keyword = searchKeyword.value.trim().toLowerCase();
    if (keyword.isEmpty) return allowUserIds.toList();
    return allowUserIds
        .where((id) => id.toLowerCase().contains(keyword))
        .toList();
  }

  @override
  void onReady() {
    super.onReady();
    loadAllowUserIds();
  }

  @override
  void onClose() {
    userIdController.dispose();
    super.onClose();
  }

  Future<void> loadAllowUserIds() async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      final ids = await _appwriteManager.getAllowUserIds();
      allowUserIds.assignAll(ids);
    } catch (error, stackTrace) {
      await showCopyableErrorDialog(
        title: '加载失败',
        context: '加载允许用户列表失败',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshAllowUserIds() async {
    await loadAllowUserIds();
  }

  Future<void> addUserId() async {
    final userId = userIdController.text.trim();
    if (userId.isEmpty) {
      Get.snackbar('提示', '请输入用户 ID');
      return;
    }

    if (allowUserIds.contains(userId)) {
      Get.snackbar('提示', '该用户 ID 已存在');
      return;
    }

    final next = [...allowUserIds, userId];
    final success = await _saveAllowUserIds(next);
    if (success) {
      userIdController.clear();
      Get.snackbar('成功', '已添加用户 ID');
    }
  }

  Future<void> removeUserId(String userId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要移除用户 ID「$userId」吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final next = allowUserIds.where((id) => id != userId).toList();
    final success = await _saveAllowUserIds(next);
    if (success) {
      Get.snackbar('成功', '已删除用户 ID');
    }
  }

  Future<bool> _saveAllowUserIds(List<String> next) async {
    if (isSaving.value) return false;

    try {
      isSaving.value = true;
      await _appwriteManager.updateAllowUserIds(next);
      allowUserIds.assignAll(next);
      return true;
    } catch (error, stackTrace) {
      await showCopyableErrorDialog(
        title: '更新失败',
        context: '更新允许用户列表失败',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }
}
