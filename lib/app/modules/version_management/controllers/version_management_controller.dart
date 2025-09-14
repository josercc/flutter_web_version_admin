import 'package:appwrite/models.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';

class VersionManagementController extends GetxController {
  final versionList = <Document>[].obs;
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();
  final isLoading = false.obs;

  // 页码相关
  final currentPage = 1.obs;
  final totalPages = 1.obs;
  final totalCount = 0.obs;
  final int pageSize = 20; // 每页20条数据

  // 筛选相关
  final isFiltering = false.obs;
  Map<String, dynamic> currentFilters = {};

  @override
  void onReady() {
    super.onReady();
    loadVersionsByPage(1, pageSize, {});
  }

  /// 根据页码加载版本列表
  Future<void> loadVersionsByPage(
      int page, int limit, Map<String, dynamic> filters) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      currentFilters = filters;

      // 检查是否有手机号筛选
      final hasPhoneFilter = filters.containsKey('phoneNumber') &&
          filters['phoneNumber'].isNotEmpty;

      if (hasPhoneFilter) {
        // 有手机号筛选时，获取所有数据进行客户端筛选
        await _loadWithPhoneFilter(page, limit, filters);
      } else {
        // 没有手机号筛选时，使用正常的服务器分页
        await _loadWithServerPaging(page, limit, filters);
      }
    } catch (error) {
      Get.snackbar('错误', '加载版本列表失败: $error');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// 使用服务器分页加载数据
  Future<void> _loadWithServerPaging(
      int page, int limit, Map<String, dynamic> filters) async {
    final result = await _appwriteManager.getVersionListByPage(
      page: page,
      limit: limit,
      filters: filters,
    );

    versionList.assignAll(result.documents);
    currentPage.value = page;
    totalCount.value = result.total;
    totalPages.value = result.total > 0 ? (result.total / limit).ceil() : 1;
  }

  /// 使用客户端筛选加载数据（用于手机号筛选）
  Future<void> _loadWithPhoneFilter(
      int page, int limit, Map<String, dynamic> filters) async {
    final phoneNumber = filters['phoneNumber'].toString().trim();

    // 获取所有符合其他条件的数据
    final result =
        await _appwriteManager.getAllVersionsForFiltering(filters: filters);

    // 在客户端进行手机号筛选
    final filteredDocuments = result.documents.where((doc) {
      final allowPhones = (doc.data['allow_phones'] as List<dynamic>? ?? []);

      // 如果手机号列表为空，包含在结果中
      if (allowPhones.isEmpty) {
        return true;
      }

      // 检查手机号列表是否包含筛选的手机号（支持部分匹配）
      return allowPhones.any((phone) => phone.toString().contains(phoneNumber));
    }).toList();

    // 对筛选后的结果进行分页
    final totalFiltered = filteredDocuments.length;
    final startIndex = (page - 1) * limit;
    final endIndex = startIndex + limit;

    List<Document> pageDocuments = [];
    if (startIndex < totalFiltered) {
      pageDocuments = filteredDocuments.sublist(
          startIndex, endIndex > totalFiltered ? totalFiltered : endIndex);
    }

    // 更新数据
    versionList.assignAll(pageDocuments);
    currentPage.value = page;
    totalCount.value = totalFiltered;
    totalPages.value = totalFiltered > 0 ? (totalFiltered / limit).ceil() : 1;
  }

  /// 刷新当前页数据
  Future<void> refreshVersions() async {
    await loadVersionsByPage(currentPage.value, pageSize, currentFilters);
  }

  /// 更新版本启用状态
  void updateVersion(
    int index, {
    bool? enable,
    List<String>? allowPhones,
    bool? isStore,
  }) {
    final document = versionList[index];
    _appwriteManager
        .updateVersion(
      documentId: document.$id,
      isEnable: enable,
      allowPhones: allowPhones,
      isStore: isStore,
    )
        .then((_) {
      if (enable != null) {
        versionList[index].data['enable'] = enable;
      }
      if (allowPhones != null) {
        versionList[index].data['allow_phones'] = allowPhones;
      }
      if (isStore != null) {
        versionList[index].data['is_store'] = isStore;
      }
      versionList.refresh();

      // 只在enable状态变更时显示成功提示
      if (enable != null) {
        Get.snackbar('成功', '版本状态已更新');
      }
    }).catchError((error) {
      Get.snackbar('失败', '更新版本状态出错: $error');
    });
  }

  /// 切换到全量模式（清空手机号列表）
  void switchToFullMode(int index) {
    final document = versionList[index];
    _appwriteManager
        .updateVersion(
      documentId: document.$id,
      allowPhones: [], // 清空手机号列表
      isStore: true, // 设置为全量发布
    )
        .then((_) {
      // 更新本地数据
      versionList[index].data['allow_phones'] = [];
      versionList[index].data['is_store'] = true;
      versionList.refresh();
      Get.snackbar('成功', '已切换到全量模式，手机号列表已清空');
    }).catchError((error) {
      Get.snackbar('失败', '切换全量模式失败: $error');
    });
  }

  /// 切换到指定手机号模式
  void switchToTargetMode(int index) {
    final document = versionList[index];
    _appwriteManager
        .updateVersion(
      documentId: document.$id,
      isStore: false, // 设置为指定发布
    )
        .then((_) {
      // 更新本地数据
      versionList[index].data['is_store'] = false;
      versionList.refresh();
      Get.snackbar('成功', '已切换到指定手机号模式');
    }).catchError((error) {
      Get.snackbar('失败', '切换指定手机号模式失败: $error');
    });
  }

  /// 更新版本环境状态
  Future<void> updateVersionEnvironment(
    int index, {
    required bool isTestEnvironment,
  }) async {
    final document = versionList[index];

    try {
      // 根据环境类型设置 is_store 值
      // 测试环境：is_store = false
      // 正式环境：is_store = true
      final newIsStore = !isTestEnvironment;

      await _appwriteManager.updateVersion(
        documentId: document.$id,
        isStore: newIsStore,
      );

      // 更新本地数据
      versionList[index].data['is_store'] = newIsStore;

      versionList.refresh();
    } catch (error) {
      throw Exception('更新版本环境失败: $error');
    }
  }
}
