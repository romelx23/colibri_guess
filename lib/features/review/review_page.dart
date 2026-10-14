import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

final dueQuestionsProvider = FutureProvider<List<Question>>((ref) async {
  final progress = ref.watch(progressProvider).valueOrNull;
  if (progress == null) return const [];
  final now = DateTime.now();
  final dueIds = progress.srs.entries
      .where((e) => e.value.isDue(now))
      .map((e) => e.key)
      .toSet();
  if (dueIds.isEmpty) return const [];
  final repo = ref.watch(questionRepositoryProvider);
  return repo.byIds(dueIds);
});

class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final due = ref.watch(dueQuestionsProvider);

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
                    Text('Repaso', style: theme.textTheme.headlineSmall),
                    Text(
                      'Refuerza lo que fallaste con la curva del olvido',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    due.when(
                      data: (questions) => questions.isEmpty
                          ? const _EmptyReview()
                          : _DueHeader(count: questions.length),
                      loading: () => const _Skeleton(height: 150),
                      error: (e, _) => SurfaceCard(
                        child: Text('No se pudo cargar: $e'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    due.when(
                      data: (questions) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (questions.isNotEmpty) ...[
                            Text(
                              'Preguntas pendientes',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            for (final q in questions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _DueTile(question: q),
                              ),
                          ],
                        ],
                      ),
                      loading: () => const Column(
                        children: [
                          _Skeleton(height: 70),
                          SizedBox(height: 10),
                          _Skeleton(height: 70),
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

class _DueHeader extends StatelessWidget {
  const _DueHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = count > 15 ? 15 : count;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.sunset,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: .35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count pregunta${count == 1 ? '' : 's'} vencida${count == 1 ? '' : 's'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Se repiten hasta que las domines.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => context.go(
                    '/quiz',
                    extra: QuizConfig(
                      count: batch,
                      mode: QuizMode.normal,
                      reviewOnly: true,
                      title: 'Repaso',
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: Text('Repasar ahora ($batch)'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const ColibriMascot(size: 96, mood: ColibriMood.idle),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12);
  }
}

class _EmptyReview extends StatelessWidget {
  const _EmptyReview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Column(
        children: [
          const ColibriMascot(size: 110, mood: ColibriMood.happy),
          const SizedBox(height: 10),
          Text('¡Todo al día!', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'No tienes preguntas pendientes. Practica una categoría '
            'nueva y el colibrí se encargará del repaso.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/practice'),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Practicar ahora'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _DueTile extends StatelessWidget {
  const _DueTile({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (question.category) {
      QuestionCategory.literatura => AppColors.literature,
      QuestionCategory.geografia => AppColors.geography,
      QuestionCategory.historia => AppColors.history,
      QuestionCategory.matematicas => AppColors.math,
      QuestionCategory.lenguaje => AppColors.language,
      QuestionCategory.ciencias => AppColors.science,
      QuestionCategory.sociales => AppColors.social,
    };

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(question.category.emoji,
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${question.topic} · ${question.source.label}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.schedule_rounded,
            size: 18,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height});

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
