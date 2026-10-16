import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import '../../core/widgets/question_image.dart';
import '../../core/widgets/surface_card.dart';
import '../../logic/xp.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';
import '../results/results_page.dart';

class ExamPage extends ConsumerStatefulWidget {
  const ExamPage({super.key, this.config});

  final QuizConfig? config;

  @override
  ConsumerState<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends ConsumerState<ExamPage> {
  late QuizConfig _config;
  List<Question> _questions = const [];
  final _answers = <int?>[];
  final _times = <Duration>[];

  int _index = 0;
  DateTime _sessionStarted = DateTime.now();
  DateTime _questionStarted = DateTime.now();
  Timer? _timer;
  int _secondsLeft = 0;

  bool _loading = true;
  String? _error;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _config = widget.config ??
        const QuizConfig(count: 20, mode: QuizMode.exam);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Question get _question => _questions[_index];

  bool get _isLast => _index >= _questions.length - 1;

  int get _answeredCount => _answers.where((a) => a != null).length;

  Future<void> _load() async {
    try {
      final repo = ref.read(questionRepositoryProvider);
      final questions = await repo.pick(_config);
      if (questions.isEmpty) {
        throw StateError('No hay preguntas para este examen.');
      }

      _sessionStarted = DateTime.now();
      _questionStarted = DateTime.now();
      _answers.addAll(List.filled(questions.length, null));
      _times.addAll(List.filled(questions.length, Duration.zero));

      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });

      final limit = _config.timeLimitSeconds;
      if (limit != null) {
        _secondsLeft = limit;
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
        _finish();
      }
    });
  }

  void _spendTime() {
    _times[_index] += DateTime.now().difference(_questionStarted);
  }

  void _goTo(int index) {
    if (_finishing || index == _index || index < 0) return;
    _spendTime();
    HapticFeedback.selectionClick();
    setState(() {
      _index = index;
      _questionStarted = DateTime.now();
    });
  }

  void _mark(int optionIndex) {
    if (_finishing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_index] = _answers[_index] == optionIndex ? null : optionIndex;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();
    _spendTime();

    var xpGained = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _answers[i];
      if (answer == null) continue;
      xpGained += XpCalculator.forAnswer(
        correct: answer == _questions[i].correctIndex,
        question: _questions[i],
        mode: _config.mode,
        timeSpent: _times[i],
      );
    }

    final now = DateTime.now();
    final result = SessionResult(
      questions: _questions,
      answers: List.of(_answers),
      answerTimes: List.of(_times),
      startedAt: _sessionStarted,
      finishedAt: now,
      mode: _config.mode,
    );

    if (result.correct > 0 || result.wrong > 0 || xpGained > 0) {
      final progress =
          await ref.read(progressProvider.notifier).applySession(
                result: result,
                xpGained: xpGained,
                now: now,
              );
      unawaited(ref.read(sessionProvider.notifier).syncProgress(progress));
    }

    // El servidor calcula el puntaje del examen (métrica del ranking).
    unawaited(
      ref.read(sessionProvider.notifier).submitExam(
            answers: [
              for (var i = 0; i < _questions.length; i++)
                {
                  'questionId': _questions[i].id,
                  'answerIndex': _answers[i] ?? -1,
                  'elapsedMs': _times[i].inMilliseconds,
                },
            ],
            cutoff: _config.cutoffPercent,
          ),
    );

    if (!mounted) return;
    context.go(
      '/results',
      extra: ResultsArgs(
        result: result,
        xpGained: xpGained,
        cutoffPercent: _config.cutoffPercent,
      ),
    );
  }

  void _requestSubmit() {
    final blank = _answers.where((a) => a == null).length;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('¿Entregar el examen?'),
        content: Text(
          blank == 0
              ? 'Contestaste los ${_questions.length} reactivos. '
                  'Verás tu resultado y el corte de aprobación.'
              : 'Contestaste $_answeredCount de ${_questions.length} '
                  'reactivos. Quedan $blank en blanco y no se califican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Seguir revisando'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _finish();
            },
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
  }

  void _requestExit() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('¿Salir del examen?'),
        content: const Text('Tu avance de este examen no se guardará.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/');
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  void _openAnswerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hoja de respuestas',
                style: Theme.of(sheetContext).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$_answeredCount contestadas · '
                '${_questions.length - _answeredCount} pendientes',
                style: Theme.of(sheetContext).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _questions.length; i++)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _goTo(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _answers[i] != null
                              ? AppColors.success
                              : AppColors.successSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: i == _index
                              ? Border.all(color: AppColors.ink, width: 2)
                              : null,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(sheetContext)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: _answers[i] != null
                                    ? Colors.white
                                    : AppColors.inkSoft,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _requestSubmit();
                },
                icon: const Icon(Icons.assignment_turned_in_rounded),
                label: const Text('Entregar examen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _timeLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorView(message: _error!, onBack: () => context.go('/exam'));
    }
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final lowTime = _config.timeLimitSeconds != null && _secondsLeft <= 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _requestExit,
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.inkSoft,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _config.title ?? 'Examen de admisión',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: lowTime
                            ? AppColors.errorSoft
                            : AppColors.successSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: lowTime
                              ? AppColors.error
                              : AppColors.success,
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _config.timeLimitSeconds != null
                                ? Icons.timer_rounded
                                : Icons.fact_check_rounded,
                            size: 17,
                            color:
                                lowTime ? AppColors.error : AppColors.success,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _config.timeLimitSeconds != null
                                ? _timeLabel
                                : '$_answeredCount/${_questions.length}',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: lowTime
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      end: _questions.isEmpty
                          ? 0
                          : _answeredCount / _questions.length,
                    ),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 12,
                      backgroundColor: AppColors.successSoft,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.success),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ExamQuestionCard(question: _question),
                      const SizedBox(height: 18),
                      for (var i = 0; i < _question.options.length; i++)
                        _Bubble(
                          letter: String.fromCharCode(65 + i),
                          text: _question.options[i],
                          image: _question.optionImages?[i],
                          selected: _answers[_index] == i,
                          onTap: () => _mark(i),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    _SquareButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _index > 0,
                      onTap: () => _goTo(_index - 1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openAnswerSheet,
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: Text(
                          'Hoja $_answeredCount/${_questions.length}',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isLast
                          ? _requestSubmit
                          : () => _goTo(_index + 1),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                      ),
                      child: Text(_isLast ? 'Entregar' : 'Siguiente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.letter,
    required this.text,
    required this.selected,
    required this.onTap,
    this.image,
  });

  final String letter;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  /// Ruta del asset cuando la opción es una imagen (p. ej. figuras A-E).
  final String? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.success : AppColors.divider,
              width: selected ? 2 : 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: .18),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.success : Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.success : AppColors.inkFaint,
                    width: 1.8,
                  ),
                ),
                child: Text(
                  letter,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? Colors.white : AppColors.inkSoft,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 8),
                      QuestionImage(asset: image!, height: 120),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20)
                  .animate()
                  .scale(
                    begin: const Offset(.6, .6),
                    end: const Offset(1, 1),
                    duration: 180.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: enabled ? AppColors.divider : AppColors.background,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 52,
          height: 48,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? AppColors.ink : AppColors.inkFaint,
          ),
        ),
      ),
    );
  }
}

class _ExamQuestionCard extends StatelessWidget {
  const _ExamQuestionCard({required this.question});

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      text: '${question.category.emoji} ${question.topic}',
                      color: color,
                    ),
                    _Chip(
                      text: question.difficulty.label,
                      color: AppColors.inkFaint,
                    ),
                    _Chip(
                      text: question.source.label,
                      color: AppColors.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Hero(
                tag: 'colibri-mascot',
                child: ColibriMascot(size: 54, mood: ColibriMood.thinking),
              ),
            ],
          ),
          if (question.hasSupport) ...[
            const SizedBox(height: 14),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .3,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: .18)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  question.supportText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            question.questionText,
            style: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
          ),
          if (question.image != null) ...[
            const SizedBox(height: 12),
            QuestionImage(asset: question.image!, height: 200),
          ],
          const SizedBox(height: 8),
          Text(
            'Marca una bolilla. Puedes cambiarla antes de entregar.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.inkFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ColibriMascot(size: 120, mood: ColibriMood.sad),
              const SizedBox(height: 20),
              Text(
                'Ups…',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onBack,
                  child: const Text('Volver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
