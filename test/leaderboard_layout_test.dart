import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:colibri_quiz/core/theme/app_theme.dart';
import 'package:colibri_quiz/features/leaderboard/leaderboard_page.dart';

void main() {
  testWidgets('header del ranking en el tamano del emulador', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          leaderboardProvider.overrideWith(
            (ref) async => const LeaderboardResult(items: [], me: null),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.ltr,
            child: LeaderboardPage(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final title = tester.getSize(find.text('Ranking'));
    final subtitle = tester.getSize(find.text('Compite con los mejores de Colibrí'));
    debugPrint('logical screen: ${tester.view.physicalSize / tester.view.devicePixelRatio}');
    debugPrint('title size: $title  bottom: ${tester.getTopLeft(find.text('Ranking')).dy}');
    debugPrint('subtitle size: $subtitle');

    expect(title.width, greaterThan(150), reason: 'el titulo colapsa');
  });
}
