import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api.dart';

/// Actual device viewing progress, isolated by account; no sample records.
class WatchHistory extends ChangeNotifier {
  WatchHistory(this.storage);
  final SessionStorage storage;
  final Map<String, List<Json>> _rows = {};
  final Map<String, Future<void>> _loading = {};
  Future<void> _writes = Future.value();
  List<Json> rows(String scope) => List.unmodifiable(_rows[scope] ?? []);
  Future<void> load(String scope) => _loading.putIfAbsent(scope, () async {
    try {
      final raw = await storage.read('watch-history:$scope');
      _rows[scope] = raw == null ? [] : objects(jsonDecode(raw));
    } catch (_) {
      _rows[scope] = [];
    }
    notifyListeners();
  });

  Future<void> record(String scope, Json row) async {
    await load(scope);
    final entries = _rows[scope]!;
    entries.removeWhere((e) => e['skitId'] == row['skitId']);
    entries.insert(0, {...row, 'watchedAt': DateTime.now().toIso8601String()});
    if (entries.length > 100) entries.removeRange(100, entries.length);
    final value = jsonEncode(entries);
    notifyListeners();
    _writes = _writes
        .then((_) => storage.write('watch-history:$scope', value))
        .catchError((Object _) {});
    await _writes;
  }
}
