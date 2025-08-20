import 'package:appwrite/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final versionList = <Document>[].obs;
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();

  @override
  void onReady() {
    super.onReady();
    fetchVersionList();
  }

  /// 获取版本列表
  void fetchVersionList() {
    _appwriteManager.getVersionList().then((value) {
      versionList.value = value.documents;
    });
  }

  /// 更新版本启用状态
  void updateVersion(
    int index, {
    bool? enable,
    List<String>? allowPhones,
    String? isStore,
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
      } else if (allowPhones != null) {
        versionList[index].data['allow_phones'] = allowPhones;
      } else if (isStore != null) {
        versionList[index].data['is_store'] = isStore;
      }
      versionList.refresh();
      Get.snackbar('成功', '版本状态已更新');
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
}
