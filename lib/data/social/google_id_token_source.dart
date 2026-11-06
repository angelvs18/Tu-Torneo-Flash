import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/auth_failure.dart';

/// Native Google sign-in, wrapped so the repository can be tested.
abstract interface class GoogleIdTokenSource {
  bool get isAvailable;

  /// Shows the Google sheet and returns an ID token for Supabase.
  /// Throws [AuthFailure.cancelled] if the user closes it.
  Future<String> obtainIdToken();
}

class NativeGoogleIdTokenSource implements GoogleIdTokenSource {
  NativeGoogleIdTokenSource({required this.webClientId, this.iosClientId = ''});

  /// OAuth "Web application" client ID: Supabase validates the token audience against it.
  final String webClientId;
  final String iosClientId;

  Future<void>? _init;

  @override
  bool get isAvailable =>
      webClientId.isNotEmpty &&
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android => true,
        TargetPlatform.iOS => iosClientId.isNotEmpty,
        _ => false,
      };

  @override
  Future<String> obtainIdToken() async {
    final google = GoogleSignIn.instance;
    await (_init ??= google.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosClientId
          : null,
      serverClientId: webClientId,
    ));
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw AuthFailure.unknown;
      return idToken;
    } on GoogleSignInException catch (e) {
      throw e.code == GoogleSignInExceptionCode.canceled
          ? AuthFailure.cancelled
          : AuthFailure.unknown;
    }
  }
}
