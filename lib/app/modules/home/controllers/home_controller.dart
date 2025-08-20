import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final versionList = <Document>[].obs;
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();
  final isLoading = false.obs;
  
  // 分页相关
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  String? lastDocumentId;
  final int pageSize = 20; // 每页加载数量
  
  // 筛选相关
  final isFiltering = false.obs;
  Map<String, dynamic> currentFilters = {};

  @override
  void onReady() {
    super.onReady();
    loadAllVersions();
  }

  /// 加载版本列表（首次加载或刷新）
  Future<void> loadAllVersions({bool refresh = false}) async {
    if (refresh) {
      // 刷新时重置分页状态
      lastDocumentId = null;
      hasMore.value = true;
      versionList.clear();
    }
    
    if (isLoading.value) return;
    
    try {
      isLoading.value = true;
      final result = await _appwriteManager.getVersionList(
        limit: pageSize,
        offset: lastDocumentId,
        filters: currentFilters,
      );
      
      if (refresh) {
        versionList.assignAll(result.documents);
      } else {
        versionList.addAll(result.documents);
      }
      
      // 更新分页状态
      if (result.documents.length < pageSize) {
        hasMore.value = false;
      } else {
        hasMore.value = true;
        if (result.documents.isNotEmpty) {
          lastDocumentId = result.documents.last.$id;
        }
      }
      
    } catch (error) {
      Get.snackbar('错误', '加载版本列表失败: $error');
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载更多版本
  Future<void> loadMoreVersions() async {
    if (!hasMore.value || isLoadingMore.value || isLoading.value) return;
    
    try {
      isLoadingMore.value = true;
      final result = await _appwriteManager.getVersionList(
        limit: pageSize,
        offset: lastDocumentId,
        filters: currentFilters,
      );
      
      versionList.addAll(result.documents);
      
      // 更新分页状态
      if (result.documents.length < pageSize) {
        hasMore.value = false;
      } else {
        if (result.documents.isNotEmpty) {
          lastDocumentId = result.documents.last.$id;
        }
      }
      
    } catch (error) {
      Get.snackbar('错误', '加载更多失败: $error');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// 刷新版本列表
  Future<void> refreshVersions() async {
    await loadAllVersions(refresh: true);
  }

  /// 根据条件筛选版本列表
  Future<void> filterVersions(Map<String, dynamic> filters) async {
    try {
      currentFilters = filters;
      isFiltering.value = filters.isNotEmpty;
      
      // 重新加载数据
      await loadAllVersions(refresh: true);
    } catch (error) {
      Get.snackbar('错误', '筛选版本列表失败: $error');
      rethrow;
    }
  }

  /// 清空筛选条件
  Future<void> clearFilters() async {
    currentFilters.clear();
    isFiltering.value = false;
    
    // 重新加载数据
    await loadAllVersions(refresh: true);
  }

  /// 获取版本列表（兼容旧方法名）
  void fetchVersionList() {
    loadAllVersions();
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

  /// 获取发布类型文本
  String getPublishTypeText(Document document) {
    final isStore = document.data['is_store'] ?? false;
    final allowPhones = document.data['allow_phones'] as List<dynamic>? ?? [];

    if (isStore) {
      return '全量发布';
    } else if (allowPhones.isEmpty) {
      return '未指定发布范围';
    } else {
      return '针对性发布 (${allowPhones.length}个手机号)';
    }
  }

  /// 获取发布类型颜色
  Color getPublishTypeColor(Document document) {
    final isStore = document.data['is_store'] ?? false;
    final allowPhones = document.data['allow_phones'] as List<dynamic>? ?? [];

    if (isStore) {
      return Colors.green;
    } else if (allowPhones.isEmpty) {
      return Colors.grey;
    } else {
      return Colors.blue;
    }
  }

  /// 获取发布环境类型
  String getEnvironmentType(Document document) {
    final isEnable = document.data['enable'] ?? false;
    final isStore = document.data['is_store'] ?? false;

    if (!isEnable) {
      return '未发布';
    } else if (isStore) {
      return '正式环境';
    } else {
      return '测试环境';
    }
  }

  /// 获取发布环境颜色
  Color getEnvironmentColor(Document document) {
    final isEnable = document.data['enable'] ?? false;
    final isStore = document.data['is_store'] ?? false;

    if (!isEnable) {
      return Colors.grey;
    } else if (isStore) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
  }

  /// 获取卡片背景色
  Color getCardBackgroundColor(Document document) {
    final color = getEnvironmentColor(document);

    if (color == Colors.grey) {
      return Colors.grey.shade100;
    } else if (color == Colors.green) {
      return Colors.green.shade50;
    } else {
      return Colors.blue.shade50;
    }
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
