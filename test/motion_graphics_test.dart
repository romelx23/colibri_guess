import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ingresa_ya/core/router/app_transitions.dart';
import 'package:ingresa_ya/core/widgets/colibri_mascot.dart';

class _BirdScreen extends StatelessWidget {
  const _BirdScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, key: Key('screen-$label')),
            Hero(
              tag: 'colibri-mascot',
              flightShuttleBuilder: (_, _, _, _, _) =>
                  const SizedBox(key: Key('shuttle'), width: 40, height: 40),
              child: const SizedBox(key: Key('bird'), width: 40, height: 40),
            ),
          ],
        ),
      ),
    );
  }
}

GoRouter _router() => GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          pageBuilder: (context, state) => fadeSlideRoute(
            key: state.pageKey,
            child: const _BirdScreen(label: 'A'),
          ),
        ),
        GoRoute(
          path: '/b',
          pageBuilder: (context, state) => fadeSlideRoute(
            key: state.pageKey,
            child: const _BirdScreen(label: 'B'),
          ),
        ),
      ],
    );

void main() {
  testWidgets('las rutas raíz se transicionan con fade-slide',
      (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.byKey(const Key('screen-A')), findsOneWidget);

    router.go('/b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Durante la transición conviven la pantalla saliente y la entrante.
    expect(find.byKey(const Key('screen-A')), findsOneWidget);
    expect(find.byKey(const Key('screen-B')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-A')), findsNothing);
    expect(find.byKey(const Key('screen-B')), findsOneWidget);

    router.dispose();
  });

  testWidgets('el colibrí vuela con Hero entre pantallas', (tester) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go('/b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(find.byKey(const Key('shuttle')), findsWidgets,
        reason: 'Debe iniciar el vuelo del Hero al cambiar de pantalla');

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bird')), findsOneWidget);

    router.dispose();
  });

  testWidgets('la mascota soporta cambios de mood en caliente', (tester) async {
    Widget build(ColibriMood mood) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: ColibriMascot(key: const Key('mascot'), size: 100, mood: mood),
            ),
          ),
        );

    await tester.pumpWidget(build(ColibriMood.idle));
    expect(find.byKey(const Key('mascot')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(build(ColibriMood.celebrating));
    await tester.pump(const Duration(milliseconds: 210));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(build(ColibriMood.sad));
    await tester.pump(const Duration(milliseconds: 420));
    expect(tester.takeException(), isNull);

    expect(find.byType(CustomPaint), findsWidgets);
  });
}
