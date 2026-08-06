import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/src/enums.dart';
import 'package:get/get.dart';
import 'rate_limit_handler.dart';
import 'appwrite_client.dart';

class AppwriteManager extends GetxService {
  final client = AppwriteClient();
  late Account _account;
  late Databases _databases;
  late Storage _storage;
  RateLimitHandler? _rateLimitHandler;

  /// 设置速率限制处理器
  void setRateLimitHandler(RateLimitHandler handler) {
    _rateLimitHandler = handler;
  }

  @override
  void onInit() {
    super.onInit();
    // 客户端已在构造函数中配置好端点等信息
    _account = Account(client);
    _databases = Databases(client);
    _storage = Storage(client);
  }

  // 公共访问器
  Databases get databases => _databases;
  Storage get storage => _storage;

  /// 获取当前限速信息（最新一次响应的限速信息）
  AppwriteRateLimit? get rateLimit => client.rateLimit;

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

  /// 退出登录
  Future<void> logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {
      // 如果当前没有会话，忽略错误
    }
  }

  /// 获取当前登录用户信息（绕过 SDK User.fromMap，避免 targets.expired 为 null 时崩溃）
  Future<Map<String, dynamic>> getCurrentAccountMap() async {
    final res = await client.call(
      HttpMethod.get,
      path: '/account',
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// 当前用户 labels
  Future<List<String>> getCurrentUserLabels() async {
    final account = await getCurrentAccountMap();
    final labels = account['labels'];
    if (labels is List) {
      return labels.map((e) => e.toString()).toList();
    }
    return const [];
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

      if (filters.containsKey('onlineStatus') &&
          filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }

      if (filters.containsKey('environment') &&
          filters['environment'] != '全部') {
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

      if (filters.containsKey('onlineStatus') &&
          filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }

      if (filters.containsKey('environment') &&
          filters['environment'] != '全部') {
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

      if (filters.containsKey('onlineStatus') &&
          filters['onlineStatus'] != '全部') {
        bool isOnline = filters['onlineStatus'] == '已上线';
        queries.add(Query.equal('enable', isOnline));
      }

      if (filters.containsKey('environment') &&
          filters['environment'] != '全部') {
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

  // ========== 打包管理相关方法 ==========

  /// 获取打包信息列表
  Future<DocumentList> getBuildList({
    required int page,
    required int limit,
    Map<String, dynamic>? filters,
  }) async {
    List<String> queries = [
      Query.orderDesc('\$createdAt'),
      Query.limit(limit),
      Query.offset((page - 1) * limit),
    ];

    // 添加筛选条件
    if (filters != null && filters.isNotEmpty) {
      if (filters.containsKey('platform') && filters['platform'] != '全部') {
        queries.add(Query.equal('platform', filters['platform']));
      }
      if (filters.containsKey('build_name') && filters['build_name'] != '全部') {
        queries.add(Query.equal('build_name', filters['build_name']));
      }
      if (filters.containsKey('melos_branch') &&
          filters['melos_branch'] != '全部') {
        queries.add(Query.equal('melos_branch', filters['melos_branch']));
      }
      if (filters.containsKey('unity_branch') &&
          filters['unity_branch'] != '全部') {
        queries.add(Query.equal('unity_branch', filters['unity_branch']));
      }
    }

    return await _databases.listDocuments(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '6846368d0020a564ca80',
      queries: queries,
    );
  }

  /// 获取所有打包信息用于筛选选项提取
  Future<DocumentList> getAllBuildsForFiltering() async {
    List<String> queries = [
      Query.orderDesc('\$createdAt'),
      Query.limit(1000), // 获取大量数据用于提取筛选选项
    ];

    return await _databases.listDocuments(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '6846368d0020a564ca80',
      queries: queries,
    );
  }

  /// 获取分支信息列表
  Future<DocumentList> getBranchList() async {
    List<String> queries = [
      Query.orderDesc('\$createdAt'),
      Query.limit(1000),
    ];

    return await _databases.listDocuments(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '68463b340010d6142dd1',
      queries: queries,
    );
  }

  /// 创建打包信息
  Future<void> createBuildInfo({
    required String platform,
    required String buildName,
    required String buildNumber,
    required String melosBranch,
    required String unityBranch,
    required String unityCommitId,
    required String unityBuildVersion,
  }) async {
    await _databases.createDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '6846368d0020a564ca80',
      documentId: 'unique()',
      data: {
        'platform': platform,
        'build_name': buildName,
        'build_number': buildNumber,
        'melos_branch': melosBranch,
        'unity_branch': unityBranch,
        'unity_commit_id': unityCommitId,
        'unity_build_version': unityBuildVersion,
      },
    );
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
    Map<String, dynamic> data = {};

    if (platform != null) data['platform'] = platform;
    if (buildName != null) data['build_name'] = buildName;
    if (buildNumber != null) data['build_number'] = buildNumber;
    if (melosBranch != null) data['melos_branch'] = melosBranch;
    if (unityBranch != null) data['unity_branch'] = unityBranch;
    if (unityCommitId != null) data['unity_commit_id'] = unityCommitId;
    if (unityBuildVersion != null) {
      data['unity_build_version'] = unityBuildVersion;
    }

    if (data.isEmpty) {
      return;
    }

    await _databases.updateDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '6846368d0020a564ca80',
      documentId: documentId,
      data: data,
    );
  }

  /// 删除打包信息
  Future<void> deleteBuildInfo(String documentId) async {
    await _databases.deleteDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '6846368d0020a564ca80',
      documentId: documentId,
    );
  }

  /// 批量删除打包信息
  Future<void> deleteMultipleBuildInfo(List<String> documentIds) async {
    for (final documentId in documentIds) {
      await _databases.deleteDocument(
        databaseId: '67c566f20023fc5bd074',
        collectionId: '6846368d0020a564ca80',
        documentId: documentId,
      );
    }
  }

  /// 创建分支信息
  Future<void> createBranchInfo({
    required String melosBuildId,
    required String path,
    required String branch,
    required String commitId,
  }) async {
    await _databases.createDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '68463b340010d6142dd1',
      documentId: 'unique()',
      data: {
        'melos_build_id': melosBuildId,
        'path': path,
        'branch': branch,
        'commit_id': commitId,
      },
    );
  }

  /// 更新分支信息
  Future<void> updateBranchInfo({
    required String documentId,
    String? melosBuildId,
    String? path,
    String? branch,
    String? commitId,
  }) async {
    Map<String, dynamic> data = {};

    if (melosBuildId != null) data['melos_build_id'] = melosBuildId;
    if (path != null) data['path'] = path;
    if (branch != null) data['branch'] = branch;
    if (commitId != null) data['commit_id'] = commitId;

    if (data.isEmpty) {
      return;
    }

    await _databases.updateDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '68463b340010d6142dd1',
      documentId: documentId,
      data: data,
    );
  }

  /// 删除分支信息
  Future<void> deleteBranchInfo(String documentId) async {
    await _databases.deleteDocument(
      databaseId: '67c566f20023fc5bd074',
      collectionId: '68463b340010d6142dd1',
      documentId: documentId,
    );
  }

  // ========== 用户管理相关方法 ==========
  // 注意：Appwrite Flutter 客户端 SDK 不支持 Users API（这是服务端 API）
  // 要获取用户列表，需要通过服务端 API 端点实现

  // ========== 打包机管理相关方法 ==========

  static const String _packagerDatabaseId = '6a6aaced00065290a69c';
  static const String _packagerCollectionId = '6a6aacfb00024a65ba3d';

  /// 获取打包机列表
  Future<DocumentList> getPackagerList({
    int page = 1,
    int limit = 100,
  }) async {
    return await _databases.listDocuments(
      databaseId: _packagerDatabaseId,
      collectionId: _packagerCollectionId,
      queries: [
        Query.orderDesc('\$createdAt'),
        Query.limit(limit),
        Query.offset((page - 1) * limit),
      ],
    );
  }

  /// 更新打包机 active 状态
  Future<void> updatePackagerActive({
    required String documentId,
    required bool active,
  }) async {
    await _databases.updateDocument(
      databaseId: _packagerDatabaseId,
      collectionId: _packagerCollectionId,
      documentId: documentId,
      data: {'active': active},
    );
  }
}
