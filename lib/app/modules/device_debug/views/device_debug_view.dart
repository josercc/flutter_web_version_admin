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
                SizedBox(width: 480, child: _buildDeviceList()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final env = controller.listFilterEnv.value;
                return SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('全部')),
                    ButtonSegment(
                      value: RemoteDebugProtocol.envSit,
                      label: Text('测试'),
                    ),
                    ButtonSegment(
                      value: RemoteDebugProtocol.envProd,
                      label: Text('生产'),
                    ),
                  ],
                  selected: {env},
                  onSelectionChanged: (s) {
                    controller.listFilterEnv.value = s.first;
                  },
                );
              }),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '用户 ID',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => controller.listFilterUserId.value = v,
              ),
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '设备 ID',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => controller.listFilterDeviceId.value = v,
              ),
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '机型',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => controller.listFilterModel.value = v,
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            final online = controller.onlineDevices;
            final reporting = controller.reportingOnlineDevices;
            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDeviceColumn(
                    title: '调试中 (${reporting.length})',
                    devices: reporting,
                    emptyHint: '暂无正在发送日志的设备\n可在下方在线列表点「打开调试」',
                    accent: Colors.orange,
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade300),
                Expanded(
                  flex: 3,
                  child: _buildDeviceColumn(
                    title: '全部在线 (${online.length})',
                    devices: online,
                    emptyHint: '暂无在线设备',
                    accent: Colors.green,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDeviceColumn({
    required String title,
    required List<DevicePresence> devices,
    required String emptyHint,
    Color accent = Colors.green,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: accent,
            ),
          ),
        ),
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      emptyHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final d = devices[index];
                    return Obx(() {
                      final selected =
                          controller.selectedDeviceId.value == d.deviceId;
                      return ListTile(
                        key: ValueKey('$title-${d.deviceId}'),
                        selected: selected,
                        selectedTileColor: Colors.blue.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: d.reportingEnabled
                              ? Colors.orange
                              : Colors.green,
                        ),
                        title: Text(
                          d.listTitle,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            d.envLabel,
                            d.reportingEnabled ? '调试中' : '在线',
                            if (d.displayModel != null) d.displayModel!,
                            if (d.displayOs != null) d.displayOs!,
                            if (d.appVersion != null) d.appVersion!,
                            '设备 ${d.deviceId}',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: d.reportingEnabled
                            ? TextButton(
                                onPressed: () => controller.closeDebug(d),
                                child: const Text(
                                  '关闭',
                                  style: TextStyle(fontSize: 12),
                                ),
                              )
                            : TextButton(
                                onPressed: () => controller.openDebug(d),
                                child: const Text(
                                  '打开调试',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                        onTap: () => controller.selectDevice(d),
                      );
                    });
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Obx(() {
            final sid = controller.viewingSessionId.value;
            if (sid == null || sid.isEmpty) {
              return const SizedBox.shrink();
            }
            return Material(
              color: Colors.amber.shade50,
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.archive_outlined, size: 18),
                title: Text(
                  '正在查看本地会话 $sid（非实时流）',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () {
                    controller.clearAll();
                    controller.statusMessage.value = '已退出会话回放';
                  },
                  child: const Text('退出回放'),
                ),
              ),
            );
          }),
          const TabBar(
            tabs: [
              Tab(text: '日志'),
              Tab(text: '请求'),
              Tab(text: '本地会话'),
              Tab(text: '设备信息'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLogTab(),
                _buildHttpTab(),
                _buildLocalSessionsTab(),
                _buildDeviceInfoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalSessionsTab() {
    return Obx(() {
      final d = controller.selectedDevice;
      if (d == null) {
        return const Center(child: Text('请先选择左侧设备'));
      }
      if (!d.reportingEnabled) {
        return const Center(child: Text('请先打开调试后再拉取本地会话'));
      }
      final loading = controller.localSessionsLoading.value;
      final fetching = controller.localSessionFetchingId.value;
      final sessions = controller.localSessions;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '设备本地最近启动归档（最多 ${RemoteDebugProtocol.maxLocalSessions} 次）',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: loading ? null : controller.refreshLocalSessions,
                  icon: loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(loading ? '拉取中…' : '刷新列表'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      loading ? '等待设备返回…' : '暂无会话，点击刷新列表',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final busy = fetching == s.id;
                      return ListTile(
                        title: Text(
                          s.id,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          [
                            s.startedLabel,
                            if (s.env != null && s.env!.isNotEmpty)
                              RemoteDebugProtocol.envLabel(s.env),
                            '日志 ${s.logLines}',
                            '请求 ${s.httpLines}',
                            s.sizeLabel,
                            if (s.appVersion != null && s.appVersion!.isNotEmpty)
                              s.appVersion!,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: TextButton(
                          onPressed: busy || fetching != null
                              ? null
                              : () => controller.fetchLocalSession(s.id),
                          child: Text(busy ? '拉取中…' : '拉取并查看'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  Widget _buildDeviceInfoTab() {
    return Obx(() {
      final d = controller.selectedDevice;
      if (d == null) {
        return const Center(child: Text('请先选择左侧设备'));
      }

      // Merge envelope-level identity so the panel always shows core fields.
      final merged = <String, String>{
        'deviceId': d.deviceId,
        if (d.userId != null && d.userId!.isNotEmpty) 'userId': d.userId!,
        if (d.launchId != null && d.launchId!.isNotEmpty)
          'launchId': d.launchId!,
        if (d.appVersion != null && d.appVersion!.isNotEmpty)
          'appVersion': d.appVersion!,
        if (d.platform != null && d.platform!.isNotEmpty)
          'platform': d.platform!,
        ...d.deviceInfo,
      };
      final view = DevicePresence(
        deviceId: d.deviceId,
        userId: d.userId,
        lastSeen: d.lastSeen,
        appVersion: d.appVersion,
        platform: d.platform,
        launchId: d.launchId,
        online: d.online,
        deviceInfo: merged,
      );

      final q = controller.deviceInfoFilter.value.trim().toLowerCase();
      var sections = view.deviceInfoSections;
      if (q.isNotEmpty) {
        sections = sections
            .map(
              (s) => DeviceInfoSection(
                title: s.title,
                entries: s.entries
                    .where(
                      (e) =>
                          e.key.toLowerCase().contains(q) ||
                          e.value.toLowerCase().contains(q),
                    )
                    .toList(),
              ),
            )
            .where((s) => s.entries.isNotEmpty)
            .toList();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    d.listTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '复制全部字段',
                  onPressed: controller.copyDeviceInfo,
                  icon: const Icon(Icons.copy_all),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              [
                if (d.displayModel != null) d.displayModel!,
                if (d.displayOs != null) d.displayOs!,
                if (d.appVersion != null) 'v${d.appVersion}',
                if (merged.isNotEmpty) '${merged.length} 字段',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '过滤字段名 / 值',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => controller.deviceInfoFilter.value = v,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: d.deviceInfo.isEmpty && merged.length <= 3
                ? const Center(
                    child: Text(
                      '暂无 Sentry 设备字段\n等待 App 下一次 presence 心跳…',
                      textAlign: TextAlign.center,
                    ),
                  )
                : sections.isEmpty
                    ? const Center(child: Text('无匹配字段'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: sections.length,
                        itemBuilder: (context, sectionIndex) {
                          final section = sections[sectionIndex];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: sectionIndex == 0 ? 4 : 16,
                                  bottom: 6,
                                ),
                                child: Text(
                                  section.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              ...section.entries.map((e) {
                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        child: SelectableText(
                                          e.key,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: SelectableText(
                                          e.value.isEmpty
                                              ? '(empty)'
                                              : e.value,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.35,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: '复制',
                                        icon: const Icon(Icons.copy, size: 16),
                                        onPressed: () => controller.copyText(
                                          '${e.key}: ${e.value}',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
          ),
        ],
      );
    });
  }

  Widget _buildLogTab() {
    final initialLevel = controller.logLevelFilter.value;
    final initialIndex = switch (initialLevel) {
      'error' => 1,
      'warning' => 2,
      'info' => 3,
      'debug' => 4,
      _ => 0,
    };
    return DefaultTabController(
      length: 5,
      initialIndex: initialIndex,
      child: Column(
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
                  tooltip: '导出日志到文件',
                  onPressed: controller.exportLogs,
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
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) {
              controller.logLevelFilter.value = switch (index) {
                1 => 'error',
                2 => 'warning',
                3 => 'info',
                4 => 'debug',
                _ => 'all',
              };
            },
            tabs: const [
              Tab(text: '全部'),
              Tab(text: 'Error'),
              Tab(text: 'Warning'),
              Tab(text: 'Info'),
              Tab(text: 'Debug'),
            ],
          ),
          Expanded(
            child: Obx(() {
              final items = controller.filteredLogs;
              if (items.isEmpty) {
                return const Center(child: Text('暂无日志'));
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final e = items[index];
                  final color = switch (e.levelKind) {
                    'error' => Colors.red.shade700,
                    'warning' => Colors.orange.shade800,
                    'info' => Colors.blue.shade700,
                    _ => Colors.grey.shade800,
                  };
                  final tag = e.tag?.trim();
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
                              _SourceBadge(isUnity: e.isUnity),
                              const SizedBox(width: 8),
                              Text(
                                e.levelLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              if (tag != null && tag.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _LogTagBadge(tag: tag),
                              ],
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
                          _ExpandableLogMessage(
                            key: ValueKey('${e.ts}_${e.message.hashCode}'),
                            message: e.message,
                            color: color,
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
      ),
    );
  }

  Widget _buildHttpTab() {
    final initialSource = controller.httpSourceFilter.value;
    final initialIndex = switch (initialSource) {
      RemoteDebugProtocol.sourceFlutter => 1,
      RemoteDebugProtocol.sourceUnity => 2,
      _ => 0,
    };
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Column(
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
                  tooltip: '导出请求到文件',
                  onPressed: controller.exportHttps,
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
          TabBar(
            onTap: (index) {
              controller.httpSourceFilter.value = switch (index) {
                1 => RemoteDebugProtocol.sourceFlutter,
                2 => RemoteDebugProtocol.sourceUnity,
                _ => 'all',
              };
            },
            tabs: const [
              Tab(text: '全部'),
              Tab(text: 'Flutter'),
              Tab(text: 'Unity'),
            ],
          ),
          Expanded(
            child: Obx(() {
              final items = controller.filteredHttps;
              if (items.isEmpty) {
                return const Center(child: Text('暂无请求'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _HttpTile(entry: items[index]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    final controlUrlCtrl =
        TextEditingController(text: controller.controlBaseUrl.value);
    final controlTokenCtrl =
        TextEditingController(text: controller.controlAccessToken.value);
    final streamUrlCtrl =
        TextEditingController(text: controller.streamBaseUrl.value);
    final streamTokenCtrl =
        TextEditingController(text: controller.streamAccessToken.value);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ntfy 设置'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controlUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '在线/指令 Base URL (chat)',
                  ),
                ),
                TextField(
                  controller: controlTokenCtrl,
                  decoration: const InputDecoration(
                    labelText: '在线/指令 Token',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: streamUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: '日志流 Base URL',
                  ),
                ),
                TextField(
                  controller: streamTokenCtrl,
                  decoration: const InputDecoration(
                    labelText: '日志流 Token',
                  ),
                ),
              ],
            ),
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
        url: streamUrlCtrl.text,
        token: streamTokenCtrl.text,
        controlUrl: controlUrlCtrl.text,
        controlToken: controlTokenCtrl.text,
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
    final Color? bg;
    if (entry.error != null && entry.statusCode == null) {
      bar = Colors.grey.shade700;
      bg = null;
    } else if (entry.isBusinessFailure) {
      // Body success == false — amber to stand out from transport errors.
      bar = Colors.amber.shade800;
      bg = Colors.amber.shade50;
    } else if (entry.ok) {
      bar = Colors.green;
      bg = null;
    } else {
      bar = Colors.red;
      bg = Colors.red.shade50;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: bar, width: 4)),
        color: bg ?? Colors.white,
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
                Row(
                  children: [
                    _SourceBadge(isUnity: entry.isUnity),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${entry.method}  ${entry.url}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (entry.statusCode != null) 'HTTP ${entry.statusCode}',
                    if (entry.businessSuccess != null)
                      'success ${entry.businessSuccess}',
                    if (entry.businessCode != null)
                      'code ${entry.businessCode}',
                    if (entry.isBusinessFailure) '业务失败',
                    if (entry.durationMs != null) '${entry.durationMs}ms',
                    if (entry.error != null) entry.error!,
                    DateTime.fromMillisecondsSinceEpoch(entry.ts)
                        .toIso8601String()
                        .substring(11, 19),
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: bar,
                    fontWeight: entry.isBusinessFailure
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogTagBadge extends StatelessWidget {
  const _LogTagBadge({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade800,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.isUnity});

  final bool isUnity;

  @override
  Widget build(BuildContext context) {
    final label = isUnity ? 'Unity' : 'Flutter';
    final color = isUnity ? Colors.deepOrange.shade700 : Colors.blue.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
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
    } else if (entry.isBusinessFailure) {
      statusColor = Colors.amber.shade900;
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
              color: entry.isBusinessFailure
                  ? Colors.amber.shade50
                  : Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _SourceBadge(isUnity: entry.isUnity),
                    const SizedBox(width: 8),
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
                        'HTTP ${entry.statusCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: entry.isBusinessFailure
                              ? Colors.grey.shade700
                              : statusColor,
                        ),
                      ),
                    if (entry.businessSuccess != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: entry.isBusinessFailure
                              ? Colors.amber.shade200
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'success ${entry.businessSuccess}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                    if (entry.businessCode != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'code ${entry.businessCode}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
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
                if (entry.isBusinessFailure) ...[
                  const SizedBox(height: 6),
                  Text(
                    '业务失败：HTTP ${entry.statusCode ?? '-'}，响应 success=false'
                    '${entry.businessCode != null ? '，code=${entry.businessCode}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
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
      MapEntry('Source', entry.sourceLabel),
      MapEntry('Method', entry.method),
      MapEntry('URL', entry.url),
      if (entry.path != null && entry.path!.isNotEmpty)
        MapEntry('Path', entry.path!),
      MapEntry('HTTP Status', entry.statusCode?.toString() ?? '-'),
      if (entry.businessSuccess != null)
        MapEntry('Success', entry.businessSuccess.toString()),
      if (entry.businessCode != null)
        MapEntry('Business Code', entry.businessCode.toString()),
      MapEntry('OK', entry.ok.toString()),
      if (entry.isBusinessFailure)
        const MapEntry('Result', '业务失败 (success ≠ true)'),
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

/// Collapses long log bodies to 3 lines; tap 展开 / 收起 to toggle.
class _ExpandableLogMessage extends StatefulWidget {
  const _ExpandableLogMessage({
    super.key,
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  State<_ExpandableLogMessage> createState() => _ExpandableLogMessageState();
}

class _ExpandableLogMessageState extends State<_ExpandableLogMessage> {
  static const int _maxCollapsedLines = 3;

  bool _expanded = false;

  TextStyle get _style => TextStyle(
        fontSize: 13,
        color: widget.color,
        height: 1.35,
      );

  bool _exceedsMaxLines(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.message, style: _style),
      maxLines: _maxCollapsedLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = _exceedsMaxLines(constraints.maxWidth);
        final showToggle = overflows || _expanded;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_expanded || !overflows)
              SelectableText(
                widget.message,
                style: _style,
              )
            else
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Text(
                  widget.message,
                  maxLines: _maxCollapsedLines,
                  overflow: TextOverflow.ellipsis,
                  style: _style,
                ),
              ),
            if (showToggle)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Text(
                      _expanded ? '收起' : '展开',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
