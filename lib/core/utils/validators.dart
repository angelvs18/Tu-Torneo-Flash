/// Form field problems. The UI maps each one to an ARB string.
enum FieldError {
  required,
  invalidEmail,
  passwordTooShort,
  passwordsDontMatch,
  tooLong,
}

abstract final class Validators {
  static const passwordMinLength = 8;

  /// Mirrors the `profiles_display_name_len` check in the database.
  static const displayNameMaxLength = 60;

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static FieldError? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return FieldError.required;
    return _email.hasMatch(v) ? null : FieldError.invalidEmail;
  }

  static FieldError? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return FieldError.required;
    return v.length < passwordMinLength ? FieldError.passwordTooShort : null;
  }

  static FieldError? passwordConfirmation(String? value, String password) {
    if ((value ?? '').isEmpty) return FieldError.required;
    return value == password ? null : FieldError.passwordsDontMatch;
  }

  static FieldError? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return FieldError.required;
    return v.length > displayNameMaxLength ? FieldError.tooLong : null;
  }
}
