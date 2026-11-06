import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/errors/auth_failure.dart';

class AppleCredential {
  const AppleCredential({
    required this.identityToken,
    this.givenName,
    this.familyName,
  });

  final String identityToken;

  /// Apple only sends the name on the very first authorization.
  final String? givenName;
  final String? familyName;

  String? get fullName {
    final parts = [
      givenName,
      familyName,
    ].map((p) => p?.trim() ?? '').where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// Native Sign in with Apple, wrapped so the repository can be tested.
abstract interface class AppleCredentialSource {
  bool get isAvailable;

  /// [hashedNonce] is the SHA-256 of the raw nonce later sent to Supabase.
  /// Throws [AuthFailure.cancelled] if the user closes the sheet.
  Future<AppleCredential> obtain({required String hashedNonce});
}

class NativeAppleCredentialSource implements AppleCredentialSource {
  const NativeAppleCredentialSource();

  /// iOS only: Apple requires it next to Google there; on Android it adds nothing.
  @override
  bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AppleCredential> obtain({required String hashedNonce}) async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final token = c.identityToken;
      if (token == null) throw AuthFailure.unknown;
      return AppleCredential(
        identityToken: token,
        givenName: c.givenName,
        familyName: c.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      throw e.code == AuthorizationErrorCode.canceled
          ? AuthFailure.cancelled
          : AuthFailure.unknown;
    }
  }
}
