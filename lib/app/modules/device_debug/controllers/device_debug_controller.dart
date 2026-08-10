import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../commons/remote_debug/ntfy_debug_client.dart';
import '../../../commons/remote_debug/remote_debug_protocol.dart';

enum NtfyLinkState { disconnected, connecting, connected, reconnecting }

class DeviceDebugController extends GetxController {
  static const _prefUrl = 'remote_debug_ntfy_url';
  static const _prefToken = 'remote_debug_ntfy_token';

  final baseUrl = RemoteDebugProtocol.defaultBaseUrl.obs;
  final accessToken = RemoteDebugProtocol.defaultAccessToken.obs;

  final linkState = NtfyLinkState.disconnected.obs;
  final statusMessage = ''.obs;

  final devices = <String, DevicePresence>{}.obs;
  final selectedDeviceId = RxnString();
  final followDeviceId = RxnString();
  final currentStreamTopic = RxnString();

  final logs = <DebugLogEntry>[].obs;
  final https = <DebugHttpEntry>[].obs;
  final logFilter = ''.obs;
  /// `all` | `error` | `warning` | `info` | `debug`
  final logLevelFilter = 'all'.obs;
  final httpFilter = ''.obs;
  final onlyFailedHttp = false.obs;
  /// `all` | `flutter` | `unity`
  final httpSourceFilter = 'all'.obs;
  final pauseScroll = false.obs;
  final deviceFilter = ''.obs;
  final deviceInfoFilter = ''.obs;

  /// Left-panel filters (substring, case-insensitive where applicable).
  final listFilterUserId = ''.obs;
  final listFilterDeviceId = ''.obs;
  final listFilterModel = ''.obs;

  NtfyDebugClient? _client;
  Timer? _presenceSweep;
  Timer? _keepaliveWatch;
  DateTime? _lastNtfyEventAt;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  /// Stable order: logged-in first, then deviceId.
  /// Avoid sorting by live [DevicePresence.lastSeen] — presence / stream
  /// refreshes would reshuffle the sidebar on every heartbeat.
  static int compareDevicesStable(DevicePresence a, DevicePresence b) {
    final aLogin = a.isLoggedIn ? 0 : 1;
    final bLogin = b.isLoggedIn ? 0 : 1;
    if (aLogin != bLogin) return aLogin - bLogin;
    return a.deviceId.compareTo(b.deviceId);
  }

  List<DevicePresence> _applyListFilters(Iterable<DevicePresence> source) {
    final uid = listFilterUserId.value.trim().toLowerCase();
    final did = listFilterDeviceId.value.trim().toLowerCase();
    final model = listFilterModel.value.trim().toLowerCase();
    return source.where((d) {
      if (uid.isNotEmpty) {
        final u = (d.userId ?? '').toLowerCase();
        if (!u.contains(uid)) return false;
      }
      if (did.isNotEmpty) {
        if (!d.deviceId.toLowerCase().contains(did)) return false;
      }
      if (model.isNotEmpty) {
        final m = (d.displayModel ?? '').toLowerCase();
        if (!m.contains(model)) return false;
      }
      return true;
    }).toList()
      ..sort(compareDevicesStable);
  }

  List<DevicePresence> get reportingOnlineDevices => _applyListFilters(
        devices.values.where((d) => d.online && d.reportingEnabled),
      );

  List<DebugLogEntry> get filteredLogs {
    final q = logFilter.value.trim().toLowerCase();
    final df = deviceFilter.value.trim();
    final level = logLevelFilter.value;
    return logs.where((e) {
      if (df.isNotEmpty && e.deviceId != df) return false;
      if (level != 'all' && e.levelKind != level) return false;
      if (q.isEmpty) return true;
      return e.copyText.toLowerCase().contains(q);
    }).toList();
  }

  List<DebugHttpEntry> get filteredHttps {
    final q = httpFilter.value.trim().toLowerCase();
    final df = deviceFilter.value.trim();
    final source = httpSourceFilter.value;
    return https.where((e) {
      if (onlyFailedHttp.value && e.ok) return false;
      if (df.isNotEmpty && e.deviceId != df) return false;
      if (source == RemoteDebugProtocol.sourceUnity && !e.isUnity) {
        return false;
      }
      if (source == RemoteDebugProtocol.sourceFlutter && e.isUnity) {
        return false;
      }
      if (q.isEmpty) return true;
      return e.url.toLowerCase().contains(q) ||
          e.method.toLowerCase().contains(q) ||
          e.sourceLabel.toLowerCase().contains(q) ||
          (e.error?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    _loadPrefs().then((_) => connect());
  }

  @override
  void onClose() {
    _disposed = true;
    _presenceSweep?.cancel();
    _keepaliveWatch?.cancel();
    _client?.close();
    _client = null;
    super.onClose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl.value =
        prefs.getString(_prefUrl) ?? RemoteDebugProtocol.defaultBaseUrl;
    accessToken.value =
        prefs.getString(_prefToken) ?? RemoteDebugProtocol.defaultAccessToken;
  }

  Future<void> saveSettings({
    required String url,
    required String token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrl, url.trim());
    await prefs.setString(_prefToken, token.trim());
    baseUrl.value = url.trim();
    accessToken.value = token.trim();
    await connect();
  }

  bool _intentionalDisconnect = false;

  Future<void> connect() async {
    if (_disposed) return;
    _intentionalDisconnect = true;
    linkState.value = _reconnectAttempt == 0
        ? NtfyLinkState.connecting
        : NtfyLinkState.reconnecting;
    statusMessage.value = '连接 ntfy…';

    _presenceSweep?.cancel();
    _keepaliveWatch?.cancel();
    _client?.close();
    _client = NtfyDebugClient(
      baseUrl: baseUrl.value,
      accessToken: accessToken.value,
    );
    _intentionalDisconnect = false;

    try {
      await _client!.subscribe(
        topic: RemoteDebugProtocol.presenceTopic,
        onMessage: _onNtfyEvent,
        onError: (e) => _onStreamBroken('presence error: $e'),
        onDone: () => _onStreamBroken('presence done'),
      );

      final topic = currentStreamTopic.value;
      if (topic != null && topic.isNotEmpty) {
        await _client!.subscribe(
          topic: topic,
          onMessage: _onNtfyEvent,
          onError: (e) => _onStreamBroken('stream error: $e'),
          onDone: () => _onStreamBroken('stream done'),
        );
      }

      linkState.value = NtfyLinkState.connected;
      statusMessage.value = '已连接';
      _reconnectAttempt = 0;
      _lastNtfyEventAt = DateTime.now();
      _presenceSweep = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _sweepPresence(),
      );
      _keepaliveWatch = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _checkKeepalive(),
      );
    } catch (e) {
      statusMessage.value = '连接失败: $e';
      linkState.value = NtfyLinkState.disconnected;
      _scheduleReconnect();
    }
  }

  void _onStreamBroken(String reason) {
    if (_disposed || _intentionalDisconnect) return;
    if (linkState.value == NtfyLinkState.reconnecting ||
        linkState.value == NtfyLinkState.connecting) {
      return;
    }
    statusMessage.value = '链路断开($reason)，状态未知';
    linkState.value = NtfyLinkState.disconnected;
    _scheduleReconnect();
  }

  void _checkKeepalive() {
    final last = _lastNtfyEventAt;
    if (last == null) return;
    if (DateTime.now().difference(last) >
        RemoteDebugProtocol.keepaliveWatchdog) {
      _onStreamBroken('keepalive timeout');
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectAttempt++;
    final delay = Duration(
      seconds: (_reconnectAttempt.clamp(1, 5) * 2),
    );
    linkState.value = NtfyLinkState.reconnecting;
    Future.delayed(delay, () {
      if (!_disposed) connect();
    });
  }

  void _sweepPresence() {
    final now = DateTime.now();
    var changed = false;
    devices.forEach((id, d) {
      if (d.online &&
          now.difference(d.lastSeen) > RemoteDebugProtocol.presenceTimeout) {
        d.online = false;
        changed = true;
      }
    });
    if (changed) devices.refresh();
  }

  void _onNtfyEvent(Map<String, dynamic> raw) {
    _lastNtfyEventAt = DateTime.now();
    final event = raw['event']?.toString();
    if (event == 'keepalive' || event == 'open') return;
    if (event != null && event != 'message') return;

    final message = raw['message']?.toString();
    if (message == null || message.isEmpty) return;

    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }

    final envelope = RemoteDebugEnvelope.fromJson(payload);
    switch (envelope.type) {
      case RemoteDebugEnvelopeType.presence:
        _handlePresence(envelope, offline: false);
        break;
      case RemoteDebugEnvelopeType.offline:
        _handlePresence(envelope, offline: true);
        break;
      case RemoteDebugEnvelopeType.log:
      case RemoteDebugEnvelopeType.http:
      case RemoteDebugEnvelopeType.batch:
        _handleData(envelope);
        break;
      case RemoteDebugEnvelopeType.command:
        break;
    }
  }

  void _handlePresence(RemoteDebugEnvelope envelope, {required bool offline}) {
    final id = envelope.deviceId;
    if (id.isEmpty) return;

    final existing = devices[id];
    if (offline) {
      if (existing != null) {
        existing.online = false;
        existing.lastSeen = DateTime.now();
        if (envelope.reportingEnabled != null) {
          existing.reportingEnabled = envelope.reportingEnabled!;
        }
        if (envelope.deviceInfo.isNotEmpty) {
          existing.deviceInfo = Map<String, String>.from(envelope.deviceInfo);
        }
        devices[id] = existing;
      }
      return;
    }

    final presence = existing ??
        DevicePresence(
          deviceId: id,
          lastSeen: DateTime.now(),
        );
    presence.userId = envelope.userId;
    presence.appVersion = envelope.appVersion;
    presence.platform = envelope.platform;
    presence.launchId = envelope.launchId;
    presence.lastSeen = DateTime.now();
    presence.online = true;
    // Legacy clients omit the field → keep treating as reporting on.
    presence.reportingEnabled = envelope.reportingEnabled ?? true;
    if (envelope.deviceInfo.isNotEmpty) {
      presence.deviceInfo = Map<String, String>.from(envelope.deviceInfo);
    }
    devices[id] = presence;
    devices.refresh();

    _maybeFollow(presence);
  }

  void _maybeFollow(DevicePresence presence) {
    final follow = followDeviceId.value;
    if (follow == null || follow != presence.deviceId) return;

    final topic = presence.streamTopic;
    if (topic == currentStreamTopic.value) return;

    statusMessage.value = presence.isLoggedIn
        ? '已跟随登录，切换到用户 ${presence.userId}'
        : '已登出，切回匿名设备';
    selectedDeviceId.value = presence.deviceId;
    unawaited(_subscribeStream(topic));
  }

  Future<void> selectDevice(DevicePresence presence) async {
    selectedDeviceId.value = presence.deviceId;
    followDeviceId.value = presence.deviceId;
    deviceFilter.value = '';
    if (!presence.reportingEnabled) {
      statusMessage.value = '该设备未开启上报，无法订阅日志流';
      return;
    }
    await _subscribeStream(presence.streamTopic);
  }

  Future<void> _subscribeStream(String topic) async {
    final client = _client;
    if (client == null) return;

    final old = currentStreamTopic.value;
    if (old != null && old != topic && old != RemoteDebugProtocol.presenceTopic) {
      await client.unsubscribe(old);
    }
    currentStreamTopic.value = topic;

    try {
      await client.subscribe(
        topic: topic,
        onMessage: _onNtfyEvent,
        onError: (e) => _onStreamBroken('stream error: $e'),
        onDone: () => _onStreamBroken('stream done'),
      );
      statusMessage.value = '订阅 $topic';
    } catch (e) {
      statusMessage.value = '订阅失败: $e';
    }
  }

  void _handleData(RemoteDebugEnvelope envelope) {
    final follow = followDeviceId.value;
    if (follow != null &&
        envelope.deviceId.isNotEmpty &&
        envelope.deviceId != follow) {
      // Still accept if subscribed to user topic with multiple devices;
      // only skip when filtering by follow is not desired — keep all for user topic.
    }

    if (envelope.deviceInfo.isNotEmpty && envelope.deviceId.isNotEmpty) {
      final existing = devices[envelope.deviceId];
      if (existing != null) {
        final nextInfo = Map<String, String>.from(envelope.deviceInfo);
        final infoChanged = !_stringMapEquals(existing.deviceInfo, nextInfo);
        var metaChanged = false;
        if (existing.appVersion == null && envelope.appVersion != null) {
          existing.appVersion = envelope.appVersion;
          metaChanged = true;
        }
        if (existing.platform == null && envelope.platform != null) {
          existing.platform = envelope.platform;
          metaChanged = true;
        }
        if (existing.launchId == null && envelope.launchId != null) {
          existing.launchId = envelope.launchId;
          metaChanged = true;
        }
        existing.deviceInfo = nextInfo;
        // Avoid rebuilding the sidebar on every stream tick with identical info.
        if (infoChanged || metaChanged) {
          devices.refresh();
        }
      }
    }

    void pushLog(Map<String, dynamic> item) {
      logs.insert(
        0,
        DebugLogEntry.fromItem(
          item,
          deviceId: envelope.deviceId,
          userId: envelope.userId,
        ),
      );
      _trim(logs);
    }

    void pushHttp(Map<String, dynamic> item) {
      https.insert(
        0,
        DebugHttpEntry.fromItem(
          item,
          deviceId: envelope.deviceId,
          userId: envelope.userId,
        ),
      );
      _trim(https);
    }

    if (envelope.type == RemoteDebugEnvelopeType.batch) {
      for (final item in envelope.items) {
        final t = item['type']?.toString();
        if (t == 'http' || item.containsKey('url')) {
          pushHttp(item);
        } else {
          pushLog(item);
        }
      }
      return;
    }

    if (envelope.type == RemoteDebugEnvelopeType.http) {
      if (envelope.items.isEmpty) {
        pushHttp(envelope.toJson());
      } else {
        for (final item in envelope.items) {
          pushHttp(item);
        }
      }
      return;
    }

    if (envelope.items.isEmpty) {
      pushLog({
        'level': 'i',
        'message': envelope.toJson()['message'] ?? '',
        'ts': envelope.ts,
      });
    } else {
      for (final item in envelope.items) {
        pushLog(item);
      }
    }
  }

  DevicePresence? get selectedDevice {
    final id = selectedDeviceId.value;
    if (id == null) return null;
    return devices[id];
  }

  Future<void> copyDeviceInfo() async {
    final d = selectedDevice;
    if (d == null) {
      statusMessage.value = '请先选择设备';
      return;
    }
    final merged = <String, String>{
      'deviceId': d.deviceId,
      if (d.userId != null && d.userId!.isNotEmpty) 'userId': d.userId!,
      if (d.launchId != null && d.launchId!.isNotEmpty) 'launchId': d.launchId!,
      if (d.appVersion != null && d.appVersion!.isNotEmpty)
        'appVersion': d.appVersion!,
      if (d.platform != null && d.platform!.isNotEmpty) 'platform': d.platform!,
      ...d.deviceInfo,
    };
    if (merged.isEmpty) {
      statusMessage.value = '暂无设备信息';
      return;
    }
    final view = DevicePresence(
      deviceId: d.deviceId,
      lastSeen: d.lastSeen,
      deviceInfo: merged,
    );
    final buf = StringBuffer();
    for (final section in view.deviceInfoSections) {
      buf.writeln('## ${section.title}');
      for (final e in section.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }
      buf.writeln();
    }
    await copyText(buf.toString());
    statusMessage.value = '设备信息已复制';
  }

  void _trim(RxList list) {
    while (list.length > RemoteDebugProtocol.maxBufferItems) {
      list.removeLast();
    }
  }

  void clearLogs() => logs.clear();
  void clearHttps() => https.clear();
  void clearAll() {
    logs.clear();
    https.clear();
  }

  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    statusMessage.value = '已复制';
  }

  Future<void> exportLogsJsonl() async {
    final buf = StringBuffer();
    for (final e in filteredLogs.reversed) {
      buf.writeln(jsonEncode({
        'source': e.source ?? RemoteDebugProtocol.sourceFlutter,
        'level': e.level,
        'tag': e.tag,
        'message': e.message,
        'ts': e.ts,
        'deviceId': e.deviceId,
        'userId': e.userId,
      }));
    }
    await copyText(buf.toString());
    statusMessage.value = '日志 JSONL 已复制到剪贴板';
  }

  Future<void> exportHttpsJsonl() async {
    final buf = StringBuffer();
    for (final e in filteredHttps.reversed) {
      buf.writeln(e.copyText);
    }
    await copyText(buf.toString());
    statusMessage.value = '请求 JSONL 已复制到剪贴板';
  }

  static bool _stringMapEquals(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
