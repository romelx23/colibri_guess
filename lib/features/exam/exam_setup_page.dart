import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/form_controls.dart';
import '../../core/widgets/surface_card.dart';
import '../../models/question.dart';
import '../../models/quiz_config.dart';

class ExamSetupPage extends ConsumerStatefulWidget {
  const ExamSetupPage({super.key});

  @override
  ConsumerState<ExamSetupPage> createState() => _ExamSetupPageState();
}

class _ExamSetupPageState extends ConsumerState<ExamSetupPage> {
  QuestionCategory? _category;
  QuestionSource? _source;
  int _count = 10;
  int _minutes = 20;
  int _cutoff = 70;
  late Future<int> _available;

  static const _counts = [10, 20, 30];
  static const _minutesOptions = [10, 20, 30, 45];
  static const _cutoffOptions = [60, 70, 80];

  static const _tips = [
    (
      Icons.hourglass_bottom_rounded,
      'Apunta a unos 45 segundos por reactivo y reserva los últimos 5 minutos '
          'para revisar tu hoja de respuestas.',
    ),
    (
      Icons.menu_book_rounded,
      'Lee la pregunta completa antes de mirar las opciones.',
    ),
    (
      Icons.filter_alt_off_rounded,
      'Descarta primero las opciones claramente incorrectas.',
    ),
    (
      Icons.psychology_rounded,
      'Si dudas entre dos opciones, quédate con tu primera impresión.',
    ),
    (
      Icons.radio_button_checked_rounded,
      'No dejes bolillas en blanco: no hay penalización por equivocarte.',
    ),
    (
      Icons.fact_check_rounded,
      'Antes de entregar, revisa los reactivos pendientes en la hoja.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _available = _loadAvailable();
  }

  Future<int> _loadAvailable() async {
    final repo = ref.read(questionRepositoryProvider);
    await repo.loadAll();
    return repo.countMatching(category: _category, source: _source);
  }

  void _refreshCount() {
    setState(() => _available = _loadAvailable());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                            child: CircleIconButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () => context.pop(),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Examen de admisión',
                                  style: theme.textTheme.headlineSmall),
                              Text(
                                'Hoja de respuestas como el día del examen',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SectionLabel('Materias'),
                    SelectPills<QuestionCategory?>(
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
                    SectionLabel('Universidad de referencia'),
                    SelectPills<QuestionSource?>(
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
                    SectionLabel('Número de reactivos'),
                    SelectPills<int>(
                      value: _count,
                      options: [for (final c in _counts) (c, '$c')],
                      onChanged: (v) => setState(() => _count = v),
                      labelOf: (v) => '$v',
                      emojiOf: (_) => '',
                    ),
                    const SizedBox(height: 18),
                    SectionLabel('Tiempo límite'),
                    SelectPills<int>(
                      value: _minutes,
                      options: [for (final m in _minutesOptions) (m, '$m min')],
                      onChanged: (v) => setState(() => _minutes = v),
                      labelOf: (v) => '$v min',
                      emojiOf: (_) => '⏱️',
                    ),
                    const SizedBox(height: 18),
                    SectionLabel('Puntaje de aprobación'),
                    SelectPills<int>(
                      value: _cutoff,
                      options: [
                        for (final c in _cutoffOptions) (c, '$c%'),
                      ],
                      onChanged: (v) => setState(() => _cutoff = v),
                      labelOf: (v) => '$v%',
                      emojiOf: (_) => '🎯',
                    ),
                    const SizedBox(height: 18),
                    _TipsCard(tips: _tips),
                    const SizedBox(height: 18),
                    SurfaceCard(
                      padding: const EdgeInsets.all(18),
                      child: FutureBuilder<int>(
                        future: _available,
                        builder: (context, snapshot) {
                          final available = snapshot.data;
                          final ok = available != null && available >= _count;
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (ok
                                          ? AppColors.success
                                          : AppColors.accent)
                                      .withValues(alpha: .15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  ok
                                      ? Icons.check_circle_rounded
                                      : Icons.info_rounded,
                                  color: ok
                                      ? AppColors.success
                                      : AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      available == null
                                          ? 'Contando preguntas…'
                                          : ok
                                              ? '$available preguntas disponibles'
                                              : 'Solo $available coinciden '
                                                  'con estos filtros',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Sin pistas: calificamos al entregar '
                                          'y te mostramos el corte.',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
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
                icon: const Icon(Icons.assignment_rounded),
                label: Text(ready ? 'Comenzar examen' : 'Cargando banco…'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
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
      source: _source,
      count: _count,
      mode: QuizMode.exam,
      timeLimitSeconds: _minutes * 60,
      cutoffPercent: _cutoff,
      title: [
        if (_category != null) _category!.label else 'Todas las materias',
        if (_source != null) _source!.label,
      ].join(' · '),
    );
    context.go('/exam/take', extra: config);
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tips});

  final List<(IconData, String)> tips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      color: AppColors.successSoft,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: AppColors.success,
          collapsedIconColor: AppColors.success,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.success),
          title: Text(
            'Consejos para el examen',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            '${tips.length} tips para sacar mejor nota',
            style: theme.textTheme.bodySmall,
          ),
          children: [
            for (final (icon, text) in tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
