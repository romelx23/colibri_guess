import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/session_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/colibri_mascot.dart';
import '../../data/session_store.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _SlideSpec(
      mood: ColibriMood.celebrating,
      icon: null,
      title: '¡Bienvenido a Ingresa Ya!',
      body:
          'Tu colibrí te acompaña a preparar el examen de admisión con preguntas '
          'de cultura general: literatura, historia, matemáticas y más.',
      bullets: [
        'Preguntas de las cartillas de San Marcos, UNI, UTP y Católica',
        'Explicación de cada opción cuando practicas',
        'Reto a duelo contra otros jugadores',
      ],
    ),
    _SlideSpec(
      mood: ColibriMood.happy,
      icon: Icons.bolt_rounded,
      title: 'Gana XP con cada acierto',
      body: 'Cuanto más difícil la pregunta, más XP obtienes.',
      bullets: [
        '10 XP por cada respuesta correcta',
        '+3 XP si es intermedia y +6 XP si es difícil',
        'Equivocarte no resta XP',
      ],
    ),
    _SlideSpec(
      mood: ColibriMood.thinking,
      icon: Icons.local_fire_department_rounded,
      title: 'Tu meta diaria: 30 XP',
      body: 'Alcanza tu meta cada día para mantener tu racha.',
      bullets: [
        'La meta diaria se reinicia cada día',
        'Unos aciertos al día bastan para cumplirla',
        'Tu XP total y tu racha nunca se pierden',
      ],
    ),
    _SlideSpec(
      mood: ColibriMood.idle,
      icon: Icons.rocket_launch_rounded,
      title: '¡Listo para volar!',
      body: 'Empieza por donde quieras:',
      shortcuts: [
        (Icons.school_rounded, 'Practicar', 'A tu ritmo y con pistas'),
        (Icons.sports_mma_rounded, 'Duelos', '1 contra 1 en tiempo real'),
        (Icons.emoji_events_rounded, 'Ranking', 'Compite con los demás'),
        (Icons.replay_rounded, 'Repaso', 'Refuerza lo que fallaste'),
      ],
    ),
  ];

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(preferencesProvider).setBool(SessionStore.kOnboardingPref, true);
    // Siguiente paso: elegir nickname e icono para el ranking.
    context.go('/identity');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Saltar'),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) => _Slide(
                    spec: _slides[i],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: .25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLast
                        ? _finish
                        : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            ),
                    child: Text(_isLast ? 'Empezar' : 'Siguiente'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideSpec {
  const _SlideSpec({
    required this.mood,
    required this.icon,
    required this.title,
    required this.body,
    this.bullets = const [],
    this.shortcuts = const [],
  });

  final ColibriMood mood;
  final IconData? icon;
  final String title;
  final String body;
  final List<String> bullets;
  final List<(IconData, String, String)> shortcuts;
}

class _Slide extends StatelessWidget {
  const _Slide({required this.spec});

  final _SlideSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: ColibriMascot(size: 148, mood: spec.mood),
          ),
          const SizedBox(height: 18),
          if (spec.icon != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(spec.icon, size: 30, color: AppColors.primary),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            spec.title,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            spec.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (spec.bullets.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: .08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (final text in spec.bullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 20,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (spec.shortcuts.isNotEmpty) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                for (final (icon, title, subtitle) in spec.shortcuts)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppColors.primary, size: 22),
                        const Spacer(),
                        Text(
                          title,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ).animate(key: ValueKey(spec.title)).fadeIn(duration: 340.ms).slideY(
            begin: .1,
            duration: 340.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}
