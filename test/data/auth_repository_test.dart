import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tu_torneo_flash/core/errors/auth_failure.dart';
import 'package:tu_torneo_flash/data/repositories/auth_repository.dart';
import 'package:tu_torneo_flash/data/social/apple_credential_source.dart';
import 'package:tu_torneo_flash/data/social/google_id_token_source.dart';

class MockGoTrue extends Mock implements GoTrueClient {}

class FakeGoogle implements GoogleIdTokenSource {
  AuthFailure? failure;

  @override
  bool get isAvailable => true;

  @override
  Future<String> obtainIdToken() async {
    if (failure != null) throw failure!;
    return 'google-id-token';
  }
}

class FakeApple implements AppleCredentialSource {
  String? receivedHashedNonce;
  AppleCredential credential = const AppleCredential(
    identityToken: 'apple-id-token',
  );

  @override
  bool get isAvailable => true;

  @override
  Future<AppleCredential> obtain({required String hashedNonce}) async {
    receivedHashedNonce = hashedNonce;
    return credential;
  }
}

void main() {
  late MockGoTrue auth;
  late FakeGoogle google;
  late FakeApple apple;
  late SupabaseAuthRepository repo;

  setUpAll(() => registerFallbackValue(OAuthProvider.google));

  setUp(() {
    auth = MockGoTrue();
    google = FakeGoogle();
    apple = FakeApple();
    repo = SupabaseAuthRepository(auth, google: google, apple: apple);
  });

  void stubIdToken() => when(
    () => auth.signInWithIdToken(
      provider: any(named: 'provider'),
      idToken: any(named: 'idToken'),
      nonce: any(named: 'nonce'),
    ),
  ).thenAnswer((_) async => AuthResponse());

  group('email', () {
    void stubPassword(Object error) => when(
      () => auth.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(error);

    test('trims the email before signing in', () async {
      when(
        () => auth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse());

      await repo.signInWithEmail(
        email: '  ana@test.dev ',
        password: 'secret12',
      );

      verify(
        () => auth.signInWithPassword(
          email: 'ana@test.dev',
          password: 'secret12',
        ),
      ).called(1);
    });

    test('maps API error codes to AuthFailure', () {
      stubPassword(
        const AuthApiException(
          'Invalid',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(
        repo.signInWithEmail(email: 'a@b.co', password: 'x'),
        throwsA(AuthFailure.invalidCredentials),
      );
    });

    test('network failures become AuthFailure.network', () {
      stubPassword(AuthRetryableFetchException());
      expect(
        repo.signInWithEmail(email: 'a@b.co', password: 'x'),
        throwsA(AuthFailure.network),
      );
    });

    test(
      'sign-up without a session means a confirmation email was sent',
      () async {
        when(
          () => auth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            emailRedirectTo: any(named: 'emailRedirectTo'),
          ),
        ).thenAnswer((_) async => AuthResponse());

        expect(
          await repo.signUpWithEmail(email: 'a@b.co', password: 'secret12'),
          SignUpResult.confirmationSent,
        );
        verify(
          () => auth.signUp(
            email: 'a@b.co',
            password: 'secret12',
            emailRedirectTo: authRedirectUrl,
          ),
        ).called(1);
      },
    );

    test('password reset uses the app deep link', () async {
      when(
        () => auth.resetPasswordForEmail(
          any(),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenAnswer((_) async {});

      await repo.sendPasswordReset(' a@b.co ');

      verify(
        () => auth.resetPasswordForEmail('a@b.co', redirectTo: authRedirectUrl),
      ).called(1);
    });
  });

  group('Google', () {
    test('exchanges the Google ID token with Supabase', () async {
      stubIdToken();

      await repo.signInWithGoogle();

      verify(
        () => auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: 'google-id-token',
        ),
      ).called(1);
    });

    test('a cancelled sheet never reaches Supabase', () async {
      google.failure = AuthFailure.cancelled;

      await expectLater(
        repo.signInWithGoogle(),
        throwsA(AuthFailure.cancelled),
      );
      verifyNever(
        () => auth.signInWithIdToken(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
        ),
      );
    });
  });

  group('Apple', () {
    test(
      'sends the hashed nonce to Apple and the raw nonce to Supabase',
      () async {
        stubIdToken();

        await repo.signInWithApple();

        final rawNonce =
            verify(
                  () => auth.signInWithIdToken(
                    provider: OAuthProvider.apple,
                    idToken: 'apple-id-token',
                    nonce: captureAny(named: 'nonce'),
                  ),
                ).captured.single
                as String;
        expect(apple.receivedHashedNonce, sha256Hex(rawNonce));
      },
    );

    test('returns the shared name only when Apple sends it', () async {
      stubIdToken();
      expect(await repo.signInWithApple(), isNull);

      apple.credential = const AppleCredential(
        identityToken: 'apple-id-token',
        givenName: ' Ana ',
        familyName: 'López',
      );
      expect(await repo.signInWithApple(), 'Ana López');
    });
  });

  test('nonces are url-safe and unique', () {
    final a = generateNonce();
    expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(generateNonce(), isNot(a));
  });

  group('availability', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('Apple is offered on iOS only', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(const NativeAppleCredentialSource().isAvailable, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(const NativeAppleCredentialSource().isAvailable, isFalse);
    });

    test('Google needs its client IDs', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(NativeGoogleIdTokenSource(webClientId: '').isAvailable, isFalse);
      expect(NativeGoogleIdTokenSource(webClientId: 'web').isAvailable, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        NativeGoogleIdTokenSource(webClientId: 'web').isAvailable,
        isFalse,
      );
      expect(
        NativeGoogleIdTokenSource(
          webClientId: 'web',
          iosClientId: 'ios',
        ).isAvailable,
        isTrue,
      );
    });
  });
}
