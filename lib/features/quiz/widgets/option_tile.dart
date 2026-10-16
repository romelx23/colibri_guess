import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/question_image.dart';

enum OptionState { idle, selected, correct, wrong, revealCorrect }

class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
    this.image,
  });

  final String letter;
  final String text;
  final OptionState state;
  final VoidCallback onTap;

  /// Ruta del asset cuando la opción es una imagen (p. ej. figuras A-E).
  final String? image;

  Color get _border => switch (state) {
        OptionState.correct => AppColors.success,
        OptionState.wrong => AppColors.error,
        OptionState.revealCorrect => AppColors.success,
        OptionState.selected => AppColors.primary,
        OptionState.idle => AppColors.divider,
      };

  Color get _fill => switch (state) {
        OptionState.correct => AppColors.successSoft,
        OptionState.wrong => AppColors.errorSoft,
        OptionState.revealCorrect => AppColors.successSoft,
        _ => Colors.white,
      };

  Color get _badge => switch (state) {
        OptionState.correct => AppColors.success,
        OptionState.wrong => AppColors.error,
        OptionState.revealCorrect => AppColors.success,
        OptionState.selected => AppColors.primary,
        OptionState.idle => AppColors.primarySoft,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = state != OptionState.idle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: locked ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _fill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _badge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: switch (state) {
                  OptionState.correct ||
                  OptionState.revealCorrect =>
                    const Icon(Icons.check_rounded,
                        color: Colors.white, size: 19),
                  OptionState.wrong => const Icon(Icons.close_rounded,
                      color: Colors.white, size: 19),
                  _ => Text(
                      letter,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: state == OptionState.selected
                            ? Colors.white
                            : AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: state == OptionState.wrong
                            ? AppColors.inkSoft
                            : AppColors.ink,
                      ),
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 8),
                      QuestionImage(asset: image!, height: 110),
                    ],
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
