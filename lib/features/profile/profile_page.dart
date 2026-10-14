import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/surface_card.dart';
import '../../logic/xp.dart';
import '../../models/progress_state.dart';
import '../../models/question.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const _categoryColors = {
    QuestionCategory.literatura: AppColors.literature,
    QuestionCategory.geografia: AppColors.geography,
    QuestionCategory.historia: AppColors.history,
    QuestionCategory.matematicas: AppColors.math,
    QuestionCategory.lenguaje: AppColors.language,
    QuestionCategory.ciencias: AppColors.science,
    QuestionCategory.sociales: AppColors.social,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text('Mi perfil', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    progress.when(
                      data: (state) => _RankCard(state: state),
                      loading: () =>
                          const _Box(height: 170),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),
                    progress.when(
                      data: (state) => Column(
                        children: [
                          Row(
                            children: [
                              _StatCard(
                                icon: Icons.local_fire_department_rounded,
                                color: AppColors.flame,
                                value: '${state.streak}',
                                label: 'Racha actual',
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                icon: Icons.emoji_events_rounded,
                                color: AppColors.accent,
                                value: '${state.bestStreak}',
                                label: 'Mejor racha',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _StatCard(
                                icon: Icons.bolt_rounded,
                                color: AppColors.primary,
                                value: '${state.xp}',
                                label: 'XP total',
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                icon: Icons.checklist_rounded,
                                color: AppColors.success,
                                value: '${state.sessions}',
                                label: 'Sesiones',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Precisión global',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${(state.globalAccuracy * 100).round()}%',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: state.globalAccuracy,
                                    minHeight: 12,
                                    backgroundColor: AppColors.primarySoft,
                                    valueColor:
                                        const AlwaysStoppedAnimation(
                                      AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${state.totalCorrect} correctas de '
                                  '${state.totalAnswered} respondidas',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SurfaceCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Por categoría',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 14),
                                for (final category
                                    in QuestionCategory.values)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _CategoryBar(
                                      category: category,
                                      stats: state.stats[category.name] ??
                                          const CategoryStats(),
                                      color: _categoryColors[category]!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _ResetButton(),
                        ],
                      ),
                      loading: () => const Column(
                        children: [
                          _Box(height: 120),
                          SizedBox(height: 12),
                          _Box(height: 240),
                        ],
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.state});

  final ProgressState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = Rank.of(state.xp);
    final next = Rank.next(state.xp);
    final progress = Rank.progressOf(state.xp);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .35),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: progress,
            size: 112,
            color: const Color(0xFFFFC94D),
            trackColor: Colors.white.withValues(alpha: .22),
            child: Text(
              rank.emoji,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rank.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${state.xp} XP',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: .22),
                    valueColor: const AlwaysStoppedAnimation(
                      Color(0xFFFFC94D),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? 'Rango máximo alcanzado 👑'
                      : 'Faltan ${next.minXp - state.xp} XP para ${next.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.titleLarge),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.category,
    required this.stats,
    required this.color,
  });

  final QuestionCategory category;
  final CategoryStats stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(category.label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              stats.answered == 0
                  ? 'Sin datos'
                  : '${(stats.accuracy * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: stats.accuracy,
            minHeight: 10,
            backgroundColor: color.withValues(alpha: .14),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _ResetButton extends ConsumerWidget {
  const _ResetButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            title: const Text('¿Reiniciar progreso?'),
            content: const Text(
              'Se borrarán tu XP, racha y repasos. Esta acción no se puede '
              'deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  ref.read(progressProvider.notifier).resetAll();
                },
                child: const Text('Reiniciar'),
              ),
            ],
          ),
        ),
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Reiniciar progreso'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(
            color: AppColors.error.withValues(alpha: .5),
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(24),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: .4, end: .9, duration: 700.ms);
  }
}
