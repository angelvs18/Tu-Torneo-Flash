import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/data/repositories/auth_repository.dart';
import 'package:tu_torneo_flash/data/repositories/profile_repository.dart';
import 'package:tu_torneo_flash/features/auth/session.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late ProviderContainer c;

  ProviderContainer create() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    addTearDown(container.dispose);
    container.listen(sessionProvider, (_, _) {}); // keep it alive and active
    return container;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository(namedProfile());
  });

  test('restores a stored session and loads the profile', () async {
    auth.currentUser = testUser;
    c = create();
    expect(c.read(sessionProvider).profileLoading, isTrue);

    await settle();

    final s = c.read(sessionProvider);
    expect(s.isSignedIn, isTrue);
    expect(s.profile?.displayName, 'Ana');
    expect(s.profileLoading, isFalse);
  });

  test('signing in loads the profile; signing out clears everything', () async {
    c = create();
    expect(c.read(sessionProvider).isSignedIn, isFalse);

    auth.emit(testUser);
    await settle();
    await settle();
    expect(c.read(sessionProvider).profile, isNotNull);

    auth.emit(null);
    await settle();
    expect(c.read(sessionProvider), const SessionState());
  });

  test('token refreshes keep the loaded profile', () async {
    auth.currentUser = testUser;
    c = create();
    await settle();
    profiles.profile = null; // a refetch would lose it

    auth.emit(testUser);
    await settle();

    expect(c.read(sessionProvider).profile?.displayName, 'Ana');
  });

  test('needsProfile only once the profile is known to have no name', () async {
    profiles.profile = namedProfile().copyWith(displayName: null);
    auth.currentUser = testUser;
    c = create();
    expect(
      c.read(sessionProvider).needsProfile,
      isFalse,
      reason: 'still loading',
    );

    await settle();
    expect(c.read(sessionProvider).needsProfile, isTrue);
  });
}
