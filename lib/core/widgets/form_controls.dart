import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class SelectPills<T> extends StatelessWidget {
  const SelectPills({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.labelOf,
    required this.emojiOf,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final String Function(T) emojiOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (option, fallback) in options)
          Builder(
            builder: (context) {
              final selected = option == value;
              final own = labelOf(option);
              final label = own.isEmpty ? fallback : own;
              final emoji = emojiOf(option);
              return GestureDetector(
                onTap: () => onChanged(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? AppColors.primary : AppColors.divider,
                      width: 1.6,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: .3),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    [if (emoji.isNotEmpty) emoji, label].join(' '),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: selected ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
      ),
    );
  }
}
