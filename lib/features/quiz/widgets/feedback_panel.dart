import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/question_image.dart';
import '../../../models/question.dart';

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.correct,
    required this.question,
    required this.selected,
    required this.onNext,
    required this.isLast,
    this.xpGained = 0,
  });

  final bool correct;
  final Question question;
  final int? selected;
  final VoidCallback onNext;
  final bool isLast;
  final int xpGained;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = correct ? AppColors.success : AppColors.error;

    return Container(
      constraints: const BoxConstraints(maxHeight: 460),
      decoration: BoxDecoration(
        color: correct ? AppColors.successSoft : AppColors.errorSoft,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .25),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            correct
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                correct ? '¡Correcto!' : 'No es la respuesta',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: accent,
                                ),
                              ),
                              if (correct && xpGained > 0)
                                Text(
                                  '+$xpGained XP',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Respuesta correcta',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            question.correctAnswer,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            question.explanation,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '¿Por qué cada opción?',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < question.options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OptionAnalysis(
                          letter: _letter(i),
                          text: question.options[i],
                          image: question.optionImages?[i],
                          analysis: question.optionAnalysis[i],
                          isCorrect: i == question.correctIndex,
                          isChosenWrong:
                              i == selected && selected != question.correctIndex,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: Text(isLast ? 'Ver resultados' : 'Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String letter(int index) => String.fromCharCode(65 + index);

  String _letter(int index) => letter(index);
}

class _OptionAnalysis extends StatelessWidget {
  const _OptionAnalysis({
    required this.letter,
    required this.text,
    required this.analysis,
    required this.isCorrect,
    required this.isChosenWrong,
    this.image,
  });

  final String letter;
  final String text;
  final String analysis;
  final bool isCorrect;
  final bool isChosenWrong;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCorrect
        ? AppColors.success
        : isChosenWrong
            ? AppColors.error
            : AppColors.inkFaint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? AppColors.success
              : isChosenWrong
                  ? AppColors.error
                  : AppColors.divider,
          width: 1.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: isCorrect
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : isChosenWrong
                        ? const Icon(Icons.close_rounded,
                            size: 15, color: Colors.white)
                        : Text(
                            letter,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (image != null) ...[
            QuestionImage(asset: image!, height: 110),
            const SizedBox(height: 6),
          ],
          Text(
            analysis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
