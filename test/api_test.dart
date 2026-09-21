import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reelmax/src/api.dart';
import 'package:reelmax/src/account_state.dart';
import 'package:reelmax/src/hls.dart';

class MemorySessionStorage implements SessionStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

http.Response response(
  dynamic data, {
  int code = 0,
  String message = 'success',
}) => http.Response(
  jsonEncode({'code': code, 'message': message, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test(
    'restored session survives profile 500 and keeps cached account, real expiry clears it',
    () async {
      final storage = MemorySessionStorage();
      final initial = SkitApi(storage: storage);
      await initial.setToken('persisted-session');
      await initial.saveProfile({
        'id': 24,
        'nickname': 'Viewer',
        'email': 'viewer@example.com',
        'balance': 37,
        'password': 'must-not-store',
      }, 'persisted-session');
      expect(
        storage.values.values.any((v) => v.contains('must-not-store')),
        false,
      );
      initial.dispose();
      var expired = false;
      final restored = SkitApi(
        storage: storage,
        client: MockClient(
          (r) async => response(
            null,
            code: expired ? -401 : 500,
            message: 'System error',
          ),
        ),
      );
      final account = AccountStore(api: restored);
      await account.initialize();
      expect(account.signedIn, true);
      expect(restored.token, 'persisted-session');
      expect(account.user!.email, 'viewer@example.com');
      expect(account.user!.balance, 37);
      expect(account.sessionError, contains('still signed in'));
      await account.reloadProfile();
      expect(account.signedIn, true);
      expired = true;
      await account.reloadProfile();
      expect(account.signedIn, false);
      expect(account.user, isNull);
      expect(await restored.readProfile(), isNull);
      expect(
        storage.values.values.any((v) => v.contains('persisted-session')),
        false,
      );
      account.dispose();
      restored.dispose();
    },
  );

  test(
    'legacy token without cached profile stays signed in on server failure and signs out explicitly',
    () async {
      final storage = MemorySessionStorage();
      final initial = SkitApi(storage: storage);
      await initial.setToken('legacy-session');
      initial.dispose();
      final restored = SkitApi(
        storage: storage,
        client: MockClient((r) async => response(null, code: 500)),
      );
      final account = AccountStore(api: restored);
      await account.initialize();
      expect(account.signedIn, true);
      expect(account.user, isNull);
      var signedInDuringNotification = true;
      account.addListener(() => signedInDuringNotification = account.signedIn);
      await account.signOut();
      expect(account.signedIn, false);
      expect(signedInDuringNotification, false);
      account.dispose();
      restored.dispose();
    },
  );

  test(
    'catalog cache deduplicates, isolates sessions and invalidates after mutations',
    () async {
      var reads = 0;
      final gate = Completer<void>();
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          if (r.method == 'POST') return response({});
          reads++;
          if (reads == 1) await gate.future;
          return response({'version': reads});
        }),
      );
      final first = api.cachedGet('skit/detail', {'id': 1});
      final duplicate = api.cachedGet('skit/detail', {'id': 1});
      gate.complete();
      await Future.wait([first, duplicate]);
      expect(reads, 1);
      await api.cachedGet('skit/detail', {'id': 1});
      expect(reads, 1);
      await api.post('skit/like', {'skitId': 1, 'status': 1});
      await api.cachedGet('skit/detail', {'id': 1});
      expect(reads, 2);
      await api.setToken('another-user');
      await api.cachedGet('skit/detail', {'id': 1});
      expect(reads, 3);
      api.language = 'zh';
      await api.cachedGet('skit/detail', {'id': 1});
      expect(reads, 4);
      await api.get('user/info');
      await api.get('user/info');
      expect(reads, 6);
      api.dispose();
    },
  );

  test('catalog failures are retriable and are never cached', () async {
    var calls = 0;
    final api = SkitApi(
      storage: MemorySessionStorage(),
      client: MockClient((r) async {
        return ++calls == 1 ? response(null, code: 500) : response({'id': 1});
      }),
    );
    await expectLater(
      api.cachedGet('skit/detail'),
      throwsA(isA<ApiException>()),
    );
    expect(await api.cachedGet('skit/detail'), {'id': 1});
    expect(calls, 2);
    api.dispose();
  });

  test(
    'requests retain service prefix and send product and session headers',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/skit-planet/skit/collect');
        expect(request.headers['X-Package-Name'], 'com.cinera');
        expect(request.headers['R-18'], '0');
        expect(request.headers['language'], 'en');
        expect(request.headers['device'], 'apple');
        expect(request.headers['Authorization'], 'test-token');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {'skitId': 5, 'status': 1});
        return response({'saved': true});
      });
      final api = SkitApi(client: client, storage: MemorySessionStorage())
        ..language = 'zh'
        ..token = 'test-token';
      expect(await api.post('/skit/collect', {'skitId': 5, 'status': 1}), {
        'saved': true,
      });
      api.dispose();
    },
  );
  test(
    'HTTP 200 business failures remain errors and password errors do not erase another session',
    () async {
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient(
          (r) async => response(
            null,
            code: r.url.path.endsWith('register') ? -401 : 500,
            message: r.url.path.endsWith('register')
                ? 'Password error'
                : 'Server error',
          ),
        ),
      )..token = 'existing';
      await expectLater(
        api.get('skit/init'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Server error',
          ),
        ),
      );
      await expectLater(
        api.post('user/register', {'password': 'wrong'}),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Password error',
          ),
        ),
      );
      expect(api.token, 'existing');
      api.dispose();
    },
  );
  test(
    'expired session is cleared but a delayed old-session failure cannot erase a new login',
    () async {
      final pending = Completer<http.Response>();
      final storage = MemorySessionStorage();
      final api = SkitApi(
        storage: storage,
        client: MockClient((_) => pending.future),
      );
      var expired = 0;
      api.onUnauthorized = () => expired++;
      await api.setToken('old');
      final request = api.get('user/info');
      final assertion = expectLater(request, throwsA(isA<ApiException>()));
      await api.setToken('new');
      pending.complete(response(null, code: -401, message: 'Expired'));
      await assertion;
      expect(api.token, 'new');
      expect(expired, 0);
      api.dispose();
      final current = SkitApi(
        storage: storage,
        client: MockClient((_) async => response(null, code: -401)),
      );
      await current.restore();
      current.onUnauthorized = () => expired++;
      await expectLater(current.get('user/info'), throwsA(isA<ApiException>()));
      expect(current.token, isNull);
      expect(expired, 1);
      current.dispose();
    },
  );
  test(
    'email login sends actual credentials and restores server balance without demo grants',
    () async {
      final storage = MemorySessionStorage();
      var loginCalls = 0;
      final info = {
        'id': 24,
        'nickname': 'Test viewer',
        'email': 'viewer@example.com',
        'type': 'email',
        'balance': 7,
      };
      final api = SkitApi(
        storage: storage,
        client: MockClient((r) async {
          if (r.url.path.endsWith('checkEmailExists')) {
            return response({'status': 1});
          }
          if (r.url.path.endsWith('register')) {
            loginCalls++;
            expect(jsonDecode(r.body)['password'], 'the-real-password');
            return response({'authorization': 'session-token', 'info': info});
          }
          if (r.url.path.endsWith('info')) return response(info);
          fail('Unexpected endpoint ${r.url.path}');
        }),
      );
      final store = AccountStore(api: api);
      await store.initialize();
      await store.loginEmail('viewer@example.com', 'the-real-password');
      expect(store.user!.balance, 7);
      expect(store.user!.orders, isEmpty);
      expect(store.user!.id, 24);
      expect(storage.values.values, contains('session-token'));
      expect(storage.values.values, isNot(contains('the-real-password')));
      await expectLater(
        store.loginEmail('viewer@example.com', 'unused', nickname: 'Existing'),
        throwsA(isA<ApiException>()),
      );
      expect(loginCalls, 1);
      await store.refreshProfile();
      await store.signOut();
      expect(store.signedIn, isFalse);
      expect(api.token, isNull);
      store.dispose();
      api.dispose();
    },
  );
  test(
    'nonexistent email login does not silently register a new account',
    () async {
      final api = SkitApi(
        storage: MemorySessionStorage(),
        client: MockClient((r) async {
          expect(r.url.path.endsWith('checkEmailExists'), isTrue);
          return response({'status': 0});
        }),
      );
      final store = AccountStore(api: api);
      await expectLater(
        store.loginEmail('new@example.com', 'password'),
        throwsA(isA<ApiException>()),
      );
      expect(store.signedIn, isFalse);
      expect(api.token, isNull);
      store.dispose();
      api.dispose();
    },
  );
  test(
    'HLS quality selection uses declared variants and preserves signed URLs',
    () {
      final base = Uri.parse('https://example.com/media/play?token=secret');
      final variants = hlsVariants(
        '#EXTM3U\n#EXT-X-STREAM-INF:RESOLUTION=1280x720\n?token=secret&playlist=720\n#EXT-X-STREAM-INF:RESOLUTION=1920x1080\nhigh.m3u8\n',
        base,
      );
      expect(
        variants['720p'].toString(),
        'https://example.com/media/play?token=secret&playlist=720',
      );
      expect(
        variants['1080p'].toString(),
        'https://example.com/media/high.m3u8',
      );
      expect(variants.containsKey('4K'), isFalse);
      final signed = hlsVariants(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=3436400\n?token=test&playlist=NzIwcC5tM3U4&playlistSig=signature',
        base,
      );
      expect(signed['720p']?.queryParameters['playlistSig'], 'signature');
      expect(hlsVariants('#EXTM3U\n#EXTINF:5\nsegment.ts', base).keys, [
        'Auto',
      ]);
    },
  );
}
