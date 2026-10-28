import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/public_search/home_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/placeholder_screen.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const myTournaments = '/my-tournaments';

  /// Public deep link: `https://tutorneoflash.app/t/{code}?c={competitionId}`.
  static String tournament(String code, {String? competitionId}) => Uri(
    path: '/t/$code',
    queryParameters: competitionId == null ? null : {'c': competitionId},
  ).toString();
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // TODO(M1): auth redirect for organizer routes.
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) =>
            PlaceholderScreen(title: AppLocalizations.of(context).loginTitle),
      ),
      GoRoute(
        path: AppRoutes.myTournaments,
        builder: (context, state) => PlaceholderScreen(
          title: AppLocalizations.of(context).myTournamentsTitle,
        ),
      ),
      GoRoute(
        path: '/t/:code',
        builder: (context, state) => PlaceholderScreen(
          title: AppLocalizations.of(context)
              .tournamentCodeTitle(state.pathParameters['code']!.toUpperCase()),
        ),
      ),
    ],
    errorBuilder: (context, state) => const _NotFoundScreen(),
  );
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: Center(
        child: TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text(l10n.goHome),
        ),
      ),
    );
  }
}
