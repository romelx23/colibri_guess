import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

class ResultsArgs {
  const ResultsArgs({
    required this.result,
    required this.xpGained,
    this.cutoffPercent = 70,
  });

  final SessionResult result;
  final int xpGained;
  final int cutoffPercent;
}

class ResultsPage extends ConsumerStatefulWidget {
  const ResultsPage({super.key, required this.args});

  final ResultsArgs args;

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    final result = widget.args.result;
    final cutoff = widget.args.cutoffPercent;
    if ((result.accuracy * 100).round() >= cutoff) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.args.result;
    final progress = ref.watch(progressProvider).valueOrNull;
    final accuracy = (result.accuracy * 100).round();
    final isExam = result.mode == QuizMode.exam;
    final cutoff = widget.args.cutoffPercent;
    final passed = accuracy >= cutoff;
    final excellent = accuracy >= 80;
    final good = isExam ? passed : accuracy >= 60;

    final message = isExam
        ? passed
            ? '¡Aprobado! Superaste el corte de $cutoff%.'
            : 'Te faltaron ${cutoff - accuracy} '
                'punto${cutoff - accuracy == 1 ? '' : 's'} para el corte.'
        : excellent
            ? '¡Vuelo espectacular! Dominas este tema.'
            : good
                ? '¡Buen trabajo! Ya casi lo tienes.'
                : 'Cuesta al principio, pero cada vuelo te acerca.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                AppColors.primary,
                AppColors.accent,
                AppColors.success,
                Color(0xFFFFC94D),
                Color(0xFFF0699A),
              ],
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Resultados',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isExam
                            ? 'Examen de admisión · Corte $cutoff%'
                            : result.mode == QuizMode.timed
                                ? 'Examen cronometrado'
                                : 'Sesión de práctica',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      _ScoreCard(
                        correct: result.correct,
                        total: result.total,
                        accuracy: accuracy,
                        xpGained: widget.args.xpGained,
                        message: message,
                        good: good,
                      ),
                      if (isExam) ...[
                        const SizedBox(height: 14),
                        _CutoffBanner(
                          passed: passed,
                          cutoff: cutoff,
                          accuracy: accuracy,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _ResultStat(
                            icon: Icons.close_rounded,
                            color: AppColors.error,
                            value: '${result.wrong}',
                            label: 'Erradas',
                          ),
                          const SizedBox(width: 10),
                          _ResultStat(
                            icon: Icons.help_outline_rounded,
                            color: AppColors.inkFaint,
                            value: '${result.unanswered}',
                            label: 'En blanco',
                          ),
                          const SizedBox(width: 10),
                          _ResultStat(
                            icon: Icons.timer_outlined,
                            color: AppColors.accent,
                            value: _format(result.elapsed),
                            label: 'Tiempo',
                          ),
                          const SizedBox(width: 10),
                          _ResultStat(
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.flame,
                            value: '${progress?.streak ?? 0}',
                            label: 'Racha',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (isExam) ...[
                        _CategoryBreakdown(result: result),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.go('/review'),
                              icon: const Icon(Icons.bolt_rounded),
                              label: const Text('Repasar errores'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  context.go(isExam ? '/exam' : '/practice'),
                              icon: const Icon(Icons.replay_rounded),
                              label: Text(isExam ? 'Otro examen' : 'Otra sesión'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Volver al inicio'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSoft,
                            side: const BorderSide(color: AppColors.divider),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Revisión pregunta por pregunta',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < result.questions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReviewTile(
                            index: i,
                            question: result.questions[i],
                            selected: result.answers[i],
                          ),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: 40 * i),
                              duration: 300.ms,
                            ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.xpGained,
    required this.message,
    required this.good,
  });

  final int correct;
  final int total;
  final int accuracy;
  final int xpGained;
  final String message;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: good ? AppGradients.primary : AppGradients.sunset,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (good ? AppColors.primary : AppColors.accent)
                .withValues(alpha: .35),
            blurRadius: 26,
            offset: const Offset(0, 14),
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
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$correct/$total',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$accuracy% de aciertos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '⚡ +$xpGained XP',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ProgressRing(
            progress: total == 0 ? 0 : correct / total,
            size: 124,
            color: const Color(0xFFFFC94D),
            trackColor: Colors.white.withValues(alpha: .22),
            child: Hero(
              tag: 'colibri-mascot',
              child: ColibriMascot(
                size: 82,
                mood: correct == total && total > 0
                    ? ColibriMood.celebrating
                    : good
                        ? ColibriMood.happy
                        : ColibriMood.sad,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: .12);
  }
}

class _CutoffBanner extends StatelessWidget {
  const _CutoffBanner({
    required this.passed,
    required this.cutoff,
    required this.accuracy,
  });

  final bool passed;
  final int cutoff;
  final int accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = passed ? AppColors.success : AppColors.error;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      color: passed ? AppColors.successSoft : AppColors.errorSoft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              passed
                  ? Icons.verified_rounded
                  : Icons.priority_high_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passed ? '¡Aprobado!' : 'Aún no alcanzas el corte',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  'Obtuviste $accuracy% · Corte de aprobación $cutoff%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 360.ms).slideY(begin: .1);
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.result});

  final SessionResult result;

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
    final theme = Theme.of(context);
    final totals = <QuestionCategory, (int, int)>{};
    for (var i = 0; i < result.questions.length; i++) {
      final question = result.questions[i];
      final entry = totals[question.category] ?? (0, 0);
      totals[question.category] = (
        entry.$1 + (result.answers[i] == question.correctIndex ? 1 : 0),
        entry.$2 + 1,
      );
    }
    final categories = totals.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Por materia', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          for (final category in categories)
            Builder(builder: (context) {
              final (correct, total) = totals[category]!;
              final percent = total == 0 ? 0 : (correct * 100) ~/ total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${category.emoji} ${category.label}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '$correct/$total · $percent%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : correct / total,
                        minHeight: 8,
                        backgroundColor: AppColors.divider,
                        valueColor: AlwaysStoppedAnimation(
                          _colors[category] ?? AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        radius: 20,
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final Question question;
  final int? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final correct = selected == question.correctIndex;
    final color = selected == null
        ? AppColors.inkFaint
        : correct
            ? AppColors.success
            : AppColors.error;

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: color,
          collapsedIconColor: AppColors.inkFaint,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(11),
            ),
            child: selected == null
                ? Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : Icon(
                    correct ? Icons.check_rounded : Icons.close_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
          ),
          title: Text(
            question.questionText,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                question.category.label,
                question.topic,
                question.source.label,
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style:
                      theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                if (question.hasSupport) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      question.supportText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Respuesta correcta',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        question.correctAnswer,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected != null && !correct) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu respuesta',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          question.options[selected!],
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  question.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  'Análisis de opciones',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == question.correctIndex
                                ? AppColors.success
                                : i == selected
                                    ? AppColors.error
                                    : AppColors.inkFaint,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${question.options[i]} — ${question.optionAnalysis[i]}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (question.reference != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Fuente: ${question.reference}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
