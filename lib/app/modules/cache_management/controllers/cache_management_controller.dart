import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter_web_version_admin/app/commons/appwrite_manager.dart';
import 'package:get/get.dart';

class CacheManagementController extends GetxController {
  final cacheList = <Document>[].obs;
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

  // 多选相关
  final isMultiSelectMode = false.obs;
  final selectedItems = <String>{}.obs;

  // 动态筛选选项
  final platformOptions = <String>[].obs;
  final configurationOptions = <String>[].obs;
  final libraryOptions = <String>[].obs;
  final typeOptions = <String>[].obs;
  final branchOptions = <String>[].obs;

  // 过滤后的筛选选项（基于当前筛选条件）
  final filteredPlatformOptions = <String>[].obs;
  final filteredConfigurationOptions = <String>[].obs;
  final filteredLibraryOptions = <String>[].obs;
  final filteredTypeOptions = <String>[].obs;
  final filteredBranchOptions = <String>[].obs;

  // 原始数据缓存
  final List<Document> _allDocuments = [];

  @override
  void onReady() {
    super.onReady();
    loadCacheListByPage(1, pageSize, {});
    loadFilterOptions();
  }

  /// 加载筛选选项
  Future<void> loadFilterOptions() async {
    try {
      // 获取所有数据来提取筛选选项
      final result = await _appwriteManager.databases.listDocuments(
        databaseId: '67d25037000787a18b45',
        collectionId: '67d25051001d789a270f',
        queries: [
          Query.limit(1000), // 获取足够多的数据来提取选项
        ],
      );

      // 保存原始数据
      _allDocuments.assignAll(result.documents);

      // 提取不重复的选项
      final Set<String> platforms = {};
      final Set<String> configurations = {};
      final Set<String> libraries = {};
      final Set<String> types = {};
      final Set<String> branches = {};

      for (final document in result.documents) {
        final data = document.data;

        if (data['platform'] != null) {
          platforms.add(data['platform'].toString());
        }
        if (data['configuration'] != null) {
          configurations.add(data['configuration'].toString());
        }
        if (data['library'] != null) {
          libraries.add(data['library'].toString());
        }
        if (data['type'] != null) {
          types.add(data['type'].toString());
        }
        if (data['branch'] != null) {
          branches.add(data['branch'].toString());
        }
      }

      // 更新选项列表
      platformOptions.assignAll(['全部', ...platforms.toList()..sort()]);
      configurationOptions
          .assignAll(['全部', ...configurations.toList()..sort()]);
      libraryOptions.assignAll(['全部', ...libraries.toList()..sort()]);
      typeOptions.assignAll(['全部', ...types.toList()..sort()]);
      branchOptions.assignAll(['全部', ...branches.toList()..sort()]);

      // 初始化过滤后的选项
      updateFilteredOptions({});
    } catch (error) {
      // 如果获取失败，使用默认选项
      platformOptions.assignAll(
          ['全部', 'iOS', 'Android', 'Web', 'Windows', 'macOS', 'Linux']);
      configurationOptions.assignAll(['全部', 'debug', 'release', 'profile']);
      libraryOptions.assignAll(['全部', 'flutter', 'native', 'hybrid']);
      typeOptions.assignAll(['全部', 'hotfix', 'feature', 'release', 'patch']);

      // 初始化过滤后的选项
      updateFilteredOptions({});
    }
  }

  /// 更新过滤后的筛选选项
  void updateFilteredOptions(Map<String, dynamic> currentFilters) {
    // 不再基于当前筛选条件过滤选项，而是保持所有选项可见
    // 这样用户可以看到所有可用的选项，体验更好
    
    // 从所有数据中提取选项（不进行过滤）
    final Set<String> allPlatforms = {};
    final Set<String> allConfigurations = {};
    final Set<String> allLibraries = {};
    final Set<String> allTypes = {};
    final Set<String> allBranches = {};

    for (final document in _allDocuments) {
      final data = document.data;

      if (data['platform'] != null) {
        allPlatforms.add(data['platform'].toString());
      }
      if (data['configuration'] != null) {
        allConfigurations.add(data['configuration'].toString());
      }
      if (data['library'] != null) {
        allLibraries.add(data['library'].toString());
      }
      if (data['type'] != null) {
        allTypes.add(data['type'].toString());
      }
      if (data['branch'] != null) {
        allBranches.add(data['branch'].toString());
      }
    }

    // 更新选项列表，保持所有选项可见
    filteredPlatformOptions
        .assignAll(['全部', ...allPlatforms.toList()..sort()]);
    filteredConfigurationOptions
        .assignAll(['全部', ...allConfigurations.toList()..sort()]);
    filteredLibraryOptions
        .assignAll(['全部', ...allLibraries.toList()..sort()]);
    filteredTypeOptions.assignAll(['全部', ...allTypes.toList()..sort()]);
    filteredBranchOptions
        .assignAll(['全部', ...allBranches.toList()..sort()]);
  }

  /// 根据页码加载缓存列表
  Future<void> loadCacheListByPage(
      int page, int limit, Map<String, dynamic> filters) async {
    if (isLoading.value) return;

    try {
      isLoading.value = true;
      currentFilters = filters;

      // 更新过滤后的选项
      updateFilteredOptions(filters);

      List<String> queries = [
        Query.orderDesc('\$createdAt'),
      ];

      // 检查是否有筛选条件
      final hasFilters = filters.isNotEmpty &&
          filters.values.any((value) =>
              value != null && value != '全部' && value.toString().isNotEmpty);

      if (hasFilters) {
        // 有筛选条件时，获取所有匹配的数据进行客户端分页
        queries.add(Query.limit(1000)); // 获取足够多的数据
      } else {
        // 没有筛选条件时，使用服务器分页
        queries.addAll([
          Query.limit(limit),
          Query.offset((page - 1) * limit),
        ]);
      }

      // 添加筛选条件
      if (filters.isNotEmpty) {
        if (filters.containsKey('platform') && filters['platform'] != '全部') {
          queries.add(Query.equal('platform', filters['platform']));
        }

        if (filters.containsKey('type') && filters['type'] != '全部') {
          queries.add(Query.equal('type', filters['type']));
        }

        if (filters.containsKey('configuration') &&
            filters['configuration'] != '全部') {
          queries.add(Query.equal('configuration', filters['configuration']));
        }

        if (filters.containsKey('library') && filters['library'] != '全部') {
          queries.add(Query.equal('library', filters['library']));
        }

        if (filters.containsKey('branch') && filters['branch'] != '全部') {
          queries.add(Query.equal('branch', filters['branch']));
        }
      }

      final result = await _appwriteManager.databases.listDocuments(
        databaseId: '67d25037000787a18b45',
        collectionId: '67d25051001d789a270f',
        queries: queries,
      );

      if (hasFilters) {
        // 有筛选条件时，进行客户端分页
        final allDocuments = result.documents;
        final totalFiltered = allDocuments.length;
        final startIndex = (page - 1) * limit;
        final endIndex = startIndex + limit;

        List<Document> pageDocuments = [];
        if (startIndex < totalFiltered) {
          pageDocuments = allDocuments.sublist(
              startIndex, endIndex > totalFiltered ? totalFiltered : endIndex);
        }

        cacheList.assignAll(pageDocuments);
        currentPage.value = page;
        totalCount.value = totalFiltered;
        totalPages.value =
            totalFiltered > 0 ? (totalFiltered / limit).ceil() : 1;
      } else {
        // 没有筛选条件时，使用服务器分页结果
        cacheList.assignAll(result.documents);
        currentPage.value = page;
        totalCount.value = result.total;
        totalPages.value = result.total > 0 ? (result.total / limit).ceil() : 1;
      }
    } catch (error) {
      Get.snackbar('错误', '加载缓存列表失败: $error');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// 刷新当前页数据
  Future<void> refreshCacheList() async {
    await loadCacheListByPage(currentPage.value, pageSize, currentFilters);
  }

  /// 删除缓存记录
  Future<void> deleteCacheRecord(String documentId, String fileId) async {
    try {
      // 1. 先删除文件库中的文件
      if (fileId.isNotEmpty) {
        await _appwriteManager.storage.deleteFile(
          bucketId: '67d26a1b002de170d9a0',
          fileId: fileId,
        );
      }

      // 2. 再删除数据库记录
      await _appwriteManager.databases.deleteDocument(
        databaseId: '67d25037000787a18b45',
        collectionId: '67d25051001d789a270f',
        documentId: documentId,
      );

      // 3. 刷新列表
      await refreshCacheList();

      Get.snackbar('成功', '缓存记录已删除');
    } catch (error) {
      Get.snackbar('失败', '删除缓存记录失败: $error');
      rethrow;
    }
  }

  /// 切换多选模式
  void toggleMultiSelectMode() {
    isMultiSelectMode.value = !isMultiSelectMode.value;
    if (!isMultiSelectMode.value) {
      selectedItems.clear();
    }
  }

  /// 切换单个项目的选中状态
  void toggleItemSelection(String documentId) {
    if (selectedItems.contains(documentId)) {
      selectedItems.remove(documentId);
    } else {
      selectedItems.add(documentId);
    }
  }

  /// 全选当前页
  void selectAllCurrentPage() {
    for (final document in cacheList) {
      selectedItems.add(document.$id);
    }
  }

  /// 取消全选
  void clearSelection() {
    selectedItems.clear();
  }

  /// 获取选中项目的数量
  int get selectedCount => selectedItems.length;

  /// 检查是否全选
  bool get isAllSelected {
    return cacheList.isNotEmpty && selectedItems.length == cacheList.length;
  }

  /// 批量删除选中的记录
  Future<void> deleteSelectedRecords() async {
    if (selectedItems.isEmpty) return;

    try {
      final List<Future<void>> deleteTasks = [];

      for (final documentId in selectedItems) {
        // 找到对应的文档
        final document = cacheList.firstWhere((doc) => doc.$id == documentId);
        final fileId = document.data['file_id'] ?? '';

        // 创建删除任务
        deleteTasks.add(_deleteSingleRecord(documentId, fileId));
      }

      // 等待所有删除任务完成
      await Future.wait(deleteTasks);

      // 记录删除数量
      final deletedCount = selectedItems.length;

      // 清空选择并刷新列表
      selectedItems.clear();
      await refreshCacheList();

      Get.snackbar('成功', '已删除 $deletedCount 条缓存记录');
    } catch (error) {
      Get.snackbar('失败', '批量删除失败: $error');
      rethrow;
    }
  }

  /// 删除单个记录（内部方法）
  Future<void> _deleteSingleRecord(String documentId, String fileId) async {
    // 1. 先删除文件库中的文件
    if (fileId.isNotEmpty) {
      await _appwriteManager.storage.deleteFile(
        bucketId: '67d26a1b002de170d9a0',
        fileId: fileId,
      );
    }

    // 2. 再删除数据库记录
    await _appwriteManager.databases.deleteDocument(
      databaseId: '67d25037000787a18b45',
      collectionId: '67d25051001d789a270f',
      documentId: documentId,
    );
  }
}
