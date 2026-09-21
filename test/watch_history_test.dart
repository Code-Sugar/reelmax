import 'package:flutter_test/flutter_test.dart';
import 'package:reelmax/src/watch_history.dart';
import 'api_test.dart' show MemorySessionStorage;

void main() {
  test(
    'real progress persists by account and keeps latest episode per show',
    () async {
      final storage = MemorySessionStorage();
      final history = WatchHistory(storage);
      await history.record('user-1', {
        'skitId': 4,
        'dramaId': 10,
        'positionMs': 6000,
      });
      await history.record('user-1', {
        'skitId': 4,
        'dramaId': 30,
        'positionMs': 12000,
      });
      await history.record('user-2', {
        'skitId': 4,
        'dramaId': 40,
        'positionMs': 4000,
      });
      final restored = WatchHistory(storage);
      await restored.load('user-1');
      expect(restored.rows('user-1'), hasLength(1));
      expect(restored.rows('user-1').single['dramaId'], 30);
      expect(restored.rows('user-1').single['positionMs'], 12000);
      await restored.load('guest');
      expect(restored.rows('guest'), isEmpty);
      await restored.load('user-2');
      expect(restored.rows('user-2').single['dramaId'], 40);
      history.dispose();
      restored.dispose();
    },
  );
}
