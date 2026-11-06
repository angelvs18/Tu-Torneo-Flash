import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/env.dart';
import '../../core/errors/auth_failure.dart';
import '../dto/app_user.dart';
import '../social/apple_credential_source.dart';
import '../social/google_id_token_source.dart';
import '../supabase_client.dart';

part 'auth_repository.g.dart';

/// Deep link for email confirmation and password reset (Android intent-filter,
/// iOS CFBundleURLTypes and Supabase Auth redirect URLs).
const authRedirectUrl = 'app.tutorneoflash.mobile://login-callback';

enum SignUpResult { signedIn, confirmationSent }

/// Every method throws [AuthFailure] on error.
abstract interface class AuthRepository {
  AppUser? get currentUser;
  Stream<AuthChange> changes();

  bool get isGoogleAvailable;
  bool get isAppleAvailable;

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> signInWithGoogle();

  /// Returns the name Apple shared (first authorization only), if any.
  Future<String?> signInWithApple();
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._auth, {
    required this.google,
    required this.apple,
  });

  final GoTrueClient _auth;
  final GoogleIdTokenSource google;
  final AppleCredentialSource apple;

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Stream<AuthChange> changes() => _auth.onAuthStateChange.map(
    (s) => AuthChange(
      user: _toAppUser(s.session?.user),
      passwordRecovery: s.event == AuthChangeEvent.passwordRecovery,
    ),
  );

  @override
  bool get isGoogleAvailable => google.isAvailable;

  @override
  bool get isAppleAvailable => apple.isAvailable;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(
    () => _auth.signInWithPassword(email: email.trim(), password: password),
  );

  @override
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: authRedirectUrl,
    );
    return res.session != null
        ? SignUpResult.signedIn
        : SignUpResult.confirmationSent;
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () =>
        _auth.resetPasswordForEmail(email.trim(), redirectTo: authRedirectUrl),
  );

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
    final idToken = await google.obtainIdToken();
    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  });

  @override
  Future<String?> signInWithApple() => _guard(() async {
    final rawNonce = generateNonce();
    final credential = await apple.obtain(hashedNonce: sha256Hex(rawNonce));
    await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: credential.identityToken,
      nonce: rawNonce,
    );
    return credential.fullName;
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  static AppUser? _toAppUser(User? u) =>
      u == null ? null : AppUser(id: u.id, email: u.email);

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw AuthFailure.network;
    } on AuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }
}

/// URL-safe random nonce (32 bytes of entropy).
String generateNonce([Random? random]) {
  final r = random ?? Random.secure();
  return base64UrlEncode(List<int>.generate(32, (_) => r.nextInt(256)))
      .replaceAll('=', '');
}

String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => SupabaseAuthRepository(
  ref.watch(supabaseClientProvider).auth,
  google: NativeGoogleIdTokenSource(
    webClientId: Env.googleWebClientId,
    iosClientId: Env.googleIosClientId,
  ),
  apple: const NativeAppleCredentialSource(),
);
