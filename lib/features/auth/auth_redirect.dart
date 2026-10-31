import '../../app/router.dart';
import 'session.dart';

/// Pure redirect rules for go_router (see `routerProvider`).
String? authRedirect(Uri location, SessionState s) {
  final path = location.path;
  final isAuthPage = AppRoutes.authPages.contains(path);
  final isOrganizerPage = AppRoutes.organizerPages.any(
    (p) => path == p || path.startsWith('$p/'),
  );

  if (s.recoveringPassword && s.isSignedIn) {
    return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
  }
  if (path == AppRoutes.resetPassword) {
    return s.isSignedIn ? AppRoutes.myTournaments : AppRoutes.login;
  }

  // supabase_flutter exchanges the link's code; wait here for the session.
  if (path == AppRoutes.loginCallback) {
    return s.isSignedIn ? AppRoutes.myTournaments : null;
  }

  if (!s.isSignedIn) {
    return isOrganizerPage
        ? AppRoutes.withFrom(AppRoutes.login, location.toString())
        : null;
  }

  if (s.needsProfile) {
    if (path == AppRoutes.completeProfile) return null;
    if (isOrganizerPage || isAuthPage) {
      return AppRoutes.withFrom(
        AppRoutes.completeProfile,
        isAuthPage ? safeFrom(location) : location.toString(),
      );
    }
    return null;
  }

  final profileDone = path == AppRoutes.completeProfile && !s.profileLoading;
  if (isAuthPage || profileDone) {
    return safeFrom(location) ?? AppRoutes.myTournaments;
  }
  return null;
}

/// The `from` query param, only if it is an in-app path that is not an auth page.
String? safeFrom(Uri location) {
  final from = location.queryParameters['from'];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      AppRoutes.authPages.contains(path) ||
      path == AppRoutes.completeProfile ||
      path == AppRoutes.resetPassword) {
    return null;
  }
  return from;
}
