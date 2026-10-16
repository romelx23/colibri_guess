import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/api_client.dart';
import '../../data/session_store.dart';
import '../../models/player.dart';
import '../../models/progress_state.dart';

enum SyncStatus { idle, syncing, synced, offline }

/// Resultado de guardar nickname + icono de perfil.
enum IdentityStatus { success, offline, rejected }

class IdentityResult {
  const IdentityResult(this.status, {this.player, this.error, this.suggestion});

  final IdentityStatus status;
  final Player? player;

  /// Mensaje del servidor cuando el nickname fue rechazado (422/403).
  final String? error;

  /// Variante libre sugerida cuando el nickname estaba tomado (409).
  final String? suggestion;

  bool get isOk => status == IdentityStatus.success;
}

class SessionState {
  const SessionState({
    required this.player,
    required this.syncStatus,
    this.pendingSync = false,
    this.lastError,
  });

  final Player? player;
  final SyncStatus syncStatus;
  final bool pendingSync;
  final String? lastError;

  bool get isReady => player != null;

  SessionState copyWith({
    Player? player,
    SyncStatus? syncStatus,
    bool? pendingSync,
    String? lastError,
    bool clearError = false,
  }) {
    return SessionState(
      player: player ?? this.player,
      syncStatus: syncStatus ?? this.syncStatus,
      pendingSync: pendingSync ?? this.pendingSync,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Se inicializa de forma síncrona en `main()` para que el router pueda leer
/// la primera ejecución antes de pintar el primer frame.
final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('preferencesProvider vive en main()'),
);

final sessionStoreProvider = FutureProvider<SessionStore>(
  (ref) => SessionStore.open(),
);

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final store = await ref.watch(sessionStoreProvider.future);
    final api = ref.read(apiClientProvider);
    api.token = store.token;

    // Identidad local: sin red no hay problema, se guarda y se sincroniza después.
    Player? player = store.cachedPlayer;
    player ??= await _registerGuest(store, api);

    return SessionState(
      player: player,
      syncStatus: SyncStatus.idle,
      pendingSync: false,
    );
  }

  Future<Player?> _registerGuest(SessionStore store, ApiClient api) async {
    try {
      final body = await api.post('/api/players/guest', {
        'deviceId': store.deviceId,
        'name': store.displayName,
      }, auth: false);
      final token = body['token'] as String?;
      final json = body['player'] as Map<String, dynamic>?;
      if (token == null || json == null) return null;
      store.token = token;
      api.token = token;
      final player = Player.fromJson(json);
      store.cachedPlayer = player;
      return player;
    } on ApiException {
      // Sin conexión: seguimos con perfil local y se registrará después.
      return store.cachedPlayer;
    }
  }

  Future<void> refresh() async {
    final store = await ref.read(sessionStoreProvider.future);
    final api = ref.read(apiClientProvider);
    api.token = store.token;

    if (store.token == null) {
      final player = await _registerGuest(store, api);
      if (player != null) state = AsyncData(SessionState(player: player, syncStatus: SyncStatus.idle));
      return;
    }

    try {
      final body = await api.get('/api/players/me');
      final json = body['player'] as Map<String, dynamic>?;
      if (json == null) return;
      final player = Player.fromJson(json);
      store.cachedPlayer = player;
      state = AsyncData(
        SessionState(player: player, syncStatus: SyncStatus.idle),
      );
    } on ApiException catch (e) {
      if (e.isNetwork) return;
      // Token inválido o cuenta borrada: volvemos a registrar el invitado.
      await store.clearIdentity();
      api.token = null;
      final player = await _registerGuest(store, api);
      if (player != null) {
        state = AsyncData(
          SessionState(player: player, syncStatus: SyncStatus.idle),
        );
      }
    }
  }

  Future<void> setDisplayName(String name) async {
    final store = await ref.read(sessionStoreProvider.future);
    store.displayName = name;
    final current = state.valueOrNull?.player;
    if (current == null) return;
    try {
      final body = await ref
          .read(apiClientProvider)
          .post('/api/players/guest', {'deviceId': store.deviceId, 'name': name});
      final json = body['player'] as Map<String, dynamic>?;
      if (json == null) return;
      final player = Player.fromJson(json);
      store.cachedPlayer = player;
      state = AsyncData(SessionState(player: player, syncStatus: SyncStatus.idle));
    } on ApiException {
      // offline: el nombre local ya quedó guardado
    }
  }

  /// Guarda la identidad (nickname único + icono) en el servidor.
  ///
  /// - OK: actualiza el player y confirma locales.
  /// - Sin red: deja nick/icono locales y marca `pendingIdentity` para
  ///   reintentar con [retryPendingIdentity].
  /// - Rechazado (422 ofensivo / 409 tomado / 403 icono bloqueado): NO
  ///   guarda nada y devuelve el error (+ sugerencia en 409).
  Future<IdentityResult> updateIdentity({
    required String displayName,
    required String avatarId,
  }) async {
    final store = await ref.read(sessionStoreProvider.future);
    if (store.token == null) {
      final registered = await _registerGuest(store, ref.read(apiClientProvider));
      if (registered == null) {
        _saveLocalIdentity(store, displayName, avatarId);
        return const IdentityResult(IdentityStatus.offline);
      }
    }
    return _putIdentity(store, displayName, avatarId, saveLocalOnNetworkError: true);
  }

  /// Reintenta subir una identidad que quedó pendiente por falta de red.
  Future<void> retryPendingIdentity() async {
    final store = await ref.read(sessionStoreProvider.future);
    if (!store.pendingIdentity) return;
    await _putIdentity(
      store,
      store.displayName,
      store.avatarId,
      saveLocalOnNetworkError: false,
    );
  }

  Future<IdentityResult> _putIdentity(
    SessionStore store,
    String displayName,
    String avatarId, {
    required bool saveLocalOnNetworkError,
  }) async {
    final api = ref.read(apiClientProvider);
    api.token = store.token ?? api.token;
    try {
      final body = await api.put('/api/players/me', {
        'displayName': displayName,
        'avatarId': avatarId,
      });
      final json = body['player'] as Map<String, dynamic>?;
      if (json == null) return const IdentityResult(IdentityStatus.rejected, error: 'Respuesta inesperada del servidor');
      final player = Player.fromJson(json);
      store.displayName = player.displayName;
      store.avatarId = player.avatarId;
      store.pendingIdentity = false;
      store.cachedPlayer = player;
      state = AsyncData(SessionState(player: player, syncStatus: SyncStatus.idle));
      return IdentityResult(IdentityStatus.success, player: player);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        if (saveLocalOnNetworkError) {
          _saveLocalIdentity(store, displayName, avatarId);
        }
        return const IdentityResult(IdentityStatus.offline);
      }
      return IdentityResult(
        IdentityStatus.rejected,
        error: e.message,
        suggestion: e.suggestion,
      );
    }
  }

  void _saveLocalIdentity(SessionStore store, String displayName, String avatarId) {
    store.displayName = displayName;
    store.avatarId = avatarId;
    store.pendingIdentity = true;
    final current = state.valueOrNull?.player;
    if (current != null) {
      final local = current.withIdentity(displayName: displayName, avatarId: avatarId);
      store.cachedPlayer = local;
      state = AsyncData(SessionState(player: local, syncStatus: SyncStatus.offline));
    }
  }

  /// Sube las respuestas de un examen para que el servidor calcule el puntaje
  /// (métrica del ranking: `examBest`). Fire-and-forget: sin red no pasa nada.
  Future<void> submitExam({
    required List<Map<String, dynamic>> answers,
    int cutoff = 70,
  }) async {
    final store = await ref.read(sessionStoreProvider.future);
    final api = ref.read(apiClientProvider);
    api.token = store.token ?? api.token;

    if (store.token == null) {
      final registered = await _registerGuest(store, api);
      if (registered == null) return;
    }

    try {
      final body = await api.post('/api/exams/submit', {
        'answers': answers,
        'cutoff': cutoff,
      });
      final examBest = (body['examBest'] as num?)?.toInt();
      final current = state.valueOrNull?.player;
      if (examBest == null || current == null) return;
      final player = current.withExamBest(examBest);
      store.cachedPlayer = player;
      state = AsyncData(
        SessionState(player: player, syncStatus: SyncStatus.idle),
      );
    } on ApiException {
      // offline o rechazo puntual: el examen local ya quedó registrado
    }
  }

  /// Sube el progreso al servidor. Si no hay red, deja `pendingSync` para reintentar.
  Future<void> syncProgress(ProgressState progress) async {
    final store = await ref.read(sessionStoreProvider.future);
    final api = ref.read(apiClientProvider);
    api.token = store.token ?? api.token;

    final current = state.valueOrNull;
    if (current == null) return;

    if (store.token == null) {
      final player = await _registerGuest(store, api);
      if (player == null) {
        state = AsyncData(current.copyWith(pendingSync: true, syncStatus: SyncStatus.offline));
        return;
      }
      state = AsyncData(SessionState(player: player, syncStatus: SyncStatus.idle));
    }

    final xpDelta = progress.xp - store.syncedXp;
    final pointsDelta = progress.points - store.syncedPoints;

    if (xpDelta <= 0 && pointsDelta <= 0 && current.player != null) {
      // nada nuevo que subir; aun así refresca racha/sesiones
    }

    state = AsyncData(
      (state.valueOrNull ?? current).copyWith(syncStatus: SyncStatus.syncing),
    );

    try {
      final body = await api.post('/api/progress/sync', {
        'xp': progress.xp,
        'points': progress.points,
        'streak': progress.streak,
        'bestStreak': progress.bestStreak,
        'sessions': progress.sessions,
        'xpDelta': xpDelta < 0 ? 0 : xpDelta,
        'pointsDelta': pointsDelta < 0 ? 0 : pointsDelta,
        'dailyXp': progress.dailyXp,
      });
      store.syncedXp = progress.xp;
      store.syncedPoints = progress.points;
      final json = body['player'] as Map<String, dynamic>?;
      final player = json == null ? null : Player.fromJson(json);
      if (player != null) store.cachedPlayer = player;
      state = AsyncData(
        SessionState(
          player: player ?? store.cachedPlayer,
          syncStatus: SyncStatus.synced,
          pendingSync: false,
        ),
      );
    } on ApiException catch (e) {
      if (e.isConflict) {
        // El servidor va adelante (p. ej. progreso reiniciado en otro lado).
        await _resetRemote(store, api, progress);
        return;
      }
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          syncStatus: e.isNetwork ? SyncStatus.offline : SyncStatus.idle,
          pendingSync: e.isNetwork,
          lastError: e.isNetwork ? null : e.message,
        ),
      );
    }
  }

  Future<void> _resetRemote(
    SessionStore store,
    ApiClient api,
    ProgressState progress,
  ) async {
    try {
      await api.delete('/api/progress');
      store.syncedXp = 0;
      store.syncedPoints = 0;
      await syncProgress(progress);
    } on ApiException {
      state = AsyncData(
        (state.valueOrNull ?? const SessionState(player: null, syncStatus: SyncStatus.idle))
            .copyWith(syncStatus: SyncStatus.offline, pendingSync: true),
      );
    }
  }
}
