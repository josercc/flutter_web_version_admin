import 'package:dart_appwrite/client_io.dart';
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
}

/// 自定义 Appwrite 客户端，用于捕获接口限速信息
class AppwriteClient extends ClientIO {
  AppwriteRateLimit? _rateLimit;

  AppwriteRateLimit? get rateLimit => _rateLimit;

  AppwriteClient()
      : super(
          endPoint: 'https://appwrite.winnermedical.com/v1',
          selfSigned: false,
        ) {
    setProject('677f626b0012252b422e');
  }

  @override
  Future<http.Response> toResponse(http.StreamedResponse streamedResponse) {
    final headers = streamedResponse.headers;
    final limitStr =
        headers['x-ratelimit-limit'] ?? headers['X-RateLimit-Limit'];
    final remainingStr =
        headers['x-ratelimit-remaining'] ?? headers['X-RateLimit-Remaining'];
    final resetStr =
        headers['x-ratelimit-reset'] ?? headers['X-RateLimit-Reset'];

    if (limitStr != null && remainingStr != null && resetStr != null) {
      final limit = int.tryParse(limitStr);
      final remaining = int.tryParse(remainingStr);
      final reset = int.tryParse(resetStr);

      if (limit != null && remaining != null && reset != null) {
        _rateLimit = AppwriteRateLimit(
          limit: limit,
          remaining: remaining,
          reset: reset,
        );
      }
    }

    return super.toResponse(streamedResponse);
  }
}
