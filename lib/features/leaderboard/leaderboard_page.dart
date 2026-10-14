import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.avatarSeed,
    required this.isGuest,
    required this.streak,
    required this.score,
  });

  final int rank;
  final String playerId;
  final String displayName;
  final int avatarSeed;
  final bool isGuest;
  final int streak;
  final int score;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        playerId: json['playerId'] as String? ?? '',
        displayName: json['displayName'] as String? ?? 'Jugador',
        avatarSeed: (json['avatarSeed'] as num?)?.toInt() ?? 0,
        isGuest: json['isGuest'] as bool? ?? true,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        score: (json['score'] as num?)?.toInt() ?? 0,
      );
}

class LeaderboardResult {
  const LeaderboardResult({required this.items, required this.me});

  final List<LeaderboardEntry> items;
  final LeaderboardEntry? me;

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final me = json['me'] as Map<String, dynamic>?;
    return LeaderboardResult(
      items: raw.map(LeaderboardEntry.fromJson).toList(),
      me: me == null ? null : LeaderboardEntry.fromJson(me),
    );
  }
}

enum LeaderboardPeriod { week, month, all }

extension LeaderboardPeriodX on LeaderboardPeriod {
  String get label => switch (this) {
        LeaderboardPeriod.week => 'Semana',
        LeaderboardPeriod.month => 'Mes',
        LeaderboardPeriod.all => 'Histórico',
      };

  String get query => switch (this) {
        LeaderboardPeriod.week => 'week',
        LeaderboardPeriod.month => 'month',
        LeaderboardPeriod.all => 'all',
      };

  String get unit => switch (this) {
        LeaderboardPeriod.week => 'XP esta semana',
        LeaderboardPeriod.month => 'XP este mes',
        LeaderboardPeriod.all => 'XP total',
      };
}

final leaderboardPeriodProvider =
    StateProvider<LeaderboardPeriod>((ref) => LeaderboardPeriod.week);

final leaderboardProvider =
    FutureProvider.autoDispose<LeaderboardResult>((ref) async {
  final period = ref.watch(leaderboardPeriodProvider);
  final api = ref.watch(apiClientProvider);
  final body = await api.get(
    '/api/leaderboard',
    query: {'period': period.query, 'limit': '100'},
  );
  return LeaderboardResult.fromJson(body);
});

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _retryPendingSync());
  }

  // Si quedó una subida pendiente por falta de red, se reintenta al abrir la pantalla.
  Future<void> _retryPendingSync() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null || !session.pendingSync) return;
    final progress = ref.read(progressProvider).valueOrNull;
    if (progress == null) return;
    await ref.read(sessionProvider.notifier).syncProgress(progress);
    if (mounted) ref.invalidate(leaderboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(leaderboardPeriodProvider);
    final board = ref.watch(leaderboardProvider);
    final session = ref.watch(sessionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _retryPendingSync();
            ref.invalidate(leaderboardProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ranking',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Compite con los mejores de Ingresa Ya',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          _DuelButton(onPressed: () => context.push('/duel')),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _PeriodSelector(period: period),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _ConnectionHint(session: session)),
              board.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: _ErrorBox(
                    message: err is ApiException && err.isNetwork
                        ? 'Sin conexión con el servidor.\nConéctate a internet para ver el ranking global.'
                        : 'No se pudo cargar el ranking.',
                    onRetry: () => ref.invalidate(leaderboardProvider),
                  ),
                ),
                data: (result) {
                  if (result.items.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: _EmptyBox(),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    sliver: SliverList.list(
                      children: [
                        for (final entry in result.items)
                          _LeaderRow(
                            entry: entry,
                            isMe: entry.playerId == session?.player?.id,
                          ).animate().fadeIn(
                                duration: 280.ms,
                                delay: Duration(milliseconds: 40 * entry.rank.clamp(0, 20)),
                              ),
                        if (result.me != null &&
                            !result.items.any((e) => e.playerId == result.me!.playerId))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _LeaderRow(entry: result.me!, isMe: true),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuelButton extends StatelessWidget {
  const _DuelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.emoji_events_rounded, size: 18),
      label: const Text('Duelo'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.period});

  final LeaderboardPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final p in LeaderboardPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    ref.read(leaderboardPeriodProvider.notifier).state = p,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: period == p ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: period == p ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectionHint extends StatelessWidget {
  const _ConnectionHint({required this.session});

  final dynamic session;

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SizedBox.shrink();
    final pending = session.pendingSync as bool;
    final status = session.syncStatus as SyncStatus;
    if (!pending && status != SyncStatus.offline) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tu progreso se subirá cuando vuelva la conexión.',
                style: TextStyle(fontSize: 12.5, color: AppColors.ink.withValues(alpha: .8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  Color get _medalColor => switch (entry.rank) {
        1 => const Color(0xFFFFC53D),
        2 => const Color(0xFFB9C1CC),
        3 => const Color(0xFFD9873D),
        _ => AppColors.primarySoft,
      };

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isMe ? Border.all(color: AppColors.primary, width: 1.6) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: isMe ? .06 : .04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _medalColor,
              borderRadius: BorderRadius.circular(13),
            ),
            child: isTop3
                ? Text('🏆', style: const TextStyle(fontSize: 17))
                : Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isMe ? AppColors.primary : AppColors.inkSoft,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _avatarFor(entry.avatarSeed),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${entry.displayName} (tú)' : entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.streak > 0 ? '🔥 ${entry.streak} días de racha' : 'Sin racha activa',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: entry.streak > 0 ? AppColors.flame : AppColors.inkFaint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'XP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 54)),
          const SizedBox(height: 14),
          Text(
            'Aún no hay puntajes',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink.withValues(alpha: .8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Termina una sesión y aparecerás aquí.',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: AppColors.inkFaint),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _avatars = ['🐣', '🦉', '🧠', '📚', '🦋', '🦜', '🌺', '⭐'];

String _avatarFor(int seed) => _avatars[seed % _avatars.length];
