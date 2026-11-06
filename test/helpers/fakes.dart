import 'dart:async';
import 'dart:typed_data';

import 'package:tu_torneo_flash/core/errors/auth_failure.dart';
import 'package:tu_torneo_flash/data/dto/app_user.dart';
import 'package:tu_torneo_flash/data/dto/profile.dart';
import 'package:tu_torneo_flash/data/repositories/auth_repository.dart';
import 'package:tu_torneo_flash/data/repositories/profile_repository.dart';

const testUser = AppUser(id: 'u1', email: 'ana@test.dev');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.currentUser,
    this.isGoogleAvailable = false,
    this.isAppleAvailable = false,
  });

  final _changes = StreamController<AuthChange>.broadcast();

  /// Thrown (once) by the next call.
  AuthFailure? nextFailure;
  SignUpResult signUpResult = SignUpResult.signedIn;
  String? appleName;
  final calls = <String>[];

  @override
  bool isGoogleAvailable;

  @override
  bool isAppleAvailable;

  @override
  AppUser? currentUser;

  @override
  Stream<AuthChange> changes() => _changes.stream;

  void emit(AppUser? user, {bool passwordRecovery = false}) {
    currentUser = user;
    _changes.add(AuthChange(user: user, passwordRecovery: passwordRecovery));
  }

  Future<void> _call(String name) async {
    calls.add(name);
    final f = nextFailure;
    nextFailure = null;
    if (f != null) throw f;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _call('signIn:$email');
    emit(AppUser(id: testUser.id, email: email));
  }

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await _call('signUp:$email');
    if (signUpResult == SignUpResult.signedIn) {
      emit(AppUser(id: testUser.id, email: email));
    }
    return signUpResult;
  }

  @override
  Future<void> sendPasswordReset(String email) => _call('reset:$email');

  @override
  Future<void> updatePassword(String newPassword) => _call('updatePassword');

  @override
  Future<void> signInWithGoogle() async {
    await _call('google');
    emit(testUser);
  }

  @override
  Future<String?> signInWithApple() async {
    await _call('apple');
    emit(testUser);
    return appleName;
  }

  @override
  Future<void> signOut() async {
    await _call('signOut');
    emit(null);
  }
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.profile]);

  Profile? profile;
  final uploads = <String>[];

  @override
  Future<Profile?> fetchMine() async => profile;

  Profile get _current => profile ?? Profile(id: testUser.id);

  @override
  Future<Profile> updateDisplayName(String displayName) async =>
      profile = _current.copyWith(displayName: displayName.trim());

  @override
  Future<void> fillDisplayNameIfMissing(String displayName) async {
    if (_current.displayName == null) await updateDisplayName(displayName);
  }

  @override
  Future<Profile> uploadAvatar(
    Uint8List bytes, {
    required String contentType,
  }) async {
    uploads.add(contentType);
    return profile = _current.copyWith(
      avatarUrl: 'https://cdn.test/avatar?v=1',
    );
  }
}

Profile namedProfile([String name = 'Ana']) =>
    Profile(id: testUser.id, displayName: name);
