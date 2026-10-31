import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/data/dto/profile.dart';
import 'package:tu_torneo_flash/features/auth/auth_redirect.dart';
import 'package:tu_torneo_flash/features/auth/session.dart';

import '../../helpers/fakes.dart';

String? go(String location, SessionState s) =>
    authRedirect(Uri.parse(location), s);

void main() {
  const signedOut = SessionState();
  final ready = SessionState(user: testUser, profile: namedProfile());
  final loading = const SessionState(user: testUser, profileLoading: true);
  final noName = SessionState(
    user: testUser,
    profile: Profile(id: testUser.id),
  );
  final recovering = ready.copyWith(recoveringPassword: true);

  group('signed out', () {
    test('public pages stay public', () {
      for (final p in [
        '/',
        '/t/ABC234?c=x',
        '/login',
        '/sign-up',
        '/forgot-password',
        '/nope',
      ]) {
        expect(go(p, signedOut), isNull, reason: p);
      }
    });

    test('organizer pages go to login, remembering where they were going', () {
      expect(go('/my-tournaments', signedOut), '/login?from=%2Fmy-tournaments');
      expect(go('/profile', signedOut), '/login?from=%2Fprofile');
      expect(go('/complete-profile', signedOut), startsWith('/login'));
    });

    test('reset password without a session goes to login', () {
      expect(go('/reset-password', signedOut), '/login');
    });

    test('the auth deep link waits for the session', () {
      expect(go('/login-callback', signedOut), isNull);
    });
  });

  group('signed in', () {
    test('auth pages bounce to from, or to my tournaments', () {
      expect(go('/login', ready), '/my-tournaments');
      expect(go('/sign-up?from=%2Fprofile', ready), '/profile');
      expect(go('/login-callback', ready), '/my-tournaments');
    });

    test('from must be an in-app path (no open redirects or loops)', () {
      expect(
        go('/login?from=https%3A%2F%2Fevil.dev', ready),
        '/my-tournaments',
      );
      expect(go('/login?from=%2F%2Fevil.dev', ready), '/my-tournaments');
      expect(go('/login?from=%2Flogin', ready), '/my-tournaments');
    });

    test('organizer and public pages are open', () {
      for (final p in ['/my-tournaments', '/profile', '/', '/t/ABC234']) {
        expect(go(p, ready), isNull, reason: p);
      }
    });

    test('complete profile is left once the name exists', () {
      expect(go('/complete-profile?from=%2Fprofile', ready), '/profile');
      expect(go('/complete-profile', loading), isNull);
    });

    test('a missing name sends organizer pages to complete profile', () {
      expect(
        go('/my-tournaments', noName),
        '/complete-profile?from=%2Fmy-tournaments',
      );
      expect(
        go('/login?from=%2Fprofile', noName),
        '/complete-profile?from=%2Fprofile',
      );
      expect(go('/complete-profile', noName), isNull);
      expect(
        go('/t/ABC234', noName),
        isNull,
        reason: 'spectating needs no name',
      );
    });

    test('while the profile loads nobody is forced anywhere', () {
      expect(go('/my-tournaments', loading), isNull);
    });
  });

  group('password recovery', () {
    test('everything goes to reset password until it is done', () {
      expect(go('/my-tournaments', recovering), '/reset-password');
      expect(go('/', recovering), '/reset-password');
      expect(go('/reset-password', recovering), isNull);
    });

    test('after recovery reset password is closed', () {
      expect(go('/reset-password', ready), '/my-tournaments');
    });
  });
}
