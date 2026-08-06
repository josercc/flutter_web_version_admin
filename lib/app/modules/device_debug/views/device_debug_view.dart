import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../commons/remote_debug/remote_debug_protocol.dart';
import '../controllers/device_debug_controller.dart';

class DeviceDebugView extends GetView<DeviceDebugController> {
  const DeviceDebugView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('远程调试流'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_outline),
            onPressed: controller.clearAll,
          ),
          IconButton(
            tooltip: '重连',
            icon: const Icon(Icons.refresh),
            onPressed: controller.connect,
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(() => _buildStatusBar()),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 280, child: _buildDeviceList()),
                const VerticalDivider(width: 1),
                Expanded(child: _buildTabs()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final state = controller.linkState.value;
    Color color;
    String label;
    switch (state) {
      case NtfyLinkState.connected:
        color = Colors.green;
        label = '已连接';
        break;
      case NtfyLinkState.connecting:
      case NtfyLinkState.reconnecting:
        color = Colors.orange;
        label = state == NtfyLinkState.connecting ? '连接中' : '重连中';
        break;
      case NtfyLinkState.disconnected:
        color = Colors.red;
        label = '已断开';
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              controller.statusMessage.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          if (controller.currentStreamTopic.value != null)
            Text(
              controller.currentStreamTopic.value!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Obx(() {
      final list = controller.onlineDevices;
      final all = controller.devices.values.toList()
        ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
      final show = list.isNotEmpty ? list : all;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '在线源 (${list.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: show.isEmpty
                ? const Center(
                    child: Text('等待 App 开启远程调试…', textAlign: TextAlign.center),
                  )
                : ListView.builder(
                    itemCount: show.length,
                    itemBuilder: (context, index) {
                      final d = show[index];
                      final selected =
                          controller.selectedDeviceId.value == d.deviceId;
                      return ListTile(
                        selected: selected,
                        selectedTileColor: Colors.blue.shade50,
                        leading: Icon(
                          Icons.circle,
                          size: 12,
                          color: d.online ? Colors.green : Colors.grey,
                        ),
                        title: Text(d.listTitle, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          [
                            if (d.platform != null) d.platform!,
                            if (d.appVersion != null) d.appVersion!,
                            d.deviceId.length > 12
                                ? '${d.deviceId.substring(0, 12)}…'
                                : d.deviceId,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => controller.selectDevice(d),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildTabs() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '日志'),
              Tab(text: '请求'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLogTab(),
                _buildHttpTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '过滤日志',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.logFilter.value = v,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '复制全部可见',
                onPressed: () {
                  final text = controller.filteredLogs
                      .map((e) => e.copyText)
                      .join('\n\n');
                  controller.copyText(text);
                },
                icon: const Icon(Icons.copy_all),
              ),
              IconButton(
                tooltip: '导出 JSONL',
                onPressed: controller.exportLogsJsonl,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: '清空日志',
                onPressed: controller.clearLogs,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final items = controller.filteredLogs;
            if (items.isEmpty) {
              return const Center(child: Text('暂无日志'));
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final e = items[index];
                final color = switch (e.level) {
                  'e' || 'E' || 'error' => Colors.red.shade700,
                  'w' || 'W' || 'warning' => Colors.orange.shade800,
                  _ => Colors.grey.shade800,
                };
                return Material(
                  color: Colors.white,
                  elevation: 0.5,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: color, width: 4),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateTime.fromMillisecondsSinceEpoch(e.ts)
                                  .toIso8601String()
                                  .substring(11, 23),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              e.level.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: '复制本条',
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () =>
                                  controller.copyText(e.copyText),
                            ),
                          ],
                        ),
                        SelectableText(
                          e.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHttpTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '按 URL 过滤',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.httpFilter.value = v,
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => FilterChip(
                  label: const Text('仅失败'),
                  selected: controller.onlyFailedHttp.value,
                  onSelected: (v) => controller.onlyFailedHttp.value = v,
                ),
              ),
              IconButton(
                tooltip: '导出 JSONL',
                onPressed: controller.exportHttpsJsonl,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: '清空请求',
                onPressed: controller.clearHttps,
                icon: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final items = controller.filteredHttps;
            if (items.isEmpty) {
              return const Center(child: Text('暂无请求'));
            }
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) => _HttpTile(entry: items[index]),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    final urlCtrl = TextEditingController(text: controller.baseUrl.value);
    final tokenCtrl = TextEditingController(text: controller.accessToken.value);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ntfy 设置'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              TextField(
                controller: tokenCtrl,
                decoration: const InputDecoration(labelText: 'Access Token'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存并重连'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await controller.saveSettings(
        url: urlCtrl.text,
        token: tokenCtrl.text,
      );
    }
  }
}

class _HttpTile extends StatelessWidget {
  const _HttpTile({required this.entry});

  final DebugHttpEntry entry;

  @override
  Widget build(BuildContext context) {
    final Color bar;
    if (entry.error != null && entry.statusCode == null) {
      bar = Colors.grey.shade700;
    } else if (entry.ok) {
      bar = Colors.green;
    } else {
      bar = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: bar, width: 4)),
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _HttpDetailDrawer.show(context, entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.method}  ${entry.url}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (entry.statusCode != null) '${entry.statusCode}',
                    if (entry.durationMs != null) '${entry.durationMs}ms',
                    if (entry.error != null) entry.error!,
                    DateTime.fromMillisecondsSinceEpoch(entry.ts)
                        .toIso8601String()
                        .substring(11, 19),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: bar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HttpDetailDrawer {
  static Future<void> show(BuildContext context, DebugHttpEntry entry) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 720 ? width * 0.92 : width * 0.45;
    final clamped = panelWidth.clamp(360.0, 640.0);

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭请求详情',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            elevation: 16,
            color: Colors.white,
            child: SizedBox(
              width: clamped.toDouble(),
              height: double.infinity,
              child: _HttpDetailPanel(entry: entry),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}

class _HttpDetailPanel extends StatelessWidget {
  const _HttpDetailPanel({required this.entry});

  final DebugHttpEntry entry;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DeviceDebugController>();
    final Color statusColor;
    if (entry.error != null && entry.statusCode == null) {
      statusColor = Colors.grey.shade700;
    } else if (entry.ok) {
      statusColor = Colors.green.shade700;
    } else {
      statusColor = Colors.red.shade700;
    }

    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        entry.method,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (entry.statusCode != null)
                      Text(
                        '${entry.statusCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    if (entry.durationMs != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${entry.durationMs}ms',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: '复制本请求',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => controller.copyText(entry.copyText),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  entry.url,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (entry.error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.error!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  DateTime.fromMillisecondsSinceEpoch(entry.ts)
                      .toIso8601String(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: '概览'),
                    Tab(text: '请求头'),
                    Tab(text: '请求体'),
                    Tab(text: '响应头'),
                    Tab(text: '响应体'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _overviewTab(),
                _bodyTab(_formatMap(entry.requestHeaders)),
                _bodyTab(entry.requestBody ?? '(empty)'),
                _bodyTab(_formatMap(entry.responseHeaders)),
                _bodyTab(entry.responseBody ?? '(empty)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    final rows = <MapEntry<String, String>>[
      MapEntry('Method', entry.method),
      MapEntry('URL', entry.url),
      if (entry.path != null && entry.path!.isNotEmpty)
        MapEntry('Path', entry.path!),
      MapEntry('Status', entry.statusCode?.toString() ?? '-'),
      MapEntry('OK', entry.ok.toString()),
      MapEntry(
        'Duration',
        entry.durationMs != null ? '${entry.durationMs}ms' : '-',
      ),
      MapEntry(
        'Time',
        DateTime.fromMillisecondsSinceEpoch(entry.ts).toIso8601String(),
      ),
      if (entry.error != null) MapEntry('Error', entry.error!),
      if (entry.deviceId != null) MapEntry('Device', entry.deviceId!),
      if (entry.userId != null) MapEntry('User', entry.userId!),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  row.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(
                child: SelectableText(
                  row.value,
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bodyTab(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        content,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.45,
        ),
      ),
    );
  }

  String _formatMap(Map<String, String> map) {
    if (map.isEmpty) return '(empty)';
    return map.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }
}
