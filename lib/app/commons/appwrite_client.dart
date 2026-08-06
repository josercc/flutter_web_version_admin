import 'package:appwrite/src/client_io.dart';
import 'package:darty_json_safe/darty_json_safe.dart';
import 'package:http/http.dart' as http;

/// Appwrite 限速信息
class AppwriteRateLimit {
  final int limit;
  final int remaining;
  final int reset;

  AppwriteRateLimit({
    required this.limit,
    required this.remaining,
    required this.reset,
  });

  @override
  String toString() {
    return 'AppwriteRateLimit(limit: $limit, remaining: $remaining, reset: $reset)';
  }
}

/// 自定义 Appwrite 客户端，用于捕获接口限速信息
///
/// 这个类可以直接替换标准的 Client 类使用
class AppwriteClient extends ClientIO {
  /// 当前限速信息（最新一次响应的限速信息）
  AppwriteRateLimit? _rateLimit;

  /// 获取当前限速信息
  AppwriteRateLimit? get rateLimit => _rateLimit;

  AppwriteClient() {
    setEndpoint('https://appwrite.winnermedical.com/v1');
    setProject('677f626b0012252b422e');
    // 设置安全配置
    setSelfSigned(status: false); // 确保使用 HTTPS
  }

  @override
  Future<http.Response> toResponse(http.StreamedResponse streamedResponse) {
    // 从响应头中提取限速信息
    final headers = streamedResponse.headers;
    final limitStr =
        headers['x-ratelimit-limit'] ?? headers['X-RateLimit-Limit'];
    final remainingStr =
        headers['x-ratelimit-remaining'] ?? headers['X-RateLimit-Remaining'];
    final resetStr =
        headers['x-ratelimit-reset'] ?? headers['X-RateLimit-Reset'];

    if (limitStr != null && remainingStr != null && resetStr != null) {
      // 使用 darty_json_safe 解析整数值
      final limit = JSON(limitStr).int;
      final remaining = JSON(remainingStr).int;
      final reset = JSON(resetStr).int;

      if (limit != null && remaining != null && reset != null) {
        // 只更新当前限速信息，不基于 URL 存储
        // 限速信息应该通过 RateLimitHandler 基于接口类型来管理
        _rateLimit = AppwriteRateLimit(
          limit: limit,
          remaining: remaining,
          reset: reset,
        );
      }
    }

    return http.Response.fromStream(streamedResponse);
  }
}
