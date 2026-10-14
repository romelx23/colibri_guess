import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/surface_card.dart';
import '../../logic/xp.dart';
import '../../models/progress_state.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return '¡Buenos días!';
    if (hour < 19) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final counts = ref.watch(questionCountsProvider);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Header(greeting: _greeting),
                    const SizedBox(height: 16),
                    progress.when(
                      data: (state) => _HeroCard(
                        progress: state,
                        mood: _moodFor(state, now),
                      ),
                      loading: () => const _HeroSkeleton(),
                      error: (e, _) => _HeroCard(
                        progress: const ProgressState(),
                        mood: ColibriMood.idle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    progress.when(
                      data: (state) => Row(
                        children: [
                          _MiniStat(
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.flame,
                            value: '${state.streak}',
                            label: 'Racha',
                          ),
                          const SizedBox(width: 12),
                          _MiniStat(
                            icon: Icons.bolt_rounded,
                            color: AppColors.accent,
                            value: '${state.xp}',
                            label: 'XP total',
                          ),
                          const SizedBox(width: 12),
                          _MiniStat(
                            icon: Icons.track_changes_rounded,
                            color: AppColors.primary,
                            value:
                                '${(state.globalAccuracy * 100).round()}%',
                            label: 'Precisión',
                          ),
                        ],
                      ),
                      loading: () => const Row(
                        children: [
                          Expanded(child: _SkeletonBox(height: 84)),
                          SizedBox(width: 12),
                          Expanded(child: _SkeletonBox(height: 84)),
                          SizedBox(width: 12),
                          Expanded(child: _SkeletonBox(height: 84)),
                        ],
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Repaso de hoy',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    progress.when(
                      data: (state) => _ReviewBanner(
                        due: state.dueReviewCount(now),
                      ),
                      loading: () => const _SkeletonBox(height: 92),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Categorías',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () => context.go('/practice'),
                          child: const Text('Ver todas'),
                        ),
                      ],
                    ),
                    counts.when(
                      data: (map) => _CategoryGrid(counts: map),
                      loading: () => const Column(
                        children: [
                          _SkeletonBox(height: 96),
                          SizedBox(height: 12),
                          _SkeletonBox(height: 96),
                        ],
                      ),
                      error: (e, _) => SurfaceCard(
                        child: Text('No se pudo cargar el banco: $e'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Modos de práctica',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _ModeCard(
                      mode: QuizMode.normal,
                      color: AppColors.primary,
                      icon: Icons.lightbulb_rounded,
                      onTap: () =>
                          context.go('/practice', extra: QuizMode.normal),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      mode: QuizMode.timed,
                      color: AppColors.accent,
                      icon: Icons.timer_rounded,
                      onTap: () =>
                          context.go('/practice', extra: QuizMode.timed),
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

  ColibriMood _moodFor(ProgressState state, DateTime now) {
    if (state.dailyProgress >= 1) return ColibriMood.celebrating;
    if (state.streak == 0) return ColibriMood.thinking;
    if (state.dueReviewCount(now) > 0) return ColibriMood.idle;
    return ColibriMood.idle;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '¿Listo para volar hoy?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .2);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.progress, required this.mood});

  final ProgressState progress;
  final ColibriMood mood;

  @override
  Widget build(BuildContext context) {
    final rank = Rank.of(progress.xp);
    final next = Rank.next(progress.xp);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${rank.emoji} ${rank.name}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      '${progress.streak} día${progress.streak == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta diaria',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.dailyXp} / ${ProgressState.dailyGoal} XP',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: progress.dailyProgress,
                        minHeight: 12,
                        backgroundColor: Colors.white.withValues(alpha: .25),
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFFC94D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      next == null
                          ? '¡Rango máximo alcanzado!'
                          : 'Faltan ${next.minXp - progress.xp} XP para ${next.name}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProgressRing(
                progress: progress.dailyProgress,
                size: 116,
                color: const Color(0xFFFFC94D),
                trackColor: Colors.white.withValues(alpha: .22),
                child: ColibriMascot(size: 78, mood: mood)
                    .animate()
                    .fadeIn(duration: 450.ms, delay: 200.ms)
                    .scale(
                      begin: const Offset(.7, .7),
                      curve: Curves.easeOutBack,
                      duration: 550.ms,
                    ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 450.ms).slideY(begin: .15);
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) => const _SkeletonBox(height: 172);
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
    return Expanded(
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.due});

  final int due;

  @override
  Widget build(BuildContext context) {
    final hasDue = due > 0;
    return SurfaceCard(
      onTap: hasDue ? () => context.go('/review') : null,
      padding: const EdgeInsets.all(18),
      color: hasDue ? AppColors.accentSoft : Colors.white,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: hasDue ? AppColors.accent : AppColors.divider,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: hasDue ? Colors.white : AppColors.inkFaint,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDue
                      ? '$due pregunta${due == 1 ? '' : 's'} para repasar'
                      : '¡Todo al día!',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  hasDue
                      ? 'Refuerza lo que fallaste antes de que se olvide.'
                      : 'Vuelve mañana o practica una categoría nueva.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (hasDue)
            const Icon(Icons.chevron_right_rounded, color: AppColors.accent),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.counts});

  final Map<QuestionCategory, int> counts;

  static const _colors = {
    QuestionCategory.literatura: AppColors.literature,
    QuestionCategory.geografia: AppColors.geography,
    QuestionCategory.historia: AppColors.history,
    QuestionCategory.matematicas: AppColors.math,
    QuestionCategory.lenguaje: AppColors.language,
    QuestionCategory.ciencias: AppColors.science,
    QuestionCategory.sociales: AppColors.social,
  };

  @override
  Widget build(BuildContext context) {
    final entries = QuestionCategory.values.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final category = entries[index];
        final color = _colors[category]!;
        final count = counts[category] ?? 0;
        return SurfaceCard(
          onTap: () => context.go('/practice', extra: category),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(category.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '$count preguntas',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ).animate().fadeIn(
              delay: Duration(milliseconds: 80 * index),
              duration: 400.ms,
            );
      },
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final QuizMode mode;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.label,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  mode.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 16, color: color),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

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
