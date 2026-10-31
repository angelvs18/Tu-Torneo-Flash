import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/auth_redirect.dart';
import '../features/auth/complete_profile_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_callback_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/session.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/my_tournaments/my_tournaments_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/public_search/home_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/placeholder_screen.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const completeProfile = '/complete-profile';
  static const myTournaments = '/my-tournaments';
  static const profile = '/profile';

  /// Path of the Supabase Auth deep link (`authRedirectUrl`).
  static const loginCallback = '/login-callback';

  /// Only for signed-out users; signed-in users bounce to `from`.
  static const authPages = {login, signUp, forgotPassword};

  /// Require a session (and a display name, except [completeProfile]).
  static const organizerPages = {myTournaments, profile, completeProfile};

  /// Public deep link: `https://tutorneoflash.app/t/{code}?c={competitionId}`.
  static String tournament(String code, {String? competitionId}) => Uri(
    path: '/t/$code',
    queryParameters: competitionId == null ? null : {'c': competitionId},
  ).toString();

  static String withFrom(String path, String? from) => Uri(
    path: path,
    queryParameters: from == null ? null : {'from': from},
  ).toString();
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  String? from(GoRouterState s) => s.uri.queryParameters['from'];

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(state.uri, ref.read(sessionProvider)),
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(from: from(state)),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => SignUpScreen(from: from(state)),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginCallback,
        builder: (context, state) => const LoginCallbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.myTournaments,
        builder: (context, state) => const MyTournamentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
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
