import 'dart:convert';

/// Shared remote-debug protocol (App publisher + desktop subscriber).
class RemoteDebugProtocol {
  static const String presenceTopic = 'winnerapp_debug_presence';
  static const String defaultBaseUrl = 'http://119.23.47.1:8385/';
  /// Default access token (override via SharedPreferences). Prefer local prefs in prod.
  static const String defaultAccessToken = 'tk_6c0b3ec5cf01uyy46swg86330rqho';

  static const Duration presenceInterval = Duration(seconds: 5);
  static const Duration presenceTimeout = Duration(seconds: 15);
  static const Duration keepaliveWatchdog = Duration(seconds: 45);
  static const int maxMessageBytes = 900 * 1024;
  static const int maxBufferItems = 5000;

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
  batch;

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
      default:
        return null;
    }
  }

  String get wire => name;
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

  factory RemoteDebugEnvelope.fromJson(Map<String, dynamic> json) {
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
    return RemoteDebugEnvelope(
      type: type,
      deviceId: json['deviceId']?.toString() ?? '',
      userId: json['userId']?.toString(),
      launchId: json['launchId']?.toString(),
      appVersion: json['appVersion']?.toString(),
      platform: json['platform']?.toString(),
      ts: (json['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      items: items,
      deviceInfo: _parseStringMap(json['deviceInfo']),
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
      };

  String encode() =>
      RemoteDebugProtocol.truncateForNtfy(jsonEncode(toJson()));
}

class DebugLogEntry {
  DebugLogEntry({
    required this.level,
    required this.message,
    required this.ts,
    this.tag,
    this.deviceId,
    this.userId,
  });

  final String level;
  final String message;
  final int ts;
  final String? tag;
  final String? deviceId;
  final String? userId;

  factory DebugLogEntry.fromItem(
    Map<String, dynamic> item, {
    String? deviceId,
    String? userId,
  }) {
    return DebugLogEntry(
      level: item['level']?.toString() ?? 'i',
      message: item['message']?.toString() ?? '',
      tag: item['tag']?.toString(),
      ts: (item['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      userId: userId,
    );
  }

  String get copyText {
    final time = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    return '[$time][$level]${tag != null ? '[$tag]' : ''} $message';
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
    this.error,
    required this.ts,
    this.deviceId,
    this.userId,
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
  final String? error;
  final int ts;
  final String? deviceId;
  final String? userId;

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
    final okFlag = item['ok'];
    final ok = okFlag is bool
        ? okFlag
        : (status != null && status >= 200 && status < 400);

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
      responseBody: item['responseBody']?.toString(),
      error: item['error']?.toString(),
      ts: (item['ts'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      deviceId: deviceId,
      userId: userId,
    );
  }

  String get copyText => jsonEncode({
        'method': method,
        'url': url,
        'statusCode': statusCode,
        'ok': ok,
        'durationMs': durationMs,
        'requestHeaders': requestHeaders,
        'requestBody': requestBody,
        'responseHeaders': responseHeaders,
        'responseBody': responseBody,
        'error': error,
        'ts': ts,
      });
}

class DevicePresence {
  DevicePresence({
    required this.deviceId,
    this.userId,
    required this.lastSeen,
    this.appVersion,
    this.platform,
    this.launchId,
    this.online = true,
    Map<String, String>? deviceInfo,
  }) : deviceInfo = deviceInfo ?? {};

  final String deviceId;
  String? userId;
  DateTime lastSeen;
  String? appVersion;
  String? platform;
  String? launchId;
  bool online;
  Map<String, String> deviceInfo;

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
