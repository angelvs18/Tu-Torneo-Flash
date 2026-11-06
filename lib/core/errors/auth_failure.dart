/// Auth errors the UI knows how to explain. Thrown by `AuthRepository`.
enum AuthFailure implements Exception {
  invalidCredentials,
  emailInUse,
  weakPassword,
  emailNotConfirmed,
  samePassword,
  rateLimited,
  network,

  /// The user closed the Google/Apple sheet. The UI shows nothing.
  cancelled,
  unknown;

  /// Maps a Supabase Auth error code (https://supabase.com/docs/guides/auth/debugging/error-codes).
  static AuthFailure fromCode(String? code) => switch (code) {
    'invalid_credentials' => invalidCredentials,
    'user_already_exists' || 'email_exists' => emailInUse,
    'weak_password' => weakPassword,
    'email_not_confirmed' => emailNotConfirmed,
    'same_password' => samePassword,
    'over_email_send_rate_limit' || 'over_request_rate_limit' => rateLimited,
    _ => unknown,
  };
}
