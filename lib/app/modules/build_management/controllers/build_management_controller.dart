import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../commons/appwrite_manager.dart';

class BuildManagementController extends GetxController {
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();

  // 状态管理
  final RxBool isLoading = false.obs;
  final RxList<Document> buildList = <Document>[].obs;
  final RxList<Document> branchList = <Document>[].obs;
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalCount = 0.obs;

  // 筛选选项
  final RxString selectedPlatform = '全部'.obs;
  final RxString selectedBuildName = '全部'.obs;
  final RxString selectedMelosBranch = '全部'.obs;
  final RxString selectedUnityBranch = '全部'.obs;

  // 筛选选项列表
  final RxList<String> platformOptions = <String>['全部'].obs;
  final RxList<String> buildNameOptions = <String>['全部'].obs;
  final RxList<String> melosBranchOptions = <String>['全部'].obs;
  final RxList<String> unityBranchOptions = <String>['全部'].obs;

  // 分页参数
  final int pageSize = 20;

  // 批量选择状态
  final RxBool isAllSelected = false.obs;
  final RxSet<String> selectedItems = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadFilterOptions();
    loadBuildList();
    loadBranchList();
  }

  /// 加载打包信息列表
  Future<void> loadBuildList() async {
    try {
      isLoading.value = true;

      Map<String, dynamic> filters = {};
      if (selectedPlatform.value != '全部') {
        filters['platform'] = selectedPlatform.value;
      }
      if (selectedBuildName.value != '全部') {
        filters['build_name'] = selectedBuildName.value;
      }
      if (selectedMelosBranch.value != '全部') {
        filters['melos_branch'] = selectedMelosBranch.value;
      }
      if (selectedUnityBranch.value != '全部') {
        filters['unity_branch'] = selectedUnityBranch.value;
      }

      final result = await _appwriteManager.getBuildList(
        page: currentPage.value,
        limit: pageSize,
        filters: filters.isNotEmpty ? filters : null,
      );

      buildList.value = result.documents;
      totalCount.value = result.total;
      totalPages.value = (result.total / pageSize).ceil();
    } catch (e) {
      Get.snackbar(
        '错误',
        '加载打包信息失败: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(Icons.error, color: Colors.red.shade600),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载分支信息列表
  Future<void> loadBranchList() async {
    try {
      final result = await _appwriteManager.getBranchList();
      branchList.value = result.documents;
    } catch (e) {
      // 分支信息加载失败，不影响主要功能
    }
  }

  /// 加载筛选选项
  Future<void> loadFilterOptions() async {
    try {
      // 获取所有打包信息用于提取筛选选项
      final result = await _appwriteManager.getAllBuildsForFiltering();

      // 提取平台选项
      final platforms = <String>{'全部'};
      final buildNames = <String>{'全部'};
      final melosBranches = <String>{'全部'};
      final unityBranches = <String>{'全部'};

      for (final build in result.documents) {
        if (build.data['platform'] != null &&
            build.data['platform'].toString().isNotEmpty) {
          platforms.add(build.data['platform'].toString());
        }
        if (build.data['build_name'] != null &&
            build.data['build_name'].toString().isNotEmpty) {
          buildNames.add(build.data['build_name'].toString());
        }
        if (build.data['melos_branch'] != null &&
            build.data['melos_branch'].toString().isNotEmpty) {
          melosBranches.add(build.data['melos_branch'].toString());
        }
        if (build.data['unity_branch'] != null &&
            build.data['unity_branch'].toString().isNotEmpty) {
          unityBranches.add(build.data['unity_branch'].toString());
        }
      }

      platformOptions.value = platforms.toList()..sort();
      buildNameOptions.value = buildNames.toList()..sort();
      melosBranchOptions.value = melosBranches.toList()..sort();
      unityBranchOptions.value = unityBranches.toList()..sort();
    } catch (e) {
      // 筛选选项加载失败，使用默认值
    }
  }

  /// 刷新数据
  @override
  Future<void> refresh() async {
    currentPage.value = 1;
    await loadFilterOptions();
    await loadBuildList();
    await loadBranchList();
  }

  /// 筛选平台
  void filterByPlatform(String platform) {
    selectedPlatform.value = platform;
    currentPage.value = 1;
    loadBuildList();
  }

  /// 筛选打包名称
  void filterByBuildName(String buildName) {
    selectedBuildName.value = buildName;
    currentPage.value = 1;
    loadBuildList();
  }

  /// 筛选Melos分支
  void filterByMelosBranch(String melosBranch) {
    selectedMelosBranch.value = melosBranch;
    currentPage.value = 1;
    loadBuildList();
  }

  /// 筛选Unity分支
  void filterByUnityBranch(String unityBranch) {
    selectedUnityBranch.value = unityBranch;
    currentPage.value = 1;
    loadBuildList();
  }

  /// 清除所有筛选
  void clearAllFilters() {
    selectedPlatform.value = '全部';
    selectedBuildName.value = '全部';
    selectedMelosBranch.value = '全部';
    selectedUnityBranch.value = '全部';
    currentPage.value = 1;
    loadBuildList();
  }

  /// 全选/取消全选
  void toggleSelectAll() {
    if (isAllSelected.value) {
      // 取消全选
      selectedItems.clear();
      isAllSelected.value = false;
    } else {
      // 全选当前页面的所有项目
      selectedItems.clear();
      for (final build in buildList) {
        selectedItems.add(build.$id);
      }
      isAllSelected.value = true;
    }
  }

  /// 切换单个项目的选择状态
  void toggleItemSelection(String itemId) {
    if (selectedItems.contains(itemId)) {
      selectedItems.remove(itemId);
    } else {
      selectedItems.add(itemId);
    }

    // 更新全选状态
    isAllSelected.value = selectedItems.length == buildList.length;
  }

  /// 批量删除选中的项目
  Future<void> deleteSelectedItems() async {
    if (selectedItems.isEmpty) {
      Get.snackbar(
        '提示',
        '请先选择要删除的项目',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade100,
        colorText: Colors.orange.shade800,
        icon: Icon(Icons.warning, color: Colors.orange.shade600),
      );
      return;
    }

    try {
      isLoading.value = true;

      // 批量删除
      await _appwriteManager.deleteMultipleBuildInfo(selectedItems.toList());

      Get.snackbar(
        '成功',
        '已删除 ${selectedItems.length} 个打包信息',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(Icons.check_circle, color: Colors.green.shade600),
      );

      // 清空选择状态
      selectedItems.clear();
      isAllSelected.value = false;

      // 刷新数据
      await refresh();
    } catch (e) {
      Get.snackbar(
        '错误',
        '批量删除失败: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(Icons.error, color: Colors.red.shade600),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 分页
  void goToPage(int page) {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page;
      loadBuildList();
    }
  }

  /// 上一页
  void previousPage() {
    if (currentPage.value > 1) {
      goToPage(currentPage.value - 1);
    }
  }

  /// 下一页
  void nextPage() {
    if (currentPage.value < totalPages.value) {
      goToPage(currentPage.value + 1);
    }
  }

  /// 添加新的打包信息
  Future<void> addBuildInfo({
    required String platform,
    required String buildName,
    required String buildNumber,
    required String melosBranch,
    required String unityBranch,
    required String unityCommitId,
    required String unityBuildVersion,
  }) async {
    try {
      isLoading.value = true;

      await _appwriteManager.createBuildInfo(
        platform: platform,
        buildName: buildName,
        buildNumber: buildNumber,
        melosBranch: melosBranch,
        unityBranch: unityBranch,
        unityCommitId: unityCommitId,
        unityBuildVersion: unityBuildVersion,
      );

      Get.snackbar(
        '成功',
        '打包信息添加成功',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(Icons.check_circle, color: Colors.green.shade600),
      );

      await refresh();
    } catch (e) {
      Get.snackbar(
        '错误',
        '添加打包信息失败: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(Icons.error, color: Colors.red.shade600),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 删除打包信息
  Future<void> deleteBuildInfo(String documentId) async {
    try {
      isLoading.value = true;

      await _appwriteManager.deleteBuildInfo(documentId);

      Get.snackbar(
        '成功',
        '打包信息删除成功',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(Icons.check_circle, color: Colors.green.shade600),
      );

      await refresh();
    } catch (e) {
      Get.snackbar(
        '错误',
        '删除打包信息失败: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(Icons.error, color: Colors.red.shade600),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// 更新打包信息
  Future<void> updateBuildInfo({
    required String documentId,
    String? platform,
    String? buildName,
    String? buildNumber,
    String? melosBranch,
    String? unityBranch,
    String? unityCommitId,
    String? unityBuildVersion,
  }) async {
    try {
      isLoading.value = true;

      await _appwriteManager.updateBuildInfo(
        documentId: documentId,
        platform: platform,
        buildName: buildName,
        buildNumber: buildNumber,
        melosBranch: melosBranch,
        unityBranch: unityBranch,
        unityCommitId: unityCommitId,
        unityBuildVersion: unityBuildVersion,
      );

      Get.snackbar(
        '成功',
        '打包信息更新成功',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.shade100,
        colorText: Colors.green.shade800,
        icon: Icon(Icons.check_circle, color: Colors.green.shade600),
      );

      await refresh();
    } catch (e) {
      Get.snackbar(
        '错误',
        '更新打包信息失败: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
        icon: Icon(Icons.error, color: Colors.red.shade600),
      );
    } finally {
      isLoading.value = false;
    }
  }
}
