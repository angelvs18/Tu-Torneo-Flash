import 'package:flutter_test/flutter_test.dart';
import 'package:tu_torneo_flash/core/errors/auth_failure.dart';
import 'package:tu_torneo_flash/core/utils/validators.dart';

void main() {
  group('AuthFailure.fromCode', () {
    test('maps Supabase error codes', () {
      expect(
        AuthFailure.fromCode('invalid_credentials'),
        AuthFailure.invalidCredentials,
      );
      expect(
        AuthFailure.fromCode('user_already_exists'),
        AuthFailure.emailInUse,
      );
      expect(AuthFailure.fromCode('email_exists'), AuthFailure.emailInUse);
      expect(AuthFailure.fromCode('weak_password'), AuthFailure.weakPassword);
      expect(
        AuthFailure.fromCode('email_not_confirmed'),
        AuthFailure.emailNotConfirmed,
      );
      expect(AuthFailure.fromCode('same_password'), AuthFailure.samePassword);
      expect(
        AuthFailure.fromCode('over_email_send_rate_limit'),
        AuthFailure.rateLimited,
      );
      expect(
        AuthFailure.fromCode('over_request_rate_limit'),
        AuthFailure.rateLimited,
      );
    });

    test('unknown or missing codes are unknown', () {
      expect(AuthFailure.fromCode('something_new'), AuthFailure.unknown);
      expect(AuthFailure.fromCode(null), AuthFailure.unknown);
    });
  });

  group('Validators.email', () {
    test('requires a value', () {
      expect(Validators.email(null), FieldError.required);
      expect(Validators.email('   '), FieldError.required);
    });

    test('rejects malformed addresses', () {
      for (final v in [
        'ana',
        'ana@',
        '@test.dev',
        'ana@test',
        'a na@test.dev',
      ]) {
        expect(Validators.email(v), FieldError.invalidEmail, reason: v);
      }
    });

    test('accepts valid addresses, ignoring surrounding spaces', () {
      expect(Validators.email(' ana.lopez+liga@test.dev '), isNull);
    });
  });

  group('Validators.password', () {
    test('requires at least 8 characters', () {
      expect(Validators.password(''), FieldError.required);
      expect(Validators.password('1234567'), FieldError.passwordTooShort);
      expect(Validators.password('12345678'), isNull);
    });

    test('confirmation must match', () {
      expect(
        Validators.passwordConfirmation('', 'secret12'),
        FieldError.required,
      );
      expect(
        Validators.passwordConfirmation('secret13', 'secret12'),
        FieldError.passwordsDontMatch,
      );
      expect(Validators.passwordConfirmation('secret12', 'secret12'), isNull);
    });
  });

  group('Validators.displayName', () {
    test('mirrors the database check: 1–60 chars after trim', () {
      expect(Validators.displayName('   '), FieldError.required);
      expect(Validators.displayName(' ${'a' * 60} '), isNull);
      expect(Validators.displayName('a' * 61), FieldError.tooLong);
    });
  });
}
