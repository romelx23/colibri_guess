import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_page.dart';
import '../../features/duel/duel_page.dart';
import '../../features/leaderboard/leaderboard_page.dart';
import '../../features/practice/practice_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/quiz/quiz_page.dart';
import '../../features/results/results_page.dart';
import '../../features/review/review_page.dart';
import '../../models/quiz_config.dart';
import '../widgets/app_shell.dart';
import 'app_transitions.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: PracticePage(initial: state.extra),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: LeaderboardPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/review',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ReviewPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/quiz',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => fadeSlideRoute(
          key: state.pageKey,
          child: QuizPage(config: state.extra as QuizConfig?),
        ),
      ),
      GoRoute(
        path: '/results',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => fadeSlideRoute(
          key: state.pageKey,
          duration: kMotionSlow,
          begin: Offset.zero,
          child: ResultsPage(args: state.extra as ResultsArgs),
        ),
      ),
      GoRoute(
        path: '/duel',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => fadeSlideRoute(
          key: state.pageKey,
          child: const DuelPage(),
        ),
      ),
    ],
  );
});
