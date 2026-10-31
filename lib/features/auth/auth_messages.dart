import '../../core/errors/auth_failure.dart';
import '../../core/utils/validators.dart';
import '../../l10n/generated/app_localizations.dart';

extension AuthMessages on AppLocalizations {
  String fieldError(FieldError e) => switch (e) {
    FieldError.required => errorRequired,
    FieldError.invalidEmail => errorInvalidEmail,
    FieldError.passwordTooShort => errorPasswordTooShort(
      Validators.passwordMinLength,
    ),
    FieldError.passwordsDontMatch => errorPasswordsDontMatch,
    FieldError.tooLong => errorTooLong(Validators.displayNameMaxLength),
  };

  String authError(Object error) => switch (error) {
    AuthFailure.invalidCredentials => authErrorInvalidCredentials,
    AuthFailure.emailInUse => authErrorEmailInUse,
    AuthFailure.weakPassword => authErrorWeakPassword,
    AuthFailure.emailNotConfirmed => authErrorEmailNotConfirmed,
    AuthFailure.samePassword => authErrorSamePassword,
    AuthFailure.rateLimited => authErrorRateLimited,
    AuthFailure.network => authErrorNetwork,
    _ => authErrorUnknown,
  };
}
