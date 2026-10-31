import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tu_torneo_flash/app/app.dart';
import 'package:tu_torneo_flash/app/router.dart';
import 'package:tu_torneo_flash/data/repositories/auth_repository.dart';
import 'package:tu_torneo_flash/data/repositories/profile_repository.dart';

import 'fakes.dart';

/// Pumps the whole app with fake repositories (Supabase is never touched).
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  FakeAuthRepository? auth,
  FakeProfileRepository? profiles,
  List<Override> overrides = const [],
  Locale locale = const Locale('es', 'MX'),
  String? initialLocation,
}) async {
  tester.platformDispatcher.localesTestValue = [locale];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository()),
      profileRepositoryProvider.overrideWithValue(
        profiles ?? FakeProfileRepository(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const TorneoFlashApp(),
    ),
  );
  await tester.pumpAndSettle();
  if (initialLocation != null) await goTo(tester, container, initialLocation);
  return container;
}

GoRouter routerOf(ProviderContainer c) => c.read(routerProvider);

Future<void> goTo(
  WidgetTester tester,
  ProviderContainer c,
  String location,
) async {
  routerOf(c).go(location);
  await tester.pumpAndSettle();
}

String currentPath(ProviderContainer c) =>
    routerOf(c).routerDelegate.currentConfiguration.uri.path;
