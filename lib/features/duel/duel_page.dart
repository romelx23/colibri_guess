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
                onStartNow: () => ref.read(duelProvider.notifier).startNow(),
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
            'Reta a tus amigos en tiempo real',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hasta 8 jugadores. 10 preguntas. Gana quien más acierte.',
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
    required this.onStartNow,
    required this.onCancel,
  });

  final DuelState duel;
  final VoidCallback onReady;
  final VoidCallback onStartNow;
  final VoidCallback onCancel;

  bool get _othersJoined => duel.players.length > 1;
  bool get _meReady => duel.me?.ready ?? false;
  bool get _allReady => _othersJoined && duel.readyCount >= duel.players.length;
  bool get _canForceStart => duel.readyCount >= 2;

  String get _statusText {
    if (!_othersJoined) return 'Esperando a que alguien se una…';
    if (_allReady) return '¡Todos listos! La partida empieza ya mismo.';
    if (duel.readyCount > 0) {
      return '${duel.readyCount} de ${duel.players.length} listos.';
    }
    return 'Pulsa listo cuando estés preparado.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${duel.players.length}/${duel.maxPlayers}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          Text(
            'Compártelo con tus amigos',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
          const SizedBox(height: 20),
          Text(
            'Jugadores en la sala',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _allReady ? AppColors.successSoft : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _allReady ? AppColors.success : AppColors.divider,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final p in duel.players) _playerChip(p),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ColibriMascot(
                mood: _allReady ? ColibriMood.happy : ColibriMood.thinking,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withValues(alpha: .8),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (duel.error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                duel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            onPressed: _othersJoined && !_meReady ? onReady : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 17),
              textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            child: Text(_meReady ? 'Listo ✓' : 'Listo'),
          ),
          if (duel.isHost) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _canForceStart ? onStartNow : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Empezar ahora'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.accentSoft,
                disabledForegroundColor: AppColors.inkFaint,
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _canForceStart
                  ? 'Los que no estén listos quedarán fuera.'
                  : 'Mínimo 2 jugadores listos para empezar.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkFaint),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _playerChip(DuelPlayer p) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.ready
                    ? AppColors.successSoft
                    : p.isMe
                        ? AppColors.primarySoft
                        : AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: p.ready
                      ? AppColors.success
                      : p.isMe
                          ? AppColors.primary
                          : AppColors.divider,
                  width: 2,
                ),
              ),
              child: Text(
                _avatarFor(p.avatarSeed),
                style: const TextStyle(fontSize: 24),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: p.ready
                  ? const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.success)
                  : const Icon(Icons.radio_button_unchecked_rounded,
                      size: 16, color: AppColors.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 68,
          child: Text(
            p.isMe ? '${p.displayName} (tú)' : p.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: p.isMe ? AppColors.primary : AppColors.ink,
            ),
          ),
        ),
      ],
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
                  ? 'Terminaste — quedan ${duel.players.length - duel.finishedCount} por acabar…'
                  : 'Respuesta enviada — esperando…',
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

class _DuelProgress extends StatefulWidget {
  const _DuelProgress({required this.duel});

  final DuelState duel;

  @override
  State<_DuelProgress> createState() => _DuelProgressState();
}

class _DuelProgressState extends State<_DuelProgress> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final duel = widget.duel;
    final players = List<DuelPlayer>.from(duel.players)
      ..sort((a, b) {
        if (a.answered != b.answered) return b.answered - a.answered;
        if (a.correct != b.correct) return b.correct - a.correct;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        child: _open
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < players.length; i++) ...[
                    _expandedRow(i, players[i]),
                    if (i < players.length - 1) const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Toca para contraer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: AppColors.inkFaint),
                  ),
                ],
              )
            : Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final p in players) _miniChip(p),
                  const Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _miniChip(DuelPlayer p) {
    final total = widget.duel.questionCount;
    final done = total > 0 && p.answered >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: p.isMe ? AppColors.primarySoft : AppColors.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: p.isMe
              ? AppColors.primary
              : done
                  ? AppColors.success
                  : AppColors.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_avatarFor(p.avatarSeed), style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '${p.correct}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: p.isMe ? AppColors.primary : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedRow(int index, DuelPlayer p) {
    final duel = widget.duel;
    final color = p.isMe ? AppColors.primary : AppColors.ink;
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            '${index + 1}',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: index == 0 ? AppColors.accent : AppColors.inkFaint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_avatarFor(p.avatarSeed), style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.isMe ? '${p.displayName} (tú)' : p.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: duel.questionCount > 0
                      ? p.answered / duel.questionCount
                      : 0,
                  minHeight: 5,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation(
                    p.isMe ? AppColors.primary : AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 22,
          child: Text(
            '${p.correct}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color),
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
    final ranked = duel.ranked;
    final total = duel.questions.length;
    final winner = ranked.isNotEmpty ? ranked.first : null;
    final isDuo = duel.players.length == 2;

    String rivalName = 'tu rival';
    for (final p in ranked) {
      if (!p.isMe) {
        rivalName = p.displayName;
        break;
      }
    }

    int myPosition = 0;
    for (var i = 0; i < ranked.length; i++) {
      if (ranked[i].isMe) myPosition = i + 1;
    }

    final String title;
    final String subtitle;
    final String emoji;
    final Color color;

    if (duel.draw) {
      title = '¡Empate!';
      subtitle = 'Nadie se llevó la victoria';
      emoji = '🤝';
      color = AppColors.accent;
    } else if (duel.iWon) {
      title = '¡Ganaste!';
      subtitle = isDuo
          ? 'Le ganaste a $rivalName'
          : 'Primero de ${duel.players.length} jugadores con ${duel.correct} de $total';
      emoji = '🏆';
      color = AppColors.success;
    } else if (myPosition > 1 && !isDuo) {
      title = 'Quedaste en $myPosition.º puesto';
      subtitle = winner == null
          ? ''
          : 'Ganó ${winner.displayName} con ${winner.correct} de $total';
      emoji = '💪';
      color = AppColors.primary;
    } else {
      title = 'Perdiste';
      subtitle = winner == null
          ? ''
          : isDuo
              ? '${winner.displayName} fue más rápido y preciso'
              : 'Ganó ${winner.displayName} con ${winner.correct} de $total';
      emoji = '💪';
      color = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          Text(
            emoji,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 66),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(begin: const Offset(.6, .6), curve: Curves.elasticOut),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < ranked.length; i++) ...[
                      _rankRow(i, ranked[i], total),
                      if (i < ranked.length - 1)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _rankRow(int index, DuelPlayer p, int total) {
    final isMe = p.isMe;
    final medal = switch (index) {
      0 => '🥇',
      1 => '🥈',
      2 => '🥉',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 17))
                : Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.inkFaint,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(_avatarFor(p.avatarSeed), style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${p.displayName} (tú)' : p.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isMe ? AppColors.primary : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${p.correct}/$total',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: index == 0 && !duel.draw
                  ? AppColors.accent
                  : isMe
                      ? AppColors.primary
                      : AppColors.inkSoft,
            ),
          ),
        ],
      ),
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

const List<String> _avatars = ['🐣', '🦉', '🧠', '📚', '🦋', '🦜', '🌺', '⭐'];

String _avatarFor(int seed) => _avatars[seed % _avatars.length];
