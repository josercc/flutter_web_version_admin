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
  Future<DocumentList> getVersionList() async {
    return await _databases.listDocuments(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      queries: [
        Query.orderDesc('version'),
      ],
    );
  }

  /// 更新版本启用状态
  Future<void> updateVersionEnable({
    required String documentId,
    required bool isEnable,
  }) async {
    await _databases.updateDocument(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      documentId: documentId,
      data: {
        'enable': isEnable,
      },
    );
  }

  /// 发布新版本
  Future<void> publishNewVersion({
    required String routeName,
    required Map<String, dynamic> data,
    bool isFullPublish = false,
    List<String>? targetPhones,
  }) async {
    // 准备发布数据
    final publishData = {
      'routeName': routeName,
      'version': DateTime.now().millisecondsSinceEpoch,
      'enable': true,
      'is_store': isFullPublish,
      ...data,
    };

    // 如果是全量发布，清空allow_phones字段
    if (isFullPublish) {
      publishData['allow_phones'] = [];
    } 
    // 如果是针对性发布，设置目标手机号
    else if (targetPhones != null && targetPhones.isNotEmpty) {
      publishData['allow_phones'] = targetPhones;
    }

    await _databases.createDocument(
      databaseId: '67f47b11001a83bd8eb1',
      collectionId: '68a340c0002682fb25ba',
      documentId: ID.unique(),
      data: publishData,
    );
  }
}
