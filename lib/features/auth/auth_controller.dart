import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/errors/auth_failure.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import 'session.dart';

part 'auth_controller.g.dart';

/// Runs auth actions for the auth screens. `state` carries loading and the
/// last [AuthFailure]; navigation happens through the router redirect.
@riverpod
class AuthController extends _$AuthController {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _repo.signInWithEmail(email: email, password: password));

  /// Null on error.
  Future<SignUpResult?> signUp({
    required String email,
    required String password,
  }) async {
    SignUpResult? result;
    final ok = await _run(() async {
      result = await _repo.signUpWithEmail(email: email, password: password);
    });
    return ok ? result : null;
  }

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> updatePassword(String newPassword) => _run(() async {
    await _repo.updatePassword(newPassword);
    ref.read(sessionProvider.notifier).passwordRecovered();
  });

  Future<bool> signInWithGoogle() => _run(_repo.signInWithGoogle);

  Future<bool> signInWithApple() => _run(() async {
    final name = await _repo.signInWithApple();
    if (name == null) return;
    final session = ref.read(sessionProvider.notifier);
    await ref.read(profileRepositoryProvider).fillDisplayNameIfMissing(name);
    await session.reloadProfile();
  });

  Future<bool> signOut() => _run(_repo.signOut);

  Future<bool> _run(Future<void> Function() body) async {
    state = const AsyncLoading<void>();
    try {
      await body();
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } on AuthFailure catch (f, st) {
      if (ref.mounted) {
        state = f == AuthFailure.cancelled
            ? const AsyncData(null)
            : AsyncError<void>(f, st);
      }
      return false;
    } on Exception catch (_, st) {
      if (ref.mounted) state = AsyncError<void>(AuthFailure.unknown, st);
      return false;
    }
  }
}
