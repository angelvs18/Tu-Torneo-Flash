import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

/// The signed-in account, decoupled from the Supabase `User` type.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({required String id, String? email}) = _AppUser;
}

/// An auth state change coming from the backend.
@freezed
abstract class AuthChange with _$AuthChange {
  const factory AuthChange({
    AppUser? user,

    /// The user opened a password reset link and must choose a new password.
    @Default(false) bool passwordRecovery,
  }) = _AuthChange;
}
