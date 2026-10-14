import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key, this.initial});

  final Object? initial;

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  QuestionCategory? _category;
  QuestionDifficulty? _difficulty;
  QuestionSource? _source;
  int _count = 10;
  QuizMode _mode = QuizMode.normal;
  int _minutes = 10;
  late Future<int> _available;

  static const _counts = [5, 10, 15, 20];
  static const _minutesOptions = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial is QuestionCategory) _category = initial;
    if (initial is QuizMode) _mode = initial;
    _available = _loadAvailable();
  }

  Future<int> _loadAvailable() async {
    final repo = ref.read(questionRepositoryProvider);
    await repo.loadAll();
    return repo.countMatching(
      category: _category,
      difficulty: _difficulty,
      source: _source,
    );
  }

  void _refreshCount() {
    setState(() => _available = _loadAvailable());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 130),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        if (GoRouter.of(context).canPop())
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CircleButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => context.pop(),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Practicar',
                                  style: theme.textTheme.headlineSmall),
                              Text(
                                'Arma tu sesión a tu medida',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('Categoría'),
                    _Pills<QuestionCategory?>(
                      value: _category,
                      options: [
                        const (null, 'Todas'),
                        ...QuestionCategory.values.map(
                          (c) => (c as QuestionCategory?, c.label),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _category = v);
                        _refreshCount();
                      },
                      labelOf: (v) => v?.label ?? '',
                      emojiOf: (v) => v?.emoji ?? '',
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Dificultad'),
                    _Pills<QuestionDifficulty?>(
                      value: _difficulty,
                      options: [
                        const (null, 'Todas'),
                        ...QuestionDifficulty.values.map(
                          (d) => (d as QuestionDifficulty?, d.label),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _difficulty = v);
                        _refreshCount();
                      },
                      labelOf: (v) => v?.label ?? '',
                      emojiOf: (v) => switch (v) {
                        QuestionDifficulty.basico => '🌱',
                        QuestionDifficulty.intermedio => '🔥',
                        QuestionDifficulty.dificil => '💎',
                        null => '',
                      },
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Universidad de referencia'),
                    _Pills<QuestionSource?>(
                      value: _source,
                      options: [
                        const (null, 'Todas'),
                        ...QuestionSource.values.map(
                          (s) => (s as QuestionSource?, s.label),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _source = v);
                        _refreshCount();
                      },
                      labelOf: (v) => v?.label ?? '',
                      emojiOf: (v) => switch (v) {
                        QuestionSource.unmsm => '🦙',
                        QuestionSource.uni => '⚙️',
                        QuestionSource.utp => '🛠️',
                        QuestionSource.pucp => '✝️',
                        QuestionSource.original => '🐦',
                        null => '',
                      },
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Número de preguntas'),
                    _Pills<int>(
                      value: _count,
                      options: [
                        for (final c in _counts) (c, '$c'),
                      ],
                      onChanged: (v) => setState(() => _count = v),
                      labelOf: (v) => '$v',
                      emojiOf: (_) => '',
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel('Modo'),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeTile(
                            mode: QuizMode.normal,
                            selected: _mode == QuizMode.normal,
                            color: AppColors.primary,
                            onTap: () =>
                                setState(() => _mode = QuizMode.normal),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ModeTile(
                            mode: QuizMode.timed,
                            selected: _mode == QuizMode.timed,
                            color: AppColors.accent,
                            onTap: () =>
                                setState(() => _mode = QuizMode.timed),
                          ),
                        ),
                      ],
                    ),
                    if (_mode == QuizMode.timed) ...[
                      const SizedBox(height: 18),
                      _SectionLabel('Tiempo total'),
                      _Pills<int>(
                        value: _minutes,
                        options: [
                          for (final m in _minutesOptions) (m, '$m min'),
                        ],
                        onChanged: (v) => setState(() => _minutes = v),
                        labelOf: (v) => '$v min',
                        emojiOf: (_) => '⏱️',
                      ),
                    ],
                    const SizedBox(height: 20),
                    _AvailabilityCard(
                      future: _available,
                      needed: _count,
                      mode: _mode,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FutureBuilder<int>(
          future: _available,
          builder: (context, snapshot) {
            final available = snapshot.data ?? 0;
            final ready = snapshot.connectionState == ConnectionState.done &&
                available >= _count;
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ready ? _start : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(ready ? 'Comenzar sesión' : 'Cargando banco…'),
                style: FilledButton.styleFrom(
                  backgroundColor: _mode == QuizMode.timed
                      ? AppColors.accent
                      : AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.inkFaint.withValues(alpha: .3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _start() {
    final config = QuizConfig(
      category: _category,
      difficulty: _difficulty,
      source: _source,
      count: _count,
      mode: _mode,
      timeLimitSeconds: _mode == QuizMode.timed ? _minutes * 60 : null,
      title: [
        if (_category != null) _category!.label else 'Todas las categorías',
        if (_source != null) _source!.label,
      ].join(' · '),
    );
    context.go('/quiz', extra: config);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _Pills<T> extends StatelessWidget {
  const _Pills({
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

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final QuizMode mode;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = mode == QuizMode.normal
        ? Icons.lightbulb_rounded
        : Icons.timer_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: 1.8,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: .35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : color,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              mode == QuizMode.normal ? 'Normal' : 'Cronometrado',
              style: theme.textTheme.titleMedium?.copyWith(
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              mode == QuizMode.normal
                  ? 'Con feedback de cada opción'
                  : 'Sin pistas, explicaciones al final',
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected ? Colors.white70 : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.future,
    required this.needed,
    required this.mode,
  });

  final Future<int> future;
  final int needed;
  final QuizMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: FutureBuilder<int>(
        future: future,
        builder: (context, snapshot) {
          final available = snapshot.data;
          final ok = available != null && available >= needed;
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (ok ? AppColors.success : AppColors.accent)
                      .withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ok ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: ok ? AppColors.success : AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available == null
                          ? 'Contando preguntas…'
                          : ok
                              ? '$available preguntas disponibles'
                              : 'Solo $available coinciden con estos filtros',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode == QuizMode.normal
                          ? 'Recibirás explicación inmediata de cada opción.'
                          : 'Sin explicaciones hasta terminar el examen.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

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
