import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import 'duel_state.dart';

class DuelPage extends ConsumerStatefulWidget {
  const DuelPage({super.key});

  @override
  ConsumerState<DuelPage> createState() => _DuelPageState();
}

class _DuelPageState extends ConsumerState<DuelPage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duel = ref.watch(duelProvider).valueOrNull ?? const DuelState();

    return PopScope(
      canPop: duel.phase == DuelPhase.lobby,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(duelProvider.notifier).leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: switch (duel.phase) {
            DuelPhase.lobby => _LobbyView(
                controller: _codeController,
                onCreate: () =>
                    ref.read(duelProvider.notifier).createRoom(),
                onJoin: () {
                  final code = _codeController.text.trim();
                  if (code.length == 6) {
                    ref.read(duelProvider.notifier).joinRoom(code);
                  }
                },
              ),
            DuelPhase.waiting => _WaitingView(
                duel: duel,
                onReady: () => ref.read(duelProvider.notifier).ready(),
                onCancel: () {
                  ref.read(duelProvider.notifier).leave();
                  context.pop();
                },
              ),
            DuelPhase.playing => _PlayingView(
                duel: duel,
                onAnswer: (i) => ref.read(duelProvider.notifier).answer(i),
              ),
            DuelPhase.result => _ResultView(
                duel: duel,
                onAgain: () => ref.read(duelProvider.notifier).backToLobby(),
                onExit: () {
                  ref.read(duelProvider.notifier).backToLobby();
                  context.pop();
                },
              ),
            DuelPhase.error => _ErrorView(
                message: duel.error ?? 'Algo salió mal.',
                onRetry: () {
                  ref.read(duelProvider.notifier).backToLobby();
                },
              ),
          },
        ),
      ),
    );
  }
}

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.controller,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController controller;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close_rounded),
              ),
              Text(
                'Duelo en vivo',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          const ColibriMascot(mood: ColibriMood.happy, size: 130)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: .15, end: 0),
          const SizedBox(height: 22),
          Text(
            'Reta a un amigo en tiempo real',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '10 preguntas. Gana quien más acierte.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear sala'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                  ),
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(
                      color: AppColors.inkFaint,
                      letterSpacing: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  backgroundColor: AppColors.accent,
                ),
                child: const Text('Unirse'),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.duel,
    required this.onReady,
    required this.onCancel,
  });

  final DuelState duel;
  final VoidCallback onReady;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRival = duel.opponentName.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
              Text(
                'Sala de espera',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Código de la sala',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              duel.code ?? '······',
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 14,
                color: AppColors.primary,
              ),
            ),
          ).animate().fadeIn(duration: 350.ms).scale(begin: const Offset(.94, .94)),
          const SizedBox(height: 10),
          Text(
            'Compártelo con tu rival',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: 34),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasRival ? AppColors.successSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ColibriMascot(
                  mood: hasRival ? ColibriMood.happy : ColibriMood.thinking,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasRival
                        ? '¡${duel.opponentName} se unió! Pulsa listo para empezar.'
                        : 'Esperando a que alguien se una…',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink.withValues(alpha: .8),
                    ),
                  ),
                ),
                if (hasRival)
                  const Icon(Icons.check_circle_rounded, color: AppColors.success),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: hasRival ? onReady : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            child: const Text('Listo'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _PlayingView extends StatelessWidget {
  const _PlayingView({required this.duel, required this.onAnswer});

  final DuelState duel;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = duel.questions[duel.current];
    final letras = ['A', 'B', 'C', 'D', 'E'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _DuelProgress(
            duel: duel,
          ),
          const SizedBox(height: 18),
          Text(
            '${duel.current + 1} / ${duel.questions.length}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: .05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      q.enunciado,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < q.options.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DuelOption(
                        letter: letras[i],
                        text: q.options[i],
                        enabled: !duel.meAnswered,
                        onTap: () => onAnswer(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (duel.meAnswered) ...[
            const SizedBox(height: 6),
            Text(
              duel.waitingForOpponent
                  ? 'Terminaste — esperando al rival…'
                  : 'Respuesta enviada — esperando al rival…',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ).animate().fadeIn(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DuelProgress extends StatelessWidget {
  const _DuelProgress({required this.duel});

  final DuelState duel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _bar(label: 'Tú', value: duel.myProgress, color: AppColors.primary),
        const SizedBox(height: 8),
        _bar(
          label: duel.opponentName.isEmpty ? 'Rival' : duel.opponentName,
          value: duel.opponentProgress,
          color: AppColors.accent,
        ),
      ],
    );
  }

  Widget _bar({
    required String label,
    required double value,
    required Color color,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.inkFaint,
            ),
          ),
        ),
      ],
    );
  }
}

class _DuelOption extends StatelessWidget {
  const _DuelOption({
    required this.letter,
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? AppColors.surface : AppColors.surface.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled ? AppColors.divider : AppColors.divider.withValues(alpha: .5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? AppColors.ink
                      : AppColors.ink.withValues(alpha: .55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.duel,
    required this.onAgain,
    required this.onExit,
  });

  final DuelState duel;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title;
    final String emoji;
    final Color color;

    if (duel.draw) {
      title = '¡Empate!';
      emoji = '🤝';
      color = AppColors.accent;
    } else if (duel.iWon) {
      title = '¡Ganaste!';
      emoji = '🏆';
      color = AppColors.success;
    } else {
      title = 'Perdiste';
      emoji = '💪';
      color = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            emoji,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 74),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(.6, .6), curve: Curves.elasticOut),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            duel.draw
                ? 'Nadie se llevó la victoria'
                : duel.iWon
                    ? 'Le ganaste a ${duel.opponentName}'
                    : '${duel.opponentName} fue más rápido y preciso',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _scoreColumn(
                    'Tú',
                    '${duel.correct}',
                    duel.questions.length,
                    AppColors.primary,
                  ),
                ),
                Container(width: 1, height: 56, color: AppColors.divider),
                Expanded(
                  child: _scoreColumn(
                    duel.opponentName.isEmpty ? 'Rival' : duel.opponentName,
                    '${duel.opponentCorrect}',
                    duel.questions.length,
                    AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onAgain,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            child: const Text('Volver al duelo'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onExit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Salir'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _scoreColumn(String name, String score, int total, Color color) {
    return Column(
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          '$score/$total',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const Text(
          'correctas',
          style: TextStyle(fontSize: 12, color: AppColors.inkFaint),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const ColibriMascot(mood: ColibriMood.sad, size: 110),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.5,
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
            ),
            child: const Text('Volver'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
