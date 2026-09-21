import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

typedef Json = Map<String, dynamic>;
Json object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> objects(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : value is Map
    ? objects(value['records'] ?? value['list'])
    : [];
int integer(dynamic value) => num.tryParse('$value')?.toInt() ?? 0;
String string(dynamic value) => value == null ? '' : '$value';

class ApiException implements Exception {
  const ApiException(this.message, {this.code});
  final String message;
  final int? code;
  @override
  String toString() => message;
}

abstract interface class SessionStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSessionStorage implements SessionStorage {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class SkitApi {
  SkitApi({
    http.Client? client,
    SessionStorage? storage,
    String? baseUrl,
    String? packageName,
  }) : client = client ?? http.Client(),
       storage = storage ?? SecureSessionStorage(),
       base = Uri.parse(
         '${(baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.0.199:8091/skit-planet/')).replaceAll(RegExp(r'/+$'), '')}/',
       ),
       packageName =
           packageName ??
           const String.fromEnvironment(
             'API_PACKAGE_NAME',
             defaultValue: 'com.cinera',
           );
  final http.Client client;
  final SessionStorage storage;
  final Uri base;
  final String packageName;
  String? token;
  int _tokenVersion = 0;
  String deviceId = '';
  String language = 'en';
  VoidCallback? onUnauthorized;
  final _cache = <String, ({DateTime at, dynamic value})>{};
  final _pending = <String, Future<dynamic>>{};
  int catalogRevision = 0;
  String _cacheKey(String path, Json query) {
    final keys = query.keys.toList()..sort();
    return jsonEncode([
      token,
      language,
      catalogRevision,
      path,
      {for (final key in keys) key: query[key]},
    ]);
  }

  /// Catalog data only. Payment, balances and playback authorization stay live.
  Future<dynamic> cachedGet(String path, [Json query = const {}]) {
    final key = _cacheKey(path, query);
    final hit = _cache[key];
    if (hit != null &&
        DateTime.now().difference(hit.at) < const Duration(minutes: 5)) {
      return Future.value(hit.value);
    }
    return _pending.putIfAbsent(key, () async {
      try {
        final value = await get(path, query);
        if (_cache.length >= 80) _cache.remove(_cache.keys.first);
        _cache[key] = (at: DateTime.now(), value: value);
        return value;
      } finally {
        _pending.remove(key);
      }
    });
  }

  void invalidateCatalog() {
    catalogRevision++;
    _cache.clear();
    _pending.clear();
  }

  String get platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';
  String get _sessionKey => 'session:${base.origin}:${base.path}:$packageName';
  Future<Json?> readProfile() async {
    if (token == null) return null;
    final saved = await storage.read('$_sessionKey:profile');
    if (saved == null) return null;
    try {
      final value = object(jsonDecode(saved));
      return value['session'] == token ? object(value['info']) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> saveProfile(Json info, String expectedToken) async {
    if (token != expectedToken) return;
    // Store only display fields, never passwords or third-party credentials.
    final display = <String, dynamic>{
      for (final key in [
        'id',
        'nickname',
        'email',
        'accountId',
        'type',
        'balance',
        'memberDate',
        'profile',
        'member',
      ])
        if (info.containsKey(key)) key: info[key],
    };
    await storage.write(
      '$_sessionKey:profile',
      jsonEncode({'session': expectedToken, 'info': display}),
    );
  }

  Future<void> restore() async {
    final version = _tokenVersion;
    final savedToken = await storage.read(_sessionKey);
    if (version == _tokenVersion) token = savedToken;
    deviceId = await storage.read('reelmax-install-id') ?? '';
    if (deviceId.isEmpty) {
      final random = Random.secure();
      deviceId = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await storage.write('reelmax-install-id', deviceId);
    }
  }

  Future<void> setToken(String? value) async {
    _tokenVersion++;
    if (token != value) invalidateCatalog();
    token = value;
    await storage.write(_sessionKey, value);
    if (value == null) await storage.write('$_sessionKey:profile', null);
  }

  Future<dynamic> get(String path, [Json query = const {}]) =>
      request('GET', path, query: query);
  Future<dynamic> post(String path, [Json body = const {}]) async {
    final result = await request('POST', path, body: body);
    if (const {
      'skit/like',
      'skit/collect',
      'skit/likeDrama',
      'skit/collectDrama',
      'skit/buyDrama',
      'skit/batchCancelCollectLike',
    }.contains(path.replaceFirst(RegExp(r'^/+'), ''))) {
      invalidateCatalog();
    }
    return result;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Json query = const {},
    Json? body,
  }) async {
    final uri = base
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .replace(
          queryParameters: query.isEmpty
              ? null
              : query.map((k, v) => MapEntry(k, '$v')),
        );
    final requestToken = token;
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Package-Name': packageName,
        'R-18': '0',
        'language': 'en',
        'device': 'apple',
        'timeZone': const String.fromEnvironment(
          'API_TIME_ZONE',
          defaultValue: 'Asia/Shanghai',
        ),
        if (requestToken != null) 'Authorization': requestToken,
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(
        await client.send(request),
      ).timeout(const Duration(seconds: 25));
      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw const ApiException('服务返回了无法识别的数据，请稍后重试。');
      }
      final result = object(decoded);
      final code = result['code'] == null
          ? response.statusCode
          : integer(result['code']);
      if ((response.statusCode == 401 || code == 401 || code == -401) &&
          path != 'user/register' &&
          path != 'user/resetEmailPassword') {
        if (token == requestToken && requestToken != null) {
          await setToken(null);
          onUnauthorized?.call();
        }
        throw const ApiException('登录已过期，请重新登录。', code: 401);
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          (code != 0 && code != 200)) {
        throw ApiException(
          string(result['message'] ?? result['msg']).isEmpty
              ? '请求失败，请稍后重试。'
              : string(result['message'] ?? result['msg']),
          code: code,
        );
      }
      return result['data'];
    } on TimeoutException {
      throw const ApiException('连接超时，请检查网络后重试。');
    } on http.ClientException {
      throw const ApiException('无法连接服务器，请检查网络。');
    }
  }

  void dispose() => client.close();
}
