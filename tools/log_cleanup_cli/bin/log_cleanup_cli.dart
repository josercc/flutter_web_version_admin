import 'dart:io';

import 'package:log_cleanup_cli/env_config.dart';
import 'package:log_cleanup_cli/log_cleanup_service.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    _printUsage();
    exit(args.isEmpty ? 1 : 0);
  }

  EnvConfig.loadLocalEnv();

  final parsed = _parseArgs(args);
  final command = parsed.command;

  if (command == null) {
    stderr.writeln('错误: 缺少命令，请使用 count、delete 或 interactive');
    _printUsage();
    exit(1);
  }

  final apiKey = parsed.apiKey ?? EnvConfig.get('APPWRITE_API_KEY');

  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('错误: 未找到 API Key');
    stderr.writeln('请在 tools/log_cleanup_cli/.env 中配置 APPWRITE_API_KEY');
    stderr.writeln('（可复制 .env.example 为 .env 后填写）');
    stderr.writeln('或使用 --api-key / 系统环境变量 APPWRITE_API_KEY');
    exit(1);
  }

  final service = LogCleanupService(
    logCallback: (message) => stdout.writeln(message),
  );
  try {
    if (EnvConfig.loadedPath != null) {
      stdout.writeln('已加载配置: ${EnvConfig.loadedPath}');
    }
    service.authenticate(apiKey: apiKey);

    switch (command) {
      case 'count':
        await _runCount(service, parsed.days);
      case 'delete':
        await _runDelete(service, parsed.days, parsed.skipConfirm);
      case 'interactive':
        await _runInteractive(service);
      default:
        stderr.writeln('错误: 未知命令 "$command"');
        _printUsage();
        exit(1);
    }
  } catch (e) {
    stderr.writeln('执行失败: $e');
    exit(1);
  }
}

void _printPreview(CleanupPreview preview, int days, DateTime cutoff) {
  stdout.writeln('');
  stdout.writeln('待删除统计（$days 天之前，截止 ${cutoff.toLocal()}，按创建时间）');
  stdout.writeln('----------------------------------------');
  stdout.writeln('启动记录:     ${preview.appLoads} 条');
  stdout.writeln('日志文档:     ${preview.logs} 条');
  stdout.writeln('用户日志:     ${preview.userLogs} 条');
  stdout.writeln('Sentry 日志:  ${preview.sentryLogs} 条');
  stdout.writeln('存储文件:     ${preview.files} 个');
  stdout.writeln('数据库合计:   ${preview.totalDatabaseRecords} 条');
  stdout.writeln('----------------------------------------');
}

Future<void> _runCount(LogCleanupService service, int? days) async {
  if (days == null || days <= 0) {
    stderr.writeln('错误: count 命令需要指定大于 0 的天数');
    exit(1);
  }

  final preview = await service.previewCleanupBeforeDays(days);
  final cutoff = service.cutoffBeforeDays(days);

  if (preview.isEmpty) {
    stdout.writeln('');
    stdout.writeln('未找到 $days 天之前的数据。');
    return;
  }

  _printPreview(preview, days, cutoff);
  stdout.writeln('');
  stdout.writeln('执行删除: dart run log_cleanup_cli delete $days');
}

Future<void> _runDelete(
  LogCleanupService service,
  int? days,
  bool skipConfirm,
) async {
  if (days == null || days <= 0) {
    stderr.writeln('错误: delete 命令需要指定大于 0 的天数');
    exit(1);
  }

  final preview = await service.previewCleanupBeforeDays(days);
  final cutoff = service.cutoffBeforeDays(days);

  if (preview.isEmpty) {
    stdout.writeln('未找到 $days 天之前的数据，无需删除。');
    return;
  }

  _printPreview(preview, days, cutoff);

  if (!skipConfirm) {
    stdout.writeln('');
    stdout.writeln('将删除以上数据库记录及存储文件。');
    stdout.write('输入 yes 确认删除: ');
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input != 'yes') {
      stdout.writeln('已取消删除。');
      return;
    }
  }

  stdout.writeln('');
  stdout.writeln('开始删除...');
  final summary = await service.deleteBeforeDays(days);

  stdout.writeln('');
  stdout.writeln('删除结果');
  stdout.writeln('----------------------------------------');
  stdout.writeln('启动记录:     ${summary.removedLoads} 条');
  stdout.writeln('日志文档:     ${summary.removedLogs} 条');
  stdout.writeln('用户日志:     ${summary.removedUserLogs} 条');
  stdout.writeln('Sentry 日志:  ${summary.removedSentryLogs} 条');
  stdout.writeln('存储文件:     ${summary.removedFiles} 个');
  stdout.writeln('----------------------------------------');
}

Future<void> _runInteractive(LogCleanupService service) async {
  stdout.writeln('日志清理交互模式（输入 q 退出）');
  stdout.writeln('已使用 API Key 认证');

  while (true) {
    stdout.write('\n请输入天数（例如 30），或输入 q 退出: ');
    final input = stdin.readLineSync()?.trim();
    if (input == null || input.toLowerCase() == 'q') {
      stdout.writeln('已退出。');
      return;
    }

    final days = int.tryParse(input);
    if (days == null || days <= 0) {
      stdout.writeln('请输入有效的正整数天数。');
      continue;
    }

    try {
      final preview = await service.previewCleanupBeforeDays(days);
      if (preview.isEmpty) {
        stdout.writeln('$days 天之前没有可删除的数据。');
        continue;
      }

      _printPreview(preview, days, service.cutoffBeforeDays(days));

      stdout.write('是否删除？输入 yes 确认: ');
      final confirm = stdin.readLineSync()?.trim().toLowerCase();
      if (confirm != 'yes') {
        stdout.writeln('已跳过删除。');
        continue;
      }

      stdout.writeln('开始删除...');
      await service.deleteBeforeDays(days);
    } catch (e) {
      stderr.writeln('操作失败: $e');
    }
  }
}

void _printUsage() {
  stdout.writeln('''
日志清理 CLI — 按创建时间统计并删除 Appwrite 历史日志（数据库 + 存储文件）

用法:
  dart run log_cleanup_cli <command> [options]

命令:
  count <days>       统计指定天数之前（按 \$createdAt）待删除的记录与文件数量
  delete <days>      先展示统计，确认后按创建时间删除各表数据及存储文件
  interactive        交互模式，循环输入天数统计/删除

选项:
  --api-key, -k      Appwrite API Key（覆盖 .env 中的配置）
  --yes, -y          删除时跳过确认（仅 delete 命令）
  --help, -h         显示帮助

配置（优先级从高到低）:
  1. 命令行 --api-key
  2. 本地 .env 中的 APPWRITE_API_KEY
  3. 系统环境变量 APPWRITE_API_KEY

示例:
  dart pub get
  dart run log_cleanup_cli count 30
  dart run log_cleanup_cli delete 30 --yes
  dart run log_cleanup_cli interactive
''');
}

class _ParsedArgs {
  final String? command;
  final int? days;
  final String? apiKey;
  final bool skipConfirm;

  const _ParsedArgs({
    this.command,
    this.days,
    this.apiKey,
    this.skipConfirm = false,
  });
}

_ParsedArgs _parseArgs(List<String> args) {
  String? command;
  int? days;
  String? apiKey;
  var skipConfirm = false;

  final positional = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--api-key':
      case '-k':
        if (i + 1 < args.length) apiKey = args[++i];
      case '--yes':
      case '-y':
        skipConfirm = true;
      case '--help':
      case '-h':
        break;
      default:
        if (arg.startsWith('-')) {
          stderr.writeln('警告: 忽略未知选项 $arg');
        } else {
          positional.add(arg);
        }
    }
  }

  if (positional.isNotEmpty) {
    command = positional.first;
    if (positional.length >= 2) {
      days = int.tryParse(positional[1]);
    }
  }

  return _ParsedArgs(
    command: command,
    days: days,
    apiKey: apiKey,
    skipConfirm: skipConfirm,
  );
}
