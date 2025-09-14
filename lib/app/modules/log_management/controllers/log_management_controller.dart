import 'package:get/get.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import '../../../commons/appwrite_manager.dart';

class LogManagementController extends GetxController {
  final AppwriteManager _appwriteManager = Get.find<AppwriteManager>();

  // 搜索相关
  final RxString searchUserId = ''.obs;
  final RxString searchDeviceId = ''.obs;
  final RxString searchSentryId = ''.obs;
  final RxString searchTitle = ''.obs;

  // 数据列表
  final RxList<Document> appLoads = <Document>[].obs;
  final RxList<Document> userLogs = <Document>[].obs;
  final RxList<Document> sentryLogs = <Document>[].obs;

  // 加载状态
  final RxBool isLoading = false.obs;
  final RxBool hasSearched = false.obs;

  // 选中的启动记录
  final Rx<Document?> selectedAppLoad = Rx<Document?>(null);

  @override
  void onInit() {
    super.onInit();
  }

  /// 搜索启动记录
  Future<void> searchAppLoads() async {
    if (searchUserId.value.isEmpty &&
        searchDeviceId.value.isEmpty &&
        searchSentryId.value.isEmpty &&
        searchTitle.value.isEmpty) {
      Get.snackbar('提示', '请输入至少一个搜索条件');
      return;
    }

    isLoading.value = true;
    hasSearched.value = true;

    try {
      // 清空之前的结果
      appLoads.clear();
      userLogs.clear();
      sentryLogs.clear();
      selectedAppLoad.value = null;

      // 根据不同的搜索条件查询启动记录
      List<String> queries = [Query.orderDesc('time')];

      if (searchDeviceId.value.isNotEmpty) {
        queries.add(Query.equal('deviceId', searchDeviceId.value));
      }

      // 查询app启动表
      DocumentList appLoadResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: '677f63ac003be28fb635',
        collectionId: '677f63b900033b03d59f',
        queries: queries,
      );

      appLoads.value = appLoadResults.documents;

      // 如果有用户ID搜索条件，进一步筛选
      if (searchUserId.value.isNotEmpty) {
        await _filterByUserId(searchUserId.value);
      }

      // 如果有SentryID或标题搜索条件，进一步筛选
      if (searchSentryId.value.isNotEmpty || searchTitle.value.isNotEmpty) {
        await _filterBySentry(searchSentryId.value, searchTitle.value);
      }
    } catch (e) {
      Get.snackbar('错误', '搜索失败: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// 根据用户ID筛选启动记录
  Future<void> _filterByUserId(String userId) async {
    try {
      // 查询用户启动表
      DocumentList userStartResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: '677f63ac003be28fb635',
        collectionId: '677f71c9000566bbcf38',
        queries: [Query.equal('userId', userId)],
      );

      // 获取匹配的appLoadId列表
      List<String> matchingAppLoadIds = userStartResults.documents
          .map((doc) => doc.data['appLoadId'] as String)
          .toList();

      // 筛选启动记录
      appLoads.value = appLoads.where((appLoad) {
        return matchingAppLoadIds.contains(appLoad.$id);
      }).toList();

      // 保存用户日志
      userLogs.value = userStartResults.documents;
    } catch (e) {
      // 根据用户ID筛选失败，继续执行
    }
  }

  /// 根据Sentry信息筛选启动记录
  Future<void> _filterBySentry(String sentryId, String title) async {
    try {
      List<String> queries = [];

      if (sentryId.isNotEmpty) {
        queries.add(Query.equal('sentryId', sentryId));
      }
      if (title.isNotEmpty) {
        queries.add(Query.search('title', title));
      }

      // 查询sentry表
      DocumentList sentryResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: '677f63ac003be28fb635',
        collectionId: '6784a4960004fd640ddf',
        queries: queries,
      );

      // 获取匹配的appLoadId列表
      List<String> matchingAppLoadIds = sentryResults.documents
          .map((doc) => doc.data['appLoadId'] as String)
          .toList();

      // 筛选启动记录
      appLoads.value = appLoads.where((appLoad) {
        return matchingAppLoadIds.contains(appLoad.$id);
      }).toList();

      // 保存sentry日志
      sentryLogs.value = sentryResults.documents;
    } catch (e) {
      // 根据Sentry信息筛选失败，继续执行
    }
  }

  /// 选择启动记录并获取详细信息
  Future<void> selectAppLoad(Document appLoad) async {
    selectedAppLoad.value = appLoad;

    try {
      // 获取该启动记录的用户日志
      DocumentList userLogResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: '677f63ac003be28fb635',
        collectionId: '677f71c9000566bbcf38',
        queries: [Query.equal('appLoadId', appLoad.$id)],
      );

      // 获取该启动记录的sentry日志
      DocumentList sentryLogResults =
          await _appwriteManager.databases.listDocuments(
        databaseId: '677f63ac003be28fb635',
        collectionId: '6784a4960004fd640ddf',
        queries: [Query.equal('appLoadId', appLoad.$id)],
      );

      // 更新相关日志
      userLogs.value = userLogResults.documents;
      sentryLogs.value = sentryLogResults.documents;

      // 触发UI更新以显示详细日志
    } catch (e) {
      Get.snackbar('错误', '获取详细信息失败: ${e.toString()}');
    }
  }

  /// 清空搜索
  void clearSearch() {
    searchUserId.value = '';
    searchDeviceId.value = '';
    searchSentryId.value = '';
    searchTitle.value = '';
    appLoads.clear();
    userLogs.clear();
    sentryLogs.clear();
    selectedAppLoad.value = null;
    hasSearched.value = false;
  }

  /// 格式化时间
  String formatTime(String timeString) {
    try {
      DateTime dateTime = DateTime.parse(timeString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeString;
    }
  }
}
