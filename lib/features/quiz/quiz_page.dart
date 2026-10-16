import 'dart:async';

import 'package:confetti/confetti.dart';
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
import '../../logic/xp.dart';
import '../../models/progress_state.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';
import '../results/results_page.dart';
import 'widgets/feedback_panel.dart';
import 'widgets/option_tile.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, this.config});

  final QuizConfig? config;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  late QuizConfig _config;
  List<Question> _questions = const [];
  final _answers = <int?>[];
  final _times = <Duration>[];

  int _index = 0;
  int? _selected;
  bool _answered = false;
  int _xpGained = 0;
  int _currentXp = 0;

  DateTime _sessionStarted = DateTime.now();
  DateTime _questionStarted = DateTime.now();
  Timer? _timer;
  int _secondsLeft = 0;

  bool _loading = true;
  String? _error;
  bool _finishing = false;

  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _config = widget.config ??
        const QuizConfig(count: 10, mode: QuizMode.normal);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  bool get _timed => _config.mode == QuizMode.timed;

  Future<void> _load() async {
    try {
      final repo = ref.read(questionRepositoryProvider);
      final progress =
          ref.read(progressProvider).valueOrNull ?? const ProgressState();

      final List<Question> questions;
      if (_config.reviewOnly) {
        final now = DateTime.now();
        final dueIds = progress.srs.entries
            .where((e) => e.value.isDue(now))
            .map((e) => e.key)
            .toSet();
        questions = await repo.pickReview(
          dueIds: dueIds,
          count: _config.count,
        );
      } else {
        questions = await repo.pick(_config);
      }

      if (questions.isEmpty) {
        throw StateError('No hay preguntas pendientes de repaso 🎉');
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

      if (_timed) {
        _secondsLeft = _config.timeLimitSeconds ?? 600;
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

  Question get _question => _questions[_index];

  bool get _isLast => _index >= _questions.length - 1;

  void _onSelect(int optionIndex) {
    if (_answered || _finishing) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = optionIndex);
  }

  void _recordAnswer() {
    if (_selected == null || _answers[_index] != null) return;
    final spent = DateTime.now().difference(_questionStarted);
    final correct = _selected == _question.correctIndex;
    _answers[_index] = _selected;
    _times[_index] = spent;
    _currentXp = XpCalculator.forAnswer(
      correct: correct,
      question: _question,
      mode: _config.mode,
      timeSpent: spent,
    );
    _xpGained += _currentXp;
  }

  void _checkAnswer() {
    if (_selected == null || _answered) return;
    _recordAnswer();
    final correct = _selected == _question.correctIndex;
    if (correct) {
      _confetti.play();
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => _answered = true);
  }

  void _timedAdvance() {
    _recordAnswer();
    _advance();
  }

  void _advance() {
    if (_isLast) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _answered = false;
      _currentXp = 0;
      _questionStarted = DateTime.now();
    });
  }

  void _next() {
    if (_finishing) return;
    _advance();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _timer?.cancel();

    final now = DateTime.now();
    final result = SessionResult(
      questions: _questions,
      answers: List.of(_answers),
      answerTimes: List.of(_times),
      startedAt: _sessionStarted,
      finishedAt: now,
      mode: _config.mode,
    );

    if (result.correct > 0 || result.wrong > 0 || _xpGained > 0) {
      final progress =
          await ref.read(progressProvider.notifier).applySession(
                result: result,
                xpGained: _xpGained,
                now: now,
              );
      // Fire-and-forget: si no hay red queda encola y se reintenta después.
      unawaited(ref.read(sessionProvider.notifier).syncProgress(progress));
    }

    if (!mounted) return;
    context.go(
      '/results',
      extra: ResultsArgs(result: result, xpGained: _xpGained),
    );
  }

  void _requestExit() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text('¿Salir de la sesión?'),
        content: const Text('Tu progreso de esta sesión no se guardará.'),
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

  String get _timeLabel {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return _ErrorView(message: _error!, onBack: () => context.go('/practice'));
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final mood = !_answered
        ? ColibriMood.thinking
        : (_selected == _question.correctIndex
            ? ColibriMood.happy
            : ColibriMood.sad);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _Header(
                    index: _index,
                    total: _questions.length,
                    progress: (_index + (_answered ? 1 : 0)) /
                        _questions.length,
                    timed: _timed,
                    timeLabel: _timeLabel,
                    secondsLeft: _secondsLeft,
                    onClose: _requestExit,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            8,
                            20,
                            _answered && !_timed ? 300 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _QuestionCard(
                                question: _question,
                                mood: mood,
                              ),
                              const SizedBox(height: 18),
                              for (var i = 0;
                                  i < _question.options.length;
                                  i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildOption(i),
                                ),
                            ],
                          ),
                        ),
                        if (_answered && !_timed)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: FeedbackPanel(
                              correct: _selected == _question.correctIndex,
                              question: _question,
                              selected: _selected,
                              xpGained: _currentXp,
                              isLast: _isLast,
                              onNext: _next,
                            )
                                .animate()
                                .slideY(
                                  begin: 1,
                                  end: 0,
                                  duration: 320.ms,
                                  curve: Curves.easeOutCubic,
                                )
                                .fadeIn(duration: 240.ms),
                          ),
                      ],
                    ),
                  ),
                  if (!_answered)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _selected == null
                              ? null
                              : () {
                                  if (_timed) {
                                    _timedAdvance();
                                  } else {
                                    _checkAnswer();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: _timed
                                ? AppColors.accent
                                : AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.inkFaint.withValues(alpha: .25),
                          ),
                          child: Text(_timed
                              ? (_isLast ? 'Finalizar' : 'Siguiente')
                              : 'Comprobar'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 22,
                gravity: 0.35,
                emissionFrequency: 0.3,
                colors: const [
                  AppColors.primary,
                  AppColors.accent,
                  AppColors.success,
                  Color(0xFFFFC94D),
                  Color(0xFFF0699A),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(int i) {
    final letter = FeedbackPanel.letter(i);
    final state = _optionState(i);

    Widget tile = OptionTile(
      letter: letter,
      text: _question.options[i],
      image: _question.optionImages?[i],
      state: state,
      onTap: () => _onSelect(i),
    );

    if (_answered && i == _selected && _selected != _question.correctIndex) {
      tile = tile
          .animate()
          .shake(duration: 420.ms, offset: const Offset(0.05, 0));
    }
    if (!_answered && i == _selected) {
      tile = tile.animate().scale(
            begin: const Offset(1, 1),
            end: const Offset(1.015, 1.015),
            duration: 160.ms,
            curve: Curves.easeOut,
          );
    }
    return tile;
  }

  OptionState _optionState(int i) {
    final isCorrectIndex = i == _question.correctIndex;
    final isChosen = i == _selected;

    if (!_answered) {
      return isChosen ? OptionState.selected : OptionState.idle;
    }
    if (_timed) {
      return isChosen ? OptionState.selected : OptionState.idle;
    }
    if (isCorrectIndex) {
      return isChosen ? OptionState.correct : OptionState.revealCorrect;
    }
    if (isChosen) return OptionState.wrong;
    return OptionState.idle;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.index,
    required this.total,
    required this.progress,
    required this.timed,
    required this.timeLabel,
    required this.secondsLeft,
    required this.onClose,
  });

  final int index;
  final int total;
  final double progress;
  final bool timed;
  final String timeLabel;
  final int secondsLeft;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lowTime = timed && secondsLeft <= 60;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.inkSoft,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: AppColors.primarySoft,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (timed)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: lowTime ? AppColors.errorSoft : AppColors.accentSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: lowTime ? AppColors.error : AppColors.accent,
                  width: 1.6,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    size: 17,
                    color: lowTime ? AppColors.error : AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: lowTime ? AppColors.error : AppColors.accent,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              '${index + 1}/$total',
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.inkSoft,
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question, required this.mood});

  final Question question;
  final ColibriMood mood;

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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                    if (question.reference != null)
                      _Chip(
                        text: '📌 ${question.reference}',
                        color: AppColors.inkSoft,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Hero(
                tag: 'colibri-mascot',
                child: ColibriMascot(size: 54, mood: mood),
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
            QuestionImage(asset: question.image!, height: 180),
          ],
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
                child: FilledButton(onPressed: onBack, child: const Text('Volver')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
