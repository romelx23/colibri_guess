import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ingresa_ya/core/providers/session_provider.dart';
import 'package:ingresa_ya/data/api_client.dart';
import 'package:ingresa_ya/features/leaderboard/leaderboard_page.dart';
import 'package:ingresa_ya/models/progress_state.dart';

/// Integration test: ejecuta el codigo real de la app (ApiClient, SessionNotifier,
/// leaderboardProvider) contra un API vivo.
///
/// Requiere el backend arrancado:  cd colibri-backend && npm run dev
/// Si el API no responde, el test se omite en lugar de fallar, para que
/// `flutter test` siga siendo verde sin servidor.
const _base = String.fromEnvironment('API_URL',
    defaultValue: 'http://127.0.0.1:4000');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la app habla con el API real: invitado, /me, sync y ranking', () async {
    // flutter_test instala un HttpOverrides que mockea dart:io HttpClient y
    // responde 400 a todo. Este test necesita red real.
    HttpOverrides.global = null;

    SharedPreferences.setMockInitialValues({});

    final probe = ApiClient(baseUrl: _base);
    try {
      final health = await probe.get('/api/health', auth: false);
      expect(health['status'], 'ok');
    } catch (e) {
      debugPrint('AVISO: API no responde en $_base - test omitido ($e). '
          'Arranca el backend con: cd colibri-backend && npm run dev');
      return;
    }

    final container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(ApiClient(baseUrl: _base)),
    ]);
    addTearDown(container.dispose);

    // 1. Registro de invitado -> token + player (session_provider.dart)
    final session = await container.read(sessionProvider.future);
    expect(session.player, isNotNull,
        reason: 'el registro de invitado debe devolver un player');
    expect(session.player!.isGuest, isTrue);
    expect(session.player!.id, isNotEmpty);
    final token = container.read(apiClientProvider).token;
    expect(token, isNotNull, reason: 'el token JWT debe guardarse en la sesion');

    // 2. GET /api/players/me con Bearer -> el mismo player
    final me = await container.read(apiClientProvider).get('/api/players/me');
    expect(me['player']['id'], session.player!.id);

    // 3. POST /api/progress/sync -> el servidor acepta el payload de la app
    await container
        .read(sessionProvider.notifier)
        .syncProgress(const ProgressState(
          xp: 40,
          points: 15,
          streak: 2,
          bestStreak: 5,
          sessions: 1,
          dailyXp: 10,
        ));
    final after = container.read(sessionProvider).valueOrNull!;
    expect(after.syncStatus, SyncStatus.synced,
        reason: 'sync fallo: ${after.lastError ?? 'sin detalle'}');
    expect(after.player!.xp, 40);
    expect(after.player!.points, 15);
    expect(after.pendingSync, isFalse);

    // 4. GET /api/leaderboard -> LeaderboardResult.fromJson parsea la respuesta
    final leaderboard = container.listen(
      leaderboardProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final board = await container.read(leaderboardProvider.future);
    expect(board.items, isNotEmpty, reason: 'debe haber jugadores sembrados');
    expect(board.items.first.rank, 1);
    // Con el token enviado, el backend devuelve tu fila (tu posición)
    expect(board.me, isNotNull, reason: 'el backend debe devolver "me"');
    expect(board.me!.playerId, session.player!.id);
    expect(board.me!.rank, greaterThanOrEqualTo(1));
    expect(leaderboard, isNotNull);

    // 5. Limpieza: deja el progreso del jugador de prueba en cero
    await container.read(apiClientProvider).delete('/api/progress');
  });
}
