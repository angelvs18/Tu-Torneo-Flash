import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/app/router.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('starts on the spectator home, in Spanish', (tester) async {
    await pumpApp(tester);

    expect(find.text('Encuentra tu torneo'), findsOneWidget);
    expect(find.text('Soy organizador'), findsOneWidget);
  });

  testWidgets('unsupported device locale falls back to Spanish', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('fr', 'FR'));

    expect(find.text('Encuentra tu torneo'), findsOneWidget);
  });

  testWidgets('English device locale uses English texts', (tester) async {
    await pumpApp(tester, locale: const Locale('en', 'US'));

    expect(find.text('Find your tournament'), findsOneWidget);
  });

  testWidgets('deep link /t/:code opens the tournament route', (tester) async {
    final container = await pumpApp(tester);

    routerOf(container).go(AppRoutes.tournament('k7q2mx', competitionId: 'x'));
    await tester.pumpAndSettle();

    expect(find.text('Torneo K7Q2MX'), findsOneWidget);
  });

  testWidgets('submitting a code in the search box navigates to it', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Torneo ABC123'), findsOneWidget);
  });

  testWidgets('organizer button asks a signed-out user to log in', (
    tester,
  ) async {
    final container = await pumpApp(tester);

    await tester.tap(find.text('Soy organizador'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(
      routerOf(container).routerDelegate.currentConfiguration.uri.toString(),
      '/login?from=%2Fmy-tournaments',
    );
  });

  testWidgets('unknown routes show the not-found screen', (tester) async {
    final container = await pumpApp(tester);

    routerOf(container).go('/nope');
    await tester.pumpAndSettle();

    expect(find.text('Página no encontrada'), findsOneWidget);
  });

  test('tournament() builds the public deep link path', () {
    expect(AppRoutes.tournament('K7Q2MX'), '/t/K7Q2MX');
    expect(
      AppRoutes.tournament('K7Q2MX', competitionId: 'abc'),
      '/t/K7Q2MX?c=abc',
    );
  });
}
