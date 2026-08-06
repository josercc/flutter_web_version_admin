import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// 从本地 `.env` 加载配置，并合并系统环境变量。
class EnvConfig {
  static DotEnv? _dotenv;
  static String? _loadedPath;

  /// 已加载的 .env 文件路径（未找到则为 null）
  static String? get loadedPath => _loadedPath;

  /// 依次尝试以下路径加载 `.env`：
  /// 1. 当前工作目录
  /// 2. `tools/log_cleanup_cli/.env`（从仓库根目录运行时）
  static void loadLocalEnv() {
    if (_dotenv != null) return;

    final candidates = <String>[
      '.env',
      'tools/log_cleanup_cli/.env',
    ];

    _dotenv = DotEnv(quiet: true);

    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;

      _dotenv!.load([path]);
      _loadedPath = file.absolute.path;
      return;
    }
  }

  /// 读取配置项：优先 `.env`，其次系统环境变量。
  static String? get(String key) {
    final fromDotenv = _dotenv?[key];
    if (fromDotenv != null && fromDotenv.isNotEmpty) {
      return fromDotenv;
    }
    final fromPlatform = Platform.environment[key];
    if (fromPlatform != null && fromPlatform.isNotEmpty) {
      return fromPlatform;
    }
    return null;
  }
}
