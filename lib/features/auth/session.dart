import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dto/app_user.dart';
import '../../data/dto/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';

part 'session.freezed.dart';
part 'session.g.dart';

@freezed
abstract class SessionState with _$SessionState {
  const factory SessionState({
    AppUser? user,
    Profile? profile,
    @Default(false) bool profileLoading,
    @Default(false) bool recoveringPassword,
  }) = _SessionState;

  const SessionState._();

  bool get isSignedIn => user != null;

  /// Signed in, profile loaded, but no name yet (e.g. Apple private relay).
  bool get needsProfile =>
      isSignedIn && profile != null && profile!.displayName == null;
}

/// Single source of truth for "who is signed in" and their profile.
/// The router redirects from this state.
@Riverpod(keepAlive: true)
class Session extends _$Session {
  @override
  SessionState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.changes().listen(_onChange);
    ref.onDispose(sub.cancel);

    final user = repo.currentUser;
    if (user != null) unawaited(_loadProfile(user.id));
    return SessionState(user: user, profileLoading: user != null);
  }

  void _onChange(AuthChange change) {
    final user = change.user;
    final userChanged = user?.id != state.user?.id;
    state = state.copyWith(
      user: user,
      profile: userChanged ? null : state.profile,
      profileLoading: user != null && (userChanged || state.profileLoading),
      recoveringPassword:
          change.passwordRecovery || (state.recoveringPassword && user != null),
    );
    if (user != null && userChanged) unawaited(_loadProfile(user.id));
  }

  Future<void> _loadProfile(String userId) async {
    Profile? profile;
    try {
      profile = await ref.read(profileRepositoryProvider).fetchMine();
    } on Exception {
      // TODO(product): offer a retry when the profile fails to load.
      profile = null;
    }
    if (state.user?.id != userId) return; // signed out or switched meanwhile
    state = state.copyWith(profile: profile, profileLoading: false);
  }

  Future<void> reloadProfile() async {
    final id = state.user?.id;
    if (id != null) await _loadProfile(id);
  }

  void setProfile(Profile profile) => state = state.copyWith(profile: profile);

  void passwordRecovered() => state = state.copyWith(recoveringPassword: false);
}
