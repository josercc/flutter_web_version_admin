import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:get/get.dart';

class AppwriteManager extends GetxService {
  final client = Client();
  late Account _account;
  late Databases _databases;

  @override
  void onInit() {
    super.onInit();
    client
        .setEndpoint('https://appwrite.winnermedical.com/v1')
        .setProject('677f626b0012252b422e');
    _account = Account(client);
    _databases = Databases(client);
  }

  /// 进行登录
  Future<void> login({required String email, required String password}) async {
    /// 查找当前是否已经登录
    final session = await _account
        .getSession(sessionId: 'current')
        .then<Session?>((e) => e)
        .catchError((e) {
      return null;
    });
    if (session == null ||
        DateTime.parse(session.expire).difference(DateTime.now()).inSeconds <=
            10 * 60) {
      await _account.createEmailPasswordSession(
        email: email,
        password: password,
      );
    }
  }

  /// 查询当前热更的版本列表
  Future<DocumentList> getVersionList({
    int limit = 25,
    String? offset,
    Map<String, dynamic>? filters,
  }) async {
    List<String> queries = [
      Query.orderDesc('version'),
      Query.limit(limit),
    ];

    // 添加分页偏移
    if (offset != null && offset.isNotEmpty) {
      queries.add(Query.cursorAfter(offset));
    }

    // 添加筛选条件（不包括手机号筛选，因为数组字段不支持搜索）
    if (filters != null && filters.isNotEmpty) {
      if (filters.containsKey('routeName') && filters['routeName'].isNotEmpty) {
        queries.add(Query.search('routeName', filters['routeName']));
      }
      
      // 手机号筛选在客户端处理，这里跳过
      
      if (filters.containsKey('onlineStatus') && filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }
      
      if (filters.containsKey('environment') && filters['environment'] != '全部') {
        bool isTestEnv = filters['environment'] == '测试环境';
        queries.add(Query.equal('is_test_environment', isTestEnv));
      }
    }

    return await _databases.listDocuments(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      queries: queries,
    );
  }

  /// 根据页码查询版本列表
  Future<DocumentList> getVersionListByPage({
    required int page,
    required int limit,
    Map<String, dynamic>? filters,
  }) async {
    List<String> queries = [
      Query.orderDesc('version'),
      Query.limit(limit),
      Query.offset((page - 1) * limit), // 计算偏移量
    ];

    // 添加筛选条件（不包括手机号筛选，因为数组字段不支持搜索）
    if (filters != null && filters.isNotEmpty) {
      if (filters.containsKey('routeName') && filters['routeName'].isNotEmpty) {
        queries.add(Query.search('routeName', filters['routeName']));
      }
      
      // 手机号筛选在客户端处理，这里跳过
      
      if (filters.containsKey('onlineStatus') && filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }
      
      if (filters.containsKey('environment') && filters['environment'] != '全部') {
        bool isTestEnv = filters['environment'] == '测试环境';
        queries.add(Query.equal('is_test_environment', isTestEnv));
      }
    }

    return await _databases.listDocuments(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      queries: queries,
    );
  }

  /// 更新版本启用状态
  Future<void> updateVersion({
    required String documentId,
    bool? isEnable,
    List<String>? allowPhones,
    bool? isStore,
  }) async {
    Map data = {};
    if (isEnable != null) {
      data['enable'] = isEnable;
    }
    if (allowPhones != null) {
      data['allow_phones'] = allowPhones;
    }
    if (isStore != null) {
      data['is_store'] = isStore;
    }
    if (data.isEmpty) {
      return;
    }
    await _databases.updateDocument(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      documentId: documentId,
      data: data,
    );
  }

  /// 获取所有版本数据用于客户端筛选（当需要手机号筛选时使用）
  Future<DocumentList> getAllVersionsForFiltering({
    Map<String, dynamic>? filters,
  }) async {
    List<String> queries = [
      Query.orderDesc('version'),
      Query.limit(1000), // 获取大量数据用于客户端筛选
    ];

    // 添加非手机号的筛选条件
    if (filters != null && filters.isNotEmpty) {
      if (filters.containsKey('routeName') && filters['routeName'].isNotEmpty) {
        queries.add(Query.search('routeName', filters['routeName']));
      }
      
      if (filters.containsKey('onlineStatus') && filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }
      
      if (filters.containsKey('environment') && filters['environment'] != '全部') {
        bool isTestEnv = filters['environment'] == '测试环境';
        queries.add(Query.equal('is_test_environment', isTestEnv));
      }
    }

    return await _databases.listDocuments(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      queries: queries,
    );
  }
}
