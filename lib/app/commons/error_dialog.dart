import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// 以可复制内容的 Dialog 展示错误信息。
Future<void> showCopyableErrorDialog({
  required String title,
  required Object error,
  StackTrace? stackTrace,
  String? context,
}) async {
  final message = _formatErrorMessage(
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  // ignore: avoid_print
  print('[ErrorDialog] $title\n$message');

  await Get.dialog<void>(
    AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: SingleChildScrollView(
            child: SelectableText(
              message,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: message));
            Get.snackbar('成功', '已复制错误信息');
          },
          child: const Text('复制'),
        ),
        ElevatedButton(
          onPressed: () => Get.back(),
          child: const Text('关闭'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

String _formatErrorMessage({
  required Object error,
  StackTrace? stackTrace,
  String? context,
}) {
  final buffer = StringBuffer();

  if (context != null && context.trim().isNotEmpty) {
    buffer.writeln(context.trim());
    buffer.writeln();
  }

  if (error is AppwriteException) {
    buffer.writeln('AppwriteException');
    if (error.type != null) buffer.writeln('type: ${error.type}');
    if (error.code != null) buffer.writeln('code: ${error.code}');
    buffer.writeln('message: ${error.message ?? error.toString()}');
  } else {
    buffer.writeln(error.runtimeType.toString());
    buffer.writeln(error.toString());
  }

  if (stackTrace != null) {
    buffer.writeln();
    buffer.writeln('StackTrace:');
    buffer.writeln(stackTrace.toString());
  }

  return buffer.toString().trimRight();
}
