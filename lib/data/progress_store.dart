import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_state.dart';

class ProgressStore {
  ProgressStore(this._prefs);

  static const String key = 'colibri.progress.v1';

  final SharedPreferences _prefs;

  static Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance());

  ProgressState load() {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return const ProgressState();
    try {
      return ProgressState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ProgressState();
    }
  }

  Future<void> save(ProgressState state) async {
    await _prefs.setString(key, jsonEncode(state.toJson()));
  }

  Future<void> reset() async => _prefs.remove(key);
}
