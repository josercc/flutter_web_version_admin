import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:log_cleanup_cli/appwrite_client.dart';

/// 日志清理服务：各集合与存储桶按 [$createdAt] 独立过滤，不做关联查询。
class LogCleanupService {
  static const String databaseId = '677f63ac003be28fb635';
  static const String appLoadCollectionId = '677f63b900033b03d59f';
  static const String logCollectionId = '6784aec8003d415d53d7';
  static const String userLogCollectionId = '677f71c9000566bbcf38';
  static const String sentryLogCollectionId = '6784a4960004fd640ddf';
  static const String storageBucketId = '6787201a00376ab5d134';

  static const int _pageSize = 100;

  static const _collections = <_CollectionTarget>[
    _CollectionTarget(label: '启动记录', id: appLoadCollectionId),
    _CollectionTarget(label: '日志文档', id: logCollectionId),
    _CollectionTarget(label: '用户日志', id: userLogCollectionId),
    _CollectionTarget(label: 'Sentry 日志', id: sentryLogCollectionId),
  ];

  final AppwriteClient client = AppwriteClient();
  late final Databases _databases;
  late final Storage _storage;

  LogCleanupService({void Function(String message)? logCallback})
      : _log = logCallback ?? _defaultLog {
    _databases = Databases(client);
    _storage = Storage(client);
  }

  final void Function(String message) _log;

  static void _defaultLog(String message) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    // ignore: avoid_print
    print('[$ts] $message');
  }

  void authenticate({required String apiKey}) {
    if (apiKey.trim().isEmpty) {
      throw ArgumentError('API Key 不能为空');
    }
    client.setKey(apiKey.trim());
    _log('API Key 认证已配置');
  }

  DateTime cutoffBeforeDays(int days) {
    return DateTime.now().subtract(Duration(days: days));
  }

  String _cutoffQuery(DateTime cutoff) {
    return cutoff.toUtc().toIso8601String();
  }

  /// 统计指定天数之前（按 [$createdAt]）待清理的数据库记录与存储文件数量。
  Future<CleanupPreview> previewCleanupBeforeDays(int days) async {
    if (days <= 0) {
      throw ArgumentError('天数必须大于 0');
    }

    final cutoff = cutoffBeforeDays(days);
    _log('统计 $days 天之前的数据（截止时间: ${_formatDateTime(cutoff)}，按创建时间）');

    var appLoads = 0;
    var logs = 0;
    var userLogs = 0;
    var sentryLogs = 0;

    for (final target in _collections) {
      _log('统计 ${target.label}...');
      final count = await _countDocumentsBeforeCutoff(
        collectionId: target.id,
        cutoff: cutoff,
      );
      _log('${target.label}: $count 条');

      if (target.id == appLoadCollectionId) {
        appLoads = count;
      } else if (target.id == logCollectionId) {
        logs = count;
      } else if (target.id == userLogCollectionId) {
        userLogs = count;
      } else if (target.id == sentryLogCollectionId) {
        sentryLogs = count;
      }
    }

    _log('统计存储文件...');
    final files = await _countFilesBeforeCutoff(cutoff);
    _log('存储文件: $files 个');

    return CleanupPreview(
      appLoads: appLoads,
      logs: logs,
      userLogs: userLogs,
      sentryLogs: sentryLogs,
      files: files,
    );
  }

  /// 删除指定天数之前（按 [$createdAt]）的数据库记录与存储文件。
  Future<CleanupSummary> deleteBeforeDays(int days) async {
    if (days <= 0) {
      throw ArgumentError('天数必须大于 0');
    }

    final cutoff = cutoffBeforeDays(days);
    _log('开始删除 $days 天之前的数据（截止时间: ${_formatDateTime(cutoff)}，按创建时间）');

    var removedLoads = 0;
    var removedLogs = 0;
    var removedUserLogs = 0;
    var removedSentryLogs = 0;

    for (final target in _collections) {
      _log('删除 ${target.label}...');
      final removed = await _deleteDocumentsBeforeCutoff(
        collectionId: target.id,
        label: target.label,
        cutoff: cutoff,
      );

      if (target.id == appLoadCollectionId) {
        removedLoads = removed;
      } else if (target.id == logCollectionId) {
        removedLogs = removed;
      } else if (target.id == userLogCollectionId) {
        removedUserLogs = removed;
      } else if (target.id == sentryLogCollectionId) {
        removedSentryLogs = removed;
      }
    }

    _log('删除存储文件...');
    final removedFiles = await _deleteFilesBeforeCutoff(cutoff);

    final summary = CleanupSummary(
      removedLoads: removedLoads,
      removedLogs: removedLogs,
      removedUserLogs: removedUserLogs,
      removedSentryLogs: removedSentryLogs,
      removedFiles: removedFiles,
    );

    _log(
      '清理完成: 启动记录 ${summary.removedLoads} 条，日志 ${summary.removedLogs} 条，'
      '用户日志 ${summary.removedUserLogs} 条，Sentry 日志 ${summary.removedSentryLogs} 条，'
      '存储文件 ${summary.removedFiles} 个',
    );

    return summary;
  }

  Future<int> _countDocumentsBeforeCutoff({
    required String collectionId,
    required DateTime cutoff,
  }) async {
    final result = await _databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: [
        Query.lessThan('\$createdAt', _cutoffQuery(cutoff)),
        Query.limit(1),
      ],
    );
    return result.total;
  }

  Future<int> _countFilesBeforeCutoff(DateTime cutoff) async {
    final result = await _storage.listFiles(
      bucketId: storageBucketId,
      queries: [
        Query.lessThan('\$createdAt', _cutoffQuery(cutoff)),
        Query.limit(1),
      ],
    );
    return result.total;
  }

  Future<int> _deleteDocumentsBeforeCutoff({
    required String collectionId,
    required String label,
    required DateTime cutoff,
  }) async {
    var removed = 0;
    var batchNum = 0;

    while (true) {
      final batch = await _databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: [
          Query.lessThan('\$createdAt', _cutoffQuery(cutoff)),
          Query.limit(_pageSize),
        ],
      );

      if (batch.documents.isEmpty) break;

      batchNum += 1;
      _log('$label: 第 $batchNum 批，${batch.documents.length} 条');

      for (final doc in batch.documents) {
        try {
          await _databases.deleteDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: doc.$id,
          );
          removed += 1;
        } catch (e) {
          _log('$label 文档 ${doc.$id} 删除失败: $e');
        }
      }
    }

    _log('$label 删除完成: $removed 条');
    return removed;
  }

  Future<int> _deleteFilesBeforeCutoff(DateTime cutoff) async {
    var removed = 0;
    var batchNum = 0;

    while (true) {
      final batch = await _storage.listFiles(
        bucketId: storageBucketId,
        queries: [
          Query.lessThan('\$createdAt', _cutoffQuery(cutoff)),
          Query.limit(_pageSize),
        ],
      );

      if (batch.files.isEmpty) break;

      batchNum += 1;
      _log('存储文件: 第 $batchNum 批，${batch.files.length} 个');

      for (final file in batch.files) {
        try {
          await _storage.deleteFile(
            bucketId: storageBucketId,
            fileId: file.$id,
          );
          removed += 1;
        } catch (e) {
          _log('存储文件 ${file.$id} 删除失败: $e');
        }
      }
    }

    _log('存储文件删除完成: $removed 个');
    return removed;
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}

class _CollectionTarget {
  final String label;
  final String id;

  const _CollectionTarget({required this.label, required this.id});
}

/// 删除前预览：待清理数量统计。
class CleanupPreview {
  final int appLoads;
  final int logs;
  final int userLogs;
  final int sentryLogs;
  final int files;

  const CleanupPreview({
    this.appLoads = 0,
    this.logs = 0,
    this.userLogs = 0,
    this.sentryLogs = 0,
    this.files = 0,
  });

  int get totalDatabaseRecords => appLoads + logs + userLogs + sentryLogs;

  bool get isEmpty =>
      appLoads == 0 &&
      logs == 0 &&
      userLogs == 0 &&
      sentryLogs == 0 &&
      files == 0;
}

class CleanupSummary {
  final int removedLoads;
  final int removedLogs;
  final int removedUserLogs;
  final int removedSentryLogs;
  final int removedFiles;

  const CleanupSummary({
    this.removedLoads = 0,
    this.removedLogs = 0,
    this.removedUserLogs = 0,
    this.removedSentryLogs = 0,
    this.removedFiles = 0,
  });
}
