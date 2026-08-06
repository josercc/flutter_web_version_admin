import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../../../commons/appwrite_manager.dart';
import '../../../commons/rate_limit_handler.dart';

class LogManagementController extends GetxController {
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();
  static const String _databaseId = '677f63ac003be28fb635';
  static const String _appLoadCollectionId = '677f63b900033b03d59f';
  static const String _logCollectionId = '6784aec8003d415d53d7';
  static const String _userLogCollectionId = '677f71c9000566bbcf38';
  static const String _sentryLogCollectionId = '6784a4960004fd640ddf';
  static const String _storageBucketId = '6787201a00376ab5d134';

  late RateLimitHandler _rateLimitHandler;

  // 输入控件
  final TextEditingController searchUserIdController = TextEditingController();
  final TextEditingController searchDeviceIdController =
      TextEditingController();
  final TextEditingController searchSentryIdController =
      TextEditingController();
  final TextEditingController searchTitleController = TextEditingController();
  final TextEditingController searchDaysController = TextEditingController();

  // 搜索相关
  final RxString searchUserId = ''.obs;
  final RxString searchDeviceId = ''.obs;
  final RxString searchSentryId = ''.obs;
  final RxString searchTitle = ''.obs;
  final RxInt searchDaysBefore = 0.obs;
  final RxBool isSearchCollapsed = false.obs;

  // 分页相关
  final RxInt currentPage = 1.obs;
  final RxInt totalPages = 1.obs;
  final RxInt totalCount = 0.obs;
  final int pageSize = 20;

  // 数据列表
  final RxList<Document> appLoads = <Document>[].obs;
  final RxList<Document> userLogs = <Document>[].obs;
  final RxList<Document> sentryLogs = <Document>[].obs;
  final RxList<String> cleanLogs = <String>[].obs;

  // 加载状态
  final RxBool isLoading = false.obs;
  final RxBool isCleaning = false.obs;
  final RxBool isCleanFinished = false.obs;
  final RxBool hasSearched = false.obs;

  // 清理进度
  final RxInt cleanCurrentIndex = 0.obs;
  final RxInt cleanTotalCount = 0.obs;

  // 选中的启动记录
  final Rx<Document?> selectedAppLoad = Rx<Document?>(null);

  // 日志滚动控制器
  final ScrollController logScrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    // 初始化速率限制处理器
    _rateLimitHandler = RateLimitHandler(logCallback: _appendCleanLog);
    _appwriteManager.setRateLimitHandler(_rateLimitHandler);
  }

  /// 尝试从 AppwriteException 中提取速率限制信息
  /// 返回提取到的 RateLimitInfo，如果提取失败则返回 null
  RateLimitInfo? _tryExtractRateLimitFromException(
    AppwriteException e,
    ApiEndpointType endpointType,
  ) {
    final headers = <String, String>{};

    try {
      // 尝试多种方式从异常中提取 header 信息

      // 方式1: 尝试从 response 中提取 headers
      final response = e.response;
      if (response != null) {
        try {
          if (response is Map) {
            final responseMap = response as Map;

            // 方式1.1: 尝试从 response['headers'] 获取
            final responseHeaders = responseMap['headers'];
            if (responseHeaders != null && responseHeaders is Map) {
              final headersMap = responseHeaders as Map;
              headersMap.forEach((key, value) {
                if (key is String && value != null) {
                  headers[key.toLowerCase()] = value.toString();
                }
              });
            }

            // 方式1.2: 尝试从 response 的直接属性中获取（某些SDK可能这样存储）
            responseMap.forEach((key, value) {
              if (key is String &&
                  (key.toLowerCase().contains('header') ||
                      key.toLowerCase().startsWith('x-ratelimit'))) {
                if (value is Map) {
                  final valueMap = value as Map;
                  valueMap.forEach((k, v) {
                    if (k is String && v != null) {
                      headers[k.toLowerCase()] = v.toString();
                    }
                  });
                } else if (value != null) {
                  headers[key.toLowerCase()] = value.toString();
                }
              }
            });
          }
        } catch (_) {
          // 忽略单个提取方式的错误
        }
      }

      // 方式2: 尝试直接从异常对象中提取（使用动态访问）
      try {
        // 尝试访问可能存在的 headers 属性
        final dynamic exception = e;
        if (exception.headers != null && exception.headers is Map) {
          final headersMap = exception.headers as Map;
          headersMap.forEach((key, value) {
            if (key is String && value != null) {
              headers[key.toLowerCase()] = value.toString();
            }
          });
        }
      } catch (_) {
        // 忽略，该属性可能不存在
      }

      // 尝试解析速率限制信息
      final rateLimitInfo = RateLimitInfo.fromHeaders(headers);
      if (rateLimitInfo != null) {
        // 更新速率限制信息（showLog=false，因为下面会显示更详细的错误信息）
        _rateLimitHandler.updateRateLimit(endpointType, rateLimitInfo,
            showLog: false);
        final typeName = _getEndpointTypeName(endpointType);
        _appendCleanLog(
            '[$typeName] 从错误响应中提取到限速信息: 剩余 ${rateLimitInfo.remaining}/${rateLimitInfo.limit} 次，重置时间: ${_formatDateTime(rateLimitInfo.resetDateTime)}');
        return rateLimitInfo;
      } else if (headers.isNotEmpty) {
        // 如果提取到了headers但没有找到速率限制字段，记录日志用于调试
        final typeName = _getEndpointTypeName(endpointType);
        _appendCleanLog(
            '[$typeName] 从响应中提取到headers但未找到速率限制字段: ${headers.keys.join(", ")}');
      }
    } catch (ex) {
      // 忽略提取错误
      final typeName = _getEndpointTypeName(endpointType);
      _appendCleanLog('[$typeName] 无法从异常中提取速率限制信息: ${ex.toString()}');
    }
    return null;
  }

  /// 从 AppwriteManager 获取限速信息并更新到 RateLimitHandler
  /// 在成功响应后调用此方法来更新限速信息
  void _updateRateLimitFromResponse(ApiEndpointType endpointType) {
    final appwriteRateLimit = _appwriteManager.rateLimit;
    if (appwriteRateLimit != null) {
      // 将 AppwriteRateLimit 转换为 RateLimitInfo
      final rateLimitInfo = RateLimitInfo(
        limit: appwriteRateLimit.limit,
        remaining: appwriteRateLimit.remaining,
        resetTime: appwriteRateLimit.reset,
      );
      // 更新限速信息并显示日志（showLog=true 会显示限速信息）
      _rateLimitHandler.updateRateLimit(endpointType, rateLimitInfo,
          showLog: true);
    }
  }

  /// 获取接口类型名称
  String _getEndpointTypeName(ApiEndpointType type) {
    switch (type) {
      case ApiEndpointType.deleteDocument:
        return '删除文档';
      case ApiEndpointType.deleteFile:
        return '删除文件';
      case ApiEndpointType.listDocuments:
        return '查询文档';
      case ApiEndpointType.createDocument:
        return '创建文档';
      case ApiEndpointType.updateDocument:
        return '更新文档';
      case ApiEndpointType.other:
        return '其他接口';
    }
  }

  @override
  void onReady() {
    super.onReady();
    // 默认加载第一页数据
    loadAppLoadsByPage(page: 1);
  }

  @override
  void onClose() {
    searchUserIdController.dispose();
    searchDeviceIdController.dispose();
    searchSentryIdController.dispose();
    searchTitleController.dispose();
    searchDaysController.dispose();
    logScrollController.dispose();
    super.onClose();
  }

  /// 分页加载启动记录
  Future<void> loadAppLoadsByPage({required int page}) async {
    if (isLoading.value) return;

    isLoading.value = true;
    hasSearched.value = true;

    try {
      // 重置状态
      appLoads.clear();
      userLogs.clear();
      sentryLogs.clear();
      selectedAppLoad.value = null;

      // 构建查询
      final List<String> queries = [Query.orderDesc('time')];
      Set<String>? filteredAppLoadIds;

      // 设备ID筛选
      if (searchDeviceId.value.isNotEmpty) {
        queries.add(Query.equal('deviceId', searchDeviceId.value));
      }

      // 按时间筛选：查询指定天数之前的数据
      if (searchDaysBefore.value > 0) {
        final DateTime cutoff =
            DateTime.now().subtract(Duration(days: searchDaysBefore.value));
        queries.add(Query.lessThan('time', cutoff.toIso8601String()));
      }

      // 用户ID筛选（从用户日志表获取关联的启动ID）
      if (searchUserId.value.isNotEmpty) {
        // 检查查询文档的速率限制
        await _rateLimitHandler.checkAndWaitIfNeeded(
          type: ApiEndpointType.listDocuments,
          minRemaining: 1,
        );
        final userStartResults = await _appwriteManager.databases.listDocuments(
          databaseId: _databaseId,
          collectionId: _userLogCollectionId,
          queries: [Query.equal('userId', searchUserId.value)],
        );
        // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
        _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

        filteredAppLoadIds = userStartResults.documents
            .map((doc) => doc.data['appLoadId'] as String)
            .toSet();
        userLogs.value = userStartResults.documents;
      }

      // Sentry筛选（从Sentry表获取关联的启动ID）
      if (searchSentryId.value.isNotEmpty || searchTitle.value.isNotEmpty) {
        final List<String> sentryQueries = [];

        if (searchSentryId.value.isNotEmpty) {
          sentryQueries.add(Query.equal('sentryId', searchSentryId.value));
        }
        if (searchTitle.value.isNotEmpty) {
          sentryQueries.add(Query.search('title', searchTitle.value));
        }

        // 检查查询文档的速率限制
        await _rateLimitHandler.checkAndWaitIfNeeded(
          type: ApiEndpointType.listDocuments,
          minRemaining: 1,
        );
        final sentryResults = await _appwriteManager.databases.listDocuments(
          databaseId: _databaseId,
          collectionId: _sentryLogCollectionId,
          queries: sentryQueries,
        );
        // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
        _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

        final sentryAppLoadIds = sentryResults.documents
            .map((doc) => doc.data['appLoadId'] as String)
            .toSet();
        sentryLogs.value = sentryResults.documents;

        if (filteredAppLoadIds == null) {
          filteredAppLoadIds = sentryAppLoadIds;
        } else {
          filteredAppLoadIds =
              filteredAppLoadIds.intersection(sentryAppLoadIds);
        }
      }

      // 如果有跨表筛选结果，直接用ID列表过滤
      if (filteredAppLoadIds != null) {
        if (filteredAppLoadIds.isEmpty) {
          // 没有匹配结果
          totalCount.value = 0;
          totalPages.value = 1;
          currentPage.value = 1;
          appLoads.clear();
          return;
        }
        queries.add(Query.equal('\$id', filteredAppLoadIds.toList()));
      }

      // 分页
      final targetPage = page < 1 ? 1 : page;
      queries.addAll([
        Query.limit(pageSize),
        Query.offset((targetPage - 1) * pageSize),
      ]);

      // 查询启动记录表
      // 检查查询文档的速率限制
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      final result = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _appLoadCollectionId,
        queries: queries,
      );
      // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      appLoads.value = result.documents;
      currentPage.value = targetPage;
      totalCount.value = result.total;
      totalPages.value =
          result.total > 0 ? (result.total / pageSize).ceil() : 1;
    } catch (e) {
      Get.snackbar('错误', '搜索失败: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// 搜索启动记录
  Future<void> searchAppLoads() async {
    await loadAppLoadsByPage(page: 1);
  }

  /// 选择启动记录并获取详细信息
  Future<void> selectAppLoad(Document appLoad) async {
    selectedAppLoad.value = appLoad;

    try {
      // 获取该启动记录的用户日志
      // 检查查询文档的速率限制
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      DocumentList userLogResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _userLogCollectionId,
        queries: [Query.equal('appLoadId', appLoad.$id)],
      );
      // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      // 获取该启动记录的sentry日志
      // 检查查询文档的速率限制
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      DocumentList sentryLogResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sentryLogCollectionId,
        queries: [Query.equal('appLoadId', appLoad.$id)],
      );
      // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      // 更新相关日志
      userLogs.value = userLogResults.documents;
      sentryLogs.value = sentryLogResults.documents;

      // 触发UI更新以显示详细日志
    } catch (e) {
      Get.snackbar('错误', '获取详细信息失败: ${e.toString()}');
    }
  }

  /// 清空搜索
  Future<void> clearSearch() async {
    searchUserId.value = '';
    searchDeviceId.value = '';
    searchSentryId.value = '';
    searchTitle.value = '';
    searchDaysBefore.value = 0;
    searchUserIdController.text = '';
    searchDeviceIdController.text = '';
    searchSentryIdController.text = '';
    searchTitleController.text = '';
    searchDaysController.text = '';
    await loadAppLoadsByPage(page: 1);
  }

  /// 格式化时间
  String formatTime(String timeString) {
    try {
      if (timeString.isEmpty) return '-';

      DateTime dateTime;

      // 兼容时间戳（秒/毫秒）与 ISO 字符串
      final int? timestamp = int.tryParse(timeString);
      if (timestamp != null) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(
          timestamp > 1000000000000 ? timestamp : timestamp * 1000,
          isUtc: true,
        );
      } else {
        dateTime = DateTime.parse(timeString);
      }

      // 已标记为 UTC 的时间做本地化，其他保持原时区，避免重复 +8h
      if (dateTime.isUtc) {
        dateTime = dateTime.toLocal();
      }

      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString;
    }
  }

  /// 获取所有符合当前查询条件的启动记录（不分页）
  Future<List<Document>> _getAllMatchingAppLoads() async {
    final List<Document> allAppLoads = [];

    // 构建查询条件（与 loadAppLoadsByPage 相同的逻辑）
    final List<String> baseQueries = [Query.orderDesc('time')];
    Set<String>? filteredAppLoadIds;

    // 设备ID筛选
    if (searchDeviceId.value.isNotEmpty) {
      baseQueries.add(Query.equal('deviceId', searchDeviceId.value));
    }

    // 按时间筛选：查询指定天数之前的数据
    if (searchDaysBefore.value > 0) {
      final DateTime cutoff =
          DateTime.now().subtract(Duration(days: searchDaysBefore.value));
      baseQueries.add(Query.lessThan('time', cutoff.toIso8601String()));
    }

    // 用户ID筛选（从用户日志表获取关联的启动ID）
    if (searchUserId.value.isNotEmpty) {
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      final userStartResults = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _userLogCollectionId,
        queries: [Query.equal('userId', searchUserId.value)],
      );
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      filteredAppLoadIds = userStartResults.documents
          .map((doc) => doc.data['appLoadId'] as String)
          .toSet();
    }

    // Sentry筛选（从Sentry表获取关联的启动ID）
    if (searchSentryId.value.isNotEmpty || searchTitle.value.isNotEmpty) {
      final List<String> sentryQueries = [];

      if (searchSentryId.value.isNotEmpty) {
        sentryQueries.add(Query.equal('sentryId', searchSentryId.value));
      }
      if (searchTitle.value.isNotEmpty) {
        sentryQueries.add(Query.search('title', searchTitle.value));
      }

      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      final sentryResults = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _sentryLogCollectionId,
        queries: sentryQueries,
      );
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      final sentryAppLoadIds = sentryResults.documents
          .map((doc) => doc.data['appLoadId'] as String)
          .toSet();

      if (filteredAppLoadIds == null) {
        filteredAppLoadIds = sentryAppLoadIds;
      } else {
        filteredAppLoadIds = filteredAppLoadIds.intersection(sentryAppLoadIds);
      }
    }

    // 如果有跨表筛选结果，直接用ID列表过滤
    if (filteredAppLoadIds != null) {
      if (filteredAppLoadIds.isEmpty) {
        return [];
      }
      baseQueries.add(Query.equal('\$id', filteredAppLoadIds.toList()));
    }

    // 使用游标分页获取所有数据
    String? cursor;
    while (true) {
      final List<String> queries = List.from(baseQueries);
      queries.add(Query.limit(100)); // Appwrite 单次查询最大限制
      if (cursor != null) {
        queries.add(Query.cursorAfter(cursor));
      }

      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );
      final result = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _appLoadCollectionId,
        queries: queries,
      );
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      if (result.documents.isEmpty) {
        break;
      }

      allAppLoads.addAll(result.documents);

      // 如果返回的数据少于限制，说明已经获取完所有数据
      if (result.documents.length < 100) {
        break;
      }

      cursor = result.documents.last.$id;
    }

    return allAppLoads;
  }

  /// 一键清理当前查询结果
  Future<void> confirmAndClean() async {
    // 先检查是否有查询条件，如果没有则提示
    final hasSearchCondition = searchUserId.value.isNotEmpty ||
        searchDeviceId.value.isNotEmpty ||
        searchSentryId.value.isNotEmpty ||
        searchTitle.value.isNotEmpty ||
        searchDaysBefore.value > 0;

    if (!hasSearchCondition && appLoads.isEmpty) {
      Get.snackbar('提示', '当前列表为空，无需清理');
      return;
    }

    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认清理'),
        content: Text(
          hasSearchCondition
              ? '将删除当前查询条件匹配的所有数据及关联文件（共 ${totalCount.value} 条），是否继续？'
              : '将删除当前查询到的所有数据及关联文件，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确认删除'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      cleanLogs.clear();
      isCleanFinished.value = false;
      cleanCurrentIndex.value = 0;
      _appendCleanLog('正在获取所有符合查询条件的数据...');
      _showCleaningDialog();

      try {
        // 获取所有符合查询条件的数据
        final allMatchingAppLoads = await _getAllMatchingAppLoads();

        if (allMatchingAppLoads.isEmpty) {
          _appendCleanLog('未找到符合查询条件的数据');
          Get.snackbar('提示', '未找到符合查询条件的数据，无需清理');
          return;
        }

        cleanTotalCount.value = allMatchingAppLoads.length;
        _appendCleanLog('开始清理，待处理 ${allMatchingAppLoads.length} 条启动记录');
        await _cleanLoads(allMatchingAppLoads);
        _appendCleanLog('清理完成');
      } catch (e) {
        _appendCleanLog('获取数据失败：${e.toString()}');
        Get.snackbar('错误', '获取数据失败: ${e.toString()}');
      } finally {
        isCleanFinished.value = true;
      }
    }
  }

  /// 单条启动记录清理
  Future<void> confirmAndCleanSingle(Document appLoad) async {
    if (isCleaning.value) return;

    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除启动记录 ${appLoad.$id} 及其关联日志和文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确认删除'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    if (confirmed == true) {
      cleanLogs.clear();
      isCleanFinished.value = false;
      cleanCurrentIndex.value = 0;
      cleanTotalCount.value = 1;
      _appendCleanLog('开始清理启动记录 ${appLoad.$id}');
      _showCleaningDialog();
      try {
        await _cleanLoads([appLoad]);
        _appendCleanLog('清理完成');
      } finally {
        isCleanFinished.value = true;
      }
    }
  }

  Future<void> _cleanLoads(List<Document> loads) async {
    if (isCleaning.value) return;
    isCleaning.value = true;

    int removedLoads = 0;
    int removedLogs = 0;
    int removedUserLogs = 0;
    int removedSentryLogs = 0;
    int removedFiles = 0;

    try {
      final int totalLoads = loads.length;
      int currentIndex = 0;

      for (final load in loads) {
        currentIndex++;
        cleanCurrentIndex.value = currentIndex;
        final String appLoadId = load.$id;
        _appendCleanLog('开始处理启动记录 $appLoadId (进度: $currentIndex/$totalLoads)');

        try {
          // 1. 查询并删除日志，同时删除存储文件
          final List<int> logResult = await _deleteLogsAndFiles(appLoadId);
          removedLogs += logResult[0];
          removedFiles += logResult[1];
          _appendCleanLog(
              '[$appLoadId] 删除日志文档共 ${logResult[0]} 条，文件 ${logResult[1]} 个');
        } catch (e) {
          _appendCleanLog(
              '[$appLoadId] 删除日志及文件阶段失败，原因: ${e.toString()}，跳过后续步骤');
          continue;
        }

        try {
          // 2. 删除用户日志
          final int userLogCount = await _deleteCollectionByAppLoadId(
            collectionId: _userLogCollectionId,
            appLoadId: appLoadId,
          );
          removedUserLogs += userLogCount;
          _appendCleanLog('[$appLoadId] 删除用户日志共 $userLogCount 条');
        } catch (e) {
          _appendCleanLog('[$appLoadId] 删除用户日志阶段失败，原因: ${e.toString()}，继续后续步骤');
        }

        try {
          // 3. 删除 sentry 日志
          final int sentryLogCount = await _deleteCollectionByAppLoadId(
            collectionId: _sentryLogCollectionId,
            appLoadId: appLoadId,
          );
          removedSentryLogs += sentryLogCount;
          _appendCleanLog('[$appLoadId] 删除 Sentry 日志共 $sentryLogCount 条');
        } catch (e) {
          _appendCleanLog(
              '[$appLoadId] 删除 Sentry 日志阶段失败，原因: ${e.toString()}，继续后续步骤');
        }

        try {
          // 4. 删除启动记录
          await _deleteDocumentWithRateLimit(
            databaseId: _databaseId,
            collectionId: _appLoadCollectionId,
            documentId: appLoadId,
            context: '$appLoadId-启动记录',
          );
          removedLoads += 1;
          _appendCleanLog('[$appLoadId] 启动记录删除完成');
        } catch (e) {
          _appendCleanLog(
              '[$appLoadId] 删除启动记录阶段失败，原因: ${e.toString()}，该启动记录可能部分残留');
        }
      }

      await loadAppLoadsByPage(page: 1);
      Get.snackbar(
        '完成',
        '已清理 $removedLoads 条启动记录，日志 $removedLogs 条，用户日志 $removedUserLogs 条，Sentry 日志 $removedSentryLogs 条，文件 $removedFiles 个',
      );
    } catch (e) {
      Get.snackbar('错误', '清理失败: ${e.toString()}');
      _appendCleanLog('清理失败：${e.toString()}');
    } finally {
      isCleaning.value = false;
    }
  }

  /// 删除日志并清理对应的存储文件
  Future<List<int>> _deleteLogsAndFiles(String appLoadId) async {
    int fileDeleted = 0;
    int logDeleted = 0;
    String? cursor;

    _appendCleanLog('[$appLoadId] 开始删除日志和文件，检查速率限制状态');

    while (true) {
      // 在查询前检查速率限制（使用查询文档的速率限制）
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );

      final List<String> queries = [
        Query.equal('appLoadId', appLoadId),
        Query.limit(100),
      ];
      if (cursor != null) {
        queries.add(Query.cursorAfter(cursor));
      }

      final batch = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: _logCollectionId,
        queries: queries,
      );
      // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      if (batch.documents.isEmpty) break;

      _appendCleanLog('[$appLoadId] 查询到 ${batch.documents.length} 条日志，开始删除');

      for (final doc in batch.documents) {
        final realmId = doc.data['realmId']?.toString();
        if (realmId != null && realmId.isNotEmpty) {
          try {
            await _deleteFileWithRateLimit(
              bucketId: _storageBucketId,
              fileId: realmId,
              context: '$appLoadId-文件',
            );
            fileDeleted += 1;
            _appendCleanLog('[$appLoadId] 删除存储文件 $realmId 成功');
          } catch (e) {
            // 继续删除文档，即便文件不存在
            _appendCleanLog(
                '[$appLoadId] 存储文件 $realmId 删除失败，原因: ${e.toString()}，继续处理文档');
          }
        }

        try {
          await _deleteDocumentWithRateLimit(
            databaseId: _databaseId,
            collectionId: _logCollectionId,
            documentId: doc.$id,
            context: '$appLoadId-日志',
          );
          logDeleted += 1;
          _appendCleanLog('[$appLoadId] 删除日志文档 ${doc.$id} 成功');
        } catch (e) {
          _appendCleanLog(
              '[$appLoadId] 删除日志文档 ${doc.$id} 失败，原因: ${e.toString()}');
          // 继续处理下一个文档
        }
      }

      if (batch.documents.length < 100) break;
      cursor = batch.documents.last.$id;
    }

    _appendCleanLog('[$appLoadId] 删除完成: 日志 $logDeleted 条，文件 $fileDeleted 个');
    return [logDeleted, fileDeleted];
  }

  /// 按 appLoadId 删除指定集合的所有记录
  Future<int> _deleteCollectionByAppLoadId({
    required String collectionId,
    required String appLoadId,
  }) async {
    int deleted = 0;
    String? cursor;
    final collectionName = collectionId == _userLogCollectionId
        ? '用户日志'
        : collectionId == _sentryLogCollectionId
            ? 'Sentry日志'
            : '集合';

    _appendCleanLog('[$appLoadId] 开始删除 $collectionName，检查速率限制状态');

    while (true) {
      // 在查询前检查速率限制（使用查询文档的速率限制）
      await _rateLimitHandler.checkAndWaitIfNeeded(
        type: ApiEndpointType.listDocuments,
        minRemaining: 1,
      );

      final List<String> queries = [
        Query.equal('appLoadId', appLoadId),
        Query.limit(100),
      ];
      if (cursor != null) {
        queries.add(Query.cursorAfter(cursor));
      }

      final batch = await _appwriteManager.databases.listDocuments(
        databaseId: _databaseId,
        collectionId: collectionId,
        queries: queries,
      );
      // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
      _updateRateLimitFromResponse(ApiEndpointType.listDocuments);

      if (batch.documents.isEmpty) break;

      _appendCleanLog(
          '[$appLoadId] 查询到 ${batch.documents.length} 条 $collectionName，开始删除');

      for (final doc in batch.documents) {
        try {
          await _deleteDocumentWithRateLimit(
            databaseId: _databaseId,
            collectionId: collectionId,
            documentId: doc.$id,
            context: '$appLoadId-$collectionName',
          );
          deleted += 1;
        } catch (e) {
          _appendCleanLog(
              '[$appLoadId] 删除 $collectionName 文档 ${doc.$id} 失败，原因: ${e.toString()}');
          // 继续处理下一个文档
        }
      }

      if (batch.documents.length < 100) break;
      cursor = batch.documents.last.$id;
    }

    _appendCleanLog('[$appLoadId] $collectionName 删除完成: $deleted 条');
    return deleted;
  }

  void _appendCleanLog(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    cleanLogs.add('[$ts] $message');

    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (logScrollController.hasClients) {
        logScrollController.animateTo(
          logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 执行带速率限制检查的删除操作
  Future<void> _deleteDocumentWithRateLimit({
    required String databaseId,
    required String collectionId,
    required String documentId,
    String? context, // 用于日志上下文
  }) async {
    const endpointType = ApiEndpointType.deleteDocument;
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // 在执行前检查速率限制（使用删除文档的速率限制）
        await _rateLimitHandler.checkAndWaitIfNeeded(
          type: endpointType,
          minRemaining: 1,
        );

        // 执行删除操作
        await _appwriteManager.databases.deleteDocument(
          databaseId: databaseId,
          collectionId: collectionId,
          documentId: documentId,
        );

        // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
        _updateRateLimitFromResponse(endpointType);

        // 成功，退出重试循环
        return;
      } on AppwriteException catch (e) {
        // 处理 429 速率限制错误（这应该是最后的兜底，正常情况下应该提前等待）
        if (e.code == 429) {
          final typeName = _getEndpointTypeName(endpointType);
          _appendCleanLog(
              '${context != null ? "[$context] " : ""}[$typeName] 遇到速率限制错误 (429): ${e.message}');

          // 优先尝试从错误响应中提取速率限制信息
          RateLimitInfo? extractedRateLimit =
              _tryExtractRateLimitFromException(e, endpointType);

          int? waitTime;

          // 优先使用从429响应中提取的重置时间
          if (extractedRateLimit != null) {
            waitTime = extractedRateLimit.secondsUntilReset;
            if (waitTime <= 0) {
              // 如果已经重置，可以立即重试
              waitTime = 1;
            }
            _appendCleanLog(
                '${context != null ? "[$context] " : ""}[$typeName] 从429响应header获取重置时间: 等待 $waitTime 秒 (重置时间: ${_formatDateTime(extractedRateLimit.resetDateTime)})');
          } else {
            // 如果无法从响应中提取，尝试使用已有的速率限制信息
            final currentRateLimit =
                _rateLimitHandler.getCurrentRateLimit(endpointType);
            if (currentRateLimit != null) {
              waitTime = currentRateLimit.secondsUntilReset;
              if (waitTime <= 0) {
                waitTime = 1; // 如果已经重置，可以立即重试
              }
              _appendCleanLog(
                  '${context != null ? "[$context] " : ""}[$typeName] 从已有速率限制信息获取等待时间: $waitTime 秒 (重置时间: ${_formatDateTime(currentRateLimit.resetDateTime)})');
            } else {
              // 无法获取重置时间，使用默认等待时间（60秒）
              waitTime = 60;
              _appendCleanLog(
                  '${context != null ? "[$context] " : ""}[$typeName] 警告: 无法获取速率限制重置时间信息，使用默认等待时间 $waitTime 秒');
            }
          }

          // waitTime 在这里一定不为null（如果为null，前面会抛出异常）
          if (waitTime > 0) {
            _appendCleanLog(
                '${context != null ? "[$context] " : ""}[$typeName] 等待 $waitTime 秒后重试 (重试 ${retryCount + 1}/$maxRetries)');

            // 显示等待进度
            final resetTime = extractedRateLimit?.resetDateTime ??
                _rateLimitHandler
                    .getCurrentRateLimit(endpointType)
                    ?.resetDateTime;
            for (int i = waitTime; i > 0; i--) {
              await Future.delayed(const Duration(seconds: 1));
              if (i % 10 == 0 || i <= 5) {
                final resetTimeStr = resetTime != null
                    ? '（将在 ${_formatDateTime(resetTime)} 重置）'
                    : '';
                _appendCleanLog(
                    '${context != null ? "[$context] " : ""}[$typeName] 等待中... 剩余 ${i} 秒$resetTimeStr');
              }
            }
          }

          retryCount++;

          if (retryCount >= maxRetries) {
            throw Exception(
                '${context != null ? "[$context] " : ""}[$typeName] 达到最大重试次数，删除失败: ${e.message}');
          }
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e) {
        // 非 AppwriteException 错误直接抛出
        if (e is! AppwriteException) {
          rethrow;
        }
      }
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }

  /// 执行带速率限制检查的文件删除操作
  Future<void> _deleteFileWithRateLimit({
    required String bucketId,
    required String fileId,
    String? context, // 用于日志上下文
  }) async {
    const endpointType = ApiEndpointType.deleteFile;
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // 在执行前检查速率限制（使用删除文件的速率限制）
        await _rateLimitHandler.checkAndWaitIfNeeded(
          type: endpointType,
          minRemaining: 1,
        );

        // 执行删除操作
        await _appwriteManager.storage.deleteFile(
          bucketId: bucketId,
          fileId: fileId,
        );

        // 成功响应后，更新限速信息（不基于 URL，而是基于接口类型）
        _updateRateLimitFromResponse(endpointType);

        // 成功，退出重试循环
        return;
      } on AppwriteException catch (e) {
        // 处理 429 速率限制错误（这应该是最后的兜底，正常情况下应该提前等待）
        if (e.code == 429) {
          final typeName = _getEndpointTypeName(endpointType);
          _appendCleanLog(
              '${context != null ? "[$context] " : ""}[$typeName] 遇到速率限制错误 (429): ${e.message}');

          // 优先尝试从错误响应中提取速率限制信息
          RateLimitInfo? extractedRateLimit =
              _tryExtractRateLimitFromException(e, endpointType);

          int? waitTime;

          // 优先使用从429响应中提取的重置时间
          if (extractedRateLimit != null) {
            waitTime = extractedRateLimit.secondsUntilReset;
            if (waitTime <= 0) {
              // 如果已经重置，可以立即重试
              waitTime = 1;
            }
            _appendCleanLog(
                '${context != null ? "[$context] " : ""}[$typeName] 从429响应header获取重置时间: 等待 $waitTime 秒 (重置时间: ${_formatDateTime(extractedRateLimit.resetDateTime)})');
          } else {
            // 如果无法从响应中提取，尝试使用已有的速率限制信息
            final currentRateLimit =
                _rateLimitHandler.getCurrentRateLimit(endpointType);
            if (currentRateLimit != null) {
              waitTime = currentRateLimit.secondsUntilReset;
              if (waitTime <= 0) {
                waitTime = 1; // 如果已经重置，可以立即重试
              }
              _appendCleanLog(
                  '${context != null ? "[$context] " : ""}[$typeName] 从已有速率限制信息获取等待时间: $waitTime 秒 (重置时间: ${_formatDateTime(currentRateLimit.resetDateTime)})');
            } else {
              // 无法获取重置时间，使用默认等待时间（60秒）
              waitTime = 60;
              _appendCleanLog(
                  '${context != null ? "[$context] " : ""}[$typeName] 警告: 无法获取速率限制重置时间信息，使用默认等待时间 $waitTime 秒');
            }
          }

          // waitTime 在这里一定不为null（如果为null，前面会抛出异常）
          if (waitTime > 0) {
            _appendCleanLog(
                '${context != null ? "[$context] " : ""}[$typeName] 等待 $waitTime 秒后重试 (重试 ${retryCount + 1}/$maxRetries)');

            // 显示等待进度
            final resetTime = extractedRateLimit?.resetDateTime ??
                _rateLimitHandler
                    .getCurrentRateLimit(endpointType)
                    ?.resetDateTime;
            for (int i = waitTime; i > 0; i--) {
              await Future.delayed(const Duration(seconds: 1));
              if (i % 10 == 0 || i <= 5) {
                final resetTimeStr = resetTime != null
                    ? '（将在 ${_formatDateTime(resetTime)} 重置）'
                    : '';
                _appendCleanLog(
                    '${context != null ? "[$context] " : ""}[$typeName] 等待中... 剩余 ${i} 秒$resetTimeStr');
              }
            }
          }

          retryCount++;

          if (retryCount >= maxRetries) {
            throw Exception(
                '${context != null ? "[$context] " : ""}[$typeName] 达到最大重试次数，删除文件失败: ${e.message}');
          }
        } else {
          // 其他错误直接抛出
          rethrow;
        }
      } catch (e) {
        // 非 AppwriteException 错误直接抛出
        if (e is! AppwriteException) {
          rethrow;
        }
      }
    }
  }

  void _showCleaningDialog() {
    Get.dialog(
      Obx(
        () => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: Get.width * 0.5,
            height: Get.height * 0.6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cleaning_services,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 8),
                      Obx(
                        () => Text(
                          cleanTotalCount.value > 0
                              ? '一键清理进度 (${cleanCurrentIndex.value}/${cleanTotalCount.value})'
                              : '一键清理进度',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: isCleaning.value ? null : () => Get.back(),
                        tooltip: isCleaning.value ? '正在清理中，请稍候' : '关闭',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isCleaning.value
                        ? '清理进行中，请勿关闭...'
                        : isCleanFinished.value
                            ? '清理完成，可以关闭'
                            : '',
                    style: TextStyle(
                      color: isCleaning.value
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Obx(
                        () {
                          // 当日志更新时，自动滚动到底部
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (logScrollController.hasClients) {
                              logScrollController.animateTo(
                                logScrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });

                          return ListView.builder(
                            controller: logScrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: cleanLogs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  cleanLogs[index],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (isCleaning.value)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        isCleaning.value
                            ? '执行中...'
                            : isCleanFinished.value
                                ? '已完成'
                                : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isCleaning.value
                              ? Colors.orange.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed:
                            isCleaning.value ? null : () => Get.back<void>(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
