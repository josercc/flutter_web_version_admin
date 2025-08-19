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
  void updateEnable(int index, bool value) {
    final document = versionList[index];
    _appwriteManager
        .updateVersionEnable(
      documentId: document.$id,
      isEnable: value,
    )
        .then((_) {
      // 更新本地状态
      versionList[index].data['enable'] = value;
      versionList.refresh();
      Get.snackbar('成功', '版本状态已更新');
    }).catchError((error) {
      Get.snackbar('失败', '更新版本状态出错: $error');
    });
  }

  /// 全量发布 - 清空allow_phones字段
  void fullPublish(String routeName) {
    _appwriteManager
        .publishNewVersion(
      routeName: routeName,
      data: {'description': '全量发布的版本'}, // 可以添加其他描述信息
      isFullPublish: true,
    )
        .then((_) {
      fetchVersionList();
      Get.snackbar('成功', '版本已全量发布');
    }).catchError((error) {
      Get.snackbar('失败', '发布版本出错: $error');
    });
  }

  /// 针对性发布 - 针对特定手机号
  void targetedPublish(String routeName, List<String> targetPhones) {
    _appwriteManager
        .publishNewVersion(
      routeName: routeName,
      data: {'description': '针对性发布的版本'}, // 可以添加其他描述信息
      isFullPublish: false,
      targetPhones: targetPhones,
    )
        .then((_) {
      fetchVersionList();
      Get.snackbar('成功', '版本已针对性发布');
    }).catchError((error) {
      Get.snackbar('失败', '发布版本出错: $error');
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

  /// 测试环境发布 - 针对特定手机号
  void publishToTestEnvironment(String routeName, List<String> targetPhones) {
    _appwriteManager
        .publishNewVersion(
      routeName: routeName,
      data: {'description': '测试环境发布的版本'},
      isFullPublish: false,
      targetPhones: targetPhones,
    )
        .then((_) {
      fetchVersionList();
      Get.snackbar('成功', '版本已发布到测试环境');
    }).catchError((error) {
      Get.snackbar('失败', '发布版本出错: $error');
    });
  }

  /// 正式环境发布 - 全量发布
  void publishToProductionEnvironment(String routeName) {
    _appwriteManager
        .publishNewVersion(
      routeName: routeName,
      data: {'description': '正式环境全量发布的版本'},
      isFullPublish: true,
    )
        .then((_) {
      fetchVersionList();
      Get.snackbar('成功', '版本已发布到正式环境');
    }).catchError((error) {
      Get.snackbar('失败', '发布版本出错: $error');
    });
  }
}
