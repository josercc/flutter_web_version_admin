import 'dart:convert';

/// Shared remote-debug protocol (App publisher + desktop subscriber).
///
/// Control plane (presence + cmd) → [controlBaseUrl].
/// Data plane (log/http) → [streamBaseUrl].
class RemoteDebugProtocol {
  /// Control plane topics (presence + cmd) on chat host.
  static const String presenceTopic = 'winnerapp_debug_presence';

  /// Presence + command (chat / 4C8G).
  static const String controlBaseUrl = 'https://chat.winnerapp.cn/';
  static const String controlAccessToken = 'tk_a9ya8h278g3b66tc5f32q63vynre8';

  /// Log / HTTP stream (weak host).
  static const String streamBaseUrl = 'http://119.23.47.1:8385/';
  static const String streamAccessToken = 'tk_6c0b3ec5cf01uyy46swg86330rqho';

  /// Legacy aliases → stream (data plane).
  static const String defaultBaseUrl = streamBaseUrl;
  static const String defaultAccessToken = streamAccessToken;

  static const Duration presenceInterval = Duration(seconds: 10);
  static const Duration presenceTimeout = Duration(seconds: 30);
  static const Duration keepaliveWatchdog = Duration(seconds: 90);
  static const int maxMessageBytes = 900 * 1024;
  static const int maxBufferItems = 5000;

  static const String sourceFlutter = 'flutter';
  static const String sourceUnity = 'unity';

  static String sanitizeTopicPart(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (cleaned.isEmpty) return 'unknown';
    if (cleaned.length <= 40) return cleaned;
    return cleaned.substring(0, 40);
  }

  static String streamTopic({String? userId, required String deviceId}) {
    final uid = userId?.trim();
    if (uid != null && uid.isNotEmpty && uid != '0') {
      return 'winnerapp_debug_user_${sanitizeTopicPart(uid)}';
    }
    return 'winnerapp_debug_anon_${sanitizeTopicPart(deviceId)}';
  }

  static String commandTopic(String deviceId) =>
      'winnerapp_debug_cmd_${sanitizeTopicPart(deviceId)}';

  static const String commandActionRefreshConfig = 'refresh_config';
  static const String commandActionDebugOn = 'on';
  static const String commandActionDebugOff = 'off';
  static const String commandActionListSessions = 'list_sessions';
  static const String commandActionFetchSession = 'fetch_session';

  static const String envSit = 'sit';
  static const String envProd = 'prod';

  static const Duration sessionFlushInterval = Duration(seconds: 5);
  static const int sessionFlushItemThreshold = 50;
  static const int sessionFlushBytesThreshold = 64 * 1024;
  static const int maxLocalSessions = 10;
  /// Per-file cap for `logs.ndjson` / `http.ndjson` within one launch.
  static const int maxSessionFileBytes = 5 * 1024 * 1024;

  static String encodeCompactCommand(
    String action, {
    String? sessionId,
  }) {
    final map = <String, dynamic>{'t': 'c', 'a': action};
    if (sessionId != null && sessionId.isNotEmpty) {
      map['id'] = sessionId;
    }
    return jsonEncode(map);
  }

  static String envLabel(String? env) {
    switch (env) {
      case envProd:
        return '生产';
      case envSit:
        return '测试';
      default:
        return '未知';
    }
  }

  static String truncateForNtfy(String value) {
    final bytes = utf8.encode(value);
    if (bytes.length <= maxMessageBytes) return value;
    final cut = utf8.decode(
      bytes.sublist(0, maxMessageBytes),
      allowMalformed: true,
    );
    return '$cut\n...(truncated)';
  }

  static Map<String, String> sanitizeHeaders(Map<String, dynamic>? headers) {
    if (headers == null) return {};
    final out = <String, String>{};
    headers.forEach((key, value) {
      final k = key.toString();
      final lower = k.toLowerCase();
      if (lower == 'authorization' ||
          lower == 'cookie' ||
          lower.contains('token')) {
        out[k] = '***';
      } else {
        out[k] = value?.toString() ?? '';
      }
    });
    return out;
  }
}

enum RemoteDebugEnvelopeType {
  presence,
  offline,
  log,
  http,
  batch,
  command,
  sessionsList,
  sessionError,
  sessionZip;

  static RemoteDebugEnvelopeType? tryParse(String? raw) {
    switch (raw) {
      case 'presence':
        return RemoteDebugEnvelopeType.presence;
      case 'offline':
        return RemoteDebugEnvelopeType.offline;
      case 'log':
        return RemoteDebugEnvelopeType.log;
      case 'http':
        return RemoteDebugEnvelopeType.http;
      case 'batch':
        return RemoteDebugEnvelopeType.batch;
      case 'command':
        return RemoteDebugEnvelopeType.command;
      case 'sessions_list':
        return RemoteDebugEnvelopeType.sessionsList;
      case 'session_error':
        return RemoteDebugEnvelopeType.sessionError;
      case 'session_zip':
        return RemoteDebugEnvelopeType.sessionZip;
      default:
        return null;
    }
  }

  String get wire => switch (this) {
        RemoteDebugEnvelopeType.sessionsList => 'sessions_list',
        RemoteDebugEnvelopeType.sessionError => 'session_error',
        RemoteDebugEnvelopeType.sessionZip => 'session_zip',
        _ => name,
      };
}

class RemoteDebugEnvelope {
  RemoteDebugEnvelope({
    required this.type,
    required this.deviceId,
    this.userId,
    this.launchId,
    this.appVersion,
    this.platform,
    required this.ts,
    this.items = const [],
    this.deviceInfo = const {},
    this.reportingEnabled,
    this.action,
    this.env,
    this.sessionId,
    this.error,
    this.sessionItems = const [],
  });

  final RemoteDebugEnvelopeType type;
  final String deviceId;
  final String? userId;
  final String? launchId;
  final String? appVersion;
  final String? platform;
  final int ts;
  final List<Map<String, dynamic>> items;
  /// Sentry-equivalent device / app tags from the mobile client.
  final Map<String, String> deviceInfo;

  /// Whether the device is uploading logs/HTTP. Null on legacy clients → treat as true.
  final bool? reportingEnabled;

  /// For [RemoteDebugEnvelopeType.command], e.g. [RemoteDebugProtocol.commandActionRefreshConfig].
  final String? action;

  /// Compact env: `sit` | `prod`.
  final String? env;

  /// Local session id (launchId) for fetch / zip / error.
  final String? sessionId;
  final String? error;

  /// Compact session rows from `sessions_list`.
  final List<Map<String, dynamic>> sessionItems;

  factory RemoteDebugEnvelope.fromJson(Map<String, dynamic> json) {
    // Compact wire: {"t":"p"|"o"|"c","d":"...","u":"...","e":"sit|prod","r":1,"a":"on"|"off"}
    final compactT = json['t']?.toString();
    if (compactT == 'p' || compactT == 'o' || compactT == 'c') {
      final type = switch (compactT) {
        'o' => RemoteDebugEnvelopeType.offline,
        'c' => RemoteDebugEnvelopeType.command,
        _ => RemoteDebugEnvelopeType.presence,
      };
      bool? reporting;
      if (type == RemoteDebugEnvelopeType.presence) {
        // Missing `r` means not reporting (Admin「调试中」必须与 App 一致).
        if (json.containsKey('r')) {
          final raw = json['r'];
          if (raw is bool) {
            reporting = raw;
          } else if (raw is num) {
            reporting = raw != 0;
          } else {
            final s = raw?.toString().toLowerCase();
            reporting = s == '1' || s == 'true';
          }
        } else {
          reporting = false;
        }
      }
      return RemoteDebugEnvelope(
        type: type,
        deviceId: json['d']?.toString() ?? json['deviceId']?.toString() ?? '',
        userId: json['u']?.toString() ?? json['userId']?.toString(),
        env: json['e']?.toString() ?? json['env']?.toString(),
        ts: (json['ts'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        action: json['a']?.toString() ?? json['action']?.toString(),
        reportingEnabled: reporting,
        sessionId: json['id']?.toString() ?? json['sessionId']?.toString(),
      );
    }

    final type = RemoteDebugEnvelopeType.tryParse(json['type']?.toString()) ??
        RemoteDebugEnvelopeType.log;
    final itemsRaw = json['items'];
    final items = <Map<String, dynamic>>[];
    if (itemsRaw is List) {
      for (final e in itemsRaw) {
        if (e is Map) {
          items.add(Map<String, dynamic>.from(e));
        }
      }
    } else if (type == RemoteDebugEnvelopeType.log ||
        type == RemoteDebugEnvelopeType.http) {
      items.add(Map<String, dynamic>.from(json));
    }
    bool? reporting;
    final rawReporting = json['reportingEnabled'];
    if (rawReporting is bool) {
      reporting = rawReporting;
    } else if (rawReporting != null) {
      final s = rawReporting.toString().toLowerCase();
      if (s == 'true' || s == '1') reporting = true;
      if (s == 'false' || s == '0') reporting = false;
    }
    return RemoteDebugEnvelope(
      type: type,
      deviceId: json['deviceId']?.toString() ?? json['d']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['u']?.toString(),
      launchId: json['launchId']?.toString(),
      appVersion: json['appVersion']?.toString(),
      platform: json['platform']?.toString(),
      env: json['e']?.toString() ?? json['env']?.toString(),
      ts: (json['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      items: items,
      deviceInfo: _parseStringMap(json['deviceInfo']),
      reportingEnabled: reporting,
      action: json['action']?.toString() ?? json['a']?.toString(),
      sessionId: json['sessionId']?.toString() ?? json['id']?.toString(),
      error: json['error']?.toString(),
      sessionItems: type == RemoteDebugEnvelopeType.sessionsList ? items : const [],
    );
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v == null) return;
      out[k.toString()] = v.toString();
    });
    return out;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'type': type.wire,
        'deviceId': deviceId,
        if (userId != null && userId!.isNotEmpty) 'userId': userId,
        if (launchId != null) 'launchId': launchId,
        if (appVersion != null) 'appVersion': appVersion,
        if (platform != null) 'platform': platform,
        'ts': ts,
        if (items.isNotEmpty) 'items': items,
        if (deviceInfo.isNotEmpty) 'deviceInfo': deviceInfo,
        if (reportingEnabled != null) 'reportingEnabled': reportingEnabled,
        if (action != null && action!.isNotEmpty) 'action': action,
        if (sessionId != null && sessionId!.isNotEmpty) 'sessionId': sessionId,
        if (error != null && error!.isNotEmpty) 'error': error,
      };

  String encode() =>
      RemoteDebugProtocol.truncateForNtfy(jsonEncode(toJson()));
}

/// One local App launch archive (from `sessions_list`).
class LocalSessionInfo {
  LocalSessionInfo({
    required this.id,
    this.startedAt,
    this.env,
    this.logLines = 0,
    this.httpLines = 0,
    this.bytes = 0,
    this.appVersion,
  });

  final String id;
  final int? startedAt;
  final String? env;
  final int logLines;
  final int httpLines;
  final int bytes;
  final String? appVersion;

  factory LocalSessionInfo.fromJson(Map<String, dynamic> json) {
    return LocalSessionInfo(
      id: json['id']?.toString() ?? json['launchId']?.toString() ?? '',
      startedAt: (json['at'] as num?)?.toInt() ??
          (json['startedAt'] as num?)?.toInt(),
      env: json['env']?.toString(),
      logLines: (json['logs'] as num?)?.toInt() ??
          (json['logLines'] as num?)?.toInt() ??
          0,
      httpLines: (json['http'] as num?)?.toInt() ??
          (json['httpLines'] as num?)?.toInt() ??
          0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      appVersion: json['appVersion']?.toString(),
    );
  }

  String get startedLabel {
    final at = startedAt;
    if (at == null || at <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(at);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String get sizeLabel {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class DebugLogEntry {
  DebugLogEntry({
    required this.level,
    required this.message,
    required this.ts,
    this.tag,
    this.source,
    this.deviceId,
    this.userId,
  });

  final String level;
  final String message;
  final int ts;
  final String? tag;

  /// `flutter` / `unity` / null (legacy envelopes without source).
  final String? source;
  final String? deviceId;
  final String? userId;

  bool get isUnity => source == RemoteDebugProtocol.sourceUnity;
  bool get isFlutter =>
      source == RemoteDebugProtocol.sourceFlutter || source == null;

  String get sourceLabel {
    if (isUnity) return 'Unity';
    if (source == RemoteDebugProtocol.sourceFlutter) return 'Flutter';
    return 'Flutter';
  }

  /// Normalized level bucket: `error` | `warning` | `info` | `debug`.
  String get levelKind {
    final raw = level.trim().toLowerCase();
    switch (raw) {
      case 'e':
      case 'error':
      case 'err':
      case 'fatal':
      case 'f':
      case 'wtf':
        return 'error';
      case 'w':
      case 'warn':
      case 'warning':
        return 'warning';
      case 'i':
      case 'info':
      case 'log':
        return 'info';
      case 'd':
      case 'debug':
      case 'v':
      case 'verbose':
      case 't':
      case 'trace':
        return 'debug';
      default:
        if (raw.contains('error') || raw.contains('fatal')) return 'error';
        if (raw.contains('warn')) return 'warning';
        if (raw.contains('info')) return 'info';
        return 'debug';
    }
  }

  String get levelLabel {
    switch (levelKind) {
      case 'error':
        return 'Error';
      case 'warning':
        return 'Warning';
      case 'info':
        return 'Info';
      default:
        return 'Debug';
    }
  }

  factory DebugLogEntry.fromItem(
    Map<String, dynamic> item, {
    String? deviceId,
    String? userId,
  }) {
    final rawSource = item['source']?.toString().trim();
    final source = (rawSource == null || rawSource.isEmpty) ? null : rawSource;
    return DebugLogEntry(
      level: item['level']?.toString() ?? 'i',
      message: item['message']?.toString() ?? '',
      tag: parseTag(item),
      source: source,
      ts: (item['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      userId: userId,
    );
  }

  /// Prefer `tag`, then first of `tags`, then `name` / `logger`.
  static String? parseTag(Map<String, dynamic> item) {
    String? clean(dynamic raw) {
      if (raw == null) return null;
      if (raw is List) {
        for (final e in raw) {
          final s = e?.toString().trim();
          if (s != null && s.isNotEmpty) return s;
        }
        return null;
      }
      final s = raw.toString().trim();
      return s.isEmpty ? null : s;
    }

    return clean(item['tag']) ??
        clean(item['tags']) ??
        clean(item['name']) ??
        clean(item['logger']);
  }

  String get copyText {
    final time = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    final tagPart = tag != null ? '[$tag]' : '';
    return '[$time][$sourceLabel][$level]$tagPart $message';
  }

  /// Plain-text export line: time, level type, message.
  String get exportText {
    final time = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    final tagPart = tag != null ? '[$tag] ' : '';
    return '[$time] [$levelLabel] $tagPart$message';
  }
}

class DebugHttpEntry {
  DebugHttpEntry({
    required this.method,
    required this.url,
    this.path,
    this.statusCode,
    required this.ok,
    this.durationMs,
    this.requestHeaders = const {},
    this.responseHeaders = const {},
    this.requestBody,
    this.responseBody,
    this.businessSuccess,
    this.businessCode,
    this.error,
    required this.ts,
    this.deviceId,
    this.userId,
    this.source,
  });

  final String method;
  final String url;
  final String? path;
  final int? statusCode;
  final bool ok;
  final int? durationMs;
  final Map<String, String> requestHeaders;
  final Map<String, String> responseHeaders;
  final String? requestBody;
  final String? responseBody;

  /// Business `success` parsed from JSON response body (e.g. `{ "success": true }`).
  final bool? businessSuccess;

  /// Business `code` parsed from JSON response body (e.g. `{ "code": 40001 }`).
  final int? businessCode;
  final String? error;
  final int ts;
  final String? deviceId;
  final String? userId;

  /// `flutter` / `unity` / null (legacy envelopes without source).
  final String? source;

  bool get isUnity => source == RemoteDebugProtocol.sourceUnity;
  bool get isFlutter =>
      source == RemoteDebugProtocol.sourceFlutter || source == null;

  /// Body `success` is present and false (HTTP status may still be 2xx).
  bool get isBusinessFailure => businessSuccess == false;

  String get sourceLabel {
    if (isUnity) return 'Unity';
    if (source == RemoteDebugProtocol.sourceFlutter) return 'Flutter';
    return 'Flutter';
  }

  static Map? _decodeBodyMap(String? body) {
    if (body == null) return null;
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed == '(empty)') return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Extract API business `success` from a JSON response body when present.
  static bool? parseBusinessSuccess(String? body) {
    final decoded = _decodeBodyMap(body);
    if (decoded == null) return null;
    final raw = decoded['success'];
    if (raw is bool) return raw;
    if (raw == null) return null;
    final text = raw.toString().trim().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  /// Extract API business code from a JSON response body when present.
  static int? parseBusinessCode(String? body) {
    final decoded = _decodeBodyMap(body);
    if (decoded == null) return null;
    final raw = decoded['code'];
    if (raw == null) return null;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  factory DebugHttpEntry.fromItem(
    Map<String, dynamic> item, {
    String? deviceId,
    String? userId,
  }) {
    Map<String, String> mapHeaders(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    }

    final status = (item['statusCode'] as num?)?.toInt();
    final responseBody = item['responseBody']?.toString();
    final businessSuccess = parseBusinessSuccess(responseBody);
    final businessCode = parseBusinessCode(responseBody);
    final httpOk = status != null && status >= 200 && status < 400;
    final okFlag = item['ok'];
    final transportOk = okFlag is bool ? okFlag : httpOk;
    // Prefer body `success`; HTTP status alone is not decisive (non-200 can be OK).
    final ok = businessSuccess ?? transportOk;
    final rawSource = item['source']?.toString().trim();
    final source = (rawSource == null || rawSource.isEmpty) ? null : rawSource;

    return DebugHttpEntry(
      method: item['method']?.toString() ?? 'GET',
      url: item['url']?.toString() ?? '',
      path: item['path']?.toString(),
      statusCode: status,
      ok: ok,
      durationMs: (item['durationMs'] as num?)?.toInt(),
      requestHeaders: mapHeaders(item['requestHeaders']),
      responseHeaders: mapHeaders(item['responseHeaders']),
      requestBody: item['requestBody']?.toString(),
      responseBody: responseBody,
      businessSuccess: businessSuccess,
      businessCode: businessCode,
      error: item['error']?.toString(),
      ts: (item['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      userId: userId,
      source: source,
    );
  }

  String get copyText => jsonEncode({
        'source': source ?? RemoteDebugProtocol.sourceFlutter,
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'businessSuccess': businessSuccess,
        'businessCode': businessCode,
        'ok': ok,
        'durationMs': durationMs,
        'requestHeaders': requestHeaders,
        'requestBody': requestBody,
        'responseHeaders': responseHeaders,
        'responseBody': responseBody,
        'error': error,
        'ts': ts,
      });

  /// Plain-text export: URL, headers, request body, response body.
  String get exportText {
    final buf = StringBuffer();
    final time = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    buf.writeln('时间: $time');
    buf.writeln('请求地址: $method $url');
    if (path != null && path!.isNotEmpty) {
      buf.writeln('Path: $path');
    }
    if (statusCode != null) buf.writeln('HTTP Status: $statusCode');
    if (businessSuccess != null) {
      buf.writeln('Success: $businessSuccess');
    }
    if (businessCode != null) buf.writeln('Business Code: $businessCode');
    if (durationMs != null) buf.writeln('Duration: ${durationMs}ms');
    if (error != null && error!.isNotEmpty) buf.writeln('Error: $error');
    buf.writeln('请求头:');
    if (requestHeaders.isEmpty) {
      buf.writeln('(empty)');
    } else {
      for (final e in requestHeaders.entries) {
        buf.writeln('${e.key}: ${e.value}');
      }
    }
    buf.writeln('请求内容:');
    buf.writeln(
      (requestBody == null || requestBody!.isEmpty) ? '(empty)' : requestBody,
    );
    buf.writeln('返回内容:');
    buf.writeln(
      (responseBody == null || responseBody!.isEmpty)
          ? '(empty)'
          : responseBody,
    );
    return buf.toString().trimRight();
  }
}

class DevicePresence {
  DevicePresence({
    required this.deviceId,
    this.userId,
    required this.lastSeen,
    DateTime? firstSeen,
    this.appVersion,
    this.platform,
    this.launchId,
    this.env,
    this.online = true,
    this.reportingEnabled = false,
    Map<String, String>? deviceInfo,
  })  : firstSeen = firstSeen ?? lastSeen,
        deviceInfo = deviceInfo ?? {};

  final String deviceId;
  String? userId;

  /// First time this device appeared in the online list (stable sort key).
  DateTime firstSeen;
  DateTime lastSeen;
  String? appVersion;
  String? platform;
  String? launchId;

  /// `sit` | `prod` from compact presence `e`.
  String? env;
  bool online;

  /// True when device uploads logs/HTTP (admin opened debug).
  bool reportingEnabled;
  Map<String, String> deviceInfo;

  String get envLabel => RemoteDebugProtocol.envLabel(env);

  String get streamTopic =>
      RemoteDebugProtocol.streamTopic(userId: userId, deviceId: deviceId);

  bool get isLoggedIn {
    final uid = userId?.trim();
    return uid != null && uid.isNotEmpty && uid != '0' && uid != 'anon';
  }

  String get listTitle {
    if (isLoggedIn) return '用户 $userId';
    final short = deviceId.length > 8 ? deviceId.substring(0, 8) : deviceId;
    return '未登录 · $short';
  }

  String? get displayModel =>
      deviceInfo['model'] ?? deviceInfo['localizedModel'];

  String? get displayOs {
    final name = deviceInfo['systemName'];
    final ver = deviceInfo['systemVersion'] ?? deviceInfo['androidRelease'];
    if (name != null && ver != null) return '$name $ver';
    if (ver != null) return ver;
    return platform;
  }

  /// Preferred display order for common Sentry / identity fields.
  static const List<String> preferredInfoKeys = [
    'environment',
    'release',
    'dist',
    'userId',
    'session',
    'appName',
    'packageName',
    'version',
    'buildNumber',
    'appLuanchId',
    'platform',
    'model',
    'localizedModel',
    'name',
    'manufacturer',
    'brand',
    'systemName',
    'systemVersion',
    'androidRelease',
    'sdkInt',
    'machine',
    'isPhysicalDevice',
    'isDebug',
    'token',
  ];

  List<MapEntry<String, String>> get sortedDeviceInfoEntries {
    final entries = deviceInfo.entries.toList();
    int rank(String key) {
      final i = preferredInfoKeys.indexOf(key);
      return i >= 0 ? i : preferredInfoKeys.length;
    }

    entries.sort((a, b) {
      final ra = rank(a.key);
      final rb = rank(b.key);
      if (ra != rb) return ra.compareTo(rb);
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  /// Grouped sections for the device-info panel.
  List<DeviceInfoSection> get deviceInfoSections {
    const appKeys = {
      'environment',
      'release',
      'dist',
      'appName',
      'packageName',
      'version',
      'buildNumber',
      'appLuanchId',
      'isDebug',
      'platform',
    };
    const userKeys = {'userId', 'session', 'token'};
    const deviceKeys = {
      'model',
      'localizedModel',
      'name',
      'manufacturer',
      'brand',
      'board',
      'device',
      'product',
      'hardware',
      'display',
      'host',
      'id',
      'machine',
      'identifierForVendor',
      'isPhysicalDevice',
    };
    const osKeys = {
      'systemName',
      'systemVersion',
      'androidRelease',
      'sdkInt',
      'incremental',
      'utsnameRelease',
      'utsnameVersion',
      'sysname',
      'nodename',
      'time',
    };

    final remaining = Map<String, String>.from(deviceInfo);
    List<MapEntry<String, String>> take(Set<String> keys) {
      final out = <MapEntry<String, String>>[];
      for (final key in preferredInfoKeys) {
        if (!keys.contains(key)) continue;
        final v = remaining.remove(key);
        if (v != null) out.add(MapEntry(key, v));
      }
      final rest = remaining.entries
          .where((e) => keys.contains(e.key))
          .toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final e in rest) {
        remaining.remove(e.key);
        out.add(e);
      }
      return out;
    }

    final sections = <DeviceInfoSection>[
      DeviceInfoSection(title: '应用 / 环境', entries: take(appKeys)),
      DeviceInfoSection(title: '用户', entries: take(userKeys)),
      DeviceInfoSection(title: '设备', entries: take(deviceKeys)),
      DeviceInfoSection(title: '系统', entries: take(osKeys)),
    ];
    if (remaining.isNotEmpty) {
      final other = remaining.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      sections.add(DeviceInfoSection(title: '其他', entries: other));
    }
    return sections.where((s) => s.entries.isNotEmpty).toList();
  }
}

class DeviceInfoSection {
  DeviceInfoSection({required this.title, required this.entries});

  final String title;
  final List<MapEntry<String, String>> entries;
}
