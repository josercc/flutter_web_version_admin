import 'dart:async';

/// 接口类型枚举
enum ApiEndpointType {
  deleteDocument, // 删除文档
  deleteFile, // 删除文件
  listDocuments, // 查询文档列表
  createDocument, // 创建文档
  updateDocument, // 更新文档
  other, // 其他接口
}

/// 速率限制信息
class RateLimitInfo {
  final int limit;
  final int remaining;
  final int resetTime; // UTC epoch 秒数

  RateLimitInfo({
    required this.limit,
    required this.remaining,
    required this.resetTime,
  });

  /// 从 HTTP header 解析速率限制信息
  static RateLimitInfo? fromHeaders(Map<String, String> headers) {
    final limitStr =
        headers['x-ratelimit-limit'] ?? headers['X-RateLimit-Limit'];
    final remainingStr =
        headers['x-ratelimit-remaining'] ?? headers['X-RateLimit-Remaining'];
    final resetStr =
        headers['x-ratelimit-reset'] ?? headers['X-RateLimit-Reset'];

    if (limitStr == null || remainingStr == null || resetStr == null) {
      return null;
    }

    final limit = int.tryParse(limitStr);
    final remaining = int.tryParse(remainingStr);
    final resetTime = int.tryParse(resetStr);

    if (limit == null || remaining == null || resetTime == null) {
      return null;
    }

    return RateLimitInfo(
      limit: limit,
      remaining: remaining,
      resetTime: resetTime,
    );
  }

  /// 获取重置时间的 DateTime 对象
  DateTime get resetDateTime => DateTime.fromMillisecondsSinceEpoch(
        resetTime * 1000,
        isUtc: true,
      );

  /// 获取距离重置的秒数
  int get secondsUntilReset {
    final now = DateTime.now().toUtc();
    final reset = resetDateTime;
    final diff = reset.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// 是否需要等待（剩余次数为 0 或接近 0）
  bool get needsWait => remaining <= 0;

  @override
  String toString() {
    return 'RateLimitInfo(limit: $limit, remaining: $remaining, resetTime: $resetTime)';
  }
}

/// 速率限制处理器（单个接口类型）
class SingleRateLimitHandler {
  RateLimitInfo? _currentRateLimit;
  final Function(String) logCallback;
  final ApiEndpointType endpointType;

  SingleRateLimitHandler({
    required this.logCallback,
    required this.endpointType,
  });

  /// 更新速率限制信息
  void updateRateLimit(RateLimitInfo? info, {bool showLog = true}) {
    _currentRateLimit = info;
    if (info != null && showLog) {
      final typeName = _getEndpointTypeName(endpointType);
      logCallback(
          '[$typeName] 限速信息: 剩余 ${info.remaining}/${info.limit} 次，重置时间: ${_formatDateTime(info.resetDateTime)}');
    }
  }

  /// 获取当前速率限制信息
  RateLimitInfo? get currentRateLimit => _currentRateLimit;

  /// 检查并等待速率限制重置（如果需要）
  /// 返回是否需要等待，如果返回true表示已经等待完成
  Future<bool> checkAndWaitIfNeeded({
    int? minRemaining, // 最小剩余次数阈值，低于此值则等待
  }) async {
    if (_currentRateLimit == null) {
      // 没有速率限制信息，无法检查，直接返回false表示未等待
      return false;
    }

    final info = _currentRateLimit!;
    final threshold = minRemaining ?? 1;
    final typeName = _getEndpointTypeName(endpointType);

    // 先显示当前限速信息
    logCallback(
        '[$typeName] 限速信息: 剩余 ${info.remaining}/${info.limit} 次，重置时间: ${_formatDateTime(info.resetDateTime)}');
    
    if (info.remaining < threshold) {
      final secondsToWait = info.secondsUntilReset;
      if (secondsToWait > 0) {
        logCallback(
            '[$typeName] 剩余次数低于阈值 $threshold，等待 ${secondsToWait} 秒直到重置');

        // 显示等待进度
        for (int i = secondsToWait; i > 0; i--) {
          await Future.delayed(const Duration(seconds: 1));
          if (i % 10 == 0 || i <= 5) {
            logCallback(
                '[$typeName] 等待中... 剩余 ${i} 秒（将在 ${_formatDateTime(info.resetDateTime)} 重置）');
          }
        }

        // 多等1秒确保重置
        await Future.delayed(const Duration(seconds: 1));
        logCallback('[$typeName] 等待完成，速率限制已重置');
        return true; // 已等待完成
      } else {
        // 重置时间已过，可以继续
        logCallback('[$typeName] 速率限制重置时间已过，可以继续');
        return false;
      }
    } else {
      // 不需要等待，已经在上面显示了限速信息
      return false; // 不需要等待
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

  /// 格式化日期时间
  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  }
}

/// 多接口速率限制管理器
class RateLimitHandler {
  final Map<ApiEndpointType, SingleRateLimitHandler> _handlers = {};
  final Function(String) logCallback;

  RateLimitHandler({required this.logCallback});

  /// 获取指定接口类型的速率限制处理器
  SingleRateLimitHandler getHandler(ApiEndpointType type) {
    if (!_handlers.containsKey(type)) {
      _handlers[type] = SingleRateLimitHandler(
        logCallback: logCallback,
        endpointType: type,
      );
    }
    return _handlers[type]!;
  }

  /// 更新指定接口类型的速率限制信息
  void updateRateLimit(ApiEndpointType type, RateLimitInfo? info, {bool showLog = true}) {
    getHandler(type).updateRateLimit(info, showLog: showLog);
  }

  /// 获取指定接口类型的当前速率限制信息
  RateLimitInfo? getCurrentRateLimit(ApiEndpointType type) {
    return getHandler(type).currentRateLimit;
  }

  /// 检查并等待指定接口类型的速率限制重置（如果需要）
  /// 返回是否需要等待，如果返回true表示已经等待完成
  Future<bool> checkAndWaitIfNeeded({
    required ApiEndpointType type,
    int? minRemaining, // 最小剩余次数阈值，低于此值则等待
  }) async {
    return await getHandler(type)
        .checkAndWaitIfNeeded(minRemaining: minRemaining);
  }

  /// 获取所有接口类型的速率限制状态（用于调试）
  Map<ApiEndpointType, RateLimitInfo?> getAllRateLimits() {
    final result = <ApiEndpointType, RateLimitInfo?>{};
    for (final type in ApiEndpointType.values) {
      result[type] = getHandler(type).currentRateLimit;
    }
    return result;
  }
}
