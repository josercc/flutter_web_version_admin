import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../commons/remote_debug/ntfy_debug_client.dart';
import '../../../commons/remote_debug/remote_debug_protocol.dart';

enum NtfyLinkState { disconnected, connecting, connected, reconnecting }

class DeviceDebugController extends GetxController {
  static const _prefControlUrl = 'remote_debug_control_ntfy_url';
  static const _prefControlToken = 'remote_debug_control_ntfy_token';
  static const _prefStreamUrl = 'remote_debug_ntfy_url';
  static const _prefStreamToken = 'remote_debug_ntfy_token';

  final controlBaseUrl = RemoteDebugProtocol.controlBaseUrl.obs;
  final controlAccessToken = RemoteDebugProtocol.controlAccessToken.obs;
  final streamBaseUrl = RemoteDebugProtocol.streamBaseUrl.obs;
  final streamAccessToken = RemoteDebugProtocol.streamAccessToken.obs;

  /// Legacy single-url bindings used by settings UI fallbacks.
  final baseUrl = RemoteDebugProtocol.streamBaseUrl.obs;
  final accessToken = RemoteDebugProtocol.streamAccessToken.obs;

  final linkState = NtfyLinkState.disconnected.obs;
  final statusMessage = ''.obs;

  final devices = <String, DevicePresence>{}.obs;

  /// Stable online order: append-only by firstSeen; never reshuffle on heartbeat/login.
  final onlineOrder = <String>[].obs;

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

  /// `all` | `sit` | `prod`
  final listFilterEnv = 'all'.obs;

  NtfyDebugClient? _controlClient;
  NtfyDebugClient? _streamClient;
  Timer? _presenceSweep;
  Timer? _keepaliveWatch;
  DateTime? _lastNtfyEventAt;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  /// After Admin「打开调试」, ignore heartbeat `r`=false briefly until App applies on.
  final Map<String, DateTime> _reportingOpenGraceUntil = {};

  /// Online devices in first-seen order (stable).
  List<DevicePresence> get onlineDevices {
    final uid = listFilterUserId.value.trim().toLowerCase();
    final did = listFilterDeviceId.value.trim().toLowerCase();
    final model = listFilterModel.value.trim().toLowerCase();
    final env = listFilterEnv.value;
    final out = <DevicePresence>[];
    for (final id in onlineOrder) {
      final d = devices[id];
      if (d == null || !d.online) continue;
      if (env != 'all' && (d.env ?? '') != env) continue;
      if (uid.isNotEmpty) {
        final u = (d.userId ?? '').toLowerCase();
        if (!u.contains(uid)) continue;
      }
      if (did.isNotEmpty && !d.deviceId.toLowerCase().contains(did)) {
        continue;
      }
      if (model.isNotEmpty) {
        final m = (d.displayModel ?? '').toLowerCase();
        if (!m.contains(model)) continue;
      }
      out.add(d);
    }
    return out;
  }

  /// Online but not currently reporting — avoids duplicating「调试中」rows.
  List<DevicePresence> get onlineIdleDevices =>
      onlineDevices.where((d) => !d.reportingEnabled).toList();

  /// Currently sending logs.
  List<DevicePresence> get reportingOnlineDevices =>
      onlineDevices.where((d) => d.reportingEnabled).toList();

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
    _controlClient?.close();
    _controlClient = null;
    _streamClient?.close();
    _streamClient = null;
    super.onClose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    controlBaseUrl.value = prefs.getString(_prefControlUrl) ??
        RemoteDebugProtocol.controlBaseUrl;
    controlAccessToken.value = prefs.getString(_prefControlToken) ??
        RemoteDebugProtocol.controlAccessToken;
    streamBaseUrl.value =
        prefs.getString(_prefStreamUrl) ?? RemoteDebugProtocol.streamBaseUrl;
    streamAccessToken.value = prefs.getString(_prefStreamToken) ??
        RemoteDebugProtocol.streamAccessToken;
    baseUrl.value = streamBaseUrl.value;
    accessToken.value = streamAccessToken.value;
  }

  Future<void> saveSettings({
    required String url,
    required String token,
    String? controlUrl,
    String? controlToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final nextStreamUrl = url.trim();
    final nextStreamToken = token.trim();
    final nextControlUrl =
        (controlUrl ?? controlBaseUrl.value).trim();
    final nextControlToken =
        (controlToken ?? controlAccessToken.value).trim();
    await prefs.setString(_prefStreamUrl, nextStreamUrl);
    await prefs.setString(_prefStreamToken, nextStreamToken);
    await prefs.setString(_prefControlUrl, nextControlUrl);
    await prefs.setString(_prefControlToken, nextControlToken);
    streamBaseUrl.value = nextStreamUrl;
    streamAccessToken.value = nextStreamToken;
    controlBaseUrl.value = nextControlUrl;
    controlAccessToken.value = nextControlToken;
    baseUrl.value = nextStreamUrl;
    accessToken.value = nextStreamToken;
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
    _controlClient?.close();
    _streamClient?.close();
    _controlClient = NtfyDebugClient(
      baseUrl: controlBaseUrl.value,
      accessToken: controlAccessToken.value,
    );
    _streamClient = NtfyDebugClient(
      baseUrl: streamBaseUrl.value,
      accessToken: streamAccessToken.value,
    );
    _intentionalDisconnect = false;

    try {
      await _controlClient!.subscribe(
        topic: RemoteDebugProtocol.presenceTopic,
        onMessage: _onNtfyEvent,
        onError: (e) => _onStreamBroken('presence error: $e'),
        onDone: () => _onStreamBroken('presence done'),
      );

      final topic = currentStreamTopic.value;
      if (topic != null && topic.isNotEmpty) {
        await _streamClient!.subscribe(
          topic: topic,
          onMessage: _onNtfyEvent,
          onError: (e) => _onStreamBroken('stream error: $e'),
          onDone: () => _onStreamBroken('stream done'),
        );
      }

      linkState.value = NtfyLinkState.connected;
      statusMessage.value = '已连接（在线=${controlBaseUrl.value}）';
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
    final expired = <String>[];
    devices.forEach((id, d) {
      if (d.online &&
          now.difference(d.lastSeen) > RemoteDebugProtocol.presenceTimeout) {
        expired.add(id);
      }
    });
    if (expired.isEmpty) return;
    for (final id in expired) {
      _removeDevice(id);
    }
  }

  void _removeDevice(String id) {
    devices.remove(id);
    onlineOrder.remove(id);
    if (selectedDeviceId.value == id) {
      selectedDeviceId.value = null;
    }
    if (followDeviceId.value == id) {
      followDeviceId.value = null;
    }
    devices.refresh();
    onlineOrder.refresh();
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

    if (offline) {
      _removeDevice(id);
      return;
    }

    final existing = devices[id];
    final now = DateTime.now();
    if (existing == null) {
      final presence = DevicePresence(
        deviceId: id,
        userId: envelope.userId,
        lastSeen: now,
        firstSeen: now,
        appVersion: envelope.appVersion,
        platform: envelope.platform,
        launchId: envelope.launchId,
        env: envelope.env,
        online: true,
        reportingEnabled: envelope.reportingEnabled ?? false,
        deviceInfo: envelope.deviceInfo.isNotEmpty
            ? Map<String, String>.from(envelope.deviceInfo)
            : null,
      );
      devices[id] = presence;
      onlineOrder.add(id);
    } else {
      // Same deviceId: update in place — do not reorder.
      if (envelope.userId != null) {
        existing.userId = envelope.userId;
      }
      if (envelope.appVersion != null) {
        existing.appVersion = envelope.appVersion;
      }
      if (envelope.platform != null) {
        existing.platform = envelope.platform;
      }
      if (envelope.launchId != null) {
        existing.launchId = envelope.launchId;
      }
      if (envelope.env != null && envelope.env!.isNotEmpty) {
        existing.env = envelope.env;
      }
      existing.lastSeen = now;
      existing.online = true;
      if (envelope.reportingEnabled != null) {
        final graceUntil = _reportingOpenGraceUntil[id];
        final inGrace =
            graceUntil != null && now.isBefore(graceUntil);
        if (envelope.reportingEnabled == true) {
          existing.reportingEnabled = true;
          _reportingOpenGraceUntil.remove(id);
        } else if (!inGrace) {
          existing.reportingEnabled = false;
        }
      }
      if (envelope.deviceInfo.isNotEmpty) {
        existing.deviceInfo = Map<String, String>.from(envelope.deviceInfo);
      }
      devices[id] = existing;
    }
    devices.refresh();
    onlineOrder.refresh();

    final presence = devices[id];
    if (presence != null) {
      _maybeFollow(presence);
    }
  }

  void _maybeFollow(DevicePresence presence) {
    final follow = followDeviceId.value;
    if (follow == null || follow != presence.deviceId) return;
    if (!presence.reportingEnabled) return;

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
      statusMessage.value = '调试未打开，可点击「打开调试」';
      return;
    }
    await _subscribeStream(presence.streamTopic);
  }

  Future<void> openDebug(DevicePresence presence) async {
    selectedDeviceId.value = presence.deviceId;
    followDeviceId.value = presence.deviceId;
    try {
      await _publishCommand(
        presence.deviceId,
        RemoteDebugProtocol.commandActionDebugOn,
      );
      _reportingOpenGraceUntil[presence.deviceId] =
          DateTime.now().add(const Duration(seconds: 8));
      presence.reportingEnabled = true;
      devices[presence.deviceId] = presence;
      devices.refresh();
      statusMessage.value = '已发送打开调试';
      await _subscribeStream(presence.streamTopic);
    } catch (e) {
      statusMessage.value = '打开调试失败: $e';
    }
  }

  Future<void> closeDebug(DevicePresence presence) async {
    try {
      await _publishCommand(
        presence.deviceId,
        RemoteDebugProtocol.commandActionDebugOff,
      );
      _reportingOpenGraceUntil.remove(presence.deviceId);
      presence.reportingEnabled = false;
      devices[presence.deviceId] = presence;
      devices.refresh();
      final topic = currentStreamTopic.value;
      if (topic != null &&
          topic == presence.streamTopic &&
          _streamClient != null) {
        await _streamClient!.unsubscribe(topic);
        currentStreamTopic.value = null;
      }
      statusMessage.value = '已发送关闭调试';
    } catch (e) {
      statusMessage.value = '关闭调试失败: $e';
    }
  }

  Future<void> _publishCommand(String deviceId, String action) async {
    final client = _controlClient;
    if (client == null) {
      throw StateError('control ntfy not connected');
    }
    final topic = RemoteDebugProtocol.commandTopic(deviceId);
    statusMessage.value =
        '发送指令 → ${controlBaseUrl.value} topic=$topic';
    await client.publish(
      topic: topic,
      message: RemoteDebugProtocol.encodeCompactCommand(action),
      title: action,
      tags: ['c', action],
    );
  }

  Future<void> _subscribeStream(String topic) async {
    final client = _streamClient;
    if (client == null) return;

    final old = currentStreamTopic.value;
    if (old != null &&
        old != topic &&
        old != RemoteDebugProtocol.presenceTopic) {
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
    if (envelope.deviceId.isNotEmpty) {
      final existing = devices[envelope.deviceId];
      if (existing != null && !existing.reportingEnabled) {
        existing.reportingEnabled = true;
        devices.refresh();
      }
    }

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

  Future<void> exportLogs() async {
    final entries = filteredLogs.reversed.toList();
    if (entries.isEmpty) {
      statusMessage.value = '没有可导出的日志';
      return;
    }
    final buf = StringBuffer();
    for (final e in entries) {
      buf.writeln(e.exportText);
    }
    final stamp = _exportStamp();
    final saved = await _saveTextFile(
      suggestedName: 'debug_logs_$stamp.txt',
      contents: buf.toString(),
    );
    if (saved != null) {
      statusMessage.value = '日志已导出: $saved';
    }
  }

  Future<void> exportHttps() async {
    final entries = filteredHttps.reversed.toList();
    if (entries.isEmpty) {
      statusMessage.value = '没有可导出的请求';
      return;
    }
    final buf = StringBuffer();
    for (var i = 0; i < entries.length; i++) {
      if (i > 0) buf.writeln();
      buf.writeln('========== #${i + 1} ==========');
      buf.writeln(entries[i].exportText);
    }
    final stamp = _exportStamp();
    final saved = await _saveTextFile(
      suggestedName: 'debug_http_$stamp.txt',
      contents: buf.toString(),
    );
    if (saved != null) {
      statusMessage.value = '请求已导出: $saved';
    }
  }

  String _exportStamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// Shows a save dialog and writes [contents] as UTF-8 text. Returns path or null.
  Future<String?> _saveTextFile({
    required String suggestedName,
    required String contents,
  }) async {
    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Text', extensions: ['txt']),
        ],
      );
      if (location == null) {
        statusMessage.value = '已取消导出';
        return null;
      }
      final file = File(location.path);
      await file.writeAsString(contents, flush: true);
      return file.path;
    } catch (e) {
      statusMessage.value = '导出失败: $e';
      return null;
    }
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
