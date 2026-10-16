import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';

/// Identidad local + marcadores de lo que ya se envió al servidor.
class SessionStore {
  SessionStore(this._prefs);

  static const String _kDeviceId = 'colibri.device.v1';
  static const String _kToken = 'colibri.token.v1';
  static const String _kName = 'colibri.name.v1';
  static const String _kPlayer = 'colibri.player.v1';
  static const String _kSyncedXp = 'colibri.syncedXp.v1';
  static const String _kSyncedPoints = 'colibri.syncedPoints.v1';
  static const String _kAvatarId = 'colibri.avatarId.v1';
  static const String _kPendingIdentity = 'colibri.pendingIdentity.v1';

  static const String kOnboardingPref = 'colibri.onboarding.v1';

  final SharedPreferences _prefs;

  static Future<SessionStore> open() async =>
      SessionStore(await SharedPreferences.getInstance());

  String get deviceId {
    final existing = _prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    _prefs.setString(_kDeviceId, generated);
    return generated;
  }

  String get displayName => _prefs.getString(_kName) ?? 'Jugador';

  set displayName(String value) => _prefs.setString(_kName, value);

  /// Icono de perfil elegido localmente (aún no confirmado por el servidor).
  String get avatarId => _prefs.getString(_kAvatarId) ?? 'chick';

  set avatarId(String value) => _prefs.setString(_kAvatarId, value);

  /// true = la identidad (nick/icono) cambió offline y falta subirla.
  bool get pendingIdentity => _prefs.getBool(_kPendingIdentity) ?? false;

  set pendingIdentity(bool value) => _prefs.setBool(_kPendingIdentity, value);

  String? get token => _prefs.getString(_kToken);

  set token(String? value) =>
      value == null ? _prefs.remove(_kToken) : _prefs.setString(_kToken, value);

  Player? get cachedPlayer {
    final raw = _prefs.getString(_kPlayer);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Player.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  set cachedPlayer(Player? value) {
    if (value == null) {
      _prefs.remove(_kPlayer);
    } else {
      _prefs.setString(_kPlayer, jsonEncode({
        'id': value.id,
        'deviceId': value.deviceId,
        'displayName': value.displayName,
        'avatarSeed': value.avatarSeed,
        'avatarId': value.avatarId,
        'isGuest': value.isGuest,
        'email': value.email,
        'xp': value.xp,
        'points': value.points,
        'examBest': value.examBest,
        'streak': value.streak,
        'bestStreak': value.bestStreak,
        'sessions': value.sessions,
      }));
    }
  }

  int get syncedXp => _prefs.getInt(_kSyncedXp) ?? 0;

  set syncedXp(int value) => _prefs.setInt(_kSyncedXp, value);

  int get syncedPoints => _prefs.getInt(_kSyncedPoints) ?? 0;

  set syncedPoints(int value) => _prefs.setInt(_kSyncedPoints, value);

  Future<void> clearIdentity() async {
    token = null;
    cachedPlayer = null;
    syncedXp = 0;
    syncedPoints = 0;
  }

  static String _generateDeviceId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'dev_$hex';
  }
}
