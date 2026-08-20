import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef NtfyJsonHandler = void Function(Map<String, dynamic> json);

/// Minimal ntfy JSON stream client with Bearer auth (query + publish body).
class NtfyDebugClient {
  NtfyDebugClient({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  String baseUrl;
  String accessToken;
  final http.Client _http;

  final Map<String, _ActiveSub> _subs = {};

  Uri get _root {
    var s = baseUrl.trim();
    if (!s.endsWith('/')) s = '$s/';
    return Uri.parse(s);
  }

  String get _authQueryValue =>
      base64Encode(utf8.encode('Bearer $accessToken'));

  Future<void> publish({
    required String topic,
    required String message,
    String? title,
    List<String>? tags,
  }) async {
    // Match App chat publish: auth must be on the POST URL query
    // (`?auth=base64(Bearer token)`), same as NtfyMessageManager._createClient.
    final uri = _root.replace(
      queryParameters: {
        ..._root.queryParameters,
        'auth': _authQueryValue,
      },
    );
    final body = <String, dynamic>{
      'topic': topic,
      'message': message,
      'authorization': 'Bearer $accessToken',
      if (title != null) 'title': title,
      if (tags != null) 'tags': tags,
    };
    final response = await _http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'ntfy publish failed ${response.statusCode} '
        'host=${uri.host} topic=$topic: ${response.body}',
      );
    }
  }

  Future<void> subscribe({
    required String topic,
    required NtfyJsonHandler onMessage,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) async {
    await unsubscribe(topic);

    final listenUri = Uri(
      scheme: _root.scheme,
      host: _root.host,
      port: _root.hasPort ? _root.port : null,
      path: '/$topic/json',
      queryParameters: {'auth': _authQueryValue},
    );

    final request = http.Request('GET', listenUri);
    final streamed = await _http.send(request);
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = await streamed.stream.bytesToString();
      throw StateError('ntfy subscribe failed ${streamed.statusCode}: $body');
    }

    var buffer = '';
    final sub = streamed.stream.transform(utf8.decoder).listen(
      (chunk) {
        buffer += chunk;
        var idx = buffer.indexOf('\n');
        while (idx >= 0) {
          final line = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 1);
          if (line.isNotEmpty) {
            try {
              final json = jsonDecode(line);
              if (json is Map<String, dynamic>) {
                onMessage(json);
              } else if (json is Map) {
                onMessage(Map<String, dynamic>.from(json));
              }
            } catch (_) {
              // ignore malformed keepalive fragments
            }
          }
          idx = buffer.indexOf('\n');
        }
      },
      onError: (e) => onError?.call(e),
      onDone: () => onDone?.call(),
      cancelOnError: true,
    );

    _subs[topic] = _ActiveSub(subscription: sub, response: streamed);
  }

  Future<void> unsubscribe(String topic) async {
    final existing = _subs.remove(topic);
    await existing?.subscription.cancel();
  }

  Future<void> unsubscribeAll() async {
    final topics = _subs.keys.toList();
    for (final t in topics) {
      await unsubscribe(t);
    }
  }

  void close() {
    unawaited(unsubscribeAll());
    _http.close();
  }
}

class _ActiveSub {
  _ActiveSub({required this.subscription, required this.response});
  final StreamSubscription subscription;
  final http.StreamedResponse response;
}
